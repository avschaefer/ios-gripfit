import Foundation
import Observation

@Observable
@MainActor
final class DeviceViewModel {
    var connectionState: ConnectionState = .disconnected
    var discoveredDevices: [DiscoveredDevice] = []
    var currentForce: Double = 0.0
    var isRecording: Bool = false
    var selectedHand: Hand = .right
    var recordingDuration: TimeInterval = 0.0
    var lastRecording: GripRecording?
    var showRecordingSaved: Bool = false
    var errorMessage: String?
    var showError: Bool = false

    private let deviceManager: GripDeviceProtocol
    private let databaseService = DatabaseService.shared
    private var userId: String = ""
    private var recordingTimer: Timer?

    init(deviceManager: GripDeviceProtocol) {
        self.deviceManager = deviceManager
    }

    // MARK: - State Sync

    func syncState() {
        connectionState = deviceManager.connectionState
        discoveredDevices = deviceManager.discoveredDevices
        currentForce = deviceManager.currentForce
        isRecording = deviceManager.isRecording
    }

    func setUserId(_ id: String) {
        userId = id
        if let mock = deviceManager as? MockBLEManager {
            mock.setUserId(id)
        } else if let ble = deviceManager as? BLEManager {
            ble.setUserId(id)
        }
    }

    // MARK: - Scanning

    func startScanning() {
        deviceManager.startScanning()
        startStateSync()
    }

    func stopScanning() {
        deviceManager.stopScanning()
        syncState()
    }

    // MARK: - Connection

    func connect(to device: DiscoveredDevice) {
        deviceManager.connect(to: device)
        startStateSync()
    }

    func disconnect() {
        stopRecordingTimer()
        deviceManager.disconnect()
        syncState()
    }

    // MARK: - Recording

    func startRecording() {
        deviceManager.startRecording()
        recordingDuration = 0.0
        startRecordingTimer()
        syncState()
    }

    func stopRecording() async {
        stopRecordingTimer()

        if let recording = deviceManager.stopRecording() {
            // Update hand selection
            let finalRecording = GripRecording(
                id: recording.id,
                userId: userId,
                timestamp: recording.timestamp,
                peakForce: recording.peakForce,
                averageForce: recording.averageForce,
                duration: recording.duration,
                hand: selectedHand,
                dataPoints: recording.dataPoints,
                synced: false
            )

            do {
                try await databaseService.saveRecording(finalRecording)
                finalRecording.synced = true
                lastRecording = finalRecording
            } catch {
                errorMessage = "Failed to save recording: \(error.localizedDescription)"
                showError = true
                lastRecording = finalRecording
            }
        }

        syncState()
    }

    // MARK: - Timers

    private var stateSyncTimer: Timer?

    private func startStateSync() {
        stateSyncTimer?.invalidate()
        stateSyncTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncState()
            }
        }
    }

    func stopStateSync() {
        stateSyncTimer?.invalidate()
        stateSyncTimer = nil
    }

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

