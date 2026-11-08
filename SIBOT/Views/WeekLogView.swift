import SwiftUI

/// A week as seven plain rows: one dot per item, and the bloat answer on the right.
struct WeekLogView: View {
    let anchor: Date
    let mealsByDay: [Date: [MealEntry]]
    let checksByDay: [Date: DailyCheck]
    let onSelectDay: (Date) -> Void
    let onAddToDay: (Date, LogEntryKind) -> Void

    private var calendar: Calendar { .current }

    private var days: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: anchor) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    Hairline()
                    dayRow(day)
                }
                Hairline()
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func dayRow(_ day: Date) -> some View {
        let meals = (mealsByDay[day] ?? []).sorted { $0.date < $1.date }
        let isToday = calendar.isDateInToday(day)
        let bloated = checksByDay[day]?.answer

        return Button {
            onSelectDay(day)
        } label: {
            HStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(isToday ? Theme.purple : .secondary)
                    Text(day.formatted(.dateTime.day()))
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(isToday ? Theme.purple : .primary)
                }
                .frame(width: 40)

                HStack(spacing: 5) {
                    ForEach(meals.prefix(10)) { meal in
                        StatusDot(status: meal.status, size: 10)
                    }
                    if meals.count > 10 {
                        Text("+\(meals.count - 10)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if let bloated {
                    BloatMark(bloated: bloated)
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Add meal") { onAddToDay(day, .meal) }
            Button("Add bowel movement") { onAddToDay(day, .bowel) }
        }
    }
}

/// Ring = no bloat, filled dot = bloated. Used across the Log.
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
