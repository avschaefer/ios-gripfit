import CoreBluetooth

enum BLEConstants {
    // Nordic UART Service (NUS) — the protocol the GripFit hardware speaks
    static let nusServiceUUID          = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let nusTXCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // device → phone (notify)
    static let nusRXCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // phone → device (write)

    static let deviceNamePrefix      = "_GRIPFIT"
    static let firmwareMessagePrefix = "D:GRIPFIT,"

    static let scanTimeout: TimeInterval = 10.0
    static let connectionTimeout: TimeInterval = 5.0
    static let forceUpdateFrequency: Double = 20.0

    static let staleConnectionThreshold: TimeInterval = 2.0

    // Reconnection backoff
    static let reconnectInitialDelay: TimeInterval = 1.0
    static let reconnectMaxDelay: TimeInterval = 30.0

    // Commands sent to device (write to RX characteristic)
    enum Command {
        static let ping = "CMD:PING\n"
        static let tare = "CMD:TARE\n"
        static let info = "CMD:INFO\n"

        static func rate(ms: Int) -> String {
            "CMD:RATE:\(ms)\n"
        }
    }
}
