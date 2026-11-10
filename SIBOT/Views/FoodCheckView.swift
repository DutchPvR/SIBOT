import PhotosUI
import SwiftData
import SwiftUI

/// The Check tab: a search bar with the menu camera beside it, and the cheat sheet below.
/// While you search, results replace the cheat sheet.
struct FoodCheckView: View {
    @State private var query = ""
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var scan: ScanImage?
    @State private var cameraImage: UIImage?
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchRow
                FoodCheckContent(query: query, isSearching: searchFocused)
            }
                .tabHeader("Check")
                // Open the results only once the camera has fully closed.
                .fullScreenCover(isPresented: $showingCamera, onDismiss: {
                    if let image = cameraImage { scan = ScanImage(image: image) }
                    cameraImage = nil
                }) {
                    CameraPicker { cameraImage = $0 }
                        .ignoresSafeArea()
                }
                .photosPicker(isPresented: $showingLibrary, selection: $libraryItem, matching: .images)
                .onChange(of: libraryItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            scan = ScanImage(image: image)
                        }
                        libraryItem = nil
                    }
                }
                .sheet(item: $scan) { MenuScanView(image: $0.image) }
        }
    }

    private var searchRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search a food, e.g. oatmeal", text: $query)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Menu {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take a photo of a menu") { showingCamera = true }
                }
                Button("Choose a menu photo") { showingLibrary = true }
            } label: {
                Image(systemName: "camera")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .tint(Theme.purple)
            .accessibilityLabel("Scan a menu")

            if searchFocused {
                Button("Cancel") {
                    query = ""
                    searchFocused = false
                }
                .tint(Theme.purple)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
        .animation(.default, value: searchFocused)
    }
}

private struct FoodCheckContent: View {
    @Environment(\.modelContext) private var modelContext

    let query: String
    /// True while the search field has the keyboard.
    let isSearching: Bool

    @State private var aiVerdict: AIFoodVerdict?
    @State private var aiError: String?
    @State private var isAsking = false
    @State private var loggedMessage: String?
    @State private var refreshTick = 0

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var results: [FoodItem] {
        _ = refreshTick // re-read after you change a food's setting
        return FoodDatabase.shared.search(query)
    }

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
        // Not on your list? Ask the AI once you pause typing.
        // Restarts (cancelling the old wait) on every keystroke, so only the final text is sent.
        // Answers are cached on the phone, so the same food never costs twice.
        .task(id: trimmed) {
            guard trimmed.count >= 3, FoodDatabase.shared.search(trimmed).isEmpty else { return }
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            await ask()
        }
    }

    // MARK: - Cheat sheet

    // From the Cedars-Sinai "Low Fermentation Diet / SIBO Diet" handout (Mark Pimentel, M.D.).
    // Short lines on purpose: readable at a glance. Search covers the details.
    private var cheatSheet: some View {
        VStack(alignment: .leading, spacing: 32) {
            sheetSection(.safe, "Good", [
                "Meat, fish, eggs",
                "Rice, potatoes, pasta",
                "White or sourdough bread",
                "Onion, garlic, root vegetables",
                "Tomato, cucumber, peppers, zucchini",
                "Most fruit",
                "Nuts, oils, sugar",
                "Lactaid milk"
            ])
            sheetSection(.limit, "Small amounts", [
                "Apples, pears, bananas",
                "Side salad",
                "Butter, hard cheese"
            ])
            sheetSection(.avoid, "Not good", [
                "Beans, hummus",
                "Broccoli, cabbage, cauliflower",
                "Whole wheat, oatmeal",
                "Milk, cheese, yogurt",
                "Splenda, gum, honey",
                "Probiotics"
            ])
        }
        .padding(.top, 8)
    }

    private func sheetSection(_ status: FoodStatus, _ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                StatusDot(status: status, size: 10)
                Text(title.uppercased())
                    .font(.footnote.weight(.heavy))
                    .tracking(1.5)
                    .foregroundStyle(status.color)
            }
            .padding(.bottom, 10)
            ForEach(lines, id: \.self) { line in
                Hairline()
                Text(line)
                    .font(.title3)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Hairline()
        }
    }

    // MARK: - Search results

    @ViewBuilder
    private var searchResults: some View {
        let results = self.results
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
                Hairline()
            }
            askAICard(onList: !results.isEmpty)
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
                Menu {
                    Section("Set for me") {
                        ForEach([FoodStatus.safe, .limit, .avoid]) { status in
                            Button(status.label) {
                                PersonalFoods.set(item.name, to: status)
                                refreshTick += 1
                            }
                        }
                    }
                    Button("Use the list's setting") {
                        PersonalFoods.set(item.name, to: nil)
                        refreshTick += 1
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .tint(Theme.purple)
            }
            Text(item.note)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            logButton(text: item.name, status: item.foodStatus)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func askAICard(onList: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(onList ? "Not what you meant?" : "Not on the list")
                .font(.system(.headline))

            if let aiVerdict {
                HStack {
                    Text("AI GUESS")
                        .font(.caption.weight(.heavy))
                        .tracking(1)
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
                HStack(spacing: 16) {
                    logButton(text: trimmed, status: aiVerdict.status)
                    Button {
                        PersonalFoods.set(trimmed, to: aiVerdict.status)
                        refreshTick += 1
                    } label: {
                        Text("Save to my list")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Theme.purple)
                }
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
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
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
            Text("Log it")
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
