import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private let service = "com.mojomoney.app"

    // MARK: - Monarch credentials

    func saveMonarchCredentials(email: String, password: String) -> Bool {
        deleteItem(account: "monarch.credentials")
        let data = "\(email):\(password)".data(using: .utf8)!
        return addItem(account: "monarch.credentials", data: data)
    }

    func getMonarchCredentials() -> (email: String, password: String)? {
        guard let data = readItem(account: "monarch.credentials"),
              let string = String(data: data, encoding: .utf8) else { return nil }
        let parts = string.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    func getMonarchEmail() -> String? {
        getMonarchCredentials()?.email
    }

    func deleteMonarchCredentials() {
        deleteItem(account: "monarch.credentials")
    }

    // MARK: - Session token

    func saveSessionToken(_ token: String) -> Bool {
        deleteItem(account: "monarch.session_token")
        return addItem(account: "monarch.session_token", data: Data(token.utf8))
    }

    func getSessionToken() -> String? {
        guard let data = readItem(account: "monarch.session_token") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteSessionToken() {
        deleteItem(account: "monarch.session_token")
    }

    // MARK: - Helpers

    private func addItem(account: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      account,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlocked
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private func readItem(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account,
            kSecMatchLimit as String:   kSecMatchLimitOne,
            kSecReturnData as String:   true
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private func deleteItem(account: String) {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
