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
