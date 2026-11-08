import Foundation

enum PremiumFeatures {
    static let freeActiveSubscriptionLimit = 5

    static func canAddSubscription(currentActiveCount: Int, isPro: Bool) -> Bool {
        isPro || currentActiveCount < freeActiveSubscriptionLimit
    }
}
