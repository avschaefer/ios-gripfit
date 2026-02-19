import CoreBluetooth

enum BLEConstants {
    // Standard Grip Dynamometer Service UUID
    // Replace with actual device UUIDs when known
    static let gripServiceUUID = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
    static let forceCharacteristicUUID = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")

    // Scanning timeout in seconds
    static let scanTimeout: TimeInterval = 10.0

    // Force data update frequency (Hz)
    static let forceUpdateFrequency: Double = 20.0

    // Connection timeout in seconds
    static let connectionTimeout: TimeInterval = 5.0
}

