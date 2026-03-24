import Foundation
import Combine
import RevenueCat

/// Manages all subscription state via RevenueCat.
/// Entitlement: "Flowline Pro"
/// Products:    monthly · yearly · lifetime
///
/// Gating model:
///   Free  — up to 3 day-plan saves per week
///   Pro   — unlimited saves (+ all features)
@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: - Published

    @Published private(set) var customerInfo: CustomerInfo?  = nil
    @Published private(set) var currentOffering: Offering?  = nil
    @Published private(set) var plansThisWeek: Int           = 0
    @Published private(set) var isLoading: Bool              = false
    @Published var errorMessage: String?                     = nil

    // MARK: - Constants

    /// Must exactly match the entitlement identifier in RevenueCat dashboard
    static let entitlementID   = "Flowline Pro"

    static let weeklyFreeLimit = 3          // plan saves/week — free tier
    static let trialDays       = 3

    static let monthlyPrice    = "$4.99"
    static let yearlyPrice     = "$34.99"

    // MARK: - Computed Pro Status

    var isPro: Bool {
        customerInfo?.entitlements[Self.entitlementID]?.isActive == true
    }

    var isLifetime: Bool {
        customerInfo?.entitlements[Self.entitlementID]?.productIdentifier.contains("lifetime") == true
    }

    // MARK: - Trial (local 3-day trial)

    private let kTrialStart   = "trial_start_date"
    private let kPlansWeek    = "plans_this_week"
    private let kWeekMonday   = "plans_week_monday"   // ISO date of the Monday that started this window
    private let kTotalSaves   = "total_plan_saves"

    var trialStartDate: Date? {
        UserDefaults.standard.object(forKey: kTrialStart) as? Date
    }

    var isInTrial: Bool {
        guard !isPro, let start = trialStartDate else { return false }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return elapsed < Self.trialDays
    }

    var trialDaysRemaining: Int {
        guard let start = trialStartDate else { return 0 }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return max(0, Self.trialDays - elapsed)
    }

    var trialExpired: Bool {
        trialStartDate != nil && !isInTrial && !isPro
    }

    func startTrialIfNeeded() {
        if trialStartDate == nil {
            UserDefaults.standard.set(Date(), forKey: kTrialStart)
        }
    }

    // MARK: - Weekly Plan Limit

    /// Whether the user can save another plan right now.
    var canSavePlan: Bool {
        isPro || isInTrial || plansThisWeek < Self.weeklyFreeLimit
    }

    /// Convenience inverse used by UI to disable controls.
    var isAtLimit: Bool { !canSavePlan }

    /// Total lifetime plan saves — used to trigger review prompts.
    var totalPlanSaves: Int {
        UserDefaults.standard.integer(forKey: kTotalSaves)
    }

    /// Call once per successful plan save. Increments locally immediately, then
    /// confirms with the server and syncs back the authoritative count.
    func recordPlanSave(token: String?) {
        resetIfNewWeek()
        plansThisWeek += 1
        let monday = Self.currentMondayString()
        UserDefaults.standard.set(plansThisWeek, forKey: kPlansWeek)
        UserDefaults.standard.set(monday,        forKey: kWeekMonday)

        let total = UserDefaults.standard.integer(forKey: kTotalSaves) + 1
        UserDefaults.standard.set(total, forKey: kTotalSaves)

        // Ask the server to increment its authoritative counter.
        // The server enforces the limit and resets the week — we sync back its result
        // so the local count matches exactly (prevents proxy-based bypass).
        if let token, !token.isEmpty {
            Task {
                if let result = await SyncService.shared.incrementPlanSave(token: token) {
                    await MainActor.run {
                        self.refreshFromServer(count: result.count, monday: result.monday)
                    }
                }
            }
        }
    }

    /// Called by SyncService after pulling the profile — syncs server's authoritative count.
    func refreshFromServer(count: Int, monday: String) {
        // Empty monday means the DB migration hasn't run yet or no saves recorded —
        // don't wipe the locally-tracked count.
        guard !monday.isEmpty else { return }
        let currentMonday = Self.currentMondayString()
        if monday == currentMonday {
            // Same week — server is authoritative
            plansThisWeek = count
            UserDefaults.standard.set(count,         forKey: kPlansWeek)
            UserDefaults.standard.set(currentMonday, forKey: kWeekMonday)
        } else {
            // Server data is from a past week — current week starts at 0
            plansThisWeek = 0
            UserDefaults.standard.set(0,             forKey: kPlansWeek)
            UserDefaults.standard.set(currentMonday, forKey: kWeekMonday)
        }
    }

    /// Reset local weekly saves when switching accounts (server pull will restore the correct value).
    func resetForAccountSwitch() {
        plansThisWeek = 0
        UserDefaults.standard.removeObject(forKey: kPlansWeek)
        UserDefaults.standard.removeObject(forKey: kWeekMonday)
    }

    // MARK: - Init

    init() {
        // Configure RevenueCat synchronously so Purchases.shared is always
        // valid — even if the user taps "Restore" before setup() runs.
        Self.configureIfNeeded()
        Purchases.shared.delegate = RCDelegateHandler.shared
        RCDelegateHandler.shared.onCustomerInfoUpdate = { [weak self] info in
            Task { @MainActor [weak self] in
                self?.customerInfo = info
            }
        }
        resetIfNewWeek()
        plansThisWeek = UserDefaults.standard.integer(forKey: kPlansWeek)
    }

    /// Call from the root view's `.task {}` to fetch the latest data from
    /// RevenueCat's servers without blocking the initial launch.
    func setup() async {
        await refreshCustomerInfo()
        await fetchOfferings()
    }

    // MARK: - RevenueCat: Fetch

    func refreshCustomerInfo() async {
        do {
            customerInfo = try await Purchases.shared.customerInfo()
        } catch {
            #if DEBUG
            print("RevenueCat customerInfo error:", error.localizedDescription)
            #endif
        }
    }

    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
        } catch {
            #if DEBUG
            print("RevenueCat offerings error:", error.localizedDescription)
            #endif
        }
    }

    // MARK: - RevenueCat: Purchase

    @discardableResult
    func purchase(package: Package) async -> Bool {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result   = try await Purchases.shared.purchase(package: package)
            customerInfo = result.customerInfo
            return isPro
        } catch let error as ErrorCode {
            if error != .purchaseCancelledError {
                errorMessage = error.localizedDescription
            }
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - RevenueCat: Restore

    func restorePurchases() async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            customerInfo = try await Purchases.shared.restorePurchases()
            if !isPro { errorMessage = "No active subscription found." }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Convenience Package Accessors

    var monthlyPackage:  Package? { currentOffering?.monthly }
    var yearlyPackage:   Package? { currentOffering?.annual }
    var lifetimePackage: Package? { currentOffering?.lifetime }

    // MARK: - Private

    static func configureIfNeeded() {
        guard !Purchases.isConfigured else { return }
        let key = Config.revenueCatAPIKey
        guard !key.isEmpty else {
            #if DEBUG
            print("⚠️ RevenueCat API key missing — purchases disabled.")
            #endif
            return
        }
        Purchases.logLevel = .error
        Purchases.configure(withAPIKey: key)
    }

    private func resetIfNewWeek() {
        let currentMonday = Self.currentMondayString()
        let savedMonday   = UserDefaults.standard.string(forKey: kWeekMonday) ?? ""
        if savedMonday != currentMonday {
            plansThisWeek = 0
            UserDefaults.standard.set(0,             forKey: kPlansWeek)
            UserDefaults.standard.set(currentMonday, forKey: kWeekMonday)
        }
    }

    /// Returns the ISO-8601 date string of the Monday that starts the current week.
    /// Using the ISO calendar guarantees Monday is always day 1, locale-independent.
    static func currentMondayString() -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale(identifier: "en_US_POSIX")
        let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let fmt = DateFormatter()
        fmt.locale     = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: monday)
    }
}

// MARK: - RCDelegateHandler (singleton bridge to @MainActor)

final class RCDelegateHandler: NSObject, PurchasesDelegate, @unchecked Sendable {
    static let shared = RCDelegateHandler()
    var onCustomerInfoUpdate: ((CustomerInfo) -> Void)?

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        onCustomerInfoUpdate?(customerInfo)
    }
}
