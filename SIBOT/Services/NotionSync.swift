import CryptoKit
import Foundation
import SwiftData
import SwiftUI

/// Sends SIBOT's log to the "SIBOT Log" database in Notion: meals, daily bloat checks,
/// supplement doses and bowel movements.
///
/// Every entry gets a stable App ID, so syncing again updates the same Notion page instead of
/// adding a copy. Only entries that changed since the last sync are sent. Entries you delete in
/// the app stay in Notion.
///
/// The integration token lives in this phone's Keychain (never in code or UserDefaults).
enum NotionSync {
    static let tokenAccount = "notionToken"
    static let dataSourceKey = "notionDataSourceID"
    static let lastSyncKey = "notionLastSync"
    private static let hashesKey = "notionSyncedHashes"

    /// The data source of the SIBOT Log database (not a secret: useless without the token).
    static let defaultDataSourceID = "e3ed8887-acb5-498a-b21c-1bdac3daa0a2"

    private static let apiVersion = "2025-09-03"
    private static let base = URL(string: "https://api.notion.com/v1/")!

    @MainActor private static var isRunning = false

    static var dataSourceID: String {
        let saved = UserDefaults.standard.string(forKey: dataSourceKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return saved.isEmpty ? defaultDataSourceID : saved
    }

    static var hasToken: Bool { !(Keychain.load(account: tokenAccount) ?? "").isEmpty }

    struct Summary {
        var created = 0
        var updated = 0
        var unchanged = 0
        var text: String { "\(created) added, \(updated) updated, \(unchanged) already in Notion" }
    }

    enum SyncError: LocalizedError {
        case noToken
        case alreadyRunning
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .noToken: return "Add your Notion integration token first."
            case .alreadyRunning: return "A sync is already running."
            case .http(401, _): return "Notion rejected the token. Paste it again."
            case .http(404, _): return "Notion can't find the SIBOT Log database. Connect the integration to it (••• > Connections)."
            case .http(let code, let message): return "Notion error \(code): \(message)"
            }
        }
    }

    // MARK: - Sync

    /// Sends every new or changed entry. Safe to call often.
    @MainActor
    @discardableResult
    static func syncAll(context: ModelContext) async throws -> Summary {
        guard let token = Keychain.load(account: tokenAccount), !token.isEmpty else { throw SyncError.noToken }
        guard !isRunning else { throw SyncError.alreadyRunning }
        isRunning = true
        defer { isRunning = false }

        // Saving first turns temporary model IDs into permanent ones, so App IDs stay stable.
        try? context.save()

        let entries = buildEntries(context: context)
        var hashes = UserDefaults.standard.dictionary(forKey: hashesKey) as? [String: String] ?? [:]
        let pending = entries.filter { hashes[$0.appID] != $0.hash }

        var summary = Summary(unchanged: entries.count - pending.count)
        guard !pending.isEmpty else {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSyncKey)
            return summary
        }

        let dsID = dataSourceID
        let existing = try await existingPages(dataSourceID: dsID, token: token)

        for entry in pending {
            let properties = try JSONSerialization.jsonObject(with: entry.json)
            if let pageID = existing[entry.appID] {
                _ = try await send("PATCH", "pages/\(pageID)", token: token, body: ["properties": properties])
                summary.updated += 1
            } else {
                let body: [String: Any] = [
                    "parent": ["type": "data_source_id", "data_source_id": dsID],
                    "properties": properties
                ]
                _ = try await send("POST", "pages", token: token, body: body)
                summary.created += 1
            }
            // Save progress as we go, so an interrupted sync picks up where it stopped.
            hashes[entry.appID] = entry.hash
            UserDefaults.standard.set(hashes, forKey: hashesKey)
            // Notion allows about 3 requests a second.
            try await Task.sleep(nanoseconds: 350_000_000)
        }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSyncKey)
        return summary
    }

    /// Quiet sync for when the app comes to the foreground. Does nothing without a token.
    @MainActor
    static func syncInBackgroundIfSetUp(context: ModelContext) {
        guard hasToken else { return }
        Task { _ = try? await syncAll(context: context) }
    }

    /// Forget what was sent, so the next sync checks every entry against Notion again
    /// (for example after switching to another database, or deleting pages in Notion).
    static func resetSyncState() {
        UserDefaults.standard.removeObject(forKey: hashesKey)
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
    }

    // MARK: - Entries

    private struct Entry {
        let appID: String
        let json: Data
        let hash: String
    }

    @MainActor
    private static func buildEntries(context: ModelContext) -> [Entry] {
        var entries: [Entry] = []

        for meal in (try? context.fetch(FetchDescriptor<MealEntry>())) ?? [] {
            let appID = "meal-" + stableID(meal.persistentModelID, fallback: meal.date)
            entries.append(entry(appID, [
                "Entry": title(meal.text),
                "Type": select("Meal"),
                "Date": dateTime(meal.date),
                "Food": text(meal.text),
                "Food verdict": select(meal.status.label),
                "Meal symptom score": number(meal.symptomScore)
            ]))
        }

        for check in (try? context.fetch(FetchDescriptor<DailyCheck>())) ?? [] where check.answered {
            let day = dayString(check.day)
            entries.append(entry("check-\(day)", [
                "Entry": title(check.bloated ? "Bloat" : "No bloat"),
                "Type": select("Bloat check"),
                "Date": ["date": ["start": day]],
                "Bloat": select(check.bloated ? "Bloat" : "No bloat"),
                "Severity": number(check.severity == 0 ? nil : check.severity),
                "Symptoms": ["multi_select": check.symptoms.map { ["name": $0] }]
            ]))
        }

        for log in (try? context.fetch(FetchDescriptor<SupplementLog>())) ?? [] {
            let appID = "supp-\(log.supplementID.uuidString)-\(dayString(log.day))-\(log.slot)"
            let doseTime = log.slot >= 0 ? "Dose at \(Supplement.timeText(log.slot))" : ""
            entries.append(entry(appID, [
                "Entry": title("\(log.supplementName) \(log.taken ? "taken" : "skipped")"),
                "Type": select("Supplement"),
                "Date": dateTime(log.date),
                "Supplement": text(log.supplementName),
                "Taken": ["checkbox": log.taken],
                "Notes": text(doseTime)
            ]))
        }

        for movement in (try? context.fetch(FetchDescriptor<BowelMovement>())) ?? [] {
            let appID = "bowel-" + stableID(movement.persistentModelID, fallback: movement.date)
            entries.append(entry(appID, [
                "Entry": title(movement.typeText),
                "Type": select("Bowel movement"),
                "Date": dateTime(movement.date),
                "Bristol type": number(movement.type == 0 ? nil : movement.type)
            ]))
        }

        return entries
    }

    private static func entry(_ appID: String, _ properties: [String: Any]) -> Entry {
        var all = properties
        all["App ID"] = text(appID)
        let json = (try? JSONSerialization.data(withJSONObject: all, options: [.sortedKeys])) ?? Data()
        let hash = SHA256.hash(data: json).map { String(format: "%02x", $0) }.joined()
        return Entry(appID: appID, json: json, hash: hash)
    }

    /// A short ID that stays the same for a stored model, even when its date or text is edited.
    private static func stableID(_ id: PersistentIdentifier, fallback date: Date) -> String {
        guard let data = try? JSONEncoder().encode(id) else {
            return String(Int(date.timeIntervalSince1970))
        }
        return SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Property helpers

    private static func title(_ value: String) -> [String: Any] {
        ["title": [["text": ["content": String((value.isEmpty ? "Entry" : value).prefix(2000))]]]]
    }

    private static func text(_ value: String) -> [String: Any] {
        ["rich_text": value.isEmpty ? [] : [["text": ["content": String(value.prefix(2000))]]]]
    }

    private static func select(_ name: String) -> [String: Any] {
        ["select": ["name": name]]
    }

    private static func number(_ value: Int?) -> [String: Any] {
        ["number": value.map { $0 as Any } ?? NSNull()]
    }

    private static func dateTime(_ date: Date) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withInternetDateTime]
        return ["date": ["start": formatter.string(from: date)]]
    }

    private static func dayString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Notion API

    /// App ID -> Notion page ID for every page already in the database.
    private static func existingPages(dataSourceID: String, token: String) async throws -> [String: String] {
        var map: [String: String] = [:]
        var cursor: String?
        repeat {
            var body: [String: Any] = ["page_size": 100]
            if let cursor { body["start_cursor"] = cursor }
            let json = try await send("POST", "data_sources/\(dataSourceID)/query", token: token, body: body)
            for page in json["results"] as? [[String: Any]] ?? [] {
                guard let pageID = page["id"] as? String,
                      let properties = page["properties"] as? [String: Any],
                      let appIDProperty = properties["App ID"] as? [String: Any],
                      let parts = appIDProperty["rich_text"] as? [[String: Any]] else { continue }
                let appID = parts.compactMap { $0["plain_text"] as? String }.joined()
                if !appID.isEmpty { map[appID] = pageID }
            }
            cursor = (json["has_more"] as? Bool == true) ? json["next_cursor"] as? String : nil
        } while cursor != nil
        return map
    }

    private static func send(_ method: String, _ path: String, token: String, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: path, relativeTo: base)!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        for attempt in 0..<4 {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

            if (200..<300).contains(status) { return json }

            // Rate limited or a passing server error: wait and try again.
            if (status == 429 || status >= 500) && attempt < 3 {
                let wait = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) } ?? 1
                try await Task.sleep(nanoseconds: UInt64(max(wait, 1) * 1_000_000_000))
                continue
            }
            throw SyncError.http(status, json["message"] as? String ?? "Unknown error")
        }
        throw SyncError.http(429, "Rate limited")
    }
}

