import Foundation

enum ConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case connected(deviceName: String)
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isScanning: Bool {
        self == .scanning
    }

    var deviceName: String? {
        if case .connected(let name) = self { return name }
        return nil
    }

    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .scanning: return "Scanning..."
        case .connecting: return "Connecting..."
        case .connected(let name): return "Connected to \(name)"
        case .error(let message): return "Error: \(message)"
        }
    }
}

struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int

    var signalStrength: String {
        switch rssi {
        case -50...0: return "Excellent"
        case -70 ..< -50: return "Good"
        case -85 ..< -70: return "Fair"
        default: return "Weak"
        }
    }
}

@MainActor
protocol GripDeviceProtocol: AnyObject {
    var connectionState: ConnectionState { get }
    var discoveredDevices: [DiscoveredDevice] { get }
    var currentForce: Double { get }           // Current force in kg
    var isRecording: Bool { get }

    func startScanning()
    func stopScanning()
    func connect(to device: DiscoveredDevice)
    func disconnect()
    func startRecording()
    func stopRecording() -> GripRecording?
}

