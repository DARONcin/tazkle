import CSQLite
import Foundation
import XCTest
@testable import TazkleDomain
@testable import TazklePersistence

final class SQLiteProjectStoreTests: XCTestCase {
    func testRoundTripPersistsBlocksAndRelations() throws {
        let context = try makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }

        let source = ProjectBlock(
            title: "Inicio de sesión",
            summary: "Acceso seguro al producto.",
            family: .product,
            architectureLayer: .experience,
            position: BlockPosition(x: 120, y: 150)
        )
        let target = ProjectBlock(
            title: "Base de datos",
            family: .technology,
            architectureLayer: .data,
            position: BlockPosition(x: 450, y: 150)
        )
        let relation = BlockRelation(
            sourceID: source.id,
            targetID: target.id,
            sourcePort: .bottom,
            targetPort: .top,
            type: .requires,
            isCritical: true
        )
        let graph = ProjectGraph(
            name: "Atlas",
            blocks: [source, target],
            relations: [relation]
        )

        try context.store.save(graph)
        let loaded = try XCTUnwrap(context.store.loadLatestProject())

        XCTAssertEqual(loaded.id, graph.id)
        XCTAssertEqual(loaded.name, graph.name)
        XCTAssertEqual(Set(loaded.blocks), Set(graph.blocks))
        XCTAssertEqual(Set(loaded.relations), Set(graph.relations))
    }

    func testListsAndLoadsProjectsWithoutMixingTheirGraphs() throws {
        let context = try makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }

        let webBlock = ProjectBlock(
            title: "Frontend",
            family: .technology,
            position: BlockPosition(x: 120, y: 150)
        )
        let webProject = ProjectGraph(name: "Portal", blocks: [webBlock])
        let blankProject = ProjectGraph(name: "Exploración")

        try context.store.save(webProject, template: .webApplication)
        try context.store.save(blankProject, template: .blankCanvas)

        let projects = try context.store.listProjects()
        XCTAssertEqual(Set(projects.map(\.id)), [webProject.id, blankProject.id])
        XCTAssertEqual(
            projects.first(where: { $0.id == webProject.id })?.template,
            .webApplication
        )
        XCTAssertEqual(
            projects.first(where: { $0.id == blankProject.id })?.template,
            .blankCanvas
        )

        let loadedWeb = try XCTUnwrap(context.store.loadProject(id: webProject.id))
        let loadedBlank = try XCTUnwrap(context.store.loadProject(id: blankProject.id))

        XCTAssertEqual(loadedWeb.blocks, [webBlock])
        XCTAssertTrue(loadedBlank.blocks.isEmpty)
        XCTAssertNotEqual(loadedWeb.id, loadedBlank.id)
    }

    func testLoadProjectReturnsNilForUnknownIdentifier() throws {
        let context = try makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }

        XCTAssertNil(try context.store.loadProject(id: UUID()))
    }

    func testRejectsUnknownProjectTemplateFromSQLite() throws {
        let context = try makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }

        try context.store.save(ProjectGraph(name: "Plantilla segura"))
        let path = context.directory.appendingPathComponent("test.sqlite3").path
        try executeRawSQL(
            """
            PRAGMA ignore_check_constraints = ON;
            UPDATE projects SET template_key = 'dynamic-template';
            """,
            path: path
        )

        XCTAssertThrowsError(try context.store.listProjects()) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "La base local contiene datos inválidos: "
                    + "Proyecto sin identificador, nombre o plantilla válida."
            )
        }
    }

    func testMigratesVersionTwoRelationsWithFacingPorts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tazkle-port-migration-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let path = directory.appendingPathComponent("version-two.sqlite3").path
        try createVersionTwoDatabase(path: path)
        let store = try SQLiteProjectStore(path: path)
        let loaded = try XCTUnwrap(store.loadLatestProject())
        let relation = try XCTUnwrap(loaded.relations.first)

        XCTAssertEqual(relation.sourcePort, .bottom)
        XCTAssertEqual(relation.targetPort, .top)
        XCTAssertNoThrow(try store.save(loaded))
    }

    func testMigratesVersionOneDatabaseBeforeSavingArchitectureLayer() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tazkle-migration-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let path = directory.appendingPathComponent("version-one.sqlite3").path
        try createVersionOneDatabase(path: path)
        let store = try SQLiteProjectStore(path: path)
        let block = ProjectBlock(
            title: "API",
            family: .technology,
            architectureLayer: .services,
            position: BlockPosition(x: 100, y: 100)
        )

        try store.save(ProjectGraph(name: "Migración", blocks: [block]))
        let loaded = try XCTUnwrap(store.loadLatestProject())

        XCTAssertEqual(loaded.blocks.first?.architectureLayer, .services)

        try executeRawSQL(
            "UPDATE blocks SET architecture_layer = 'unknown-layer';",
            path: path
        )
        XCTAssertThrowsError(try store.loadLatestProject()) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "La base local contiene datos inválidos: Bloque con capa arquitectónica desconocida."
            )
        }
    }

    func testPreparedStatementPreservesQuotedInput() throws {
        let context = try makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }

        let suspiciousButValidTitle = "Robert'); DROP TABLE blocks; --"
        let block = ProjectBlock(
            title: suspiciousButValidTitle,
            family: .product,
            position: BlockPosition(x: 100, y: 100)
        )
        let graph = ProjectGraph(name: "Injection test", blocks: [block])

        try context.store.save(graph)
        let loaded = try XCTUnwrap(context.store.loadLatestProject())

        XCTAssertEqual(loaded.blocks.first?.title, suspiciousButValidTitle)
        XCTAssertNoThrow(try context.store.save(loaded))
    }

    func testSaveRejectsInvalidGraphBeforeSQLite() throws {
        let context = try makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }

        let block = ProjectBlock(
            title: "API",
            family: .technology,
            position: BlockPosition(x: 100, y: 100)
        )
        let invalid = ProjectGraph(
            name: "Producto",
            blocks: [block],
            relations: [
                BlockRelation(sourceID: block.id, targetID: block.id, type: .dependsOn)
            ]
        )

        XCTAssertThrowsError(try context.store.save(invalid)) { error in
            XCTAssertEqual(error as? GraphValidationError, .selfRelation)
        }
    }

    func testSavingDeletionRemovesBlockAndRelationsFromSQLite() throws {
        let context = try makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }

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
        var graph = ProjectGraph(
            name: "Producto",
            blocks: [source, target],
            relations: [
                BlockRelation(
                    sourceID: source.id,
                    targetID: target.id,
                    type: .dependsOn
                )
            ]
        )
        try context.store.save(graph)

        XCTAssertNotNil(graph.removeBlock(id: source.id))
        try context.store.save(graph)
        let loaded = try XCTUnwrap(context.store.loadLatestProject())

        XCTAssertEqual(loaded.blocks, [target])
        XCTAssertTrue(loaded.relations.isEmpty)
    }

    func testSavingRelationDeletionKeepsItsBlocksInSQLite() throws {
        let context = try makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }

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
        try context.store.save(graph)

        XCTAssertNotNil(graph.removeRelation(id: relation.id))
        try context.store.save(graph)
        let loaded = try XCTUnwrap(context.store.loadLatestProject())

        XCTAssertEqual(loaded.blocks, [source, target])
        XCTAssertTrue(loaded.relations.isEmpty)
    }

    func testSavingRelationEditPersistsEndpointsPortsTypeAndCriticality() throws {
        let context = try makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }

        let frontend = ProjectBlock(
            title: "Frontend",
            family: .technology,
            position: BlockPosition(x: 100, y: 100)
        )
        let api = ProjectBlock(
            title: "API",
            family: .technology,
            position: BlockPosition(x: 400, y: 100)
        )
        let relation = BlockRelation(
            sourceID: frontend.id,
            targetID: api.id,
            type: .dependsOn
        )
        var graph = ProjectGraph(
            name: "Producto",
            blocks: [frontend, api],
            relations: [relation]
        )
        try context.store.save(graph)

        try graph.updateRelationDetails(
            id: relation.id,
            sourceID: api.id,
            targetID: frontend.id,
            sourcePort: .top,
            targetPort: .bottom,
            type: .requires,
            isCritical: true
        )
        try context.store.save(graph)
        let loaded = try XCTUnwrap(context.store.loadLatestProject())
        let persisted = try XCTUnwrap(loaded.relations.first)

        XCTAssertEqual(persisted.sourceID, api.id)
        XCTAssertEqual(persisted.targetID, frontend.id)
        XCTAssertEqual(persisted.sourcePort, .top)
        XCTAssertEqual(persisted.targetPort, .bottom)
        XCTAssertEqual(persisted.type, .requires)
        XCTAssertTrue(persisted.isCritical)
        XCTAssertEqual(persisted.rowVersion, relation.rowVersion + 1)
    }

    func testRejectsUnknownConnectionPortFromSQLite() throws {
        let context = try makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }

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
                BlockRelation(
                    sourceID: source.id,
                    targetID: target.id,
                    sourcePort: .right,
                    targetPort: .left,
                    type: .dependsOn
                )
            ]
        )
        try context.store.save(graph)

        let path = context.directory.appendingPathComponent("test.sqlite3").path
        try executeRawSQL(
            """
            PRAGMA ignore_check_constraints = ON;
            UPDATE relations SET source_port = 'diagonal';
            """,
            path: path
        )

        XCTAssertThrowsError(try context.store.loadLatestProject()) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "La base local contiene datos inválidos: Relación con valores desconocidos."
            )
        }
    }

    func testPlanningProfileRoundTripStaysScopedToItsProject() throws {
        let context = try makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }

        let first = ProjectGraph(name: "Primero")
        let second = ProjectGraph(name: "Segundo")
        try context.store.save(first)
        try context.store.save(second)

        var profile = ProjectPlanningProfile.defaultProfile(for: first)
        profile.problemStatement = "Reducir el tiempo de captura."
        profile.availableBudgetMXN = 850_000
        profile.prepareForSave()
        try context.store.savePlanningProfile(profile)

        let loaded = try XCTUnwrap(
            context.store.loadPlanningProfile(projectID: first.id)
        )

        XCTAssertEqual(loaded, profile)
        XCTAssertNil(try context.store.loadPlanningProfile(projectID: second.id))
    }

    func testPlanningProfileRejectsMismatchedProjectIdentifier() throws {
        let context = try makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }

        let graph = ProjectGraph(name: "Proyecto")
        try context.store.save(graph)
        let anotherGraph = ProjectGraph(name: "Otro")
        let profile = ProjectPlanningProfile.defaultProfile(for: anotherGraph)

        XCTAssertThrowsError(
            try PlanningValidator.validate(profile, projectID: graph.id)
        ) { error in
            XCTAssertEqual(error as? PlanningValidationError, .projectMismatch)
        }
    }

    func testPlanningProfileUsesBoundPayloadAndPreservesQuotedText() throws {
        let context = try makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }

        let graph = ProjectGraph(name: "Entrada parametrizada")
        try context.store.save(graph)
        var profile = ProjectPlanningProfile.defaultProfile(for: graph)
        profile.problemStatement = "'); DROP TABLE planning_profiles; --"
        profile.prepareForSave()

        try context.store.savePlanningProfile(profile)
        let loaded = try XCTUnwrap(
            context.store.loadPlanningProfile(projectID: graph.id)
        )

        XCTAssertEqual(loaded.problemStatement, profile.problemStatement)
        XCTAssertEqual(try context.store.listProjects().map(\.id), [graph.id])
    }

    private func makeStore() throws -> (store: SQLiteProjectStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tazkle-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try SQLiteProjectStore(path: directory.appendingPathComponent("test.sqlite3").path)
        return (store, directory)
    }

    private func createVersionOneDatabase(path: String) throws {
        var database: OpaquePointer?
        guard sqlite3_open(path, &database) == SQLITE_OK else {
            XCTFail("No se pudo crear la base de migración")
            return
        }
        defer { sqlite3_close(database) }

        let schema = """
        CREATE TABLE projects (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            row_version INTEGER NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE TABLE blocks (
            id TEXT PRIMARY KEY NOT NULL,
            project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
            title TEXT NOT NULL,
            summary TEXT NOT NULL,
            family TEXT NOT NULL,
            state TEXT NOT NULL,
            position_x REAL NOT NULL,
            position_y REAL NOT NULL,
            row_version INTEGER NOT NULL
        );
        CREATE TABLE relations (
            id TEXT PRIMARY KEY NOT NULL,
            project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
            source_id TEXT NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
            target_id TEXT NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
            relation_type TEXT NOT NULL,
            is_critical INTEGER NOT NULL,
            row_version INTEGER NOT NULL
        );
        PRAGMA user_version = 1;
        """

        guard sqlite3_exec(database, schema, nil, nil, nil) == SQLITE_OK else {
            XCTFail("No se pudo preparar la base de migración")
            return
        }
    }

    private func createVersionTwoDatabase(path: String) throws {
        var database: OpaquePointer?
        guard sqlite3_open(path, &database) == SQLITE_OK else {
            XCTFail("No se pudo crear la base de migración de puertos")
            return
        }
        defer { sqlite3_close(database) }

        let projectID = UUID().uuidString
        let sourceID = UUID().uuidString
        let targetID = UUID().uuidString
        let relationID = UUID().uuidString
        let schema = """
        CREATE TABLE projects (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            row_version INTEGER NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE TABLE blocks (
            id TEXT PRIMARY KEY NOT NULL,
            project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
            title TEXT NOT NULL,
            summary TEXT NOT NULL,
            family TEXT NOT NULL,
            state TEXT NOT NULL,
            architecture_layer TEXT,
            position_x REAL NOT NULL,
            position_y REAL NOT NULL,
            row_version INTEGER NOT NULL
        );
        CREATE TABLE relations (
            id TEXT PRIMARY KEY NOT NULL,
            project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
            source_id TEXT NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
            target_id TEXT NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
            relation_type TEXT NOT NULL,
            is_critical INTEGER NOT NULL,
            row_version INTEGER NOT NULL
        );
        INSERT INTO projects VALUES ('\(projectID)', 'Migración', 1, 1);
        INSERT INTO blocks VALUES (
            '\(sourceID)', '\(projectID)', 'Frontend', '', 'technology',
            'draft', 'experience', 100, 100, 1
        );
        INSERT INTO blocks VALUES (
            '\(targetID)', '\(projectID)', 'API', '', 'technology',
            'draft', 'services', 100, 400, 1
        );
        INSERT INTO relations VALUES (
            '\(relationID)', '\(projectID)', '\(sourceID)', '\(targetID)',
            'dependsOn', 0, 1
        );
        PRAGMA user_version = 2;
        """

        guard sqlite3_exec(database, schema, nil, nil, nil) == SQLITE_OK else {
            XCTFail("No se pudo preparar la base de migración de puertos")
            return
        }
    }

    private func executeRawSQL(_ sql: String, path: String) throws {
        var database: OpaquePointer?
        guard sqlite3_open(path, &database) == SQLITE_OK else {
            XCTFail("No se pudo abrir la base de prueba")
            return
        }
        defer { sqlite3_close(database) }

        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            XCTFail("No se pudo alterar la base de prueba")
            return
        }
    }
}
