import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @State private var gapHours = MealTimerStore.gapHours
    @State private var apiKey = Keychain.load(account: AIFoodChecker.keyAccount) ?? ""
    @State private var keySaved = false
    @AppStorage(AIFoodChecker.modelDefaultsKey) private var aiModel = AIFoodChecker.defaultModel
    @FocusState private var fieldFocused: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var backupDocument = BackupDocument(data: Data())
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingRestore: URL?
    @State private var backupMessage: String?
    @State private var goalNotification = MealTimerStore.goalNotificationOn
    @AppStorage(NotificationManager.remindersOnKey) private var remindersOn = true
    @AppStorage(BackupService.lastBackupKey) private var lastBackup: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $gapHours, in: 1...8, step: 0.5) {
                        Text("Goal between meals: \(gapText) h")
                    }
                    .onChange(of: gapHours) { _, newValue in
                        MealTimerStore.gapHours = newValue
                    }
                } header: {
                    Text("Fasting timer")
                } footer: {
                    Text("The timer counts up from your last meal. The goal turns it green and sends a \"you can eat\" notification. The Cedars-Sinai handout recommends at least 4 hours.")
                }

                Section {
                    Toggle("Fasting goal reached", isOn: $goalNotification)
                        .onChange(of: goalNotification) { _, on in
                            MealTimerStore.goalNotificationOn = on
                            if !on {
                                UNUserNotificationCenter.current()
                                    .removePendingNotificationRequests(withIdentifiers: [MealTimerController.notificationID])
                            } else if let start = MealTimerStore.startDate {
                                Task { await MealTimerController.start(at: start) }
                            }
                        }
                    Toggle("Supplement reminders", isOn: $remindersOn)
                        .onChange(of: remindersOn) { _, _ in
                            let supplements = (try? modelContext.fetch(FetchDescriptor<Supplement>())) ?? []
                            NotificationManager.rescheduleAll(supplements)
                        }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Each supplement can also be turned off on its own in Reminders.")
                }

                Section {
                    SecureField("OpenRouter API key (sk-or-…)", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .onSubmit { fieldFocused = false }
                    Picker("Model", selection: modelChoice) {
                        ForEach(Self.models) { Text($0.name).tag($0.id) }
                        Text("Custom…").tag(Self.customTag)
                    }
                    if isCustomModel {
                        TextField("Model name, e.g. vendor/model", text: $aiModel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($fieldFocused)
                            .submitLabel(.done)
                            .onSubmit { fieldFocused = false }
                    }
                    Button(keySaved ? "Saved" : "Save") {
                        Keychain.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                                      account: AIFoodChecker.keyAccount)
                        keySaved = true
                        fieldFocused = false
                    }
                    .onChange(of: apiKey) { _, _ in keySaved = false }
                } header: {
                    Text("AI fallback (optional)")
                } footer: {
                    Text("Used for foods that are not on the built-in list. Pick a model, or choose Custom to enter any name from openrouter.ai/models. The key is stored in this phone's Keychain and only sent to OpenRouter.")
                }

                Section {
                    Button("Back up to Files / iCloud Drive") {
                        do {
                            backupDocument = BackupDocument(data: try BackupService.makeData(context: modelContext))
                            showingExporter = true
                        } catch {
                            backupMessage = "Could not make the backup: \(error.localizedDescription)"
                        }
                    }
                    Button("Restore from a backup…") { showingImporter = true }
                    if let backupMessage {
                        Text(backupMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Choose iCloud Drive in the Files picker to keep a copy in iCloud. Restoring replaces everything currently in the app.\(lastBackupText)")
                }

                Section {
                    Text(FoodDatabase.shared.source)
                        .font(.footnote)
                    Text("SIBOT is a personal tracking tool, not medical advice. Follow your doctor or dietitian's guidance.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("About the food list")
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .fileExporter(
                isPresented: $showingExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "SIBOT-backup-\(Date().formatted(.iso8601.year().month().day()))"
            ) { result in
                switch result {
                case .success: backupMessage = "Backup saved."
                case .failure(let error): backupMessage = "Backup failed: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result { pendingRestore = url }
            }
            .confirmationDialog(
                "Replace everything in the app with this backup?",
                isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                titleVisibility: .visible
            ) {
                Button("Restore", role: .destructive) {
                    if let url = pendingRestore {
                        do {
                            try BackupService.restore(from: url, context: modelContext)
                            backupMessage = "Backup restored."
                        } catch {
                            backupMessage = "Could not restore: \(error.localizedDescription)"
                        }
                    }
                    pendingRestore = nil
                }
                Button("Cancel", role: .cancel) { pendingRestore = nil }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { fieldFocused = false }
                }
            }
        }
    }

    private static let customTag = "__custom__"

    /// Cheap models that handle a one-line food rating well. The first is the default.
    private struct ModelChoice: Identifiable {
        let id: String
        let name: String
    }

    private static let models = [
        ModelChoice(id: "anthropic/claude-haiku-5.5", name: "Claude Haiku 5.5 (cheap, recommended)"),
        ModelChoice(id: "google/gemini-3.7-flash", name: "Gemini 3.7 Flash (cheap)"),
        ModelChoice(id: "anthropic/claude-sonnet-5", name: "Claude Sonnet 5 (best, pricier)")
    ]

    @State private var customSelected = false

    private var isCustomModel: Bool {
        customSelected || !Self.models.contains { $0.id == aiModel }
    }

    private var modelChoice: Binding<String> {
        Binding(
            get: { isCustomModel ? Self.customTag : aiModel },
            set: { choice in
                if choice == Self.customTag {
                    customSelected = true
                } else {
                    customSelected = false
                    aiModel = choice
                }
            }
        )
    }

    private var lastBackupText: String {
        guard lastBackup > 0 else { return " No backup yet." }
        return " Last backup: \(Date(timeIntervalSince1970: lastBackup).formatted(date: .abbreviated, time: .shortened))."
    }

    private var gapText: String {
        gapHours == gapHours.rounded() ? String(Int(gapHours)) : String(format: "%.1f", gapHours)
    }

}
