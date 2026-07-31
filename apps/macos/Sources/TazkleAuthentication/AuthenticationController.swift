import Combine
import Foundation
import Security

@MainActor
public final class AuthenticationController: ObservableObject {
    @Published public private(set) var state: AuthenticationState
    @Published public private(set) var user: AuthenticatedUser?
    @Published public private(set) var isDeletingAccount = false
    @Published public private(set) var accountDeletionFailure: AuthenticationFailure?
    @Published public private(set) var hasPendingLocalAccountCleanup = false

    public let configuration: OIDCConfiguration?

    public var workspaceAccountID: String? {
        guard let configuration, let user else { return nil }
        return Self.workspaceAccountID(
            issuer: configuration.issuer,
            user: user
        )
    }

    private let client: OIDCClient?
    private let credentialStore: any RefreshCredentialStore
    private let webAuthenticator: SystemWebAuthenticator
    private var accessToken: String?
    private var accessTokenExpiresAt: Date?
    private var pendingLocalAccountCleanupID: String?

    public convenience init() {
        let configuration: OIDCConfiguration?
        let initialState: AuthenticationState
        do {
            configuration = try OIDCConfiguration.load()
            initialState = configuration == nil ? .configurationRequired : .signedOut
        } catch {
            configuration = nil
            initialState = .failed(.invalidConfiguration)
        }
        self.init(configuration: configuration, initialState: initialState)
    }

    init(
        configuration: OIDCConfiguration?,
        initialState: AuthenticationState,
        credentialStore: any RefreshCredentialStore = KeychainRefreshCredentialStore(),
        webAuthenticator: SystemWebAuthenticator = SystemWebAuthenticator()
    ) {
        self.configuration = configuration
        state = initialState
        user = nil
        client = configuration.map { OIDCClient(configuration: $0) }
        self.credentialStore = credentialStore
        self.webAuthenticator = webAuthenticator
    }

    public func restore() async {
        guard let configuration, let client else {
            if case .failed = state {
                return
            }
            state = .configurationRequired
            return
        }

        let refreshToken: String?
        let cachedUser: AuthenticatedUser?
        do {
            refreshToken = try credentialStore.read(account: configuration.credentialAccount)
            cachedUser = try credentialStore.readUser(
                account: configuration.credentialAccount
            )
        } catch {
            state = .failed(.credentialStorage)
            return
        }
        guard let refreshToken else {
            state = .signedOut
            return
        }

        state = .restoring
        do {
            let tokenSet = try await client.refresh(using: refreshToken)
            try accept(tokenSet, fallbackRefreshToken: refreshToken)
        } catch AuthenticationFailure.providerUnavailable {
            guard let cachedUser else {
                clearMemoryCredential()
                state = .failed(.providerUnavailable)
                return
            }
            user = cachedUser
            state = .offline
        } catch {
            try? credentialStore.delete(account: configuration.credentialAccount)
            clearMemoryCredential()
            state = .failed(
                (error as? AuthenticationFailure) ?? .sessionExpired
            )
        }
    }

    public func signIn() async {
        await authorize(intent: .signIn)
    }

    public func signUp() async {
        await authorize(intent: .signUp)
    }

    private func authorize(intent: AccountAuthorizationIntent) async {
        accountDeletionFailure = nil
        guard let client else {
            state = configuration == nil
                ? .configurationRequired
                : .failed(.invalidConfiguration)
            return
        }

        state = .authorizing
        do {
            let request = try await client.makeAuthorizationRequest(intent: intent)
            let callbackURL = try await webAuthenticator.authenticate(using: request)
            let tokenSet = try await client.exchange(
                callbackURL: callbackURL,
                request: request
            )
            try accept(tokenSet, fallbackRefreshToken: nil)
        } catch AuthenticationFailure.cancelled {
            state = .signedOut
        } catch let failure as AuthenticationFailure {
            state = .failed(failure)
        } catch {
            state = .failed(.providerUnavailable)
        }
    }

