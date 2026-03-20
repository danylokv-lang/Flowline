import Foundation
import Combine
import RevenueCat

/// Manages all subscription state via RevenueCat.
/// Entitlement: "Flowline Pro"
/// Products:    monthly · yearly · lifetime
@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: - Published

    @Published private(set) var customerInfo: CustomerInfo?   = nil
    @Published private(set) var currentOffering: Offering?   = nil
    @Published private(set) var messagesUsedToday: Int        = 0
    @Published private(set) var isLoading: Bool               = false
    @Published var errorMessage: String?                      = nil

    // MARK: - Constants

    /// Must exactly match the entitlement identifier in RevenueCat dashboard
    static let entitlementID = "Flowline Pro"

    static let freeLimit     = 3     // messages/day — free tier
    static let proLimit      = 10    // messages/day — pro/trial tier
    static let trialDays     = 3

    static let monthlyPrice  = "$4.99"
    static let originalPrice = "$10.99"

    // MARK: - Computed Pro Status

    var isPro: Bool {
        customerInfo?.entitlements[Self.entitlementID]?.isActive == true
    }

    var isLifetime: Bool {
        customerInfo?.entitlements[Self.entitlementID]?.productIdentifier.contains("lifetime") == true
    }

    // MARK: - Trial (local 3-day trial, runs before or without purchase)

    private let kTrialStart = "trial_start_date"
    private let kUsageCount = "usage_count"
    private let kUsageDate  = "usage_date"

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

    var dailyLimit: Int {
        isPro || isInTrial ? Self.proLimit : Self.freeLimit
    }

    func startTrialIfNeeded() {
        if trialStartDate == nil {
            UserDefaults.standard.set(Date(), forKey: kTrialStart)
        }
    }

    // MARK: - Message Limiting

    var isAtLimit: Bool {
        !isPro && !isInTrial && messagesUsedToday >= dailyLimit
    }

    var remainingMessages: Int {
        max(0, dailyLimit - messagesUsedToday)
    }

    func consumeMessage() -> Bool {
        if isPro { return true }
        resetIfNewDay()
        if messagesUsedToday >= dailyLimit { return false }
        messagesUsedToday += 1
        UserDefaults.standard.set(messagesUsedToday, forKey: kUsageCount)
        return true
    }

    // MARK: - Init

    init() {
        // ⚠️ Configure FIRST — before any Purchases.shared access
        Self.configureIfNeeded()

        resetIfNewDay()
        messagesUsedToday = UserDefaults.standard.integer(forKey: kUsageCount)

        // Listen to RevenueCat customer info updates in real time
        Purchases.shared.delegate = RCDelegateHandler.shared

        Task {
            await refreshCustomerInfo()
            await fetchOfferings()
        }

        // Forward delegate updates to this manager
        RCDelegateHandler.shared.onCustomerInfoUpdate = { [weak self] info in
            Task { @MainActor [weak self] in
                self?.customerInfo = info
            }
        }
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
        isLoading   = true
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

    /// Configures RevenueCat exactly once. Safe to call multiple times.
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

    private func resetIfNewDay() {
        let today     = Calendar.current.startOfDay(for: Date())
        let savedDate = UserDefaults.standard.object(forKey: kUsageDate) as? Date
        guard savedDate == nil || !Calendar.current.isDate(savedDate!, inSameDayAs: today) else { return }
        messagesUsedToday = 0
        UserDefaults.standard.set(0,     forKey: kUsageCount)
        UserDefaults.standard.set(today, forKey: kUsageDate)
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
