import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .blue

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        }
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

