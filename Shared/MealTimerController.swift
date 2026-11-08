import ActivityKit
import Foundation
import UserNotifications
import WidgetKit

/// Starts and stops the meal timer: stored dates, local notification, Live Activity, widget refresh.
enum MealTimerController {
    static let notificationID = "mealTimerDone"

    static func start() async {
        let gap = MealTimerStore.gapHours
        let now = Date()
        let end = now.addingTimeInterval(gap * 3600)

        MealTimerStore.startDate = now
        MealTimerStore.endDate = end

        await scheduleNotification(after: gap * 3600, hours: gap)
        await restartActivity(start: now, end: end)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func stop() async {
        MealTimerStore.startDate = nil
        MealTimerStore.endDate = nil

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
        await endActivities()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Private

    private static func scheduleNotification(after seconds: TimeInterval, hours: Double) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])

        let content = UNMutableNotificationContent()
        content.title = "You can eat now 🍽️"
        let hoursText = hours == hours.rounded() ? String(Int(hours)) : String(format: "%.1f", hours)
        content.body = "Your \(hoursText)-hour gap is up."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private static func endActivities() async {
        for activity in Activity<MealTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func restartActivity(start: Date, end: Date) async {
        await endActivities()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = MealTimerAttributes(startDate: start)
        let state = MealTimerAttributes.ContentState(endDate: end)
        let content = ActivityContent(state: state, staleDate: end)
        _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }
}
