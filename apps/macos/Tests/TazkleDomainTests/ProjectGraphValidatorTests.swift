import XCTest
@testable import TazkleDomain

final class ProjectGraphValidatorTests: XCTestCase {
    func testAcceptsValidGraph() throws {
        let source = ProjectBlock(
            title: "Frontend",
            family: .technology,
            position: BlockPosition(x: 100, y: 100)
        )
        let target = ProjectBlock(
            title: "API",
            family: .technology,
            position: BlockPosition(x: 400, y: 100)
        )
        let graph = ProjectGraph(
            name: "Producto",
            blocks: [source, target],
            relations: [
                BlockRelation(sourceID: source.id, targetID: target.id, type: .dependsOn)
            ]
        )

        XCTAssertNoThrow(try ProjectGraphValidator.validate(graph))
    }

    func testRejectsSelfRelation() {
        let block = ProjectBlock(
            title: "API",
            family: .technology,
            position: BlockPosition(x: 100, y: 100)
        )
        let graph = ProjectGraph(
            name: "Producto",
            blocks: [block],
            relations: [
                BlockRelation(sourceID: block.id, targetID: block.id, type: .dependsOn)
            ]
        )

        XCTAssertThrowsError(try ProjectGraphValidator.validate(graph)) { error in
            XCTAssertEqual(error as? GraphValidationError, .selfRelation)
        }
    }

    func testRejectsDuplicateSemanticRelation() {
        let source = ProjectBlock(
            title: "Frontend",
            family: .technology,
            position: BlockPosition(x: 100, y: 100)
        )
        let target = ProjectBlock(
            title: "API",
            family: .technology,
            position: BlockPosition(x: 400, y: 100)
        )
        let first = BlockRelation(sourceID: source.id, targetID: target.id, type: .dependsOn)
        let second = BlockRelation(sourceID: source.id, targetID: target.id, type: .dependsOn)
        let graph = ProjectGraph(
            name: "Producto",
            blocks: [source, target],
            relations: [first, second]
        )

        XCTAssertThrowsError(try ProjectGraphValidator.validate(graph)) { error in
            XCTAssertEqual(error as? GraphValidationError, .duplicateRelation)
        }
    }

    func testSanitizesControlCharactersAndLength() {
        let value = "  Bloque\ncon\ttítulo demasiado largo  "
        let sanitized = ProjectGraphValidator.sanitizedSingleLine(value, limit: 12)

        XCTAssertEqual(sanitized, "Bloquecontít")
        XCTAssertFalse(sanitized.contains("\n"))
        XCTAssertFalse(sanitized.contains("\t"))
    }

    func testMovesArchitectureBlockBetweenLayers() throws {
        let experience = ProjectBlock(
            title: "Aplicación web",
            family: .technology,
            architectureLayer: .experience,
            position: BlockPosition(x: 100, y: 100)
        )
        let api = ProjectBlock(
            title: "API",
            family: .technology,
            architectureLayer: .services,
            position: BlockPosition(x: 300, y: 100)
        )
        var graph = ProjectGraph(name: "Producto", blocks: [experience, api])

        try graph.moveArchitectureBlock(id: experience.id, to: .services, before: api.id)

        XCTAssertEqual(graph.blocks.map(\.id), [experience.id, api.id])
        XCTAssertEqual(graph.blocks.first?.architectureLayer, .services)
        XCTAssertEqual(graph.blocks.first?.rowVersion, experience.rowVersion + 1)
        XCTAssertEqual(graph.rowVersion, 2)
    }

