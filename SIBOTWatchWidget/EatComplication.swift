import SwiftUI
import WidgetKit

struct EatEntry: TimelineEntry {
    let date: Date
    let state: EatState
}

struct EatProvider: TimelineProvider {
    func placeholder(in context: Context) -> EatEntry {
        EatEntry(date: Date(), state: .wait(until: Date().addingTimeInterval(80 * 60)))
    }

    func getSnapshot(in context: Context, completion: @escaping (EatEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : EatEntry(date: Date(), state: EatState.at(Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EatEntry>) -> Void) {
        let now = Date()
        let state = EatState.at(now)
        var entries = [EatEntry(date: now, state: state)]
        // The countdown runs on its own. Add one more entry for the moment it turns green.
        if case .wait(let until) = state {
            entries.append(EatEntry(date: until, state: EatState.at(until)))
        }
        // Nothing changes after that until the iPhone sends a new meal, which reloads the timeline.
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct EatComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: EatEntry

    /// X while waiting, checkmark when it is OK to eat, a dash until the iPhone has synced.
    private var symbol: String {
        switch entry.state {
        case .wait: "xmark"
        case .ok: "checkmark"
        case .unknown: "minus"
        }
    }

    private var mark: some View {
        Image(systemName: symbol)
            .fontWeight(.heavy)
            .foregroundStyle(entry.state.color)
            .widgetAccentable()
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Image(systemName: symbol)
        case .accessoryCorner:
            mark.font(.system(size: 22))
        default:
            ZStack {
                AccessoryWidgetBackground()
                mark.font(.system(size: 24))
            }
        }
    }
}

@main
struct EatComplication: Widget {
    let kind = "EatComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EatProvider()) { entry in
            EatComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Safe to eat")
        .description("An X while you wait, a checkmark once your fasting gap is up.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}
