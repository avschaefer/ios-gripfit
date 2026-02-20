import SwiftUI

struct DeviceConnectionView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var deviceVM: DeviceViewModel

    init(deviceManager: GripDeviceProtocol) {
        _deviceVM = State(initialValue: DeviceViewModel(deviceManager: deviceManager))
    }

    var body: some View {
        NavigationStack {
            Group {
                if deviceVM.connectionState.isConnected {
                    LiveReadingView(deviceVM: deviceVM)
                } else {
                    connectionView
                }
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

    // MARK: - Connection View

    private var connectionView: some View {
        ZStack {
            ModernScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppConstants.UI.sectionSpacing) {
                    header
                    Group {
                        switch deviceVM.connectionState {
                        case .disconnected:
                            disconnectedView
                        case .scanning:
                            scanningView
                        case .connecting:
                            connectingView
                        case .connected:
                            EmptyView()
                        case .error(let message):
                            errorView(message: message)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
            .padding(.top, 10)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Device")
                    .font(.title.weight(.bold))
                Text("Grip strength insights")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ConnectionStatusBadge(state: deviceVM.connectionState)
        }
    }

    // MARK: - Disconnected

    private var disconnectedView: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No device connected")
                        .font(.headline.weight(.semibold))
                    Text("Scan for nearby devices")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    deviceVM.startScanning()
                } label: {
                    bluetoothCircle
                }
                .buttonStyle(.plain)

                Text("Scan for Devices")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: AppConstants.UI.sectionSpacing) {
            ModernCard {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.blue)
                    Text("Scanning for devices...")
                        .font(.headline)
                    ConnectionStatusBadge(state: .scanning)
                }
                .frame(maxWidth: .infinity)
            }

            ModernCard {
                VStack(alignment: .leading, spacing: 12) {
                    if deviceVM.discoveredDevices.isEmpty {
                        Text("Looking for nearby BLE devices...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(deviceVM.discoveredDevices) { device in
                            Button {
                                deviceVM.connect(to: device)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(device.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text("Signal: \(device.signalStrength)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("Pair")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(.white.opacity(0.1), in: Capsule())
                                }
                                .padding(12)
                                .background(
                                    .white.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Button("Stop Scanning") {
                deviceVM.stopScanning()
            }
            .buttonStyle(ModernPrimaryButtonStyle())
        }
    }

    // MARK: - Connecting

    private var connectingView: some View {
        ModernCard {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.6)
                    .tint(.blue)
                Text("Connecting...")
                    .font(.title3.weight(.semibold))
                Text("Please keep your device nearby.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Shared

    private var bluetoothCircle: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.14))
            Circle()
                .stroke(.blue.opacity(0.55), lineWidth: 1.5)
            BluetoothIcon()
                .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 36, height: 44)
        }
        .frame(width: 130, height: 130)
        .frame(maxWidth: .infinity)
        .contentShape(Circle())
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: AppConstants.UI.sectionSpacing) {
            ModernCard {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Connection Error")
                        .font(.title3.weight(.bold))
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button {
                deviceVM.startScanning()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(ModernPrimaryButtonStyle())
        }
    }
}

#Preview {
    DeviceConnectionView(deviceManager: MockBLEManager())
        .environment(AuthViewModel())
        .preferredColorScheme(.dark)
}
