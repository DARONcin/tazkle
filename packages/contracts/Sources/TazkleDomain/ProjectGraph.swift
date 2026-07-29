import Foundation

public struct BlockPosition: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum BlockFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case strategy
    case product
    case process
    case technology
    case people
    case economy
    case governance

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .strategy: "Estrategia"
        case .product: "Producto"
        case .process: "Proceso"
        case .technology: "Tecnología"
        case .people: "Personas"
        case .economy: "Economía"
        case .governance: "Gobierno"
        }
    }
}

public enum BlockState: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft
    case ready
    case warning
    case approved

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .draft: "Borrador"
        case .ready: "Listo"
        case .warning: "Con advertencia"
        case .approved: "Aprobado"
        }
    }
}

public enum ArchitectureLayer: String, Codable, CaseIterable, Identifiable, Sendable {
    case experience
    case services
    case data
    case infrastructure

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .experience: "Experiencia"
        case .services: "Servicios"
        case .data: "Datos"
        case .infrastructure: "Infraestructura"
        }
    }

    public var summary: String {
        switch self {
        case .experience: "Interfaces y canales de usuario."
        case .services: "Lógica de negocio y servicios."
        case .data: "Persistencia y gestión de información."
        case .infrastructure: "Plataforma, operación y observabilidad."
        }
    }
}

public struct ProjectBlock: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var summary: String
    public var family: BlockFamily
    public var state: BlockState
    public var architectureLayer: ArchitectureLayer?
    public var position: BlockPosition
    public var rowVersion: Int

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String = "",
        family: BlockFamily,
        state: BlockState = .draft,
        architectureLayer: ArchitectureLayer? = nil,
        position: BlockPosition,
        rowVersion: Int = 1
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.family = family
        self.state = state
        self.architectureLayer = architectureLayer
        self.position = position
        self.rowVersion = rowVersion
    }
}

public enum RelationType: String, Codable, CaseIterable, Identifiable, Sendable {
    case contains
    case dependsOn
    case implements
    case requires
    case produces
    case validates
    case assigns
    case finances
    case blocks

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .contains: "Contiene"
        case .dependsOn: "Depende de"
        case .implements: "Implementa"
        case .requires: "Requiere"
        case .produces: "Produce"
        case .validates: "Valida"
        case .assigns: "Asigna"
        case .finances: "Financia"
        case .blocks: "Bloquea"
        }
    }
}

public enum ConnectionPort: String, Codable, CaseIterable, Identifiable, Sendable {
    case top
    case right
    case bottom
    case left

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .top: "Arriba"
        case .right: "Derecha"
        case .bottom: "Abajo"
        case .left: "Izquierda"
        }
    }
}

public struct BlockRelation: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var sourceID: UUID
    public var targetID: UUID
    public var sourcePort: ConnectionPort
    public var targetPort: ConnectionPort
    public var type: RelationType
    public var isCritical: Bool
    public var rowVersion: Int

    public init(
        id: UUID = UUID(),
        sourceID: UUID,
        targetID: UUID,
        sourcePort: ConnectionPort = .right,
        targetPort: ConnectionPort = .left,
        type: RelationType,
        isCritical: Bool = false,
        rowVersion: Int = 1
    ) {
        self.id = id
        self.sourceID = sourceID
        self.targetID = targetID
        self.sourcePort = sourcePort
        self.targetPort = targetPort
        self.type = type
        self.isCritical = isCritical
        self.rowVersion = rowVersion
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sourceID
        case targetID
        case sourcePort
        case targetPort
        case type
        case isCritical
        case rowVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceID = try container.decode(UUID.self, forKey: .sourceID)
        targetID = try container.decode(UUID.self, forKey: .targetID)
        sourcePort = try container.decodeIfPresent(ConnectionPort.self, forKey: .sourcePort) ?? .right
        targetPort = try container.decodeIfPresent(ConnectionPort.self, forKey: .targetPort) ?? .left
        type = try container.decode(RelationType.self, forKey: .type)
        isCritical = try container.decode(Bool.self, forKey: .isCritical)
        rowVersion = try container.decode(Int.self, forKey: .rowVersion)
    }
}

public struct RemovedBlockSnapshot: Equatable, Sendable {
    public let block: ProjectBlock
    public let relations: [BlockRelation]
    public let blockIndex: Int

    public init(block: ProjectBlock, relations: [BlockRelation], blockIndex: Int) {
        self.block = block
        self.relations = relations
        self.blockIndex = blockIndex
    }
}

public struct RemovedRelationSnapshot: Equatable, Sendable {
    public let relation: BlockRelation
    public let relationIndex: Int

    public init(relation: BlockRelation, relationIndex: Int) {
        self.relation = relation
        self.relationIndex = relationIndex
    }
}

