import SwiftUI

/// "Signal" design: white/black, hairlines, no cards. Colour appears only to mean Safe / Limit / Avoid.
enum Theme {
    /// Primary ink: black in light mode, white in dark mode.
    static let ink = Color.primary
    /// Accent for headers, tint and selected states.
    static let purple = Color(red: 0.44, green: 0.27, blue: 0.86)
    static let purpleUI = UIColor(red: 0.44, green: 0.27, blue: 0.86, alpha: 1)
    static let green = Color(red: 0.09, green: 0.64, blue: 0.29)
    static let amber = Color(red: 0.85, green: 0.47, blue: 0.02)
    static let red = Color(red: 0.86, green: 0.15, blue: 0.15)
    static let hairline = Color.primary.opacity(0.12)

    static var background: some View {
        Color(.systemBackground).ignoresSafeArea()
    }
}

/// A plain block with no box around it.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(.vertical, 12)
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}

struct StatusDot: View {
    let status: FoodStatus
    var size: CGFloat = 10

    var body: some View {
        Circle().fill(status.color).frame(width: size, height: size)
    }
}

struct StatusBadge: View {
    let status: FoodStatus

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(status: status, size: 8)
            Text(status.label.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(1)
        }
        .foregroundStyle(status.color)
    }
}