    func testUpdatesBlockDetailsAsOneValidatedVersionedOperation() throws {
        let block = ProjectBlock(
            title: "Componente",
            family: .product,
            position: BlockPosition(x: 100, y: 100)
        )
        var graph = ProjectGraph(name: "Producto", blocks: [block])

        try graph.updateBlockDetails(
            id: block.id,
            title: "API pública",
            summary: "Expone las operaciones del producto.",
            family: .technology,
            state: .ready,
            architectureLayer: .services
        )

        let updated = try XCTUnwrap(graph.block(id: block.id))
        XCTAssertEqual(updated.title, "API pública")
        XCTAssertEqual(updated.summary, "Expone las operaciones del producto.")
        XCTAssertEqual(updated.family, .technology)
        XCTAssertEqual(updated.state, .ready)
        XCTAssertEqual(updated.architectureLayer, .services)
        XCTAssertEqual(updated.rowVersion, block.rowVersion + 1)
        XCTAssertEqual(graph.rowVersion, 2)
    }

    func testRejectsEditingApprovedBlockWithoutChangingGraph() {
        let block = ProjectBlock(
            title: "Alcance aprobado",
            family: .product,
            state: .approved,
            position: BlockPosition(x: 100, y: 100)
        )
        var graph = ProjectGraph(name: "Producto", blocks: [block])
        let original = graph

        XCTAssertThrowsError(
            try graph.updateBlockDetails(
                id: block.id,
                title: "Alcance alterado",
                summary: "",
                family: .product,
                state: .draft,
                architectureLayer: .experience
            )
        ) { error in
            XCTAssertEqual(error as? GraphValidationError, .approvedBlockImmutable)
        }
        XCTAssertEqual(graph, original)
    }

    func testRejectsInvalidBlockEditAtomically() {
        let block = ProjectBlock(
            title: "Componente",
            family: .product,
            position: BlockPosition(x: 100, y: 100)
        )
        var graph = ProjectGraph(name: "Producto", blocks: [block])
        let original = graph

        XCTAssertThrowsError(
            try graph.updateBlockDetails(
                id: block.id,
                title: "",
                summary: "No debe persistirse",
                family: .technology,
                state: .ready,
                architectureLayer: .services
            )
        ) { error in
            XCTAssertEqual(error as? GraphValidationError, .emptyBlockTitle)
        }
        XCTAssertEqual(graph, original)
    }

    func testUpdatesRelationDetailsAsOneValidatedVersionedOperation() throws {
        let source = ProjectBlock(
            title: "Frontend",
            family: .technology,
            position: BlockPosition(x: 100, y: 100)
        )
        let target = ProjectBlock(
            title: "API",
            family: .technology,
            position: BlockPosition(x: 400, y: 100)
        )
        let relation = BlockRelation(
            sourceID: source.id,
            targetID: target.id,
            sourcePort: .right,
            targetPort: .left,
            type: .dependsOn
        )
        var graph = ProjectGraph(
            name: "Producto",
            blocks: [source, target],
            relations: [relation]
        )

        try graph.updateRelationDetails(
            id: relation.id,
            sourceID: target.id,
            targetID: source.id,
            sourcePort: .bottom,
            targetPort: .top,
            type: .requires,
            isCritical: true
        )

        let updated = try XCTUnwrap(graph.relations.first)
        XCTAssertEqual(updated.sourceID, target.id)
        XCTAssertEqual(updated.targetID, source.id)
        XCTAssertEqual(updated.sourcePort, .bottom)
        XCTAssertEqual(updated.targetPort, .top)
        XCTAssertEqual(updated.type, .requires)
        XCTAssertTrue(updated.isCritical)
        XCTAssertEqual(updated.rowVersion, relation.rowVersion + 1)
        XCTAssertEqual(graph.rowVersion, 2)
    }

    func testRejectsDuplicateRelationEditAtomically() {
        let source = ProjectBlock(
            title: "Frontend",
            family: .technology,
            position: BlockPosition(x: 100, y: 100)
        )
        let target = ProjectBlock(
            title: "API",
            family: .technology,
            position: BlockPosition(x: 400, y: 100)
        )
        let first = BlockRelation(
            sourceID: source.id,
            targetID: target.id,
            type: .requires
        )
        let second = BlockRelation(
            sourceID: source.id,
            targetID: target.id,
            type: .dependsOn
        )
        var graph = ProjectGraph(
            name: "Producto",
            blocks: [source, target],
            relations: [first, second]
        )
        let original = graph

        XCTAssertThrowsError(
            try graph.updateRelationDetails(
                id: second.id,
                sourceID: source.id,
                targetID: target.id,
                sourcePort: .bottom,
                targetPort: .top,
                type: .requires,
                isCritical: true
            )
        ) { error in
            XCTAssertEqual(error as? GraphValidationError, .duplicateRelation)
        }
        XCTAssertEqual(graph, original)
    }

