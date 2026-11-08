import ActivityKit
import Foundation
import UserNotifications
import WidgetKit

/// Starts and stops the meal timer: stored dates, local notification, Live Activity, widget refresh.
enum MealTimerController {
    static let notificationID = "mealTimerDone"

    /// Marks "I just ate" (or ate at `date`): the fasting timer counts up from there.
    /// The goal gap only drives the "you can eat" notification and the color change.
    static func start(at date: Date = Date()) async {
        let gap = MealTimerStore.gapHours
        let end = date.addingTimeInterval(gap * 3600)

        MealTimerStore.startDate = date
        MealTimerStore.endDate = end

        if end > Date() {
            await scheduleNotification(after: end.timeIntervalSinceNow, hours: gap)
        } else {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [notificationID])
        }
        await restartActivity(start: date, end: end)
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
        content.title = "Fasting goal reached"
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
