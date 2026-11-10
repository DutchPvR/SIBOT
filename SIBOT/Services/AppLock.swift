import LocalAuthentication
import SwiftUI

/// Optional lock: Face ID, Touch ID or the phone's passcode is needed to open the app,
/// and the screen is hidden in the app switcher. Turned on in Settings.
@MainActor
final class AppLock: ObservableObject {
    static let shared = AppLock()
    static let enabledKey = "appLockOn"

    @Published private(set) var isLocked: Bool
    private var window: UIWindow?
    private var authenticating = false
    /// Face ID is offered once each time the app comes back; after a cancel, the Unlock button is used.
    private var triedThisSession = false

    private var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    private init() {
        isLocked = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    /// Call whenever the app moves between foreground and background.
    func sceneChanged(_ phase: ScenePhase) {
        guard isEnabled else {
            isLocked = false
            hideCover()
            return
        }
        switch phase {
        case .background:
            isLocked = true
            triedThisSession = false
            showCover(takeFocus: true)
        case .inactive:
            // Hides the diary in the app switcher.
            showCover(takeFocus: false)
        case .active:
            if isLocked {
                showCover(takeFocus: true)
                if !triedThisSession { unlock() }
            } else {
                hideCover()
            }
        @unknown default:
            break
        }
    }

    func unlock() {
        guard isLocked, !authenticating else { return }
        authenticating = true
        triedThisSession = true
        Task {
            let passed = await Self.authenticate(reason: "Unlock SIBOT")
            authenticating = false
            // nil means the phone has no passcode, so there is nothing to check against.
            if passed != false {
                isLocked = false
                hideCover()
            }
        }
    }

    /// true = passed, false = failed or cancelled, nil = this phone has no passcode set.
    static func authenticate(reason: String) async -> Bool? {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return nil }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }

    // MARK: - Cover

    /// The cover sits in its own window above everything, including open sheets.
    private func showCover(takeFocus: Bool) {
        if window == nil {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }
            let cover = UIWindow(windowScene: scene)
            cover.windowLevel = .alert + 1
            cover.rootViewController = UIHostingController(rootView: LockCover(lock: self))
            window = cover
        }
        if takeFocus {
            // Puts the keyboard away and stops typing from reaching the app underneath.
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            window?.makeKeyAndVisible()
        } else {
            window?.isHidden = false
        }
        Appearance.saved.apply()
    }

    private func hideCover() {
        guard let cover = window, !cover.isHidden else { return }
        cover.isHidden = true
        cover.windowScene?.windows.first { $0 !== cover }?.makeKey()
    }
}

private struct LockCover: View {
    @ObservedObject var lock: AppLock

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("SIBOT")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(Theme.purple)
                if lock.isLocked {
                    Button("Unlock") { lock.unlock() }
                        .font(.headline.weight(.heavy))
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(Theme.purple)
                }
            }
        }
    }
}
