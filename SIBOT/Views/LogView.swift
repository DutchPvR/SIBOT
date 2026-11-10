import SwiftData
import SwiftUI

enum LogEntryKind {
    case meal, bowel, bloat
}

/// The Log tab: one day as a timeline. Tap the date to pick another day from a calendar.
/// Only the day on screen is read from the database, so it stays fast as the diary grows.
struct LogView: View {
    /// Changes each time the Log tab is tapped: go to today and scroll to the current time.
    var jumpToNow = 0

    @State private var selected = Date()
    @State private var showingAdd = false
    @State private var addSeed = Date()
    @State private var showingBowel = false
    @State private var showingBloat = false
    @State private var showingCalendar = false

    private var calendar: Calendar { .current }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                VStack(spacing: 10) {
                    header
                    DayLogLoader(day: selected, scrollToken: jumpToNow, onAddAt: openAdd)
                }
            }
            .floatingButton { addButton }
            .tabHeader("Log")
            .onChange(of: jumpToNow) { _, _ in selected = Date() }
            .sheet(isPresented: $showingAdd) {
                AddMealSheet(initialDate: addSeed)
            }
            .sheet(isPresented: $showingBowel) {
                BowelSheet(initialDate: addSeed)
            }
            .sheet(isPresented: $showingBloat) {
                BloatSheet(day: addSeed)
            }
            .sheet(isPresented: $showingCalendar) { calendarSheet }
        }
    }

    /// A month calendar for jumping to any day.
    private var calendarSheet: some View {
        NavigationStack {
            DatePicker("Day", selection: $selected, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Theme.purple)
                .padding(.horizontal)
                .frame(maxHeight: .infinity, alignment: .top)
                .navigationTitle("Go to day")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Today") {
                            selected = Date()
                            showingCalendar = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingCalendar = false }
                    }
                }
                // Picking a day closes the calendar.
                .onChange(of: calendar.startOfDay(for: selected)) { _, _ in showingCalendar = false }
        }
        .presentationDetents([.medium, .large])
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
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { step(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous day")
            Spacer()
            Button { showingCalendar = true } label: {
                HStack(spacing: 6) {
                    Text(selected.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }
            }
            Spacer()
            Button { step(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next day")
                .disabled(calendar.isDateInToday(selected))
        }
        .padding(.horizontal, Theme.pageMargin)
        .padding(.top, Theme.titleGap)
        .tint(Theme.purple)
    }

    private func step(_ direction: Int) {
        selected = calendar.date(byAdding: .day, value: direction, to: selected) ?? selected
    }

    /// New meals are stamped "now" on today, or midday when you are looking at another day.
    private var addDate: Date {
        if calendar.isDateInToday(selected) { return Date() }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: selected) ?? selected
    }

    private func openAdd(_ date: Date, _ kind: LogEntryKind) {
        addSeed = date
        switch kind {
        case .meal: showingAdd = true
        case .bowel: showingBowel = true
        case .bloat: showingBloat = true
        }
    }
}

/// Reads one day's entries from the database.
private struct DayLogLoader: View {
    let day: Date
    let scrollToken: Int
    let onAddAt: (Date, LogEntryKind) -> Void

    @Query private var meals: [MealEntry]
    @Query private var supplementLogs: [SupplementLog]
    @Query private var bowelMovements: [BowelMovement]
    @Query private var bloatEpisodes: [BloatEpisode]
    @Query private var checks: [DailyCheck]

    init(day: Date, scrollToken: Int, onAddAt: @escaping (Date, LogEntryKind) -> Void) {
        self.day = day
        self.scrollToken = scrollToken
        self.onAddAt = onAddAt
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _meals = Query(filter: #Predicate<MealEntry> { $0.date >= start && $0.date < end }, sort: \.date)
        _supplementLogs = Query(filter: #Predicate<SupplementLog> { $0.date >= start && $0.date < end }, sort: \.date)
        _bowelMovements = Query(filter: #Predicate<BowelMovement> { $0.date >= start && $0.date < end }, sort: \.date)
        _bloatEpisodes = Query(filter: #Predicate<BloatEpisode> { $0.date >= start && $0.date < end }, sort: \.date)
        _checks = Query(filter: #Predicate<DailyCheck> { $0.day >= start && $0.day < end })
    }

    var body: some View {
        DayLogView(day: day, meals: meals, supplementLogs: supplementLogs,
                   bowelMovements: bowelMovements, bloatEpisodes: bloatEpisodes,
                   check: checks.first, scrollToken: scrollToken, onAddAt: onAddAt)
    }
}
