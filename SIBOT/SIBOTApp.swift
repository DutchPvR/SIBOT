import SwiftData
import SwiftUI
import UserNotifications

@main
struct SIBOTApp: App {
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    _ = await NotificationManager.requestAuthorization()
                    let defaults = UserDefaults.standard
                    if defaults.object(forKey: "gingerEnabled") == nil {
                        defaults.set(true, forKey: "gingerEnabled")
                        defaults.set(22 * 60, forKey: "gingerMinutes")
                    }
                    if defaults.bool(forKey: "gingerEnabled") {
                        let minutes = defaults.integer(forKey: "gingerMinutes")
                        NotificationManager.scheduleGinger(hour: minutes / 60, minute: minutes % 60)
                    }
                }
        }
        .modelContainer(for: MealEntry.self)
    }
}
