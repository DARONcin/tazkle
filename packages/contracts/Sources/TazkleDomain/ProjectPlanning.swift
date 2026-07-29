import Foundation

public enum PlanningRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case product
    case technicalLead
    case design
    case development
    case quality
    case operations

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .product: "Producto"
        case .technicalLead: "Responsable técnico"
        case .design: "Diseño"
        case .development: "Desarrollo"
        case .quality: "QA"
        case .operations: "DevOps"
        }
    }
}

public struct RoleEstimate: Codable, Equatable, Identifiable, Sendable {
    public var role: PlanningRole
    public var plannedHours: Int
    public var hourlyRateMXN: Int

    public var id: PlanningRole { role }
    public var plannedCostMXN: Int { plannedHours * hourlyRateMXN }

    public init(
        role: PlanningRole,
        plannedHours: Int,
        hourlyRateMXN: Int
    ) {
        self.role = role
        self.plannedHours = plannedHours
        self.hourlyRateMXN = hourlyRateMXN
    }
}

public struct ProjectPlanningProfile: Codable, Equatable, Sendable {
    public let projectID: UUID
    public var problemStatement: String
    public var objective: String
    public var marketEvidence: String
    public var targetWeeks: Int
    public var teamWeeklyCapacityHours: Int
    public var availableBudgetMXN: Int
    public var fixedCostsMXN: Int
    public var monthlyServicesMXN: Int
    public var riskReservePercent: Int
    public var clientMarginPercent: Int
    public var roles: [RoleEstimate]
    public var rowVersion: Int

    public init(
        projectID: UUID,
        problemStatement: String = "",
        objective: String = "",
        marketEvidence: String = "",
        targetWeeks: Int = 12,
        teamWeeklyCapacityHours: Int = 80,
        availableBudgetMXN: Int = 0,
        fixedCostsMXN: Int = 0,
        monthlyServicesMXN: Int = 0,
        riskReservePercent: Int = 15,
        clientMarginPercent: Int = 25,
        roles: [RoleEstimate],
        rowVersion: Int = 1
    ) {
        self.projectID = projectID
        self.problemStatement = problemStatement
        self.objective = objective
        self.marketEvidence = marketEvidence
        self.targetWeeks = targetWeeks
        self.teamWeeklyCapacityHours = teamWeeklyCapacityHours
        self.availableBudgetMXN = availableBudgetMXN
        self.fixedCostsMXN = fixedCostsMXN
        self.monthlyServicesMXN = monthlyServicesMXN
        self.riskReservePercent = riskReservePercent
        self.clientMarginPercent = clientMarginPercent
        self.roles = roles
        self.rowVersion = rowVersion
    }

    public static func defaultProfile(for graph: ProjectGraph) -> ProjectPlanningProfile {
        let scopeUnits = max(graph.blocks.count, 1)
        let technicalUnits = max(
            graph.blocks.count { $0.family == .technology },
            1
        )

        return ProjectPlanningProfile(
            projectID: graph.id,
            roles: [
                RoleEstimate(
                    role: .product,
                    plannedHours: 32 + scopeUnits * 4,
                    hourlyRateMXN: 800
                ),
                RoleEstimate(
                    role: .technicalLead,
                    plannedHours: 40 + technicalUnits * 8,
                    hourlyRateMXN: 1_200
                ),
                RoleEstimate(
                    role: .design,
                    plannedHours: 48 + scopeUnits * 6,
                    hourlyRateMXN: 900
                ),
                RoleEstimate(
                    role: .development,
                    plannedHours: 80 + scopeUnits * 20,
                    hourlyRateMXN: 850
                ),
                RoleEstimate(
                    role: .quality,
                    plannedHours: 32 + scopeUnits * 8,
                    hourlyRateMXN: 700
                ),
                RoleEstimate(
                    role: .operations,
                    plannedHours: 24 + technicalUnits * 6,
                    hourlyRateMXN: 1_100
                ),
            ]
        )
    }

    public mutating func prepareForSave() {
        problemStatement = PlanningValidator.sanitizedMultiline(problemStatement, limit: 1_500)
        objective = PlanningValidator.sanitizedMultiline(objective, limit: 1_000)
        marketEvidence = PlanningValidator.sanitizedMultiline(marketEvidence, limit: 1_500)
        rowVersion += 1
    }
}

