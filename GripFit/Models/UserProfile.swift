import Foundation

struct UserProfile: Codable {
    var userId: String
    var displayName: String
    var email: String
    var preferredUnit: ForceUnit
    var dominantHand: Hand
    var createdAt: Date

    init(
        userId: String,
        displayName: String,
        email: String,
        preferredUnit: ForceUnit = .kilograms,
        dominantHand: Hand = .right,
        createdAt: Date = Date()
    ) {
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.preferredUnit = preferredUnit
        self.dominantHand = dominantHand
        self.createdAt = createdAt
    }
}

