import Foundation
import Observation

@Observable
@MainActor
final class MockBLEManager: GripDeviceProtocol {
    var connectionState: ConnectionState = .disconnected
    var discoveredDevices: [DiscoveredDevice] = []
    var currentForce: Double = 0.0
    var isRecording: Bool = false
    var firmwareVersion: String? = nil
    var sensorReady: Bool = true

    private var forceTimer: Timer?
    private var scanTimer: Timer?
    private var recordedDataPoints: [ForceDataPoint] = []
    private var recordingStartTime: Date?
    private var elapsedTime: TimeInterval = 0.0
    private var currentUserId: String = ""

    private var simulationPhase: SimulationPhase = .idle
    private var phaseStartTime: TimeInterval = 0.0
    private var targetPeak: Double = 0.0

    private enum SimulationPhase {
        case idle
        case rampUp
        case hold
        case rampDown
        case rest
    }

    private let mockDevices: [DiscoveredDevice] = [
        DiscoveredDevice(id: UUID(), name: "_GRIPFIT", rssi: -45),
        DiscoveredDevice(id: UUID(), name: "GripPro-A1B2", rssi: -62),
        DiscoveredDevice(id: UUID(), name: "DynaGrip-3C4D", rssi: -78)
    ]

    // MARK: - Scanning

    func startScanning() {
        guard connectionState == .disconnected else { return }
        connectionState = .scanning
        discoveredDevices = []

        scanTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.connectionState == .scanning else { return }
                self.discoveredDevices = self.mockDevices
            }
        }
    }

    func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    // MARK: - Connection

    func connect(to device: DiscoveredDevice) {
        stopScanning()
        connectionState = .connecting

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.connectionState = .connected(deviceName: device.name)
                self.firmwareVersion = "1.0"
                self.sensorReady = true
                self.startForceSimulation()
            }
        }
    }

    func disconnect() {
        stopForceSimulation()
        if isRecording {
            _ = stopRecording()
        }
        connectionState = .disconnected
        discoveredDevices = []
        currentForce = 0.0
        firmwareVersion = nil
        sensorReady = true
    }

    // MARK: - Commands

    func sendTare() {
        guard connectionState.isConnected else { return }
        print("[MockBLE] Tare command sent")
    }

    func sendPing() {
        guard connectionState.isConnected else { return }
        print("[MockBLE] Ping → Pong")
    }

    func setSampleRate(ms: Int) {
        guard connectionState.isConnected else { return }
        print("[MockBLE] Sample rate set to \(ms)ms")
    }

    // MARK: - Recording

    func startRecording() {
        guard connectionState.isConnected else { return }
        isRecording = true
        recordedDataPoints = []
        recordingStartTime = Date()
    }

    func stopRecording() -> GripRecording? {
        guard isRecording, let startTime = recordingStartTime else { return nil }
        isRecording = false

        let duration = Date().timeIntervalSince(startTime)
        let dataPoints = recordedDataPoints

        guard !dataPoints.isEmpty else { return nil }

        let peakForce = dataPoints.map(\.force).max() ?? 0
        let averageForce = dataPoints.map(\.force).reduce(0, +) / Double(dataPoints.count)

        let recording = GripRecording(
            userId: currentUserId,
            timestamp: startTime,
            peakForce: peakForce,
            averageForce: averageForce,
            duration: duration,
            hand: .right,
            dataPoints: dataPoints
        )

        recordedDataPoints = []
        recordingStartTime = nil
        return recording
    }

    func setUserId(_ userId: String) {
        currentUserId = userId
    }

    // MARK: - Force Simulation

    private func startForceSimulation() {
        elapsedTime = 0.0
        simulationPhase = .idle
        targetPeak = Double.random(in: 25...55)
        phaseStartTime = 0.0

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.simulationPhase = .rampUp
                self?.phaseStartTime = self?.elapsedTime ?? 0
            }
        }

        forceTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / BLEConstants.forceUpdateFrequency, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateForce()
            }
        }
    }

    private func stopForceSimulation() {
        forceTimer?.invalidate()
        forceTimer = nil
        simulationPhase = .idle
    }

    private func updateForce() {
        let dt = 1.0 / BLEConstants.forceUpdateFrequency
        elapsedTime += dt
        let phaseElapsed = elapsedTime - phaseStartTime
        let noise = Double.random(in: -0.5...0.5)

        switch simulationPhase {
        case .idle:
            currentForce = max(0, noise * 0.2)

        case .rampUp:
            let rampDuration = 0.5
            let progress = min(phaseElapsed / rampDuration, 1.0)
            currentForce = targetPeak * progress + noise
            if progress >= 1.0 {
                simulationPhase = .hold
                phaseStartTime = elapsedTime
            }

        case .hold:
            let holdDuration = Double.random(in: 2.0...3.0)
            currentForce = targetPeak + noise * 2.0
            if phaseElapsed >= holdDuration {
                simulationPhase = .rampDown
                phaseStartTime = elapsedTime
            }

        case .rampDown:
            let rampDuration = 1.0
            let progress = min(phaseElapsed / rampDuration, 1.0)
            currentForce = targetPeak * (1.0 - progress) + noise
            if progress >= 1.0 {
                simulationPhase = .rest
                phaseStartTime = elapsedTime
            }

        case .rest:
            currentForce = max(0, noise * 0.3)
            let restDuration = Double.random(in: 1.5...3.0)
            if phaseElapsed >= restDuration {
                targetPeak = Double.random(in: 25...55)
                simulationPhase = .rampUp
                phaseStartTime = elapsedTime
            }
        }

        currentForce = max(0, currentForce)

        if isRecording, let startTime = recordingStartTime {
            let relativeTime = Date().timeIntervalSince(startTime)
            let dataPoint = ForceDataPoint(relativeTime: relativeTime, force: currentForce)
            recordedDataPoints.append(dataPoint)
        }
    }
}
