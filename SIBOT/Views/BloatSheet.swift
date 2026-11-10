import SwiftData
import SwiftUI

/// Log bloating at a time of day (how bad, which symptoms), or mark the day as "No bloat".
/// Pass an existing entry to edit it.
struct BloatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// The day, and the starting time for a new entry.
    let day: Date
    let episode: BloatEpisode?

    @State private var bloated: Bool
    @State private var when: Date
    @State private var severity: Int
    @State private var symptoms: Set<String>

    init(day: Date, episode: BloatEpisode? = nil, startsAsNoBloat: Bool = false) {
        self.day = day
        self.episode = episode
        _bloated = State(initialValue: !startsAsNoBloat)
        _when = State(initialValue: episode?.date ?? day)
        // 3 of 5 for a new entry, or one logged from the widget that has no rating yet.
        let saved = episode?.severity ?? 0
        _severity = State(initialValue: saved > 0 ? saved : 3)
        _symptoms = State(initialValue: Set(episode?.symptoms ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                if episode == nil {
                    Section {
                        Picker("Bloating", selection: $bloated) {
                            Text("Bloated").tag(true)
                            Text("No bloat").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                if bloated {
                    Section {
                        DatePicker("Time", selection: $when, displayedComponents: .hourAndMinute)
                    }

                    Section("How bad (1 mild, 5 severe)") {
                        Picker("How bad", selection: $severity) {
                            ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
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

                if let episode {
                    Section {
                        Button("Delete", role: .destructive) {
                            BloatLog.delete(episode, in: modelContext)
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
        }
    }

    private func save() {
        // Keep the usual order of symptoms.
        let ordered = DailyCheck.symptomOptions.filter { symptoms.contains($0) }
        if let episode {
            let oldDay = episode.date
            episode.date = when
            episode.severity = severity
            episode.symptoms = ordered
            BloatLog.syncDay(oldDay, in: modelContext)
            BloatLog.syncDay(when, in: modelContext)
        } else if bloated {
            BloatLog.add(at: when, severity: severity, symptoms: ordered, in: modelContext)
        } else {
            BloatLog.setNoBloat(on: day, in: modelContext)
        }
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
