import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(MealTimerSync.recentMeals) private var meals: [MealEntry]

    private enum AppTab { case check, fasting, log, reminders, settings }

    @State private var tab: AppTab = .check
    /// Goes up every time the Log tab is tapped, so the log jumps to today and the current time.
    @State private var logJump = 0

    /// Also fires when you tap the tab you are already on.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { tab },
            set: { newTab in
                if newTab == .log { logJump += 1 }
                tab = newTab
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            FoodCheckView()
                .tabItem { Label("Check", systemImage: "magnifyingglass") }
                .tag(AppTab.check)
            TimerView()
                .tabItem { Label("Fasting", systemImage: "timer") }
                .tag(AppTab.fasting)
            LogView(jumpToNow: logJump)
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.log)
            RemindersView()
                .tabItem { Label("Reminders", systemImage: "bell.badge") }
                .tag(AppTab.reminders)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Theme.purple)
        // The fasting timer follows the most recent meal in the log.
        .onChange(of: meals.map(\.date)) { _, _ in
            Task { await MealTimerSync.sync(meals) }
        }
        .onAppear { AppLock.shared.sceneChanged(.active) }
        .onChange(of: scenePhase) { _, phase in
            AppLock.shared.sceneChanged(phase)
            if phase == .active {
                BloatLog.reconcilePending(in: modelContext)
                MealTimerSync.reconcile(meals, context: modelContext)
                WatchSync.shared.push()
            }
        }
    }
}
