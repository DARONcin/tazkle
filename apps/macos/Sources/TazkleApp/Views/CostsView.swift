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
        VStack(spacing: TazkleSpacing.medium) {
            ForEach(CostPrototype.modules) { module in
                ProjectSectionCard(title: module.name, systemImage: module.systemImage) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(module.range)
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                            Text(module.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ProjectStatusPill(
                            title: module.confidence,
                            systemImage: "chart.bar.fill",
                            color: module.confidence == "Confianza alta" ? TazkleColors.success : TazkleColors.warning
                        )
                    }
                    ProgressView(value: module.weight)
                        .tint(module.color)
                        .accessibilityLabel("Participación en el costo interno")
                        .accessibilityValue("\(Int(module.weight * 100)) por ciento")
                }
            }
        }
    }
}

private struct CostsServicesView: View {
    @State private var includeOptional = false

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.large) {
            Toggle("Incluir servicios opcionales", isOn: $includeOptional)
                .toggleStyle(.switch)

            ProjectSectionCard(title: "Servicios y licencias", systemImage: "shippingbox") {
                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: TazkleSpacing.xLarge, verticalSpacing: 0) {
                        GridRow {
                            heading("Concepto")
                            heading("Frecuencia")
                            heading("Costo")
                            heading("Supuesto")
                        }
                        Divider().gridCellColumns(4)
                        ForEach(CostPrototype.services.filter { includeOptional || !$0.optional }) { service in
                            GridRow {
                                Label(service.name, systemImage: service.systemImage)
                                Text(service.frequency).foregroundStyle(.secondary)
                                Text(service.cost).monospacedDigit()
                                Text(service.assumption).foregroundStyle(.secondary)
                            }
                            .font(.callout)
                            .padding(.vertical, TazkleSpacing.medium)
                            Divider().gridCellColumns(4)
                        }
                    }
                    .frame(minWidth: 720, alignment: .leading)
                }
            }
        }
    }

    private func heading(_ value: String) -> some View {
        Text(value).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }
}

private struct CostsHistoryView: View {
    var body: some View {
        ProjectSectionCard(title: "Historial del presupuesto", systemImage: "clock.arrow.circlepath") {
            ForEach(CostPrototype.history) { entry in
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    ZStack {
                        Circle().fill(entry.color.opacity(0.14)).frame(width: 34, height: 34)
                        Image(systemName: entry.systemImage).foregroundStyle(entry.color)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.title).font(.callout.weight(.semibold))
                            Spacer()
                            Text(entry.version).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Text(entry.detail).font(.callout).foregroundStyle(.secondary)
                        Text(entry.author).font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, TazkleSpacing.small)
                Divider()
            }
        }
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

private struct CostScenario: Identifiable {
    let id: String
    let value: String
    let detail: String
    let color: Color
}

private struct CostDeviation: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let impact: String
    let level: String
}

private struct CostRole: Identifiable {
    let id = UUID()
    let name: String
    let plannedHours: Int
    let actualHours: Int
    let rate: String
    let plannedCost: String
    let variance: String
}

private struct CostModule: Identifiable {
    let id = UUID()
    let name: String
    let systemImage: String
    let range: String
    let detail: String
    let confidence: String
    let weight: Double
    let color: Color
}

private struct CostService: Identifiable {
    let id = UUID()
    let name: String
    let systemImage: String
    let frequency: String
    let cost: String
    let assumption: String
    let optional: Bool
}

private struct CostHistoryEntry: Identifiable {
    let id = UUID()
    let title: String
    let version: String
    let detail: String
    let author: String
    let systemImage: String
    let color: Color
}

private enum CostPrototype {
    static let scenarios = [
        CostScenario(id: "P90", value: "$735k MXN", detail: "Escenario conservador con mayor incertidumbre cubierta.", color: TazkleColors.warning),
        CostScenario(id: "P50", value: "$655k MXN", detail: "Escenario base bajo los supuestos actuales.", color: TazkleColors.success),
        CostScenario(id: "P10", value: "$575k MXN", detail: "Escenario optimista; no debe presentarse como garantía.", color: TazkleColors.relationship),
    ]

