import Foundation
import SwiftData

/// Your own food settings: they override the bundled list, and can add foods it does not have.
enum PersonalFoods {
    private static let key = "personalFoods"

    /// Read from disk once, then kept in memory.
    private static var cache: [String: String]?

    static var all: [String: String] {
        get {
            if let cache { return cache }
            let loaded = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
            cache = loaded
            return loaded
        }
        set {
            cache = newValue
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func status(for name: String) -> FoodStatus? {
        all[normalize(name)].flatMap { FoodStatus(rawValue: $0) }
    }

    static func set(_ name: String, to status: FoodStatus?) {
        var current = all
        if let status { current[normalize(name)] = status.rawValue } else { current.removeValue(forKey: normalize(name)) }
        all = current
    }
}

/// A food you are testing on purpose, one at a time, to see if you tolerate it.
@Model
final class FoodTrial {
    var food: String = ""
    var startDate: Date = Date()
    /// 0 = still testing, 1 = tolerated, 2 = reacted.
    var resultRaw: Int = 0
    var notes: String = ""

    init(food: String, startDate: Date = Date()) {
        self.food = food
        self.startDate = startDate
    }
}
