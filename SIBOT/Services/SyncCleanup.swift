import Foundation
import SwiftData

/// iCloud sync can leave two copies of something that should exist once, for example the
/// starter ginger reminder created on a fresh install before the old one arrived from iCloud,
/// or a day's summary made on two devices. This folds those copies back into one.
@MainActor
enum SyncCleanup {
    static func run(in context: ModelContext) {
        mergeDuplicateSupplements(in: context)
        mergeDuplicateDays(in: context)
        mergeDuplicateDoseAnswers(in: context)
        try? context.save()
    }

    /// Reminders that are identical in every setting become one; the oldest is kept
    /// and the other's answers move over to it.
    private static func mergeDuplicateSupplements(in context: ModelContext) {
        guard let supplements = try? context.fetch(FetchDescriptor<Supplement>(sortBy: [SortDescriptor(\.createdAt)])),
              supplements.count > 1 else { return }
        var keeperFor: [String: Supplement] = [:]
        var moved: [UUID: UUID] = [:]
        for supplement in supplements {
            let key = [
                supplement.name, "\(supplement.minutes)", "\(supplement.weekdays.sorted())",
                "\(supplement.extraMinutes.sorted())", supplement.dose, supplement.notes,
                "\(supplement.startDate?.timeIntervalSince1970 ?? -1)", "\(supplement.endDate?.timeIntervalSince1970 ?? -1)",
            ].joined(separator: "|")
            if let keeper = keeperFor[key] {
                if keeper.id != supplement.id {
                    moved[supplement.id] = keeper.id
                    NotificationManager.cancel(supplementID: supplement.id)
                }
                context.delete(supplement)
            } else {
                keeperFor[key] = supplement
            }
        }
        guard !moved.isEmpty, let logs = try? context.fetch(FetchDescriptor<SupplementLog>()) else { return }
        for log in logs {
            if let target = moved[log.supplementID] { log.supplementID = target }
        }
    }

    /// One summary per day: copies are merged, keeping the most complete answer.
    private static func mergeDuplicateDays(in context: ModelContext) {
        guard let checks = try? context.fetch(FetchDescriptor<DailyCheck>(sortBy: [SortDescriptor(\.day)])),
              checks.count > 1 else { return }
        var byDay: [Date: DailyCheck] = [:]
        for check in checks {
            let day = Calendar.current.startOfDay(for: check.day)
            guard let keeper = byDay[day] else {
                byDay[day] = check
                continue
            }
            if check.answered {
                if !keeper.answered {
                    keeper.answered = true
                    keeper.bloated = check.bloated
                } else {
                    keeper.bloated = keeper.bloated || check.bloated
                }
            }
            keeper.severity = max(keeper.severity, check.severity)
            let symptoms = Set(keeper.symptoms + check.symptoms)
            keeper.symptoms = DailyCheck.symptomOptions.filter { symptoms.contains($0) }
                + symptoms.filter { !DailyCheck.symptomOptions.contains($0) }.sorted()
            keeper.bowelCount = max(keeper.bowelCount, check.bowelCount)
            keeper.bowelType = max(keeper.bowelType, check.bowelType)
            context.delete(check)
        }
    }

    /// One answer per dose per day: the most recent answer wins.
    private static func mergeDuplicateDoseAnswers(in context: ModelContext) {
        guard let logs = try? context.fetch(FetchDescriptor<SupplementLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])),
              logs.count > 1 else { return }
        var seen = Set<String>()
        for log in logs {
            let key = "\(log.supplementID.uuidString)|\(log.slot)|\(Calendar.current.startOfDay(for: log.day).timeIntervalSince1970)"
            if seen.contains(key) {
                context.delete(log)
            } else {
                seen.insert(key)
            }
        }
    }
}
