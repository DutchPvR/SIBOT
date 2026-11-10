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

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .accessoryCorner: corner
        default: circular
        }
    }

    private var state: EatState { entry.state }

    @ViewBuilder
    private var countdown: some View {
        if case .wait(let until) = state, until > entry.date {
            Text(timerInterval: entry.date...until, countsDown: true)
                .monospacedDigit()
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                switch state {
                case .wait:
                    Text("WAIT")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(state.color)
                        .widgetAccentable()
                    countdown
                        .font(.system(size: 12, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                case .ok:
                    Image(systemName: "fork.knife")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(state.color)
                        .widgetAccentable()
                    Text("EAT")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(state.color)
                        .widgetAccentable()
                case .unknown:
                    Image(systemName: "iphone")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(state.title)
                .font(.system(.headline).weight(.heavy))
                .foregroundStyle(state.color)
                .widgetAccentable()
            switch state {
            case .wait:
                HStack(spacing: 4) {
                    countdown
                    Text("left")
                }
                .font(.system(.body).weight(.semibold))
            case .ok:
                Text("Fasting goal reached")
                    .font(.system(.footnote))
                    .foregroundStyle(.secondary)
            case .unknown:
                Text("Open SIBOT on iPhone")
                    .font(.system(.footnote))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var inline: some View {
        if case .wait(let until) = state, until > entry.date {
            Text("Wait \(Text(timerInterval: entry.date...until, countsDown: true))")
        } else {
            Text(state.title)
        }
    }

    private var corner: some View {
        Image(systemName: state == .ok ? "fork.knife" : state == .unknown ? "iphone" : "hourglass")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(state.color)
            .widgetAccentable()
            .widgetLabel {
                if case .wait = state {
                    countdown
                } else {
                    Text(state.title)
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
        .description("Red Wait with the time left, then green OK to eat once your fasting gap is up.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
