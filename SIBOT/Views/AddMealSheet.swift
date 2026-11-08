import SwiftData
import SwiftUI

struct AddMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var text = ""
    @State private var status: FoodStatus = .unknown
    @State private var when: Date
    @State private var startTimer = true
    @FocusState private var textFocused: Bool

    init(initialDate: Date = Date()) {
        _when = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you eat?") {
                    TextField("e.g. chicken, rice and carrots", text: $text, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($textFocused)
                }
                Section("When") {
                    DatePicker("Time", selection: $when)
                }
                Section("How does it fit the diet?") {
                    Picker("Status", selection: $status) {
                        ForEach(FoodStatus.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("Filled in from the food list when it recognizes a word. You can change it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Toggle("Restart the fasting timer", isOn: $startTimer)
                } footer: {
                    Text("Counts up from the time above. Only applies if that time is in the past 24 hours or just now.")
                }
            }
            .navigationTitle("Log a meal")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { textFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: text) { _, newValue in
                status = FoodDatabase.shared.bestStatus(for: newValue) ?? .unknown
            }
        }
    }

    private func save() {
        let entry = MealEntry(
            date: when,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status
        )
        modelContext.insert(entry)

        // Only restart the timer for meals from the last 24 hours (or a few minutes ahead),
        // and never move it backwards past a more recent meal.
        let age = -when.timeIntervalSinceNow
        let lastMeal = MealTimerStore.startDate ?? .distantPast
        let shouldStart = startTimer && age < 24 * 3600 && age > -300 && when >= lastMeal
        let mealTime = min(when, Date())
        dismiss()
        if shouldStart {
            Task { await MealTimerController.start(at: mealTime) }
        }
    }
}
