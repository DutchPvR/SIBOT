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
}

/// Looks back from each journal day to the food eaten that day and the days before it,
/// and shows which foods turn up more before bloated days than before clear days.
enum Insights {
    static func analyze(meals: [MealEntry], checks: [DailyCheck], windowDays: Int = 2) -> InsightResult {
        let cal = Calendar.current
        var bloatedSets: [Set<String>] = []
        var clearSets: [Set<String>] = []
        var bloatedRisk: [Int] = []
        var clearRisk: [Int] = []

        for check in checks {
            guard let bloated = check.answer else { continue }
            let end = cal.startOfDay(for: check.day)
            guard let start = cal.date(byAdding: .day, value: -windowDays, to: end),
                  let stop = cal.date(byAdding: .day, value: 1, to: end) else { continue }
            let window = meals.filter { $0.date >= start && $0.date < stop }
            let foods = Set(window.flatMap { foodNames($0.text) })
            let risk = window.filter { $0.status == .limit || $0.status == .avoid }.count
            if bloated {
                bloatedSets.append(foods); bloatedRisk.append(risk)
            } else {
                clearSets.append(foods); clearRisk.append(risk)
            }
        }

        let allFoods = Set(bloatedSets.flatMap { $0 })
        var suspects: [FoodSuspect] = []
        for food in allFoods {
            let b = bloatedSets.filter { $0.contains(food) }.count
            let c = clearSets.filter { $0.contains(food) }.count
            let bloatRate = Double(b) / Double(max(bloatedSets.count, 1))
            let clearRate = Double(c) / Double(max(clearSets.count, 1))
            if b >= 2 && bloatRate > clearRate + 0.2 {
                suspects.append(FoodSuspect(food: food, bloatedWindows: b, clearWindows: c))
            }
        }
        suspects.sort {
            let l = Double($0.bloatedWindows) / Double(max(bloatedSets.count, 1)) - Double($0.clearWindows) / Double(max(clearSets.count, 1))
            let r = Double($1.bloatedWindows) / Double(max(bloatedSets.count, 1)) - Double($1.clearWindows) / Double(max(clearSets.count, 1))
            return l > r
        }

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
