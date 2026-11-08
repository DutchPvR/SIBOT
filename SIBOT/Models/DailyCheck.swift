import Foundation
import SwiftData

/// One "how was your belly today" answer per day: bloated or not.
@Model
final class DailyCheck {
    /// Start of the day this answer belongs to.
    var day: Date
    var bloated: Bool

    init(day: Date, bloated: Bool) {
        self.day = Calendar.current.startOfDay(for: day)
        self.bloated = bloated
    }
}
