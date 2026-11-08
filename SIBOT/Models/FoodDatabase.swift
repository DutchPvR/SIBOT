import Foundation

struct FoodItem: Codable, Identifiable, Hashable {
    let name: String
    let aliases: [String]
    let status: String
    let note: String

    var id: String { name }
    /// Your own setting wins over the bundled list.
    var foodStatus: FoodStatus {
        PersonalFoods.status(for: name) ?? FoodStatus(rawValue: status) ?? .unknown
    }

    var isPersonal: Bool { note == FoodItem.personalNote }
    static let personalNote = "Added by you."
}

private struct FoodFile: Codable {
    let source: String
    let foods: [FoodItem]
}

/// Bundled low-fermentation food list. Edit Resources/foods.json to match your own guide.
final class FoodDatabase {
    static let shared = FoodDatabase()

    let foods: [FoodItem]
    let source: String
    /// Lowercased name + aliases per food, worked out once instead of on every keystroke.
    private let names: [[String]]

    private init() {
        if let url = Bundle.main.url(forResource: "foods", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(FoodFile.self, from: data) {
            foods = file.foods
            source = file.source
        } else {
            foods = []
            source = "Food list could not be loaded."
        }
        names = foods.map { [$0.name.lowercased()] + $0.aliases.map { $0.lowercased() } }
    }

    /// Matches a free-text query against names and aliases. Best matches first.
    func search(_ query: String) -> [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        var scored: [(FoodItem, Int)] = []
        for (item, itemNames) in zip(foods, names) {
            var best = 0
            for n in itemNames {
                if n == q { best = max(best, 100) }
                else if n.hasPrefix(q) { best = max(best, 70) }
                else if n.contains(q) { best = max(best, 50) }
                else if q.contains(n) && n.count >= 3 { best = max(best, 40) }
            }
            if best > 0 { scored.append((item, best)) }
        }
        // Foods you added yourself that the bundled list does not have.
        let bundled = Set(foods.map { $0.name.lowercased() })
        for (name, raw) in PersonalFoods.all where !bundled.contains(name) && name.contains(q) {
            scored.append((FoodItem(name: name.capitalized, aliases: [], status: raw, note: FoodItem.personalNote), name == q ? 100 : 60))
        }
        return scored.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    /// Best single match for a logged meal, or nil.
    func bestStatus(for text: String) -> FoodStatus? {
        let lower = text.lowercased()
        let words = lower
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }

        var found: [FoodStatus] = []
        for (item, itemNames) in zip(foods, names) {
            if itemNames.contains(where: { lower.contains($0) || words.contains($0) }) {
                found.append(item.foodStatus)
            }
        }
        for (name, raw) in PersonalFoods.all where lower.contains(name) {
            if let status = FoodStatus(rawValue: raw) { found.append(status) }
        }
        if found.contains(.avoid) { return .avoid }
        if found.contains(.limit) { return .limit }
        if found.contains(.safe) { return .safe }
        return nil
    }
}
