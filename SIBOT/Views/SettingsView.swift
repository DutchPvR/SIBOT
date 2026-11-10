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
    @AppStorage(Appearance.defaultsKey) private var appearance: Appearance = .automatic
    @State private var showingReports = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: appearance) { _, newValue in newValue.apply() }
                } header: {
                    Text("Appearance")
                }

                Section {
                    Stepper(value: $gapHours, in: 1...8, step: 0.5) {
                        LabeledContent("Between meals", value: "\(gapText) h")
                    }
                    .onChange(of: gapHours) { _, newValue in
                        MealTimerStore.gapHours = newValue
                        WatchSync.shared.push()
                    }
                } header: {
                    Text("Timer")
                }

                Section {
                    Toggle("Goal reached", isOn: $goalNotification)
                        .onChange(of: goalNotification) { _, on in
                            MealTimerStore.goalNotificationOn = on
                            if !on {
                                UNUserNotificationCenter.current()
                                    .removePendingNotificationRequests(withIdentifiers: [MealTimerController.notificationID])
                            } else if let start = MealTimerStore.startDate {
                                Task { await MealTimerController.start(at: start) }
                            }
                        }
                    Toggle("Supplements", isOn: $remindersOn)
                        .onChange(of: remindersOn) { _, _ in
                            let supplements = (try? modelContext.fetch(FetchDescriptor<Supplement>())) ?? []
                            NotificationManager.rescheduleAll(supplements)
                        }
                } header: {
                    Text("Notifications")
                }

                Section {
                    SecureField("OpenRouter key", text: $apiKey)
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
                        TextField("vendor/model", text: $aiModel)
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
                    Text("AI fallback")
                }

                Section {
                    Button("Export log") { showingReports = true }
                    Button("Back up") {
                        do {
                            backupDocument = BackupDocument(data: try BackupService.makeData(context: modelContext))
                            showingExporter = true
                        } catch {
                            backupMessage = "Could not make the backup: \(error.localizedDescription)"
                        }
                    }
                    Button("Restore…") { showingImporter = true }
                    LabeledContent("Last backup", value: lastBackupText)
                    if let backupMessage {
                        Text(backupMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Data")
                }

                Section {
                    NavigationLink("About") { AboutView() }
                }
            }
            .tabHeader("Settings", grouped: true)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.groupedBackground)
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
            .sheet(isPresented: $showingReports) {
                ReportsView()
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
        ModelChoice(id: "anthropic/claude-haiku-5.5", name: "Claude Haiku 5.5"),
        ModelChoice(id: "google/gemini-3.7-flash", name: "Gemini 3.7 Flash"),
        ModelChoice(id: "anthropic/claude-sonnet-5", name: "Claude Sonnet 5")
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
        guard lastBackup > 0 else { return "Never" }
        return Date(timeIntervalSince1970: lastBackup).formatted(date: .abbreviated, time: .shortened)
    }

    private var gapText: String {
        gapHours == gapHours.rounded() ? String(Int(gapHours)) : String(format: "%.1f", gapHours)
    }

}

/// Food list source and the medical note, kept off the main settings list.
private struct AboutView: View {
    var body: some View {
        Form {
            Section("Food list") {
                Text(FoodDatabase.shared.source)
                    .font(.footnote)
            }
            Section {
                Text("Not medical advice. Follow your doctor or dietitian.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Theme.groupedBackground)
    }
}
