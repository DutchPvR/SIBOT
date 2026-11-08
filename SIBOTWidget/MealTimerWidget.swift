import AppIntents
import SwiftUI
import WidgetKit

struct MealTimerEntry: TimelineEntry {
    let date: Date
    let startDate: Date?
    let endDate: Date?

    var goalReached: Bool {
        guard let endDate else { return false }
        return date >= endDate
    }
}

struct MealTimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> MealTimerEntry {
        MealTimerEntry(date: Date(), startDate: Date().addingTimeInterval(-3 * 3600), endDate: Date().addingTimeInterval(2 * 3600))
    }

    func getSnapshot(in context: Context, completion: @escaping (MealTimerEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MealTimerEntry>) -> Void) {
        let entry = currentEntry()
        if let end = entry.endDate, end > entry.date {
            // The counter runs on its own. Reload at the goal so the color can switch.
            completion(Timeline(entries: [entry], policy: .after(end)))
        } else {
            completion(Timeline(entries: [entry], policy: .never))
        }
    }

    private func currentEntry() -> MealTimerEntry {
        MealTimerEntry(date: Date(), startDate: MealTimerStore.startDate, endDate: MealTimerStore.endDate)
    }
}

struct MealTimerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MealTimerEntry

    private let grape = Color(red: 0.42, green: 0.30, blue: 0.85)
    private let mint = Color(red: 0.14, green: 0.74, blue: 0.56)
    private let orange = Color(red: 1.00, green: 0.62, blue: 0.20)

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreenView
        default:
            homeView
        }
    }

    private var timerColor: Color { entry.goalReached ? mint : orange }

    private var homeView: some View {
        VStack(spacing: 8) {
            if let start = entry.startDate {
                Text("Since last meal")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
                // .timer style counts up from a past date and keeps going.
                Text(start, style: .timer)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(timerColor)
                    .multilineTextAlignment(.center)
            } else {
                Text("🍽️ No meal yet")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .multilineTextAlignment(.center)
            }
            Button(intent: StartMealTimerIntent()) {
                Text("I just ate")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .tint(grape)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lockScreenView: some View {
        VStack(alignment: .leading) {
            if let start = entry.startDate {
                Text("Since last meal")
                    .font(.caption)
                Text(start, style: .timer)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
            } else {
                Text("🍽️ No meal yet")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MealTimerWidget: Widget {
    let kind = "MealTimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MealTimerProvider()) { entry in
            MealTimerWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.42, green: 0.30, blue: 0.85).opacity(0.18),
                            Color(red: 1.00, green: 0.36, blue: 0.62).opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Fasting timer")
        .description("Shows how long it has been since your last meal. Tap to restart it.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
