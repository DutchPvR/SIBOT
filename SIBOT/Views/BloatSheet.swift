import SwiftData
import SwiftUI

/// Log or edit the day's bloating: bloated or not, how bad, and symptoms. One entry per day.
struct BloatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var checks: [DailyCheck]

    let day: Date

    // Defaults for a new entry: bloated, 3 of 5, no symptoms.
    @State private var bloated = true
    @State private var severity = 3
    @State private var symptoms: Set<String> = []
    @State private var loaded = false

    private var existing: DailyCheck? {
        checks.first { Calendar.current.isDate($0.day, inSameDayAs: day) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Bloating", selection: $bloated) {
                        Text("Bloated").tag(true)
                        Text("No bloat").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if bloated {
                    Section {
                        Picker("How bad", selection: $severity) {
                            ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    } header: {
                        Text("How bad")
                    } footer: {
                        Text("1 mild, 5 severe")
                    }

                    Section("Symptoms") {
                        ForEach(DailyCheck.symptomOptions, id: \.self) { symptom in
                            Button {
                                if symptoms.contains(symptom) { symptoms.remove(symptom) } else { symptoms.insert(symptom) }
                            } label: {
                                HStack {
                                    Text(symptom).foregroundStyle(Color.primary)
                                    Spacer()
                                    if symptoms.contains(symptom) {
                                        Image(systemName: "checkmark").foregroundStyle(Theme.purple)
                                    }
                                }
                            }
                        }
                    }
                }

                if existing?.answered == true {
                    Section {
                        Button("Delete", role: .destructive) {
                            clear()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
            .navigationBarTitleDisplayMode(.inline)
            .groupedPage()
            .tint(Theme.purple)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let existing, existing.answered else { return }
        bloated = existing.bloated
        if existing.severity > 0 { severity = existing.severity }
        symptoms = Set(existing.symptoms)
    }

    private func save() {
        let entry: DailyCheck
        if let existing {
            entry = existing
        } else {
            entry = DailyCheck(day: day, bloated: bloated)
            modelContext.insert(entry)
        }
        entry.bloated = bloated
        entry.answered = true
        entry.severity = bloated ? severity : 0
        // Keep the usual order of symptoms.
        entry.symptoms = bloated ? DailyCheck.symptomOptions.filter { symptoms.contains($0) } : []
    }

    private func clear() {
        guard let existing else { return }
        existing.answered = false
        existing.severity = 0
        existing.symptoms = []
        if existing.isEmpty { modelContext.delete(existing) }
    }
}

extension DailyCheck {
    /// One line for the Day page, e.g. "Bloated · 3/5 · Gas, Pain".
    var summaryText: String {
        guard bloated else { return "No bloat" }
        var parts = ["Bloated"]
        if severity > 0 { parts.append("\(severity)/5") }
        if !symptoms.isEmpty { parts.append(symptoms.joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }
}

/// Ring = no bloat, filled dot = bloated. Used on the Day page and in the month calendar.
struct BloatMark: View {
    let bloated: Bool
    var color: Color = .primary
    var size: CGFloat = 10

    var body: some View {
        ZStack {
            Circle().strokeBorder(color, lineWidth: 1.5)
            if bloated { Circle().fill(color) }
        }
        .frame(width: size, height: size)
    }
}
