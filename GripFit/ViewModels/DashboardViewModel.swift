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
    var chartTimeRange: ChartTimeRange = .oneWeek
    var handFilter: Hand? = nil

    private let databaseService = DatabaseService.shared

    // MARK: - Filtered Data

    var filteredRecordings: [GripRecording] {
        guard let hand = handFilter else { return recordings }
        return recordings.filter { $0.hand == hand }
    }

    // MARK: - Computed Stats

    var hasRecordings: Bool {
        !recordings.isEmpty
    }

    var totalSessions: Int {
        filteredRecordings.count
    }

    var allTimePeak: Double {
        filteredRecordings.map(\.peakForce).max() ?? 0
    }

    private var todaysRecordings: [GripRecording] {
        let cal = Calendar.current
        return filteredRecordings.filter { cal.isDateInToday($0.timestamp) }
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
        let recent = filteredRecordings.filter { $0.timestamp >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return recent.map(\.peakForce).reduce(0, +) / Double(recent.count)
    }

    var oneMonthAverage: Double {
        let cutoff = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let recent = filteredRecordings.filter { $0.timestamp >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return recent.map(\.peakForce).reduce(0, +) / Double(recent.count)
    }

    var changePercent: Double? {
        guard allTimePeak > 0 else { return nil }
        let recs = filteredRecordings
        guard !recs.isEmpty else { return nil }
        let overallAvg = recs.map(\.peakForce).reduce(0, +) / Double(recs.count)
        guard overallAvg > 0 else { return nil }
        return ((todaysBest - overallAvg) / overallAvg) * 100
    }

    // MARK: - Strength Balance

    var leftBestAverage: Double {
        let leftRecs = recordings.filter { $0.hand == .left }
        guard !leftRecs.isEmpty else { return 0 }
        return leftRecs.map(\.peakForce).reduce(0, +) / Double(leftRecs.count)
    }

    var rightBestAverage: Double {
        let rightRecs = recordings.filter { $0.hand == .right }
        guard !rightRecs.isEmpty else { return 0 }
        return rightRecs.map(\.peakForce).reduce(0, +) / Double(rightRecs.count)
    }

    var balanceDifferencePercent: Int {
        let total = leftBestAverage + rightBestAverage
        guard total > 0 else { return 0 }
        return Int(abs(leftBestAverage - rightBestAverage) / max(leftBestAverage, rightBestAverage) * 100)
    }

    var balanceRatio: Double {
        let total = leftBestAverage + rightBestAverage
        guard total > 0 else { return 0.5 }
        return leftBestAverage / total
    }

    // MARK: - Streak

    struct WeekdayActivity {
        let label: String
        let hasSession: Bool
    }

    var weekStreak: [WeekdayActivity] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let mondayOffset = (weekday + 5) % 7

        guard let monday = cal.date(byAdding: .day, value: -mondayOffset, to: today) else { return [] }

        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        return (0..<7).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: monday)!
            let nextDay = cal.date(byAdding: .day, value: 1, to: day)!
            let hasSession = recordings.contains { $0.timestamp >= day && $0.timestamp < nextDay }
            return WeekdayActivity(label: labels[offset], hasSession: hasSession)
        }
    }

    var streakDaysCount: Int {
        weekStreak.filter(\.hasSession).count
    }

    // MARK: - Readiness Score

    var readinessScore: Int {
        let timeframeRaw = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.readinessTimeframe) ?? ReadinessTimeframe.oneWeek.rawValue
        let timeframe = ReadinessTimeframe(rawValue: timeframeRaw) ?? .oneWeek
        return computeReadiness(timeframe: timeframe)
    }

    private func computeReadiness(timeframe: ReadinessTimeframe) -> Int {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -timeframe.days, to: Date()) else { return 0 }
        let recentRecs = recordings.filter { $0.timestamp >= cutoff }
        guard !recentRecs.isEmpty else { return 0 }

        let recentAvg = recentRecs.map(\.peakForce).reduce(0, +) / Double(recentRecs.count)
        guard allTimePeak > 0 else { return 0 }

        // Consistency: how many of the last N days had at least one session
        let totalDays = timeframe.days
        var daysWithSessions = 0
        let today = cal.startOfDay(for: Date())
        for offset in 0..<totalDays {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let nextDay = cal.date(byAdding: .day, value: 1, to: day)!
            if recentRecs.contains(where: { $0.timestamp >= day && $0.timestamp < nextDay }) {
                daysWithSessions += 1
            }
        }
        let consistencyRatio = Double(daysWithSessions) / Double(totalDays)

        // Performance: recent average vs all-time peak
        let performanceRatio = min(recentAvg / allTimePeak, 1.0)

        // Trend: is today better than the period average?
        let trendBonus: Double = todaysBest > recentAvg ? 0.1 : 0.0

        let raw = (performanceRatio * 0.5 + consistencyRatio * 0.4 + trendBonus) * 100
        return max(0, min(100, Int(raw)))
    }

    // MARK: - Chart Data

    struct DailyAverage: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let average: Double
    }

    var chartAverages: [DailyAverage] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let recs = filteredRecordings

        let totalDays: Int
        if let rangeDays = chartTimeRange.days {
            totalDays = rangeDays
        } else {
            guard let oldest = recs.min(by: { $0.timestamp < $1.timestamp }) else { return [] }
            totalDays = max((cal.dateComponents([.day], from: cal.startOfDay(for: oldest.timestamp), to: today).day ?? 0) + 1, 1)
        }

        let bucketSize: Int
        switch totalDays {
        case ...14: bucketSize = 1
        case 15...45: bucketSize = 7
        case 46...120: bucketSize = 14
        default: bucketSize = 30
        }
        let bucketCount = max(1, (totalDays + bucketSize - 1) / bucketSize)

        let shortFormatter = DateFormatter()
        switch bucketSize {
        case 1: shortFormatter.dateFormat = "EEE"
        case 7: shortFormatter.dateFormat = "MMM d"
        case 14: shortFormatter.dateFormat = "M/d"
        default: shortFormatter.dateFormat = "MMM"
        }

        return (0..<bucketCount).reversed().compactMap { bucketIdx -> DailyAverage? in
            let endOffset = bucketIdx * bucketSize
            let startOffset = endOffset + bucketSize
            guard let bucketStart = cal.date(byAdding: .day, value: -startOffset, to: today),
                  let bucketEnd = cal.date(byAdding: .day, value: -endOffset, to: today) else { return nil }
            let nextDay = cal.date(byAdding: .day, value: 1, to: bucketEnd)!

            let bucketRecordings = recs.filter { $0.timestamp >= bucketStart && $0.timestamp < nextDay }
            let avg = bucketRecordings.isEmpty ? 0 : bucketRecordings.map(\.peakForce).reduce(0, +) / Double(bucketRecordings.count)
            return DailyAverage(date: bucketEnd, label: shortFormatter.string(from: bucketEnd), average: avg)
        }
    }

    var recentRecordings: [GripRecording] {
        Array(filteredRecordings.sorted { $0.timestamp > $1.timestamp }.prefix(5))
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

