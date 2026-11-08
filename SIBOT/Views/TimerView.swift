import SwiftData
import SwiftUI

/// Fasting timer: counts UP from your last meal so you can see how long it has been.
struct TimerView: View {
    @Query(MealTimerSync.recentMeals) private var meals: [MealEntry]
    @State private var showingAte = false

    /// The latest meal in the log, or a newer tap on the widget that the log has not caught up with.
    private var startDate: Date? {
        let logged = MealTimerSync.latestMeal(meals)
        guard let stored = MealTimerStore.startDate else { return logged }
        guard let logged else { return stored }
        return max(logged, stored)
    }

    var body: some View {
        NavigationStack {
            // The counter text ticks on its own; the rest only needs a refresh now and then.
            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(spacing: 24) {
                    statusCard(now: context.date)
                        .padding(.top, 40)
                    Spacer()
                    buttons
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Fasting")
        }
        .sheet(isPresented: $showingAte) {
            AddMealSheet(initialDate: Date(), title: "I just ate")
        }
    }

    private func statusCard(now: Date) -> some View {
        let goalReached = startDate.map { now.timeIntervalSince($0) >= goalSeconds } ?? false
        return VStack(alignment: .leading, spacing: 10) {
            if let startDate {
                Text("SINCE YOUR LAST MEAL")
                    .font(.caption.weight(.heavy))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                // .timer style counts up from a past date, and keeps going.
                Text(startDate, style: .timer)
                    .font(.system(size: 96, weight: .heavy))
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .foregroundStyle(goalReached ? Theme.green : Theme.ink)

                ProgressView(value: progress(now: now))
                    .tint(goalReached ? Theme.green : Theme.purple)
                    .padding(.top, 8)

                HStack {
                    Text("Last ate at \(lastAteText(startDate))")
                    Spacer()
                    Text(goalReached ? "Past \(hoursText)h goal" : "Goal \(hoursText)h")
                        .fontWeight(.semibold)
                        .foregroundStyle(goalReached ? Theme.green : Theme.ink)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
                Text("No meal yet")
                    .font(.system(size: 44, weight: .heavy))
                Text("Tap the button when you eat. The timer counts up from there.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var buttons: some View {
        Button {
            showingAte = true
        } label: {
            Text("I just ate")
                .font(.headline.weight(.heavy))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(Theme.purple)
    }

    private var goalSeconds: Double { MealTimerStore.gapHours * 3600 }

    /// 0...1 progress toward the goal gap.
    private func progress(now: Date) -> Double {
        guard let startDate, goalSeconds > 0 else { return 0 }
        return min(max(now.timeIntervalSince(startDate) / goalSeconds, 0), 1)
    }

    /// Time of the latest meal in the log; adds the weekday when it was not today.
    private func lastAteText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    private var hoursText: String {
        let hours = MealTimerStore.gapHours
        return hours == hours.rounded() ? String(Int(hours)) : String(format: "%.1f", hours)
    }
}
