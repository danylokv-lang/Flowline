import Combine
import Foundation
import StoreKit

// ─────────────────────────────────────────────────────────────────────────────
// StreakManager
//
// Tracks how many consecutive days the user has created a plan.
// Also fires the App Store review prompt after meaningful usage.
// ─────────────────────────────────────────────────────────────────────────────

final class StreakManager: ObservableObject {

    static let shared = StreakManager()

    // ── Published state ──────────────────────────────────────────────────────
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var totalPlansCreated: Int = 0

    // ── UserDefaults keys (scoped per user) ─────────────────────────────────
    private var userSuffix: String = ""

    private var kStreak:      String { "streak.current\(userSuffix)" }
    private var kLongest:     String { "streak.longest\(userSuffix)" }
    private var kLastPlanned: String { "streak.lastPlannedDate\(userSuffix)" }
    private var kTotalPlans:  String { "streak.totalPlans\(userSuffix)" }
    private var kReviewAsked: String { "streak.reviewAsked\(userSuffix)" }

    private let defaults = UserDefaults.standard
    private let cal      = Calendar.current

    private init() {
        // Keys are global until configure(userId:) is called on first login
        currentStreak     = defaults.integer(forKey: kStreak)
        longestStreak     = defaults.integer(forKey: kLongest)
        totalPlansCreated = defaults.integer(forKey: kTotalPlans)
    }

    /// Call immediately after login / account switch.
    /// Loads streak from user-scoped keys so each account has its own streak.
    func configure(userId: String) {
        let newSuffix = userId.isEmpty ? "" : ".\(userId)"
        guard newSuffix != userSuffix else { return }
        userSuffix        = newSuffix
        currentStreak     = defaults.integer(forKey: kStreak)
        longestStreak     = defaults.integer(forKey: kLongest)
        totalPlansCreated = defaults.integer(forKey: kTotalPlans)
    }

    // ── Call every time a plan is successfully saved ──────────────────────────
    func recordPlan() {
        let today = cal.startOfDay(for: Date())

        if let raw = defaults.object(forKey: kLastPlanned) as? Date {
            let last = cal.startOfDay(for: raw)
            if cal.isDate(last, inSameDayAs: today) {
                return   // already recorded today
            }
            let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
            currentStreak = cal.isDate(last, inSameDayAs: yesterday) ? currentStreak + 1 : 1
        } else {
            currentStreak = 1     // very first plan ever
        }

        totalPlansCreated += 1
        if currentStreak > longestStreak { longestStreak = currentStreak }

        defaults.set(today,             forKey: kLastPlanned)
        defaults.set(currentStreak,     forKey: kStreak)
        defaults.set(longestStreak,     forKey: kLongest)
        defaults.set(totalPlansCreated, forKey: kTotalPlans)

        maybeRequestReview()
    }

    // ── Account switch reset ─────────────────────────────────────────────────

    /// Reset in-memory counters when switching accounts.
    /// The on-disk data is preserved under the old user-scoped keys
    /// so switching back restores the correct streak.
    func resetForAccountSwitch() {
        currentStreak     = 0
        longestStreak     = 0
        totalPlansCreated = 0
    }

    // ── Debug helpers (remove before shipping) ───────────────────────────────

    #if DEBUG
    /// Simulates having planned yesterday — call this, then call recordPlan()
    /// to verify the streak increments correctly.
    func debugSetLastPlannedToYesterday() {
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        defaults.set(yesterday, forKey: kLastPlanned)
    }

    /// Wipes all streak data so you can start fresh.
    func debugReset() {
        defaults.removeObject(forKey: kStreak)
        defaults.removeObject(forKey: kLongest)
        defaults.removeObject(forKey: kLastPlanned)
        defaults.removeObject(forKey: kTotalPlans)
        defaults.removeObject(forKey: kReviewAsked)
        currentStreak = 0
        longestStreak = 0
        totalPlansCreated = 0
    }
    #endif

    // ─────────────────────────────────────────────────────────────────────────

    /// True if the user has already created a plan today
    var plannedToday: Bool {
        guard let raw = defaults.object(forKey: kLastPlanned) as? Date else { return false }
        return cal.isDateInToday(raw)
    }

    // ── App Store review prompt ───────────────────────────────────────────────
    private func maybeRequestReview() {
        guard !defaults.bool(forKey: kReviewAsked), totalPlansCreated >= 5 else { return }
        defaults.set(true, forKey: kReviewAsked)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            SKStoreReviewController.requestReview()
        }
    }
}
