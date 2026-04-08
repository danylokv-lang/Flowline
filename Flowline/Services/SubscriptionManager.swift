import Foundation
import Combine
import RevenueCat

/// Manages all subscription state via RevenueCat.
/// Entitlement: "Flowline Pro"
///
/// Gating model:
///   Free  — up to 3 day-plan saves per week
///   Pro   — unlimited (entitlement active, covers RC-managed free trials too)
///
/// NOTE: There is NO separate local trial. Trials are configured in App Store Connect
/// as introductory offers on the Pro product and surfaced through RevenueCat.
/// `isPro` returns true during an active trial, so the UI doesn't need to special-case them.
@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: - Published

    @Published private(set) var customerInfo:      CustomerInfo? = nil
    @Published private(set) var currentOffering:   Offering?     = nil
    @Published private(set) var plansThisWeek:     Int           = 0
    @Published private(set) var isLoading:         Bool          = false
    @Published var errorMessage:  String?                        = nil
    /// Fires once when an active Pro subscription expires mid-session.
    @Published private(set) var proJustExpired:   Bool           = false

    private var wasProBeforeUpdate: Bool = false

    // MARK: - Constants

    static let entitlementID   = "Flowline Pro"
    static let weeklyFreeLimit = 3
    static let monthlyPrice    = "$4.99"
    static let yearlyPrice     = "$34.99"

    // MARK: - Pro / Trial status (all derived from RevenueCat)

    var isPro: Bool {
        customerInfo?.entitlements[Self.entitlementID]?.isActive == true
    }

    var isLifetime: Bool {
        customerInfo?.entitlements[Self.entitlementID]?.productIdentifier.contains("lifetime") == true
    }

    /// True while the active entitlement is in its introductory trial period.
    var isInTrial: Bool {
        guard let ent = customerInfo?.entitlements[Self.entitlementID], ent.isActive else { return false }
        return ent.periodType == .trial
    }

    /// Days remaining in a RC-managed trial (0 if not in trial or no expiry date).
    var trialDaysRemaining: Int {
        guard isInTrial,
              let expiry = customerInfo?.entitlements[Self.entitlementID]?.expirationDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        return max(0, days)
    }

    // MARK: - Weekly Plan Limit

    private let kPlansWeek  = "plans_this_week"
    private let kWeekMonday = "plans_week_monday"
    private let kTotalSaves = "total_plan_saves"

    /// Whether the user can save another plan right now.
    var canSavePlan: Bool {
        isPro || plansThisWeek < Self.weeklyFreeLimit
    }

    var isAtLimit: Bool { !canSavePlan }

    /// Lifetime total plan saves — used to trigger the first-save paywall and review prompts.
    /// Keyed to the device but reset on account switch via `clearLocalUserData()` in FlowlineApp.
    var totalPlanSaves: Int {
        UserDefaults.standard.integer(forKey: kTotalSaves)
    }

    /// Call once per successful plan save.
    func recordPlanSave(token: String?) {
        resetIfNewWeek()
        plansThisWeek += 1
        let monday = Self.currentMondayString()
        UserDefaults.standard.set(plansThisWeek, forKey: kPlansWeek)
        UserDefaults.standard.set(monday,        forKey: kWeekMonday)
        let total = UserDefaults.standard.integer(forKey: kTotalSaves) + 1
        UserDefaults.standard.set(total,         forKey: kTotalSaves)

        if let token, !token.isEmpty {
            Task {
                if let result = await SyncService.shared.incrementPlanSave(token: token) {
                    self.refreshFromServer(count: result.count, monday: result.monday)
                }
            }
        }
    }

    /// Called by SyncService after pulling the profile — syncs server's authoritative weekly count.
    func refreshFromServer(count: Int, monday: String) {
        guard !monday.isEmpty else { return }
        let currentMonday = Self.currentMondayString()
        if monday == currentMonday {
            plansThisWeek = count
            UserDefaults.standard.set(count,         forKey: kPlansWeek)
            UserDefaults.standard.set(currentMonday, forKey: kWeekMonday)
        } else {
            plansThisWeek = 0
            UserDefaults.standard.set(0,             forKey: kPlansWeek)
            UserDefaults.standard.set(currentMonday, forKey: kWeekMonday)
        }
    }

    /// Reset local counters when switching accounts.
    /// Server count is restored once pullAll completes.
    func resetForAccountSwitch() {
        plansThisWeek = 0
        UserDefaults.standard.removeObject(forKey: kPlansWeek)
        UserDefaults.standard.removeObject(forKey: kWeekMonday)
    }

    // MARK: - RevenueCat Identity (account-tied subscriptions)

    /// Call immediately after login/registration so RevenueCat links the subscription
    /// to the account, not the device. This is what makes purchases restore on other devices.
    func loginRevenueCat(userId: String) async {
        guard !userId.isEmpty else { return }
        do {
            let (info, _) = try await Purchases.shared.logIn(userId)
            customerInfo = info
        } catch {
            // Non-fatal — RC retries on next launch. Don't block the user.
        }
    }

    /// Call on sign-out so RevenueCat falls back to an anonymous session.
    func logoutRevenueCat() async {
        do {
            customerInfo = try await Purchases.shared.logOut()
        } catch {}
    }

    // MARK: - Init / Setup

    init() {
        Self.configureIfNeeded()
        Purchases.shared.delegate = RCDelegateHandler.shared
        RCDelegateHandler.shared.onCustomerInfoUpdate = { [weak self] info in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasPro = self.isPro
                self.customerInfo = info
                if wasPro && !self.isPro {
                    self.proJustExpired = true
                }
            }
        }
        resetIfNewWeek()
        plansThisWeek = UserDefaults.standard.integer(forKey: kPlansWeek)
    }

    func setup() async {
        await refreshCustomerInfo()
        await fetchOfferings()
    }

    // MARK: - RevenueCat: Fetch

    func refreshCustomerInfo() async {
        let wasPro = isPro
        do {
            customerInfo = try await Purchases.shared.customerInfo()
            // Detect mid-session expiry: was Pro, now isn't
            if wasPro && !isPro {
                proJustExpired = true
            }
        } catch {
            #if DEBUG
            print("RevenueCat customerInfo error:", error.localizedDescription)
            #endif
        }
    }

    /// Call after showing the expired-subscription UI so the flag resets.
    func clearExpiredFlag() { proJustExpired = false }

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
            if error != .purchaseCancelledError { errorMessage = error.localizedDescription }
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

    var monthlyPackage: Package? {
        currentOffering?.monthly
        ?? currentOffering?.availablePackages.first(where: { $0.packageType == .monthly })
        ?? currentOffering?.availablePackages.first(where: { $0.storeProduct.productIdentifier.contains("monthly") })
    }

    var yearlyPackage: Package? {
        currentOffering?.annual
        ?? currentOffering?.availablePackages.first(where: { $0.packageType == .annual })
        ?? currentOffering?.availablePackages.first(where: {
            $0.storeProduct.productIdentifier.contains("annual")
            || $0.storeProduct.productIdentifier.contains("yearly")
            || $0.storeProduct.productIdentifier.contains("year")
        })
    }

    var lifetimePackage: Package? {
        currentOffering?.lifetime
        ?? currentOffering?.availablePackages.first(where: { $0.packageType == .lifetime })
        ?? currentOffering?.availablePackages.first(where: { $0.storeProduct.productIdentifier.contains("lifetime") })
    }

    /// The expiration date of the active Pro entitlement (nil if lifetime or not subscribed).
    var proExpirationDate: Date? {
        customerInfo?.entitlements[Self.entitlementID]?.expirationDate
    }

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

// MARK: - RCDelegateHandler

final class RCDelegateHandler: NSObject, PurchasesDelegate, @unchecked Sendable {
    static let shared = RCDelegateHandler()
    var onCustomerInfoUpdate: ((CustomerInfo) -> Void)?

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        onCustomerInfoUpdate?(customerInfo)
    }
}