    func testRejectsEditingRelationAttachedToApprovedBlock() {
        let source = ProjectBlock(
            title: "Alcance aprobado",
            family: .product,
            state: .approved,
            position: BlockPosition(x: 100, y: 100)
        )
        let target = ProjectBlock(
            title: "API",
            family: .technology,
            position: BlockPosition(x: 400, y: 100)
        )
        let relation = BlockRelation(
            sourceID: source.id,
            targetID: target.id,
            type: .implements
        )
        var graph = ProjectGraph(
            name: "Producto",
            blocks: [source, target],
            relations: [relation]
        )
        let original = graph

        XCTAssertThrowsError(
            try graph.updateRelationDetails(
                id: relation.id,
                sourceID: source.id,
                targetID: target.id,
                sourcePort: .bottom,
                targetPort: .top,
                type: .validates,
                isCritical: true
            )
        ) { error in
            XCTAssertEqual(error as? GraphValidationError, .approvedRelationImmutable)
        }
        XCTAssertEqual(graph, original)
    }

    func testAppendsDroppedBlockToTargetLayer() throws {
        let api = ProjectBlock(
            title: "API",
            family: .technology,
            architectureLayer: .services,
            position: BlockPosition(x: 100, y: 100)
        )
        let database = ProjectBlock(
            title: "Base de datos",
            family: .technology,
            architectureLayer: .data,
            position: BlockPosition(x: 300, y: 100)
        )
        var graph = ProjectGraph(name: "Producto", blocks: [api, database])

        try graph.moveArchitectureBlock(id: database.id, to: .services)

        XCTAssertEqual(graph.blocks.map(\.id), [api.id, database.id])
        XCTAssertEqual(graph.blocks.last?.architectureLayer, .services)
    }

    func testCanvasDragPayloadRoundTripsKnownValues() {
        let blockID = UUID()

        XCTAssertEqual(
            CanvasDragPayload(rawValue: CanvasDragPayload.existingBlock(blockID).rawValue),
            .existingBlock(blockID)
        )
        XCTAssertEqual(
            CanvasDragPayload(rawValue: CanvasDragPayload.blockTemplate(.technology).rawValue),
            .blockTemplate(.technology)
        )
    }

    func testCanvasDragPayloadRejectsUnknownOrMalformedInput() {
        XCTAssertNil(CanvasDragPayload(rawValue: "file:/Users/example/secret"))
        XCTAssertNil(CanvasDragPayload(rawValue: "template:unknown"))
        XCTAssertNil(CanvasDragPayload(rawValue: "block:not-a-uuid"))
        XCTAssertNil(CanvasDragPayload(rawValue: "template:technology:extra"))
        XCTAssertNil(CanvasDragPayload(rawValue: ""))
    }

    func testRemovingBlockAlsoRemovesIncidentRelations() throws {
        let source = ProjectBlock(
            title: "Frontend",
            family: .technology,
            position: BlockPosition(x: 100, y: 100)
        )
        let target = ProjectBlock(
            title: "API",
            family: .technology,
            position: BlockPosition(x: 400, y: 100)
        )
        let relation = BlockRelation(
            sourceID: source.id,
            targetID: target.id,
            type: .dependsOn
        )
        var graph = ProjectGraph(
            name: "Producto",
            blocks: [source, target],
            relations: [relation]
        )

        let snapshot = try XCTUnwrap(graph.removeBlock(id: source.id))

        XCTAssertEqual(snapshot.block, source)
        XCTAssertEqual(snapshot.relations, [relation])
        XCTAssertEqual(graph.blocks, [target])
        XCTAssertTrue(graph.relations.isEmpty)
        XCTAssertNoThrow(try ProjectGraphValidator.validate(graph))
    }

