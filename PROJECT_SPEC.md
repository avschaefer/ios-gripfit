# GripTrack — iOS Project Spec for Cursor Implementation

> **Purpose:** This document is the single source of truth for Cursor AI to implement the GripTrack iOS app. Reference this file in every Cursor agent session. Place it at the project root as `PROJECT_SPEC.md` and reference it from your `.cursor/rules/` files.

---

## 1. Product Definition

**GripTrack** is an iOS app that connects to a Bluetooth Low Energy (BLE) grip strength dynamometer, displays real-time force data, records grip sessions, and persists all data to a user account.

### MVP Scope — What to Build

- **User authentication** — email/password registration, login, logout, password reset
- **Main dashboard** — list of recent recordings, summary stats (max grip, average, trend over time)
- **Recording detail view** — tap a recording to see the force-time curve and metadata
- **Device connection screen** — scan for BLE devices, connect, show connection status
- **Live reading screen** — real-time force display during a grip test, record button
- **Settings screen** — profile info, unit preference (kg/lbs), dominant hand, sign out
- **Persistent storage** — all recordings tied to user account, synced to cloud database
- **Mock BLE mode** — simulated data source so the entire app works in the iOS simulator

### MVP Scope — What NOT to Build

- Social features, sharing, leaderboards
- Apple Watch companion
- Multiple device pairing
- Export to CSV/PDF
- Push notifications
- In-app purchases
- Onboarding tutorial screens
- Dark mode toggle (just support system setting)

---

## 2. Tech Stack (Locked Decisions)

| Layer | Choice | Notes |
|---|---|---|
| Language | **Swift 5.9+** | Minimum deployment target iOS 17.0 |
| UI | **SwiftUI** | No UIKit unless absolutely necessary |
| Architecture | **MVVM** | ViewModels are `@Observable` classes (Observation framework, not ObservableObject) |
| Navigation | **NavigationStack** + **TabView** | No NavigationView (deprecated) |
| BLE | **CoreBluetooth** | Wrapped behind a protocol for mock injection |
| Auth | **Firebase Authentication** | Email/password to start |
| Cloud Database | **Cloud Firestore** | One collection per data type |
| Local Persistence | **SwiftData** | On-device cache, offline support |
| Package Manager | **Swift Package Manager** | No CocoaPods, no Carthage |
| Min iOS | **17.0** | Enables @Observable, SwiftData, modern NavigationStack |

### SPM Dependencies

```
firebase-ios-sdk          — Auth + Firestore
(optional) IOS-CoreBluetooth-Mock — Nordic's BLE mock library for simulator/testing
swift-charts              — (built-in with iOS 17, no external package needed)
```

---

## 3. Project Structure

Create this exact folder and file structure. Every file listed below must exist. Files marked `[stub]` should be created with minimal placeholder code that compiles.

```
GripTrack/
├── GripTrackApp.swift                    # @main App entry point
├── ContentView.swift                     # Root view: auth gate → TabView
│
├── Models/
│   ├── GripRecording.swift               # SwiftData @Model
│   ├── ForceDataPoint.swift              # Struct: timestamp + force value
│   ├── UserProfile.swift                 # Local user profile model
│   └── Hand.swift                        # Enum: .left, .right
│
├── ViewModels/
│   ├── AuthViewModel.swift               # Login, register, logout, auth state listener
│   ├── DashboardViewModel.swift          # Fetch recordings, compute stats
│   ├── RecordingViewModel.swift          # Detail view logic for one recording
│   ├── DeviceViewModel.swift             # BLE scanning, connection, live data
│   └── SettingsViewModel.swift           # User prefs, profile updates
│
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift           # Main tab: recording list + stats summary
│   │   ├── RecordingRowView.swift        # Single row in recording list
│   │   └── RecordingDetailView.swift     # Full detail with chart
│   ├── Device/
│   │   ├── DeviceConnectionView.swift    # Scan + connect UI
│   │   └── LiveReadingView.swift         # Real-time force gauge + record button
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Components/
│       ├── ForceChartView.swift          # Swift Charts force-time graph
│       ├── StatCardView.swift            # Reusable stat display card
│       └── ConnectionStatusBadge.swift   # BLE status indicator
│
├── Services/
│   ├── BLE/
│   │   ├── GripDeviceProtocol.swift      # Protocol defining BLE interface
│   │   ├── BLEManager.swift              # Real CoreBluetooth implementation
│   │   ├── MockBLEManager.swift          # Simulated data for simulator
│   │   └── BLEConstants.swift            # Service/Characteristic UUIDs
│   ├── AuthService.swift                 # Firebase Auth wrapper
│   └── DatabaseService.swift             # Firestore CRUD operations
│
├── Utilities/
│   ├── Constants.swift                   # App-wide constants
│   ├── ForceUnit.swift                   # Enum: .kilograms, .pounds + conversion
│   └── DateFormatters.swift              # Shared date formatting
│
├── Resources/
│   └── Assets.xcassets                   # App icon, colors, images
│
└── Info.plist                            # BLE usage description, background modes
```

