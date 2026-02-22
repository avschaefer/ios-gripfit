import Foundation
import FirebaseFirestore

enum DatabaseError: LocalizedError {
    case notAuthenticated
    case documentNotFound
    case encodingError
    case decodingError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .documentNotFound:
            return "The requested data was not found."
        case .encodingError:
            return "Failed to save data."
        case .decodingError:
            return "Failed to read data."
        case .unknown(let message):
            return message
        }
    }
}

@MainActor
final class DatabaseService {
    static let shared = DatabaseService()
    private lazy var db = Firestore.firestore()

    private init() {}

    // MARK: - User Profile

    func createUserProfile(_ profile: UserProfile) async throws {
        let data: [String: Any] = [
            "displayName": profile.displayName,
            "email": profile.email,
            "preferredUnit": profile.preferredUnit.rawValue,
            "dominantHand": profile.dominantHand.rawValue,
            "createdAt": Timestamp(date: profile.createdAt)
        ]

        do {
            try await db.collection("users").document(profile.userId).setData(data)
        } catch {
            throw DatabaseError.unknown("Failed to create profile: \(error.localizedDescription)")
        }
    }

    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        do {
            let document = try await db.collection("users").document(userId).getDocument()

            guard document.exists, let data = document.data() else {
                return nil
            }

            let displayName = data["displayName"] as? String ?? ""
            let email = data["email"] as? String ?? ""
            let unitRaw = data["preferredUnit"] as? String ?? ForceUnit.kilograms.rawValue
            let handRaw = data["dominantHand"] as? String ?? Hand.right.rawValue
            let createdTimestamp = data["createdAt"] as? Timestamp

            return UserProfile(
                userId: userId,
                displayName: displayName,
                email: email,
                preferredUnit: ForceUnit(rawValue: unitRaw) ?? .kilograms,
                dominantHand: Hand(rawValue: handRaw) ?? .right,
                createdAt: createdTimestamp?.dateValue() ?? Date()
            )
        } catch {
            throw DatabaseError.unknown("Failed to fetch profile: \(error.localizedDescription)")
        }
    }

    // MARK: - Recordings

    func saveRecording(_ recording: GripRecording) async throws {
        let dataPointsArray = recording.dataPoints.map { point -> [String: Any] in
            [
                "relativeTime": point.relativeTime,
                "force": point.force
            ]
        }

        let data: [String: Any] = [
            "id": recording.id.uuidString,
            "timestamp": Timestamp(date: recording.timestamp),
            "peakForce": recording.peakForce,
            "averageForce": recording.averageForce,
            "duration": recording.duration,
            "hand": recording.hand.rawValue,
            "dataPoints": dataPointsArray
        ]

        do {
            try await db.collection("users")
                .document(recording.userId)
                .collection("recordings")
                .document(recording.id.uuidString)
                .setData(data)
        } catch {
            throw DatabaseError.unknown("Failed to save recording: \(error.localizedDescription)")
        }
    }

    func fetchRecordings(userId: String) async throws -> [GripRecording] {
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("recordings")
                .order(by: "timestamp", descending: true)
                .getDocuments()

            return snapshot.documents.compactMap { document -> GripRecording? in
                let data = document.data()

                guard let idString = data["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
                      let peakForce = data["peakForce"] as? Double,
                      let averageForce = data["averageForce"] as? Double,
                      let duration = data["duration"] as? Double,
                      let handRaw = data["hand"] as? String,
                      let hand = Hand(rawValue: handRaw) else {
                    return nil
                }

                let dataPointsArray = data["dataPoints"] as? [[String: Any]] ?? []
                let dataPoints = dataPointsArray.compactMap { pointData -> ForceDataPoint? in
                    guard let relativeTime = pointData["relativeTime"] as? Double,
                          let force = pointData["force"] as? Double else {
                        return nil
                    }
                    return ForceDataPoint(relativeTime: relativeTime, force: force)
                }

                return GripRecording(
                    id: id,
                    userId: userId,
                    timestamp: timestamp,
                    peakForce: peakForce,
                    averageForce: averageForce,
                    duration: duration,
                    hand: hand,
                    dataPoints: dataPoints,
                    synced: true
                )
            }
        } catch {
            throw DatabaseError.unknown("Failed to fetch recordings: \(error.localizedDescription)")
        }
    }

    func deleteRecording(userId: String, recordingId: String) async throws {
        do {
            try await db.collection("users")
                .document(userId)
                .collection("recordings")
                .document(recordingId)
                .delete()
        } catch {
            throw DatabaseError.unknown("Failed to delete recording: \(error.localizedDescription)")
        }
    }

    func updateEmail(userId: String, email: String) async throws {
        guard !userId.isEmpty else { return }
        do {
            try await db.collection("users").document(userId).updateData(["email": email])
        } catch {
            throw DatabaseError.unknown("Failed to update email: \(error.localizedDescription)")
        }
    }

    func updateDisplayName(userId: String, name: String) async throws {
        guard !userId.isEmpty else { return }
        do {
            try await db.collection("users").document(userId).updateData(["displayName": name])
        } catch {
            throw DatabaseError.unknown("Failed to update display name: \(error.localizedDescription)")
        }
    }

    func updateUserPreferences(userId: String, unit: ForceUnit, hand: Hand) async throws {
        let data: [String: Any] = [
            "preferredUnit": unit.rawValue,
            "dominantHand": hand.rawValue
        ]

        do {
            try await db.collection("users").document(userId).updateData(data)
        } catch {
            throw DatabaseError.unknown("Failed to update preferences: \(error.localizedDescription)")
        }
    }
}

