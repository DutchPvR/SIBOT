import SwiftData
import SwiftUI

struct RemindersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Supplement.minutes) private var supplements: [Supplement]
    /// Only recent answers are needed here (today, the 14-day count and the short history).
    @Query(RemindersView.recentLogs) private var logs: [SupplementLog]

    nonisolated private static var recentLogs: FetchDescriptor<SupplementLog> {
        var descriptor = FetchDescriptor<SupplementLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 300
        return descriptor
    }

    @State private var editing: Supplement?
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                List {
                    Section("Today") {
                        if supplements.isEmpty {
                            Text("No reminders yet. Tap + to add a supplement.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(supplements) { supplement in
                            supplementRow(supplement)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                let supplement = supplements[index]
                                NotificationManager.cancel(supplementID: supplement.id)
                                modelContext.delete(supplement)
                            }
                        }
                    }

                    if !logs.isEmpty {
                        Section("History") {
                            ForEach(logs.prefix(20)) { log in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(log.supplementName)
                                            .font(.system(.body).weight(.semibold))
                                        Text(log.day.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(log.taken ? "Taken" : "Skipped")
                                        .font(.subheadline.weight(log.taken ? .semibold : .regular))
                                        .foregroundStyle(log.taken ? Color.primary : Color.secondary)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNew) {
                SupplementEditSheet(supplement: nil)
            }
            .sheet(item: $editing) { supplement in
                SupplementEditSheet(supplement: supplement)
            }
        }
    }

    private func todaysLog(for supplement: Supplement) -> SupplementLog? {
        logs.first { $0.supplementID == supplement.id && Calendar.current.isDateInToday($0.day) }
    }

    private func supplementRow(_ supplement: Supplement) -> some View {
        let log = todaysLog(for: supplement)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(supplement.name)
                        .font(.system(.headline))
                    Text(([supplement.dose.isEmpty ? nil : supplement.dose, supplement.timeText, supplement.daysText] as [String?])
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let course = supplement.courseText {
                        Text(course)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.purple)
                    }
                    let stats = supplement.adherence(logs: logs)
                    if stats.expected > 0 {
                        Text("Taken \(stats.taken) of the last \(stats.expected) days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !supplement.enabled {
                        Text("Paused")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    editing = supplement
                } label: {
                    Text("Edit")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
                .tint(Theme.purple)
            }

            HStack(spacing: 10) {
                answerButton(title: "Taken", selected: log?.taken == true) {
                    SupplementLogger.record(
                        supplementID: supplement.id, name: supplement.name, taken: true, in: modelContext)
                }
                answerButton(title: "Skipped", selected: log?.taken == false) {
                    SupplementLogger.record(
                        supplementID: supplement.id, name: supplement.name, taken: false, in: modelContext)
                }
                if log != nil {
                    Button("Clear") {
                        SupplementLogger.clearToday(supplementID: supplement.id, in: modelContext)
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Outlined, like the bloat buttons; the chosen answer gets a dark outline and bold text.
    private func answerButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .heavy : .medium))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(selected ? Color.primary : Theme.hairline, lineWidth: selected ? 1.5 : 1)
                )
        }
        .buttonStyle(.borderless)
    }
}

struct SupplementEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let supplement: Supplement?

    @State private var name: String
    @State private var time: Date
    @State private var weekdays: Set<Int>
    @State private var enabled: Bool
    @State private var dose: String
    @State private var notes: String
    @State private var hasStart: Bool
    @State private var start: Date
    @State private var hasEnd: Bool
    @State private var end: Date
    @FocusState private var nameFocused: Bool

    init(supplement: Supplement?) {
        self.supplement = supplement
        let minutes = supplement?.minutes ?? 22 * 60
        _name = State(initialValue: supplement?.name ?? "")
        _time = State(initialValue: Calendar.current.date(
            bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date())
        _weekdays = State(initialValue: Set(supplement?.weekdays ?? Array(1...7)))
        _enabled = State(initialValue: supplement?.enabled ?? true)
        _dose = State(initialValue: supplement?.dose ?? "")
        _notes = State(initialValue: supplement?.notes ?? "")
        _hasStart = State(initialValue: supplement?.startDate != nil)
        _start = State(initialValue: supplement?.startDate ?? Date())
        _hasEnd = State(initialValue: supplement?.endDate != nil)
        _end = State(initialValue: supplement?.endDate ?? Calendar.current.date(byAdding: .day, value: 13, to: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Supplement") {
                    TextField("Name, e.g. Ginger pills", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { nameFocused = false }
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    TextField("Dose, e.g. 500 mg", text: $dose)
                        .focused($nameFocused)
                    TextField("Notes, e.g. with food", text: $notes, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($nameFocused)
                }

                Section {
                    Toggle("Start date", isOn: $hasStart)
                    if hasStart { DatePicker("Starts", selection: $start, displayedComponents: .date) }
                    Toggle("End date", isOn: $hasEnd)
                    if hasEnd { DatePicker("Ends", selection: $end, in: start..., displayedComponents: .date) }
                } header: {
                    Text("Course")
                } footer: {
                    Text("For a prescription with a fixed length. Reminders stop after the end date.")
                }

                Section {
                    dayPicker
                    Button("Every day") { weekdays = Set(1...7) }
                        .font(.subheadline)
                } header: {
                    Text("Days")
                }

                Section {
                    Toggle("Reminder on", isOn: $enabled)
                }
            }
            .navigationTitle(supplement == nil ? "New reminder" : "Edit reminder")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { nameFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || weekdays.isEmpty)
                }
            }
        }
    }

    private var dayPicker: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                let selected = weekdays.contains(weekday)
                Button {
                    if selected { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
                } label: {
                    Text(symbols[weekday - 1])
                        .font(.system(.subheadline).weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(selected ? Theme.purple : Theme.purple.opacity(0.12), in: Circle())
                        .foregroundStyle(selected ? Color.white : Theme.purple)
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let minutes = (parts.hour ?? 22) * 60 + (parts.minute ?? 0)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sortedDays = weekdays.sorted()

        let target: Supplement
        if let supplement {
            supplement.name = trimmed
            supplement.minutes = minutes
            supplement.weekdays = sortedDays
            supplement.enabled = enabled
            supplement.dose = dose.trimmingCharacters(in: .whitespacesAndNewlines)
            supplement.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            supplement.startDate = hasStart ? start : nil
            supplement.endDate = hasEnd ? end : nil
            target = supplement
        } else {
            target = Supplement(name: trimmed, minutes: minutes, weekdays: sortedDays, enabled: enabled)
            target.dose = dose.trimmingCharacters(in: .whitespacesAndNewlines)
            target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            target.startDate = hasStart ? start : nil
            target.endDate = hasEnd ? end : nil
            modelContext.insert(target)
        }
        try? modelContext.save()
        NotificationManager.schedule(target)
        dismiss()
    }
}
