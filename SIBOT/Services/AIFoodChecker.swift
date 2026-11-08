import Foundation

struct AIFoodVerdict {
    let status: FoodStatus
    let reason: String
}

enum AIFoodError: LocalizedError {
    case missingKey
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Add your OpenRouter API key in Settings to ask AI about foods that are not on the list."
        case .badResponse(let detail):
            return detail
        }
    }
}

/// Asks an AI model (through OpenRouter) about foods that are not in the bundled list.
/// The API key lives in the iOS Keychain on this device only.
enum AIFoodChecker {
    static let keyAccount = "openrouter-api-key"
    static let modelDefaultsKey = "aiModel"
    static let defaultModel = "anthropic/claude-sonnet-4.5"

    static var model: String {
        let saved = UserDefaults.standard.string(forKey: modelDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return saved.isEmpty ? defaultModel : saved
    }

    private static let systemPrompt = """
    You help someone with SIBO follow the Cedars-Sinai low fermentation diet. \
    Rules of that diet: proteins and fats are allowed; simple easily digested carbohydrates are best \
    (white rice, potatoes, sweet potatoes, white or sourdough bread, regular sugar); \
    avoid cabbage, Brussels sprouts, broccoli, cauliflower and leafy vegetables as a main dish (a small side is okay); \
    avoid beans, legumes, chickpeas and hummus; avoid whole wheat, multigrain, bran and oats; \
    avoid regular dairy with lactose (use lactose-free milk; hard aged cheese is fine) and avoid yogurt and probiotic or fermented foods; \
    avoid sugar alcohols (sorbitol, xylitol, mannitol), sucralose and gum; aspartame is allowed; \
    most fruit is fine one serving at a time, but limit apples, pears and ripe bananas, and avoid dried fruit; \
    nuts are fine; avoid chia and flax seeds; onion and garlic are allowed in small cooked amounts.
    Given a food or meal, answer with ONLY a JSON object: \
    {"status": "safe" | "limit" | "avoid", "reason": "one or two short sentences"}. \
    If you are unsure, choose "limit" and say what is uncertain. Do not give medical advice.
    """

    static func check(_ food: String) async throws -> AIFoodVerdict {
        guard let key = Keychain.load(account: keyAccount), !key.isEmpty else {
            throw AIFoodError.missingKey
        }

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("SIBOT", forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Food or meal: \(food)"]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIFoodError.badResponse("No response from OpenRouter.")
        }
        guard http.statusCode == 200 else {
            switch http.statusCode {
            case 401:
                throw AIFoodError.badResponse("OpenRouter rejected the API key. Check it in Settings.")
            case 402:
                throw AIFoodError.badResponse("OpenRouter says your account is out of credits.")
            case 400, 404:
                throw AIFoodError.badResponse("OpenRouter could not use the model “\(model)”. Check the model name in Settings.")
            default:
                throw AIFoodError.badResponse("OpenRouter returned an error (\(http.statusCode)).")
            }
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String
        else {
            throw AIFoodError.badResponse("Could not read the AI's answer.")
        }
        return try parse(text)
    }

    private static func parse(_ text: String) throws -> AIFoodVerdict {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start < end,
              let data = String(text[start...end]).data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let statusString = obj["status"] as? String
        else {
            throw AIFoodError.badResponse("The AI's answer was not in the expected format.")
        }
        let status = FoodStatus(rawValue: statusString.lowercased()) ?? .limit
        let reason = (obj["reason"] as? String) ?? ""
        return AIFoodVerdict(status: status == .unknown ? .limit : status, reason: reason)
    }
}