public enum PlanningValidationError: Error, LocalizedError, Equatable {
    case projectMismatch
    case invalidDuration
    case invalidCapacity
    case invalidBudget
    case invalidCosts
    case invalidReserve
    case invalidMargin
    case incompleteRoles
    case duplicateRole
    case invalidRoleEstimate
    case invalidVersion

    public var errorDescription: String? {
        switch self {
        case .projectMismatch: "Los datos de planeación no pertenecen al proyecto actual."
        case .invalidDuration: "La duración debe estar entre 1 y 260 semanas."
        case .invalidCapacity: "La capacidad semanal debe estar entre 1 y 10 000 horas."
        case .invalidBudget: "El presupuesto no puede ser negativo."
        case .invalidCosts: "Los costos fijos y periódicos no pueden ser negativos."
        case .invalidReserve: "La reserva de riesgo debe estar entre 0% y 100%."
        case .invalidMargin: "El margen debe estar entre 0% y 90%."
        case .incompleteRoles: "La estimación debe incluir todos los roles base."
        case .duplicateRole: "Un rol no puede aparecer más de una vez."
        case .invalidRoleEstimate: "Las horas y tarifas deben ser valores válidos y no negativos."
        case .invalidVersion: "La versión de los datos de planeación no es válida."
        }
    }
}

public enum PlanningValidator {
    public static func validate(
        _ profile: ProjectPlanningProfile,
        projectID: UUID? = nil
    ) throws {
        if let projectID, profile.projectID != projectID {
            throw PlanningValidationError.projectMismatch
        }
        guard (1...260).contains(profile.targetWeeks) else {
            throw PlanningValidationError.invalidDuration
        }
        guard (1...10_000).contains(profile.teamWeeklyCapacityHours) else {
            throw PlanningValidationError.invalidCapacity
        }
        guard profile.availableBudgetMXN >= 0 else {
            throw PlanningValidationError.invalidBudget
        }
        guard profile.fixedCostsMXN >= 0, profile.monthlyServicesMXN >= 0 else {
            throw PlanningValidationError.invalidCosts
        }
        guard (0...100).contains(profile.riskReservePercent) else {
            throw PlanningValidationError.invalidReserve
        }
        guard (0...90).contains(profile.clientMarginPercent) else {
            throw PlanningValidationError.invalidMargin
        }
        guard profile.roles.count == PlanningRole.allCases.count else {
            throw PlanningValidationError.incompleteRoles
        }
        guard Set(profile.roles.map(\.role)).count == profile.roles.count else {
            throw PlanningValidationError.duplicateRole
        }
        guard Set(profile.roles.map(\.role)) == Set(PlanningRole.allCases) else {
            throw PlanningValidationError.incompleteRoles
        }
        guard profile.roles.allSatisfy({
            (0...100_000).contains($0.plannedHours)
                && (0...1_000_000).contains($0.hourlyRateMXN)
        }) else {
            throw PlanningValidationError.invalidRoleEstimate
        }
        guard profile.rowVersion > 0 else {
            throw PlanningValidationError.invalidVersion
        }
    }

    public static func sanitizedMultiline(_ value: String, limit: Int) -> String {
        let filtered = value.unicodeScalars.filter {
            $0 == "\n" || $0 == "\t" || !CharacterSet.controlCharacters.contains($0)
        }
        return String(String.UnicodeScalarView(filtered))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(limit)
            .description
    }
}

public enum FeasibilityState: String, Codable, CaseIterable, Sendable {
    case favorable
    case conditional
    case risky

    public var displayName: String {
        switch self {
        case .favorable: "Favorable"
        case .conditional: "Con condiciones"
        case .risky: "Requiere replanteamiento"
        }
    }
}

public enum FeasibilityConfidence: String, Codable, Sendable {
    case low
    case medium
    case high

    public var displayName: String {
        switch self {
        case .low: "Baja"
        case .medium: "Media"
        case .high: "Alta"
        }
    }
}

