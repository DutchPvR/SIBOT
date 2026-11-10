import AppIntents
import SwiftUI
import WidgetKit

struct QuickLogEntry: TimelineEntry {
    let date: Date
    let lastBloat: Date?
}

struct QuickLogProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickLogEntry {
        QuickLogEntry(date: Date(), lastBloat: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickLogEntry) -> Void) {
        completion(QuickLogEntry(date: Date(), lastBloat: PendingLog.lastBloat))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLogEntry>) -> Void) {
        // Redrawn by the system after each button tap; nothing changes on its own.
        completion(Timeline(entries: [QuickLogEntry(date: Date(), lastBloat: PendingLog.lastBloat)], policy: .never))
    }
}

/// Two buttons for the lock screen or home screen: "Ate" restarts the fasting timer, "Bloated" logs bloating now.
struct QuickLogView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuickLogEntry

    private let purple = Color(red: 0.44, green: 0.27, blue: 0.86)

    /// Shown under the buttons so a tap is visibly confirmed.
    private var confirmation: String? {
        guard let last = entry.lastBloat, Calendar.current.isDateInToday(last) else { return nil }
        return "Bloated \(last.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 4) {
            if family == .systemSmall {
                Button(intent: StartMealTimerIntent()) { label("I just ate") }
                Button(intent: LogBloatIntent()) { label("Bloated") }
            } else {
                HStack(spacing: 6) {
                    Button(intent: StartMealTimerIntent()) { label("Ate") }
                    Button(intent: LogBloatIntent()) { label("Bloated") }
                }
            }
            if let confirmation {
                Text(confirmation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .tint(purple)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
    }
}

struct QuickLogWidget: Widget {
    let kind = "QuickLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickLogProvider()) { entry in
            QuickLogView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(uiColor: .systemBackground)
                }
        }
        .configurationDisplayName("Quick log")
        .description("Log a meal or bloating without opening the app.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}
