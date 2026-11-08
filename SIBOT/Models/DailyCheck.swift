import Foundation
import SwiftData

/// One journal entry per day: the bloat answer, how bad it was, symptoms and bowel movements.
@Model
final class DailyCheck {
    /// Start of the day this entry belongs to.
    var day: Date
    var bloated: Bool
    /// False when the entry only holds bowel data and the bloat question was not answered.
    var answered: Bool = true
    /// 1 (mild) ... 5 (severe); 0 means not rated.
    var severity: Int = 0
    /// Comma separated symptom names.
    var symptomsRaw: String = ""
    var bowelCount: Int = 0
    /// Bristol stool type 1...7; 0 means not set.
    var bowelType: Int = 0

    init(day: Date, bloated: Bool, answered: Bool = true) {
        self.day = Calendar.current.startOfDay(for: day)
        self.bloated = bloated
        self.answered = answered
    }

    /// true = bloated, false = no bloat, nil = not answered.
    var answer: Bool? { answered ? bloated : nil }

    var symptoms: [String] {
        get { symptomsRaw.split(separator: ",").map(String.init) }
        set { symptomsRaw = newValue.joined(separator: ",") }
    }

    static let symptomOptions = ["Gas", "Pain", "Nausea", "Diarrhea", "Constipation", "Reflux"]

    static let bristolNames = [
        1: "Separate hard lumps", 2: "Lumpy sausage", 3: "Sausage with cracks",
        4: "Smooth sausage", 5: "Soft blobs", 6: "Mushy", 7: "Watery"
    ]

    /// True when there is nothing worth keeping in this entry.
    var isEmpty: Bool {
        !answered && bowelCount == 0 && bowelType == 0
    }
}
