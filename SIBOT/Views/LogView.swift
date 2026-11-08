import Charts
import SwiftData
import SwiftUI

struct LogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealEntry.date, order: .reverse) private var entries: [MealEntry]

    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                List {
                    if !recentEntries.isEmpty {
                        Section {
                            chart
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    Section("Meals") {
                        if entries.isEmpty {
                            Text("Nothing logged yet. Tap + to add a meal.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(entries) { entry in
                            row(entry)
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(entries[index]) }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddMealSheet()
            }
        }
    }

    private var recentEntries: [MealEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return entries.filter { $0.date >= cutoff }
    }

    // MARK: - Chart

    private struct DayCount: Identifiable {
        let id = UUID()
        let day: Date
        let status: FoodStatus
        let count: Int
    }

    private struct DaySymptom: Identifiable {
        let id = UUID()
        let day: Date
        let average: Double
    }

    private var dayCounts: [DayCount] {
        let calendar = Calendar.current
        var counts: [String: DayCount] = [:]
        for entry in recentEntries {
            let day = calendar.startOfDay(for: entry.date)
            let key = "\(day.timeIntervalSince1970)-\(entry.statusRaw)"
            let existing = counts[key]?.count ?? 0
            counts[key] = DayCount(day: day, status: entry.status, count: existing + 1)
        }
        return Array(counts.values)
    }

    private var daySymptoms: [DaySymptom] {
        let calendar = Calendar.current
        var grouped: [Date: [Int]] = [:]
        for entry in recentEntries {
            if let score = entry.symptomScore {
                grouped[calendar.startOfDay(for: entry.date), default: []].append(score)
            }
        }
        return grouped
            .map { DaySymptom(day: $0.key, average: Double($0.value.reduce(0, +)) / Double($0.value.count)) }
            .sorted { $0.day < $1.day }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 14 days")
                .font(.system(.headline, design: .rounded))

            Chart(dayCounts) { item in
                BarMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("Meals", item.count)
                )
                .foregroundStyle(by: .value("Status", item.status.label))
            }
            .chartForegroundStyleScale([
                FoodStatus.safe.label: FoodStatus.safe.color,
                FoodStatus.limit.label: FoodStatus.limit.color,
                FoodStatus.avoid.label: FoodStatus.avoid.color,
                FoodStatus.unknown.label: FoodStatus.unknown.color
            ])
            .frame(height: 140)

            if !daySymptoms.isEmpty {
                Text("Average symptoms (1 fine – 5 rough)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Chart(daySymptoms) { item in
                    LineMark(
                        x: .value("Day", item.day, unit: .day),
                        y: .value("Symptoms", item.average)
                    )
                    .foregroundStyle(Theme.pink)
                    PointMark(
                        x: .value("Day", item.day, unit: .day),
                        y: .value("Symptoms", item.average)
                    )
                    .foregroundStyle(Theme.pink)
                }
                .chartYScale(domain: 1...5)
                .frame(height: 110)
            }
        }
        .card()
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Rows

    private func row(_ entry: MealEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.text)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Spacer()
                StatusBadge(status: entry.status)
            }
            HStack {
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach(1...5, id: \.self) { score in
                        Button(symptomLabel(score)) { entry.symptomScore = score }
                    }
                    if entry.symptomScore != nil {
                        Button("Clear rating", role: .destructive) { entry.symptomScore = nil }
                    }
                } label: {
                    Label(
                        entry.symptomScore.map { "Symptoms: \($0)/5" } ?? "Rate symptoms",
                        systemImage: "waveform.path.ecg"
                    )
                    .font(.caption.weight(.semibold))
                }
                .tint(Theme.pink)
            }
        }
        .padding(.vertical, 2)
    }

    private func symptomLabel(_ score: Int) -> String {
        switch score {
        case 1: return "1 – Feeling fine"
        case 2: return "2 – Slight"
        case 3: return "3 – Noticeable"
        case 4: return "4 – Bad"
        default: return "5 – Very bad"
        }
    }
}

struct AddMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var text = ""
    @State private var status: FoodStatus = .unknown
    @State private var startTimer = true

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you eat?") {
                    TextField("e.g. chicken, rice and carrots", text: $text, axis: .vertical)
                        .lineLimit(1...4)
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
                }
            }
            .navigationTitle("Log a meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: text) { _, newValue in
                if let match = FoodDatabase.shared.bestStatus(for: newValue) {
                    status = match
                } else {
                    status = .unknown
                }
            }
        }
    }

    private func save() {
        let entry = MealEntry(text: text.trimmingCharacters(in: .whitespacesAndNewlines), status: status)
        modelContext.insert(entry)
        let shouldStart = startTimer
        dismiss()
        if shouldStart {
            Task { await MealTimerController.start() }
        }
    }
}
