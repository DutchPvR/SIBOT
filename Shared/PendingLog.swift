import Foundation

/// Bloating logged outside the app (widget, shortcut, Action button) waits here,
/// in the shared App Group, until the app adds it to the diary.
enum PendingLog {
    private static let key = "pendingBloat"
    private static let lastKey = "lastBloat"
    private static let defaults = UserDefaults(suiteName: MealTimerStore.appGroup) ?? .standard

    /// Set by the app so entries are added right away when it is already running.
    static var onAdd: (() -> Void)?

    static func addBloat(at date: Date = Date()) {
        var list = defaults.array(forKey: key) as? [Date] ?? []
        list.append(date)
        defaults.set(Array(list.suffix(50)), forKey: key)
        defaults.set(date, forKey: lastKey)
        onAdd?()
    }

    /// Returns the waiting entries and clears them.
    static func takeBloat() -> [Date] {
        let list = defaults.array(forKey: key) as? [Date] ?? []
        if !list.isEmpty { defaults.removeObject(forKey: key) }
        return list
    }

    /// When bloating was last logged from outside the app, for the widget's confirmation line.
    static var lastBloat: Date? { defaults.object(forKey: lastKey) as? Date }
}
