# GripFit BLE Integration — Cursor Agent Instructions

## Context

GripFit is a grip strength measurement device. The hardware is a custom PCB with a Seeed XIAO nRF52840 microcontroller and an HX711 load cell amplifier. The firmware is now production-ready and communicates over Bluetooth Low Energy (BLE) using the Nordic UART Service (NUS). Your job is to integrate BLE connectivity into the existing iOS app so the app can discover the device, connect, receive real-time grip strength readings, and send commands.

The app already uses SwiftUI with MVVM architecture, Firebase (Auth/Firestore), and SwiftData. There is likely already a `BLEManager` or similar file in the project, possibly with a `MockBLEManager` for simulator development. You should integrate into the existing architecture — do not create a parallel structure. If no BLE files exist yet, create them following the patterns already established in the codebase.

---

## 1. Firmware Protocol Specification

This is the exact protocol the hardware speaks. Every implementation decision on the iOS side must match this spec.

### 1.1 BLE Service & Characteristics

The device uses the **Nordic UART Service (NUS)**, a standard BLE UART emulation:

| Role | UUID | iOS Operation |
|---|---|---|
| **NUS Service** | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` | Scan filter / service discovery |
| **TX Characteristic** | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` | Subscribe to **notifications** (device → phone) |
| **RX Characteristic** | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` | **Write** data to this (phone → device) |

**Critical:** TX and RX are named from the *device's* perspective. The TX characteristic is what the *phone reads from* (via notifications). The RX characteristic is what the *phone writes to*.

### 1.2 Device Advertising

- Device name: `_GRIPFIT`
- The device advertises the NUS Service UUID in its advertising packet
- Advertising restarts automatically after disconnection
- You can discover the device by filtering for either the service UUID or the device name (prefer service UUID as primary filter, name as secondary confirmation)

### 1.3 Messages FROM Device (notifications on TX characteristic)

All messages are UTF-8 encoded, newline-terminated (`\n`). Every message has a prefix tag:

| Prefix | Format | Meaning | Example |
|---|---|---|---|
| `R:` | `R:<integer>\n` | Grip strength reading (raw HX711 value, signed long) | `R:834572\n` |
| `S:` | `S:<status>\n` | Status message | `S:READY\n` |
| `D:` | `D:GRIPFIT,<version>\n` | Device info (sent automatically on connect) | `D:GRIPFIT,1.0\n` |

**Status values the device sends:**

| Message | When |
|---|---|
| `S:READY` | Sensor is operational |
| `S:NOT_READY` | HX711 sensor not responding (hardware issue) |
| `S:PONG` | Response to a PING command |
| `S:TARED` | Tare completed successfully |
| `S:RATE:<ms>` | Sample rate change confirmed (e.g., `S:RATE:50`) |

### 1.4 Commands TO Device (write to RX characteristic)

All commands are UTF-8 encoded, newline-terminated. Write with response (not write-without-response).

| Command | Format | Purpose | Expected Response |
|---|---|---|---|
| Ping | `CMD:PING\n` | Connection health check | `S:PONG\n` |
| Tare | `CMD:TARE\n` | Zero the scale at current load | `S:TARED\n` or `S:NOT_READY\n` |
| Set sample rate | `CMD:RATE:<ms>\n` | Change reading interval (20–1000 ms) | `S:RATE:<ms>\n` |
| Request info | `CMD:INFO\n` | Re-request device info | `D:GRIPFIT,<version>\n` |

### 1.5 Data Flow Timeline

Here is exactly what happens during a typical session:

```
1. App starts scanning for NUS service UUID
2. Device found → app initiates connection
3. Connected → app discovers services → discovers TX and RX characteristics
4. App subscribes to notifications on TX characteristic
5. Device automatically sends: D:GRIPFIT,1.0\n
6. Device begins streaming: R:123456\n  R:123789\n  R:124001\n ... (every 100ms)
7. App sends CMD:TARE\n → device responds S:TARED\n → subsequent readings are zeroed
8. Readings continue until disconnect
9. On disconnect → device restarts advertising → app can reconnect
```

### 1.6 Reading Interpretation

- Raw readings are signed integers from the HX711 24-bit ADC
- After a tare command, readings represent force relative to the tare point
- Positive values = compression (squeezing)
- The conversion from raw value to kilograms/pounds will be handled in the app's calibration layer, NOT in firmware
- Expect values roughly in the range of -8,388,608 to 8,388,607 (24-bit signed), though typical grip readings will be a much narrower band
- A reading of exactly 0 after tare means no force applied
- `S:NOT_READY` means the HX711 hardware is not responding — this is an error state, not a zero reading

---

## 2. iOS Implementation Requirements

### 2.1 Protocol-Based Abstraction

The app must support two execution modes:
- **Simulator**: Uses a mock BLE manager that generates fake data (no actual Bluetooth)
- **Physical device**: Uses real CoreBluetooth

Define a **protocol** (e.g., `BLEManagerProtocol` or `GripDeviceProtocol` — use whatever naming convention the codebase already follows) that both the real and mock implementations conform to. This protocol should expose:

```
- Connection state (disconnected, scanning, connecting, connected, error)
- A stream/publisher of grip readings (the parsed numeric value)
- Device info (firmware version, once received)
- Methods: startScanning(), stopScanning(), connect(to:), disconnect()
- Methods: sendTare(), sendPing(), setSampleRate(ms:)
- Sensor readiness state
```

Use `@Published` properties, Combine publishers, or async streams — whatever pattern the existing codebase uses for reactive state. Do not introduce a new reactive pattern if one is already established.

### 2.2 Real BLE Manager Implementation

This is the CoreBluetooth implementation. Key requirements:

**Scanning:**
- Use `CBCentralManager` to scan for peripherals advertising the NUS service UUID
- Filter discovered peripherals: primary filter is service UUID, secondary confirmation is device name containing `_GRIPFIT`
- Expose discovered peripherals so the UI can present them (even though there will typically be only one device)
- Stop scanning after connection is established

**Connecting:**
- On connection, discover the NUS service, then discover its characteristics
- Identify the TX characteristic (UUID `6E400003-...`) and subscribe to notifications
- Identify the RX characteristic (UUID `6E400002-...`) and store a reference for writing commands
- The RX characteristic supports `.write` (with response) — verify this from the characteristic's properties

**Receiving data:**
- Data arrives in `didUpdateValueFor characteristic` as `Data` bytes
- BLE can fragment messages across multiple packets — you MUST buffer incoming bytes and split on `\n` to extract complete messages
- A single `didUpdateValueFor` callback may contain a partial message, a full message, or multiple messages
- Parse each complete line according to the prefix tag (R:, S:, D:)

**Data buffering pseudocode:**
```
class has: var incomingBuffer: String = ""

