import SwiftData
import SwiftUI

/// One day as horizontal hour rows. Scroll up and down through the day.
struct DayLogView: View {
    @Environment(\.modelContext) private var modelContext

    let day: Date
    let meals: [MealEntry]
    let supplementLogs: [SupplementLog]
    let bowelMovements: [BowelMovement]
    let bloatEpisodes: [BloatEpisode]
    let check: DailyCheck?
    /// Changes when the Log tab is tapped: scroll back to the current time.
    var scrollToken = 0
    let onAddAt: (Date, LogEntryKind) -> Void

    @State private var editingMeal: MealEntry?
    @State private var addingTo: Date?
    @State private var editingBowel: BowelMovement?
    @State private var editingBloat = false
    @State private var editingEpisode: BloatEpisode?

    private var calendar: Calendar { .current }

    var body: some View {
        // Redrawn every minute so the "now" line keeps moving.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            timeline(now: context.date)
        }
        .sheet(item: $editingMeal) { EditMealSheet(meal: $0) }
        .sheet(isPresented: $editingBloat) { BloatSheet(day: day, startsAsNoBloat: check?.answer == false) }
        .sheet(item: $editingEpisode) { BloatSheet(day: $0.date, episode: $0) }
        .sheet(item: $editingBowel) { BowelSheet(existing: $0) }
        .sheet(isPresented: Binding(get: { addingTo != nil }, set: { if !$0 { addingTo = nil } })) {
            AddMealSheet(initialDate: addingTo ?? Date(), title: "Add to this meal")
        }
    }

    private func hour(_ date: Date) -> Int { calendar.component(.hour, from: date) }

    private func timeline(now: Date) -> some View {
        let nowHour = calendar.isDateInToday(day) ? hour(now) : nil
        // Sort the day's entries into hours once, not once per hour row.
        let mealsByHour = Dictionary(grouping: meals) { hour($0.date) }
        let supplementsByHour = Dictionary(grouping: supplementLogs) { hour($0.date) }
        let bowelByHour = Dictionary(grouping: bowelMovements) { hour($0.date) }
        let bloatByHour = Dictionary(grouping: bloatEpisodes) { hour($0.date) }
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Bloating has its own time now; this row is only for a "No bloat" day.
                    if let check, check.answered, bloatEpisodes.isEmpty {
                        bloatRow(check)
                    }
                    ForEach(0..<24, id: \.self) { hour in
                        hourRow(hour, meals: mealsByHour[hour] ?? [],
                                supplements: supplementsByHour[hour] ?? [], bowel: bowelByHour[hour] ?? [],
                                bloat: bloatByHour[hour] ?? [], now: hour == nowHour ? now : nil)
                            .id(hour)
                    }
                }
                .padding(.horizontal, Theme.pageMargin)
                .padding(.bottom, 24)
            }
            .onAppear { scroll(proxy) }
            .onChange(of: day) { _, _ in scroll(proxy) }
            .onChange(of: scrollToken) { _, _ in scroll(proxy) }
        }
    }

    /// Today opens at the current time. Other days open near their first meal, or in the morning.
    private func scroll(_ proxy: ScrollViewProxy) {
        let target: Int
        if calendar.isDateInToday(day) {
            target = max(hour(Date()) - 1, 0)
        } else if let first = meals.map({ hour($0.date) }).min() {
            target = max(first - 1, 0)
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

    private func hourRow(_ hour: Int, meals hourMeals: [MealEntry],
                         supplements hourSupplements: [SupplementLog], bowel hourBowel: [BowelMovement],
                         bloat hourBloat: [BloatEpisode], now: Date?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(hourLabel(hour))
                .font(.system(.caption).weight(now == nil ? .semibold : .heavy))
                .foregroundStyle(now == nil ? Color.secondary : Theme.purple)
                .frame(width: 48, alignment: .trailing)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(hourMeals) { meal in
                    mealPill(meal)
                }
                ForEach(hourBloat) { episode in
                    episodeRow(episode)
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
            .overlay(alignment: .topLeading) {
                if let now { nowLine(now) }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            let time = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
            Button("Add meal at \(hourLabel(hour))") { onAddAt(time, .meal) }
            Button("Add bowel movement at \(hourLabel(hour))") { onAddAt(time, .bowel) }
            Button("Add bloating at \(hourLabel(hour))") { onAddAt(time, .bloat) }
        }
    }

    /// A purple line across the current hour, placed by how far into the hour it is.
    private func nowLine(_ now: Date) -> some View {
        let fraction = CGFloat(calendar.component(.minute, from: now)) / 60
        return GeometryReader { geo in
            HStack(spacing: 4) {
                Circle().fill(Theme.purple).frame(width: 7, height: 7)
                Rectangle().fill(Theme.purple).frame(height: 1.5)
                Text(now.formatted(date: .omitted, time: .shortened))
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Theme.purple)
            }
            .offset(x: -4, y: geo.size.height * fraction - 4)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Now, \(now.formatted(date: .omitted, time: .shortened))")
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

    private func episodeRow(_ episode: BloatEpisode) -> some View {
        Menu {
            Button { editingEpisode = episode } label: { Label("Edit", systemImage: "pencil") }
            Button("Delete", role: .destructive) { BloatLog.delete(episode, in: modelContext) }
        } label: {
            HStack(spacing: 8) {
                BloatMark(bloated: true, color: .secondary, size: 10)
                Text(episode.summaryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text(episode.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
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

    /// The day's bloating, pinned above the hours because it is logged once per day.
    private func bloatRow(_ check: DailyCheck) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("Day")
                .font(.system(.caption).weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
                .padding(.top, 6)

            Menu {
                Button { editingBloat = true } label: { Label("Edit", systemImage: "pencil") }
                Button("Delete", role: .destructive) {
                    check.answered = false
                    check.severity = 0
                    check.symptoms = []
                    if check.isEmpty { modelContext.delete(check) }
                }
            } label: {
                HStack(spacing: 8) {
                    BloatMark(bloated: check.bloated, color: .secondary, size: 10)
                    Text(check.summaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
