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
    /// e.g. "500 mg" or "2 capsules".
    var dose: String = ""
    var notes: String = ""
    /// Optional course dates, e.g. a 14-day antibiotic.
    var startDate: Date?
    var endDate: Date?

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

    var hasCourse: Bool { startDate != nil || endDate != nil }

    /// "Day 3 of 14", "Ends Nov 20", "Starts Nov 20" or "Course finished" for dated courses.
    var courseText: String? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let start = startDate.map({ cal.startOfDay(for: $0) }), start > today {
            return "Starts \(start.formatted(.dateTime.month(.abbreviated).day()))"
        }
        if let end = endDate.map({ cal.startOfDay(for: $0) }) {
            if end < today { return "Course finished" }
            if let start = startDate.map({ cal.startOfDay(for: $0) }) {
                let total = (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1
                let current = (cal.dateComponents([.day], from: start, to: today).day ?? 0) + 1
                return "Day \(current) of \(total)"
            }
            return "Ends \(end.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return nil
    }

    /// Whether a dose is expected on this day (right weekday and inside the course).
    func isExpected(on day: Date) -> Bool {
        let cal = Calendar.current
        let d = cal.startOfDay(for: day)
        guard weekdays.contains(cal.component(.weekday, from: d)) else { return false }
        if d < cal.startOfDay(for: createdAt) && startDate == nil { return false }
        if let start = startDate, d < cal.startOfDay(for: start) { return false }
        if let end = endDate, d > cal.startOfDay(for: end) { return false }
        return true
    }

    /// Doses taken versus expected over the last `days` days (including today).
    func adherence(logs: [SupplementLog], days: Int = 14) -> (taken: Int, expected: Int) {
        let cal = Calendar.current
        var taken = 0
        var expected = 0
        for offset in 0..<days {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()), isExpected(on: day) else { continue }
            // Today does not count as missed until it is over.
            let log = logs.first { $0.supplementID == id && cal.isDate($0.day, inSameDayAs: day) }
            if log?.taken == true {
                taken += 1; expected += 1
            } else if offset > 0 {
                expected += 1
            }
        }
        return (taken, expected)
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
