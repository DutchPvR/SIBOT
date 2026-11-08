import SwiftData
import SwiftUI

/// One day as horizontal hour rows. Scroll up and down through the day.
struct DayLogView: View {
    @Environment(\.modelContext) private var modelContext

    let day: Date
    let meals: [MealEntry]
    let supplementLogs: [SupplementLog]
    let bowelMovements: [BowelMovement]
    let check: DailyCheck?
    let onAddAt: (Date, LogEntryKind) -> Void

    @State private var editingMeal: MealEntry?
    @State private var addingTo: Date?
    @State private var editingBowel: BowelMovement?

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(spacing: 0) {
            BloatCheckBar(day: day, check: check)
            timeline
        }
        .sheet(item: $editingMeal) { EditMealSheet(meal: $0) }
        .sheet(item: $editingBowel) { BowelSheet(existing: $0) }
        .sheet(isPresented: Binding(get: { addingTo != nil }, set: { if !$0 { addingTo = nil } })) {
            AddMealSheet(initialDate: addingTo ?? Date(), title: "Add to this meal")
        }
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        hourRow(hour)
                            .id(hour)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .onAppear { scroll(proxy) }
            .onChange(of: day) { _, _ in scroll(proxy) }
        }
    }

    /// Start near the first meal of the day, or the current hour, or morning for other days.
    private func scroll(_ proxy: ScrollViewProxy) {
        let target: Int
        if let first = meals.map({ calendar.component(.hour, from: $0.date) }).min() {
            target = max(first - 1, 0)
        } else if calendar.isDateInToday(day) {
            target = max(calendar.component(.hour, from: Date()) - 1, 0)
        } else {
            target = 6
        }
        DispatchQueue.main.async {
            proxy.scrollTo(target, anchor: .top)
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        return date.formatted(.dateTime.hour())
    }

    private func hourRow(_ hour: Int) -> some View {
        let hourMeals = meals.filter { calendar.component(.hour, from: $0.date) == hour }
        let hourSupplements = supplementLogs.filter { calendar.component(.hour, from: $0.date) == hour }
        let hourBowel = bowelMovements.filter { calendar.component(.hour, from: $0.date) == hour }

        return HStack(alignment: .top, spacing: 10) {
            Text(hourLabel(hour))
                .font(.system(.caption).weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(hourMeals) { meal in
                    mealPill(meal)
                }
                ForEach(hourBowel) { movement in
                    bowelRow(movement)
                }
                ForEach(hourSupplements) { log in
                    supplementPill(log)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            .padding(.vertical, 6)
            .overlay(alignment: .top) {
                Hairline()
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            let time = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
            Button("Add meal at \(hourLabel(hour))") { onAddAt(time, .meal) }
            Button("Add bowel movement at \(hourLabel(hour))") { onAddAt(time, .bowel) }
        }
    }

    private func mealPill(_ meal: MealEntry) -> some View {
        Menu {
            Section("Symptoms after this meal") {
                ForEach(1...5, id: \.self) { score in
                    Button(symptomLabel(score)) { meal.symptomScore = score }
                }
                if meal.symptomScore != nil {
                    Button("Clear rating") { meal.symptomScore = nil }
                }
            }
            Button { editingMeal = meal } label: { Label("Edit", systemImage: "pencil") }
            Button { addingTo = meal.date } label: { Label("Add another item", systemImage: "plus") }
            Button("Delete", role: .destructive) { modelContext.delete(meal) }
        } label: {
            HStack(spacing: 8) {
                StatusDot(status: meal.status)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.text)
                        .font(.system(.subheadline).weight(.semibold))
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Text(meal.date.formatted(date: .omitted, time: .shortened))
                        if let score = meal.symptomScore {
                            Text("· symptoms \(score)/5")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    private func bowelRow(_ movement: BowelMovement) -> some View {
        Menu {
            Button { editingBowel = movement } label: { Label("Edit", systemImage: "pencil") }
            Button("Delete", role: .destructive) { modelContext.delete(movement) }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .strokeBorder(Color.secondary, lineWidth: 1.5)
                    .frame(width: 10, height: 10)
                Text(movement.typeText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(movement.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
    }

    private func supplementPill(_ log: SupplementLog) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "pills")
                .font(.caption)
                .foregroundStyle(Theme.purple)
                .frame(width: 10)
            Text("\(log.supplementName) · \(log.taken ? "taken" : "skipped")")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
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
