import SwiftUI
import SwiftData
import FirebaseCore

@main
struct GripFitApp: App {
    @State private var authVM = AuthViewModel()
    @State private var deviceManager: MockBLEManager

    init() {
        FirebaseApp.configure()

        // Use MockBLEManager for simulator, BLEManager for real device
        #if targetEnvironment(simulator)
        let mock = MockBLEManager()
        _deviceManager = State(initialValue: mock)
        #else
        // On real device, we still initialize MockBLEManager here as the default.
        // Replace with BLEManager() when ready for real BLE:
        // let manager = BLEManager()
        let mock = MockBLEManager()
        _deviceManager = State(initialValue: mock)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(deviceManager: deviceManager)
                .environment(authVM)
        }
        .modelContainer(for: GripRecording.self)
    }
}
