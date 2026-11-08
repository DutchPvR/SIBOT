import Foundation

struct FoodItem: Codable, Identifiable, Hashable {
    let name: String
    let aliases: [String]
    let status: String
    let note: String

    var id: String { name }
    var foodStatus: FoodStatus { FoodStatus(rawValue: status) ?? .unknown }
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
    }

    /// Matches a free-text query against names and aliases. Best matches first.
    func search(_ query: String) -> [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        var scored: [(FoodItem, Int)] = []
        for item in foods {
            let names = [item.name.lowercased()] + item.aliases.map { $0.lowercased() }
            var best = 0
            for n in names {
                if n == q { best = max(best, 100) }
                else if n.hasPrefix(q) { best = max(best, 70) }
                else if n.contains(q) { best = max(best, 50) }
                else if q.contains(n) && n.count >= 3 { best = max(best, 40) }
            }
            if best > 0 { scored.append((item, best)) }
        }
        return scored.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    /// Best single match for a logged meal, or nil.
    func bestStatus(for text: String) -> FoodStatus? {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }

        var found: [FoodStatus] = []
        for item in foods {
            let names = [item.name.lowercased()] + item.aliases.map { $0.lowercased() }
            if names.contains(where: { text.lowercased().contains($0) || words.contains($0) }) {
                found.append(item.foodStatus)
            }
        }
        if found.contains(.avoid) { return .avoid }
        if found.contains(.limit) { return .limit }
        if found.contains(.safe) { return .safe }
        return nil
    }
}
