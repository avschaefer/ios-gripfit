import Foundation
import FirebaseFirestore

enum ReferralError: LocalizedError {
    case invalidCode
    case selfReferral
    case alreadyReferred

    var errorDescription: String? {
        switch self {
        case .invalidCode: return "That referral code doesn't exist."
        case .selfReferral: return "You can't refer yourself."
        case .alreadyReferred: return "You've already used a referral code."
        }
    }
}

@MainActor
class ReferralService {
    static let shared = ReferralService()
    private let db = Firestore.firestore()

    private init() {}

    /// Generate a unique referral code for a new user
    func generateReferralCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code = "GRIP-" + String((0..<4).map { _ in chars.randomElement()! })
        return code
    }

    /// Save a referral code to a user's document (call at registration)
    func saveReferralCode(userId: String, code: String) async throws {
        try await db.collection("users").document(userId).setData([
            "referralCode": code,
            "referralRewardsPending": 0,
            "referralRewardsRedeemed": 0,
        ], merge: true)
    }

    /// Fetch the referral code for the current user
    func fetchReferralCode(userId: String) async throws -> String? {
        let doc = try await db.collection("users").document(userId).getDocument()
        return doc.data()?["referralCode"] as? String
    }

    /// Fetch referral stats for a user
    func fetchReferralStats(userId: String) async throws -> (pending: Int, redeemed: Int, referredBy: String?) {
        let doc = try await db.collection("users").document(userId).getDocument()
        let data = doc.data() ?? [:]
        return (
            pending: data["referralRewardsPending"] as? Int ?? 0,
            redeemed: data["referralRewardsRedeemed"] as? Int ?? 0,
            referredBy: data["referredBy"] as? String
        )
    }

    /// Record that a user was referred by a code
    func recordReferral(refereeUserId: String, referrerCode: String) async throws {
        let snapshot = try await db.collection("users")
            .whereField("referralCode", isEqualTo: referrerCode.uppercased())
            .limit(to: 1)
            .getDocuments()

        guard let referrerDoc = snapshot.documents.first else {
            throw ReferralError.invalidCode
        }

        let referrerUserId = referrerDoc.documentID

        guard referrerUserId != refereeUserId else {
            throw ReferralError.selfReferral
        }

        // Check if referee already has a referrer
        let refereeDoc = try await db.collection("users").document(refereeUserId).getDocument()
        if let existing = refereeDoc.data()?["referredBy"] as? String, !existing.isEmpty {
            throw ReferralError.alreadyReferred
        }

        try await db.collection("referrals").addDocument(data: [
            "referrerUserId": referrerUserId,
            "referrerCode": referrerCode.uppercased(),
            "refereeUserId": refereeUserId,
            "status": "pending",
            "refereeSubscribed": false,
            "createdAt": Timestamp(date: Date())
        ])

        try await db.collection("users").document(refereeUserId).setData([
            "referredBy": referrerUserId
        ], merge: true)
    }

    /// When referee subscribes, complete the referral and assign reward to referrer
    func completeReferral(refereeUserId: String) async throws {
        let snapshot = try await db.collection("referrals")
            .whereField("refereeUserId", isEqualTo: refereeUserId)
            .whereField("status", isEqualTo: "pending")
            .limit(to: 1)
            .getDocuments()

        guard let referralDoc = snapshot.documents.first else { return }

        let referrerUserId = referralDoc.data()["referrerUserId"] as? String ?? ""

        // Assign an offer code from the pool
        let codeSnapshot = try await db.collection("offerCodePool")
            .whereField("status", isEqualTo: "available")
            .limit(to: 1)
            .getDocuments()

        var assignedCode: String?
        if let codeDoc = codeSnapshot.documents.first {
            assignedCode = codeDoc.data()["code"] as? String
            try await codeDoc.reference.updateData([
                "status": "assigned",
                "assignedToUserId": referrerUserId,
                "assignedAt": Timestamp(date: Date())
            ])
        }

        try await referralDoc.reference.updateData([
            "status": "completed",
            "refereeSubscribed": true,
            "referrerOfferCode": assignedCode as Any,
            "completedAt": Timestamp(date: Date())
        ])

        try await db.collection("users").document(referrerUserId).updateData([
            "referralRewardsPending": FieldValue.increment(Int64(1)),
            "pendingOfferCode": assignedCode as Any
        ])
    }
}
