import Foundation
import SwiftData

/// A supplement or medication reminder (e.g. ginger pills at 10 PM every night).
@Model
final class Supplement {
    var id: UUID
    var name: String
    /// Minutes after midnight, local time.
    var minutes: Int
    /// Calendar weekdays: 1 = Sunday ... 7 = Saturday.
    var weekdays: [Int]
    var enabled: Bool
    var createdAt: Date

    init(name: String, minutes: Int, weekdays: [Int] = Array(1...7), enabled: Bool = true) {
        self.id = UUID()
        self.name = name
        self.minutes = minutes
        self.weekdays = weekdays
        self.enabled = enabled
        self.createdAt = Date()
    }

    var timeText: String {
        let date = Calendar.current.date(
            bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()
        ) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    var daysText: String {
        let days = Set(weekdays)
        if days.count == 7 { return "Every day" }
        if days.isEmpty { return "No days selected" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return (1...7).filter { days.contains($0) }.map { symbols[$0 - 1] }.joined(separator: " ")
    }
}

/// Whether a dose was taken or skipped on a given day.
@Model
final class SupplementLog {
    var supplementID: UUID
    var supplementName: String
    /// When the answer was recorded.
    var date: Date
    /// The day the dose belongs to (start of day).
    var day: Date
    var taken: Bool

    init(supplementID: UUID, supplementName: String, taken: Bool, date: Date = Date()) {
        self.supplementID = supplementID
        self.supplementName = supplementName
        self.taken = taken
        self.date = date
        self.day = Calendar.current.startOfDay(for: date)
    }
}
