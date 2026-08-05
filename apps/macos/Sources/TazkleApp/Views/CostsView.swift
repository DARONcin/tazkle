import SwiftUI
import TazkleDesignSystem
import TazkleDomain

struct CostsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    private var destinationID: String {
        appState.selectedDestinationID ?? "costs.summary"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
                ProjectSectionHeader(
                    title: appState.selectedDestination?.title ?? "Costos",
                    subtitle: subtitle,
                    systemImage: "dollarsign.circle",
                    accent: TazkleColors.warning,
                    trailingTitle: destinationID == "costs.summary" ? "Preparar propuesta" : nil,
                    trailingAction: destinationID == "costs.summary" ? {
                        appState.selectDestination(CostPrototype.destination("costs.proposal"))
                    } : nil,
                    contextBadgeTitle: usesPersistedData
                        ? "Cálculo local"
                        : "Escenario de prototipo",
                    contextBadgeSystemImage: usesPersistedData
                        ? "externaldrive.badge.checkmark"
                        : "hammer",
                    contextBadgeHelp: usesPersistedData
                        ? "Estos valores proceden del perfil local guardado del proyecto."
                        : "Esta subvista todavía ilustra el flujo y no persiste sus acciones."
                )

                Label(dataStatusTitle, systemImage: dataStatusImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        usesPersistedData
                            ? TazkleColors.assistantProposal
                            : TazkleColors.warning
                    )

                switch destinationID {
                case "costs.roles":
                    CostsByRoleView()
                case "costs.modules":
                    CostsByModuleView()
                case "costs.services":
                    CostsServicesView()
                case "costs.history":
                    CostsHistoryView()
                case "costs.proposal":
                    CostsProposalView()
                default:
                    CostsDashboardView()
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
        case "costs.roles": "Horas, tarifas y variación por responsabilidad."
        case "costs.modules": "Costo atribuible a cada módulo del alcance."
        case "costs.services": "Licencias, infraestructura y servicios periódicos."
        case "costs.history": "Cambios del presupuesto con causa, versión y responsable."
        case "costs.proposal": "Precio al cliente separado del costo interno y del margen."
        default: "Rangos y confianza primero; el detalle permanece en subvistas."
        }
    }

    private var usesPersistedData: Bool {
        ["costs.summary", "costs.roles", "costs.proposal"].contains(destinationID)
    }

    private var dataStatusTitle: String {
        if usesPersistedData {
            return "Cálculo local persistido · requiere revisión del responsable"
        }
        return "Escenario visual pendiente de conectar al modelo de costos"
    }

    private var dataStatusImage: String {
        usesPersistedData ? "externaldrive.badge.checkmark" : "exclamationmark.shield"
    }
}

