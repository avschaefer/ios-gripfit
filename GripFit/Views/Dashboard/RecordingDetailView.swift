import SwiftUI

struct RecordingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RecordingViewModel

    private var unit: ForceUnit {
        SettingsViewModel.currentUnit()
    }

    init(recording: GripRecording) {
        _viewModel = State(initialValue: RecordingViewModel(recording: recording))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Chart
                chartSection

                // Stats
                statsSection

                // Delete Button
                deleteSection
            }
            .padding()
        }
        .navigationTitle("Recording Detail")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Recording", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteRecording()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this recording? This action cannot be undone.")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? AppConstants.ErrorMessages.genericError)
        }
        .onChange(of: viewModel.didDelete) { _, deleted in
            if deleted {
                dismiss()
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.formattedDate)
                .font(.headline)

            ModernPillBadge(
                text: viewModel.recording.hand.displayName + " Hand",
                tone: .positive
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Force Over Time")
                .font(.headline)

            if viewModel.recording.dataPoints.isEmpty {
                Text("No data points recorded")
                    .foregroundStyle(.secondary)
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
            } else {
                ForceChartView(
                    dataPoints: viewModel.recording.dataPoints,
                    unit: unit
                )
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            HStack(spacing: 12) {
                StatCardView(
                    title: "Peak Force",
                    value: unit.format(viewModel.recording.peakForce),
                    icon: AppConstants.Icons.flame,
                    color: .orange
                )

                StatCardView(
                    title: "Average Force",
                    value: unit.format(viewModel.recording.averageForce),
                    icon: AppConstants.Icons.chartBar,
                    color: .blue
                )

                StatCardView(
                    title: "Duration",
                    value: viewModel.formattedDuration,
                    icon: AppConstants.Icons.clock,
                    color: .green
                )
            }
        }
    }

    private var deleteSection: some View {
        Button(role: .destructive) {
            viewModel.showDeleteConfirmation = true
        } label: {
            HStack {
                if viewModel.isDeleting {
                    ProgressView()
                        .tint(.red)
                } else {
                    Image(systemName: AppConstants.Icons.trash)
                    Text("Delete Recording")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(viewModel.isDeleting)
    }

    private var handIcon: String {
        viewModel.recording.hand == .left ? AppConstants.Icons.leftHand : AppConstants.Icons.rightHand
    }
}

#Preview {
    let sampleData = (0..<100).map { i in
        let time = Double(i) * 0.05
        let force = 30.0 * sin(time * 0.5) * exp(-time * 0.1) + Double.random(in: -1...1)
        return ForceDataPoint(relativeTime: time, force: max(0, force))
    }

    let recording = GripRecording(
        userId: "test",
        peakForce: 42.5,
        averageForce: 35.2,
        duration: 5.0,
        hand: .right,
        dataPoints: sampleData
    )

    return NavigationStack {
        RecordingDetailView(recording: recording)
    }
}

