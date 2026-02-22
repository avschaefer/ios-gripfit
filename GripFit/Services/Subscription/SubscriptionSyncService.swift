import Foundation
import FirebaseFirestore

class SubscriptionSyncService {
    private let db = Firestore.firestore()

    func syncToFirebase(userId: String, state: SubscriptionState) async throws {
        let data: [String: Any] = [
            "subscription": [
                "tier": state.tier.rawValue,
                "isActive": state.isActive,
                "productId": state.productId as Any,
                "expirationDate": state.expirationDate.map { Timestamp(date: $0) } as Any,
                "originalPurchaseDate": state.originalPurchaseDate.map { Timestamp(date: $0) } as Any,
                "willAutoRenew": state.willAutoRenew,
                "lastSyncedAt": Timestamp(date: Date()),
                "isFromOfferCode": state.isInFreeTrialFromReferral
            ]
        ]

        try await db.collection("users").document(userId).setData(data, merge: true)
    }

    func logSubscriptionEvent(
        userId: String,
        eventType: String,
        productId: String?,
        expirationDate: Date?,
        offerCode: String? = nil,
        transactionId: String
    ) async throws {
        let data: [String: Any] = [
            "eventType": eventType,
            "productId": productId as Any,
            "timestamp": Timestamp(date: Date()),
            "expirationDate": expirationDate.map { Timestamp(date: $0) } as Any,
            "offerCodeUsed": offerCode as Any,
            "transactionId": transactionId
        ]

        try await db.collection("users").document(userId)
            .collection("subscriptionHistory")
            .addDocument(data: data)
    }
}
