import SwiftData
import SwiftUI

enum LogEntryKind {
    case meal, bowel, bloat
}

enum LogMode: String, CaseIterable, Identifiable {
    case day = "Day"
    case month = "Month"

    var id: String { rawValue }
}

/// The Log tab: switch between a day timeline and a month calendar. Tap a day in the month to open it.
/// Only the day or month on screen is read from the database, so it stays fast as the diary grows.
struct LogView: View {
    @State private var mode: LogMode = .day
    @State private var selected = Date()
    @State private var showingAdd = false
    @State private var addSeed = Date()
    @State private var showingBowel = false
    @State private var showingBloat = false

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
            .sheet(isPresented: $showingBloat) {
                BloatSheet(day: addSeed)
            }
        }
    }

    /// Floating add button, bottom right.
    private var addButton: some View {
        Menu {
            Button("Meal") { openAdd(addDate, .meal) }
            Button("Bowel movement") { openAdd(addDate, .bowel) }
            Button("Bloating") { openAdd(addDate, .bloat) }
        } label: {
            FloatingPlus()
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
        case .month:
            return selected.formatted(.dateTime.month(.wide).year())
        }
    }

    private func step(_ direction: Int) {
        let component: Calendar.Component
        let value: Int
        switch mode {
        case .day: component = .day; value = direction
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
            DayLogLoader(day: selected, onAddAt: openAdd)
        case .month:
            MonthLogLoader(anchor: selected, onSelectDay: openDay, onAddToDay: addOnDay)
        }
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
        case .bloat: showingBloat = true
        }
    }

    private func openDay(_ day: Date) {
        selected = day
        mode = .day
    }
}

/// Reads one day's entries from the database.
private struct DayLogLoader: View {
    let day: Date
    let onAddAt: (Date, LogEntryKind) -> Void

    @Query private var meals: [MealEntry]
    @Query private var supplementLogs: [SupplementLog]
    @Query private var bowelMovements: [BowelMovement]
    @Query private var checks: [DailyCheck]

    init(day: Date, onAddAt: @escaping (Date, LogEntryKind) -> Void) {
        self.day = day
        self.onAddAt = onAddAt
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _meals = Query(filter: #Predicate<MealEntry> { $0.date >= start && $0.date < end }, sort: \.date)
        _supplementLogs = Query(filter: #Predicate<SupplementLog> { $0.date >= start && $0.date < end }, sort: \.date)
        _bowelMovements = Query(filter: #Predicate<BowelMovement> { $0.date >= start && $0.date < end }, sort: \.date)
        _checks = Query(filter: #Predicate<DailyCheck> { $0.day >= start && $0.day < end })
    }

    var body: some View {
        DayLogView(day: day, meals: meals, supplementLogs: supplementLogs,
                   bowelMovements: bowelMovements, check: checks.first, onAddAt: onAddAt)
    }
}

/// Reads one month's meals and bloat answers from the database.
private struct MonthLogLoader: View {
    let anchor: Date
    let onSelectDay: (Date) -> Void
    let onAddToDay: (Date, LogEntryKind) -> Void

    @Query private var meals: [MealEntry]
    @Query private var checks: [DailyCheck]

    init(anchor: Date, onSelectDay: @escaping (Date) -> Void, onAddToDay: @escaping (Date, LogEntryKind) -> Void) {
        self.anchor = anchor
        self.onSelectDay = onSelectDay
        self.onAddToDay = onAddToDay
        let month = Calendar.current.dateInterval(of: .month, for: anchor)
        let start = month?.start ?? anchor
        let end = month?.end ?? anchor
        _meals = Query(filter: #Predicate<MealEntry> { $0.date >= start && $0.date < end }, sort: \.date)
        _checks = Query(filter: #Predicate<DailyCheck> { $0.day >= start && $0.day < end })
    }

    var body: some View {
        let calendar = Calendar.current
        MonthLogView(
            anchor: anchor,
            mealsByDay: Dictionary(grouping: meals) { calendar.startOfDay(for: $0.date) },
            checksByDay: Dictionary(checks.map { (calendar.startOfDay(for: $0.day), $0) },
                                    uniquingKeysWith: { first, _ in first }),
            onSelectDay: onSelectDay,
            onAddToDay: onAddToDay
        )
    }
}
