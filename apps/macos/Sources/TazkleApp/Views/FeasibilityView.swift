import SwiftUI
import TazkleDesignSystem
import TazkleDomain

struct FeasibilityView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    private var destinationID: String {
        appState.selectedDestinationID ?? "feasibility.summary"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
                ProjectSectionHeader(
                    title: appState.selectedDestination?.title ?? "Factibilidad",
                    subtitle: subtitle,
                    systemImage: "checkmark.seal",
                    accent: TazkleColors.warning,
                    trailingTitle: destinationID == "feasibility.summary" ? "Completar datos" : nil,
                    trailingAction: destinationID == "feasibility.summary" ? {
                        appState.presentPlanningProfile()
                    } : nil,
                    contextBadgeTitle: usesCalculatedData
                        ? "Cálculo local"
                        : "Escenario de prototipo",
                    contextBadgeSystemImage: usesCalculatedData
                        ? "externaldrive.badge.checkmark"
                        : "hammer",
                    contextBadgeHelp: usesCalculatedData
                        ? "Este resultado se calcula desde el grafo y el perfil guardado del proyecto."
                        : "Esta subvista todavía ilustra el flujo y no persiste sus acciones."
                )

                switch destinationID {
                case "feasibility.dimensions":
                    FeasibilityDimensionsView()
                case "feasibility.evidence":
                    FeasibilityEvidenceView()
                case "feasibility.assumptions":
                    FeasibilityAssumptionsView()
                case "feasibility.alternatives":
                    FeasibilityAlternativesView()
                case "feasibility.approval":
                    FeasibilityApprovalView()
                default:
                    FeasibilityDashboardView()
                }
            }
            .padding(TazkleSpacing.xLarge)
        }
        .background(
            TazkleColors.canvas(
                for: colorScheme,
                highContrast: highContrast
            )
        )
    }

    private var subtitle: String {
        switch destinationID {
        case "feasibility.dimensions": "Diez dimensiones evaluadas con estado, evidencia y confianza."
        case "feasibility.evidence": "Fuentes que respaldan la evaluación y vacíos que reducen su confianza."
        case "feasibility.assumptions": "Condiciones no verificadas que modifican costo, tiempo o riesgo."
        case "feasibility.alternatives": "Variantes comparables sin sobrescribir el plan original."
        case "feasibility.approval": "Puerta de revisión con responsable, condiciones y excepción documentada."
        default: "Conclusión, confianza y condiciones críticas antes de solicitar aprobación."
        }
    }

    private var usesCalculatedData: Bool {
        ["feasibility.summary", "feasibility.dimensions"].contains(destinationID)
    }
}

private struct FeasibilityDashboardView: View {
    @EnvironmentObject private var appState: AppState

    private var assessment: ProjectPlanningAssessment? {
        appState.planningAssessment
    }

    var body: some View {
        if let assessment {
            dashboard(for: assessment)
        } else {
            ContentUnavailableView(
                "Datos de planeación inválidos",
                systemImage: "exclamationmark.triangle",
                description: Text("Corrige los datos para volver a calcular la evaluación.")
            )
        }
    }