---

## 4. Data Models — Exact Definitions

### GripRecording (SwiftData @Model + Firestore document)

```swift
import SwiftData
import Foundation

@Model
final class GripRecording {
    var id: UUID
    var userId: String
    var timestamp: Date
    var peakForce: Double          // Always stored in kilograms
    var averageForce: Double       // Always stored in kilograms
    var duration: TimeInterval     // Seconds
    var hand: Hand
    var dataPoints: [ForceDataPoint]
    var synced: Bool               // Has been written to Firestore

    init(
        id: UUID = UUID(),
        userId: String,
        timestamp: Date = Date(),
        peakForce: Double,
        averageForce: Double,
        duration: TimeInterval,
        hand: Hand,
        dataPoints: [ForceDataPoint],
        synced: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.timestamp = timestamp
        self.peakForce = peakForce
        self.averageForce = averageForce
        self.duration = duration
        self.hand = hand
        self.dataPoints = dataPoints
        self.synced = synced
    }
}
```

### ForceDataPoint

```swift
import Foundation

struct ForceDataPoint: Codable, Identifiable {
    var id: UUID = UUID()
    var relativeTime: TimeInterval   // Seconds from recording start
    var force: Double                // Kilograms
}
```

### Hand Enum

```swift
enum Hand: String, Codable, CaseIterable {
    case left
    case right
}
```

### ForceUnit Enum

```swift
enum ForceUnit: String, CaseIterable {
    case kilograms
    case pounds

    var abbreviation: String {
        switch self {
        case .kilograms: return "kg"
        case .pounds: return "lbs"
        }
    }

    func convert(_ kg: Double) -> Double {
        switch self {
        case .kilograms: return kg
        case .pounds: return kg * 2.20462
        }
    }
}
```

---

## 5. BLE Architecture — Protocol Abstraction

This is the most critical architectural decision. The BLE layer MUST be behind a protocol so that MockBLEManager can power the entire app in the simulator.

### GripDeviceProtocol.swift

```swift
import Foundation
import Combine

enum ConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case connected(deviceName: String)
    case error(String)
}

struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int
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
```

### MockBLEManager.swift — Behavior Spec

The mock must simulate realistic behavior:
- `startScanning()` → after 1-2 second delay, populate `discoveredDevices` with 2-3 fake devices (e.g., "GripPro-A1B2", "DynaGrip-3C4D")
- `connect(to:)` → after 0.5s delay, set state to `.connected`
- When connected, `currentForce` should update at ~20Hz with a simulated grip curve:
  - Ramp up over 0.5s to a random peak (20-60 kg)
  - Hold near peak with small noise for 2-3s
  - Ramp down over 1s
  - Return to ~0 with small noise
- `startRecording()` → begin capturing data points
- `stopRecording()` → return a `GripRecording` with captured data points
- `disconnect()` → reset state

---

## 6. Navigation Flow

```
App Launch
  └── ContentView checks AuthViewModel.isAuthenticated
        ├── false → LoginView
        │             └── "Create Account" link → RegisterView
        └── true → MainTabView
                     ├── Tab 1: DashboardView (house icon, "Dashboard")
                     │            └── tap row → RecordingDetailView (pushed)
                     ├── Tab 2: DeviceConnectionView (sensor icon, "Device")
                     │            └── connected → LiveReadingView (pushed)
                     └── Tab 3: SettingsView (gear icon, "Settings")
```

