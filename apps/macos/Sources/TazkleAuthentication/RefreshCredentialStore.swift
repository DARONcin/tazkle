import Foundation
import Security

protocol RefreshCredentialStore: Sendable {
    func read(account: String) throws -> String?
    func save(_ credential: String, account: String) throws
    func delete(account: String) throws
}

struct KeychainRefreshCredentialStore: RefreshCredentialStore {
    private let service = "app.tazkle.desktop.authentication"

    func read(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard
            status == errSecSuccess,
            let data = item as? Data,
            let credential = String(data: data, encoding: .utf8),
            !credential.isEmpty
        else {
            throw AuthenticationFailure.credentialStorage
        }
        return credential
    }

    func save(_ credential: String, account: String) throws {
        guard
            !credential.isEmpty,
            credential.count <= 32_768,
            let data = credential.data(using: .utf8)
        else {
            throw AuthenticationFailure.credentialStorage
        }

        let query = baseQuery(account: account)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw AuthenticationFailure.credentialStorage
        }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw AuthenticationFailure.credentialStorage
        }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthenticationFailure.credentialStorage
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
        ]
    }
}
