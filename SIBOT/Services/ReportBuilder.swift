import UIKit

/// Builds the doctor report (PDF) and the spreadsheet (CSV) from the journal.
enum ReportBuilder {
    struct Input {
        let days: Int
        let meals: [MealEntry]
        let checks: [DailyCheck]
        let supplements: [Supplement]
        let supplementLogs: [SupplementLog]
    }

    private static var calendar: Calendar { .current }

    private static func rangeStart(_ days: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
    }

    private static func dayList(_ days: Int) -> [Date] {
        let start = rangeStart(days)
        return (0..<days).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private static func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - CSV

    private static func field(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func csv(_ input: Input) -> String {
        var rows = ["Date,Time,Type,Item,Result,Details"]
        func row(_ date: Date, _ time: String, _ type: String, _ item: String, _ result: String, _ details: String) {
            let d = date.formatted(.iso8601.year().month().day())
            rows.append([d, time, type, item, result, details].map(field).joined(separator: ","))
        }
        for day in dayList(input.days) {
            for meal in input.meals.filter({ calendar.isDate($0.date, inSameDayAs: day) }).sorted(by: { $0.date < $1.date }) {
                let symptoms = meal.symptomScore.map { "symptoms \($0)/5" } ?? ""
                row(day, timeText(meal.date), "Meal", meal.text, meal.status.label, symptoms)
            }
            if let check = input.checks.first(where: { calendar.isDate($0.day, inSameDayAs: day) }) {
                if let bloated = check.answer {
                    var details: [String] = []
                    if check.severity > 0 { details.append("severity \(check.severity)/5") }
                    if !check.symptoms.isEmpty { details.append(check.symptoms.joined(separator: " + ")) }
                    row(day, "", "Bloat", bloated ? "Bloated" : "No bloat", bloated ? "Bloated" : "No bloat", details.joined(separator: "; "))
                }
                if check.bowelCount > 0 || check.bowelType > 0 {
                    let type = check.bowelType > 0 ? "Bristol type \(check.bowelType)" : ""
                    row(day, "", "Bowel", "\(check.bowelCount) movement(s)", type, DailyCheck.bristolNames[check.bowelType] ?? "")
                }
            }
            for log in input.supplementLogs.filter({ calendar.isDate($0.day, inSameDayAs: day) }).sorted(by: { $0.date < $1.date }) {
                row(day, timeText(log.date), "Supplement", log.supplementName, log.taken ? "Taken" : "Skipped", "")
            }
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - PDF

    private final class Page {
        let rect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 48
        var context: UIGraphicsPDFRendererContext!
        var y: CGFloat = 48

        func newPage() {
            context.beginPage()
            y = margin
        }

        func write(_ text: String, font: UIFont, color: UIColor = .black, indent: CGFloat = 0, after: CGFloat = 4) {
            let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
            let width = rect.width - 2 * margin - indent
            let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
            let height = ceil(attributed.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude), options: options, context: nil).height)
            if y + height > rect.height - margin { newPage() }
            attributed.draw(with: CGRect(x: margin + indent, y: y, width: width, height: height), options: options, context: nil)
            y += height + after
        }
    }

    static func pdf(_ input: Input) -> Data {
        let page = Page()
        let renderer = UIGraphicsPDFRenderer(bounds: page.rect)
        let start = rangeStart(input.days)
        let range = "\(start.formatted(date: .abbreviated, time: .omitted)) – \(Date().formatted(date: .abbreviated, time: .omitted))"

        return renderer.pdfData { context in
            page.context = context
            page.newPage()
            let title = UIFont.systemFont(ofSize: 22, weight: .heavy)
            let heading = UIFont.systemFont(ofSize: 13, weight: .heavy)
            let body = UIFont.systemFont(ofSize: 11)
            let bold = UIFont.systemFont(ofSize: 11, weight: .semibold)
            let grey = UIColor.darkGray

            page.write("SIBO diary", font: title, after: 2)
            page.write(range, font: body, color: grey, after: 12)

            // Summary
            let answered = input.checks.filter { $0.answer != nil && $0.day >= start }
            let bloatedDays = answered.filter { $0.answer == true }
            let rated = bloatedDays.filter { $0.severity > 0 }
            page.write("SUMMARY", font: heading, after: 4)
            page.write("Days with a bloat answer: \(answered.count) of \(input.days)", font: body)
            page.write("Bloated days: \(bloatedDays.count)  ·  No-bloat days: \(answered.count - bloatedDays.count)", font: body)
            if !rated.isEmpty {
                let average = Double(rated.map(\.severity).reduce(0, +)) / Double(rated.count)
                page.write(String(format: "Average severity on bloated days: %.1f of 5", average), font: body)
            }
            var counts: [String: Int] = [:]
            for check in bloatedDays { for symptom in check.symptoms { counts[symptom, default: 0] += 1 } }
            if !counts.isEmpty {
                let text = counts.sorted { $0.value > $1.value }.map { "\($0.key) (\($0.value))" }.joined(separator: ", ")
                page.write("Symptoms on bloated days: \(text)", font: body)
            }
            let periodMeals = input.meals.filter { $0.date >= start }
            let flagged = periodMeals.filter { $0.status == .limit || $0.status == .avoid }.count
            page.write("Items logged: \(periodMeals.count)  ·  rated Limit or Avoid: \(flagged)", font: body, after: 10)

            // Supplements
            if !input.supplements.isEmpty {
                page.write("SUPPLEMENTS AND PRESCRIPTIONS", font: heading, after: 4)
                for supplement in input.supplements {
                    let stats = supplement.adherence(logs: input.supplementLogs, days: input.days)
                    let dose = supplement.dose.isEmpty ? "" : " \(supplement.dose)"
                    var line = "\(supplement.name)\(dose), \(supplement.timeText), \(supplement.daysText)"
                    if stats.expected > 0 { line += " — taken \(stats.taken) of \(stats.expected) days" }
                    page.write(line, font: body, after: 1)
                    if let course = supplement.courseText { page.write(course, font: body, color: grey, indent: 12, after: 1) }
                    if !supplement.notes.isEmpty { page.write(supplement.notes, font: body, color: grey, indent: 12, after: 1) }
                }
                page.y += 8
            }

            // Possible triggers
            let insight = Insights.analyze(meals: input.meals, checks: input.checks)
            page.write("POSSIBLE TRIGGERS", font: heading, after: 4)
            if insight.hasEnoughData && !insight.suspects.isEmpty {
                for suspect in insight.suspects {
                    page.write("\(suspect.food.capitalized): before \(suspect.bloatedWindows) of \(insight.bloatedDays) bloated days, \(suspect.clearWindows) of \(insight.clearDays) clear days", font: body, after: 1)
                }
                page.write("Looks at the day and the 2 days before. A pattern in the diary, not a diagnosis.", font: body, color: grey, after: 10)
            } else {
                page.write("Not enough days logged yet to see a pattern.", font: body, color: grey, after: 10)
            }

            // Day by day
            page.write("DAY BY DAY", font: heading, after: 4)
            for day in dayList(input.days).reversed() {
                let meals = input.meals.filter { calendar.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
                let check = input.checks.first { calendar.isDate($0.day, inSameDayAs: day) }
                let logs = input.supplementLogs.filter { calendar.isDate($0.day, inSameDayAs: day) }
                if meals.isEmpty && check == nil && logs.isEmpty { continue }

                var header = day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
                if let bloated = check?.answer {
                    header += bloated ? "  —  BLOATED" : "  —  no bloat"
                    if bloated, let severity = check?.severity, severity > 0 { header += " (\(severity)/5)" }
                }
                page.write(header, font: bold, after: 2)
                if let check, check.answer == true, !check.symptoms.isEmpty {
                    page.write("Symptoms: \(check.symptoms.joined(separator: ", "))", font: body, color: grey, indent: 12, after: 1)
                }
                if let check, check.bowelCount > 0 || check.bowelType > 0 {
                    var text = "Bowel: \(check.bowelCount) movement(s)"
                    if check.bowelType > 0 { text += ", Bristol type \(check.bowelType)" }
                    page.write(text, font: body, color: grey, indent: 12, after: 1)
                }
                for meal in meals {
                    var line = "\(timeText(meal.date))  \(meal.text)  [\(meal.status.label)]"
                    if let score = meal.symptomScore { line += "  symptoms \(score)/5" }
                    page.write(line, font: body, indent: 12, after: 1)
                }
                for log in logs.sorted(by: { $0.date < $1.date }) {
                    page.write("\(timeText(log.date))  \(log.supplementName): \(log.taken ? "taken" : "skipped")", font: body, indent: 12, after: 1)
                }
                page.y += 6
            }
            page.write("Generated by SIBOT. Personal tracking record, not medical advice.", font: body, color: grey)
        }
    }

    // MARK: - Files

    /// Writes the files to a temporary folder and returns their URLs.
    static func writeFiles(_ input: Input) -> (pdf: URL, csv: URL)? {
        let stamp = Date().formatted(.iso8601.year().month().day())
        let folder = FileManager.default.temporaryDirectory
        let pdfURL = folder.appendingPathComponent("SIBOT-diary-\(stamp).pdf")
        let csvURL = folder.appendingPathComponent("SIBOT-diary-\(stamp).csv")
        do {
            try pdf(input).write(to: pdfURL, options: .atomic)
            try csv(input).write(to: csvURL, atomically: true, encoding: .utf8)
            return (pdfURL, csvURL)
        } catch {
            return nil
        }
    }
}
