import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// A JSON file with everything in the app. Save it to iCloud Drive from the Files picker.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupFile: Codable {
    struct Meal: Codable { var date: Date; var text: String; var status: String; var symptomScore: Int? }
    struct Check: Codable {
        var day: Date; var bloated: Bool; var answered: Bool; var severity: Int
        var symptoms: String; var bowelCount: Int; var bowelType: Int
    }
    struct Supp: Codable {
        var id: UUID; var name: String; var minutes: Int; var weekdays: [Int]; var enabled: Bool
        var createdAt: Date; var dose: String; var notes: String; var startDate: Date?; var endDate: Date?
    }
    struct SuppLog: Codable {
        var supplementID: UUID; var supplementName: String; var date: Date; var day: Date; var taken: Bool
    }

    struct Trial: Codable { var food: String; var startDate: Date; var result: Int; var notes: String }

    var version = 1
    var personalFoods: [String: String]?
    var trials: [Trial]?
    var exportedAt = Date()
    var gapHours: Double = 5
    var meals: [Meal] = []
    var checks: [Check] = []
    var supplements: [Supp] = []
    var supplementLogs: [SuppLog] = []
}

enum BackupService {
    static let lastBackupKey = "lastBackupDate"

    @MainActor
    static func makeData(context: ModelContext) throws -> Data {
        var file = BackupFile()
        file.gapHours = MealTimerStore.gapHours
        file.meals = try context.fetch(FetchDescriptor<MealEntry>()).map {
            .init(date: $0.date, text: $0.text, status: $0.statusRaw, symptomScore: $0.symptomScore)
        }
        file.checks = try context.fetch(FetchDescriptor<DailyCheck>()).map {
            .init(day: $0.day, bloated: $0.bloated, answered: $0.answered, severity: $0.severity,
                  symptoms: $0.symptomsRaw, bowelCount: $0.bowelCount, bowelType: $0.bowelType)
        }
        file.supplements = try context.fetch(FetchDescriptor<Supplement>()).map {
            .init(id: $0.id, name: $0.name, minutes: $0.minutes, weekdays: $0.weekdays, enabled: $0.enabled,
                  createdAt: $0.createdAt, dose: $0.dose, notes: $0.notes, startDate: $0.startDate, endDate: $0.endDate)
        }
        file.supplementLogs = try context.fetch(FetchDescriptor<SupplementLog>()).map {
            .init(supplementID: $0.supplementID, supplementName: $0.supplementName, date: $0.date, day: $0.day, taken: $0.taken)
        }
        file.personalFoods = PersonalFoods.all
        file.trials = try context.fetch(FetchDescriptor<FoodTrial>()).map {
            .init(food: $0.food, startDate: $0.startDate, result: $0.resultRaw, notes: $0.notes)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastBackupKey)
        return data
    }

    /// Replaces everything in the app with the contents of a backup file.
    @MainActor
    static func restore(from url: URL, context: ModelContext) throws {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(BackupFile.self, from: data)

        for old in try context.fetch(FetchDescriptor<Supplement>()) {
            NotificationManager.cancel(supplementID: old.id)
        }
        try context.delete(model: MealEntry.self)
        try context.delete(model: DailyCheck.self)
        try context.delete(model: Supplement.self)
        try context.delete(model: SupplementLog.self)
        try context.delete(model: FoodTrial.self)

        for m in file.meals {
            context.insert(MealEntry(date: m.date, text: m.text,
                                     status: FoodStatus(rawValue: m.status) ?? .unknown, symptomScore: m.symptomScore))
        }
        for c in file.checks {
            let check = DailyCheck(day: c.day, bloated: c.bloated, answered: c.answered)
            check.severity = c.severity
            check.symptomsRaw = c.symptoms
            check.bowelCount = c.bowelCount
            check.bowelType = c.bowelType
            context.insert(check)
        }
        var restored: [Supplement] = []
        for s in file.supplements {
            let supplement = Supplement(name: s.name, minutes: s.minutes, weekdays: s.weekdays, enabled: s.enabled)
            supplement.id = s.id
            supplement.createdAt = s.createdAt
            supplement.dose = s.dose
            supplement.notes = s.notes
            supplement.startDate = s.startDate
            supplement.endDate = s.endDate
            context.insert(supplement)
            restored.append(supplement)
        }
        for l in file.supplementLogs {
            let log = SupplementLog(supplementID: l.supplementID, supplementName: l.supplementName, taken: l.taken, date: l.date)
            log.day = l.day
            context.insert(log)
        }
        for t in file.trials ?? [] {
            let trial = FoodTrial(food: t.food, startDate: t.startDate)
            trial.resultRaw = t.result
            trial.notes = t.notes
            context.insert(trial)
        }
        if let personal = file.personalFoods { PersonalFoods.all = personal }
        try context.save()
        MealTimerStore.gapHours = file.gapHours
        NotificationManager.rescheduleAll(restored)
    }
}
