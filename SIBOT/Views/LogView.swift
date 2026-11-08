import SwiftData
import SwiftUI

enum LogMode: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }
}

/// The Log tab: switch between a day timeline, a week of blocks and a month calendar.
struct LogView: View {
    @Query(sort: \MealEntry.date) private var entries: [MealEntry]
    @Query(sort: \SupplementLog.date) private var supplementLogs: [SupplementLog]
    @Query private var dailyChecks: [DailyCheck]

    @State private var mode: LogMode = .day
    @State private var selected = Date()
    @State private var showingAdd = false

    private var calendar: Calendar { .current }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                VStack(spacing: 10) {
                    Picker("View", selection: $mode) {
                        ForEach(LogMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    header
                    content
                }
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
                AddMealSheet(initialDate: addDate)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { step(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Button { selected = Date() } label: {
                Text(title)
                    .font(.system(.headline))
                    .foregroundStyle(.primary)
            }
            Spacer()
            Button { step(1) } label: { Image(systemName: "chevron.right") }
        }
        .padding(.horizontal, 24)
        .tint(Theme.purple)
    }

    private var title: String {
        switch mode {
        case .day:
            return selected.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: selected) else { return "" }
            let last = calendar.date(byAdding: .day, value: 6, to: interval.start) ?? interval.start
            let start = interval.start.formatted(.dateTime.month(.abbreviated).day())
            let end = last.formatted(.dateTime.month(.abbreviated).day())
            return "\(start) – \(end)"
        case .month:
            return selected.formatted(.dateTime.month(.wide).year())
        }
    }

    private func step(_ direction: Int) {
        let component: Calendar.Component
        let value: Int
        switch mode {
        case .day: component = .day; value = direction
        case .week: component = .day; value = 7 * direction
        case .month: component = .month; value = direction
        }
        selected = calendar.date(byAdding: component, value: value, to: selected) ?? selected
    }

    /// New meals are stamped "now" on today, or midday when you are looking at another day.
    private var addDate: Date {
        if calendar.isDateInToday(selected) { return Date() }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: selected) ?? selected
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .day:
            DayLogView(
                day: selected,
                meals: entries.filter { calendar.isDate($0.date, inSameDayAs: selected) },
                supplementLogs: supplementLogs.filter { calendar.isDate($0.date, inSameDayAs: selected) },
                check: dailyChecks.first { calendar.isDate($0.day, inSameDayAs: selected) }
            )
        case .week:
            WeekLogView(anchor: selected, entries: entries, checks: dailyChecks, onSelectDay: openDay)
        case .month:
            MonthLogView(anchor: selected, entries: entries, checks: dailyChecks, onSelectDay: openDay)
        }
    }

    private func openDay(_ day: Date) {
        selected = day
        mode = .day
    }
}
