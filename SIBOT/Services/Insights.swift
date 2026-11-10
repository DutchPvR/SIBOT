import Foundation

struct FoodSuspect: Identifiable {
    let food: String
    let bloatedWindows: Int
    let clearWindows: Int
    var id: String { food }
}

struct InsightResult {
    let bloatedDays: Int
    let clearDays: Int
    let suspects: [FoodSuspect]
    /// Average number of Limit / Avoid items in the look-back window before bloated vs clear days.
    let riskBloated: Double
    let riskClear: Double

    /// A few bloated and clear days are needed before the numbers mean anything.
    var hasEnoughData: Bool { bloatedDays >= 3 && clearDays >= 3 }

    static let empty = InsightResult(bloatedDays: 0, clearDays: 0, suspects: [], riskBloated: 0, riskClear: 0)
}

/// Looks back from each journal day to the food eaten that day and the days before it,
/// and shows which foods turn up more before bloated days than before clear days.
enum Insights {
    static func analyze(meals: [MealEntry], checks: [DailyCheck], windowDays: Int = 2) -> InsightResult {
        let cal = Calendar.current
        let byDay = Dictionary(grouping: meals) { cal.startOfDay(for: $0.date) }
        var bloatedSets: [Set<String>] = []
        var clearSets: [Set<String>] = []
        var bloatedRisk: [Int] = []
        var clearRisk: [Int] = []

        for check in checks {
            guard let bloated = check.answer else { continue }
            let end = cal.startOfDay(for: check.day)
            let window = (0...windowDays).flatMap { offset -> [MealEntry] in
                guard let day = cal.date(byAdding: .day, value: -offset, to: end) else { return [] }
                return byDay[day] ?? []
            }
            let foods = Set(window.flatMap { foodNames($0.text) })
            let risk = window.filter { $0.status == .limit || $0.status == .avoid }.count
            if bloated {
                bloatedSets.append(foods); bloatedRisk.append(risk)
            } else {
                clearSets.append(foods); clearRisk.append(risk)
            }
        }

        let allFoods = Set(bloatedSets.flatMap { $0 })
        var scored: [(suspect: FoodSuspect, gap: Double)] = []
        for food in allFoods {
            let b = bloatedSets.filter { $0.contains(food) }.count
            let c = clearSets.filter { $0.contains(food) }.count
            let gap = Double(b) / Double(max(bloatedSets.count, 1)) - Double(c) / Double(max(clearSets.count, 1))
            if b >= 2 && gap > 0.2 {
                scored.append((FoodSuspect(food: food, bloatedWindows: b, clearWindows: c), gap))
            }
        }
        let suspects = scored.sorted { $0.gap > $1.gap }.map(\.suspect)

        func average(_ values: [Int]) -> Double {
            values.isEmpty ? 0 : Double(values.reduce(0, +)) / Double(values.count)
        }
        return InsightResult(
            bloatedDays: bloatedSets.count,
            clearDays: clearSets.count,
            suspects: Array(suspects.prefix(6)),
            riskBloated: average(bloatedRisk),
            riskClear: average(clearRisk)
        )
    }

    /// One logged item can still hold a few foods ("chicken, rice"); split them up.
    private static func foodNames(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { ",;\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "meal" }
    }
}