    func testRestoringRemovedBlockRestoresItsPositionAndRelations() throws {
        let source = ProjectBlock(
            title: "Frontend",
            family: .technology,
            position: BlockPosition(x: 100, y: 100)
        )
        let target = ProjectBlock(
            title: "API",
            family: .technology,
            position: BlockPosition(x: 400, y: 100)
        )
        let relation = BlockRelation(
            sourceID: source.id,
            targetID: target.id,
            type: .dependsOn
        )
        var graph = ProjectGraph(
            name: "Producto",
            blocks: [source, target],
            relations: [relation]
        )
        let snapshot = try XCTUnwrap(graph.removeBlock(id: source.id))

        graph.restoreBlock(from: snapshot)

        XCTAssertEqual(graph.blocks, [source, target])
        XCTAssertEqual(graph.relations, [relation])
        XCTAssertNoThrow(try ProjectGraphValidator.validate(graph))
    }

    func testRemovingRelationPreservesBlocksAndReturnsItsPosition() throws {
        let source = ProjectBlock(
            title: "Frontend",
            family: .technology,
            position: BlockPosition(x: 100, y: 100)
        )
        let target = ProjectBlock(
            title: "API",
            family: .technology,
            position: BlockPosition(x: 400, y: 100)
        )
        let first = BlockRelation(sourceID: source.id, targetID: target.id, type: .requires)
        let second = BlockRelation(sourceID: target.id, targetID: source.id, type: .dependsOn)
        var graph = ProjectGraph(
            name: "Producto",
            blocks: [source, target],
            relations: [first, second]
        )
        let initialVersion = graph.rowVersion

        let snapshot = try XCTUnwrap(graph.removeRelation(id: first.id))

        XCTAssertEqual(snapshot.relation, first)
        XCTAssertEqual(snapshot.relationIndex, 0)
        XCTAssertEqual(graph.blocks, [source, target])
        XCTAssertEqual(graph.relations, [second])
        XCTAssertEqual(graph.rowVersion, initialVersion + 1)
        XCTAssertNoThrow(try ProjectGraphValidator.validate(graph))
    }

    func testRestoringRelationUsesItsOriginalPosition() throws {
        let source = ProjectBlock(
            title: "Frontend",
            family: .technology,
            position: BlockPosition(x: 100, y: 100)
        )
        let target = ProjectBlock(
            title: "API",
            family: .technology,
            position: BlockPosition(x: 400, y: 100)
        )
        let first = BlockRelation(sourceID: source.id, targetID: target.id, type: .requires)
        let second = BlockRelation(sourceID: target.id, targetID: source.id, type: .dependsOn)
        var graph = ProjectGraph(
            name: "Producto",
            blocks: [source, target],
            relations: [first, second]
        )
        let snapshot = try XCTUnwrap(graph.removeRelation(id: first.id))

        graph.restoreRelation(from: snapshot)

        XCTAssertEqual(graph.relations, [first, second])
        XCTAssertNoThrow(try ProjectGraphValidator.validate(graph))
    }

    func testDecodesLegacyRelationWithDefaultPorts() throws {
        let relationID = UUID()
        let sourceID = UUID()
        let targetID = UUID()
        let data = try XCTUnwrap(
            """
            {
              "id": "\(relationID.uuidString)",
              "sourceID": "\(sourceID.uuidString)",
              "targetID": "\(targetID.uuidString)",
              "type": "requires",
              "isCritical": false,
              "rowVersion": 1
            }
            """.data(using: .utf8)
        )

        let relation = try JSONDecoder().decode(BlockRelation.self, from: data)

        XCTAssertEqual(relation.sourcePort, .right)
        XCTAssertEqual(relation.targetPort, .left)
    }
}
