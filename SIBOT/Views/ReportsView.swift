import SwiftData
import SwiftUI

/// Summary, possible triggers and the doctor report (PDF / CSV).
struct ReportsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MealEntry.date) private var meals: [MealEntry]
    @Query private var checks: [DailyCheck]
    @Query private var supplements: [Supplement]
    @Query private var supplementLogs: [SupplementLog]
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodTrial.startDate, order: .reverse) private var trials: [FoodTrial]
    @State private var showingNewTrial = false
    @State private var newTrialFood = ""

    @State private var days = 14
    @State private var files: (pdf: URL, csv: URL)?

    private var input: ReportBuilder.Input {
        ReportBuilder.Input(days: days, meals: meals, checks: checks, supplements: supplements, supplementLogs: supplementLogs)
    }

    var body: some View {
        let insight = Insights.analyze(meals: meals, checks: checks)
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
                        ShareLink(item: files.pdf) {
                            Label("Share PDF for your doctor", systemImage: "doc.richtext")
                        }
                        ShareLink(item: files.csv) {
                            Label("Share spreadsheet (CSV)", systemImage: "tablecells")
                        }
                    } else {
                        Text("Preparing…").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Export")
                } footer: {
                    Text("Meals with times, bloat days, symptoms, bowel movements and supplements for the period.")
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
                } footer: {
                    Text("Test one food at a time and note how you react. Marking the result sets that food to Safe or Avoid just for you.")
                }

                Section {
                    row("Bloated days", "\(insight.bloatedDays)")
                    row("No-bloat days", "\(insight.clearDays)")
                } header: {
                    Text("All time")
                }

                Section {
                    if insight.hasEnoughData {
                        if insight.suspects.isEmpty {
                            Text("No food stands out yet.").foregroundStyle(.secondary)
                        }
                        ForEach(insight.suspects) { suspect in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suspect.food.capitalized).font(.headline)
                                Text("Before \(suspect.bloatedWindows) of \(insight.bloatedDays) bloated days, \(suspect.clearWindows) of \(insight.clearDays) clear days")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        row("Limit/Avoid items before bloated days", String(format: "%.1f", insight.riskBloated))
                        row("Limit/Avoid items before clear days", String(format: "%.1f", insight.riskClear))
                    } else {
                        Text("Log at least 3 bloated and 3 clear days to see patterns.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Possible triggers")
                } footer: {
                    Text("Compares the day and the 2 days before each bloat answer. It shows patterns in your diary, not causes.")
                }
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
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

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
    }
}
