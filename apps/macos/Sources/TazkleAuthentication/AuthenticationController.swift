import Combine
import Foundation

@MainActor
public final class AuthenticationController: ObservableObject {
    @Published public private(set) var state: AuthenticationState
    @Published public private(set) var user: AuthenticatedUser?

    public let configuration: OIDCConfiguration?

    private let client: OIDCClient?
    private let credentialStore: any RefreshCredentialStore
    private let webAuthenticator: SystemWebAuthenticator
    private var accessToken: String?
    private var accessTokenExpiresAt: Date?

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
        do {
            refreshToken = try credentialStore.read(account: configuration.credentialAccount)
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
            state = .offline
        } catch {
            try? credentialStore.delete(account: configuration.credentialAccount)
            clearMemoryCredential()
            state = .failed(
                (error as? AuthenticationFailure) ?? .sessionExpired
            )
        }
    }

    public func signIn(email: EmailLoginHint) async {
        guard let client else {
            state = configuration == nil
                ? .configurationRequired
                : .failed(.invalidConfiguration)
            return
        }

        state = .authorizing
        do {
            let request = try await client.makeAuthorizationRequest(loginHint: email)
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

    public func continueLocally() {
        webAuthenticator.cancel()
        clearMemoryCredential()
        state = .localOnly
    }

    public func returnToSignIn() {
        webAuthenticator.cancel()
        clearMemoryCredential()
        state = configuration == nil ? .configurationRequired : .signedOut
    }

    public func signOut() async {
        webAuthenticator.cancel()
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
            state = .offline
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
        if let refreshToken, let configuration {
            try credentialStore.save(
                refreshToken,
                account: configuration.credentialAccount
            )
        }
        accessToken = tokenSet.accessToken
        accessTokenExpiresAt = tokenSet.expiresAt
        user = tokenSet.user
        state = .authenticated(RemoteSession(expiresAt: tokenSet.expiresAt))
    }

    private func clearMemoryCredential() {
        accessToken = nil
        accessTokenExpiresAt = nil
        user = nil
    }
}
