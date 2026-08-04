import Foundation
import TazkleDomain

enum PlatformAPIError: Error, Equatable {
    case unauthorized
    case forbidden
    case network
    case server(status: Int)
    case decoding
}

/// Thin client for Gateway's public `/v1/*` routes. Callers supply a fresh
/// access token per request (see `AuthenticationController.validAccessToken()`)
/// rather than this type owning any session state.
struct PlatformAPIClient {
    let baseURL: URL
    var session: URLSession = .shared

    func fetchMembers(accessToken: String) async throws -> [OrganizationMember] {
        let response: MembersListResponse = try await get("v1/members", accessToken: accessToken)
        return response.members
    }

    func fetchRoleRates(accessToken: String) async throws -> [RoleRate] {
        let response: RoleRatesListResponse = try await get("v1/role-rates", accessToken: accessToken)
        return response.rates
    }

    func upsertRoleRate(
        _ command: UpsertRoleRateCommand,
        accessToken: String
    ) async throws -> RoleRate {
        let response: UpsertRoleRateResponse = try await put(
            "v1/role-rates",
            body: command,
            accessToken: accessToken
        )
        return response.rate
    }

    func fetchOrganizationPlanningDefaults(
        organizationId: UUID,
        accessToken: String
    ) async throws -> OrganizationPlanningDefaults {
        try await get(
            "v1/organizations/\(organizationId.uuidString)/planning-defaults",
            accessToken: accessToken
        )
    }

    func updateOrganizationPlanningDefaults(
        organizationId: UUID,
        _ command: UpdateOrganizationPlanningDefaultsCommand,
        accessToken: String
    ) async throws -> OrganizationPlanningDefaults {
        let response: UpdateOrganizationPlanningDefaultsResponse = try await put(
            "v1/organizations/\(organizationId.uuidString)/planning-defaults",
            body: command,
            accessToken: accessToken
        )
        return response.defaults
    }

    private func get<Response: Decodable>(
        _ path: String,
        accessToken: String
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        return try await send(request)
    }

    private func put<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        accessToken: String
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "PUT"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        request.httpBody = try JSONEncoder().encode(body)

        return try await send(request, acceptableStatusCodes: [200, 201])
    }

    private func send<Response: Decodable>(
        _ request: URLRequest,
        acceptableStatusCodes: Set<Int> = [200]
    ) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PlatformAPIError.network
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlatformAPIError.network
        }
        guard acceptableStatusCodes.contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw PlatformAPIError.unauthorized
            }
            if httpResponse.statusCode == 403 {
                throw PlatformAPIError.forbidden
            }
            throw PlatformAPIError.server(status: httpResponse.statusCode)
        }

        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw PlatformAPIError.decoding
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { fieldDecoder in
            let container = try fieldDecoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = iso8601DateWithFractionalSeconds(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO 8601 date, got \(value)"
            )
        }
        return decoder
    }()

    /// Fresh formatters per call: `ISO8601DateFormatter` is a mutable class,
    /// not safe to share across the `@Sendable` decoding closure.
    private static func iso8601DateWithFractionalSeconds(_ value: String) -> Date? {
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractionalSeconds.date(from: value) {
            return date
        }
        let withoutFractionalSeconds = ISO8601DateFormatter()
        withoutFractionalSeconds.formatOptions = [.withInternetDateTime]
        return withoutFractionalSeconds.date(from: value)
    }
}

extension URL {
    /// Origin (scheme + host + port) of the configured OIDC issuer, which is
    /// also where Gateway publishes its `/v1/*` API — Gateway is the only
    /// component that serves both `/api/auth/*` and the platform routes.
    static func platformGatewayBaseURL(fromIssuer issuer: URL) -> URL? {
        var components = URLComponents(url: issuer, resolvingAgainstBaseURL: false)
        components?.path = ""
        components?.query = nil
        components?.fragment = nil
        return components?.url
    }
}
