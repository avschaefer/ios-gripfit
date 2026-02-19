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

    var maxGripForce: Double {
        recordings.map(\.peakForce).max() ?? 0
    }

    var averageGripForce: Double {
        guard !recordings.isEmpty else { return 0 }
        return recordings.map(\.peakForce).reduce(0, +) / Double(recordings.count)
    }

    var totalSessions: Int {
        recordings.count
    }

    var hasRecordings: Bool {
        !recordings.isEmpty
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

