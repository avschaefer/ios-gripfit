import Foundation

enum SubscriptionTier: String, Codable {
    case free
    case pro
}

struct SubscriptionState: Codable {
    var tier: SubscriptionTier
    var isActive: Bool
    var productId: String?
    var expirationDate: Date?
    var originalPurchaseDate: Date?
    var willAutoRenew: Bool
    var isInFreeTrialFromReferral: Bool

    static let free = SubscriptionState(
        tier: .free,
        isActive: false,
        productId: nil,
        expirationDate: nil,
        originalPurchaseDate: nil,
        willAutoRenew: false,
        isInFreeTrialFromReferral: false
    )
}