private struct CostsDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var scenario = "Base"

    var body: some View {
        if let assessment = appState.planningAssessment {
            dashboard(for: assessment)
        } else {
            ContentUnavailableView(
                "No se puede calcular la cotización",
                systemImage: "exclamationmark.triangle",
                description: Text("Corrige los datos de planeación para continuar.")
            )
        }
    }

    private func dashboard(for assessment: ProjectPlanningAssessment) -> some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            LazyVGrid(
                columns: ProjectGridLayout.equalColumns(4),
                spacing: TazkleSpacing.medium
            ) {
                ProjectMetricCard(
                    title: "Costo interno",
                    value: compactRange(assessment.internalCost),
                    detail: "MXN · incluye reserva",
                    systemImage: "building.columns",
                    accent: TazkleColors.warning
                )
                ProjectMetricCard(
                    title: "Precio propuesto",
                    value: compactRange(assessment.clientPrice),
                    detail: "MXN · antes de impuestos",
                    systemImage: "tag",
                    accent: TazkleColors.relationship
                )
                ProjectMetricCard(
                    title: "Margen configurado",
                    value: "\(appState.planningProfile.clientMarginPercent)%",
                    detail: "Separado del costo interno",
                    systemImage: "chart.line.uptrend.xyaxis",
                    accent: TazkleColors.success
                )
                ProjectMetricCard(
                    title: "Reserva de riesgo",
                    value: money(assessment.reserveMXN),
                    detail: "\(appState.planningProfile.riskReservePercent)% del subtotal",
                    systemImage: "shield",
                    accent: TazkleColors.warning
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    scenarioCard(assessment)
                    compositionCard(assessment)
                }
                VStack(spacing: TazkleSpacing.medium) {
                    scenarioCard(assessment)
                    compositionCard(assessment)
                }
            }

            ProjectSectionCard(title: "Supuestos que requieren atención", systemImage: "exclamationmark.triangle") {
                if assessment.conditions.isEmpty {
                    Label("No hay condiciones abiertas", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(TazkleColors.success)
                }
                ForEach(Array(assessment.conditions.prefix(4).enumerated()), id: \.offset) { index, condition in
                    ProjectListRow {
                        Text(condition)
                            .font(.callout)
                    } trailing: {
                        ProjectStatusPill(
                            title: "Condición \(index + 1)",
                            systemImage: "exclamationmark.circle.fill",
                            color: TazkleColors.warning
                        )
                    }
                }
            }

            HStack {
                Spacer()
                Button("Editar datos y supuestos") {
                    appState.presentPlanningProfile()
                }
                .buttonStyle(.borderedProminent)
                .tint(TazkleColors.relationship)
            }
        }
    }

    private func scenarioCard(_ assessment: ProjectPlanningAssessment) -> some View {
        ProjectSectionCard(title: "Escenarios de costo", systemImage: "slider.horizontal.3") {
            Picker("Escenario", selection: $scenario) {
                Text("Interno bajo").tag("Bajo")
                Text("Interno base").tag("Base")
                Text("Interno alto").tag("Alto")
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            let selectedValue: Int = switch scenario {
            case "Bajo": assessment.internalCost.lowerBound
            case "Alto": assessment.internalCost.upperBound
            default:
                (assessment.internalCost.lowerBound + assessment.internalCost.upperBound) / 2
            }
            VStack(alignment: .leading, spacing: TazkleSpacing.small) {
                Text(money(selectedValue))
                    .font(.largeTitle.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(
                        scenario == "Alto"
                            ? TazkleColors.warning
                            : TazkleColors.relationship
                    )
                Text("Rango calculado con horas, tarifas, servicios, reserva e incertidumbre.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("Revisar desglose por rol") {
                appState.selectDestination(CostPrototype.destination("costs.roles"))
            }
            .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func compositionCard(_ assessment: ProjectPlanningAssessment) -> some View {
        let total = max(
            assessment.laborCostMXN
                + assessment.serviceCostMXN
                + assessment.reserveMXN,
            1
        )
        return ProjectSectionCard(title: "Composición estimada", systemImage: "chart.bar.xaxis") {
            ProjectProgressRow(
                title: "Personal",
                detail: money(assessment.laborCostMXN),
                value: Double(assessment.laborCostMXN) / Double(total),
                color: TazkleColors.warning
            )
            ProjectProgressRow(
                title: "Servicios y costos fijos",
                detail: money(assessment.serviceCostMXN),
                value: Double(assessment.serviceCostMXN) / Double(total),
                color: TazkleColors.relationship
            )
            ProjectProgressRow(
                title: "Reserva de riesgo",
                detail: money(assessment.reserveMXN),
                value: Double(assessment.reserveMXN) / Double(total),
                color: TazkleColors.assistantProposal
            )
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func compactRange(_ range: MoneyRange) -> String {
        "\(compactMoney(range.lowerBound))–\(compactMoney(range.upperBound))"
    }

    private func compactMoney(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "$%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "$%.0fk", Double(value) / 1_000)
        }
        return "$\(value)"
    }

    private func money(_ value: Int) -> String {
        value.formatted(.currency(code: "MXN").precision(.fractionLength(0)))
    }
}

private struct CostsByRoleView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedRole = PlanningRole.development

    var body: some View {
        let roles = appState.planningProfile.roles
        let assessment = appState.planningAssessment

        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            LazyVGrid(
                columns: ProjectGridLayout.equalColumns(3),
                spacing: TazkleSpacing.medium
            ) {
                ProjectMetricCard(
                    title: "Costo de personal",
                    value: money(assessment?.laborCostMXN ?? 0),
                    detail: "Suma de horas por tarifa",
                    systemImage: "person.2",
                    accent: TazkleColors.warning
                )
                ProjectMetricCard(
                    title: "Horas planeadas",
                    value: "\(assessment?.totalHours ?? 0) h",
                    detail: "\(assessment?.weeklyHoursRequired ?? 0) h por semana",
                    systemImage: "clock",
                    accent: TazkleColors.actionPrimary
                )
                ProjectMetricCard(
                    title: "Capacidad disponible",
                    value: "\(appState.planningProfile.teamWeeklyCapacityHours) h/sem",
                    detail: "Declarada por el equipo",
                    systemImage: "gauge.with.dots.needle.50percent",
                    accent: TazkleColors.success
                )
            }

            ProjectSectionCard(title: "Estimación por rol", systemImage: "person.2") {
                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: TazkleSpacing.xLarge, verticalSpacing: 0) {
                        GridRow {
                            heading("Rol")
                            heading("Horas planeadas")
                            heading("Tarifa")
                            heading("Subtotal")
                        }
                        Divider().gridCellColumns(4)
                        ForEach(roles) { role in
                            GridRow {
                                Button(role.role.displayName) { selectedRole = role.role }
                                    .buttonStyle(.plain)
                                    .fontWeight(selectedRole == role.role ? .semibold : .regular)
                                Text("\(role.plannedHours) h")
                                    .monospacedDigit()
                                Text("\(money(role.hourlyRateMXN))/h")
                                    .monospacedDigit()
                                Text(money(role.plannedCostMXN))
                                    .monospacedDigit()
                            }
                            .font(.callout)
                            .padding(.vertical, TazkleSpacing.medium)
                            Divider().gridCellColumns(4)
                        }
                    }
                    .frame(minWidth: 700, alignment: .leading)
                }
            }

            if let role = roles.first(where: { $0.role == selectedRole }) {
                ProjectSectionCard(title: "Detalle de \(role.role.displayName)", systemImage: "sidebar.right") {
                    HStack {
                        Label("\(money(role.hourlyRateMXN))/h", systemImage: "banknote")
                        Spacer()
                        Text("\(role.plannedHours) h planeadas · \(money(role.plannedCostMXN))")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text("Las tarifas son internas y no forman parte del precio visible para el cliente.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Editar horas y tarifas") {
                    appState.presentPlanningProfile()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func heading(_ value: String) -> some View {
        Text(value)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func money(_ value: Int) -> String {
        value.formatted(.currency(code: "MXN").precision(.fractionLength(0)))
    }
}

private struct CostsByModuleView: View {
    var body: some View {
        SectionUnavailableView(
            title: "Costo por módulo pendiente",
            detail: "Repartir el costo interno por módulo requiere horas y tarifas asociadas a cada bloque del mapa, que todavía no existen."
        )
    }
}

private struct CostsServicesView: View {
    var body: some View {
        SectionUnavailableView(
            title: "Servicios y licencias pendientes",
            detail: "Los costos periódicos de infraestructura y licencias todavía no tienen un registro real en Project Core."
        )
    }
}

private struct CostsHistoryView: View {
    var body: some View {
        SectionUnavailableView(
            title: "Historial del presupuesto pendiente",
            detail: "El registro de cambios al presupuesto con causa, versión y responsable todavía no existe en Project Core."
        )
    }
}

private struct CostsProposalView: View {
    @EnvironmentObject private var appState: AppState
    @State private var includeTechnicalSheet = true
    @State private var includeAssumptions = true
    @State private var reviewPrepared = false

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    proposalPreview
                    proposalControls
                }
                VStack(spacing: TazkleSpacing.medium) {
                    proposalPreview
                    proposalControls
                }
            }

            if reviewPrepared {
                Label("La propuesta quedó preparada para revisión interna", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(TazkleColors.success)
            }
        }
    }

    private var proposalPreview: some View {
        ProjectSectionCard(title: "Vista previa", systemImage: "doc.text") {
            Text(appState.graph.name)
                .font(.title2.weight(.semibold))
            Text("Propuesta para una aplicación web modular")
                .font(.callout)
                .foregroundStyle(.secondary)
            Divider()
            proposalLine(
                "Alcance",
                "\(appState.graph.blocks.count) bloques · \(appState.graph.relations.count) relaciones"
            )
            proposalLine(
                "Duración estimada",
                "\(appState.planningProfile.targetWeeks) semanas"
            )
            proposalLine(
                "Precio propuesto",
                appState.planningAssessment.map { moneyRange($0.clientPrice) } ?? "Datos insuficientes"
            )
            proposalLine("Incluye", "Diseño, desarrollo, QA y puesta en producción")
            if includeTechnicalSheet {
                proposalLine("Ficha técnica", "Arquitectura, tecnologías e integraciones")
            }
            if includeAssumptions {
                proposalLine("Supuestos", "Volumen, disponibilidad y servicios considerados")
            }
            Divider()
            Text("El costo interno y las tarifas no aparecen en la versión para cliente.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var proposalControls: some View {
        ProjectSectionCard(title: "Contenido y aprobación", systemImage: "checkmark.shield") {
            Toggle("Incluir ficha técnica", isOn: $includeTechnicalSheet)
            Toggle("Incluir supuestos y exclusiones", isOn: $includeAssumptions)
            Divider()
            ProjectStatusPill(
                title: reviewPrepared ? "Lista para revisión" : "Borrador interno",
                systemImage: reviewPrepared ? "checkmark.circle.fill" : "circle.dashed",
                color: reviewPrepared ? TazkleColors.success : TazkleColors.warning
            )
            Button("Preparar revisión interna") {
                reviewPrepared = true
            }
            .buttonStyle(.borderedProminent)
            .tint(TazkleColors.relationship)
        }
        .frame(maxWidth: 360, alignment: .top)
    }

    private func proposalLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.callout.weight(.semibold))
            Spacer()
            Text(value).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }

    private func moneyRange(_ range: MoneyRange) -> String {
        "\(money(range.lowerBound)) – \(money(range.upperBound))"
    }

    private func money(_ value: Int) -> String {
        value.formatted(.currency(code: "MXN").precision(.fractionLength(0)))
    }
}

private enum CostPrototype {
    static func destination(_ id: String) -> SectionDestination {
        AppSection.costs.contextualDestinations.first { $0.id == id }
            ?? AppSection.costs.contextualDestinations[0]
    }
}
