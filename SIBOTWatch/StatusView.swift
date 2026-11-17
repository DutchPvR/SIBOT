import SwiftUI

/// What opens when you tap the complication: the time since your last meal and a reset button.
struct StatusView: View {
    private let purple = Color(red: 0.44, green: 0.27, blue: 0.86)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let state = EatState.at(context.date)
            VStack(spacing: 10) {
                if let start = MealTimerStore.startDate {
                    // Counts up from the last meal; green once the goal gap is up.
                    Text(start, style: .timer)
                        .font(.system(size: 40, weight: .heavy))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(state == .ok ? EatColors.green : Color.primary)
                } else {
                    Text(state == .unknown ? "Open SIBOT on iPhone" : "No meal yet")
                        .font(.system(.headline).weight(.heavy))
                        .multilineTextAlignment(.center)
                }
                Button {
                    WatchReceiver.shared.ateNow()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(.body).weight(.bold))
                }
                .tint(purple)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
