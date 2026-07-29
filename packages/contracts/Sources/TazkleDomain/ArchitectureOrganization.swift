import Foundation

public enum ArchitectureOrganizationError: Error, LocalizedError, Equatable {
    case blockNotFound
    case targetNotFound
    case targetInDifferentLayer

    public var errorDescription: String? {
        switch self {
        case .blockNotFound:
            "El bloque que intentas mover ya no existe."
        case .targetNotFound:
            "El destino del movimiento ya no existe."
        case .targetInDifferentLayer:
            "El destino pertenece a una capa distinta."
        }
    }
}

public extension ProjectGraph {
    mutating func moveArchitectureBlock(
        id blockID: UUID,
        to layer: ArchitectureLayer,
        before targetID: UUID? = nil
    ) throws {
        guard let sourceIndex = blocks.firstIndex(where: { $0.id == blockID }) else {
            throw ArchitectureOrganizationError.blockNotFound
        }

        if targetID == blockID, blocks[sourceIndex].architectureLayer == layer {
            return
        }

        if let targetID {
            guard let target = blocks.first(where: { $0.id == targetID }) else {
                throw ArchitectureOrganizationError.targetNotFound
            }
            guard target.architectureLayer == layer else {
                throw ArchitectureOrganizationError.targetInDifferentLayer
            }
        }

        var block = blocks.remove(at: sourceIndex)
        block.architectureLayer = layer
        block.rowVersion += 1

        if let targetID, let destination = blocks.firstIndex(where: { $0.id == targetID }) {
            blocks.insert(block, at: destination)
        } else if let lastInLayer = blocks.lastIndex(where: { $0.architectureLayer == layer }) {
            blocks.insert(block, at: blocks.index(after: lastInLayer))
        } else {
            blocks.append(block)
        }

        rowVersion += 1
    }
}
