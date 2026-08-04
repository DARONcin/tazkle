import Foundation

public enum OrganizationRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case organizationAdmin = "organization-admin"
    case projectManager = "project-manager"
    case product
    case technicalLead = "technical-lead"
    case design
    case development
    case qa
    case finance
    case collaborator
    case client
    case observer

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .organizationAdmin: "Administrador de organización"
        case .projectManager: "Líder de proyecto"
        case .product: "Producto"
        case .technicalLead: "Liderazgo técnico"
        case .design: "Diseño"
        case .development: "Desarrollo"
        case .qa: "QA"
        case .finance: "Finanzas"
        case .collaborator: "Colaborador"
        case .client: "Cliente"
        case .observer: "Observador"
        }
    }
}

public enum MembershipStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case invited
    case active
    case suspended
    case revoked

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .invited: "Invitado"
        case .active: "Activo"
        case .suspended: "Suspendido"
        case .revoked: "Revocado"
        }
    }
}

public struct OrganizationMember: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let organizationId: UUID
    public let userId: UUID
    public let displayName: String?
    public let role: OrganizationRole
    public let status: MembershipStatus
    public let createdAt: Date

    public var id: UUID { userId }

    public init(
        organizationId: UUID,
        userId: UUID,
        displayName: String?,
        role: OrganizationRole,
        status: MembershipStatus,
        createdAt: Date
    ) {
        self.organizationId = organizationId
        self.userId = userId
        self.displayName = displayName
        self.role = role
        self.status = status
        self.createdAt = createdAt
    }
}

public struct MembersListResponse: Codable, Equatable, Sendable {
    public let members: [OrganizationMember]

    public init(members: [OrganizationMember]) {
        self.members = members
    }
}
