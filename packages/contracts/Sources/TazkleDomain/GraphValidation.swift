import Foundation

public enum GraphValidationError: Error, Equatable, LocalizedError, Sendable {
    case emptyProjectName
    case invalidProjectName
    case duplicateBlockID
    case emptyBlockTitle
    case blockTitleTooLong
    case blockSummaryTooLong
    case invalidControlCharacter
    case invalidPosition
    case missingBlock
    case missingRelation
    case approvedBlockImmutable
    case approvedRelationImmutable
    case duplicateRelationID
    case missingRelationEndpoint
    case selfRelation
    case duplicateRelation

    public var errorDescription: String? {
        switch self {
        case .emptyProjectName: "El proyecto necesita un nombre."
        case .invalidProjectName: "El nombre del proyecto contiene caracteres no permitidos."
        case .duplicateBlockID: "Dos bloques comparten el mismo identificador."
        case .emptyBlockTitle: "Cada bloque necesita un nombre."
        case .blockTitleTooLong: "El nombre del bloque no puede superar 80 caracteres."
        case .blockSummaryTooLong: "La descripción del bloque no puede superar 500 caracteres."
        case .invalidControlCharacter: "El contenido incluye caracteres de control no permitidos."
        case .invalidPosition: "La posición del bloque no es válida."
        case .missingBlock: "El bloque ya no existe en el proyecto."
        case .missingRelation: "La relación ya no existe en el proyecto."
        case .approvedBlockImmutable: "Un bloque aprobado requiere una nueva versión para modificarse."
        case .approvedRelationImmutable: "Una relación vinculada con alcance aprobado requiere una nueva versión para modificarse."
        case .duplicateRelationID: "Dos relaciones comparten el mismo identificador."
        case .missingRelationEndpoint: "La relación apunta a un bloque inexistente."
        case .selfRelation: "Un bloque no puede relacionarse consigo mismo."
        case .duplicateRelation: "Esta relación ya existe."
        }
    }
}

public enum ProjectGraphValidator {
    public static func validate(_ graph: ProjectGraph) throws {
        let projectName = graph.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectName.isEmpty else { throw GraphValidationError.emptyProjectName }
        guard !containsControlCharacters(projectName) else { throw GraphValidationError.invalidProjectName }

        let blockIDs = graph.blocks.map(\.id)
        guard Set(blockIDs).count == blockIDs.count else { throw GraphValidationError.duplicateBlockID }

        for block in graph.blocks {
            let title = block.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { throw GraphValidationError.emptyBlockTitle }
            guard title.count <= 80 else { throw GraphValidationError.blockTitleTooLong }
            guard block.summary.count <= 500 else { throw GraphValidationError.blockSummaryTooLong }
            guard !containsControlCharacters(title), !containsControlCharacters(block.summary) else {
                throw GraphValidationError.invalidControlCharacter
            }
            guard block.position.x.isFinite, block.position.y.isFinite else {
                throw GraphValidationError.invalidPosition
            }
        }

        let relationIDs = graph.relations.map(\.id)
        guard Set(relationIDs).count == relationIDs.count else {
            throw GraphValidationError.duplicateRelationID
        }

        let knownBlocks = Set(blockIDs)
        var semanticRelations = Set<String>()

        for relation in graph.relations {
            guard relation.sourceID != relation.targetID else { throw GraphValidationError.selfRelation }
            guard knownBlocks.contains(relation.sourceID), knownBlocks.contains(relation.targetID) else {
                throw GraphValidationError.missingRelationEndpoint
            }

            let key = "\(relation.sourceID.uuidString)|\(relation.type.rawValue)|\(relation.targetID.uuidString)"
            guard semanticRelations.insert(key).inserted else { throw GraphValidationError.duplicateRelation }
        }
    }

    public static func sanitizedSingleLine(_ value: String, limit: Int) -> String {
        String(
            value
                .components(separatedBy: .controlCharacters)
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(limit)
        )
    }

    private static func containsControlCharacters(_ value: String) -> Bool {
        value.rangeOfCharacter(from: .controlCharacters) != nil
    }
}
