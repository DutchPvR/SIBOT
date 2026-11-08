import ActivityKit
import SwiftUI
import WidgetKit

struct MealTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MealTimerAttributes.self) { context in
            // Lock screen / banner
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fasting")
                        .font(.system(.subheadline).weight(.bold))
                    Text("Last ate at \(context.attributes.startDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // .timer style counts up from the start date.
                Text(context.attributes.startDate, style: .timer)
                    .font(.system(size: 34, weight: .heavy))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140, alignment: .trailing)
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.44, green: 0.27, blue: 0.86).opacity(0.18))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.startDate, style: .timer)
                        .font(.system(.title2).weight(.bold))
                        .monospacedDigit()
                        .frame(maxWidth: 120, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Since your last meal at \(context.attributes.startDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(context.attributes.startDate, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}
