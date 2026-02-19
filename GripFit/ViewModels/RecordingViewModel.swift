import Foundation
import Observation

@Observable
@MainActor
final class RecordingViewModel {
    var recording: GripRecording
    var showDeleteConfirmation: Bool = false
    var isDeleting: Bool = false
    var errorMessage: String?
    var showError: Bool = false
    var didDelete: Bool = false

    private let databaseService = DatabaseService.shared

    init(recording: GripRecording) {
        self.recording = recording
    }

    // MARK: - Formatted Data

    var formattedDate: String {
        DateFormatters.recordingDate.string(from: recording.timestamp)
    }

    var formattedDuration: String {
        DateFormatters.durationString(recording.duration)
    }

    // MARK: - Actions

    func deleteRecording() async {
        isDeleting = true
        errorMessage = nil

        do {
            try await databaseService.deleteRecording(
                userId: recording.userId,
                recordingId: recording.id.uuidString
            )
            didDelete = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isDeleting = false
    }
}