    static let deviations = [
        CostDeviation(title: "Alcance en crecimiento", detail: "Dos funcionalidades nuevas incrementan el esfuerzo.", impact: "+$12k", level: "Alto"),
        CostDeviation(title: "Eficiencia del equipo", detail: "La productividad observada coincide con el escenario base.", impact: "$0", level: "Bajo"),
        CostDeviation(title: "Servicios en la nube", detail: "El consumo previsto supera el plan inicial.", impact: "+$6k", level: "Medio"),
    ]

    static let roles = [
        CostRole(name: "Responsable técnico", plannedHours: 240, actualHours: 198, rate: "$120/h", plannedCost: "$28,800", variance: "−$5,040"),
        CostRole(name: "Diseño", plannedHours: 160, actualHours: 142, rate: "$90/h", plannedCost: "$14,400", variance: "−$1,620"),
        CostRole(name: "Desarrollo", plannedHours: 560, actualHours: 480, rate: "$85/h", plannedCost: "$47,600", variance: "−$6,800"),
        CostRole(name: "QA", plannedHours: 160, actualHours: 128, rate: "$70/h", plannedCost: "$11,200", variance: "−$2,240"),
        CostRole(name: "DevOps", plannedHours: 80, actualHours: 64, rate: "$110/h", plannedCost: "$8,800", variance: "−$1,760"),
        CostRole(name: "Producto", plannedHours: 60, actualHours: 52, rate: "$80/h", plannedCost: "$4,800", variance: "−$640"),
    ]

    static let modules = [
        CostModule(name: "Módulo de usuarios", systemImage: "person.2", range: "$145k–$180k", detail: "Registro, autenticación y perfiles.", confidence: "Confianza alta", weight: 0.28, color: TazkleColors.relationship),
        CostModule(name: "API", systemImage: "chevron.left.forwardslash.chevron.right", range: "$120k–$165k", detail: "Servicios, validación y documentación.", confidence: "Confianza media", weight: 0.24, color: TazkleColors.actionPrimary),
        CostModule(name: "Datos", systemImage: "cylinder", range: "$90k–$130k", detail: "Persistencia, migraciones y recuperación.", confidence: "Confianza media", weight: 0.19, color: TazkleColors.success),
        CostModule(name: "Operación", systemImage: "cloud", range: "$70k–$110k", detail: "Infraestructura, monitoreo y release.", confidence: "Confianza media", weight: 0.16, color: TazkleColors.assistantProposal),
    ]

    static let services = [
        CostService(name: "Neon", systemImage: "cylinder", frequency: "Mensual", cost: "$4,800", assumption: "Escenario base", optional: false),
        CostService(name: "PowerSync", systemImage: "arrow.triangle.2.circlepath", frequency: "Mensual", cost: "$3,600", assumption: "Sincronización inicial", optional: false),
        CostService(name: "Almacenamiento R2", systemImage: "externaldrive", frequency: "Mensual", cost: "$1,200", assumption: "250 GB", optional: false),
        CostService(name: "Monitoreo avanzado", systemImage: "waveform.path.ecg", frequency: "Mensual", cost: "$2,900", assumption: "Retención de 30 días", optional: true),
        CostService(name: "Soporte prioritario", systemImage: "person.fill.questionmark", frequency: "Anual", cost: "$18,000", assumption: "Proveedor externo", optional: true),
    ]

    static let history = [
        CostHistoryEntry(title: "Escenario base generado", version: "v1", detail: "Estimación inicial a partir de horas por rol.", author: "Carlos Ruiz · Responsable técnico", systemImage: "plus.circle", color: TazkleColors.actionPrimary),
        CostHistoryEntry(title: "Reserva incrementada al 15%", version: "v2", detail: "Se añadió cobertura para riesgos de integración.", author: "Finanzas", systemImage: "shield", color: TazkleColors.warning),
        CostHistoryEntry(title: "Alternativa administrada comparada", version: "v3", detail: "La variante reduce tiempo y aumenta servicios periódicos.", author: "Tazki · propuesta pendiente de aprobación", systemImage: "sparkles", color: TazkleColors.relationship),
    ]

    static func destination(_ id: String) -> SectionDestination {
        AppSection.costs.contextualDestinations.first { $0.id == id }
            ?? AppSection.costs.contextualDestinations[0]
    }
}
