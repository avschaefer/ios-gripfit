import SwiftUI
import UIKit

// MARK: - Custom Bluetooth Icon (no SF Symbol exists for this)

struct BluetoothIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.22, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.28))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.05))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.95))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.28))
        return path
    }
}

enum BluetoothIconRenderer {
    static func tabImage(size: CGFloat = 25, lineWidth: CGFloat = 1.8) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let img = renderer.image { _ in
            let w = size
            let h = size
            let path = UIBezierPath()
            path.move(to: CGPoint(x: w * 0.22, y: h * 0.72))
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.28))
            path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.05))
            path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.95))
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.72))
            path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.28))
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor.white.setStroke()
            path.stroke()
        }
        return img.withRenderingMode(.alwaysTemplate)
    }
}

// MARK: - Shared Design System (Dark Theme)

struct ModernScreenBackground: View {
    private let accentPurple = Color(red: 0.43, green: 0.36, blue: 0.86)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.16),
                    accentPurple.opacity(0.22),
                    Color(red: 0.02, green: 0.08, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.blue.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: -140, y: -300)
            Circle()
                .fill(accentPurple.opacity(0.15))
                .frame(width: 260, height: 260)
                .blur(radius: 50)
                .offset(x: 140, y: -260)
            Circle()
                .fill(Color.cyan.opacity(0.1))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: 0, y: 320)
        }
        .ignoresSafeArea()
    }
}

struct ModernCard<Content: View>: View {
    let content: Content
    var compact: Bool = false

    init(compact: Bool = false, @ViewBuilder content: () -> Content) {
        self.compact = compact
        self.content = content()
    }

    private var radius: CGFloat {
        compact ? AppConstants.UI.compactCardCornerRadius : AppConstants.UI.cardCornerRadius
    }

    var body: some View {
        content
            .padding(compact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}

struct ModernPillBadge: View {
    let text: String
    var tone: Tone = .neutral

    enum Tone {
        case neutral, positive, warning, negative
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(toneColor)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(toneColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule(style: .continuous).fill(toneColor.opacity(0.18)))
    }

    private var toneColor: Color {
        switch tone {
        case .neutral: return .gray
        case .positive: return .green
        case .warning: return .orange
        case .negative: return .red
        }
    }
}

struct ModernPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.buttonCornerRadius, style: .continuous)
                    .fill(.blue.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.buttonCornerRadius, style: .continuous)
                    .stroke(.blue.opacity(0.55), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

struct ModernSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.buttonCornerRadius, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.buttonCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

struct ProfileInitialsView: View {
    let name: String

    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? "?"
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 44, height: 44)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
    }
}

// MARK: - Connection Status Badge

struct ConnectionStatusBadge: View {
    let state: ConnectionState

    var body: some View {
        ModernPillBadge(text: statusText, tone: badgeTone)
    }

    private var statusText: String {
        switch state {
        case .disconnected: return "Disconnected"
        case .scanning: return "Scanning"
        case .connecting: return "Connecting"
        case .connected(let name): return name
        case .error: return "Error"
        }
    }

    private var badgeTone: ModernPillBadge.Tone {
        switch state {
        case .disconnected: return .neutral
        case .scanning, .connecting: return .warning
        case .connected: return .positive
        case .error: return .negative
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
    .preferredColorScheme(.dark)
}
