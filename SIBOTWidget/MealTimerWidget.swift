import AppIntents
import SwiftUI
import WidgetKit

struct MealTimerEntry: TimelineEntry {
    let date: Date
    let startDate: Date?
    let endDate: Date?

    var isWaiting: Bool {
        guard let endDate else { return false }
        return endDate > date
    }
}

struct MealTimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> MealTimerEntry {
        MealTimerEntry(date: Date(), startDate: Date(), endDate: Date().addingTimeInterval(3 * 3600))
    }

    func getSnapshot(in context: Context, completion: @escaping (MealTimerEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MealTimerEntry>) -> Void) {
        let entry = currentEntry()
        if entry.isWaiting, let end = entry.endDate {
            // Reload when the countdown finishes so the widget flips to "You can eat".
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

    private var homeView: some View {
        VStack(spacing: 8) {
            if entry.isWaiting, let start = entry.startDate, let end = entry.endDate {
                Text("⏳ Wait")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(orange)
                Text(timerInterval: start...end, countsDown: true)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(grape)
                    .multilineTextAlignment(.center)
                Button(intent: StopMealTimerIntent()) {
                    Text("Reset")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(grape)
            } else {
                Text("🍽️ You can eat")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(mint)
                    .multilineTextAlignment(.center)
                Button(intent: StartMealTimerIntent()) {
                    Text("Start timer")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(grape)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lockScreenView: some View {
        VStack(alignment: .leading) {
            if entry.isWaiting, let start = entry.startDate, let end = entry.endDate {
                Text("Next meal in")
                    .font(.caption)
                Text(timerInterval: start...end, countsDown: true)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
            } else {
                Text("🍽️ You can eat")
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
        .configurationDisplayName("Meal timer")
        .description("Start the wait between meals and watch it count down.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