on didUpdateValueFor:
    append new bytes (as UTF-8 string) to incomingBuffer
    split incomingBuffer on "\n"
    all segments except the last are complete messages → process them
    the last segment is either empty (if data ended with \n) or a partial message → keep it in buffer
```

**Sending commands:**
- Write UTF-8 encoded command bytes to the RX characteristic
- Always append `\n` to commands
- Use `.withResponse` write type
- Example: to tare, write `Data("CMD:TARE\n".utf8)` to the RX characteristic

**Disconnection & reconnection:**
- Detect disconnection via `didDisconnectPeripheral`
- Implement automatic reconnection with backoff (e.g., try reconnecting after 1s, 2s, 4s, up to 30s max)
- Clear the incoming buffer on disconnect
- Reset connection state so the UI reflects the disconnection

**Background considerations:**
- CoreBluetooth can run in the background if the app declares `bluetooth-central` in `UIBackgroundModes` (Info.plist)
- For now, this is NOT required — the app only needs BLE while foregrounded
- Do NOT add background mode unless it already exists in the project

### 2.3 Mock BLE Manager Implementation

For simulator and SwiftUI previews:

- Conform to the same protocol as the real BLE manager
- Simulate connection with a short delay (e.g., 0.5s)
- After "connecting", start a Timer that fires every 100ms and publishes fake readings
- Fake readings should simulate a realistic squeeze curve: start near 0, ramp up over ~1 second to a peak value, hold briefly, then ramp back down
- Respond to tare/ping commands immediately with appropriate status changes
- Use `#if targetEnvironment(simulator)` or dependency injection to swap implementations — follow whatever pattern exists in the codebase

