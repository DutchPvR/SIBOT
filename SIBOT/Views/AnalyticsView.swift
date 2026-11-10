import Charts
import SwiftData
import SwiftUI

/// A first, simple look at the diary: bloating over time, when it starts, and foods that tend to come before it.
struct AnalyticsView: View {
    @State private var days = 30

    var body: some View {
        Form {
            Section {
                Picker("Period", selection: $days) {
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                .pickerStyle(.segmented)
            }
            AnalyticsContent(days: days)
                // A new period reads a new range from the database.
                .id(days)
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .groupedPage()
    }
}

private struct AnalyticsContent: View {
    let days: Int
    private let start: Date

    @Query private var checks: [DailyCheck]
    @Query private var episodes: [BloatEpisode]
    @Query private var meals: [MealEntry]

    /// Worked out when the data changes, not on every redraw.
    @State private var insight = InsightResult.empty

    init(days: Int) {
        self.days = days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        self.start = start
        // Meals from two days earlier, because the trigger analysis looks back that far.
        let mealStart = calendar.date(byAdding: .day, value: -2, to: start) ?? start
        _checks = Query(filter: #Predicate<DailyCheck> { $0.day >= start }, sort: \.day)
        _episodes = Query(filter: #Predicate<BloatEpisode> { $0.date >= start }, sort: \.date)
        _meals = Query(filter: #Predicate<MealEntry> { $0.date >= mealStart }, sort: \.date)
    }

    private var answered: [DailyCheck] { checks.filter(\.answered) }
    private var bloatedDays: [DailyCheck] { answered.filter(\.bloated) }

    var body: some View {
        Group {
            if answered.isEmpty {
                Section {
                    Text("Nothing to show yet. Log bloating or \"No bloat\" for a few days.")
                        .foregroundStyle(.secondary)
                }
            } else {
                summary
                bloatingChart
                if !episodes.isEmpty { timeOfDayChart }
                triggers
            }
        }
        .task(id: [meals.count, checks.count, episodes.count]) {
            insight = Insights.analyze(meals: meals, checks: checks, episodes: episodes)
        }
    }

    private var summary: some View {
        Section("Summary") {
            LabeledContent("Days answered", value: "\(answered.count) of \(days)")
            LabeledContent("Bloated days", value: "\(bloatedDays.count)")
            LabeledContent("No-bloat days", value: "\(answered.count - bloatedDays.count)")
            let rated = bloatedDays.filter { $0.severity > 0 }
            if !rated.isEmpty {
                let average = Double(rated.map(\.severity).reduce(0, +)) / Double(rated.count)
                LabeledContent("Average severity", value: String(format: "%.1f of 5", average))
            }
        }
    }

    /// One bar per answered day: its worst bloating that day, 0 for a clear day.
    private var bloatingChart: some View {
        Section {
            Chart(answered) { check in
                BarMark(
                    x: .value("Day", check.day, unit: .day),
                    // A bloated day with no rating still shows as a short bar.
                    y: .value("Severity", check.bloated ? max(check.severity, 1) : 0)
                )
                .foregroundStyle(Theme.purple)
            }
            .chartXScale(domain: start...Date())
            .chartYScale(domain: 0...5)
            .chartYAxis { AxisMarks(values: [0, 1, 2, 3, 4, 5]) }
            .frame(height: 160)
            .padding(.vertical, 8)
            .accessibilityLabel("Bloating severity by day")
        } header: {
            Text("Bloating by day")
        } footer: {
            Text("Worst severity each day, 1 to 5. No bar means a clear day or no answer.")
        }
    }

    /// How many bloating entries started in each hour of the day.
    private var timeOfDayChart: some View {
        let counts = Dictionary(grouping: episodes) { Calendar.current.component(.hour, from: $0.date) }
            .map { HourCount(hour: $0.key, count: $0.value.count) }
            .sorted { $0.hour < $1.hour }
        return Section("When bloating starts") {
            Chart(counts) { item in
                BarMark(x: .value("Hour", item.hour), y: .value("Entries", item.count), width: .fixed(8))
                    .foregroundStyle(Theme.purple)
            }
            .chartXScale(domain: 0...23)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let hour = value.as(Int.self) { Text(Self.hourLabel(hour)) }
                    }
                }
            }
            .frame(height: 120)
            .padding(.vertical, 8)
            .accessibilityLabel("Bloating entries by hour of day")
        }
    }

    private var triggers: some View {
        Section {
            if !insight.hasEnoughData {
                Text("Log at least 3 bloated and 3 clear days to see patterns.")
                    .foregroundStyle(.secondary)
            } else if insight.suspects.isEmpty {
                Text("No food stands out yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(insight.suspects) { suspect in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(suspect.food.capitalized).font(.headline)
                        shareBar("Before bloated days", suspect.bloatedWindows, of: insight.bloatedDays, color: Theme.purple)
                        shareBar("Before clear days", suspect.clearWindows, of: insight.clearDays, color: .secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Possible triggers")
        } footer: {
            Text("Foods eaten in the 2 days before bloating, compared with clear days. Patterns, not causes.")
        }
    }

    private func shareBar(_ label: String, _ count: Int, of total: Int, color: Color) -> some View {
        let share = total > 0 ? Double(count) / Double(total) : 0
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                Spacer()
                Text("\(count) of \(total)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            ProgressView(value: share).tint(color)
        }
    }

    private struct HourCount: Identifiable {
        let hour: Int
        let count: Int
        var id: Int { hour }
    }

    private static func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(.dateTime.hour())
    }
}
