import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authVM
    let deviceManager: GripDeviceProtocol

    var body: some View {
        Group {
            if authVM.isAuthenticated {
                MainTabView(deviceManager: deviceManager)
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.isAuthenticated)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    let deviceManager: GripDeviceProtocol

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label(AppConstants.Tabs.dashboard, systemImage: AppConstants.Icons.dashboard)
                }

            DeviceConnectionView(deviceManager: deviceManager)
                .tabItem {
                    Label(AppConstants.Tabs.device, systemImage: AppConstants.Icons.device)
                }

            SettingsView()
                .tabItem {
                    Label(AppConstants.Tabs.settings, systemImage: AppConstants.Icons.settings)
                }
        }
    }
}

#Preview {
    ContentView(deviceManager: MockBLEManager())
        .environment(AuthViewModel())
}

