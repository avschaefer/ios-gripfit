import SwiftUI
import SwiftData
import FirebaseCore

@main
struct GripFitApp: App {
    @State private var authVM: AuthViewModel

    #if targetEnvironment(simulator)
    @State private var deviceManager: MockBLEManager
    #else
    @State private var deviceManager: BLEManager
    #endif

    init() {
        FirebaseApp.configure()
        _authVM = State(initialValue: AuthViewModel())

        #if targetEnvironment(simulator)
        _deviceManager = State(initialValue: MockBLEManager())
        #else
        _deviceManager = State(initialValue: BLEManager())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(deviceManager: deviceManager)
                .environment(authVM)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: GripRecording.self)
    }
}
