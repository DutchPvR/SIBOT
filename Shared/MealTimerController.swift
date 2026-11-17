import ActivityKit
import Foundation
import UserNotifications
import WidgetKit

/// Starts and stops the meal timer: stored dates, local notification, Live Activity, widget refresh.
enum MealTimerController {
    static let notificationID = "mealTimerDone"

    /// Set by the app to pass timer changes on to the Apple Watch.
    /// Stays nil in the widget extension.
    static var didChange: (() -> Void)?

    /// The home and lock screen fasting timer widget. Only this one shows the timer.
    static let widgetKind = "MealTimerWidget"

    /// Marks "I just ate" (or ate at `date`): the fasting timer counts up from there.
    /// The goal gap only drives the "you can eat" notification and the color change.
    static func start(at date: Date = Date()) async {
        let gap = MealTimerStore.gapHours
        let end = date.addingTimeInterval(gap * 3600)

        MealTimerStore.startDate = date
        MealTimerStore.endDate = end
        // Refresh the widget and the watch first, so they reset right away
        // instead of waiting for the notification and the Live Activity below.
        refreshWidgetAndWatch()

        async let notification: Void = updateNotification(end: end, hours: gap)
        async let activity: Void = restartActivity(start: date, end: end)
        _ = await (notification, activity)
    }

    static func stop() async {
        MealTimerStore.startDate = nil
        MealTimerStore.endDate = nil
        refreshWidgetAndWatch()

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
        await endActivities()
    }

    // MARK: - Private

    /// Reloads only the timer widget (the Quick log widget doesn't show the timer) and tells the watch.
    private static func refreshWidgetAndWatch() {
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        didChange?()
    }

    private static func updateNotification(end: Date, hours: Double) async {
        if end > Date() && MealTimerStore.goalNotificationOn {
            await scheduleNotification(after: end.timeIntervalSinceNow, hours: hours)
        } else {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [notificationID])
        }
    }

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

    /// Ends every running timer Live Activity at the same time rather than one after another.
    private static func endActivities() async {
        await withTaskGroup(of: Void.self) { group in
            for activity in Activity<MealTimerAttributes>.activities {
                group.addTask { await activity.end(nil, dismissalPolicy: .immediate) }
            }
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
