import SwiftData
import SwiftUI

/// The journal block at the top of a day: bloat, severity and symptoms.
struct BloatCheckBar: View {
    @Environment(\.modelContext) private var modelContext

    let day: Date
    let check: DailyCheck?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("BELLY TODAY")
            HStack(spacing: 10) {
                bloatButton("No bloat", value: false)
                bloatButton("Bloated", value: true)
            }

            if check?.answer == true {
                label("HOW BAD")
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { level in
                        let selected = check?.severity == level
                        Button {
                            edit { $0.severity = selected ? 0 : level }
                        } label: {
                            Text("\(level)")
                                .font(.subheadline.weight(selected ? .heavy : .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .background(selected ? Theme.purple : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(selected ? Theme.purple : Theme.hairline))
                        }
                        .buttonStyle(.plain)
                    }
                }

                label("SYMPTOMS")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DailyCheck.symptomOptions, id: \.self) { symptom in
                            let on = check?.symptoms.contains(symptom) == true
                            Button {
                                edit { entry in
                                    var list = entry.symptoms
                                    if on { list.removeAll { $0 == symptom } } else { list.append(symptom) }
                                    entry.symptoms = list
                                }
                            } label: {
                                Text(symptom)
                                    .font(.footnote.weight(on ? .heavy : .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(on ? Color.white : Color.primary)
                                    .background(on ? Theme.purple : Color.clear, in: Capsule())
                                    .overlay(Capsule().stroke(on ? Theme.purple : Theme.hairline))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .tracking(1.5)
            .foregroundStyle(.secondary)
    }

    /// Same marks as the month view: ring = no bloat, filled dot = bloated.
    private func bloatButton(_ title: String, value: Bool) -> some View {
        let selected = check?.answer == value
        return Button {
            setBloat(value)
        } label: {
            HStack(spacing: 10) {
                BloatMark(bloated: value, size: 14)
                Text(title)
                    .font(.subheadline.weight(selected ? .heavy : .medium))
            }
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(selected ? Color.primary : Theme.hairline, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Tap an answer to set it; tap it again to clear it.
    private func setBloat(_ value: Bool) {
        if let check {
            if check.answer == value {
                check.answered = false
                check.severity = 0
                check.symptoms = []
                if check.isEmpty { modelContext.delete(check) }
            } else {
                check.bloated = value
                check.answered = true
                if !value {
                    check.severity = 0
                    check.symptoms = []
                }
            }
        } else {
            modelContext.insert(DailyCheck(day: day, bloated: value))
        }
    }

    /// Change the day's entry, creating one (without a bloat answer) if needed.
    private func edit(_ change: (DailyCheck) -> Void) {
        let entry: DailyCheck
        if let check {
            entry = check
        } else {
            entry = DailyCheck(day: day, bloated: false, answered: false)
            modelContext.insert(entry)
        }
        change(entry)
        if entry.isEmpty { modelContext.delete(entry) }
    }
}