### ContentView.swift — Auth Gate Pattern

```swift
struct ContentView: View {
    @State private var authVM = AuthViewModel()

    var body: some View {
        Group {
            if authVM.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environment(authVM)
    }
}
```

---

## 7. Screen-by-Screen Specifications

### 7.1 LoginView

- Email text field (keyboard type: `.emailAddress`, autocapitalization: `.never`)
- Password secure field
- "Sign In" button (disabled while fields empty or loading)
- Loading indicator during auth
- Error alert on failure
- "Create Account" navigation link to RegisterView
- "Forgot Password?" button → triggers password reset email

### 7.2 RegisterView

- Display name text field
- Email text field
- Password secure field (minimum 8 characters)
- Confirm password secure field
- "Create Account" button
- Validation: passwords match, email format, minimum password length
- Error display inline or as alert
- "Already have an account?" link back to LoginView

### 7.3 DashboardView (Tab 1)

**Top section — Stats Summary:**
- Three `StatCardView` cards in a horizontal scroll or grid:
  - "Max Grip" — highest `peakForce` across all recordings
  - "Average" — mean of all `peakForce` values
  - "Sessions" — total recording count
- Display values in user's preferred unit (kg or lbs)

**Bottom section — Recent Recordings:**
- `List` of `RecordingRowView` items, sorted by date descending
- Each row shows: date, peak force, hand indicator (L/R), duration
- Tap → push `RecordingDetailView`
- Empty state: friendly message + "Start your first recording" prompt
- Pull to refresh

### 7.4 RecordingDetailView

- Header: date/time, hand, duration
- `ForceChartView` — Swift Charts `LineMark` showing force over time
  - X axis: time in seconds
  - Y axis: force in user's preferred unit
- Stats below chart: peak force, average force, duration
- Delete button (with confirmation alert)

### 7.5 DeviceConnectionView (Tab 2)

**Disconnected state:**
- "Scan for Devices" button
- While scanning: progress indicator + "Scanning..."
- List of discovered devices with name and signal strength
- Tap device → initiate connection

**Connected state:**
- Device name + green status badge
- "Start Test" button → push LiveReadingView
- "Disconnect" button

**Error state:**
- Error message with "Try Again" button

### 7.6 LiveReadingView

- Large, prominent force number (centered, large font, updates in real-time)
- Unit label below number
- Simple force gauge or arc indicator (optional for MVP, nice to have)
- "Start Recording" / "Stop Recording" toggle button (prominent, colored)
  - Start → button turns red, label changes to "Stop Recording"
  - Stop → saves recording, shows brief success feedback, auto-navigates back or shows option to view
- Hand selector (left/right segmented control) at top
- Current session timer showing elapsed recording time

### 7.7 SettingsView (Tab 3)

- **Profile section:** display name, email (read-only)
- **Preferences section:**
  - Unit picker: kg / lbs (segmented control)
  - Dominant hand: left / right (segmented control)
- **About section:** app version
- **Sign Out button** (with confirmation alert)
- Settings stored in `UserDefaults` via `@AppStorage`

---

## 8. Firestore Schema

### Collection: `users/{userId}`

```
{
  displayName: String,
  email: String,
  preferredUnit: "kilograms" | "pounds",
  dominantHand: "left" | "right",
  createdAt: Timestamp
}
```

### Collection: `users/{userId}/recordings/{recordingId}`

```
{
  id: String (UUID),
  timestamp: Timestamp,
  peakForce: Number (kg),
  averageForce: Number (kg),
  duration: Number (seconds),
  hand: "left" | "right",
  dataPoints: [{ relativeTime: Number, force: Number }]
}
```

### DatabaseService Methods

```swift
class DatabaseService {
    func createUserProfile(_ profile: UserProfile) async throws
    func fetchUserProfile(userId: String) async throws -> UserProfile?
    func saveRecording(_ recording: GripRecording) async throws
    func fetchRecordings(userId: String) async throws -> [GripRecording]
    func deleteRecording(userId: String, recordingId: String) async throws
    func updateUserPreferences(userId: String, unit: ForceUnit, hand: Hand) async throws
}
```

