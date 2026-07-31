import Foundation
import Testing
@testable import TazkleAuthentication

@Test
func loadsACompleteEnvironmentConfiguration() throws {
    let loaded = try OIDCConfiguration.load(
        bundle: Bundle(for: BundleSentinel.self),
        environment: [
            "TAZKLE_OIDC_ISSUER": "https://identity.example.com/",
            "TAZKLE_OIDC_CLIENT_ID": "tazkle-macos",
            "TAZKLE_OIDC_RESOURCE": "https://api.tazkle.app",
        ]
    )
    let configuration = try #require(loaded)

    #expect(configuration.issuer.absoluteString == "https://identity.example.com")
    #expect(configuration.clientID == "tazkle-macos")
    #expect(configuration.redirectURI.absoluteString == "app.tazkle.desktop:/oauth/callback")
    #expect(configuration.scopes.contains("offline_access"))
}

@Test
func refusesPartialOrInsecureConfiguration() {
    #expect(throws: AuthenticationFailure.invalidConfiguration) {
        try OIDCConfiguration.load(
            bundle: Bundle(for: BundleSentinel.self),
            environment: ["TAZKLE_OIDC_ISSUER": "https://identity.example.com"]
        )
    }

    #expect(throws: AuthenticationFailure.invalidConfiguration) {
        try OIDCConfiguration(
            issuer: URL(string: "http://identity.example.com")!,
            clientID: "tazkle-macos",
            redirectURI: URL(string: "app.tazkle.desktop:/oauth/callback")!
        )
    }
}

@Test
func loadsThePinnedLocalProviderInDebugBuilds() throws {
    let loaded = try OIDCConfiguration.load(
        bundle: Bundle(for: BundleSentinel.self),
        environment: [:]
    )
    let configuration = try #require(loaded)

    #expect(configuration.issuer.absoluteString == "http://127.0.0.1:8787/api/auth")
    #expect(configuration.clientID == "tazkle-macos")
    #expect(configuration.resource == "tazkle-local")
}

@Test
func producesTheRFC7636S256Challenge() {
    let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    #expect(
        OIDCClient.codeChallenge(for: verifier)
            == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
    )
}

@Test
func validatesProviderEmailClaimsWithoutPersistingOrInterpretingThem() {
    #expect(SafeEmailAddress("persona@ejemplo.com")?.value == "persona@ejemplo.com")
    #expect(SafeEmailAddress("  persona@ejemplo.com  ")?.value == "persona@ejemplo.com")
    #expect(SafeEmailAddress("sin-arroba") == nil)
    #expect(SafeEmailAddress("persona@@ejemplo.com") == nil)
    #expect(SafeEmailAddress("persona@ejemplo.com\r\nX-Test: injected") == nil)
}

@Test
func distinguishesSignInCreationAndSensitiveReauthentication() throws {
    let configuration = try OIDCConfiguration(
        issuer: URL(string: "https://identity.example.com")!,
        clientID: "tazkle-macos",
        redirectURI: URL(string: "app.tazkle.desktop:/oauth/callback")!
    )
    let metadata = OIDCProviderMetadata(
        issuer: "https://identity.example.com",
        authorizationEndpoint: URL(string: "https://identity.example.com/authorize")!,
        tokenEndpoint: URL(string: "https://identity.example.com/token")!,
        revocationEndpoint: nil,
        userInfoEndpoint: URL(string: "https://identity.example.com/userinfo")!,
        codeChallengeMethodsSupported: ["S256"]
    )
    let signInRequest = try OIDCClient.authorizationRequest(
        metadata: metadata,
        configuration: configuration,
        state: "state",
        codeVerifier: "verifier",
        intent: .signIn
    )
    let signUpRequest = try OIDCClient.authorizationRequest(
        metadata: metadata,
        configuration: configuration,
        state: "state",
        codeVerifier: "verifier",
        intent: .signUp
    )
    let reauthenticationRequest = try OIDCClient.authorizationRequest(
        metadata: metadata,
        configuration: configuration,
        state: "state",
        codeVerifier: "verifier",
        intent: .reauthenticate
    )
    let signInQuery = try #require(
        URLComponents(url: signInRequest.url, resolvingAgainstBaseURL: false)?.queryItems
    )
    let signUpQuery = try #require(
        URLComponents(url: signUpRequest.url, resolvingAgainstBaseURL: false)?.queryItems
    )
    let reauthenticationQuery = try #require(
        URLComponents(
            url: reauthenticationRequest.url,
            resolvingAgainstBaseURL: false
        )?.queryItems
    )

    #expect(signInQuery.first { $0.name == "prompt" } == nil)
    #expect(signInQuery.first { $0.name == "login_hint" } == nil)
    #expect(signUpQuery.first { $0.name == "prompt" }?.value == "create")
    #expect(signUpQuery.first { $0.name == "login_hint" } == nil)
    #expect(
        reauthenticationQuery.first { $0.name == "prompt" }?.value == "login"
    )
    #expect(
        reauthenticationQuery.first { $0.name == "login_hint" } == nil
    )
}

