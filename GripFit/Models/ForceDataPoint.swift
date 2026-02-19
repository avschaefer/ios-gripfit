import Foundation

struct ForceDataPoint: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var relativeTime: TimeInterval   // Seconds from recording start
    var force: Double                // Kilograms
}

