import SwiftUI

struct SettingsView: View {
    @State private var gapHours = MealTimerStore.gapHours
    @State private var apiKey = Keychain.load(account: AIFoodChecker.keyAccount) ?? ""
    @State private var keySaved = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $gapHours, in: 1...8, step: 0.5) {
                        Text("Wait between meals: \(gapText) h")
                    }
                    .onChange(of: gapHours) { _, newValue in
                        MealTimerStore.gapHours = newValue
                    }
                } header: {
                    Text("Meal timer")
                } footer: {
                    Text("Default is 5 hours. Changes apply the next time you start the timer.")
                }

                Section {
                    SecureField("sk-ant-…", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button(keySaved ? "Saved ✓" : "Save key") {
                        Keychain.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                                      account: AIFoodChecker.keyAccount)
                        keySaved = true
                    }
                    .onChange(of: apiKey) { _, _ in keySaved = false }
                } header: {
                    Text("Ask Claude (optional)")
                } footer: {
                    Text("Used for foods that are not on the built-in list. The key is stored in this phone's Keychain and only sent to Anthropic.")
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
            .background(Theme.background)
        }
    }

    private var gapText: String {
        gapHours == gapHours.rounded() ? String(Int(gapHours)) : String(format: "%.1f", gapHours)
    }

}
