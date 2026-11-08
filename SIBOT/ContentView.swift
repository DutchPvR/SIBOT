import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            FoodCheckView()
                .tabItem { Label("Check", systemImage: "magnifyingglass") }
            LogView()
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle") }
            TimerView()
                .tabItem { Label("Fasting", systemImage: "timer") }
            RemindersView()
                .tabItem { Label("Reminders", systemImage: "bell.badge") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.grape)
    }
}
