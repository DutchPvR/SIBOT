import Foundation
import Security

/// Tiny Keychain wrapper used to store the OpenRouter API key.
/// The key stays on this device only: it is not included in iCloud or device backups.
enum Keychain {
    private static let service = "com.dutchpvr.sibot"

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    /// Saves the value, replacing any earlier one. An empty value removes it.
    @discardableResult
    static func save(_ value: String, account: String) -> Bool {
        let base = baseQuery(account)
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty else { return true }

        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    /// Whether a value is stored, without reading it into memory.
    static func exists(account: String) -> Bool {
        var query = baseQuery(account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
