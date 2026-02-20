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
            ZStack {
                ModernScreenBackground()

                Group {
                    if dashboardVM.isLoading && dashboardVM.recordings.isEmpty {
                        loadingView
                    } else if dashboardVM.hasRecordings {
                        contentView
                    } else {
                        emptyStateView
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                .padding(.top, 10)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dashboard")
                    .font(.title.weight(.bold))
                Text("Your grip performance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppConstants.UI.sectionSpacing) {
                header
                statsSection

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Sessions")
                            .font(.headline)
                        Spacer()
                        Text("\(dashboardVM.totalSessions)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    ForEach(dashboardVM.recordings, id: \.id) { recording in
                        RecordingRowView(recording: recording, unit: unit)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRecording = recording
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task {
                                        await dashboardVM.deleteRecording(recording)
                                    }
                                } label: {
                                    Label("Delete", systemImage: AppConstants.Icons.trash)
                                }
                            }
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var statsSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Today's Best")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    ModernPillBadge(
                        text: dashboardVM.maxGripForce > 0 ? "+\(Int(dashboardVM.maxGripForce))" : "No Data",
                        tone: dashboardVM.maxGripForce > 0 ? .positive : .neutral
                    )
                }

                Text(unit.format(dashboardVM.maxGripForce))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                VStack(spacing: 10) {
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
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView()
                .scaleEffect(1.25)
                .tint(.blue)
            Text("Loading sessions...")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(alignment: .leading) {
            header
            Spacer()
            ModernCard {
                VStack(spacing: 14) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    Text("No Recordings Yet")
                        .font(.title3.weight(.bold))
                    Text("Connect to a device and run your first grip test to populate this dashboard.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Go to Device tab to get started")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    DashboardView()
        .environment(AuthViewModel())
}

