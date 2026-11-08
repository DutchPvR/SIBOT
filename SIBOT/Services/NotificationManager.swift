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

    private static func content(for supplement: Supplement) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "\(supplement.name) 💊"
        let dose = supplement.dose.trimmingCharacters(in: .whitespaces)
        content.body = dose.isEmpty
            ? "Time for your \(supplement.name). Did you take it?"
            : "Time for your \(supplement.name) (\(dose)). Did you take it?"
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = [
            "supplementID": supplement.id.uuidString,
            "supplementName": supplement.name
        ]
        return content
    }

    /// Replaces all notifications for one supplement.
    /// Ongoing reminders repeat weekly; dated courses get one notification per upcoming day so they stop on time.
    static func schedule(_ supplement: Supplement) {
        let center = UNUserNotificationCenter.current()
        let prefix = "supp-\(supplement.id.uuidString)"

        // Build the requests now, on the calling thread, so the model is never touched from a callback.
        var requests: [UNNotificationRequest] = []
        if supplement.enabled {
            let cal = Calendar.current
            if supplement.hasCourse {
                // Up to 60 upcoming days, only on chosen weekdays inside the course.
                for offset in 0..<60 {
                    guard let day = cal.date(byAdding: .day, value: offset, to: Date()),
                          supplement.isExpected(on: day) else { continue }
                    var parts = cal.dateComponents([.year, .month, .day], from: day)
                    parts.hour = supplement.minutes / 60
                    parts.minute = supplement.minutes % 60
                    guard let fire = cal.date(from: parts), fire > Date() else { continue }
                    requests.append(UNNotificationRequest(
                        identifier: "\(prefix)-d\(parts.year ?? 0)\(parts.month ?? 0)\(parts.day ?? 0)",
                        content: content(for: supplement),
                        trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
                }
            } else {
                for weekday in supplement.weekdays where (1...7).contains(weekday) {
                    var components = DateComponents()
                    components.weekday = weekday
                    components.hour = supplement.minutes / 60
                    components.minute = supplement.minutes % 60
                    requests.append(UNNotificationRequest(
                        identifier: identifier(for: supplement.id, weekday: weekday),
                        content: content(for: supplement),
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
                }
            }
        }

        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for request in requests { center.add(request) }
        }
    }

    static func cancel(supplementID: UUID) {
        let center = UNUserNotificationCenter.current()
        let prefix = "supp-\(supplementID.uuidString)"
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
        }
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
