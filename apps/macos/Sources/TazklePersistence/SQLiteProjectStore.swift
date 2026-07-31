import CSQLite
import CryptoKit
import Foundation
import TazkleDomain

public enum SQLiteStoreError: Error, LocalizedError {
    case cannotOpen(String)
    case executionFailed(String)
    case preparationFailed(String)
    case bindingFailed(String)
    case corruptData(String)

    public var errorDescription: String? {
        switch self {
        case let .cannotOpen(message): "No se pudo abrir la base local: \(message)"
        case let .executionFailed(message): "Falló una operación local: \(message)"
        case let .preparationFailed(message): "No se pudo preparar una operación local: \(message)"
        case let .bindingFailed(message): "No se pudo vincular un valor local: \(message)"
        case let .corruptData(message): "La base local contiene datos inválidos: \(message)"
        }
    }
}

public enum ProjectTemplateKey: String, CaseIterable, Codable, Sendable {
    case webApplication = "web-application"
    case blankCanvas = "blank-canvas"
}

public struct StoredProjectSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let template: ProjectTemplateKey
    public let updatedAt: Date

    public init(
        id: UUID,
        name: String,
        template: ProjectTemplateKey,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.template = template
        self.updatedAt = updatedAt
    }
}

public final class SQLiteProjectStore {
    private var database: OpaquePointer?

    public init(path: String) throws {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &database, flags, nil) == SQLITE_OK else {
            let message = databaseMessage
            sqlite3_close(database)
            database = nil
            throw SQLiteStoreError.cannotOpen(message)
        }