// MARK: - Settings section

/// Drop this inside the Form in SettingsView.
struct NotionSyncSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var token = Keychain.load(account: NotionSync.tokenAccount) ?? ""
    @AppStorage(NotionSync.dataSourceKey) private var dataSourceID = ""
    @AppStorage(NotionSync.lastSyncKey) private var lastSync: Double = 0
    @State private var status: String?
    @State private var syncing = false

    var body: some View {
        Section {
            SecureField("Integration token", text: $token)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: token) { _, newValue in
                    Keychain.save(newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                                  account: NotionSync.tokenAccount)
                }

            TextField("Data source ID", text: $dataSourceID,
                      prompt: Text(NotionSync.defaultDataSourceID))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.footnote.monospaced())
                .onChange(of: dataSourceID) { _, _ in NotionSync.resetSyncState() }

            Button {
                Task { await syncNow() }
            } label: {
                HStack {
                    Text("Sync now")
                    if syncing { Spacer(); ProgressView() }
                }
            }
            .disabled(syncing || token.isEmpty)

            Button("Send everything again") {
                NotionSync.resetSyncState()
                Task { await syncNow() }
            }
            .disabled(syncing || token.isEmpty)

            if let status {
                Text(status).font(.footnote).foregroundStyle(.secondary)
            } else if lastSync > 0 {
                Text("Last sync \(Date(timeIntervalSince1970: lastSync).formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Notion sync")
        } footer: {
            Text("Sends meals, bloat checks, supplement doses and bowel movements to the SIBOT Log database in Notion when the app opens, or when you tap Sync now. The token is stored in this phone's Keychain and only sent to Notion.")
        }
    }

    @MainActor
    private func syncNow() async {
        syncing = true
        defer { syncing = false }
        do {
            let summary = try await NotionSync.syncAll(context: modelContext)
            status = summary.text
        } catch {
            status = error.localizedDescription
        }
    }
}
