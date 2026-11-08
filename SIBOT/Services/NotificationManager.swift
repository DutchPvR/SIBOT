import Foundation
import SwiftData
import UserNotifications

/// Shows notifications as banners while the app is open, and handles the
/// Taken / Skipped buttons on supplement reminders.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let idString = info["supplementID"] as? String,
              let id = UUID(uuidString: idString) else { return }

        let taken: Bool
        switch response.actionIdentifier {
        case NotificationManager.takenAction: taken = true
        case NotificationManager.skippedAction: taken = false
        default: return
        }

        let name = info["supplementName"] as? String
        await MainActor.run {
            SupplementLogger.record(
                supplementID: id,
                name: name,
                taken: taken,
                in: Persistence.container.mainContext
            )
        }
    }
}

enum NotificationManager {
    static let categoryID = "SUPPLEMENT"
    static let takenAction = "SUPPLEMENT_TAKEN"
    static let skippedAction = "SUPPLEMENT_SKIPPED"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Registers the Taken / Skipped buttons shown on supplement notifications.
    static func registerCategories() {
        let taken = UNNotificationAction(identifier: takenAction, title: "Taken ✓", options: [])
        let skipped = UNNotificationAction(identifier: skippedAction, title: "Skipped", options: [])
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [taken, skipped],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private static func identifier(for supplementID: UUID, weekday: Int) -> String {
        "supp-\(supplementID.uuidString)-\(weekday)"
    }

    /// Replaces all notifications for one supplement with one repeating notification per chosen weekday.
    static func schedule(_ supplement: Supplement) {
        let center = UNUserNotificationCenter.current()
        cancel(supplementID: supplement.id)
        guard supplement.enabled else { return }

        for weekday in supplement.weekdays where (1...7).contains(weekday) {
            let content = UNMutableNotificationContent()
            content.title = "\(supplement.name) 💊"
            content.body = "Time for your \(supplement.name). Did you take it?"
            content.sound = .default
            content.categoryIdentifier = categoryID
            content.userInfo = [
                "supplementID": supplement.id.uuidString,
                "supplementName": supplement.name
            ]

            var components = DateComponents()
            components.weekday = weekday
            components.hour = supplement.minutes / 60
            components.minute = supplement.minutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: identifier(for: supplement.id, weekday: weekday),
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    static func cancel(supplementID: UUID) {
        let ids = (1...7).map { identifier(for: supplementID, weekday: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Re-creates every reminder, e.g. at launch, so schedules always match what is saved.
    static func rescheduleAll(_ supplements: [Supplement]) {
        for supplement in supplements { schedule(supplement) }
    }

    /// Removes the single ginger reminder used by the first version of the app.
    static func cancelLegacyGinger() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["gingerReminder"])
    }
}
