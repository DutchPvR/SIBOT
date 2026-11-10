import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(MealTimerSync.recentMeals) private var meals: [MealEntry]

    var body: some View {
        TabView {
            FoodCheckView()
                .tabItem { Label("Check", systemImage: "magnifyingglass") }
            TimerView()
                .tabItem { Label("Fasting", systemImage: "timer") }
            LogView()
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle") }
            RemindersView()
                .tabItem { Label("Reminders", systemImage: "bell.badge") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
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