@Test
func carriesTheConfiguredResourceIntoTokenAndRefreshRequests() {
    let tokenParameters = OIDCClient.withResource(
        [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "client_id", value: "tazkle-macos"),
        ],
        resource: "tazkle-local"
    )
    let refreshParameters = OIDCClient.withResource(
        [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "client_id", value: "tazkle-macos"),
        ],
        resource: "tazkle-local"
    )

    #expect(tokenParameters.filter { $0.name == "resource" }.count == 1)
    #expect(tokenParameters.first { $0.name == "resource" }?.value == "tazkle-local")
    #expect(refreshParameters.filter { $0.name == "resource" }.count == 1)
    #expect(refreshParameters.first { $0.name == "resource" }?.value == "tazkle-local")
}

@Test
func acceptsOnlySafeProviderIdentityClaims() {
    let user = AuthenticatedUser(
        subject: "provider-subject",
        name: "Ada Lovelace",
        email: "ada@example.com",
        isEmailVerified: true
    )
    let injected = AuthenticatedUser(
        subject: "provider-subject",
        name: "Ada\r\nX-Test: injected",
        email: "ada@example.com",
        isEmailVerified: true
    )

    #expect(user?.displayName == "Ada Lovelace")
    #expect(user?.email == "ada@example.com")
    #expect(user?.isEmailVerified == true)
    #expect(injected == nil)
}

@Test
func rejectsACallbackWithTheWrongStateBeforeTokenExchange() async throws {
    let configuration = try OIDCConfiguration(
        issuer: URL(string: "https://identity.example.com")!,
        clientID: "tazkle-macos",
        redirectURI: URL(string: "app.tazkle.desktop:/oauth/callback")!
    )
    let client = OIDCClient(configuration: configuration)
    let request = AuthorizationRequest(
        url: URL(string: "https://identity.example.com/authorize")!,
        callbackScheme: "app.tazkle.desktop",
        state: "expected-state",
        codeVerifier: "verifier"
    )
    let callback = URL(
        string: "app.tazkle.desktop:/oauth/callback?code=code&state=other-state"
    )!

    do {
        _ = try await client.exchange(callbackURL: callback, request: request)
        Issue.record("A callback with a mismatched state was accepted")
    } catch let failure as AuthenticationFailure {
        #expect(failure == .invalidAuthorizationResponse)
    }
}

@Test @MainActor
func requiresAValidatedSessionBeforeWorkspaceAccess() throws {
    let configuration = try OIDCConfiguration(
        issuer: URL(string: "https://identity.example.com")!,
        clientID: "tazkle-macos",
        redirectURI: URL(string: "app.tazkle.desktop:/oauth/callback")!
    )
    let controller = AuthenticationController(
        configuration: configuration,
        initialState: .signedOut,
        credentialStore: MemoryCredentialStore()
    )

    #expect(controller.state == .signedOut)
    #expect(!controller.state.permitsWorkspace)
    #expect(AuthenticationState.offline.permitsWorkspace)
}

@Test
func accountDeletionReauthenticationMustMatchTheActiveWorkspace() throws {
    let issuer = URL(string: "https://identity.example.com/api/auth")!
    let original = try #require(
        AuthenticatedUser(
            subject: "original-account",
            name: "Original",
            email: "original@example.com",
            isEmailVerified: true
        )
    )
    let other = try #require(
        AuthenticatedUser(
            subject: "other-account",
            name: "Other",
            email: "other@example.com",
            isEmailVerified: true
        )
    )

    let expected = AuthenticationController.workspaceAccountID(
        issuer: issuer,
        user: original
    )
    let reauthenticated = AuthenticationController.workspaceAccountID(
        issuer: issuer,
        user: original
    )
    let mismatched = AuthenticationController.workspaceAccountID(
        issuer: issuer,
        user: other
    )

    #expect(reauthenticated == expected)
    #expect(mismatched != expected)
}

private final class MemoryCredentialStore: RefreshCredentialStore, @unchecked Sendable {
    private var credentials: [String: String] = [:]
    private var users: [String: AuthenticatedUser] = [:]
    private let lock = NSLock()

    func read(account: String) throws -> String? {
        lock.withLock { credentials[account] }
    }

    func save(_ credential: String, account: String) throws {
        lock.withLock {
            credentials[account] = credential
        }
    }

    func readUser(account: String) throws -> AuthenticatedUser? {
        lock.withLock { users[account] }
    }

    func saveUser(_ user: AuthenticatedUser, account: String) throws {
        lock.withLock {
            users[account] = user
        }
    }

    func delete(account: String) throws {
        lock.withLock {
            credentials.removeValue(forKey: account)
            users.removeValue(forKey: account)
        }
    }
}

private final class BundleSentinel {}
