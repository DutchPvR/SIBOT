import AppIntents

/// Used by the widget buttons. LiveActivityIntent runs inside the app process,
/// which is required to start a Live Activity.
struct StartMealTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "I just ate"
    static var description = IntentDescription("Restarts the fasting timer from now.")

    func perform() async throws -> some IntentResult {
        await MealTimerController.start()
        return .result()
    }
}

struct StopMealTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Clear fasting timer"

    func perform() async throws -> some IntentResult {
        await MealTimerController.stop()
        return .result()
    }
}

/// Logs bloating at the current time. Used by the Quick log widget, Siri, Shortcuts and the Action button.
struct LogBloatIntent: AppIntent {
    static var title: LocalizedStringResource = "Log bloating"
    static var description = IntentDescription("Adds a bloating entry to your diary at the current time.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        PendingLog.addBloat()
        return .result(dialog: "Bloating logged.")
    }
}
