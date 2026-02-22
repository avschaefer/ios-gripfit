import SwiftUI

struct LiveReadingView: View {
    @Bindable var deviceVM: DeviceViewModel

    private var unit: ForceUnit {
        SettingsViewModel.currentUnit()
    }

    var body: some View {
        ZStack {
            ModernScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppConstants.UI.sectionSpacing) {
                    header

                    if !deviceVM.sensorReady && deviceVM.connectionState.isConnected {
                        ModernCard {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Sensor not ready — check device hardware")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    ModernCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("ACTIVE HAND")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text("\(deviceVM.selectedHand.displayName) Hand")
                                        .font(.title3.weight(.bold))
                                }
                                Spacer()
                                handSwitchButton
                            }

                            forceDisplay

                            HStack(spacing: 10) {
                                ModernCard(compact: true) {
                                    metric(title: "PEAK", value: peakText, unitLabel: unit.abbreviation)
                                }
                                ModernCard(compact: true) {
                                    metric(
                                        title: "TIMER",
                                        value: DateFormatters.durationString(deviceVM.recordingDuration),
                                        unitLabel: "sec"
                                    )
                                }
                            }

                            Text("Squeeze hard. Hold steady.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    tareButton
                    recordButton

                    NavigationLink(destination: InstructionsView()) {
                        HStack(spacing: 6) {
                            Image(systemName: "book.closed")
                                .font(.caption)
                            Text("How to use")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)

                    if !deviceVM.isRecording {
                        Button(role: .destructive) {
                            deviceVM.disconnect()
                        } label: {
                            Text("Disconnect")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.85))
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .alert("Error", isPresented: $deviceVM.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deviceVM.errorMessage ?? AppConstants.ErrorMessages.genericError)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Grip Test")
                    .font(.title.weight(.bold))
                if let fw = deviceVM.firmwareVersion {
                    Text("Firmware v\(fw)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Grip strength insights")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            ModernPillBadge(
                text: "Live",
                tone: .positive
            )
        }
    }

    private var handSwitchButton: some View {
        Button {
            deviceVM.selectedHand = deviceVM.selectedHand == .left ? .right : .left
        } label: {
            Text("Switch")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.09), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(deviceVM.isRecording)
    }

    private var forceDisplay: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.14))
                .frame(width: 220, height: 220)
            Circle()
                .stroke(.blue.opacity(0.55), lineWidth: 1.5)
                .frame(width: 220, height: 220)
            Circle()
                .fill(Color(red: 0.05, green: 0.06, blue: 0.16))
                .frame(width: 200, height: 200)

            VStack(spacing: 2) {
                Text("LIVE FORCE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f", unit.convert(deviceVM.currentForce)))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                Text(unit.abbreviation)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func metric(title: String, value: String, unitLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unitLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var peakText: String {
        guard let peak = deviceVM.lastRecording?.peakForce else { return "0" }
        return String(format: "%.0f", unit.convert(peak))
    }

    private var tareButton: some View {
        Button {
            deviceVM.sendTare()
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("Tare (Zero)")
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(deviceVM.isRecording)

    }

    private var recordButton: some View {
        Button {
            if deviceVM.isRecording {
                Task {
                    await deviceVM.stopRecording()
                }
            } else {
                deviceVM.startRecording()
            }
        } label: {
            HStack {
                Image(systemName: deviceVM.isRecording ? "stop.fill" : "record.circle")
                Text(deviceVM.isRecording ? "Stop Recording" : "Start Test")
            }
        }
        .buttonStyle(ModernPrimaryButtonStyle())
    }
}

#Preview {
    let mockManager = MockBLEManager()
    let vm = DeviceViewModel(deviceManager: mockManager)

    return NavigationStack {
        LiveReadingView(deviceVM: vm)
    }
}
