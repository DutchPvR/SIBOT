import Foundation
import SwiftData

enum SupplementLogger {
    /// Records taken/skipped for one dose today. Answering again replaces the earlier answer.
    /// `slot` is the dose time in minutes; nil means the supplement's first time.
    @MainActor
    static func record(supplementID: UUID, name: String? = nil, slot: Int?, taken: Bool, in context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())
        let supplement = (try? context.fetch(FetchDescriptor<Supplement>(
            predicate: #Predicate { $0.id == supplementID })))?.first
        let resolvedName = name ?? supplement?.name ?? "Supplement"
        let resolvedSlot = slot ?? supplement?.minutes ?? 0

        let descriptor = FetchDescriptor<SupplementLog>(
            predicate: #Predicate { $0.supplementID == supplementID && $0.day == today && $0.slot == resolvedSlot }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.taken = taken
            existing.date = Date()
            existing.supplementName = resolvedName
        } else {
            context.insert(SupplementLog(supplementID: supplementID, supplementName: resolvedName,
                                         taken: taken, slot: resolvedSlot))
        }
        try? context.save()
    }

    /// Removes today's answer for one dose, back to "not logged".
    @MainActor
    static func clearToday(supplementID: UUID, slot: Int, in context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<SupplementLog>(
            predicate: #Predicate { $0.supplementID == supplementID && $0.day == today && $0.slot == slot }
        )
        for log in (try? context.fetch(descriptor)) ?? [] {
            context.delete(log)
        }
        try? context.save()
    }

    /// Answers saved before a supplement could have several times belong to its first time.
    @MainActor
    static func migrateLegacySlots(_ context: ModelContext) {
        let descriptor = FetchDescriptor<SupplementLog>(predicate: #Predicate { $0.slot == -1 })
        guard let legacy = try? context.fetch(descriptor), !legacy.isEmpty else { return }
        let supplements = (try? context.fetch(FetchDescriptor<Supplement>())) ?? []
        let firstTime = Dictionary(supplements.map { ($0.id, $0.minutes) }, uniquingKeysWith: { a, _ in a })
        for log in legacy {
            log.slot = firstTime[log.supplementID] ?? 0
        }
        try? context.save()
    }
}
