import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
                .padding(8)
                .background(color.opacity(0.12), in: Circle())

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                .fill(.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HStack(spacing: 12) {
        StatCardView(title: "Max Grip", value: "45.2 kg", icon: "flame.fill", color: .orange)
        StatCardView(title: "Average", value: "32.1 kg", icon: "chart.bar.fill", color: .blue)
        StatCardView(title: "Sessions", value: "12", icon: "number", color: .green)
    }
    .padding()
}

