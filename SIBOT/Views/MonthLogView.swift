import SwiftUI

/// A month as a calendar grid. Each day is green, orange or red by the worst food that day.
struct MonthLogView: View {
    let anchor: Date
    let mealsByDay: [Date: [MealEntry]]
    let checksByDay: [Date: DailyCheck]
    let onSelectDay: (Date) -> Void
    let onAddToDay: (Date) -> Void

    private var calendar: Calendar { .current }

    private var monthDays: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: anchor) else { return [] }
        let count = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 30
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    /// Empty cells before the 1st so days line up under the right weekday.
    private var leadingBlanks: Int {
        guard let first = monthDays.first else { return 0 }
        let weekday = calendar.component(.weekday, from: first)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var weekdayHeaders: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.system(.caption).weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(0..<leadingBlanks, id: \.self) { _ in
                        Color.clear.frame(height: 46)
                    }
                    ForEach(monthDays, id: \.self) { day in
                        dayCell(day)
                    }
                }

                HStack(spacing: 12) {
                    legendItem(.safe, "Good")
                    legendItem(.limit, "Limits")
                    legendItem(.avoid, "Not good")
                    HStack(spacing: 4) { BloatMark(bloated: true, size: 8); Text("Bloated") }
                    HStack(spacing: 4) { BloatMark(bloated: false, size: 8); Text("No bloat") }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let worst = (mealsByDay[day] ?? []).worstStatus
        let isToday = calendar.isDateInToday(day)
        let check = checksByDay[day]
        let fill: Color = {
            guard let worst else { return Color.secondary.opacity(0.15) }
            return worst == .unknown ? Color.secondary.opacity(0.5) : worst.color
        }()

        return Button {
            onSelectDay(day)
        } label: {
            Text(day.formatted(.dateTime.day()))
                .font(.system(.subheadline).weight(.bold))
                .foregroundStyle(worst == nil ? Color.primary : Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(fill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(alignment: .bottom) {
                    if let bloated = check?.answer {
                        BloatMark(bloated: bloated, color: worst == nil ? .primary : .white, size: 8)
                            .padding(.bottom, 5)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isToday ? Theme.purple : .clear, lineWidth: 2.5)
                )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onAddToDay(day) } label: { Label("Add entry", systemImage: "plus") }
        }
    }

    private func legendItem(_ status: FoodStatus, _ text: String) -> some View {
        HStack(spacing: 4) {
            StatusDot(status: status, size: 8)
            Text(text)
        }
    }
}
