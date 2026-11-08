import ActivityKit
import SwiftUI
import WidgetKit

struct MealTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MealTimerAttributes.self) { context in
            // Lock screen / banner
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("⏳ Fasting")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                    Text("Last ate at \(context.attributes.startDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // .timer style counts up from the start date.
                Text(context.attributes.startDate, style: .timer)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140, alignment: .trailing)
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
                    Text(context.attributes.startDate, style: .timer)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .frame(maxWidth: 120, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Since your last meal at \(context.attributes.startDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                }
            } compactLeading: {
                Text("⏳")
            } compactTrailing: {
                Text(context.attributes.startDate, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Text("⏳")
            }
        }
    }
}
