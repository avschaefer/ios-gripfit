import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var dashboardVM = DashboardViewModel()
    @State private var selectedRecording: GripRecording?
    @State private var showAllSessions = false

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
            .navigationDestination(isPresented: $showAllSessions) {
                allSessionsView
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
                recentSessionsCard
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Summary Card

    private var statsSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("TODAY'S BEST")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.0f", unit.convert(dashboardVM.todaysBest)))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(unit.abbreviation)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if let hand = dashboardVM.todaysBestHand {
                    Text("\(hand.displayName) Hand · \(dashboardVM.todaysTestCount) test\(dashboardVM.todaysTestCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No tests today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                weeklyChart

                Divider()
                    .overlay(.white.opacity(0.08))

                HStack(spacing: 0) {
                    summaryMetric(
                        title: "3 Day Avg",
                        value: String(format: "%.0f", unit.convert(dashboardVM.threeDayAverage)),
                        unit: unit.abbreviation
                    )
                    summaryMetric(
                        title: "1 Mo Avg",
                        value: String(format: "%.0f", unit.convert(dashboardVM.oneMonthAverage)),
                        unit: unit.abbreviation
                    )
                    summaryMetric(
                        title: "All Time",
                        value: String(format: "%.0f", unit.convert(dashboardVM.allTimePeak)),
                        unit: unit.abbreviation
                    )
                    summaryMetric(
                        title: "Increase",
                        value: increaseText,
                        unit: nil,
                        color: increaseColor
                    )
                }
            }
        }
    }

    // MARK: - 7-Day Line Chart

    private var weeklyChart: some View {
        let data = dashboardVM.sevenDayAverages
        let hasData = data.contains { $0.average > 0 }

        return VStack(alignment: .leading, spacing: 6) {
            if hasData {
                Chart(data) { day in
                    LineMark(
                        x: .value("Day", day.label),
                        y: .value("Avg", unit.convert(day.average))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    if day.average > 0 {
                        PointMark(
                            x: .value("Day", day.label),
                            y: .value("Avg", unit.convert(day.average))
                        )
                        .symbolSize(day.date == Calendar.current.startOfDay(for: Date()) ? 50 : 24)
                        .foregroundStyle(.white)
                    }

                    AreaMark(
                        x: .value("Day", day.label),
                        y: .value("Avg", unit.convert(day.average))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.25), .blue.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
                .frame(height: 120)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.04))
                    .frame(height: 120)
                    .overlay {
                        Text("Chart data will appear here")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
            }
        }
    }

    // MARK: - Recent Sessions Card

    private var recentSessionsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Recent Sessions")
                        .font(.headline)
                    Spacer()
                    Button {
                        showAllSessions = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("View all")
                                .font(.caption.weight(.medium))
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 14)

                tableHeader

                Divider().overlay(.white.opacity(0.08))

                ForEach(dashboardVM.recentRecordings, id: \.id) { recording in
                    tableRow(recording)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRecording = recording
                        }

                    if recording.id != dashboardVM.recentRecordings.last?.id {
                        Divider().overlay(.white.opacity(0.05))
                    }
                }
            }
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("Weight")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Date")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Hand")
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: 44)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.bottom, 8)
    }

    private func tableRow(_ recording: GripRecording) -> some View {
        let isPR = recording.peakForce == dashboardVM.allTimePeak && dashboardVM.allTimePeak > 0

        return HStack(spacing: 0) {
            Text(unit.format(recording.peakForce))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(shortDate(recording.timestamp))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(recording.hand.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if isPR {
                    HStack(spacing: 3) {
                        Text("PR")
                            .font(.caption2.weight(.bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.55), in: Capsule())
                    .overlay(Capsule().stroke(.blue.opacity(0.7), lineWidth: 1))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    // MARK: - All Sessions View

    private var allSessionsView: some View {
        ZStack {
            ModernScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppConstants.UI.sectionSpacing) {
                    ModernCard {
                        VStack(alignment: .leading, spacing: 0) {
                            tableHeader

                            Divider().overlay(.white.opacity(0.08))

                            let sorted = dashboardVM.recordings.sorted { $0.timestamp > $1.timestamp }
                            ForEach(sorted, id: \.id) { recording in
                                tableRow(recording)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedRecording = recording
                                    }

                                if recording.id != sorted.last?.id {
                                    Divider().overlay(.white.opacity(0.05))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("All Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Helpers

    private func summaryMetric(title: String, value: String, unit: String?, color: Color = .white) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                if let unit {
                    Text(unit)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var increaseText: String {
        guard let pct = dashboardVM.increasePercent else { return "--" }
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(Int(pct))%"
    }

    private var increaseColor: Color {
        guard let pct = dashboardVM.increasePercent else { return .secondary }
        return pct >= 0 ? .green : .red.opacity(0.85)
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
