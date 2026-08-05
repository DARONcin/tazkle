import Foundation

public struct OrganizationPlanningDefaults: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let organizationId: UUID
    public let riskReservePercent: Int
    public let targetMarginPercent: Int
    public let workdayHours: Int
    public let allowFinanceRateEdits: Bool
    public let updatedAt: Date

    public var id: UUID { organizationId }

    public init(
        organizationId: UUID,
        riskReservePercent: Int,
        targetMarginPercent: Int,
        workdayHours: Int,
        allowFinanceRateEdits: Bool,
        updatedAt: Date
    ) {
        self.organizationId = organizationId
        self.riskReservePercent = riskReservePercent
        self.targetMarginPercent = targetMarginPercent
        self.workdayHours = workdayHours
        self.allowFinanceRateEdits = allowFinanceRateEdits
        self.updatedAt = updatedAt
    }
}

public struct UpdateOrganizationPlanningDefaultsCommand: Codable, Equatable, Sendable {
    public let riskReservePercent: Int
    public let targetMarginPercent: Int
    public let workdayHours: Int
    public let allowFinanceRateEdits: Bool

    public init(
        riskReservePercent: Int,
        targetMarginPercent: Int,
        workdayHours: Int,
        allowFinanceRateEdits: Bool
    ) {
        self.riskReservePercent = riskReservePercent
        self.targetMarginPercent = targetMarginPercent
        self.workdayHours = workdayHours
        self.allowFinanceRateEdits = allowFinanceRateEdits
    }
}

public struct UpdateOrganizationPlanningDefaultsResponse: Codable, Equatable, Sendable {
    public let defaults: OrganizationPlanningDefaults
    public let replayed: Bool

    public init(defaults: OrganizationPlanningDefaults, replayed: Bool) {
        self.defaults = defaults
        self.replayed = replayed
    }
}
