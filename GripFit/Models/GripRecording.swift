import SwiftData
import Foundation

@Model
final class GripRecording {
    var id: UUID
    var userId: String
    var timestamp: Date
    var peakForce: Double          // Always stored in kilograms
    var averageForce: Double       // Always stored in kilograms
    var duration: TimeInterval     // Seconds
    var hand: Hand
    var dataPoints: [ForceDataPoint]
    var synced: Bool               // Has been written to Firestore

    init(
        id: UUID = UUID(),
        userId: String,
        timestamp: Date = Date(),
        peakForce: Double,
        averageForce: Double,
        duration: TimeInterval,
        hand: Hand,
        dataPoints: [ForceDataPoint],
        synced: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.timestamp = timestamp
        self.peakForce = peakForce
        self.averageForce = averageForce
        self.duration = duration
        self.hand = hand
        self.dataPoints = dataPoints
        self.synced = synced
    }
}

