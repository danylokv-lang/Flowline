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

    // ── UserDefaults keys ─────────────────────────────────────────────────────
    private let kStreak      = "streak.current"
    private let kLongest     = "streak.longest"
    private let kLastPlanned = "streak.lastPlannedDate"
    private let kTotalPlans  = "streak.totalPlans"
    private let kReviewAsked = "streak.reviewAsked"

    private let defaults = UserDefaults.standard
    private let cal      = Calendar.current

    private init() {
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
