import ActivityKit
import Foundation

struct MealTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
    }

    var startDate: Date
}
