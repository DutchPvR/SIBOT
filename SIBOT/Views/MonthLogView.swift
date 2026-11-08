import SwiftUI

/// A month as a calendar grid. Each day is green, orange or red by the worst food that day.
struct MonthLogView: View {
    let anchor: Date
    let entries: [MealEntry]
    let onSelectDay: (Date) -> Void

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

                HStack(spacing: 14) {
                    legendItem(.safe, "All good")
                    legendItem(.limit, "Some limits")
                    legendItem(.avoid, "Not good")
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.2)).frame(width: 12, height: 12)
                        Text("Empty")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let meals = entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
        let worst = meals.worstStatus
        let isToday = calendar.isDateInToday(day)
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
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isToday ? Theme.purple : .clear, lineWidth: 2.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func legendItem(_ status: FoodStatus, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(status.color).frame(width: 12, height: 12)
            Text(text)
        }
    }
}