    public func returnToSignIn() {
        webAuthenticator.cancel()
        accountDeletionFailure = nil
        clearMemoryCredential()
        state = configuration == nil ? .configurationRequired : .signedOut
    }

    public func signOut() async {
        webAuthenticator.cancel()
        accountDeletionFailure = nil
        if
            let configuration,
            let client,
            let refreshToken = try? credentialStore.read(
                account: configuration.credentialAccount
            )
        {
            await client.revoke(refreshToken: refreshToken)
        }
        if let configuration {
            try? credentialStore.delete(account: configuration.credentialAccount)
        }
        clearMemoryCredential()
        state = configuration == nil ? .configurationRequired : .signedOut
    }

    public func deleteAccount(
        removingLocalWorkspaceWith localCleanup: (String) throws -> Void
    ) async {
        guard
            case .authenticated = state,
            let configuration,
            let client,
            let workspaceAccountID
        else {
            accountDeletionFailure = .accountDeletionRequiresOnlineSession
            return
        }

        isDeletingAccount = true
        accountDeletionFailure = nil
        defer { isDeletingAccount = false }

        do {
            let reauthentication = try await client.makeAuthorizationRequest(
                intent: .reauthenticate
            )
            let reauthenticationCallback = try await webAuthenticator.authenticate(
                using: reauthentication
            )
            let freshTokenSet = try await client.exchange(
                callbackURL: reauthenticationCallback,
                request: reauthentication
            )
            guard
                let freshUser = freshTokenSet.user,
                Self.workspaceAccountID(
                    issuer: configuration.issuer,
                    user: freshUser
                ) == workspaceAccountID
            else {
                if let refreshToken = freshTokenSet.refreshToken {
                    await client.revoke(refreshToken: refreshToken)
                }
                throw AuthenticationFailure.accountDeletionIdentityMismatch
            }
            try accept(freshTokenSet, fallbackRefreshToken: nil)

            let stateValue = try Self.randomURLSafeValue()
            let callbackURL = URL(
                string: "app.tazkle.desktop:/account/deleted"
            )!
            var page = URLComponents(
                url: configuration.issuer,
                resolvingAgainstBaseURL: false
            )
            page?.path = "/account/delete"
            page?.queryItems = [
                URLQueryItem(name: "callback", value: callbackURL.absoluteString),
                URLQueryItem(name: "state", value: stateValue),
            ]
            guard let pageURL = page?.url else {
                throw AuthenticationFailure.invalidConfiguration
            }

            let callback = try await webAuthenticator.authenticate(
                url: pageURL,
                callbackScheme: "app.tazkle.desktop"
            )
            guard
                callback.scheme == "app.tazkle.desktop",
                callback.host == nil,
                callback.path == "/account/deleted",
                URLComponents(
                    url: callback,
                    resolvingAgainstBaseURL: false
                )?.queryItems?.first(where: { $0.name == "state" })?.value
                    == stateValue
            else {
                throw AuthenticationFailure.invalidAuthorizationResponse
            }

            let localWorkspaceWasCleared: Bool
            do {
                try localCleanup(workspaceAccountID)
                pendingLocalAccountCleanupID = nil
                hasPendingLocalAccountCleanup = false
                localWorkspaceWasCleared = true
            } catch {
                pendingLocalAccountCleanupID = workspaceAccountID
                hasPendingLocalAccountCleanup = true
                localWorkspaceWasCleared = false
            }

            let keychainWasCleared: Bool
            do {
                try credentialStore.delete(
                    account: configuration.credentialAccount
                )
                keychainWasCleared = true
            } catch {
                keychainWasCleared = false
            }
            clearMemoryCredential()
            state = .signedOut
            if !keychainWasCleared {
                accountDeletionFailure = .credentialStorage
            } else if !localWorkspaceWasCleared {
                accountDeletionFailure = .localAccountCleanupFailed
            } else {
                accountDeletionFailure = nil
            }
        } catch AuthenticationFailure.cancelled {
            accountDeletionFailure = nil
        } catch let failure as AuthenticationFailure {
            accountDeletionFailure = switch failure {
            case .providerUnavailable, .accountDeletionIdentityMismatch:
                failure
            default:
                .accountDeletionFailed
            }
        } catch {
            accountDeletionFailure = .accountDeletionFailed
        }
    }

