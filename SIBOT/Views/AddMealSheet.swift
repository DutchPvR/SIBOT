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
                        ForEach(FoodStatus.allCases) { Text("\($0.emoji) \($0.label)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("Filled in from the food list when it recognizes a word. You can change it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Toggle("Start the meal timer", isOn: $startTimer)
                } footer: {
                    Text("Only starts if the meal time is within the last hour.")
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

        let recent = abs(when.timeIntervalSinceNow) < 3600
        let shouldStart = startTimer && recent
        dismiss()
        if shouldStart {
            Task { await MealTimerController.start() }
        }
    }
}
