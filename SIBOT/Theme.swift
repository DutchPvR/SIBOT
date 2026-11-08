import SwiftUI

enum Theme {
    static let grape = Color(red: 0.42, green: 0.30, blue: 0.85)
    static let pink = Color(red: 1.00, green: 0.36, blue: 0.62)
    static let orange = Color(red: 1.00, green: 0.62, blue: 0.20)
    static let red = Color(red: 0.93, green: 0.26, blue: 0.29)
    static let mint = Color(red: 0.14, green: 0.74, blue: 0.56)
    static let sky = Color(red: 0.25, green: 0.65, blue: 1.00)

    static var background: some View {
        LinearGradient(
            colors: [grape.opacity(0.18), pink.opacity(0.14), orange.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

struct StatusBadge: View {
    let status: FoodStatus

    var body: some View {
        Text("\(status.emoji) \(status.label)")
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(status.color.opacity(0.18), in: Capsule())
            .foregroundStyle(status.color)
    }
}
