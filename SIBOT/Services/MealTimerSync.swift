import Foundation
import SwiftData

/// Keeps the fasting timer in step with the meal log.
@MainActor
enum MealTimerSync {
    /// Only the newest few meals matter for the timer, so views fetch just these.
    nonisolated static var recentMeals: FetchDescriptor<MealEntry> {
        var descriptor = FetchDescriptor<MealEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 10
        return descriptor
    }

    /// The most recent meal that is not in the future (a few minutes of slack allowed).
    nonisolated static func latestMeal(_ meals: [MealEntry]) -> Date? {
        let limit = Date().addingTimeInterval(300)
        return meals.lazy.map(\.date).filter { $0 <= limit }.max().map { min($0, Date()) }
    }

    /// Call when the log changes: the timer counts up from the latest meal in the log.
    static func sync(_ meals: [MealEntry]) async {
        guard let target = latestMeal(meals) else {
            if MealTimerStore.startDate != nil { await MealTimerController.stop() }
            return
        }
        if let current = MealTimerStore.startDate, abs(current.timeIntervalSince(target)) < 1 { return }
        await MealTimerController.start(at: target)
    }

    /// The widget or Live Activity "I just ate" button only sets the timer.
    /// When the app opens, add a log entry for it so the log stays the source of truth.
    static func reconcile(_ meals: [MealEntry], context: ModelContext) {
        guard let start = MealTimerStore.startDate else { return }
        if let latest = latestMeal(meals), start <= latest.addingTimeInterval(60) { return }
        context.insert(MealEntry(date: start, text: "Meal", status: .unknown))
    }
}
