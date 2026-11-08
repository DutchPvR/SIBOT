import Foundation
import SwiftData

enum SupplementLogger {
    /// Records taken/skipped for today. Answering again replaces the earlier answer.
    @MainActor
    static func record(supplementID: UUID, name: String? = nil, taken: Bool, in context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())

        var resolvedName = name ?? "Supplement"
        if name == nil {
            let supplementDescriptor = FetchDescriptor<Supplement>(
                predicate: #Predicate { $0.id == supplementID }
            )
            if let found = (try? context.fetch(supplementDescriptor))?.first {
                resolvedName = found.name
            }
        }

        let logDescriptor = FetchDescriptor<SupplementLog>(
            predicate: #Predicate { $0.supplementID == supplementID && $0.day == today }
        )
        if let existing = (try? context.fetch(logDescriptor))?.first {
            existing.taken = taken
            existing.date = Date()
            existing.supplementName = resolvedName
        } else {
            context.insert(SupplementLog(supplementID: supplementID, supplementName: resolvedName, taken: taken))
        }
        try? context.save()
    }

    /// Removes today's answer, back to "not logged".
    @MainActor
    static func clearToday(supplementID: UUID, in context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<SupplementLog>(
            predicate: #Predicate { $0.supplementID == supplementID && $0.day == today }
        )
        for log in (try? context.fetch(descriptor)) ?? [] {
            context.delete(log)
        }
        try? context.save()
    }
}
