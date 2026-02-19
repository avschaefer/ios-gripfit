import SwiftUI

struct DeviceConnectionView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var deviceVM: DeviceViewModel
    @State private var showLiveReading: Bool = false

    init(deviceManager: GripDeviceProtocol) {
        _deviceVM = State(initialValue: DeviceViewModel(deviceManager: deviceManager))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch deviceVM.connectionState {
                case .disconnected:
                    disconnectedView
                case .scanning:
                    scanningView
                case .connecting:
                    connectingView
                case .connected(let deviceName):
                    connectedView(deviceName: deviceName)
                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle(AppConstants.Tabs.device)
            .navigationDestination(isPresented: $showLiveReading) {
                LiveReadingView(deviceVM: deviceVM)
            }
            .task {
                if let userId = authVM.currentUserId {
                    deviceVM.setUserId(userId)
                }
            }
            .onDisappear {
                deviceVM.stopStateSync()
            }
        }
    }

    // MARK: - Disconnected State

    private var disconnectedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: AppConstants.Icons.bluetooth)
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("No Device Connected")
                .font(.title2)
                .fontWeight(.bold)

            Text("Scan for nearby grip strength devices to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                deviceVM.startScanning()
            } label: {
                HStack {
                    Image(systemName: AppConstants.Icons.scanning)
                    Text("Scan for Devices")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Scanning State

    private var scanningView: some View {
        VStack(spacing: 20) {
            // Scanning indicator
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Scanning for devices...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            // Device list
            if !deviceVM.discoveredDevices.isEmpty {
                List(deviceVM.discoveredDevices) { device in
                    Button {
                        deviceVM.connect(to: device)
                    } label: {
                        HStack {
                            Image(systemName: AppConstants.Icons.bluetooth)
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text("Signal: \(device.signalStrength)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }

            // Stop scanning button
            Button("Stop Scanning") {
                deviceVM.stopScanning()
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Connecting State

    private var connectingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(2)
            Text("Connecting...")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Connected State

    private func connectedView(deviceName: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Status
            Image(systemName: AppConstants.Icons.connected)
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Connected")
                .font(.title2)
                .fontWeight(.bold)

            ConnectionStatusBadge(state: .connected(deviceName: deviceName))

            // Start Test Button
            Button {
                showLiveReading = true
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Test")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 40)

            // Disconnect Button
            Button(role: .destructive) {
                deviceVM.disconnect()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Disconnect")
                }
            }

            Spacer()
        }
    }

    // MARK: - Error State

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)

            Text("Connection Error")
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                deviceVM.startScanning()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

#Preview {
    DeviceConnectionView(deviceManager: MockBLEManager())
        .environment(AuthViewModel())
}

