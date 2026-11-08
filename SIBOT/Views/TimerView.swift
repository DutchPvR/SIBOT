import Combine
import SwiftUI

/// Fasting timer: counts UP from your last meal so you can see how long it has been.
struct TimerView: View {
    @State private var startDate: Date? = MealTimerStore.startDate
    @State private var endDate: Date? = MealTimerStore.endDate
    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var goalReached: Bool {
        if let endDate { return now >= endDate }
        return false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                VStack(spacing: 24) {
                    Spacer()
                    statusCard
                    Spacer()
                    buttons
                }
                .padding()
            }
            .navigationTitle("Fasting timer")
        }
        .onReceive(ticker) { date in
            now = date
            // Pick up changes made from the widget or Live Activity.
            if startDate != MealTimerStore.startDate {
                refresh()
            }
        }
        .onAppear(perform: refresh)
    }

    private var statusCard: some View {
        VStack(spacing: 14) {
            if let startDate {
                Text("Since your last meal")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                // .timer style counts up from a past date, and keeps going.
                Text(startDate, style: .timer)
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(goalReached ? Theme.mint : Theme.orange)

                ProgressView(value: progress)
                    .tint(goalReached ? Theme.mint : Theme.orange)
                    .padding(.horizontal, 24)

                Text(goalReached
                     ? "✅ Past your \(hoursText)-hour goal"
                     : "⏳ Goal: \(hoursText) hours")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(goalReached ? Theme.mint : .secondary)

                Text("Last ate at \(startDate.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else {
                Text("🍽️")
                    .font(.system(size: 64))
                Text("No meal yet")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                Text("Tap the button when you eat. The timer counts up from there.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .card()
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await MealTimerController.start()
                    refresh()
                }
            } label: {
                Text("I just ate")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.grape)

            if startDate != nil {
                Button("Clear timer", role: .destructive) {
                    Task {
                        await MealTimerController.stop()
                        refresh()
                    }
                }
            }
        }
    }

    /// 0...1 progress toward the goal gap.
    private var progress: Double {
        guard let startDate else { return 0 }
        let goal = MealTimerStore.gapHours * 3600
        guard goal > 0 else { return 1 }
        return min(max(now.timeIntervalSince(startDate) / goal, 0), 1)
    }

    private var hoursText: String {
        let hours = MealTimerStore.gapHours
        return hours == hours.rounded() ? String(Int(hours)) : String(format: "%.1f", hours)
    }

    private func refresh() {
        startDate = MealTimerStore.startDate
        endDate = MealTimerStore.endDate
        now = Date()
    }
}
