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

    /// Page colour behind grouped boxes (Settings, Reminders): light grey in light mode, black in dark mode,
    /// so the white or dark grey boxes stand out in both.
    static let groupedFill = Color(.systemGroupedBackground)

    static var groupedBackground: some View {
        groupedFill.ignoresSafeArea()
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

/// Light / Dark / Automatic, chosen in Settings. Applied to the app's windows so sheets follow it too.
enum Appearance: String, CaseIterable, Identifiable {
    case automatic, light, dark

    static let defaultsKey = "appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    private var style: UIUserInterfaceStyle {
        switch self {
        case .automatic: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    static var saved: Appearance {
        Appearance(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .automatic
    }

    @MainActor
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

/// The title at the top of each tab. Same size, weight and height on every tab, and it never collapses.
struct TabHeader<Trailing: View>: View {
    let title: String
    var background: Color = Color(.systemBackground)
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Theme.purple)
                .lineLimit(1)
            Spacer()
            trailing
                .font(.title3.weight(.semibold))
                .tint(Theme.purple)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(background)
    }
}

extension TabHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}

extension View {
    /// Puts the tab title above the content and hides the system navigation bar on that tab only.
    /// Pass grouped: true on screens with grouped boxes so the header matches their page colour.
    func tabHeader(_ title: String, grouped: Bool = false) -> some View {
        tabHeader(title, grouped: grouped) { EmptyView() }
    }

    func tabHeader<Trailing: View>(_ title: String, grouped: Bool = false,
                                   @ViewBuilder trailing: () -> Trailing) -> some View {
        let header = TabHeader(title: title,
                               background: grouped ? Theme.groupedFill : Color(.systemBackground),
                               trailing: trailing)
        return self
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .navigationTitle(title)
            .toolbar(.hidden, for: .navigationBar)
    }
}

/// The round purple plus used as the floating add button (Log, Reminders).
struct FloatingPlus: View {
    var body: some View {
        Image(systemName: "plus")
            .font(.title2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(Circle().fill(Theme.purple))
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}
