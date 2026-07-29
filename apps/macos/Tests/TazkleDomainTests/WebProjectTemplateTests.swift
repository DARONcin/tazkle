import XCTest
@testable import TazkleDomain

final class WebProjectTemplateTests: XCTestCase {
    func testBuildsConnectedArchitectureFromSelectedTechnologies() throws {
        let technologies = WebTechnologySelection(
            frontend: .svelteKit,
            language: .go,
            api: .rest,
            authentication: .keycloak,
            database: .mysql,
            deployment: .docker
        )

        let graph = WebProjectTemplateFactory.make(
            name: "Portal operativo",
            technologies: technologies
        )

        try ProjectGraphValidator.validate(graph)
        XCTAssertEqual(graph.blocks.count, 6)
        XCTAssertEqual(graph.relations.count, 7)
        XCTAssertEqual(Set(graph.blocks.compactMap(\.architectureLayer)), Set(ArchitectureLayer.allCases))
        XCTAssertTrue(graph.blocks.contains { $0.title == "Frontend · SvelteKit" })
        XCTAssertTrue(graph.blocks.contains { $0.title == "Backend · Go" })
        XCTAssertTrue(graph.blocks.contains { $0.title == "Base de datos · MySQL" })
        XCTAssertTrue(graph.blocks.contains { $0.title == "Autenticación · Keycloak" })
        XCTAssertTrue(
            graph.blocks.allSatisfy { graph.relationshipCount(for: $0.id) > 0 },
            "La plantilla no debe producir servicios aislados."
        )
    }

    func testMarksIncompatibleTRPCBackendAsWarningWithoutDroppingThePlan() throws {
        let technologies = WebTechnologySelection(
            language: .python,
            api: .trpc
        )

        XCTAssertEqual(technologies.compatibilityWarnings.count, 1)

        let graph = WebProjectTemplateFactory.make(
            name: "Variante documentada",
            technologies: technologies
        )

        try ProjectGraphValidator.validate(graph)
        XCTAssertEqual(
            graph.blocks.first { $0.title == "API · tRPC" }?.state,
            .warning
        )
        XCTAssertTrue(graph.relations.contains { $0.isCritical })
    }

    func testDefaultTechnologySelectionHasNoCompatibilityWarnings() {
        XCTAssertTrue(WebTechnologySelection.defaultSelection.compatibilityWarnings.isEmpty)
    }
}
