import SwiftData

/// One shared SwiftData container so notification actions can write logs
/// even when they arrive while the UI is not showing.
enum Persistence {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: MealEntry.self, Supplement.self, SupplementLog.self, DailyCheck.self, FoodTrial.self, BowelMovement.self, BloatEpisode.self)
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
    }()
}
