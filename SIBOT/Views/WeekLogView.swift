import SwiftUI

/// A week as seven rows, each with one colored block per meal.
struct WeekLogView: View {
    let anchor: Date
    let entries: [MealEntry]
    let onSelectDay: (Date) -> Void

    private var calendar: Calendar { .current }

    private var days: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: anchor) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(days, id: \.self) { day in
                    dayRow(day)
                }
                legend
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func dayRow(_ day: Date) -> some View {
        let meals = entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
        let worst = meals.worstStatus
        let isToday = calendar.isDateInToday(day)

        return Button {
            onSelectDay(day)
        } label: {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(isToday ? Theme.grape : .secondary)
                    Text(day.formatted(.dateTime.day()))
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(.primary)
                }
                .frame(width: 44)

                if meals.isEmpty {
                    Text("Nothing logged")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    // One block per meal, in time order. Wraps if there are many.
                    let blocks = meals.sorted { $0.date < $1.date }
                    HStack(spacing: 6) {
                        ForEach(blocks.prefix(8)) { meal in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(meal.status.color)
                                .frame(width: 24, height: 24)
                        }
                        if blocks.count > 8 {
                            Text("+\(blocks.count - 8)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill((worst?.color ?? Color.secondary).opacity(worst == nil ? 0.25 : 1))
                    .frame(width: 5)
                    .padding(.vertical, 10)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isToday ? Theme.grape.opacity(0.6) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(.safe)
            legendItem(.limit)
            legendItem(.avoid)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    private func legendItem(_ status: FoodStatus) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(status.color).frame(width: 12, height: 12)
            Text(status.label)
        }
    }
}
