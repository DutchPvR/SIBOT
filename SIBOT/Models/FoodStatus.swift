import SwiftUI

enum FoodStatus: String, Codable, CaseIterable, Identifiable {
    case safe, limit, avoid, unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .safe: return "Safe"
        case .limit: return "Limit"
        case .avoid: return "Avoid"
        case .unknown: return "Not sure"
        }
    }

    var emoji: String {
        switch self {
        case .safe: return "✅"
        case .limit: return "⚠️"
        case .avoid: return "🚫"
        case .unknown: return "❓"
        }
    }

    var color: Color {
        switch self {
        case .safe: return Theme.mint
        case .limit: return Theme.orange
        case .avoid: return Theme.pink
        case .unknown: return Theme.sky
        }
    }
}
