import Foundation

/// Shared state between the app, the widget and the Live Activity,
/// stored in the App Group so every process sees the same timer.
enum MealTimerStore {
    static let appGroup = "group.com.dutchpvr.sibot"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    /// Hours to wait between meals. Default 5.
    static var gapHours: Double {
        get {
            let value = defaults.double(forKey: "gapHours")
            return value == 0 ? 5 : value
        }
        set { defaults.set(newValue, forKey: "gapHours") }
    }

    static var startDate: Date? {
        get { defaults.object(forKey: "timerStart") as? Date }
        set { defaults.set(newValue, forKey: "timerStart") }
    }

    static var endDate: Date? {
        get { defaults.object(forKey: "timerEnd") as? Date }
        set { defaults.set(newValue, forKey: "timerEnd") }
    }

    static var isWaiting: Bool {
        guard let end = endDate else { return false }
        return end > Date()
    }
}
