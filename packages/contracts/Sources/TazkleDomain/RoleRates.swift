import Foundation

public struct RoleRate: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let organizationId: UUID
    public let role: OrganizationRole
    public let hourlyRateMXN: Int
    public let updatedAt: Date

    public var id: String { "\(organizationId.uuidString):\(role.rawValue)" }

    public init(
        organizationId: UUID,
        role: OrganizationRole,
        hourlyRateMXN: Int,
        updatedAt: Date
    ) {
        self.organizationId = organizationId
        self.role = role
        self.hourlyRateMXN = hourlyRateMXN
        self.updatedAt = updatedAt
    }
}

public struct RoleRatesListResponse: Codable, Equatable, Sendable {
    public let rates: [RoleRate]

    public init(rates: [RoleRate]) {
        self.rates = rates
    }
}

public struct UpsertRoleRateCommand: Codable, Equatable, Sendable {
    public let organizationId: UUID
    public let role: OrganizationRole
    public let hourlyRateMXN: Int

    public init(organizationId: UUID, role: OrganizationRole, hourlyRateMXN: Int) {
        self.organizationId = organizationId
        self.role = role
        self.hourlyRateMXN = hourlyRateMXN
    }
}

public struct UpsertRoleRateResponse: Codable, Equatable, Sendable {
    public let rate: RoleRate
    public let replayed: Bool

    public init(rate: RoleRate, replayed: Bool) {
        self.rate = rate
        self.replayed = replayed
    }
}