### 2.4 Data Parsing Layer

Create a parser (e.g., `GripDataParser` or `BLEMessageParser`) that is **separate from the BLE manager**. Both the real and mock managers should feed raw message strings into this parser. The parser:

- Accepts a complete message string (already split on `\n`, tag prefix included)
- Parses the prefix tag and routes accordingly:
  - `R:` → extract the integer value, publish as a grip reading
  - `S:` → update device status (ready, not ready, tare confirmed, etc.)
  - `D:` → extract firmware version, store in device info
- Handles malformed messages gracefully (log a warning, do not crash)
- Is fully unit-testable with no BLE dependency

### 2.5 Required UUID Constants

Define these once, centrally, and reference them everywhere:

```swift
import CoreBluetooth

enum GripFitBLEConstants {
    static let nusServiceUUID        = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let nusTXCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // device → phone (notify)
    static let nusRXCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // phone → device (write)
    static let deviceNamePrefix      = "_GRIPFIT"
    static let firmwareMessagePrefix = "D:GRIPFIT,"
}
```

---

## 3. Integration Points with Existing App

### 3.1 Where BLE State Fits in the Architecture

- The BLE manager should be a **singleton or environment object** — there is only one Bluetooth connection at a time
- Inject it at the app root level so any view can access connection state and readings
- If the app uses a dependency injection container or an `@EnvironmentObject` pattern, register the BLE manager there
- Connection state should be accessible from:
  - Any view that displays device status (connected/disconnected indicator)
  - The measurement/workout view that displays real-time readings
  - Settings or device management views

### 3.2 Where Readings Fit in the Data Flow

The data flow should be:

```
BLE Notification → BLEManager (buffer + split) → Parser (tag routing) → Published Reading Value → ViewModel → View
```

- The BLE manager's job ends at "here is a complete message string"
- The parser's job ends at "here is a typed, validated reading or status update"
- The ViewModel transforms readings for display (e.g., applying calibration, computing max, tracking squeeze duration)
- The View renders the current state

Do NOT put parsing logic in the BLE manager. Do NOT put BLE logic in the ViewModel. Keep each layer focused.

### 3.3 Calibration (Future — Do Not Implement Yet)

The firmware sends raw ADC values. Converting these to kg/lbs requires a calibration factor that will be determined per-device. For now:
- Store and display raw values
- The calibration layer will sit between the parser output and the ViewModel input
- Design the data flow so a calibration transform can be inserted later without restructuring

### 3.4 Firebase / SwiftData Interaction

- BLE readings during a session should be held in memory (an array in the ViewModel)
- When a grip test session is complete, the session summary (max force, average force, duration, timestamp) should be saved to the existing data persistence layer (SwiftData or Firestore — use whichever the app already uses for user data)
- Do NOT stream individual readings to Firebase/SwiftData in real time — that is too much write volume
- The BLE layer should have zero knowledge of Firebase or SwiftData

---

## 4. Error Handling Requirements

### 4.1 Bluetooth Permission & Availability

