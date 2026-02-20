import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class DashboardViewModel {
    var recordings: [GripRecording] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var showError: Bool = false

    private let databaseService = DatabaseService.shared

    // MARK: - Computed Stats

    var hasRecordings: Bool {
        !recordings.isEmpty
    }

    var totalSessions: Int {
        recordings.count
    }

    var allTimePeak: Double {
        recordings.map(\.peakForce).max() ?? 0
    }

    private var todaysRecordings: [GripRecording] {
        let cal = Calendar.current
        return recordings.filter { cal.isDateInToday($0.timestamp) }
    }

    var todaysBest: Double {
        todaysRecordings.map(\.peakForce).max() ?? 0
    }

    var todaysTestCount: Int {
        todaysRecordings.count
    }

    var todaysBestHand: Hand? {
        guard let best = todaysRecordings.max(by: { $0.peakForce < $1.peakForce }) else { return nil }
        return best.hand
    }

    var threeDayAverage: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let recent = recordings.filter { $0.timestamp >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return recent.map(\.peakForce).reduce(0, +) / Double(recent.count)
    }

    var oneMonthAverage: Double {
        let cutoff = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let recent = recordings.filter { $0.timestamp >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return recent.map(\.peakForce).reduce(0, +) / Double(recent.count)
    }

    var increasePercent: Double? {
        guard allTimePeak > 0 else { return nil }
        let overallAvg = recordings.map(\.peakForce).reduce(0, +) / Double(recordings.count)
        guard overallAvg > 0 else { return nil }
        return ((todaysBest - overallAvg) / overallAvg) * 100
    }

    struct DailyAverage: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let average: Double
    }

    var sevenDayAverages: [DailyAverage] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let shortFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f
        }()

        return (0..<7).reversed().compactMap { offset -> DailyAverage? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let nextDay = cal.date(byAdding: .day, value: 1, to: day)!
            let dayRecordings = recordings.filter { $0.timestamp >= day && $0.timestamp < nextDay }
            let avg = dayRecordings.isEmpty ? 0 : dayRecordings.map(\.peakForce).reduce(0, +) / Double(dayRecordings.count)
            return DailyAverage(date: day, label: shortFormatter.string(from: day), average: avg)
        }
    }

    var recentRecordings: [GripRecording] {
        Array(recordings.sorted { $0.timestamp > $1.timestamp }.prefix(5))
    }

    // MARK: - Data Loading

    func loadRecordings(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            recordings = try await databaseService.fetchRecordings(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func refreshRecordings(userId: String) async {
        do {
            recordings = try await databaseService.fetchRecordings(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func deleteRecording(_ recording: GripRecording) async {
        do {
            try await databaseService.deleteRecording(
                userId: recording.userId,
                recordingId: recording.id.uuidString
            )
            recordings.removeAll { $0.id == recording.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

