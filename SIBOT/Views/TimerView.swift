import Combine
import SwiftUI

struct TimerView: View {
    @State private var startDate: Date? = MealTimerStore.startDate
    @State private var endDate: Date? = MealTimerStore.endDate
    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isWaiting: Bool {
        if let endDate { return endDate > now }
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
            .navigationTitle("Meal timer")
        }
        .onReceive(ticker) { date in
            now = date
            // Pick up changes made from the widget or Live Activity.
            if endDate != MealTimerStore.endDate {
                refresh()
            }
        }
        .onAppear(perform: refresh)
    }

    private var statusCard: some View {
        VStack(spacing: 14) {
            if isWaiting, let startDate, let endDate {
                Text("⏳ Hold off on eating")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.orange)
                Text(timerInterval: startDate...endDate, countsDown: true)
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.grape)
                Text("Next meal at \(endDate.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
            } else {
                Text("🍽️")
                    .font(.system(size: 64))
                Text("You can eat")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.mint)
                Text("Start the timer after your meal.")
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
                Text(isWaiting ? "Restart timer" : "Start \(hoursText)-hour timer")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.grape)

            if isWaiting {
                Button("Reset", role: .destructive) {
                    Task {
                        await MealTimerController.stop()
                        refresh()
                    }
                }
            }
        }
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
