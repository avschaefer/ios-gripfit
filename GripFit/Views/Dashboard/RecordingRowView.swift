import SwiftUI

struct RecordingRowView: View {
    let recording: GripRecording
    var unit: ForceUnit = .kilograms

    var body: some View {
        HStack(spacing: 12) {
            // Hand indicator
            handIndicator

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(DateFormatters.recordingDate.string(from: recording.timestamp))
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    Label(DateFormatters.durationString(recording.duration), systemImage: AppConstants.Icons.clock)
                    Label(recording.hand.displayName, systemImage: handIcon)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Peak Force
            VStack(alignment: .trailing, spacing: 2) {
                Text(unit.format(recording.peakForce))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)

                Text("peak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        }
    }

    private var handIndicator: some View {
        Image(systemName: handIcon)
            .font(.title3)
            .foregroundStyle(.blue)
            .frame(width: 36, height: 36)
            .background {
                Circle()
                    .fill(.blue.opacity(0.1))
            }
    }

    private var handIcon: String {
        recording.hand == .left ? AppConstants.Icons.leftHand : AppConstants.Icons.rightHand
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