---

## 9. Implementation Order

Follow this exact sequence. Each step should compile and run before moving to the next. Verify in the simulator after each step.

### Step 1: Project Skeleton

1. Create Xcode project (iOS App, SwiftUI, Swift, SwiftData)
2. Set deployment target to iOS 17.0
3. Create the full folder structure from Section 3
4. Add Firebase SDK via SPM (`FirebaseAuth`, `FirebaseFirestore`)
5. Configure `GoogleService-Info.plist` (from Firebase console)
6. Initialize Firebase in `GripTrackApp.swift`
7. Add Info.plist entries for Bluetooth
8. **Verify:** App compiles and launches to a blank screen

### Step 2: Data Models

1. Implement all models from Section 4: `GripRecording`, `ForceDataPoint`, `Hand`, `ForceUnit`, `UserProfile`
2. Configure SwiftData `ModelContainer` in the App entry point
3. **Verify:** App compiles with models registered

### Step 3: Authentication

1. Implement `AuthService.swift` — register, login, logout, password reset, auth state listener
2. Implement `AuthViewModel.swift` — wraps AuthService, exposes `isAuthenticated`, `currentUser`, error handling
3. Implement `LoginView.swift` and `RegisterView.swift` per Section 7 specs
4. Implement auth gate in `ContentView.swift`
5. **Verify:** Can register a new user, log out, log back in. Auth state persists across app restart.

### Step 4: Navigation Shell

1. Implement `MainTabView` with three tabs (Dashboard, Device, Settings)
2. Each tab shows a placeholder view with the tab name
3. Wire up ContentView auth gate → MainTabView
4. **Verify:** After login, see three tabs. Can switch between them.

### Step 5: Settings Screen

1. Implement `SettingsView.swift` — profile display, unit picker, hand picker, sign out
2. Implement `SettingsViewModel.swift` — reads/writes `@AppStorage` preferences
3. **Verify:** Can change units, change hand, sign out (returns to login)

### Step 6: Mock BLE Manager

1. Implement `GripDeviceProtocol.swift`
2. Implement `MockBLEManager.swift` per Section 5 behavior spec
3. Inject MockBLEManager via environment in App entry point (always use mock in simulator)
4. **Verify:** Mock manager produces simulated scanning, connection, and force data (log to console)

### Step 7: Device & Live Reading Screens

1. Implement `DeviceConnectionView.swift` — scan, device list, connect
2. Implement `LiveReadingView.swift` — force display, record button, hand selector
3. Implement `DeviceViewModel.swift` — wraps GripDeviceProtocol, manages state
4. Implement `ConnectionStatusBadge.swift`
5. **Verify:** Can scan (see mock devices), connect, see live force updates, start/stop recording

### Step 8: Database Service

1. Implement `DatabaseService.swift` — Firestore CRUD per Section 8
2. Wire `stopRecording()` flow → save to SwiftData locally → save to Firestore
3. **Verify:** After recording, data appears in Firestore console

### Step 9: Dashboard

1. Implement `DashboardViewModel.swift` — fetch recordings, compute stats
2. Implement `DashboardView.swift` — stats cards + recording list
3. Implement `RecordingRowView.swift`
4. Implement `StatCardView.swift`
5. **Verify:** After making recordings, dashboard shows them with correct stats

### Step 10: Recording Detail

1. Implement `RecordingDetailView.swift` — header, chart, stats, delete
2. Implement `ForceChartView.swift` — Swift Charts LineMark
3. Implement `RecordingViewModel.swift`
4. Wire delete flow (confirmation → remove from Firestore + SwiftData)
5. **Verify:** Tap recording → see force-time chart with correct data. Delete works.

### Step 11: Polish & Edge Cases

1. Empty states for dashboard (no recordings yet)
2. Loading states for all async operations
3. Error handling and user-facing error messages
4. Pull-to-refresh on dashboard
5. Keyboard dismissal on text fields
6. Respect user's unit preference everywhere forces are displayed

---

## 10. Cursor Rules Files

Create these files in the `.cursor/rules/` directory of your project.

### .cursor/rules/core.mdc