    public func retryPendingLocalAccountCleanup(
        using localCleanup: (String) throws -> Void
    ) {
        guard let pendingLocalAccountCleanupID else { return }
        do {
            try localCleanup(pendingLocalAccountCleanupID)
            self.pendingLocalAccountCleanupID = nil
            hasPendingLocalAccountCleanup = false
            accountDeletionFailure = nil
        } catch {
            accountDeletionFailure = .localAccountCleanupFailed
        }
    }

    public func validAccessToken() async throws -> String {
        guard let client, let configuration else {
            throw AuthenticationFailure.invalidConfiguration
        }
        if
            let accessToken,
            let accessTokenExpiresAt,
            accessTokenExpiresAt.timeIntervalSinceNow > 60
        {
            return accessToken
        }
        let refreshToken: String
        do {
            guard
                let storedRefreshToken = try credentialStore.read(
                    account: configuration.credentialAccount
                )
            else {
                state = .failed(.sessionExpired)
                throw AuthenticationFailure.sessionExpired
            }
            refreshToken = storedRefreshToken
        } catch let failure as AuthenticationFailure {
            state = .failed(failure)
            throw failure
        } catch {
            state = .failed(.credentialStorage)
            throw AuthenticationFailure.credentialStorage
        }

        do {
            let tokenSet = try await client.refresh(using: refreshToken)
            try accept(tokenSet, fallbackRefreshToken: refreshToken)
            return tokenSet.accessToken
        } catch AuthenticationFailure.providerUnavailable {
            if
                let cachedUser = try? credentialStore.readUser(
                    account: configuration.credentialAccount
                )
            {
                user = cachedUser
                state = .offline
            } else {
                clearMemoryCredential()
                state = .failed(.providerUnavailable)
            }
            throw AuthenticationFailure.providerUnavailable
        } catch let failure as AuthenticationFailure {
            try? credentialStore.delete(account: configuration.credentialAccount)
            clearMemoryCredential()
            state = .failed(
                failure == .credentialStorage ? failure : .sessionExpired
            )
            throw failure
        } catch {
            clearMemoryCredential()
            state = .failed(.sessionExpired)
            throw AuthenticationFailure.sessionExpired
        }
    }

    private func accept(
        _ tokenSet: TokenSet,
        fallbackRefreshToken: String?
    ) throws {
        let refreshToken = tokenSet.refreshToken ?? fallbackRefreshToken
        let acceptedUser: AuthenticatedUser?
        if let tokenUser = tokenSet.user {
            acceptedUser = tokenUser
        } else if let configuration {
            acceptedUser = try credentialStore.readUser(
                account: configuration.credentialAccount
            )
        } else {
            acceptedUser = nil
        }
        guard let acceptedUser else {
            throw AuthenticationFailure.invalidAuthorizationResponse
        }
        if let refreshToken, let configuration {
            try credentialStore.save(
                refreshToken,
                account: configuration.credentialAccount
            )
            try credentialStore.saveUser(
                acceptedUser,
                account: configuration.credentialAccount
            )
        }
        accessToken = tokenSet.accessToken
        accessTokenExpiresAt = tokenSet.expiresAt
        user = acceptedUser
        state = .authenticated(RemoteSession(expiresAt: tokenSet.expiresAt))
    }

    private func clearMemoryCredential() {
        accessToken = nil
        accessTokenExpiresAt = nil
        user = nil
    }

    private static func randomURLSafeValue() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard
            SecRandomCopyBytes(
                kSecRandomDefault,
                bytes.count,
                &bytes
            ) == errSecSuccess
        else {
            throw AuthenticationFailure.accountDeletionFailed
        }
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated static func workspaceAccountID(
        issuer: URL,
        user: AuthenticatedUser
    ) -> String {
        "\(issuer.absoluteString)|\(user.subject)"
    }
}
