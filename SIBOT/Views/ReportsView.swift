import SwiftData
import SwiftUI

/// The doctor report (PDF / CSV) and food trials. Charts and triggers are in Analytics.
struct ReportsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MealEntry.date) private var meals: [MealEntry]
    @Query private var checks: [DailyCheck]
    @Query private var supplements: [Supplement]
    @Query private var supplementLogs: [SupplementLog]
    @Query private var bowelMovements: [BowelMovement]
    @Query private var bloatEpisodes: [BloatEpisode]
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodTrial.startDate, order: .reverse) private var trials: [FoodTrial]
    @State private var showingNewTrial = false
    @State private var newTrialFood = ""

    @State private var days = 14
    @State private var files: (pdf: URL, csv: URL)?

    private var input: ReportBuilder.Input {
        ReportBuilder.Input(days: days, meals: meals, checks: checks, supplements: supplements, supplementLogs: supplementLogs, bowelMovements: bowelMovements, bloatEpisodes: bloatEpisodes)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Period", selection: $days) {
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if let files {
                        ShareLink("PDF", item: files.pdf)
                        ShareLink("Spreadsheet (CSV)", item: files.csv)
                    } else {
                        Text("Preparing…").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Export")
                }

                Section {
                    ForEach(trials) { trial in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trial.food).font(.headline)
                                Text("Started \(trial.startDate.formatted(.dateTime.month(.abbreviated).day()))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Menu {
                                Button("Tolerated it") { setResult(trial, 1) }
                                Button("Reacted") { setResult(trial, 2) }
                                Button("Still testing") { setResult(trial, 0) }
                                Button("Delete", role: .destructive) { modelContext.delete(trial) }
                            } label: {
                                Text(trial.resultRaw == 1 ? "TOLERATED" : trial.resultRaw == 2 ? "REACTED" : "TESTING")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(trial.resultRaw == 1 ? Theme.green : trial.resultRaw == 2 ? Theme.red : Theme.purple)
                            }
                        }
                    }
                    Button("Test a new food") { showingNewTrial = true }
                } header: {
                    Text("Food trials")
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .groupedPage()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Test a food", isPresented: $showingNewTrial) {
                TextField("Food, e.g. avocado", text: $newTrialFood)
                Button("Start") {
                    let name = newTrialFood.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { modelContext.insert(FoodTrial(food: name)) }
                    newTrialFood = ""
                }
                Button("Cancel", role: .cancel) { newTrialFood = "" }
            }
            .task(id: days) { files = ReportBuilder.writeFiles(input) }
        }
    }

    private func setResult(_ trial: FoodTrial, _ result: Int) {
        trial.resultRaw = result
        switch result {
        case 1: PersonalFoods.set(trial.food, to: .safe)
        case 2: PersonalFoods.set(trial.food, to: .avoid)
        default: break
        }
    }
}
