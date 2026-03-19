import Foundation
import Combine

/// Tracks daily free usage and subscription state.
/// Drop-in ready for RevenueCat — just replace `isPro` with their entitlement check.
@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: - Published

    @Published private(set) var messagesUsedToday: Int = 0
    @Published private(set) var isPro: Bool = false   // ← swap with RevenueCat entitlement

    // MARK: - Limits

    static let freeLimit = 10          // messages per day on free tier
    static let monthlyPrice = "$4.99"
    static let yearlyPrice  = "$39.99"

    // MARK: - Storage keys

    private let kUsageCount = "usage_count"
    private let kUsageDate  = "usage_date"

    // MARK: - Init

    init() {
        resetIfNewDay()
        messagesUsedToday = UserDefaults.standard.integer(forKey: kUsageCount)
    }

    // MARK: - Public API

    var isAtLimit: Bool {
        !isPro && messagesUsedToday >= Self.freeLimit
    }

    var remainingMessages: Int {
        max(0, Self.freeLimit - messagesUsedToday)
    }

    /// Call before every AI message. Returns false if the user hit the limit.
    func consumeMessage() -> Bool {
        if isPro { return true }
        resetIfNewDay()
        if messagesUsedToday >= Self.freeLimit { return false }
        messagesUsedToday += 1
        UserDefaults.standard.set(messagesUsedToday, forKey: kUsageCount)
        return true
    }

    /// Call when RevenueCat confirms purchase. For now toggle manually for testing.
    func activatePro() {
        isPro = true
    }

    func deactivatePro() {
        isPro = false
    }

    // MARK: - Private

    private func resetIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let savedDate = UserDefaults.standard.object(forKey: kUsageDate) as? Date
        if savedDate == nil || !Calendar.current.isDate(savedDate!, inSameDayAs: today) {
            messagesUsedToday = 0
            UserDefaults.standard.set(0, forKey: kUsageCount)
            UserDefaults.standard.set(today, forKey: kUsageDate)
        }
    }
}
