import AppKit
import SwiftUI

enum InazumaPalette {
    static let accent = Color.accentColor

    static let bgPrimary = Color(nsColor: .windowBackgroundColor)
    static let bgSidebar = Color(nsColor: .underPageBackgroundColor)
    static let bgCard = Color(nsColor: .controlBackgroundColor)
    static let bgElevated = Color(nsColor: .textBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)

    static let cyan = accent
    static let cyanGlow = accent.opacity(0.08)
    static let cyanBorder = separator.opacity(0.75)

    static let green = Color(nsColor: .systemGreen)
    static let red = Color(nsColor: .systemRed)
    static let amber = Color(nsColor: .systemOrange)

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textMuted = Color(nsColor: .tertiaryLabelColor)

    static let blue = Color(nsColor: .systemBlue)

    static let windowGradient = LinearGradient(colors: [bgPrimary, bgPrimary], startPoint: .top, endPoint: .bottom)
}

enum InazumaSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
}

enum InazumaTypography {
    static let label = Font.system(.subheadline, design: .default).weight(.medium)

    static func metric(size: CGFloat = 17, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static let heroMetric = Font.system(size: 28, weight: .bold, design: .monospaced)
    static let caption = Font.system(.caption, design: .default).weight(.regular)
}

enum InazumaSeverity {
    case safe
    case warning
    case danger
    case info
    case muted

    var color: Color {
        switch self {
        case .safe:
            InazumaPalette.green
        case .warning:
            InazumaPalette.amber
        case .danger:
            InazumaPalette.red
        case .info:
            InazumaPalette.cyan
        case .muted:
            InazumaPalette.textMuted
        }
    }
}

struct InazumaStatusDot: View {
    let color: Color
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.25), radius: 2)
    }
}

struct InazumaPill: View {
    let text: String
    let severity: InazumaSeverity
    var monospaced = false

    var body: some View {
        Text(text)
            .font(monospaced ? InazumaTypography.metric(size: 11, weight: .semibold) : InazumaTypography.caption.weight(.semibold))
            .foregroundStyle(severity.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(severity.color.opacity(0.16))
            .overlay {
                Capsule().stroke(severity.color.opacity(0.34), lineWidth: 1)
            }
            .clipShape(Capsule())
    }
}

struct InazumaSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: InazumaSpacing.xs) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(InazumaPalette.textSecondary)
            Spacer()
            trailing()
        }
        .padding(.top, InazumaSpacing.xs)
    }
}

struct InazumaCardModifier: ViewModifier {
    var glow = false
    var borderColor: Color = InazumaPalette.separator

    func body(content: Content) -> some View {
        content
            .padding(InazumaSpacing.sm)
            .background(InazumaPalette.bgCard)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            }
            .overlay {
                if glow {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(InazumaPalette.accent.opacity(0.22), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(glow ? 0.1 : 0.05), radius: glow ? 6 : 3, y: 1)
    }
}

extension View {
    func inazumaCard(glow: Bool = false, borderColor: Color = InazumaPalette.separator) -> some View {
        modifier(InazumaCardModifier(glow: glow, borderColor: borderColor))
    }
}

struct InazumaWindowBackdrop: View {
    var body: some View {
        ZStack {
            InazumaPalette.windowGradient

            LinearGradient(
                colors: [InazumaPalette.accent.opacity(0.025), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
}

struct InazumaProgressBar: View {
    let value: Double
    var maxValue: Double
    var height: CGFloat = 6
    var severityStops: (warning: Double, danger: Double)? = nil

    private var clamped: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value / maxValue, 0), 1)
    }

    private var fillColor: Color {
        guard let stops = severityStops else { return InazumaPalette.cyan }
        if value >= stops.danger { return InazumaPalette.red }
        if value >= stops.warning { return InazumaPalette.amber }
        return InazumaPalette.cyan
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(InazumaPalette.separator.opacity(0.5))
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(fillColor)
                    .frame(width: max(geo.size.width * clamped, 2))
            }
        }
        .frame(height: height)
    }
}

struct InazumaActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(InazumaPalette.accent.opacity(isEnabled ? (configuration.isPressed ? 0.16 : 0.10) : 0.05))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(InazumaPalette.accent.opacity(isEnabled ? (configuration.isPressed ? 0.46 : 0.28) : 0.10), lineWidth: 1)
            }
            .foregroundStyle(isEnabled ? InazumaPalette.textPrimary : InazumaPalette.textMuted)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(isEnabled ? 1 : 0.76)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct InazumaInputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(InazumaPalette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(InazumaPalette.bgElevated)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(InazumaPalette.separator.opacity(0.9), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .tint(InazumaPalette.accent)
    }
}

extension View {
    func inazumaInputField() -> some View {
        modifier(InazumaInputFieldModifier())
    }
}

struct InazumaHoverCardModifier: ViewModifier {
    @State private var isHovering = false
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .background(highlighted ? InazumaPalette.bgElevated : InazumaPalette.bgCard)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        highlighted ? InazumaPalette.accent.opacity(0.45) : InazumaPalette.separator.opacity(isHovering ? 0.95 : 0.65),
                        lineWidth: 1
                    )
            }
            .shadow(color: isHovering ? Color.black.opacity(0.08) : .clear, radius: 4, y: 1)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
    }
}

extension View {
    func inazumaHoverCard(highlighted: Bool = false) -> some View {
        modifier(InazumaHoverCardModifier(highlighted: highlighted))
    }
}

struct InazumaRunTypePill: View {
    let runType: RunType

    private var severity: InazumaSeverity {
        switch runType {
        case .backtest:
            .info
        case .validate:
            .safe
        case .shadow:
            .warning
        }
    }

    var body: some View {
        InazumaPill(text: runType.rawValue.uppercased(), severity: severity, monospaced: true)
    }
}

struct SparklineView: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let points = normalizedPoints(in: geo.size)
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(InazumaPalette.cyan, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 0.001)

        return values.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
            let normalized = (value - minValue) / range
            let y = (1 - normalized) * size.height
            return CGPoint(x: x, y: y)
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Date {
    func relativeTimeString(reference: Date = .now) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: reference)
    }
}
