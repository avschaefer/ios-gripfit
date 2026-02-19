import SwiftUI

struct LiveReadingView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var deviceVM: DeviceViewModel

    private var unit: ForceUnit {
        SettingsViewModel.currentUnit()
    }

    var body: some View {
        VStack(spacing: 24) {
            // Hand Selector
            handSelector

            // Force Display
            forceDisplay

            // Recording Timer
            if deviceVM.isRecording {
                recordingTimer
            }

            Spacer()

            // Record Button
            recordButton

            // Back / Done
            if !deviceVM.isRecording {
                Button("Done") {
                    dismiss()
                }
                .padding(.bottom, 8)
            }
        }
        .padding()
        .navigationTitle("Live Reading")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(deviceVM.isRecording)
        .alert("Recording Saved!", isPresented: $deviceVM.showRecordingSaved) {
            Button("View Dashboard") {
                dismiss()
            }
            Button("Continue", role: .cancel) {}
        } message: {
            if let recording = deviceVM.lastRecording {
                Text("Peak force: \(unit.format(recording.peakForce))\nDuration: \(DateFormatters.durationString(recording.duration))")
            }
        }
        .alert("Error", isPresented: $deviceVM.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deviceVM.errorMessage ?? AppConstants.ErrorMessages.genericError)
        }
    }

    // MARK: - Subviews

    private var handSelector: some View {
        Picker("Hand", selection: $deviceVM.selectedHand) {
            ForEach(Hand.allCases, id: \.self) { hand in
                Text(hand.displayName).tag(hand)
            }
        }
        .pickerStyle(.segmented)
        .disabled(deviceVM.isRecording)
    }

    private var forceDisplay: some View {
        VStack(spacing: 8) {
            // Force gauge circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.blue.opacity(0.15), lineWidth: 20)
                    .frame(width: 220, height: 220)

                // Progress arc
                Circle()
                    .trim(from: 0, to: forceProgress)
                    .stroke(
                        AngularGradient(
                            colors: [.blue, .cyan, .green],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.1), value: forceProgress)

                // Force value
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", unit.convert(deviceVM.currentForce)))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.1), value: deviceVM.currentForce)

                    Text(unit.abbreviation)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 20)
    }

    private var forceProgress: CGFloat {
        // Normalize force to 0-1 range (assuming max ~60kg)
        min(CGFloat(deviceVM.currentForce / 60.0), 1.0)
    }

    private var recordingTimer: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .opacity(pulsingOpacity)

            Text(DateFormatters.durationString(deviceVM.recordingDuration))
                .font(.title3)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background {
            Capsule()
                .fill(.red.opacity(0.1))
        }
    }

    @State private var pulsingOpacity: Double = 1.0

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
                Text(deviceVM.isRecording ? "Stop Recording" : "Start Recording")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(deviceVM.isRecording ? .red : .blue)
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulsingOpacity = 0.3
            }
        }
    }
}

#Preview {
    let mockManager = MockBLEManager()
    let vm = DeviceViewModel(deviceManager: mockManager)

    return NavigationStack {
        LiveReadingView(deviceVM: vm)
    }
}

