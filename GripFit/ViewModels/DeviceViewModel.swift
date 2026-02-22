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

    var firmwareVersion: String?
    var sensorReady: Bool = true

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
        firmwareVersion = deviceManager.firmwareVersion
        sensorReady = deviceManager.sensorReady
    }

    func setUserId(_ id: String) {
        userId = id
        deviceManager.setUserId(id)
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
        stopStateSync()
        deviceManager.disconnect()
        syncState()
    }

    // MARK: - Commands

    func sendTare() {
        deviceManager.sendTare()
    }

    func sendPing() {
        deviceManager.sendPing()
    }

    func setSampleRate(ms: Int) {
        deviceManager.setSampleRate(ms: ms)
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

    func resumeStateSyncIfNeeded() {
        guard stateSyncTimer == nil,
              connectionState.isConnected || connectionState.isScanning || connectionState == .connecting
        else { return }
        startStateSync()
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