Before scanning, check `CBCentralManager.state`:
- `.poweredOff` → prompt user to enable Bluetooth
- `.unauthorized` → prompt user to grant Bluetooth permission in Settings
- `.unsupported` → display error (this shouldn't happen on any modern iPhone)
- `.poweredOn` → proceed with scanning

The app needs the following Info.plist entries (add if not already present):
- `NSBluetoothAlwaysUsageDescription` — e.g., "GripFit needs Bluetooth to connect to your grip strength device."
- `NSBluetoothPeripheralUsageDescription` — same description (for older iOS compatibility)

### 4.2 Connection Failures

- Scan timeout: if no device found within 10 seconds, stop scanning and show a user-facing message
- Connection timeout: if connection not established within 5 seconds, cancel and show error
- Service/characteristic discovery failure: if NUS service or expected characteristics not found, disconnect and show a "device not recognized" error
- All errors should surface to the UI through the connection state enum, NOT through thrown exceptions that the UI has to catch

### 4.3 Data Errors

- If a `R:` message contains a non-numeric value, log it and skip (do not crash or show error to user)
- If `S:NOT_READY` is received, surface this to the UI as a device hardware issue — the user may need to check the device
- If no readings received for 2+ seconds while connected, the connection may be stale — consider sending a `CMD:PING` and waiting for `S:PONG`

---

## 5. Testing Strategy

### 5.1 Unit Tests

The following should be unit-testable without any Bluetooth hardware:

- **Message parser**: feed it raw strings like `"R:123456"`, `"S:TARED"`, `"D:GRIPFIT,1.0"`, `"garbage"` and verify correct output
- **Buffer logic**: feed it fragmented data like `"R:123"` then `"456\nR:789\n"` and verify it correctly extracts `["R:123456", "R:789"]`
- **Command formatting**: verify tare command produces `Data("CMD:TARE\n".utf8)`, etc.

### 5.2 Simulator Testing

- The mock BLE manager should allow full UI development and testing without hardware
- Mock should cycle through connection states (scanning → connecting → connected) with realistic delays
- Mock should generate readings that look like a real squeeze pattern, not just random numbers

### 5.3 Device Testing

- Build to a physical iPhone with the real BLE manager
- Verify: scanning discovers the device, connection succeeds, readings stream in real time, tare command works, disconnect/reconnect works
- Test with device at various distances to verify Bluetooth range

---

## 6. Files You Will Likely Create or Modify

This is a guide — adapt based on what already exists in the project:

**New files (if they don't exist):**
- `GripFitBLEConstants.swift` — UUID constants and protocol message definitions
- `BLEManagerProtocol.swift` — the protocol defining the BLE interface
- `BLEManager.swift` — real CoreBluetooth implementation
- `MockBLEManager.swift` — simulator mock implementation
- `BLEMessageParser.swift` — message parsing logic

**Files you will likely modify:**
- App entry point — to inject the BLE manager as an environment object
- Info.plist — to add Bluetooth usage description strings
- Any existing ViewModel that will display grip readings — to subscribe to the BLE manager's reading publisher
- Any existing view that shows device status — to bind to connection state

**Do NOT create or modify:**
- The firmware (that is handled separately)
- Firebase configuration
- Authentication flows
- Anything unrelated to BLE connectivity

---

## 7. Implementation Order

Follow this sequence. Each step should compile and run before proceeding to the next.

1. **Constants and protocol** — define UUIDs, message types, and the BLE manager protocol
2. **Message parser** — implement and unit test the parser in isolation
3. **Mock BLE manager** — implement the mock, wire it to a view, verify fake readings display
4. **Real BLE manager** — implement CoreBluetooth scanning, connecting, receiving, sending
5. **Integration** — swap mock for real on physical device builds, verify end-to-end
6. **Error handling** — add permission checks, timeouts, reconnection logic
7. **Polish** — connection status UI indicators, device info display, tare button wiring

---

## 8. Quick Reference

**Device advertises as:** `_GRIPFIT`
**BLE Protocol:** Nordic UART Service (NUS)
**Service UUID:** `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
**Read from (notify):** `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`
**Write to:** `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
**Message format:** UTF-8, newline-terminated, tag-prefixed
**Reading format:** `R:<signed_integer>\n`
**Default sample rate:** 100ms (10 Hz)
**Tare command:** `CMD:TARE\n`
**Ping command:** `CMD:PING\n`