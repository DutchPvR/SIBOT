import Foundation
import SwiftData

@Model
final class MealEntry {
    var date: Date
    var text: String
    var statusRaw: String
    /// Optional symptom rating after the meal: 1 (fine) to 5 (very bad).
    var symptomScore: Int?

    init(date: Date = Date(), text: String, status: FoodStatus, symptomScore: Int? = nil) {
        self.date = date
        self.text = text
        self.statusRaw = status.rawValue
        self.symptomScore = symptomScore
    }

    var status: FoodStatus {
        FoodStatus(rawValue: statusRaw) ?? .unknown
    }
}