    private func dashboard(for assessment: ProjectPlanningAssessment) -> some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            Label(
                "Evaluación calculada desde el grafo y los datos guardados del proyecto",
                systemImage: "function"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(TazkleColors.assistantProposal)

            ProjectSectionCard(title: "Resultado actual", systemImage: "waveform.path.ecg") {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: TazkleSpacing.xLarge) {
                        viabilitySummary(assessment)
                        Divider().frame(height: 104)
                        confidenceSummary(assessment)
                        Divider().frame(height: 104)
                        analysisSummary
                    }
                    VStack(alignment: .leading, spacing: TazkleSpacing.large) {
                        viabilitySummary(assessment)
                        Divider()
                        confidenceSummary(assessment)
                        Divider()
                        analysisSummary
                    }
                }
            }

            LazyVGrid(
                columns: ProjectGridLayout.equalColumns(3, minimumWidth: 180),
                spacing: TazkleSpacing.medium
            ) {
                FeasibilityGateCard(
                    title: "Factibilidad económica",
                    dimension: dimension(.budget, in: assessment),
                    systemImage: "dollarsign.circle"
                )
                FeasibilityGateCard(
                    title: "Capacidad del equipo",
                    dimension: dimension(.teamCapacity, in: assessment),
                    systemImage: "person.2"
                )
                FeasibilityGateCard(
                    title: "Coherencia de arquitectura",
                    dimension: dimension(.technicalViability, in: assessment),
                    systemImage: "square.3.layers.3d"
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    dimensionsCard(assessment)
                    conditionsCard(assessment)
                }
                VStack(spacing: TazkleSpacing.medium) {
                    dimensionsCard(assessment)
                    conditionsCard(assessment)
                }
            }

            ProjectSectionCard(title: "Siguiente paso recomendado", systemImage: "arrow.forward.circle") {
                Text(recommendation(for: assessment))
                    .font(.callout)
                Text("El resultado aplica reglas transparentes. No aprueba el proyecto ni sustituye al responsable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func viabilitySummary(_ assessment: ProjectPlanningAssessment) -> some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            ProjectStatusPill(
                title: assessment.overall.displayName,
                systemImage: assessment.overall.systemImage,
                color: assessment.overall.color
            )
            Text(
                assessment.conditions.isEmpty
                    ? "No hay condiciones abiertas en la evaluación actual."
                    : "\(assessment.conditions.count) condiciones deben revisarse antes de aprobar."
            )
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func confidenceSummary(_ assessment: ProjectPlanningAssessment) -> some View {
        let supported = assessment.dimensions.count { $0.confidence != .low }
        return VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            Label("Confianza \(assessment.confidence.displayName.lowercased())", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundStyle(assessment.confidence.color)
            Text("\(supported) de 10 dimensiones tienen evidencia suficiente.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var analysisSummary: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            Label("Último análisis", systemImage: "calendar")
                .font(.headline)
            Text("Calculado en tiempo real · perfil local v\(appState.planningProfile.rowVersion)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dimensionsCard(_ assessment: ProjectPlanningAssessment) -> some View {
        ProjectSectionCard(title: "Dimensiones evaluadas", systemImage: "square.grid.2x2") {
            ForEach(assessment.dimensions.prefix(5)) { dimension in
                ProjectListRow {
                    Text(dimension.key.displayName)
                        .font(.callout)
                } trailing: {
                    ProjectStatusPill(
                        title: dimension.state.displayName,
                        systemImage: dimension.state.systemImage,
                        color: dimension.state.color
                    )
                }
            }
            Button("Ver las diez dimensiones") {
                appState.selectDestination(FeasibilityPrototype.destination("feasibility.dimensions"))
            }
            .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func conditionsCard(_ assessment: ProjectPlanningAssessment) -> some View {
        ProjectSectionCard(title: "Condiciones para aprobar", systemImage: "exclamationmark.triangle") {
            if assessment.conditions.isEmpty {
                Label("No hay condiciones abiertas", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(TazkleColors.success)
            } else {
                ForEach(Array(assessment.conditions.prefix(4).enumerated()), id: \.offset) { _, value in
                    condition(value)
                }
            }
            Divider()
            Label(
                "\(assessment.conditions.count) condiciones registradas",
                systemImage: "doc.badge.ellipsis"
            )
                .font(.callout)
                .foregroundStyle(TazkleColors.assistantProposal)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func condition(_ value: String) -> some View {
        Label(value, systemImage: "circle.fill")
            .font(.callout)
            .foregroundStyle(.secondary)
            .symbolRenderingMode(.hierarchical)
    }

    private func dimension(
        _ key: FeasibilityDimensionKey,
        in assessment: ProjectPlanningAssessment
    ) -> FeasibilityDimensionResult {
        assessment.dimensions.first { $0.key == key }
            ?? FeasibilityDimensionResult(
                key: key,
                state: .conditional,
                confidence: .low,
                finding: "No hay datos suficientes.",
                recommendation: "Completar los datos de planeación."
            )
    }

    private func recommendation(for assessment: ProjectPlanningAssessment) -> String {
        if let first = assessment.conditions.first {
            return first
        }
        return "El expediente puede pasar a revisión humana de factibilidad y presupuesto."
    }
}

private struct FeasibilityGateCard: View {
    let title: String
    let dimension: FeasibilityDimensionResult
    let systemImage: String

    var body: some View {
        ProjectSectionCard(title: title, systemImage: systemImage) {
            ProjectStatusPill(
                title: dimension.state.displayName,
                systemImage: dimension.state.systemImage,
                color: dimension.state.color
            )
            Text(dimension.finding)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FeasibilityDimensionsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var statusFilter = "Todas"
    @State private var selectedDimensionID = FeasibilityDimensionKey.technicalViability

    private var dimensions: [FeasibilityDimensionResult] {
        let all = appState.planningAssessment?.dimensions ?? []
        guard statusFilter != "Todas" else { return all }
        return all.filter { $0.state.displayName == statusFilter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.large) {
            HStack {
                Picker("Estado", selection: $statusFilter) {
                    Text("Todas").tag("Todas")
                    Text("Favorable").tag("Favorable")
                    Text("Con condiciones").tag("Con condiciones")
                    Text("Requiere replanteamiento").tag("Requiere replanteamiento")
                }
                .frame(maxWidth: 260)
                Spacer()
                Text("\(dimensions.count) dimensiones")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProjectSectionCard(title: "Evaluación por dimensión", systemImage: "list.number") {
                ForEach(dimensions) { dimension in
                    Button {
                        selectedDimensionID = dimension.id
                    } label: {
                        FeasibilityDimensionRow(
                            dimension: dimension,
                            isSelected: selectedDimensionID == dimension.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if let selected = appState.planningAssessment?.dimensions.first(where: { $0.id == selectedDimensionID }) {
                ProjectSectionCard(title: "Detalle: \(selected.key.displayName)", systemImage: "sidebar.right") {
                    Text(selected.finding)
                        .font(.callout)
                    HStack {
                        Label("Estado \(selected.state.displayName.lowercased())", systemImage: "doc.text")
                        Spacer()
                        Label("Confianza \(selected.confidence.displayName.lowercased())", systemImage: "chart.bar")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    Divider()
                    Label(selected.recommendation, systemImage: "arrow.forward.circle")
                        .font(.callout)
                }
            }
        }
    }
}

private struct FeasibilityDimensionRow: View {
    let dimension: FeasibilityDimensionResult
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: TazkleSpacing.medium) {
            Text(dimension.key.index.formatted())
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)

            VStack(alignment: .leading, spacing: 3) {
                Text(dimension.key.displayName)
                    .font(.callout.weight(.semibold))
                Text(dimension.finding)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text("Confianza \(dimension.confidence.displayName.lowercased())")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProjectStatusPill(
                title: dimension.state.displayName,
                systemImage: dimension.state.systemImage,
                color: dimension.state.color
            )
        }
        .padding(TazkleSpacing.medium)
        .background(
            isSelected
                ? TazkleColors.relationship.opacity(0.12)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.control))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(dimension.key.index). \(dimension.key.displayName), \(dimension.state.displayName)"
        )
        .accessibilityValue(dimension.finding)
    }
}

private struct FeasibilityEvidenceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            LazyVGrid(
                columns: ProjectGridLayout.equalColumns(3, minimumWidth: 180),
                spacing: TazkleSpacing.medium
            ) {
                ProjectMetricCard(title: "Fuentes registradas", value: "8", detail: "Documentos y decisiones", systemImage: "doc.on.doc", accent: TazkleColors.actionPrimary)
                ProjectMetricCard(title: "Con evidencia fuerte", value: "4", detail: "Dimensiones respaldadas", systemImage: "checkmark.seal", accent: TazkleColors.success)
                ProjectMetricCard(title: "Vacíos críticos", value: "3", detail: "Antes de solicitar aprobación", systemImage: "exclamationmark.triangle", accent: TazkleColors.warning)
            }

            ProjectSectionCard(title: "Registro de evidencias", systemImage: "doc.text.magnifyingglass") {
                ForEach(FeasibilityPrototype.evidence) { evidence in
                    ProjectListRow {
                        VStack(alignment: .leading, spacing: 3) {
                            Label(evidence.title, systemImage: evidence.systemImage)
                                .font(.callout.weight(.medium))
                            Text(evidence.supports)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } trailing: {
                        ProjectStatusPill(
                            title: evidence.strength,
                            systemImage: evidence.strength == "Fuerte" ? "checkmark.circle.fill" : "circle.lefthalf.filled",
                            color: evidence.strength == "Fuerte" ? TazkleColors.success : TazkleColors.warning
                        )
                    }
                }
            }
        }
    }
}

private struct FeasibilityAssumptionsView: View {
    @State private var showResolved = true

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.large) {
            Toggle("Mostrar supuestos resueltos", isOn: $showResolved)
                .toggleStyle(.switch)

            ForEach(FeasibilityPrototype.assumptions.filter { showResolved || !$0.resolved }) { assumption in
                ProjectSectionCard(title: assumption.title, systemImage: "text.bubble") {
                    HStack {
                        ProjectStatusPill(
                            title: assumption.resolved ? "Validado" : "Por confirmar",
                            systemImage: assumption.resolved ? "checkmark.circle.fill" : "questionmark.circle.fill",
                            color: assumption.resolved ? TazkleColors.success : TazkleColors.warning
                        )
                        Spacer()
                        Text(assumption.impact)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(assumption.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct FeasibilityAlternativesView: View {
    @State private var selected = "Servicios administrados"

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            Picker("Variante", selection: $selected) {
                Text("Arquitectura actual").tag("Arquitectura actual")
                Text("Servicios administrados").tag("Servicios administrados")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 520)

            LazyVGrid(
                columns: ProjectGridLayout.equalColumns(4),
                spacing: TazkleSpacing.medium
            ) {
                ProjectMetricCard(title: "Costo interno", value: selected == "Servicios administrados" ? "$610k" : "$655k", detail: "Rango base de demostración", systemImage: "dollarsign.circle", accent: TazkleColors.warning)
                ProjectMetricCard(title: "Tiempo", value: selected == "Servicios administrados" ? "14 sem" : "17 sem", detail: "Hasta primera producción", systemImage: "calendar", accent: TazkleColors.actionPrimary)
                ProjectMetricCard(title: "Riesgo técnico", value: selected == "Servicios administrados" ? "Medio" : "Alto", detail: "Dependencias críticas", systemImage: "exclamationmark.triangle", accent: TazkleColors.warning)
                ProjectMetricCard(title: "Operación", value: selected == "Servicios administrados" ? "Menor" : "Mayor", detail: "Capacidad especializada", systemImage: "gearshape.2", accent: TazkleColors.relationship)
            }

            ProjectSectionCard(title: "Diferencias principales", systemImage: "arrow.left.arrow.right") {
                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: TazkleSpacing.large) {
                        comparison("Autenticación", current: "Implementación propia", alternative: "Servicio administrado")
                        comparison("Base de datos", current: "Operación del equipo", alternative: "Copias y escalado administrados")
                        comparison("Costo periódico", current: "Más bajo al inicio", alternative: "Mayor, pero predecible")
                        comparison("Tiempo de entrega", current: "Más desarrollo", alternative: "Tres semanas menos")
                    }
                    .frame(minWidth: 680, alignment: .leading)
                }
            }
        }
    }

    private func comparison(_ name: String, current: String, alternative: String) -> some View {
        GridRow {
            Text(name).font(.callout.weight(.semibold))
            Text(current).font(.callout).foregroundStyle(.secondary)
            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
            Text(alternative).font(.callout).foregroundStyle(.secondary)
        }
        .padding(.vertical, TazkleSpacing.small)
    }
}

private struct FeasibilityApprovalView: View {
    @State private var economic = true
    @State private var capacity = false
    @State private var architecture = false
    @State private var reviewSent = false

    private var canSubmit: Bool {
        economic && capacity && architecture
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            ProjectSectionCard(title: "Puerta de aprobación", systemImage: "checkmark.shield") {
                Toggle("Factibilidad económica revisada", isOn: $economic)
                Toggle("Roles cubiertos sin sobrecarga no autorizada", isOn: $capacity)
                Toggle("Arquitectura coherente y riesgos críticos tratados", isOn: $architecture)
            }

            ProjectSectionCard(title: "Responsable de la decisión", systemImage: "person.crop.circle.badge.checkmark") {
                Label("Carlos Ruiz · Responsable técnico", systemImage: "person.crop.circle.fill")
                    .font(.headline)
                Text("La política del proyecto permite que el responsable final solicite la revisión después de que las tres verificaciones obligatorias estén satisfechas.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if reviewSent {
                Label("Solicitud preparada en el prototipo", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(TazkleColors.success)
                    .font(.headline)
            }

            Button("Enviar a revisión") {
                reviewSent = true
            }
            .buttonStyle(.borderedProminent)
            .tint(TazkleColors.relationship)
            .disabled(!canSubmit)
            .accessibilityHint(canSubmit ? "Prepara la solicitud de revisión" : "Completa las tres verificaciones obligatorias")
        }
    }
}

private enum FeasibilityStatus {
    case favorable
    case conditional
    case risky

    var title: String {
        switch self {
        case .favorable: "Favorable"
        case .conditional: "Con condiciones"
        case .risky: "Riesgoso"
        }
    }

    var systemImage: String {
        switch self {
        case .favorable: "checkmark.circle.fill"
        case .conditional: "exclamationmark.circle.fill"
        case .risky: "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .favorable: TazkleColors.success
        case .conditional: TazkleColors.warning
        case .risky: TazkleColors.critical
        }
    }
}

private struct FeasibilityDimension: Identifiable {
    let id = UUID()
    let index: Int
    let name: String
    let status: FeasibilityStatus
    let evidence: String
    let confidence: String
    let finding: String
}

private struct FeasibilityEvidence: Identifiable {
    let id = UUID()
    let title: String
    let supports: String
    let strength: String
    let systemImage: String
}

private struct FeasibilityAssumption: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let impact: String
    let resolved: Bool
}

private enum FeasibilityPrototype {
    static let dimensions = [
        FeasibilityDimension(index: 1, name: "Problema y objetivos", status: .favorable, evidence: "Fuerte", confidence: "Alta", finding: "El problema está definido y alineado con los objetivos del producto."),
        FeasibilityDimension(index: 2, name: "Alcance y complejidad", status: .favorable, evidence: "Fuerte", confidence: "Alta", finding: "El alcance inicial está delimitado; los cambios requieren control de versión."),
        FeasibilityDimension(index: 3, name: "Viabilidad técnica", status: .conditional, evidence: "Media", confidence: "Media", finding: "La solución es viable, pero exige validar rendimiento y recuperación."),
        FeasibilityDimension(index: 4, name: "Compatibilidad tecnológica", status: .conditional, evidence: "Media", confidence: "Media", finding: "Las integraciones son compatibles bajo los supuestos actuales."),
        FeasibilityDimension(index: 5, name: "Capacidad y experiencia", status: .conditional, evidence: "Media", confidence: "Media", finding: "Falta cubrir Diseño y eliminar una sobrecarga de Backend."),
        FeasibilityDimension(index: 6, name: "Tiempo disponible", status: .conditional, evidence: "Media", confidence: "Media", finding: "El calendario es alcanzable si se resuelven dependencias antes del sprint 2."),
        FeasibilityDimension(index: 7, name: "Presupuesto", status: .conditional, evidence: "Media", confidence: "Media", finding: "El presupuesto admite el escenario base con una reserva del 15%."),
        FeasibilityDimension(index: 8, name: "Riesgos y dependencias", status: .risky, evidence: "Débil", confidence: "Baja", finding: "Persisten dependencias críticas sin evidencia de mitigación."),
        FeasibilityDimension(index: 9, name: "Necesidad o mercado", status: .conditional, evidence: "Media", confidence: "Media", finding: "Existe necesidad aparente, pendiente de validar con evidencia del mercado."),
        FeasibilityDimension(index: 10, name: "Seguridad y cumplimiento", status: .favorable, evidence: "Fuerte", confidence: "Alta", finding: "La propuesta contempla controles base, auditoría y minimización de datos."),
    ]

    static let evidence = [
        FeasibilityEvidence(title: "Expediente de alcance v1", supports: "Problema, objetivos y alcance", strength: "Fuerte", systemImage: "doc.text"),
        FeasibilityEvidence(title: "Diagrama de arquitectura", supports: "Viabilidad y compatibilidad técnica", strength: "Media", systemImage: "square.3.layers.3d"),
        FeasibilityEvidence(title: "Matriz de capacidad", supports: "Equipo y tiempo disponible", strength: "Media", systemImage: "person.2"),
        FeasibilityEvidence(title: "Estimación de costos", supports: "Presupuesto y reserva", strength: "Media", systemImage: "dollarsign.circle"),
        FeasibilityEvidence(title: "Revisión de seguridad", supports: "Privacidad, controles y cumplimiento", strength: "Fuerte", systemImage: "lock.shield"),
    ]

    static let assumptions = [
        FeasibilityAssumption(title: "Volumen inicial moderado", detail: "La estimación supone hasta 25 000 personas activas al mes durante el primer año.", impact: "Costo e infraestructura", resolved: false),
        FeasibilityAssumption(title: "Equipo disponible desde el sprint 1", detail: "Las personas asignadas mantienen al menos el 70% de su capacidad prevista.", impact: "Tiempo", resolved: false),
        FeasibilityAssumption(title: "Proveedor de correo compatible", detail: "La API seleccionada cubre entrega transaccional y trazabilidad básica.", impact: "Tecnología", resolved: true),
        FeasibilityAssumption(title: "Sin migración histórica masiva", detail: "El primer release no incluye importar más de 100 000 registros heredados.", impact: "Alcance", resolved: true),
    ]

    static func destination(_ id: String) -> SectionDestination {
        AppSection.feasibility.contextualDestinations.first { $0.id == id }
            ?? AppSection.feasibility.contextualDestinations[0]
    }
}

private extension FeasibilityState {
    var systemImage: String {
        switch self {
        case .favorable: "checkmark.circle.fill"
        case .conditional: "exclamationmark.circle.fill"
        case .risky: "arrow.triangle.branch"
        }
    }

    var color: Color {
        switch self {
        case .favorable: TazkleColors.success
        case .conditional: TazkleColors.warning
        case .risky: TazkleColors.critical
        }
    }
}

private extension FeasibilityConfidence {
    var color: Color {
        switch self {
        case .high: TazkleColors.success
        case .medium: TazkleColors.warning
        case .low: TazkleColors.critical
        }
    }
}

private extension OverallFeasibility {
    var systemImage: String {
        switch self {
        case .viable: "checkmark.circle.fill"
        case .viableWithConditions: "exclamationmark.circle.fill"
        case .requiresReplanning: "arrow.triangle.branch"
        }
    }

    var color: Color {
        switch self {
        case .viable: TazkleColors.success
        case .viableWithConditions: TazkleColors.warning
        case .requiresReplanning: TazkleColors.critical
        }
    }
}
