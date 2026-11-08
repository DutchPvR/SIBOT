import SwiftUI

struct SettingsView: View {
    @State private var gapHours = MealTimerStore.gapHours
    @State private var apiKey = Keychain.load(account: AIFoodChecker.keyAccount) ?? ""
    @State private var keySaved = false
    @AppStorage(AIFoodChecker.modelDefaultsKey) private var aiModel = AIFoodChecker.defaultModel
    @FocusState private var fieldFocused: Bool

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
                    Text("The timer counts up from your last meal. The goal turns it green and sends a \"you can eat\" notification. Default is 5 hours. Changes apply the next time you tap \"I just ate\".")
                }

                Section {
                    SecureField("OpenRouter API key (sk-or-…)", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .onSubmit { fieldFocused = false }
                    TextField("Model", text: $aiModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .onSubmit { fieldFocused = false }
                    Button(keySaved ? "Saved ✓" : "Save") {
                        Keychain.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                                      account: AIFoodChecker.keyAccount)
                        keySaved = true
                        fieldFocused = false
                    }
                    .onChange(of: apiKey) { _, _ in keySaved = false }
                } header: {
                    Text("AI fallback (optional)")
                } footer: {
                    Text("Used for foods that are not on the built-in list. Enter any model name from openrouter.ai/models, for example anthropic/claude-sonnet-4.5. The key is stored in this phone's Keychain and only sent to OpenRouter.")
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
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { fieldFocused = false }
                }
            }
        }
    }

    private var gapText: String {
        gapHours == gapHours.rounded() ? String(Int(gapHours)) : String(format: "%.1f", gapHours)
    }

}
