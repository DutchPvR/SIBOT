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
                    statusCard
                        .padding(.top, 40)
                    Spacer()
                    buttons
                }
                .padding()
            }
            .navigationTitle("Fasting")
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
        VStack(alignment: .leading, spacing: 10) {
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

                ProgressView(value: progress)
                    .tint(goalReached ? Theme.green : Theme.purple)
                    .padding(.top, 8)

                HStack {
                    Text("Last ate \(startDate.formatted(date: .omitted, time: .shortened))")
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
        VStack(spacing: 8) {
            Button {
                Task {
                    await MealTimerController.start()
                    refresh()
                }
            } label: {
                Text("I just ate")
                    .font(.headline.weight(.heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Theme.purple)

            if startDate != nil {
                Button("Clear timer", role: .destructive) {
                    Task {
                        await MealTimerController.stop()
                        refresh()
                    }
                }
                .font(.subheadline)
                .padding(.vertical, 6)
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