public enum FeasibilityDimensionKey: String, Codable, CaseIterable, Identifiable, Sendable {
    case problemAndObjectives
    case scopeAndComplexity
    case technicalViability
    case technologyCompatibility
    case teamCapacity
    case availableTime
    case budget
    case risksAndDependencies
    case marketEvidence
    case securityAndCompliance

    public var id: String { rawValue }

    public var index: Int {
        (Self.allCases.firstIndex(of: self) ?? 0) + 1
    }

    public var displayName: String {
        switch self {
        case .problemAndObjectives: "Problema y objetivos"
        case .scopeAndComplexity: "Alcance y complejidad"
        case .technicalViability: "Viabilidad técnica"
        case .technologyCompatibility: "Compatibilidad tecnológica"
        case .teamCapacity: "Capacidad y experiencia"
        case .availableTime: "Tiempo disponible"
        case .budget: "Presupuesto"
        case .risksAndDependencies: "Riesgos y dependencias"
        case .marketEvidence: "Necesidad o mercado"
        case .securityAndCompliance: "Seguridad y cumplimiento"
        }
    }
}

public struct FeasibilityDimensionResult: Identifiable, Equatable, Sendable {
    public let key: FeasibilityDimensionKey
    public let state: FeasibilityState
    public let confidence: FeasibilityConfidence
    public let finding: String
    public let recommendation: String

    public var id: FeasibilityDimensionKey { key }

    public init(
        key: FeasibilityDimensionKey,
        state: FeasibilityState,
        confidence: FeasibilityConfidence,
        finding: String,
        recommendation: String
    ) {
        self.key = key
        self.state = state
        self.confidence = confidence
        self.finding = finding
        self.recommendation = recommendation
    }
}

public enum OverallFeasibility: String, Sendable {
    case viable
    case viableWithConditions
    case requiresReplanning

    public var displayName: String {
        switch self {
        case .viable: "Viable"
        case .viableWithConditions: "Viable con condiciones"
        case .requiresReplanning: "Requiere replanteamiento"
        }
    }
}

public struct MoneyRange: Equatable, Sendable {
    public let lowerBound: Int
    public let upperBound: Int
}

public struct ProjectPlanningAssessment: Equatable, Sendable {
    public let totalHours: Int
    public let laborCostMXN: Int
    public let serviceCostMXN: Int
    public let reserveMXN: Int
    public let internalCost: MoneyRange
    public let clientPrice: MoneyRange
    public let weeklyHoursRequired: Int
    public let overall: OverallFeasibility
    public let confidence: FeasibilityConfidence
    public let dimensions: [FeasibilityDimensionResult]

    public var conditions: [String] {
        dimensions
            .filter { $0.state != .favorable }
            .map(\.recommendation)
    }
}

