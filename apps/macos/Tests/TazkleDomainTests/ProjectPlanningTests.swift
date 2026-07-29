import XCTest
@testable import TazkleDomain

final class ProjectPlanningTests: XCTestCase {
    func testCalculatesHoursCostsReserveAndClientPriceFromRoles() throws {
        let graph = WebProjectTemplateFactory.make(name: "Portal")
        var profile = ProjectPlanningProfile.defaultProfile(for: graph)
        profile.roles = PlanningRole.allCases.map {
            RoleEstimate(role: $0, plannedHours: 100, hourlyRateMXN: 1_000)
        }
        profile.targetWeeks = 12
        profile.teamWeeklyCapacityHours = 60
        profile.fixedCostsMXN = 30_000
        profile.monthlyServicesMXN = 10_000
        profile.riskReservePercent = 10
        profile.clientMarginPercent = 20

        let assessment = try ProjectPlanningEngine.assess(
            graph: graph,
            profile: profile
        )

        XCTAssertEqual(assessment.totalHours, 600)
        XCTAssertEqual(assessment.laborCostMXN, 600_000)
        XCTAssertEqual(assessment.serviceCostMXN, 60_000)
        XCTAssertEqual(assessment.reserveMXN, 66_000)
        XCTAssertEqual(assessment.internalCost.lowerBound, 726_000)
        XCTAssertEqual(assessment.clientPrice.lowerBound, 907_500)
        XCTAssertEqual(assessment.weeklyHoursRequired, 50)
    }

    func testMissingEvidenceProducesConditionsAndExplicitLowConfidence() throws {
        let graph = ProjectGraph(name: "Idea")
        let profile = ProjectPlanningProfile.defaultProfile(for: graph)

        let assessment = try ProjectPlanningEngine.assess(
            graph: graph,
            profile: profile
        )

        XCTAssertNotEqual(assessment.overall, .viable)
        XCTAssertFalse(assessment.conditions.isEmpty)
        XCTAssertEqual(
            assessment.dimensions.first { $0.key == .marketEvidence }?.confidence,
            .low
        )
        XCTAssertEqual(
            assessment.dimensions.first { $0.key == .problemAndObjectives }?.state,
            .risky
        )
    }

    func testBudgetAndCapacityCanRequireReplanningWithoutBlockingAssessment() throws {
        let graph = WebProjectTemplateFactory.make(name: "Portal")
        var profile = ProjectPlanningProfile.defaultProfile(for: graph)
        profile.availableBudgetMXN = 1
        profile.teamWeeklyCapacityHours = 1
        profile.targetWeeks = 1

        let assessment = try ProjectPlanningEngine.assess(
            graph: graph,
            profile: profile
        )

        XCTAssertEqual(assessment.overall, .requiresReplanning)
        XCTAssertEqual(
            assessment.dimensions.first { $0.key == .budget }?.state,
            .risky
        )
        XCTAssertEqual(
            assessment.dimensions.first { $0.key == .teamCapacity }?.state,
            .risky
        )
        XCTAssertFalse(assessment.conditions.isEmpty)
    }

    func testRejectsDuplicateRoles() {
        let graph = ProjectGraph(name: "Duplicado")
        var profile = ProjectPlanningProfile.defaultProfile(for: graph)
        profile.roles[1].role = profile.roles[0].role

        XCTAssertThrowsError(try PlanningValidator.validate(profile)) { error in
            XCTAssertEqual(error as? PlanningValidationError, .duplicateRole)
        }
    }

    func testSanitizesControlCharactersBeforeSave() {
        let graph = ProjectGraph(name: "Seguro")
        var profile = ProjectPlanningProfile.defaultProfile(for: graph)
        profile.problemStatement = "Problema\u{0000}\nvisible"

        profile.prepareForSave()

        XCTAssertEqual(profile.problemStatement, "Problema\nvisible")
        XCTAssertEqual(profile.rowVersion, 2)
    }
}