        sqlite3_busy_timeout(database, 3_000)
        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA journal_mode = WAL;")
        try migrate()

        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: path
        )
    }

    deinit {
        sqlite3_close(database)
    }

    public static func applicationSupport(
        workspaceAccountID: String
    ) throws -> SQLiteProjectStore {
        let directory = try applicationSupportDirectory(
            workspaceAccountID: workspaceAccountID
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return try SQLiteProjectStore(path: directory.appendingPathComponent("tazkle.sqlite3").path)
    }

    public static func deleteApplicationSupport(
        workspaceAccountID: String
    ) throws {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw SQLiteStoreError.cannotOpen(
                "Application Support no está disponible."
            )
        }
        try deleteApplicationSupport(
            workspaceAccountID: workspaceAccountID,
            applicationSupportBase: base
        )
    }

    static func deleteApplicationSupport(
        workspaceAccountID: String,
        applicationSupportBase: URL
    ) throws {
        let directory = try applicationSupportDirectory(
            workspaceAccountID: workspaceAccountID,
            applicationSupportBase: applicationSupportBase
        )
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }
        try FileManager.default.removeItem(at: directory)
    }

    static func accountDirectoryName(
        for workspaceAccountID: String
    ) throws -> String {
        let normalizedSubject = workspaceAccountID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard
            !normalizedSubject.isEmpty,
            normalizedSubject.count <= 255,
            !normalizedSubject.unicodeScalars.contains(where: {
                CharacterSet.controlCharacters.contains($0)
            })
        else {
            throw SQLiteStoreError.cannotOpen(
                "La sesión no contiene un identificador de cuenta válido."
            )
        }
        return SHA256.hash(
            data: Data(normalizedSubject.utf8)
        ).map { String(format: "%02x", $0) }.joined()
    }

    private static func applicationSupportDirectory(
        workspaceAccountID: String
    ) throws -> URL {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw SQLiteStoreError.cannotOpen(
                "Application Support no está disponible."
            )
        }
        return try applicationSupportDirectory(
            workspaceAccountID: workspaceAccountID,
            applicationSupportBase: base
        )
    }

    static func applicationSupportDirectory(
        workspaceAccountID: String,
        applicationSupportBase: URL
    ) throws -> URL {
        let accountDirectoryName = try accountDirectoryName(
            for: workspaceAccountID
        )
        return applicationSupportBase
            .appendingPathComponent("Tazkle", isDirectory: true)
            .appendingPathComponent("Accounts", isDirectory: true)
            .appendingPathComponent(accountDirectoryName, isDirectory: true)
    }

    public func save(
        _ graph: ProjectGraph,
        template: ProjectTemplateKey = .webApplication
    ) throws {
        try ProjectGraphValidator.validate(graph)
        try execute("BEGIN IMMEDIATE TRANSACTION;")

        do {
            try upsertProject(graph, template: template)
            try deleteRelations(projectID: graph.id)
            try deleteBlocks(projectID: graph.id)

            for block in graph.blocks {
                try insert(block: block, projectID: graph.id)
            }
            for relation in graph.relations {
                try insert(relation: relation, projectID: graph.id)
            }

            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    public func loadLatestProject() throws -> ProjectGraph? {
        guard let latest = try listProjects().first else { return nil }
        return try loadProject(id: latest.id)
    }

    public func savePlanningProfile(_ profile: ProjectPlanningProfile) throws {
        try PlanningValidator.validate(profile)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload: Data
        do {
            payload = try encoder.encode(profile)
        } catch {
            throw SQLiteStoreError.corruptData(
                "No se pudieron codificar los datos de planeación."
            )
        }
        guard let payloadJSON = String(data: payload, encoding: .utf8) else {
            throw SQLiteStoreError.corruptData(
                "Los datos de planeación no tienen una codificación válida."
            )
        }

        let sql = """
        INSERT INTO planning_profiles (
            project_id, payload_json, row_version, updated_at
        ) VALUES (?, ?, ?, ?)
        ON CONFLICT(project_id) DO UPDATE SET
            payload_json = excluded.payload_json,
            row_version = excluded.row_version,
            updated_at = excluded.updated_at;
        """

        try withStatement(sql) { statement in
            try bind(profile.projectID.uuidString, to: 1, in: statement)
            try bind(payloadJSON, to: 2, in: statement)
            try bind(Int64(profile.rowVersion), to: 3, in: statement)
            try bind(Date().timeIntervalSince1970, to: 4, in: statement)
            try requireDone(statement)
        }
    }

    public func loadPlanningProfile(projectID: UUID) throws -> ProjectPlanningProfile? {
        let sql = """
        SELECT payload_json, row_version
        FROM planning_profiles
        WHERE project_id = ?
        LIMIT 1;
        """

        return try withStatement(sql) { statement in
            try bind(projectID.uuidString, to: 1, in: statement)
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return nil }
            guard result == SQLITE_ROW,
                  let payloadJSON = optionalText(statement, column: 0),
                  let payload = payloadJSON.data(using: .utf8) else {
                throw SQLiteStoreError.corruptData(
                    "Perfil de planeación sin contenido válido."
                )
            }

            let profile: ProjectPlanningProfile
            do {
                profile = try JSONDecoder().decode(ProjectPlanningProfile.self, from: payload)
            } catch {
                throw SQLiteStoreError.corruptData(
                    "Perfil de planeación con estructura desconocida."
                )
            }

            let storedVersion = Int(sqlite3_column_int64(statement, 1))
            guard profile.rowVersion == storedVersion else {
                throw SQLiteStoreError.corruptData(
                    "La versión del perfil de planeación no coincide."
                )
            }
            try PlanningValidator.validate(profile, projectID: projectID)
            return profile
        }
    }

    public func listProjects() throws -> [StoredProjectSummary] {
        let sql = """
        SELECT id, name, template_key, updated_at
        FROM projects
        ORDER BY updated_at DESC, name COLLATE NOCASE;
        """

        return try withStatement(sql) { statement in
            var projects: [StoredProjectSummary] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                guard
                    let projectID = UUID(uuidString: text(statement, column: 0)),
                    let name = optionalText(statement, column: 1),
                    let template = ProjectTemplateKey(rawValue: text(statement, column: 2))
                else {
                    throw SQLiteStoreError.corruptData(
                        "Proyecto sin identificador, nombre o plantilla válida."
                    )
                }

                projects.append(
                    StoredProjectSummary(
                        id: projectID,
                        name: name,
                        template: template,
                        updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
                    )
                )
            }
            return projects
        }
    }

    public func loadProject(id projectID: UUID) throws -> ProjectGraph? {
        let projectSQL = """
        SELECT id, name, row_version
        FROM projects
        WHERE id = ?
        LIMIT 1;
        """

        return try withStatement(projectSQL) { statement in
            try bind(projectID.uuidString, to: 1, in: statement)
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return nil }
            guard result == SQLITE_ROW else {
                throw SQLiteStoreError.executionFailed(databaseMessage)
            }

            guard
                let storedProjectID = UUID(uuidString: text(statement, column: 0)),
                let name = optionalText(statement, column: 1)
            else {
                throw SQLiteStoreError.corruptData("Proyecto sin identificador o nombre válido.")
            }

            let rowVersion = Int(sqlite3_column_int64(statement, 2))
            let blocks = try loadBlocks(projectID: storedProjectID)
            let relations = try loadRelations(projectID: storedProjectID)
            let graph = ProjectGraph(
                id: storedProjectID,
                name: name,
                blocks: blocks,
                relations: relations,
                rowVersion: rowVersion
            )
            try ProjectGraphValidator.validate(graph)
            return graph
        }
    }

    public func deleteProject(id projectID: UUID) throws {
        try withStatement("DELETE FROM projects WHERE id = ?;") { statement in
            try bind(projectID.uuidString, to: 1, in: statement)
            try requireDone(statement)
        }
    }

    @discardableResult
    public func removeLegacySyntheticPlaceholderIfPresent() throws -> Bool {
        let projects = try listProjects()
        guard
            projects.count == 1,
            let summary = projects.first,
            summary.name == "Proyecto sin nombre",
            summary.template == .blankCanvas,
            let graph = try loadProject(id: summary.id),
            graph.blocks.isEmpty,
            graph.relations.isEmpty,
            try loadPlanningProfile(projectID: summary.id) == nil
        else {
            return false
        }

        try deleteProject(id: summary.id)
        return true
    }

    private func migrate() throws {
        let existingVersion = try userVersion()
        guard existingVersion <= 6 else {
            throw SQLiteStoreError.corruptData(
                "La base local usa una versión más reciente que esta aplicación."
            )
        }

        try execute("""
        CREATE TABLE IF NOT EXISTS projects (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 120),
            template_key TEXT NOT NULL DEFAULT 'web-application' CHECK(
                template_key IN ('web-application', 'blank-canvas')
            ),
            row_version INTEGER NOT NULL CHECK(row_version > 0),
            updated_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS blocks (
            id TEXT PRIMARY KEY NOT NULL,
            project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
            title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 80),
            summary TEXT NOT NULL CHECK(length(summary) <= 500),
            family TEXT NOT NULL,
            state TEXT NOT NULL,
            architecture_layer TEXT CHECK(
                architecture_layer IS NULL OR architecture_layer IN (
                    'experience', 'services', 'data', 'infrastructure'
                )
            ),
            position_x REAL NOT NULL,
            position_y REAL NOT NULL,
            row_version INTEGER NOT NULL CHECK(row_version > 0)
        );

        CREATE TABLE IF NOT EXISTS relations (
            id TEXT PRIMARY KEY NOT NULL,
            project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
            source_id TEXT NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
            target_id TEXT NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
            source_port TEXT NOT NULL DEFAULT 'right' CHECK(
                source_port IN ('top', 'right', 'bottom', 'left')
            ),
            target_port TEXT NOT NULL DEFAULT 'left' CHECK(
                target_port IN ('top', 'right', 'bottom', 'left')
            ),
            relation_type TEXT NOT NULL,
            is_critical INTEGER NOT NULL CHECK(is_critical IN (0, 1)),
            row_version INTEGER NOT NULL CHECK(row_version > 0),
            CHECK(source_id <> target_id),
            UNIQUE(project_id, source_id, target_id, relation_type)
        );

        CREATE INDEX IF NOT EXISTS idx_blocks_project ON blocks(project_id);
        CREATE INDEX IF NOT EXISTS idx_relations_project ON relations(project_id);

        CREATE TABLE IF NOT EXISTS planning_profiles (
            project_id TEXT PRIMARY KEY NOT NULL
                REFERENCES projects(id) ON DELETE CASCADE,
            payload_json TEXT NOT NULL CHECK(length(payload_json) <= 100000),
            row_version INTEGER NOT NULL CHECK(row_version > 0),
            updated_at REAL NOT NULL
        );
        """)

        if existingVersion == 1 {
            try execute("ALTER TABLE blocks ADD COLUMN architecture_layer TEXT;")
        }

        if existingVersion == 1 || existingVersion == 2 {
            try execute("""
            ALTER TABLE relations ADD COLUMN source_port TEXT NOT NULL DEFAULT 'right'
            CHECK(source_port IN ('top', 'right', 'bottom', 'left'));
            """)
            try execute("""
            ALTER TABLE relations ADD COLUMN target_port TEXT NOT NULL DEFAULT 'left'
            CHECK(target_port IN ('top', 'right', 'bottom', 'left'));
            """)
        }

        if (1...3).contains(existingVersion) {
            try execute("""
            CREATE TEMP TABLE relation_port_migration AS
            SELECT
                relation.id AS relation_id,
                CASE
                    WHEN abs(target.position_x - source.position_x)
                        >= abs(target.position_y - source.position_y)
                    THEN CASE
                        WHEN target.position_x >= source.position_x THEN 'right'
                        ELSE 'left'
                    END
                    ELSE CASE
                        WHEN target.position_y >= source.position_y THEN 'bottom'
                        ELSE 'top'
                    END
                END AS source_port,
                CASE
                    WHEN abs(target.position_x - source.position_x)
                        >= abs(target.position_y - source.position_y)
                    THEN CASE
                        WHEN target.position_x >= source.position_x THEN 'left'
                        ELSE 'right'
                    END
                    ELSE CASE
                        WHEN target.position_y >= source.position_y THEN 'top'
                        ELSE 'bottom'
                    END
                END AS target_port
            FROM relations relation
            JOIN blocks source ON source.id = relation.source_id
            JOIN blocks target ON target.id = relation.target_id;

            UPDATE relations
            SET
                source_port = (
                    SELECT source_port
                    FROM relation_port_migration
                    WHERE relation_id = relations.id
                ),
                target_port = (
                    SELECT target_port
                    FROM relation_port_migration
                    WHERE relation_id = relations.id
                );

            DROP TABLE relation_port_migration;
            """)
        }

        if (1...4).contains(existingVersion) {
            try execute("""
            ALTER TABLE projects ADD COLUMN template_key TEXT NOT NULL
            DEFAULT 'web-application'
            CHECK(template_key IN ('web-application', 'blank-canvas'));
            """)
        }

        try execute("PRAGMA user_version = 6;")
    }

    private func userVersion() throws -> Int {
        try withStatement("PRAGMA user_version;") { statement in
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw SQLiteStoreError.executionFailed(databaseMessage)
            }
            return Int(sqlite3_column_int(statement, 0))
        }
    }

    private func upsertProject(
        _ graph: ProjectGraph,
        template: ProjectTemplateKey
    ) throws {
        let sql = """
        INSERT INTO projects (id, name, template_key, row_version, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            template_key = excluded.template_key,
            row_version = excluded.row_version,
            updated_at = excluded.updated_at;
        """

        try withStatement(sql) { statement in
            try bind(graph.id.uuidString, to: 1, in: statement)
            try bind(graph.name, to: 2, in: statement)
            try bind(template.rawValue, to: 3, in: statement)
            try bind(Int64(graph.rowVersion), to: 4, in: statement)
            try bind(Date().timeIntervalSince1970, to: 5, in: statement)
            try requireDone(statement)
        }
    }

    private func insert(block: ProjectBlock, projectID: UUID) throws {
        let sql = """
        INSERT INTO blocks (
            id, project_id, title, summary, family, state, architecture_layer,
            position_x, position_y, row_version
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        try withStatement(sql) { statement in
            try bind(block.id.uuidString, to: 1, in: statement)
            try bind(projectID.uuidString, to: 2, in: statement)
            try bind(block.title, to: 3, in: statement)
            try bind(block.summary, to: 4, in: statement)
            try bind(block.family.rawValue, to: 5, in: statement)
            try bind(block.state.rawValue, to: 6, in: statement)
            try bind(block.architectureLayer?.rawValue, to: 7, in: statement)
            try bind(block.position.x, to: 8, in: statement)
            try bind(block.position.y, to: 9, in: statement)
            try bind(Int64(block.rowVersion), to: 10, in: statement)
            try requireDone(statement)
        }
    }

    private func insert(relation: BlockRelation, projectID: UUID) throws {
        let sql = """
        INSERT INTO relations (
            id, project_id, source_id, target_id, source_port, target_port,
            relation_type, is_critical, row_version
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        try withStatement(sql) { statement in
            try bind(relation.id.uuidString, to: 1, in: statement)
            try bind(projectID.uuidString, to: 2, in: statement)
            try bind(relation.sourceID.uuidString, to: 3, in: statement)
            try bind(relation.targetID.uuidString, to: 4, in: statement)
            try bind(relation.sourcePort.rawValue, to: 5, in: statement)
            try bind(relation.targetPort.rawValue, to: 6, in: statement)
            try bind(relation.type.rawValue, to: 7, in: statement)
            try bind(Int64(relation.isCritical ? 1 : 0), to: 8, in: statement)
            try bind(Int64(relation.rowVersion), to: 9, in: statement)
            try requireDone(statement)
        }
    }

    private func deleteRelations(projectID: UUID) throws {
        try delete(from: "relations", projectID: projectID)
    }

    private func deleteBlocks(projectID: UUID) throws {
        try delete(from: "blocks", projectID: projectID)
    }

    private func delete(from trustedTable: String, projectID: UUID) throws {
        let allowedTables = ["blocks", "relations"]
        guard allowedTables.contains(trustedTable) else {
            throw SQLiteStoreError.executionFailed("Tabla no permitida.")
        }

        try withStatement("DELETE FROM \(trustedTable) WHERE project_id = ?;") { statement in
            try bind(projectID.uuidString, to: 1, in: statement)
            try requireDone(statement)
        }
    }

    private func loadBlocks(projectID: UUID) throws -> [ProjectBlock] {
        let sql = """
        SELECT id, title, summary, family, state, architecture_layer,
               position_x, position_y, row_version
        FROM blocks
        WHERE project_id = ?
        ORDER BY rowid;
        """

        return try withStatement(sql) { statement in
            try bind(projectID.uuidString, to: 1, in: statement)
            var blocks: [ProjectBlock] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                guard
                    let id = UUID(uuidString: text(statement, column: 0)),
                    let title = optionalText(statement, column: 1),
                    let summary = optionalText(statement, column: 2),
                    let family = BlockFamily(rawValue: text(statement, column: 3)),
                    let state = BlockState(rawValue: text(statement, column: 4))
                else {
                    throw SQLiteStoreError.corruptData("Bloque con valores desconocidos.")
                }

                let rawLayer = optionalText(statement, column: 5)
                let architectureLayer: ArchitectureLayer?
                if let rawLayer {
                    guard let parsedLayer = ArchitectureLayer(rawValue: rawLayer) else {
                        throw SQLiteStoreError.corruptData("Bloque con capa arquitectónica desconocida.")
                    }
                    architectureLayer = parsedLayer
                } else {
                    architectureLayer = nil
                }

                blocks.append(ProjectBlock(
                    id: id,
                    title: title,
                    summary: summary,
                    family: family,
                    state: state,
                    architectureLayer: architectureLayer,
                    position: BlockPosition(
                        x: sqlite3_column_double(statement, 6),
                        y: sqlite3_column_double(statement, 7)
                    ),
                    rowVersion: Int(sqlite3_column_int64(statement, 8))
                ))
            }
            return blocks
        }
    }

    private func loadRelations(projectID: UUID) throws -> [BlockRelation] {
        let sql = """
        SELECT id, source_id, target_id, source_port, target_port,
               relation_type, is_critical, row_version
        FROM relations
        WHERE project_id = ?
        ORDER BY rowid;
        """

        return try withStatement(sql) { statement in
            try bind(projectID.uuidString, to: 1, in: statement)
            var relations: [BlockRelation] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                guard
                    let id = UUID(uuidString: text(statement, column: 0)),
                    let sourceID = UUID(uuidString: text(statement, column: 1)),
                    let targetID = UUID(uuidString: text(statement, column: 2)),
                    let sourcePort = ConnectionPort(rawValue: text(statement, column: 3)),
                    let targetPort = ConnectionPort(rawValue: text(statement, column: 4)),
                    let type = RelationType(rawValue: text(statement, column: 5))
                else {
                    throw SQLiteStoreError.corruptData("Relación con valores desconocidos.")
                }

                relations.append(BlockRelation(
                    id: id,
                    sourceID: sourceID,
                    targetID: targetID,
                    sourcePort: sourcePort,
                    targetPort: targetPort,
                    type: type,
                    isCritical: sqlite3_column_int(statement, 6) == 1,
                    rowVersion: Int(sqlite3_column_int64(statement, 7))
                ))
            }
            return relations
        }
    }

    private func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorPointer) == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? databaseMessage
            sqlite3_free(errorPointer)
            throw SQLiteStoreError.executionFailed(message)
        }
    }

    private func withStatement<T>(
        _ sql: String,
        operation: (OpaquePointer) throws -> T
    ) throws -> T {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SQLiteStoreError.preparationFailed(databaseMessage)
        }
        defer { sqlite3_finalize(statement) }
        return try operation(statement)
    }

    private func bind(_ value: String, to index: Int32, in statement: OpaquePointer) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
            throw SQLiteStoreError.bindingFailed(databaseMessage)
        }
    }

    private func bind(_ value: String?, to index: Int32, in statement: OpaquePointer) throws {
        guard let value else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw SQLiteStoreError.bindingFailed(databaseMessage)
            }
            return
        }
        try bind(value, to: index, in: statement)
    }

    private func bind(_ value: Int64, to index: Int32, in statement: OpaquePointer) throws {
        guard sqlite3_bind_int64(statement, index, value) == SQLITE_OK else {
            throw SQLiteStoreError.bindingFailed(databaseMessage)
        }
    }

    private func bind(_ value: Double, to index: Int32, in statement: OpaquePointer) throws {
        guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
            throw SQLiteStoreError.bindingFailed(databaseMessage)
        }
    }

    private func requireDone(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.executionFailed(databaseMessage)
        }
    }

    private func text(_ statement: OpaquePointer, column: Int32) -> String {
        optionalText(statement, column: column) ?? ""
    }

    private func optionalText(_ statement: OpaquePointer, column: Int32) -> String? {
        guard let value = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: value)
    }

    private var databaseMessage: String {
        guard let database, let message = sqlite3_errmsg(database) else {
            return "Error SQLite desconocido."
        }
        return String(cString: message)
    }
}
