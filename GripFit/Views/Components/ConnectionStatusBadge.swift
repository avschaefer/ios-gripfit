import SwiftUI

struct ConnectionStatusBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(statusColor.opacity(0.12))
        }
    }

    private var statusColor: Color {
        switch state {
        case .disconnected:
            return .gray
        case .scanning, .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }

    private var statusText: String {
        switch state {
        case .disconnected:
            return "Disconnected"
        case .scanning:
            return "Scanning"
        case .connecting:
            return "Connecting"
        case .connected(let name):
            return name
        case .error:
            return "Error"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ConnectionStatusBadge(state: .disconnected)
        ConnectionStatusBadge(state: .scanning)
        ConnectionStatusBadge(state: .connecting)
        ConnectionStatusBadge(state: .connected(deviceName: "GripPro-A1B2"))
        ConnectionStatusBadge(state: .error("Connection failed"))
    }
}