public enum ProjectPlanningEngine {
    public static func assess(
        graph: ProjectGraph,
        profile: ProjectPlanningProfile
    ) throws -> ProjectPlanningAssessment {
        try ProjectGraphValidator.validate(graph)
        try PlanningValidator.validate(profile, projectID: graph.id)

        let totalHours = profile.roles.reduce(0) { $0 + $1.plannedHours }
        let laborCost = profile.roles.reduce(0) { $0 + $1.plannedCostMXN }
        let projectMonths = max(1, Int(ceil(Double(profile.targetWeeks) / 4)))
        let serviceCost = profile.fixedCostsMXN + profile.monthlyServicesMXN * projectMonths
        let subtotal = laborCost + serviceCost
        let reserve = percentage(of: subtotal, percent: profile.riskReservePercent)
        let internalBase = subtotal + reserve

        let missingBriefFields = [
            profile.problemStatement,
            profile.objective,
            profile.marketEvidence,
        ].count { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let warnings = graph.blocks.count { $0.state == .warning }
        let criticalRelations = graph.relations.count { $0.isCritical }
        let uncertainty = min(
            35,
            10 + missingBriefFields * 4 + warnings * 2 + criticalRelations * 2
        )
        let internalHigh = internalBase + percentage(of: internalBase, percent: uncertainty)
        let clientLow = price(for: internalBase, marginPercent: profile.clientMarginPercent)
        let clientHigh = price(for: internalHigh, marginPercent: profile.clientMarginPercent)
        let weeklyHoursRequired = Int(
            ceil(Double(totalHours) / Double(profile.targetWeeks))
        )

        let dimensions = makeDimensions(
            graph: graph,
            profile: profile,
            weeklyHoursRequired: weeklyHoursRequired,
            internalCost: MoneyRange(lowerBound: internalBase, upperBound: internalHigh)
        )
        let riskyCount = dimensions.count { $0.state == .risky }
        let conditionalCount = dimensions.count { $0.state == .conditional }
        let overall: OverallFeasibility
        if riskyCount >= 3 {
            overall = .requiresReplanning
        } else if riskyCount == 0, conditionalCount <= 2 {
            overall = .viable
        } else {
            overall = .viableWithConditions
        }

        let highConfidenceCount = dimensions.count { $0.confidence == .high }
        let mediumConfidenceCount = dimensions.count { $0.confidence == .medium }
        let confidence: FeasibilityConfidence
        if highConfidenceCount >= 7 {
            confidence = .high
        } else if highConfidenceCount + mediumConfidenceCount >= 6 {
            confidence = .medium
        } else {
            confidence = .low
        }

        return ProjectPlanningAssessment(
            totalHours: totalHours,
            laborCostMXN: laborCost,
            serviceCostMXN: serviceCost,
            reserveMXN: reserve,
            internalCost: MoneyRange(lowerBound: internalBase, upperBound: internalHigh),
            clientPrice: MoneyRange(lowerBound: clientLow, upperBound: clientHigh),
            weeklyHoursRequired: weeklyHoursRequired,
            overall: overall,
            confidence: confidence,
            dimensions: dimensions
        )
    }

    private static func makeDimensions(
        graph: ProjectGraph,
        profile: ProjectPlanningProfile,
        weeklyHoursRequired: Int,
        internalCost: MoneyRange
    ) -> [FeasibilityDimensionResult] {
        let hasProblem = !profile.problemStatement.isEmpty
        let hasObjective = !profile.objective.isEmpty
        let problemState: FeasibilityState = hasProblem && hasObjective
            ? .favorable
            : (hasProblem || hasObjective ? .conditional : .risky)

        let architectureLayers = Set(graph.blocks.compactMap(\.architectureLayer)).count
        let orphanTechnologyCount = graph.blocks.count {
            $0.family == .technology && graph.relationshipCount(for: $0.id) == 0
        }
        let warningCount = graph.blocks.count { $0.state == .warning }
        let criticalCount = graph.relations.count { $0.isCritical }
        let capacityRatio = Double(weeklyHoursRequired)
            / Double(max(profile.teamWeeklyCapacityHours, 1))

        let scopeState: FeasibilityState = graph.blocks.isEmpty
            ? .risky
            : (graph.blocks.count >= 4 && !graph.relations.isEmpty ? .favorable : .conditional)
        let technicalState: FeasibilityState = architectureLayers >= 3 && orphanTechnologyCount == 0
            ? .favorable
            : (architectureLayers >= 2 ? .conditional : .risky)
        let compatibilityState: FeasibilityState = warningCount == 0
            ? .favorable
            : (warningCount <= 2 ? .conditional : .risky)
        let capacityState: FeasibilityState = capacityRatio <= 1
            ? .favorable
            : (capacityRatio <= 1.15 ? .conditional : .risky)
        let timeState: FeasibilityState = capacityRatio <= 0.9
            ? .favorable
            : (capacityRatio <= 1.15 ? .conditional : .risky)
        let budgetState: FeasibilityState
        if profile.availableBudgetMXN == 0 {
            budgetState = .conditional
        } else if profile.availableBudgetMXN >= internalCost.upperBound {
            budgetState = .favorable
        } else if profile.availableBudgetMXN >= internalCost.lowerBound {
            budgetState = .conditional
        } else {
            budgetState = .risky
        }
        let riskState: FeasibilityState = criticalCount == 0
            ? .favorable
            : (criticalCount <= 2 ? .conditional : .risky)
        let marketState: FeasibilityState = profile.marketEvidence.isEmpty
            ? .conditional
            : .favorable
        let hasSecuritySignal = graph.blocks.contains {
            $0.family == .governance
                || $0.title.localizedCaseInsensitiveContains("auth")
                || $0.title.localizedCaseInsensitiveContains("seguridad")
        }
        let securityState: FeasibilityState = hasSecuritySignal ? .favorable : .conditional

        return [
            result(
                .problemAndObjectives,
                state: problemState,
                finding: problemState == .favorable
                    ? "El problema y el objetivo están registrados."
                    : "Falta precisar el problema o el resultado que debe lograr el producto.",
                recommendation: "Completar y validar el problema y el objetivo con el responsable de producto."
            ),
            result(
                .scopeAndComplexity,
                state: scopeState,
                finding: "\(graph.blocks.count) bloques y \(graph.relations.count) relaciones delimitan el alcance actual.",
                recommendation: "Agregar los módulos y dependencias mínimas que todavía no están representados."
            ),
            result(
                .technicalViability,
                state: technicalState,
                finding: "La arquitectura cubre \(architectureLayers) de 4 capas y tiene \(orphanTechnologyCount) componentes aislados.",
                recommendation: "Cubrir al menos experiencia, servicios y datos, y conectar cada componente técnico."
            ),
            result(
                .technologyCompatibility,
                state: compatibilityState,
                finding: warningCount == 0
                    ? "No existen discrepancias tecnológicas registradas."
                    : "Existen \(warningCount) componentes con advertencia.",
                recommendation: "Documentar o resolver las discrepancias tecnológicas antes de aprobar."
            ),
            result(
                .teamCapacity,
                state: capacityState,
                finding: "Se requieren \(weeklyHoursRequired) h/sem frente a \(profile.teamWeeklyCapacityHours) h/sem disponibles.",
                recommendation: "Aumentar capacidad, reducir alcance o extender el calendario para evitar sobrecarga."
            ),
            result(
                .availableTime,
                state: timeState,
                finding: "El escenario considera \(profile.targetWeeks) semanas con la carga estimada actual.",
                recommendation: "Ajustar plazo o esfuerzo hasta que la carga semanal quede dentro de la capacidad."
            ),
            result(
                .budget,
                state: budgetState,
                confidence: profile.availableBudgetMXN == 0 ? .low : .high,
                finding: profile.availableBudgetMXN == 0
                    ? "El presupuesto disponible todavía no está definido."
                    : "El presupuesto disponible se compara contra el rango interno calculado.",
                recommendation: "Confirmar un presupuesto que cubra costo interno y reserva de riesgo."
            ),
            result(
                .risksAndDependencies,
                state: riskState,
                finding: criticalCount == 0
                    ? "No hay relaciones críticas sin tratar."
                    : "Existen \(criticalCount) relaciones marcadas como críticas.",
                recommendation: "Asignar una mitigación y un responsable a cada dependencia crítica."
            ),
            result(
                .marketEvidence,
                state: marketState,
                confidence: profile.marketEvidence.isEmpty ? .low : .high,
                finding: profile.marketEvidence.isEmpty
                    ? "No existe un resultado de análisis de mercado registrado."
                    : "El expediente contiene evidencia resumida de necesidad o mercado.",
                recommendation: "Registrar el resultado del análisis de mercado y la evidencia que lo respalda."
            ),
            result(
                .securityAndCompliance,
                state: securityState,
                finding: hasSecuritySignal
                    ? "El grafo incluye al menos un control o componente relacionado con seguridad."
                    : "El alcance no representa controles de seguridad o gobierno.",
                recommendation: "Agregar autenticación, privacidad, auditoría o cumplimiento según los datos tratados."
            ),
        ]
    }

    private static func result(
        _ key: FeasibilityDimensionKey,
        state: FeasibilityState,
        confidence: FeasibilityConfidence? = nil,
        finding: String,
        recommendation: String
    ) -> FeasibilityDimensionResult {
        FeasibilityDimensionResult(
            key: key,
            state: state,
            confidence: confidence ?? (state == .favorable ? .high : .medium),
            finding: finding,
            recommendation: recommendation
        )
    }

    private static func percentage(of value: Int, percent: Int) -> Int {
        Int((Double(value) * Double(percent) / 100).rounded())
    }

    private static func price(for cost: Int, marginPercent: Int) -> Int {
        guard marginPercent < 100 else { return cost }
        return Int(
            ceil(Double(cost) / (1 - Double(marginPercent) / 100))
        )
    }
}
