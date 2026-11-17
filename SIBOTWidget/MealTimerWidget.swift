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
        var entries = [entry]
        // The counter runs on its own. Add one more entry for the moment the goal is reached,
        // so the color switches on time without asking the system for another reload.
        if let end = entry.endDate, end > entry.date {
            entries.append(MealTimerEntry(date: end, startDate: entry.startDate, endDate: end))
        }
        // Nothing else changes until the app logs a new meal, which reloads this widget.
        completion(Timeline(entries: entries, policy: .never))
    }

    private func currentEntry() -> MealTimerEntry {
        MealTimerEntry(date: Date(), startDate: MealTimerStore.startDate, endDate: MealTimerStore.endDate)
    }
}

struct MealTimerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MealTimerEntry

    private let grape = Color(red: 0.44, green: 0.27, blue: 0.86)
    private let green = Color(red: 0.09, green: 0.64, blue: 0.29)

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreenView
        default:
            homeView
        }
    }

    private var timerColor: Color { entry.goalReached ? green : Color.primary }

    private var homeView: some View {
        VStack(spacing: 8) {
            if let start = entry.startDate {
                Text("SINCE LAST MEAL")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                // .timer style counts up from a past date and keeps going.
                Text(start, style: .timer)
                    .font(.system(size: 34, weight: .heavy))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(timerColor)
                    .multilineTextAlignment(.center)
            } else {
                Text("No meal yet")
                    .font(.system(.headline).weight(.heavy))
                    .multilineTextAlignment(.center)
            }
            Button(intent: StartMealTimerIntent()) {
                Text("I just ate")
                    .font(.system(.subheadline).weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
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
                    .font(.system(.title2).weight(.bold))
                    .monospacedDigit()
            } else {
                Text("No meal yet")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MealTimerWidget: Widget {
    let kind = MealTimerController.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MealTimerProvider()) { entry in
            MealTimerWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(uiColor: .systemBackground)
                }
        }
        .configurationDisplayName("Fasting timer")
        .description("Shows how long it has been since your last meal. Tap to restart it.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
