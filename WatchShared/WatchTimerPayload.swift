import Foundation

/// What the iPhone sends the Apple Watch over WatchConnectivity.
///
/// The watch cannot read the iPhone's App Group, so the phone sends the time of the
/// last meal and the goal gap from Settings, and the watch stores them in its own
/// App Group with `MealTimerStore`, where the complication reads them.
enum WatchTimerPayload {
    static let startKey = "start"
    static let gapKey = "gapHours"
    static let sentKey = "sent"

    /// iPhone side: the current timer as a property-list dictionary.
    static func make(start: Date?, gapHours: Double, sent: Date = Date()) -> [String: Any] {
        var payload: [String: Any] = [
            gapKey: gapHours,
            sentKey: sent.timeIntervalSince1970,
        ]
        if let start { payload[startKey] = start.timeIntervalSince1970 }
        return payload
    }

    /// When the watch last stored a payload from the phone. Nil until the first sync.
    static var lastSync: Date? {
        get { defaults.object(forKey: "watchLastSync") as? Date }
        set { defaults.set(newValue, forKey: "watchLastSync") }
    }

    /// Watch side: stores the payload. Returns false if it is malformed or older
    /// than what is already stored (application context and complication transfers
    /// can arrive out of order).
    @discardableResult
    static func apply(_ payload: [String: Any]) -> Bool {
        guard let gap = payload[gapKey] as? Double, gap > 0,
              let sentValue = payload[sentKey] as? Double else { return false }
        let sent = Date(timeIntervalSince1970: sentValue)
        if let last = lastSync, sent < last { return false }

        let start = (payload[startKey] as? Double).map { Date(timeIntervalSince1970: $0) }
        MealTimerStore.gapHours = gap
        MealTimerStore.startDate = start
        MealTimerStore.endDate = start?.addingTimeInterval(gap * 3600)
        lastSync = sent
        return true
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: MealTimerStore.appGroup) ?? .standard
    }
}
