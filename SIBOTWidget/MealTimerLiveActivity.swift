import ActivityKit
import SwiftUI
import WidgetKit

struct MealTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MealTimerAttributes.self) { context in
            // Lock screen / banner
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("⏳ Hold off on eating")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                    Text("Next meal at \(context.state.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(timerInterval: context.attributes.startDate...context.state.endDate, countsDown: true)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 130, alignment: .trailing)
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.42, green: 0.30, blue: 0.85).opacity(0.25))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("⏳")
                        .font(.title)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.startDate...context.state.endDate, countsDown: true)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Next meal at \(context.state.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                }
            } compactLeading: {
                Text("⏳")
            } compactTrailing: {
                Text(timerInterval: context.attributes.startDate...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
            } minimal: {
                Text("⏳")
            }
        }
    }
}
