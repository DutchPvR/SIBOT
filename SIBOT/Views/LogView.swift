import SwiftData
import SwiftUI

enum LogEntryKind {
    case meal, bowel
}

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
    @Query(sort: \BowelMovement.date) private var bowelMovements: [BowelMovement]

    @State private var mode: LogMode = .day
    @State private var selected = Date()
    @State private var showingAdd = false
    @State private var addSeed = Date()
    @State private var showingBowel = false

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
                // Room under the last item so the floating button never covers it.
                .contentMargins(.bottom, 80, for: .scrollContent)
            }
            .overlay(alignment: .bottomTrailing) { addButton }
            .tabHeader("Log")
            .sheet(isPresented: $showingAdd) {
                AddMealSheet(initialDate: addSeed)
            }
            .sheet(isPresented: $showingBowel) {
                BowelSheet(initialDate: addSeed)
            }
        }
    }

    /// Floating add button, bottom right.
    private var addButton: some View {
        Menu {
            Button("Meal") { openAdd(addDate, .meal) }
            Button("Bowel movement") { openAdd(addDate, .bowel) }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Theme.purple))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .accessibilityLabel("Add")
        .padding(.trailing, 20)
        .padding(.bottom, 16)
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
            let day = calendar.startOfDay(for: selected)
            DayLogView(
                day: selected,
                meals: entries.filter { calendar.isDate($0.date, inSameDayAs: day) },
                supplementLogs: supplementLogs.filter { calendar.isDate($0.date, inSameDayAs: day) },
                bowelMovements: bowelMovements.filter { calendar.isDate($0.date, inSameDayAs: day) },
                check: dailyChecks.first { calendar.isDate($0.day, inSameDayAs: day) },
                onAddAt: openAdd
            )
        case .week:
            WeekLogView(anchor: selected, mealsByDay: mealsByDay, checksByDay: checksByDay,
                        onSelectDay: openDay, onAddToDay: addOnDay)
        case .month:
            MonthLogView(anchor: selected, mealsByDay: mealsByDay, checksByDay: checksByDay,
                         onSelectDay: openDay, onAddToDay: addOnDay)
        }
    }

    /// Meals grouped by day once, so the week and month views do not scan every meal per cell.
    private var mealsByDay: [Date: [MealEntry]] {
        Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
    }

    private var checksByDay: [Date: DailyCheck] {
        Dictionary(dailyChecks.map { (calendar.startOfDay(for: $0.day), $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Long press on a day: add an entry for it (now if it is today, otherwise midday).
    private func addOnDay(_ day: Date, _ kind: LogEntryKind) {
        if calendar.isDateInToday(day) {
            openAdd(Date(), kind)
        } else {
            openAdd(calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day, kind)
        }
    }

    private func openAdd(_ date: Date, _ kind: LogEntryKind) {
        addSeed = date
        switch kind {
        case .meal: showingAdd = true
        case .bowel: showingBowel = true
        }
    }

    private func openDay(_ day: Date) {
        selected = day
        mode = .day
    }
}
