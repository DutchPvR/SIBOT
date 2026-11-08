import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TimerView()
                .tabItem { Label("Timer", systemImage: "timer") }
            FoodCheckView()
                .tabItem { Label("Check", systemImage: "magnifyingglass") }
            LogView()
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle") }
            RemindersView()
                .tabItem { Label("Reminders", systemImage: "bell.badge") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.grape)
    }
}
