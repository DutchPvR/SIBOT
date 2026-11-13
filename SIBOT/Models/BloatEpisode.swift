import Foundation
import SwiftData

/// One bout of bloating, logged at a time of day. A day can have several.
@Model
final class BloatEpisode {
    var date: Date = Date()
    /// 1 (mild) ... 5 (severe); 0 means not rated.
    var severity: Int = 0
    /// Comma separated symptom names.
    var symptomsRaw: String = ""

    init(date: Date = Date(), severity: Int = 0, symptoms: [String] = []) {
        self.date = date
        self.severity = severity
        self.symptomsRaw = symptoms.joined(separator: ",")
    }

    var symptoms: [String] {
        get { symptomsRaw.split(separator: ",").map(String.init) }
        set { symptomsRaw = newValue.joined(separator: ",") }
    }

    /// One line, e.g. "Bloated · 3/5 · Gas, Pain".
    var summaryText: String {
        var parts = ["Bloated"]
        if severity > 0 { parts.append("\(severity)/5") }
        if !symptoms.isEmpty { parts.append(symptoms.joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }
}

/// Keeps the timed bloating entries and each day's summary (DailyCheck) in step.
/// The day summary is what the month calendar, the reports and the trigger analysis read.
@MainActor
enum BloatLog {
    private static func dayRange(_ day: Date) -> (start: Date, end: Date) {
        let start = Calendar.current.startOfDay(for: day)
        return (start, Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start)
    }

    static func episodes(on day: Date, in context: ModelContext) -> [BloatEpisode] {
        let (start, end) = dayRange(day)
        let descriptor = FetchDescriptor<BloatEpisode>(
            predicate: #Predicate { $0.date >= start && $0.date < end }, sortBy: [SortDescriptor(\.date)])
        return (try? context.fetch(descriptor)) ?? []
    }

    static func check(on day: Date, in context: ModelContext) -> DailyCheck? {
        let (start, end) = dayRange(day)
        let descriptor = FetchDescriptor<DailyCheck>(predicate: #Predicate { $0.day >= start && $0.day < end })
        return (try? context.fetch(descriptor))?.first
    }

    /// Rebuilds a day's summary from its timed entries. Call after adding, editing or deleting one.
    static func syncDay(_ day: Date, in context: ModelContext) {
        let entries = episodes(on: day, in: context)
        let existing = check(on: day, in: context)
        guard !entries.isEmpty else {
            // The last bloating entry was removed: the day goes back to "not answered".
            if let existing, existing.answered, existing.bloated { context.delete(existing) }
            return
        }
        let summary: DailyCheck
        if let existing {
            summary = existing
        } else {
            summary = DailyCheck(day: day, bloated: true)
            context.insert(summary)
        }
        summary.bloated = true
        summary.answered = true
        summary.severity = entries.map(\.severity).max() ?? 0
        let all = Set(entries.flatMap(\.symptoms))
        summary.symptoms = DailyCheck.symptomOptions.filter { all.contains($0) }
    }

    static func add(at date: Date, severity: Int = 0, symptoms: [String] = [], in context: ModelContext) {
        context.insert(BloatEpisode(date: date, severity: severity, symptoms: symptoms))
        syncDay(date, in: context)
    }

    static func delete(_ episode: BloatEpisode, in context: ModelContext) {
        let day = episode.date
        context.delete(episode)
        syncDay(day, in: context)
    }

    /// Marks the day as clear. Any bloating entries that day are removed.
    static func setNoBloat(on day: Date, in context: ModelContext) {
        for episode in episodes(on: day, in: context) { context.delete(episode) }
        let summary: DailyCheck
        if let existing = check(on: day, in: context) {
            summary = existing
        } else {
            summary = DailyCheck(day: day, bloated: false)
            context.insert(summary)
        }
        summary.bloated = false
        summary.answered = true
        summary.severity = 0
        summary.symptoms = []
    }

    /// Adds entries logged from the widget, a shortcut or the Action button while the app was closed.
    static func reconcilePending(in context: ModelContext) {
        for date in PendingLog.takeBloat() {
            add(at: date, in: context)
        }
    }

    /// Bloated days saved before bloating had a time become one entry at noon (once).
    static func migrateLegacy(in context: ModelContext) {
        let bloated = FetchDescriptor<DailyCheck>(predicate: #Predicate { $0.answered && $0.bloated })
        guard let checks = try? context.fetch(bloated), !checks.isEmpty else { return }
        let dated = Set(((try? context.fetch(FetchDescriptor<BloatEpisode>())) ?? [])
            .map { Calendar.current.startOfDay(for: $0.date) })
        for check in checks where !dated.contains(Calendar.current.startOfDay(for: check.day)) {
            let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: check.day) ?? check.day
            context.insert(BloatEpisode(date: noon, severity: check.severity, symptoms: check.symptoms))
        }
        try? context.save()
    }
}
