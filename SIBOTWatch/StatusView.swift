import SwiftUI

/// The watch app itself: the same Wait / OK to eat answer as the complication, a little larger.
struct StatusView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let state = EatState.at(context.date)
            VStack(spacing: 8) {
                Image(systemName: icon(for: state))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(state.color)
                Text(state.title)
                    .font(.system(.title3).weight(.heavy))
                    .foregroundStyle(state.color)
                detail(for: state, now: context.date)
                    .font(.system(.footnote).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func icon(for state: EatState) -> String {
        switch state {
        case .unknown: "iphone"
        case .wait: "hourglass"
        case .ok: "fork.knife"
        }
    }

    @ViewBuilder
    private func detail(for state: EatState, now: Date) -> some View {
        switch state {
        case .unknown:
            Text("Open SIBOT on your iPhone to sync the timer.")
        case .wait(let until):
            Text("\(Text(timerInterval: now...until, countsDown: true)) left")
        case .ok:
            if let start = MealTimerStore.startDate {
                Text("\(Text(start, style: .timer)) since last meal")
            } else {
                Text("No meal logged")
            }
        }
    }
}