```
---
description: Core project rules applied to all files
alwaysApply: true
---

# GripTrack iOS Project Rules

## Project Context
You are building GripTrack, an iOS app for BLE grip strength measurement.
Always reference PROJECT_SPEC.md for architectural decisions and implementation details.

## Tech Stack (do not deviate)
- Swift 5.9+, iOS 17.0 minimum deployment target
- SwiftUI only (no UIKit unless absolutely unavoidable)
- MVVM architecture with @Observable (Observation framework, NOT ObservableObject/Combine)
- SwiftData for local persistence
- Firebase Auth + Cloud Firestore for cloud backend
- CoreBluetooth for BLE (behind GripDeviceProtocol)
- Swift Package Manager only

## Code Style
- Use @Observable classes for ViewModels, not ObservableObject
- Use @State private var for view-local state
- Use @Environment for dependency injection of ViewModels and services
- Prefer async/await over Combine publishers for async operations
- Use structured concurrency (Task, TaskGroup) over raw DispatchQueue
- All ViewModels and Services that touch UI must be @MainActor
- Force values are ALWAYS stored internally in kilograms. Convert for display only.
- Use Swift's native error handling (do/catch/throw), define custom error enums per service

## Naming Conventions
- Views: PascalCase ending in "View" (e.g., DashboardView, LiveReadingView)
- ViewModels: PascalCase ending in "ViewModel" (e.g., AuthViewModel)
- Services: PascalCase ending in "Service" or "Manager" (e.g., DatabaseService, BLEManager)
- Protocols: PascalCase ending in "Protocol" (e.g., GripDeviceProtocol)
- Files match their primary type name exactly

## File Organization
- One primary type per file
- File name matches the type name
- Follow the folder structure defined in PROJECT_SPEC.md Section 3
- Do not create files outside the defined structure without asking

## What NOT To Do
- Do NOT use Combine's ObservableObject/@Published — use @Observable/@State
- Do NOT use NavigationView — use NavigationStack
- Do NOT use UIKit wrappers when SwiftUI has a native equivalent
- Do NOT hardcode strings that should be in Constants.swift
- Do NOT put business logic in Views — all logic belongs in ViewModels or Services
- Do NOT access Firestore directly from Views or ViewModels — always go through DatabaseService
- Do NOT use force unwrapping (!) except for IBOutlets (which we shouldn't have)
- Do NOT ignore errors silently — log them and surface to user when appropriate
```

### .cursor/rules/swiftui.mdc

```
---
description: SwiftUI view implementation patterns
globs: ["**/Views/**/*.swift", "**/Components/**/*.swift"]
alwaysApply: false
---

# SwiftUI View Rules

## View Structure
Every view should follow this order:
1. Properties (@State, @Environment, let/var)
2. body
3. Computed properties used in body
4. Subview extraction methods (private var or @ViewBuilder)

## Patterns
- Extract reusable pieces into Components/ folder
- Use .task { } modifier for loading data on appear (not .onAppear with Task)
- Use @Environment(AuthViewModel.self) pattern for accessing shared state
- Handle loading/error/empty states explicitly in every data-displaying view
- Use system SF Symbols for icons (e.g., "house.fill", "sensor.fill", "gearshape.fill")

## Forms & Input
- Use .textContentType() hints for email and password fields
- Use .submitLabel() for keyboard return button
- Disable submit buttons while loading or validation fails
- Show inline validation errors below fields, not just alerts

## Lists
- Always provide an id or make items Identifiable
- Use .swipeActions for delete on list rows
- Include .refreshable { } for pull-to-refresh on data lists
```

### .cursor/rules/ble.mdc

