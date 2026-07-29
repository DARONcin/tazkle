import Foundation

public struct OIDCConfiguration: Equatable, Sendable {
    public let issuer: URL
    public let clientID: String
    public let redirectURI: URL
    public let resource: String?
    public let scopes: [String]

    public init(
        issuer: URL,
        clientID: String,
        redirectURI: URL,
        resource: String? = nil,
        scopes: [String] = ["openid", "profile", "email", "offline_access"]
    ) throws {
        guard
            Self.isSecureIssuer(issuer),
            issuer.user == nil,
            issuer.password == nil,
            issuer.query == nil,
            issuer.fragment == nil
        else {
            throw AuthenticationFailure.invalidConfiguration
        }

        let normalizedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedClientID.isEmpty, normalizedClientID.count <= 256 else {
            throw AuthenticationFailure.invalidConfiguration
        }

        guard
            let redirectScheme = redirectURI.scheme,
            redirectScheme.caseInsensitiveCompare("app.tazkle.desktop") == .orderedSame,
            redirectURI.user == nil,
            redirectURI.password == nil,
            redirectURI.query == nil,
            redirectURI.fragment == nil,
            redirectURI.path == "/oauth/callback"
        else {
            throw AuthenticationFailure.invalidConfiguration
        }

        let normalizedResource = resource?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedResource, normalizedResource.isEmpty || normalizedResource.count > 512 {
            throw AuthenticationFailure.invalidConfiguration
        }

        let normalizedScopes = Array(
            Set(scopes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        ).filter { !$0.isEmpty }.sorted()
        guard normalizedScopes.contains("openid") else {
            throw AuthenticationFailure.invalidConfiguration
        }

        self.issuer = Self.normalizedIssuer(issuer)
        self.clientID = normalizedClientID
        self.redirectURI = redirectURI
        self.resource = normalizedResource
        self.scopes = normalizedScopes
    }

    public static func load(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> OIDCConfiguration? {
        let issuerValue = configuredValue(
            environment["TAZKLE_OIDC_ISSUER"],
            bundle.object(forInfoDictionaryKey: "TazkleOIDCIssuer") as? String
        )
        let clientIDValue = configuredValue(
            environment["TAZKLE_OIDC_CLIENT_ID"],
            bundle.object(forInfoDictionaryKey: "TazkleOIDCClientID") as? String
        )

        let useDevelopmentDefaults = issuerValue == nil && clientIDValue == nil
        let effectiveIssuerValue = useDevelopmentDefaults ? developmentIssuer : issuerValue
        let effectiveClientIDValue = useDevelopmentDefaults ? developmentClientID : clientIDValue

        if effectiveIssuerValue == nil, effectiveClientIDValue == nil {
            return nil
        }
        guard
            let effectiveIssuerValue,
            let effectiveClientIDValue,
            let issuer = URL(string: effectiveIssuerValue)
        else {
            throw AuthenticationFailure.invalidConfiguration
        }

        let redirectValue = configuredValue(
            environment["TAZKLE_OIDC_REDIRECT_URI"],
            bundle.object(forInfoDictionaryKey: "TazkleOIDCRedirectURI") as? String
        ) ?? "app.tazkle.desktop:/oauth/callback"
        guard let redirectURI = URL(string: redirectValue) else {
            throw AuthenticationFailure.invalidConfiguration
        }

        return try OIDCConfiguration(
            issuer: issuer,
            clientID: effectiveClientIDValue,
            redirectURI: redirectURI,
            resource: configuredValue(
                environment["TAZKLE_OIDC_RESOURCE"],
                bundle.object(forInfoDictionaryKey: "TazkleOIDCResource") as? String
            ) ?? (useDevelopmentDefaults ? developmentResource : nil)
        )
    }

    var discoveryURL: URL {
        issuer.appending(path: ".well-known/openid-configuration")
    }

    var credentialAccount: String {
        "\(issuer.absoluteString)|\(clientID)"
    }

    private static func normalizedIssuer(_ url: URL) -> URL {
        guard url.path == "/" else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.path = ""
        return components?.url ?? url
    }

    private static func isSecureIssuer(_ url: URL) -> Bool {
        if url.scheme == "https" {
            return true
        }
#if DEBUG
        return url.scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(url.host)
#else
        return false
#endif
    }

    private static var developmentIssuer: String? {
#if DEBUG
        "http://127.0.0.1:8787/api/auth"
#else
        nil
#endif
    }

    private static var developmentClientID: String? {
#if DEBUG
        "tazkle-macos"
#else
        nil
#endif
    }

    private static var developmentResource: String? {
#if DEBUG
        "tazkle-local"
#else
        nil
#endif
    }

    private static func configuredValue(_ values: String?...) -> String? {
        values.lazy
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

public enum AuthenticationFailure: Error, Equatable, Sendable {
    case invalidConfiguration
    case providerUnavailable
    case providerRejected
    case invalidAuthorizationResponse
    case cancelled
    case sessionExpired
    case credentialStorage

    public var userMessage: String {
        switch self {
        case .invalidConfiguration:
            "La configuración de acceso está incompleta o no es válida."
        case .providerUnavailable:
            "No fue posible contactar al proveedor de identidad. Revisa tu conexión e inténtalo de nuevo."
        case .providerRejected:
            "El proveedor no pudo completar el acceso. No se modificó tu trabajo local."
        case .invalidAuthorizationResponse:
            "La respuesta de acceso no pudo validarse de forma segura."
        case .cancelled:
            "El inicio de sesión fue cancelado."
        case .sessionExpired:
            "La sesión terminó. Inicia sesión nuevamente para sincronizar."
        case .credentialStorage:
            "La credencial no pudo guardarse de forma segura en Keychain."
        }
    }
}

public struct RemoteSession: Equatable, Sendable {
    public let expiresAt: Date

    public init(expiresAt: Date) {
        self.expiresAt = expiresAt
    }
}

public struct AuthenticatedUser: Equatable, Sendable {
    public let subject: String
    public let name: String?
    public let email: String?
    public let isEmailVerified: Bool

    public var displayName: String {
        name ?? email ?? "Cuenta conectada"
    }

    init?(
        subject: String,
        name: String?,
        email: String?,
        isEmailVerified: Bool
    ) {
        guard let subject = Self.safeClaim(subject, maximumLength: 255) else {
            return nil
        }
        let safeName = Self.optionalSafeClaim(name, maximumLength: 120)
        let safeEmail = Self.optionalEmail(email)
        guard
            name == nil || safeName != nil,
            email == nil || safeEmail != nil
        else {
            return nil
        }
        self.subject = subject
        self.name = safeName
        self.email = safeEmail
        self.isEmailVerified = safeEmail != nil && isEmailVerified
    }

    private static func optionalSafeClaim(
        _ value: String?,
        maximumLength: Int
    ) -> String? {
        guard let value else { return nil }
        return safeClaim(value, maximumLength: maximumLength)
    }

    private static func safeClaim(
        _ value: String,
        maximumLength: Int
    ) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !normalized.isEmpty,
            normalized.count <= maximumLength,
            !normalized.unicodeScalars.contains(where: {
                CharacterSet.controlCharacters.contains($0)
            })
        else {
            return nil
        }
        return normalized
    }

    private static func optionalEmail(_ value: String?) -> String? {
        guard let value else { return nil }
        return SafeEmailAddress(value)?.value
    }
}

public struct SafeEmailAddress: Equatable, Sendable {
    public let value: String

    public init?(_ rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            value.count >= 3,
            value.count <= 254,
            !value.unicodeScalars.contains(where: {
                CharacterSet.whitespacesAndNewlines.contains($0)
                    || CharacterSet.controlCharacters.contains($0)
            })
        else {
            return nil
        }

        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard
            parts.count == 2,
            !parts[0].isEmpty,
            parts[0].count <= 64,
            !parts[1].isEmpty,
            parts[1].count <= 253,
            !parts[0].hasPrefix("."),
            !parts[0].hasSuffix("."),
            !parts[1].hasPrefix("."),
            !parts[1].hasSuffix("."),
            !parts[1].contains("..")
        else {
            return nil
        }

        self.value = value
    }
}

enum AccountAuthorizationIntent: Equatable, Sendable {
    case signIn
    case signUp
}

public enum AuthenticationState: Equatable, Sendable {
    case configurationRequired
    case signedOut
    case restoring
    case authorizing
    case authenticated(RemoteSession)
    case offline
    case localOnly
    case failed(AuthenticationFailure)

    public var permitsWorkspace: Bool {
        switch self {
        case .authenticated, .offline, .localOnly:
            true
        default:
            false
        }
    }
}

struct OIDCProviderMetadata: Decodable, Equatable, Sendable {
    let issuer: String
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let revocationEndpoint: URL?
    let userInfoEndpoint: URL?
    let codeChallengeMethodsSupported: [String]?

    enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case revocationEndpoint = "revocation_endpoint"
        case userInfoEndpoint = "userinfo_endpoint"
        case codeChallengeMethodsSupported = "code_challenge_methods_supported"
    }
}

struct AuthorizationRequest: Equatable, Sendable {
    let url: URL
    let callbackScheme: String
    let state: String
    let codeVerifier: String
}

struct TokenSet: Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let user: AuthenticatedUser?
}

struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Double
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct UserInfoResponse: Decodable {
    let subject: String
    let name: String?
    let preferredUsername: String?
    let email: String?
    let isEmailVerified: Bool?

    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case name
        case preferredUsername = "preferred_username"
        case email
        case isEmailVerified = "email_verified"
    }
}
