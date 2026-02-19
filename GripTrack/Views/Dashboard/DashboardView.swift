import SwiftUI

struct DashboardView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var dashboardVM = DashboardViewModel()
    @State private var selectedRecording: GripRecording?

    private var unit: ForceUnit {
        SettingsViewModel.currentUnit()
    }

    var body: some View {
        NavigationStack {
            Group {
                if dashboardVM.isLoading && dashboardVM.recordings.isEmpty {
                    loadingView
                } else if dashboardVM.hasRecordings {
                    contentView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle(AppConstants.Tabs.dashboard)
            .navigationDestination(item: $selectedRecording) { recording in
                RecordingDetailView(recording: recording)
            }
            .task {
                if let userId = authVM.currentUserId {
                    await dashboardVM.loadRecordings(userId: userId)
                }
            }
            .refreshable {
                if let userId = authVM.currentUserId {
                    await dashboardVM.refreshRecordings(userId: userId)
                }
            }
            .alert("Error", isPresented: $dashboardVM.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(dashboardVM.errorMessage ?? AppConstants.ErrorMessages.genericError)
            }
        }
    }

    // MARK: - Content

    private var contentView: some View {
        List {
            // Stats Summary
            Section {
                statsSection
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // Recent Recordings
            Section {
                ForEach(dashboardVM.recordings, id: \.id) { recording in
                    RecordingRowView(recording: recording, unit: unit)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRecording = recording
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            await dashboardVM.deleteRecording(dashboardVM.recordings[index])
                        }
                    }
                }
            } header: {
                Text("Recent Recordings")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            HStack(spacing: 12) {
                StatCardView(
                    title: "Max Grip",
                    value: unit.format(dashboardVM.maxGripForce),
                    icon: AppConstants.Icons.flame,
                    color: .orange
                )

                StatCardView(
                    title: "Average",
                    value: unit.format(dashboardVM.averageGripForce),
                    icon: AppConstants.Icons.chartBar,
                    color: .blue
                )

                StatCardView(
                    title: "Sessions",
                    value: "\(dashboardVM.totalSessions)",
                    icon: "number",
                    color: .green
                )
            }
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading recordings...")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Recordings Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Connect to a device and start your first grip test to see your results here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Image(systemName: "arrow.right.circle.fill")
                .font(.title)
                .foregroundStyle(.blue)

            Text("Go to the Device tab to get started")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    DashboardView()
        .environment(AuthViewModel())
}