public struct ProjectGraph: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var blocks: [ProjectBlock]
    public var relations: [BlockRelation]
    public var rowVersion: Int

    public init(
        id: UUID = UUID(),
        name: String,
        blocks: [ProjectBlock] = [],
        relations: [BlockRelation] = [],
        rowVersion: Int = 1
    ) {
        self.id = id
        self.name = name
        self.blocks = blocks
        self.relations = relations
        self.rowVersion = rowVersion
    }

    public func block(id: UUID) -> ProjectBlock? {
        blocks.first { $0.id == id }
    }

    public func relationshipCount(for blockID: UUID) -> Int {
        relations.count { $0.sourceID == blockID || $0.targetID == blockID }
    }

    public mutating func updateBlockDetails(
        id blockID: UUID,
        title: String,
        summary: String,
        family: BlockFamily,
        state: BlockState,
        architectureLayer: ArchitectureLayer?
    ) throws {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else {
            throw GraphValidationError.missingBlock
        }
        guard blocks[index].state != .approved else {
            throw GraphValidationError.approvedBlockImmutable
        }

        var candidate = self
        candidate.blocks[index].title = title
        candidate.blocks[index].summary = summary
        candidate.blocks[index].family = family
        candidate.blocks[index].state = state
        candidate.blocks[index].architectureLayer = architectureLayer
        candidate.blocks[index].rowVersion += 1
        candidate.rowVersion += 1

        try ProjectGraphValidator.validate(candidate)
        self = candidate
    }

    public mutating func updateRelationDetails(
        id relationID: UUID,
        sourceID: UUID,
        targetID: UUID,
        sourcePort: ConnectionPort,
        targetPort: ConnectionPort,
        type: RelationType,
        isCritical: Bool
    ) throws {
        guard let index = relations.firstIndex(where: { $0.id == relationID }) else {
            throw GraphValidationError.missingRelation
        }

        let current = relations[index]
        let protectedBlockIDs = [current.sourceID, current.targetID, sourceID, targetID]
        guard !blocks.contains(where: {
            protectedBlockIDs.contains($0.id) && $0.state == .approved
        }) else {
            throw GraphValidationError.approvedRelationImmutable
        }

        var candidate = self
        candidate.relations[index].sourceID = sourceID
        candidate.relations[index].targetID = targetID
        candidate.relations[index].sourcePort = sourcePort
        candidate.relations[index].targetPort = targetPort
        candidate.relations[index].type = type
        candidate.relations[index].isCritical = isCritical
        candidate.relations[index].rowVersion += 1
        candidate.rowVersion += 1

        try ProjectGraphValidator.validate(candidate)
        self = candidate
    }

    @discardableResult
    public mutating func removeBlock(id blockID: UUID) -> RemovedBlockSnapshot? {
        guard let blockIndex = blocks.firstIndex(where: { $0.id == blockID }) else {
            return nil
        }

        let removedRelations = relations.filter {
            $0.sourceID == blockID || $0.targetID == blockID
        }
        let removedBlock = blocks.remove(at: blockIndex)
        relations.removeAll {
            $0.sourceID == blockID || $0.targetID == blockID
        }
        rowVersion += 1

        return RemovedBlockSnapshot(
            block: removedBlock,
            relations: removedRelations,
            blockIndex: blockIndex
        )
    }

    public mutating func restoreBlock(from snapshot: RemovedBlockSnapshot) {
        guard !blocks.contains(where: { $0.id == snapshot.block.id }) else {
            return
        }

        let insertionIndex = min(max(snapshot.blockIndex, 0), blocks.count)
        blocks.insert(snapshot.block, at: insertionIndex)

        let knownBlockIDs = Set(blocks.map(\.id))
        let knownRelationIDs = Set(relations.map(\.id))
        relations.append(
            contentsOf: snapshot.relations.filter {
                !knownRelationIDs.contains($0.id)
                    && knownBlockIDs.contains($0.sourceID)
                    && knownBlockIDs.contains($0.targetID)
            }
        )
        rowVersion += 1
    }

    @discardableResult
    public mutating func removeRelation(id relationID: UUID) -> RemovedRelationSnapshot? {
        guard let relationIndex = relations.firstIndex(where: { $0.id == relationID }) else {
            return nil
        }

        let relation = relations.remove(at: relationIndex)
        rowVersion += 1
        return RemovedRelationSnapshot(
            relation: relation,
            relationIndex: relationIndex
        )
    }

    public mutating func restoreRelation(from snapshot: RemovedRelationSnapshot) {
        guard !relations.contains(where: { $0.id == snapshot.relation.id }) else {
            return
        }

        let knownBlockIDs = Set(blocks.map(\.id))
        guard knownBlockIDs.contains(snapshot.relation.sourceID),
              knownBlockIDs.contains(snapshot.relation.targetID) else {
            return
        }

        let insertionIndex = min(max(snapshot.relationIndex, 0), relations.count)
        relations.insert(snapshot.relation, at: insertionIndex)
        rowVersion += 1
    }
}