```
---
description: Bluetooth Low Energy implementation rules
globs: ["**/Services/BLE/**/*.swift"]
alwaysApply: false
---

# BLE Implementation Rules

## Critical Constraint
CoreBluetooth does NOT work in the iOS simulator. It returns CBManagerState.unsupported.
All BLE code must be behind GripDeviceProtocol so MockBLEManager can substitute in simulator.

## Protocol-First Development
1. Define all interactions in GripDeviceProtocol
2. Implement MockBLEManager FIRST and get the full app working with it
3. Implement BLEManager (real CoreBluetooth) SECOND

## BLEManager Implementation
- Use CBCentralManager as the central
- Implement CBCentralManagerDelegate and CBPeripheralDelegate
- Always check centralManager.state before scanning
- Store discovered peripherals strongly (CBPeripheral is weakly held by the system)
- Use specific service UUIDs in scanForPeripherals when known
- Handle disconnection gracefully with automatic reconnection attempt
- All delegate callbacks arrive on a background queue — dispatch to @MainActor for UI updates

## MockBLEManager Implementation
- Simulate realistic timing: scanning delay, connection delay, data latency
- Generate plausible force curves (ramp up, hold with noise, ramp down)
- Update currentForce at ~20Hz using a Timer
- Support the full protocol: scan → discover → connect → stream → record → disconnect

## Info.plist Requirements
- NSBluetoothAlwaysUsageDescription must have a user-friendly description
- UIBackgroundModes must include bluetooth-central if background use is needed
```

### .cursor/rules/firebase.mdc

```
---
description: Firebase Auth and Firestore patterns
globs: ["**/Services/AuthService.swift", "**/Services/DatabaseService.swift", "**/ViewModels/AuthViewModel.swift"]
alwaysApply: false
---

# Firebase Rules

## Auth
- Use Firebase.configure() in App init, before any Firebase calls
- Use Auth.auth().addStateDidChangeListener for reactive auth state
- Store the listener handle and remove it on deinit
- Handle all FirebaseAuth error codes and present user-friendly messages
- Never store passwords or tokens locally

## Firestore
- Use the subcollection pattern: users/{userId}/recordings/{recordingId}
- Always include userId in queries for security
- Use Firestore Codable support for serialization when possible
- Handle offline scenarios: Firestore has built-in offline persistence (enabled by default)
- Batch writes when saving recording + updating user stats
- Use Firestore Timestamps, not Date (convert at the boundary)

## Error Handling
- Wrap all Firebase calls in do/catch
- Map Firebase errors to user-facing messages in the ViewModel
- Log technical errors for debugging
- Never expose raw Firebase error messages to users
```

---

## 11. Environment & Build Setup Checklist

Run through this before writing any feature code:

- [ ] Xcode project created: "GripTrack", iOS App, SwiftUI lifecycle, Swift, SwiftData
- [ ] Deployment target set to iOS 17.0
- [ ] Bundle identifier set (e.g., com.yourname.griptrack)
- [ ] Firebase project created at console.firebase.google.com
- [ ] Firebase iOS app registered with bundle ID
- [ ] `GoogleService-Info.plist` downloaded and added to project
- [ ] Firebase Auth enabled (Email/Password provider)
- [ ] Cloud Firestore database created (start in test mode, secure later)
- [ ] SPM: `firebase-ios-sdk` added (FirebaseAuth, FirebaseFirestore products)
- [ ] Info.plist: `NSBluetoothAlwaysUsageDescription` added
- [ ] Info.plist: `UIBackgroundModes` → `bluetooth-central` added
- [ ] Git repository initialized, `.gitignore` includes `GoogleService-Info.plist`
- [ ] All folders from Section 3 created
- [ ] `.cursor/rules/` directory created with all four `.mdc` files from Section 10
- [ ] Project compiles and runs in simulator (blank screen is fine)

---

## 12. Cursor Workflow Tips

### Starting a Session
Open Cursor and tell the agent:
> "Read PROJECT_SPEC.md. I am on Step [N] of Section 9. Implement the files for this step."

### After Each Step
1. Build in Xcode (or via Sweetpad in Cursor on Mac)
2. Run in simulator
3. Verify the checkpoint listed in Section 9
4. Fix any compiler errors before moving to the next step
5. Git commit with message: `"Step N: [description]"`

### When Things Break
Tell the agent:
> "The app crashes / shows error [X]. Here is the error: [paste]. Fix it while following PROJECT_SPEC.md rules."

### Adding Something Not in Spec
If you want to add something beyond this spec, create a mini-spec first:
> "I want to add [feature]. Write a brief spec for it in the same format as PROJECT_SPEC.md Section 7, then implement it."

---

*Last updated: February 2026*
