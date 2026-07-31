import Foundation
import Security

protocol RefreshCredentialStore: Sendable {
    func read(account: String) throws -> String?
    func readUser(account: String) throws -> AuthenticatedUser?
    func save(_ credential: String, account: String) throws
    func saveUser(_ user: AuthenticatedUser, account: String) throws
    func delete(account: String) throws
}

struct KeychainRefreshCredentialStore: RefreshCredentialStore {
    private let service = "app.tazkle.desktop.authentication"
    private let identitySuffix = "|validated-identity-v1"

    func read(account: String) throws -> String? {
        guard let data = try readData(account: account) else {
            return nil
        }
        guard
            let credential = String(data: data, encoding: .utf8),
            !credential.isEmpty
        else {
            throw AuthenticationFailure.credentialStorage
        }
        return credential
    }

    func readUser(account: String) throws -> AuthenticatedUser? {
        guard let data = try readData(account: identityAccount(for: account)) else {
            return nil
        }
        guard
            let identity = try? JSONDecoder().decode(
                StoredValidatedIdentity.self,
                from: data
            ),
            let user = AuthenticatedUser(
                subject: identity.subject,
                name: identity.name,
                email: identity.email,
                isEmailVerified: identity.isEmailVerified
            )
        else {
            throw AuthenticationFailure.credentialStorage
        }
        return user
    }

    func save(_ credential: String, account: String) throws {
        guard
            !credential.isEmpty,
            credential.count <= 32_768,
            let data = credential.data(using: .utf8)
        else {
            throw AuthenticationFailure.credentialStorage
        }
        try saveData(data, account: account)
    }

    func saveUser(_ user: AuthenticatedUser, account: String) throws {
        let identity = StoredValidatedIdentity(
            subject: user.subject,
            name: user.name,
            email: user.email,
            isEmailVerified: user.isEmailVerified,
            validatedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(identity), data.count <= 16_384 else {
            throw AuthenticationFailure.credentialStorage
        }
        try saveData(data, account: identityAccount(for: account))
    }

    func delete(account: String) throws {
        try deleteItem(account: account)
        try deleteItem(account: identityAccount(for: account))
    }

    private func readData(account: String) throws -> Data? {
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
            let data = item as? Data
        else {
            throw AuthenticationFailure.credentialStorage
        }
        return data
    }

    private func saveData(_ data: Data, account: String) throws {
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

    private func deleteItem(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthenticationFailure.credentialStorage
        }
    }

    private func identityAccount(for account: String) -> String {
        account + identitySuffix
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

private struct StoredValidatedIdentity: Codable {
    let subject: String
    let name: String?
    let email: String?
    let isEmailVerified: Bool
    let validatedAt: Date
}
