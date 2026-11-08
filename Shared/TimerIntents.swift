import AppIntents

/// Used by the widget buttons. LiveActivityIntent runs inside the app process,
/// which is required to start a Live Activity.
struct StartMealTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start meal timer"
    static var description = IntentDescription("Starts the wait before your next meal.")

    func perform() async throws -> some IntentResult {
        await MealTimerController.start()
        return .result()
    }
}

struct StopMealTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Reset meal timer"

    func perform() async throws -> some IntentResult {
        await MealTimerController.stop()
        return .result()
    }
}
