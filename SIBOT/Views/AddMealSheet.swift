import SwiftData
import SwiftUI

/// Log one meal made of several items, all at the same time.
/// Used for "I just ate", the + button in the Log, long-press on a day, and "Add another item".
struct AddMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(AddMealSheet.pastMealsDescriptor) private var pastMeals: [MealEntry]

    /// The last 300 items are plenty to find what you eat most.
    nonisolated private static var pastMealsDescriptor: FetchDescriptor<MealEntry> {
        var descriptor = FetchDescriptor<MealEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 300
        return descriptor
    }

    struct Recent: Hashable {
        let text: String
        let status: FoodStatus
    }

    struct Item: Identifiable {
        let id = UUID()
        var text: String
        var status: FoodStatus
    }

    let title: String
    @State private var when: Date
    @State private var items: [Item] = []
    @State private var draft = ""
    @FocusState private var draftFocused: Bool

    init(initialDate: Date = Date(), title: String = "Log a meal") {
        self.title = title
        _when = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            Button {
                                cycleStatus(item)
                            } label: {
                                StatusDot(status: item.status, size: 14)
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                            Text(item.text)
                            Spacer()
                            Text(item.status.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { items.remove(atOffsets: $0) }

                    HStack {
                        TextField("Add an item, e.g. chicken", text: $draft)
                            .focused($draftFocused)
                            .submitLabel(.done)
                            .onSubmit(addDraft)
                        Button("Add", action: addDraft)
                            .disabled(trimmedDraft.isEmpty)
                    }
                } header: {
                    Text("What did you eat?")
                } footer: {
                    Text("Tap a dot to change its status.")
                }

                if !recents.isEmpty {
                    Section("Recent") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recents, id: \.self) { recent in
                                    Button {
                                        items.append(Item(text: recent.text, status: recent.status))
                                    } label: {
                                        HStack(spacing: 6) {
                                            StatusDot(status: recent.status, size: 8)
                                            Text(recent.text).font(.footnote.weight(.medium))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .overlay(Capsule().stroke(Theme.hairline))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                Section {
                    DatePicker("Time", selection: $when)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { draftFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear { draftFocused = true }
        }
    }

    /// Foods you log most, with the status you gave them last time. One tap adds them.
    private var recents: [Recent] {
        let added = Set(items.map { $0.text.lowercased() })
        var counts: [String: (count: Int, recent: Recent)] = [:]
        for meal in pastMeals {
            let key = meal.text.lowercased()
            guard key != "meal", !added.contains(key) else { continue }
            if let entry = counts[key] {
                counts[key] = (entry.count + 1, entry.recent)
            } else {
                counts[key] = (1, Recent(text: meal.text, status: meal.status))
            }
        }
        return counts.values
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.recent.text < $1.recent.text }
            .prefix(12)
            .map(\.recent)
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addDraft() {
        let text = trimmedDraft
        guard !text.isEmpty else { return }
        let status = FoodDatabase.shared.bestStatus(for: text) ?? .unknown
        items.append(Item(text: text, status: status))
        draft = ""
        draftFocused = true
    }

    private func cycleStatus(_ item: Item) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let all = FoodStatus.allCases
        let next = (all.firstIndex(of: items[index].status) ?? 0) + 1
        items[index].status = all[next % all.count]
    }

    private func save() {
        addDraft()
        // Saving with nothing typed still logs the time of the meal.
        let toSave = items.isEmpty ? [Item(text: "Meal", status: .unknown)] : items
        for item in toSave {
            modelContext.insert(MealEntry(date: when, text: item.text, status: item.status))
        }
        dismiss()
    }
}

/// Edit one logged item: its text, status and time.
struct EditMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var meal: MealEntry
    @FocusState private var focused: Bool

    private var statusBinding: Binding<FoodStatus> {
        Binding(get: { meal.status }, set: { meal.statusRaw = $0.rawValue })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What") {
                    TextField("Food", text: $meal.text, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($focused)
                }
                Section("How does it fit the diet?") {
                    Picker("Status", selection: statusBinding) {
                        ForEach(FoodStatus.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("When") {
                    DatePicker("Time", selection: $meal.date)
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
