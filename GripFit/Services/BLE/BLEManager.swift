import Foundation
import CoreBluetooth
import Observation

@Observable
@MainActor
final class BLEManager: NSObject, GripDeviceProtocol {

    // MARK: - Protocol Properties

    var connectionState: ConnectionState = .disconnected
    var discoveredDevices: [DiscoveredDevice] = []
    var currentForce: Double = 0.0
    var isRecording: Bool = false
    var firmwareVersion: String? = nil
    var sensorReady: Bool = true

    // MARK: - Private State

    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?   // device → phone (notify)
    private var rxCharacteristic: CBCharacteristic?   // phone → device (write)
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]

    private var incomingBuffer: String = ""
    private var lastReadingTime: Date?

    private var currentUserId: String = ""
    private var recordedDataPoints: [ForceDataPoint] = []
    private var recordingStartTime: Date?

    // Timers
    private var scanTimeoutTimer: Timer?
    private var connectionTimeoutTimer: Timer?
    private var staleCheckTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectDelay: TimeInterval = BLEConstants.reconnectInitialDelay
    private var shouldReconnect: Bool = false
    private var lastPeripheralIdentifier: UUID?

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Scanning

    func startScanning() {
        guard let central = centralManager else { return }

        switch central.state {
        case .poweredOn:
            break
        case .poweredOff:
            connectionState = .error("Bluetooth is turned off. Enable it in Settings.")
            return
        case .unauthorized:
            connectionState = .error("Bluetooth permission denied. Grant access in Settings.")
            return
        case .unsupported:
            connectionState = .error("Bluetooth is not supported on this device.")
            return
        default:
            connectionState = .error("Bluetooth is unavailable.")
            return
        }

        connectionState = .scanning
        discoveredDevices = []
        discoveredPeripherals = [:]
        shouldReconnect = false
        cancelReconnect()

        central.scanForPeripherals(
            withServices: [BLEConstants.nusServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = Timer.scheduledTimer(withTimeInterval: BLEConstants.scanTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.connectionState == .scanning else { return }
                self.stopScanning()
                if self.discoveredDevices.isEmpty {
                    self.connectionState = .error("No GripFit device found. Make sure your device is powered on and nearby.")
                }
            }
        }
    }

    func stopScanning() {
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = nil
        centralManager?.stopScan()
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    // MARK: - Connection

    func connect(to device: DiscoveredDevice) {
        guard let peripheral = discoveredPeripherals[device.id] else { return }

        stopScanning()
        connectionState = .connecting
        connectedPeripheral = peripheral
        lastPeripheralIdentifier = peripheral.identifier
        shouldReconnect = true

        centralManager?.connect(peripheral, options: nil)

        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: BLEConstants.connectionTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.connectionState == .connecting else { return }
                self.centralManager?.cancelPeripheralConnection(peripheral)
                self.connectionState = .error("Connection timed out. Try again.")
                self.cleanup(attemptReconnect: false)
            }
        }
    }

    func disconnect() {
        shouldReconnect = false
        cancelReconnect()
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        cleanup(attemptReconnect: false)
    }

    // MARK: - Commands

    func sendTare() {
        sendCommand(BLEConstants.Command.tare)
    }

    func sendPing() {
        sendCommand(BLEConstants.Command.ping)
    }

    func setSampleRate(ms: Int) {
        let clamped = max(20, min(1000, ms))
        sendCommand(BLEConstants.Command.rate(ms: clamped))
    }

    private func sendCommand(_ command: String) {
        guard let rx = rxCharacteristic, let peripheral = connectedPeripheral else {
            print("[BLE] Cannot send command — not connected or RX characteristic not found")
            return
        }
        let data = Data(command.utf8)
        peripheral.writeValue(data, for: rx, type: .withResponse)
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

    // MARK: - Message Handling

    private func handleIncomingData(_ data: Data) {
        let messages = BLEMessageParser.extractMessages(from: &incomingBuffer, newData: data)

        for raw in messages {
            guard let parsed = BLEMessageParser.parse(raw) else { continue }

            switch parsed {
            case .reading(let rawValue):
                lastReadingTime = Date()
                currentForce = max(0, Double(rawValue) / 100_000.0)

                if isRecording, let startTime = recordingStartTime {
                    let relativeTime = Date().timeIntervalSince(startTime)
                    let dataPoint = ForceDataPoint(relativeTime: relativeTime, force: currentForce)
                    recordedDataPoints.append(dataPoint)
                }

            case .status(let status):
                handleStatus(status)

            case .deviceInfo(let version):
                firmwareVersion = version
            }
        }
    }

    private func handleStatus(_ status: DeviceStatus) {
        switch status {
        case .ready:
            sensorReady = true
        case .notReady:
            sensorReady = false
        case .pong:
            break
        case .tared:
            break
        case .rateConfirmed:
            break
        }
    }

    // MARK: - Stale Connection Check

    private func startStaleConnectionCheck() {
        staleCheckTimer?.invalidate()
        staleCheckTimer = Timer.scheduledTimer(withTimeInterval: BLEConstants.staleConnectionThreshold, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.connectionState.isConnected else { return }
                if let lastReading = self.lastReadingTime,
                   Date().timeIntervalSince(lastReading) > BLEConstants.staleConnectionThreshold {
                    self.sendPing()
                }
            }
        }
    }

    private func stopStaleConnectionCheck() {
        staleCheckTimer?.invalidate()
        staleCheckTimer = nil
    }

    // MARK: - Reconnection

    private func attemptReconnect() {
        guard shouldReconnect, let central = centralManager, central.state == .poweredOn else { return }

        if let identifier = lastPeripheralIdentifier {
            let known = central.retrievePeripherals(withIdentifiers: [identifier])
            if let peripheral = known.first {
                connectionState = .connecting
                connectedPeripheral = peripheral
                central.connect(peripheral, options: nil)
                scheduleNextReconnect()
                return
            }
        }

        startScanning()
    }

    private func scheduleNextReconnect() {
        cancelReconnect()
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, BLEConstants.reconnectMaxDelay)

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.connectionState.isConnected else { return }
                self.attemptReconnect()
            }
        }
    }

    private func cancelReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectDelay = BLEConstants.reconnectInitialDelay
    }

    // MARK: - Cleanup

    private func cleanup(attemptReconnect: Bool) {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        stopStaleConnectionCheck()

        connectedPeripheral = nil
        txCharacteristic = nil
        rxCharacteristic = nil
        incomingBuffer = ""
        lastReadingTime = nil
        connectionState = .disconnected
        currentForce = 0.0
        sensorReady = true
        isRecording = false
        recordedDataPoints = []
        recordingStartTime = nil

        if attemptReconnect && shouldReconnect {
            scheduleNextReconnect()
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                break
            case .poweredOff:
                connectionState = .error("Bluetooth is turned off")
            case .unauthorized:
                connectionState = .error("Bluetooth permission denied")
            case .unsupported:
                connectionState = .error("Bluetooth is not supported")
            default:
                connectionState = .error("Bluetooth is unavailable")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let deviceId = peripheral.identifier
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let deviceName = peripheral.name ?? advertisedName ?? "Unknown Device"

        Task { @MainActor in
            discoveredPeripherals[deviceId] = peripheral

            if !discoveredDevices.contains(where: { $0.id == deviceId }) {
                discoveredDevices.append(
                    DiscoveredDevice(id: deviceId, name: deviceName, rssi: RSSI.intValue)
                )
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectionTimeoutTimer?.invalidate()
            connectionTimeoutTimer = nil
            cancelReconnect()

            let name = peripheral.name ?? "GripFit"
            connectionState = .connected(deviceName: name)
            peripheral.delegate = self
            peripheral.discoverServices([BLEConstants.nusServiceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionState = .error(error?.localizedDescription ?? "Failed to connect")
            cleanup(attemptReconnect: true)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            cleanup(attemptReconnect: true)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            Task { @MainActor in
                connectionState = .error("Failed to discover services")
                disconnect()
            }
            return
        }

        for service in services where service.uuid == BLEConstants.nusServiceUUID {
            peripheral.discoverCharacteristics(
                [BLEConstants.nusTXCharacteristicUUID, BLEConstants.nusRXCharacteristicUUID],
                for: service
            )
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else {
            Task { @MainActor in
                connectionState = .error("Device not recognized — expected characteristics not found")
                disconnect()
            }
            return
        }

        Task { @MainActor in
            var foundTX = false
            var foundRX = false

            for characteristic in characteristics {
                if characteristic.uuid == BLEConstants.nusTXCharacteristicUUID {
                    txCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    foundTX = true
                } else if characteristic.uuid == BLEConstants.nusRXCharacteristicUUID {
                    rxCharacteristic = characteristic
                    foundRX = true
                }
            }

            if !foundTX || !foundRX {
                connectionState = .error("Device not recognized — missing NUS characteristics")
                disconnect()
                return
            }

            startStaleConnectionCheck()
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == BLEConstants.nusTXCharacteristicUUID,
              let data = characteristic.value else { return }

        Task { @MainActor in
            handleIncomingData(data)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            print("[BLE] Write error: \(error.localizedDescription)")
        }
    }
}
