import Foundation
import UserNotifications

/// Shows notifications as banners even while the app is open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

enum NotificationManager {
    static let gingerID = "gingerReminder"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Schedules the daily ginger pill reminder at the given local time.
    static func scheduleGinger(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [gingerID])

        let content = UNMutableNotificationContent()
        content.title = "Ginger pills 🫚"
        content.body = "Time to take your ginger before bed."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: gingerID, content: content, trigger: trigger))
    }

    static func cancelGinger() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [gingerID])
    }
}
