import SwiftData
import SwiftUI

/// The journal block at the top of a day: bloat, severity, symptoms and bowel movements.
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

            label("BOWEL MOVEMENTS")
            HStack(spacing: 14) {
                Button { edit { $0.bowelCount = max($0.bowelCount - 1, 0) } } label: {
                    Image(systemName: "minus.circle").font(.title3)
                }
                Text("\(check?.bowelCount ?? 0)")
                    .font(.headline)
                    .frame(minWidth: 24)
                Button { edit { $0.bowelCount += 1 } } label: {
                    Image(systemName: "plus.circle").font(.title3)
                }
                Spacer()
                Menu {
                    Picker("Type", selection: Binding(
                        get: { check?.bowelType ?? 0 },
                        set: { value in edit { $0.bowelType = value } }
                    )) {
                        Text("Not set").tag(0)
                        ForEach(1...7, id: \.self) { type in
                            Text("\(type) – \(DailyCheck.bristolNames[type] ?? "")").tag(type)
                        }
                    }
                } label: {
                    Text(typeText)
                        .font(.footnote.weight(.semibold))
                }
            }
            .buttonStyle(.borderless)
            .tint(Theme.purple)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private var typeText: String {
        let type = check?.bowelType ?? 0
        return type == 0 ? "Stool type" : "Type \(type) · \(DailyCheck.bristolNames[type] ?? "")"
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
                ZStack {
                    Circle().strokeBorder(Color.primary, lineWidth: 1.5)
                    if value { Circle().fill(Color.primary) }
                }
                .frame(width: 14, height: 14)
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
        if let check {
            change(check)
        } else {
            let entry = DailyCheck(day: day, bloated: false, answered: false)
            modelContext.insert(entry)
            change(entry)
        }
    }
}
