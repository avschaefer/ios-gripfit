import SwiftUI
import Charts

struct ForceChartView: View {
    let dataPoints: [ForceDataPoint]
    var unit: ForceUnit = .kilograms
    var height: CGFloat = 250

    var body: some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value("Time", point.relativeTime),
                y: .value("Force", unit.convert(point.force))
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Time", point.relativeTime),
                y: .value("Force", unit.convert(point.force))
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [.blue.opacity(0.3), .cyan.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartXAxisLabel("Time (s)")
        .chartYAxisLabel("Force (\(unit.abbreviation))")
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6))
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5))
        }
        .frame(height: height)
    }
}

#Preview {
    let sampleData = (0..<100).map { i in
        let time = Double(i) * 0.05
        let force = 30.0 * sin(time * 0.5) * exp(-time * 0.1) + Double.random(in: -1...1)
        return ForceDataPoint(relativeTime: time, force: max(0, force))
    }

    return ForceChartView(dataPoints: sampleData)
        .padding()
}

