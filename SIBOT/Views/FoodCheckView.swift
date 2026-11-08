import SwiftData
import SwiftUI

/// The Check tab: a quick cheat sheet by default. Pull down to reveal the search bar,
/// which takes over the screen with results while you search.
struct FoodCheckView: View {
    @State private var query = ""

    var body: some View {
        NavigationStack {
            FoodCheckContent(query: query)
                .navigationTitle("Can I eat this?")
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "Search a food, e.g. oatmeal"
                )
        }
    }
}

private struct FoodCheckContent: View {
    /// True while the search bar is active. Only works inside the view that has `.searchable`.
    @Environment(\.isSearching) private var isSearching
    @Environment(\.modelContext) private var modelContext

    let query: String

    @State private var aiVerdict: AIFoodVerdict?
    @State private var aiError: String?
    @State private var isAsking = false
    @State private var loggedMessage: String?

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var results: [FoodItem] { FoodDatabase.shared.search(query) }

    var body: some View {
        ZStack {
            Theme.background
            ScrollView {
                VStack(spacing: 14) {
                    if isSearching || !trimmed.isEmpty {
                        searchResults
                    } else {
                        cheatSheet
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: query) { _, _ in
            aiVerdict = nil
            aiError = nil
            loggedMessage = nil
        }
        // Nothing on the list? Check with the AI automatically once you stop typing.
        // The task restarts (and the old one is cancelled) every time the text changes.
        .task(id: trimmed) {
            guard trimmed.count >= 3, FoodDatabase.shared.search(trimmed).isEmpty else { return }
            do {
                try await Task.sleep(nanoseconds: 700_000_000)
            } catch {
                return // text changed during the pause
            }
            await ask()
        }
    }

    // MARK: - Cheat sheet

    private var cheatSheet: some View {
        VStack(spacing: 14) {
            Label("Not here? Pull down to search", systemImage: "arrow.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            sheetCard(
                status: .safe,
                title: "Good",
                lines: [
                    "Meat, fish, eggs, plain proteins",
                    "White rice, potatoes, sweet potatoes",
                    "White, sourdough or French bread, plain pasta",
                    "Carrots, cucumber, tomato, zucchini, peppers, eggplant, green beans",
                    "Most fruit, one serving at a time (berries, citrus, grapes, pineapple, melon)",
                    "Lactose-free milk, hard aged cheese",
                    "Nuts, oils, butter",
                    "Plain sugar, dark chocolate"
                ]
            )

            sheetCard(
                status: .limit,
                title: "Small amounts",
                lines: [
                    "Onion and garlic, cooked and small",
                    "Leafy greens and salad, only as a side",
                    "Apples, pears, ripe bananas",
                    "Avocado, mushrooms, honey"
                ]
            )

            sheetCard(
                status: .avoid,
                title: "Not good",
                lines: [
                    "Broccoli, cauliflower, cabbage, Brussels sprouts",
                    "Beans, lentils, chickpeas, hummus",
                    "Whole wheat, multigrain, oats, bran",
                    "Regular milk, yogurt, soft cheese, ice cream",
                    "Sugar alcohols (sorbitol, xylitol), Splenda, gum",
                    "Dried fruit (raisins, dates, figs, prunes)",
                    "Chia and flax seeds",
                    "Probiotic and fermented foods (kombucha, kimchi)"
                ]
            )

            Text("Quick reference from the starter list, based on the Cedars-Sinai diet. Check your own guide or doctor for anything that matters.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
                .padding(.horizontal)
        }
    }

    private func sheetCard(status: FoodStatus, title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                StatusDot(status: status)
                Text(title.uppercased())
                    .font(.caption.weight(.heavy))
                    .tracking(1.5)
                    .foregroundStyle(status.color)
            }
            ForEach(lines, id: \.self) { line in
                Hairline()
                Text(line)
                    .font(.system(.body).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Search results

    @ViewBuilder
    private var searchResults: some View {
        if trimmed.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Theme.purple)
                Text("Type a food to see if it fits the diet.")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
        } else {
            ForEach(results) { item in
                resultCard(item)
            }
            askAICard
            if let loggedMessage {
                Text(loggedMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resultCard(_ item: FoodItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.name)
                    .font(.system(.headline))
                Spacer()
                StatusBadge(status: item.foodStatus)
            }
            Text(item.note)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            logButton(text: item.name, status: item.foodStatus)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var askAICard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(results.isEmpty ? "Not on the list" : "Not what you meant?")
                .font(.system(.headline))

            if let aiVerdict {
                HStack {
                    Text("AI guess")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(Theme.purple)
                    Spacer()
                    StatusBadge(status: aiVerdict.status)
                }
                Text(aiVerdict.reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Generated by an AI model, not from your food list. Verify if it matters.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                logButton(text: trimmed, status: aiVerdict.status)
            } else {
                if let aiError {
                    Text(aiError)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                }
                Button {
                    Task { await ask() }
                } label: {
                    HStack {
                        if isAsking { ProgressView() }
                        Text(isAsking ? "Checking with AI…" : "Ask AI about “\(trimmed)”")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.purple)
                .disabled(isAsking)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func logButton(text: String, status: FoodStatus) -> some View {
        Button {
            modelContext.insert(MealEntry(text: text, status: status))
            loggedMessage = "Logged “\(text)”."
        } label: {
            Label("Log it", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
        }
        .tint(Theme.purple)
    }

    private func ask() async {
        let food = trimmed
        guard !food.isEmpty else { return }
        isAsking = true
        aiError = nil
        do {
            let verdict = try await AIFoodChecker.check(food)
            // Ignore the answer if you have kept typing since.
            if food == trimmed { aiVerdict = verdict }
        } catch is CancellationError {
            // Search text changed; a newer check will run.
        } catch {
            if food == trimmed { aiError = error.localizedDescription }
        }
        isAsking = false
    }
}
