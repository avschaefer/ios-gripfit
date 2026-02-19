import SwiftUI

struct RecordingRowView: View {
    let recording: GripRecording
    var unit: ForceUnit = .kilograms

    var body: some View {
        ModernCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(unit.format(recording.peakForce))
                        .font(.headline.weight(.semibold))
                    Text(DateFormatters.recordingDate.string(from: recording.timestamp))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Label(DateFormatters.durationString(recording.duration), systemImage: AppConstants.Icons.clock)
                        Text("\(recording.hand.displayName) Hand")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    let recording = GripRecording(
        userId: "test",
        peakForce: 42.5,
        averageForce: 35.2,
        duration: 5.3,
        hand: .right,
        dataPoints: []
    )

    return RecordingRowView(recording: recording)
        .padding()
}

