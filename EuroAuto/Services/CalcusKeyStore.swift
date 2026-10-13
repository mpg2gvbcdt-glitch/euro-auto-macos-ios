import Foundation
import Security

enum CalcusKeyStore {
    private static let service = "com.nordauto.euroauto.calcus"
    private static let clientIDAccount = "client-id"
    private static let apiKeyAccount = "api-key"

    struct Credentials {
        let clientID: String
        let apiKey: String
    }

    static var hasCredentials: Bool { (try? readCredentials()) != nil }

    static func save(clientID: String, apiKey: String) throws {
        let normalizedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedClientID.isEmpty, !normalizedAPIKey.isEmpty else { throw KeyStoreError.emptyCredentials }
        try saveItem(normalizedClientID, account: clientIDAccount)
        do {
            try saveItem(normalizedAPIKey, account: apiKeyAccount)
        } catch {
            try? deleteItem(account: clientIDAccount)
            throw error
        }
    }

    private static func saveItem(_ string: String, account: String) throws {
        let value = Data(string.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let update: [String: Any] = [kSecValueData as String: value]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = value
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeyStoreError.keychain(addStatus) }
        } else if status != errSecSuccess {
            throw KeyStoreError.keychain(status)
        }
    }

    private static func readItem(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeyStoreError.keychain(status)
        }
        return key
    }

    static func readCredentials() throws -> Credentials {
        Credentials(clientID: try readItem(account: clientIDAccount), apiKey: try readItem(account: apiKeyAccount))
    }

    private static func deleteItem(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyStoreError.keychain(status)
        }
    }

    static func delete() throws {
        try deleteItem(account: clientIDAccount)
        try deleteItem(account: apiKeyAccount)
    }

    enum KeyStoreError: LocalizedError {
        case emptyCredentials
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case .emptyCredentials: "Введите ID клиента и API-ключ Calcus."
            case .keychain(let status): "Не удалось сохранить ключ Calcus (ошибка Связки ключей: \(status))."
            }
        }
    }
}
