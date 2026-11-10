import SwiftUI

/// Whether it is OK to eat yet, from the last meal and the goal gap set in the iPhone app.
enum EatState: Equatable {
    /// The watch has not heard from the iPhone yet.
    case unknown
    /// Still inside the gap. `until` is when the gap is up.
    case wait(until: Date)
    /// The gap is up, or no meal is logged.
    case ok

    static func at(_ date: Date) -> EatState {
        guard WatchTimerPayload.lastSync != nil else { return .unknown }
        guard let start = MealTimerStore.startDate else { return .ok }
        // Use the gap as set now, so a change in Settings applies to the running timer.
        let end = start.addingTimeInterval(MealTimerStore.gapHours * 3600)
        return date < end ? .wait(until: end) : .ok
    }

    var title: String {
        switch self {
        case .unknown: "Open SIBOT"
        case .wait: "Wait"
        case .ok: "OK to eat"
        }
    }

    var color: Color {
        switch self {
        case .unknown: .gray
        case .wait: EatColors.red
        case .ok: EatColors.green
        }
    }
}

/// Same red and green as the iPhone app's Theme.
enum EatColors {
    static let red = Color(red: 0.86, green: 0.15, blue: 0.15)
    static let green = Color(red: 0.09, green: 0.64, blue: 0.29)
}
