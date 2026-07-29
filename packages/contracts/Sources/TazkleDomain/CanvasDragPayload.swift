import Foundation

/// Payload pequeño y cerrado para movimientos dentro de los lienzos de Tazkle.
/// Evita interpretar texto libre, rutas o tipos no previstos recibidos por drag and drop.
public enum CanvasDragPayload: Equatable, Sendable {
    case existingBlock(UUID)
    case blockTemplate(BlockFamily)

    public init?(rawValue: String) {
        let parts = rawValue.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        switch parts[0] {
        case "block":
            guard let id = UUID(uuidString: String(parts[1])) else { return nil }
            self = .existingBlock(id)
        case "template":
            guard let family = BlockFamily(rawValue: String(parts[1])) else { return nil }
            self = .blockTemplate(family)
        default:
            return nil
        }
    }

    public var rawValue: String {
        switch self {
        case let .existingBlock(id):
            "block:\(id.uuidString)"
        case let .blockTemplate(family):
            "template:\(family.rawValue)"
        }
    }
}
