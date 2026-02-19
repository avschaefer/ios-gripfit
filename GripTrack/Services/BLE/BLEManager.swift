import Foundation
import CoreBluetooth
import Observation

@Observable
@MainActor
final class BLEManager: NSObject, GripDeviceProtocol {
    var connectionState: ConnectionState = .disconnected
    var discoveredDevices: [DiscoveredDevice] = []
    var currentForce: Double = 0.0
    var isRecording: Bool = false

    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var forceCharacteristic: CBCharacteristic?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var recordedDataPoints: [ForceDataPoint] = []
    private var recordingStartTime: Date?
    private var currentUserId: String = ""
    private var scanTimeoutTimer: Timer?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        guard let central = centralManager, central.state == .poweredOn else {
            connectionState = .error("Bluetooth is not available")
            return
        }

        connectionState = .scanning
        discoveredDevices = []
        discoveredPeripherals = [:]

        central.scanForPeripherals(
            withServices: [BLEConstants.gripServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Auto-stop scanning after timeout
        scanTimeoutTimer = Timer.scheduledTimer(withTimeInterval: BLEConstants.scanTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopScanning()
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

    func connect(to device: DiscoveredDevice) {
        guard let peripheral = discoveredPeripherals[device.id] else { return }
        stopScanning()
        connectionState = .connecting
        connectedPeripheral = peripheral
        centralManager?.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        cleanup()
    }

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

    private func cleanup() {
        connectedPeripheral = nil
        forceCharacteristic = nil
        connectionState = .disconnected
        currentForce = 0.0
        isRecording = false
        recordedDataPoints = []
        recordingStartTime = nil
    }

    private func processForceData(_ data: Data) {
        // Parse force value from BLE data
        // Adjust parsing based on actual device protocol
        guard data.count >= 2 else { return }
        let rawValue = data.withUnsafeBytes { $0.load(as: UInt16.self) }
        let forceKg = Double(rawValue) / 100.0 // Assuming device sends force * 100

        currentForce = forceKg

        if isRecording, let startTime = recordingStartTime {
            let relativeTime = Date().timeIntervalSince(startTime)
            let dataPoint = ForceDataPoint(relativeTime: relativeTime, force: forceKg)
            recordedDataPoints.append(dataPoint)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                break // Ready to scan
            case .poweredOff:
                connectionState = .error("Bluetooth is turned off")
            case .unauthorized:
                connectionState = .error("Bluetooth permission denied")
            case .unsupported:
                connectionState = .error("Bluetooth is not supported on this device")
            default:
                connectionState = .error("Bluetooth is unavailable")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let deviceId = peripheral.identifier
        let deviceName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Device"
        let rssi = RSSI.intValue

        Task { @MainActor in
            discoveredPeripherals[deviceId] = peripheral
            let device = DiscoveredDevice(id: deviceId, name: deviceName, rssi: rssi)

            if !discoveredDevices.contains(where: { $0.id == deviceId }) {
                discoveredDevices.append(device)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            let name = peripheral.name ?? "Device"
            connectionState = .connected(deviceName: name)
            peripheral.delegate = self
            peripheral.discoverServices([BLEConstants.gripServiceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionState = .error(error?.localizedDescription ?? "Failed to connect")
            cleanup()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            cleanup()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([BLEConstants.forceCharacteristicUUID], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == BLEConstants.forceCharacteristicUUID {
                Task { @MainActor in
                    forceCharacteristic = characteristic
                }
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == BLEConstants.forceCharacteristicUUID,
              let data = characteristic.value else { return }
        Task { @MainActor in
            processForceData(data)
        }
    }
}

