import SwiftUI
import SwiftData
import FirebaseCore

@main
struct GripFitApp: App {
    @State private var authVM: AuthViewModel
    @State private var subscriptionService: SubscriptionService

    #if targetEnvironment(simulator)
    @State private var deviceManager: MockBLEManager
    #else
    @State private var deviceManager: BLEManager
    #endif

    init() {
        FirebaseApp.configure()
        _authVM = State(initialValue: AuthViewModel())
        _subscriptionService = State(initialValue: SubscriptionService())

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
                .environment(subscriptionService)
                .task {
                    await subscriptionService.fetchProducts()
                    await subscriptionService.updateSubscriptionStatus()
                }
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: GripRecording.self)
    }
}
