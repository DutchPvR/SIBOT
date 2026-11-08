import Foundation
import SwiftUI
import SwiftData

/// One bowel movement, logged at a time like a meal.
@Model
final class BowelMovement {
    var date: Date
    /// Bristol stool type 1...7; 0 means not set.
    var type: Int

    init(date: Date = Date(), type: Int = 0) {
        self.date = date
        self.type = type
    }

    static let typeNames = [
        1: "Separate hard lumps", 2: "Lumpy sausage", 3: "Sausage with cracks",
        4: "Smooth sausage", 5: "Soft blobs", 6: "Mushy", 7: "Watery"
    ]

    var typeText: String {
        type == 0 ? "Bowel movement" : "Bowel movement · type \(type)"
    }

    /// The bowel counts that used to live on the daily check become timed entries (once).
    @MainActor
    static func migrateFromDailyChecks(_ context: ModelContext) {
        guard let checks = try? context.fetch(FetchDescriptor<DailyCheck>()) else { return }
        for check in checks where check.bowelCount > 0 || check.bowelType > 0 {
            let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: check.day) ?? check.day
            for _ in 0..<max(check.bowelCount, 1) {
                context.insert(BowelMovement(date: noon, type: check.bowelType))
            }
            check.bowelCount = 0
            check.bowelType = 0
            if !check.answered { context.delete(check) }
        }
        try? context.save()
    }
}

/// Add or edit a bowel movement: time and stool type.
struct BowelSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let existing: BowelMovement?
    @State private var when: Date
    @State private var type: Int

    init(initialDate: Date = Date(), existing: BowelMovement? = nil) {
        self.existing = existing
        _when = State(initialValue: existing?.date ?? initialDate)
        _type = State(initialValue: existing?.type ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $when)
                }
                Section("Type") {
                    Picker("Type", selection: $type) {
                        Text("Not set").tag(0)
                        ForEach(1...7, id: \.self) { value in
                            Text("\(value) – \(BowelMovement.typeNames[value] ?? "")").tag(value)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle(existing == nil ? "Bowel movement" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let existing {
                            existing.date = when
                            existing.type = type
                        } else {
                            modelContext.insert(BowelMovement(date: when, type: type))
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
