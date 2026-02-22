import Foundation

enum BLEParsedMessage {
    case reading(Int)
    case status(DeviceStatus)
    case deviceInfo(version: String)
}

enum DeviceStatus: Equatable {
    case ready
    case notReady
    case pong
    case tared
    case rateConfirmed(ms: Int)
}

struct BLEMessageParser {

    /// Parse a single complete message line (already split on newline, prefix included).
    static func parse(_ message: String) -> BLEParsedMessage? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("R:") {
            return parseReading(trimmed)
        } else if trimmed.hasPrefix("S:") {
            return parseStatus(trimmed)
        } else if trimmed.hasPrefix("D:") {
            return parseDeviceInfo(trimmed)
        }

        print("[BLEParser] Unrecognized message: \(trimmed)")
        return nil
    }

    private static func parseReading(_ message: String) -> BLEParsedMessage? {
        let valueString = String(message.dropFirst(2)) // drop "R:"
        guard let value = Int(valueString) else {
            print("[BLEParser] Invalid reading value: \(valueString)")
            return nil
        }
        return .reading(value)
    }

    private static func parseStatus(_ message: String) -> BLEParsedMessage? {
        let payload = String(message.dropFirst(2)) // drop "S:"

        switch payload {
        case "READY":
            return .status(.ready)
        case "NOT_READY":
            return .status(.notReady)
        case "PONG":
            return .status(.pong)
        case "TARED":
            return .status(.tared)
        default:
            if payload.hasPrefix("RATE:"), let ms = Int(payload.dropFirst(5)) {
                return .status(.rateConfirmed(ms: ms))
            }
            print("[BLEParser] Unknown status: \(payload)")
            return nil
        }
    }

    private static func parseDeviceInfo(_ message: String) -> BLEParsedMessage? {
        guard message.hasPrefix(BLEConstants.firmwareMessagePrefix) else {
            print("[BLEParser] Unexpected device info format: \(message)")
            return nil
        }
        let version = String(message.dropFirst(BLEConstants.firmwareMessagePrefix.count))
        return .deviceInfo(version: version)
    }

    // MARK: - Buffer Processing

    /// Processes a raw byte buffer: appends new data, extracts complete newline-delimited
    /// messages, and returns them. The buffer retains any trailing partial message.
    static func extractMessages(from buffer: inout String, newData: Data) -> [String] {
        guard let chunk = String(data: newData, encoding: .utf8) else { return [] }
        buffer.append(chunk)

        var segments = buffer.split(separator: "\n", omittingEmptySubsequences: false)
        // Last segment is either empty (data ended with \n) or a partial message
        let remainder = String(segments.removeLast())
        buffer = remainder

        return segments.map(String.init).filter { !$0.isEmpty }
    }
}
