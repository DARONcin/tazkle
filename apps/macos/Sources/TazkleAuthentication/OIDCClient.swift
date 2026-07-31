import CryptoKit
import Foundation
import Security

actor OIDCClient {
    private static let maximumResponseBytes = 1_048_576

    private let configuration: OIDCConfiguration
    private let session: URLSession
    private var cachedMetadata: OIDCProviderMetadata?

    init(configuration: OIDCConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        if let session {
            self.session = session
        } else {
            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.timeoutIntervalForRequest = 15
            sessionConfiguration.timeoutIntervalForResource = 20
            sessionConfiguration.waitsForConnectivity = false
            sessionConfiguration.httpShouldSetCookies = false
            self.session = URLSession(configuration: sessionConfiguration)
        }
    }

    func makeAuthorizationRequest(
        intent: AccountAuthorizationIntent
    ) async throws -> AuthorizationRequest {
        let metadata = try await providerMetadata()
        let state = try Self.randomURLSafeValue(byteCount: 32)
        let codeVerifier = try Self.randomURLSafeValue(byteCount: 64)
        return try Self.authorizationRequest(
            metadata: metadata,
            configuration: configuration,
            state: state,
            codeVerifier: codeVerifier,
            intent: intent
        )
    }

    func exchange(
        callbackURL: URL,
        request: AuthorizationRequest
    ) async throws -> TokenSet {
        let code = try authorizationCode(from: callbackURL, expectedState: request.state)
        let metadata = try await providerMetadata()
        let tokenSet = try await tokenRequest(
            endpoint: metadata.tokenEndpoint,
            parameters: Self.withResource(
                [
                    URLQueryItem(name: "grant_type", value: "authorization_code"),
                    URLQueryItem(name: "client_id", value: configuration.clientID),
                    URLQueryItem(name: "code", value: code),
                    URLQueryItem(name: "code_verifier", value: request.codeVerifier),
                    URLQueryItem(
                        name: "redirect_uri",
                        value: configuration.redirectURI.absoluteString
                    ),
                ],
                resource: configuration.resource
            )
        )
        return await attachingUserInfo(to: tokenSet, metadata: metadata)
    }

    func refresh(using refreshToken: String) async throws -> TokenSet {
        let metadata = try await providerMetadata()
        let tokenSet = try await tokenRequest(
            endpoint: metadata.tokenEndpoint,
            parameters: Self.withResource(
                [
                    URLQueryItem(name: "grant_type", value: "refresh_token"),
                    URLQueryItem(name: "client_id", value: configuration.clientID),
                    URLQueryItem(name: "refresh_token", value: refreshToken),
                ],
                resource: configuration.resource
            )
        )
        return await attachingUserInfo(to: tokenSet, metadata: metadata)
    }

    func revoke(refreshToken: String) async {
        guard
            let metadata = try? await providerMetadata(),
            let endpoint = metadata.revocationEndpoint,
            let body = Self.formBody([
                URLQueryItem(name: "token", value: refreshToken),
                URLQueryItem(name: "token_type_hint", value: "refresh_token"),
                URLQueryItem(name: "client_id", value: configuration.clientID),
            ])
        else {
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 10
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        _ = try? await session.data(for: request)
    }

    private func providerMetadata() async throws -> OIDCProviderMetadata {
        if let cachedMetadata {
            return cachedMetadata
        }

        var request = URLRequest(url: configuration.discoveryURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthenticationFailure.providerUnavailable
        }

        guard
            data.count <= Self.maximumResponseBytes,
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200,
            let metadata = try? JSONDecoder().decode(OIDCProviderMetadata.self, from: data),
            metadata.issuer == configuration.issuer.absoluteString,
            Self.isSafeProviderEndpoint(
                metadata.authorizationEndpoint,
                issuer: configuration.issuer
            ),
            Self.isSafeProviderEndpoint(
                metadata.tokenEndpoint,
                issuer: configuration.issuer
            ),
            metadata.revocationEndpoint.map({
                Self.isSafeProviderEndpoint($0, issuer: configuration.issuer)
            }) ?? true,
            metadata.userInfoEndpoint.map({
                Self.isSafeProviderEndpoint($0, issuer: configuration.issuer)
            }) ?? true,
            metadata.codeChallengeMethodsSupported?.contains("S256") ?? false
        else {
            throw AuthenticationFailure.providerUnavailable
        }

        cachedMetadata = metadata
        return metadata
    }

    private func authorizationCode(
        from callbackURL: URL,
        expectedState: String
    ) throws -> String {
        guard
            callbackURL.scheme?.caseInsensitiveCompare(configuration.redirectURI.scheme ?? "")
                == .orderedSame,
            callbackURL.host == configuration.redirectURI.host,
            callbackURL.path == configuration.redirectURI.path,
            let components = URLComponents(
                url: callbackURL,
                resolvingAgainstBaseURL: false
            )
        else {
            throw AuthenticationFailure.invalidAuthorizationResponse
        }

        let values = Dictionary(
            grouping: components.queryItems ?? [],
            by: \.name
        )
        guard
            values["state"]?.count == 1,
            values["state"]?.first?.value == expectedState
        else {
            throw AuthenticationFailure.invalidAuthorizationResponse
        }

        if values["error"]?.first?.value != nil {
            throw AuthenticationFailure.providerRejected
        }
        guard
            values["code"]?.count == 1,
            let code = values["code"]?.first?.value,
            !code.isEmpty,
            code.count <= 4_096
        else {
            throw AuthenticationFailure.invalidAuthorizationResponse
        }
        return code
    }

    private func tokenRequest(
        endpoint: URL,
        parameters: [URLQueryItem]
    ) async throws -> TokenSet {
        guard let body = Self.formBody(parameters) else {
            throw AuthenticationFailure.invalidConfiguration
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 15
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthenticationFailure.providerUnavailable
        }

        guard
            data.count <= Self.maximumResponseBytes,
            let httpResponse = response as? HTTPURLResponse
        else {
            throw AuthenticationFailure.providerUnavailable
        }
        guard httpResponse.statusCode == 200 else {
            throw AuthenticationFailure.providerRejected
        }
        guard
            let response = try? JSONDecoder().decode(TokenResponse.self, from: data),
            response.tokenType.caseInsensitiveCompare("Bearer") == .orderedSame,
            !response.accessToken.isEmpty,
            response.accessToken.count <= 32_768,
            response.expiresIn.isFinite,
            response.expiresIn > 0,
            response.expiresIn <= 86_400,
            response.refreshToken.map({ !$0.isEmpty && $0.count <= 32_768 }) ?? true
        else {
            throw AuthenticationFailure.invalidAuthorizationResponse
        }

        return TokenSet(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(response.expiresIn),
            user: nil
        )
    }

    private func attachingUserInfo(
        to tokenSet: TokenSet,
        metadata: OIDCProviderMetadata
    ) async -> TokenSet {
        guard
            let endpoint = metadata.userInfoEndpoint,
            let user = await fetchUserInfo(
                endpoint: endpoint,
                accessToken: tokenSet.accessToken
            )
        else {
            return tokenSet
        }
        return TokenSet(
            accessToken: tokenSet.accessToken,
            refreshToken: tokenSet.refreshToken,
            expiresAt: tokenSet.expiresAt,
            user: user
        )
    }

    private func fetchUserInfo(
        endpoint: URL,
        accessToken: String
    ) async -> AuthenticatedUser? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        guard
            let (data, response) = try? await session.data(for: request),
            data.count <= 65_536,
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200,
            let claims = try? JSONDecoder().decode(UserInfoResponse.self, from: data)
        else {
            return nil
        }

        return AuthenticatedUser(
            subject: claims.subject,
            name: claims.name ?? claims.preferredUsername,
            email: claims.email,
            isEmailVerified: claims.isEmailVerified ?? false
        )
    }

    static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    static func authorizationRequest(
        metadata: OIDCProviderMetadata,
        configuration: OIDCConfiguration,
        state: String,
        codeVerifier: String,
        intent: AccountAuthorizationIntent
    ) throws -> AuthorizationRequest {
        var components = URLComponents(
            url: metadata.authorizationEndpoint,
            resolvingAgainstBaseURL: false
        )
        var queryItems = components?.queryItems ?? []
        queryItems.append(contentsOf: [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge(for: codeVerifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ])
        if let resource = configuration.resource {
            queryItems.append(URLQueryItem(name: "resource", value: resource))
        }
        if intent == .signUp {
            queryItems.append(URLQueryItem(name: "prompt", value: "create"))
        } else if intent == .reauthenticate {
            queryItems.append(URLQueryItem(name: "prompt", value: "login"))
        }
        components?.queryItems = queryItems

        guard
            let authorizationURL = components?.url,
            let callbackScheme = configuration.redirectURI.scheme
        else {
            throw AuthenticationFailure.invalidConfiguration
        }
        return AuthorizationRequest(
            url: authorizationURL,
            callbackScheme: callbackScheme,
            state: state,
            codeVerifier: codeVerifier
        )
    }

    private static func randomURLSafeValue(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        guard SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes) == errSecSuccess else {
            throw AuthenticationFailure.invalidAuthorizationResponse
        }
        return Data(bytes).base64URLEncodedString()
    }

    private static func formBody(_ items: [URLQueryItem]) -> Data? {
        var components = URLComponents()
        components.queryItems = items
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    static func withResource(
        _ parameters: [URLQueryItem],
        resource: String?
    ) -> [URLQueryItem] {
        guard let resource else {
            return parameters
        }
        return parameters + [URLQueryItem(name: "resource", value: resource)]
    }

    private static func isSafeProviderEndpoint(_ url: URL, issuer: URL) -> Bool {
        let safeLocation: Bool
        if url.scheme == "https" {
            safeLocation = true
        } else {
#if DEBUG
            safeLocation = issuer.scheme == "http"
                && ["127.0.0.1", "localhost", "::1"].contains(issuer.host)
                && url.scheme == "http"
                && url.host == issuer.host
                && url.port == issuer.port
#else
            safeLocation = false
#endif
        }
        return safeLocation
            && url.user == nil
            && url.password == nil
            && url.fragment == nil
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
