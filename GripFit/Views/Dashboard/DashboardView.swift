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
                handFilterPicker
                statsSection
                balanceAndStreakRow
                recentSessionsCard
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Summary Card

    private var statsSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
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
                    }

                    Spacer()

                    readinessRing
                }

                chartSection

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
                        title: "Change",
                        value: changeText,
                        unit: nil,
                        color: changeColor
                    )
                }
            }
        }
    }

    // MARK: - Readiness Ring

    private var readinessRing: some View {
        let score = dashboardVM.readinessScore
        let fraction = Double(score) / 100.0

        return VStack(spacing: 6) {
            Text("READINESS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        readinessGradient(for: score),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(score)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(readinessColor(for: score))
            }
            .frame(width: 72, height: 72)
        }
    }

    private func readinessColor(for score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private func readinessGradient(for score: Int) -> AngularGradient {
        let color = readinessColor(for: score)
        return AngularGradient(
            colors: [color.opacity(0.6), color],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * Double(score) / 100)
        )
    }

    // MARK: - Hand Filter

    private var handFilterPicker: some View {
        HStack(spacing: 0) {
            handFilterButton(label: "All", hand: nil)
            handFilterButton(label: "Left", hand: .left)
            handFilterButton(label: "Right", hand: .right)
        }
        .padding(3)
        .background(
            Capsule().fill(.white.opacity(0.06))
        )
    }

    private func handFilterButton(label: String, hand: Hand?) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                dashboardVM.handFilter = hand
            }
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(dashboardVM.handFilter == hand ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    dashboardVM.handFilter == hand
                        ? Capsule().fill(.white.opacity(0.12))
                        : nil
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Strength Balance & Streak

    private var balanceAndStreakRow: some View {
        HStack(spacing: 12) {
            strengthBalanceCard
            streakCard
        }
    }

    private var strengthBalanceCard: some View {
        let leftAvg = dashboardVM.leftBestAverage
        let rightAvg = dashboardVM.rightBestAverage
        let ratio = dashboardVM.balanceRatio
        let diff = dashboardVM.balanceDifferencePercent

        return ModernCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Strength Balance")
                    .font(.caption.weight(.semibold))

                HStack {
                    Text("Left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.08))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * ratio), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(String(format: "%.1f", unit.convert(leftAvg)))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(unit.abbreviation)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f", unit.convert(rightAvg)))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(unit.abbreviation)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if diff > 0 {
                    Text("\(diff)% difference")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(.orange.opacity(0.15))
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var streakCard: some View {
        let streak = dashboardVM.weekStreak
        let count = dashboardVM.streakDaysCount

        return ModernCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Streak")
                    .font(.caption.weight(.semibold))

                HStack(spacing: 6) {
                    ForEach(Array(streak.enumerated()), id: \.offset) { _, day in
                        Circle()
                            .fill(day.hasSession ? .cyan : .white.opacity(0.12))
                            .frame(width: 12, height: 12)
                    }
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 6) {
                    ForEach(Array(streak.enumerated()), id: \.offset) { _, day in
                        Text(day.label)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    }
                }
                .frame(maxWidth: .infinity)

                Text("\(count) of 7 days")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("This Week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Chart with Timeline

    private var chartSection: some View {
        let data = dashboardVM.chartAverages
        let hasData = data.contains { $0.average > 0 }

        return VStack(spacing: 8) {
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
                    let count = data.count
                    let stride = count > 8 ? max(1, count / 6) : 1
                    AxisMarks(values: .automatic) { value in
                        if value.index % stride == 0 {
                            AxisValueLabel()
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
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

            chartTimeRangePicker
        }
    }

    private var chartTimeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(ChartTimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dashboardVM.chartTimeRange = range
                    }
                } label: {
                    Text(range.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(dashboardVM.chartTimeRange == range ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            dashboardVM.chartTimeRange == range
                                ? Capsule().fill(.white.opacity(0.12))
                                : nil
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule().fill(.white.opacity(0.06))
        )
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

    private var changeText: String {
        guard let pct = dashboardVM.changePercent else { return "--" }
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(Int(pct))%"
    }

    private var changeColor: Color {
        guard let pct = dashboardVM.changePercent else { return .secondary }
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
