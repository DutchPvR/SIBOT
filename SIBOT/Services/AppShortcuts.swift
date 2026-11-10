import AppIntents

/// Makes the quick actions available to Siri, Spotlight, Shortcuts and the Action button
/// without any setup.
struct SIBOTShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartMealTimerIntent(),
            phrases: ["I just ate in \(.applicationName)", "Start my \(.applicationName) fast"],
            shortTitle: "I just ate",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: LogBloatIntent(),
            phrases: ["Log bloating in \(.applicationName)", "I'm bloated in \(.applicationName)"],
            shortTitle: "Log bloating",
            systemImageName: "circle.fill"
        )
    }
}
