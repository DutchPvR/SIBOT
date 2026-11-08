import SwiftData
import SwiftUI

/// One day as horizontal hour rows. Scroll up and down through the day.
struct DayLogView: View {
    @Environment(\.modelContext) private var modelContext

    let day: Date
    let meals: [MealEntry]
    let supplementLogs: [SupplementLog]
    let check: DailyCheck?

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(spacing: 0) {
            bloatBar
            timeline
        }
    }

    // MARK: - Daily bloat check

    private var bloatBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BELLY TODAY")
                .font(.caption.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                bloatButton("No bloat", value: false, color: Theme.green)
                bloatButton("Bloated", value: true, color: Theme.red)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private func bloatButton(_ title: String, value: Bool, color: Color) -> some View {
        let selected = check?.bloated == value
        return Button {
            setBloat(value)
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(selected ? Color.white : color)
                .background(selected ? color : color.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Tap an answer to set it; tap it again to clear it.
    private func setBloat(_ value: Bool) {
        if let check {
            if check.bloated == value {
                modelContext.delete(check)
            } else {
                check.bloated = value
            }
        } else {
            modelContext.insert(DailyCheck(day: day, bloated: value))
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
                ForEach(hourSupplements) { log in
                    supplementPill(log)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            .padding(.vertical, 6)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: 1)
            }
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(meal.status.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(meal.status.color)
                    .frame(width: 4)
                    .padding(.vertical, 6)
            }
        }
    }

    private func supplementPill(_ log: SupplementLog) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "pills").foregroundStyle(Theme.purple)
            Text("\(log.supplementName) · \(log.taken ? "taken" : "skipped")")
                .font(.system(.footnote).weight(.semibold))
            Spacer(minLength: 0)
            Text(log.date.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
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
