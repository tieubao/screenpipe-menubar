import Foundation
import Security

// The ONLY place a cloud LLM API key is stored. Generic-password items in the macOS Keychain,
// service `app.screenpipe.menubar`, account per provider. The key is never written to the config
// file or UserDefaults (the privacy invariant); callers store via `set`, check presence via
// `exists`, and never read it back into the UI.

enum KeychainStore {
    static let service = "app.screenpipe.menubar"

    @discardableResult
    static func set(_ value: String, account: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)   // replace any existing
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(account: String) -> Bool {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary) == errSecSuccess
    }

    static func exists(account: String) -> Bool { get(account: account) != nil }
}
