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

extension Sequence where Element == MealEntry {
    /// The "worst" status among these meals: avoid beats limit beats safe.
    /// Returns nil when there are no meals, and `.unknown` when none could be rated.
    var worstStatus: FoodStatus? {
        var sawAny = false
        var sawLimit = false
        var sawSafe = false
        for entry in self {
            sawAny = true
            switch entry.status {
            case .avoid: return .avoid
            case .limit: sawLimit = true
            case .safe: sawSafe = true
            case .unknown: break
            }
        }
        if !sawAny { return nil }
        if sawLimit { return .limit }
        if sawSafe { return .safe }
        return .unknown
    }
}
