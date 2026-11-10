import Foundation

/// Shared state between the app, the widget and the Live Activity,
/// stored in the App Group so every process sees the same timer.
enum MealTimerStore {
    static let appGroup = "group.com.dutchpvr.sibot"

    /// Opened once; every read and write reuses it.
    private static let defaults = UserDefaults(suiteName: appGroup) ?? .standard

    /// Hours to wait between meals. Default 4, as in the Cedars-Sinai handout.
    static var gapHours: Double {
        get {
            let value = defaults.double(forKey: "gapHours")
            return value == 0 ? 4 : value
        }
        set { defaults.set(newValue, forKey: "gapHours") }
    }

    /// Send "Fasting goal reached" when the goal gap is up. Default on.
    static var goalNotificationOn: Bool {
        get { defaults.object(forKey: "goalNotificationOn") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "goalNotificationOn") }
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
