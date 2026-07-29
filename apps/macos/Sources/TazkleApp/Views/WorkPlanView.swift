import SwiftUI
import TazkleDesignSystem

struct WorkPlanView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    private var destinationID: String {
        appState.selectedDestinationID ?? "work.summary"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
                ProjectSectionHeader(
                    title: appState.selectedDestination?.title ?? "Plan de trabajo",
                    subtitle: subtitle,
                    systemImage: "calendar",
                    accent: TazkleColors.actionPrimary,
                    trailingTitle: destinationID == "work.summary" ? "Abrir tablero" : nil,
                    trailingAction: destinationID == "work.summary" ? {
                        appState.selectDestination(WorkPrototype.destination("work.board"))
                    } : nil
                )

                switch destinationID {
                case "work.calendar":
                    WorkCalendarView()
                case "work.board":
                    WorkBoardView()
                case "work.backlog":
                    WorkBacklogView()
                case "work.deliverables":
                    WorkDeliverablesView()
                case "work.approvals":
                    WorkApprovalsView()
                default:
                    WorkPlanDashboardView()
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
        case "work.calendar": "Dependencias y duración por semana, sin mezclar el tablero."
        case "work.board": "Trabajo por estado con movimiento accesible entre columnas."
        case "work.backlog": "Elementos priorizados que todavía no pertenecen a un sprint."
        case "work.deliverables": "Resultado esperado, compromiso y evidencia de aceptación."
        case "work.approvals": "Revisiones pendientes y responsables de cada entrega."
        default: "Objetivo, capacidad y siguiente trabajo del sprint actual."
        }
    }
}

private struct WorkPlanDashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            ProjectSectionCard(title: "Sprint 03", systemImage: "flag.checkered") {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: TazkleSpacing.xLarge) {
                        sprintObjective
                        Divider().frame(height: 82)
                        sprintCapacity
                        Divider().frame(height: 82)
                        sprintDates
                    }
                    VStack(alignment: .leading, spacing: TazkleSpacing.large) {
                        sprintObjective
                        Divider()
                        sprintCapacity
                        Divider()
                        sprintDates
                    }
                }
            }

            LazyVGrid(
                columns: ProjectGridLayout.equalColumns(4),
                spacing: TazkleSpacing.medium
            ) {
                ProjectMetricCard(title: "Comprometidas", value: "320 h", detail: "De 400 h disponibles", systemImage: "clock", accent: TazkleColors.actionPrimary)
                ProjectMetricCard(title: "En progreso", value: "3", detail: "Tareas activas", systemImage: "arrow.triangle.2.circlepath", accent: TazkleColors.assistantProposal)
                ProjectMetricCard(title: "Bloqueadas", value: "1", detail: "Dependencia pendiente", systemImage: "exclamationmark.triangle", accent: TazkleColors.warning)
                ProjectMetricCard(title: "Entregables", value: "2", detail: "Comprometidos en el sprint", systemImage: "shippingbox", accent: TazkleColors.relationship)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    activeWork
                    milestoneCard
                }
                VStack(spacing: TazkleSpacing.medium) {
                    activeWork
                    milestoneCard
                }
            }

            ProjectSectionCard(title: "Dependencia pendiente", systemImage: "exclamationmark.triangle") {
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(TazkleColors.warning)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recuperación de contraseña espera Gestión de sesiones")
                            .font(.callout.weight(.semibold))
                        Text("La tarea conserva su estimación y responsable, pero no puede iniciar hasta validar la relación Arquitectura 2.4.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Ver tablero") {
                        appState.selectDestination(WorkPrototype.destination("work.board"))
                    }
                }
            }
        }
    }

    private var sprintObjective: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Objetivo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Completar autenticación y exponer el perfil mediante la API.")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sprintCapacity: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            Text("80% de capacidad")
                .font(.headline)
            ProgressView(value: 0.8)
                .tint(TazkleColors.success)
            Text("320 de 400 horas")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sprintDates: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("14 días")
                .font(.headline)
            Text("13–26 mayo")
                .font(.callout)
                .foregroundStyle(.secondary)
            ProjectStatusPill(title: "En curso", systemImage: "circle.fill", color: TazkleColors.actionPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeWork: some View {
        ProjectSectionCard(title: "Trabajo activo", systemImage: "list.bullet.rectangle") {
            ForEach(WorkPrototype.tasks.filter { $0.status == .inProgress }) { task in
                ProjectListRow {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title).font(.callout.weight(.semibold))
                        Text("\(task.owner) · \(task.module)").font(.caption).foregroundStyle(.secondary)
                    }
                } trailing: {
                    Text("\(task.hours) h").font(.callout.monospacedDigit())
                }
            }
            Button("Abrir tablero") {
                appState.selectDestination(WorkPrototype.destination("work.board"))
            }
            .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var milestoneCard: some View {
        ProjectSectionCard(title: "Próximos compromisos", systemImage: "signpost.right") {
            ForEach(WorkPrototype.deliverables.prefix(3)) { deliverable in
                ProjectListRow {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(deliverable.title).font(.callout.weight(.semibold))
                        Text(deliverable.owner).font(.caption).foregroundStyle(.secondary)
                    }
                } trailing: {
                    Text(deliverable.date).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            Button("Ver entregables") {
                appState.selectDestination(WorkPrototype.destination("work.deliverables"))
            }
            .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct WorkCalendarView: View {
    @State private var scale = "Semanas"

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.large) {
            Picker("Escala", selection: $scale) {
                Text("Semanas").tag("Semanas")
                Text("Sprints").tag("Sprints")
                Text("Meses").tag("Meses")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            ProjectSectionCard(title: "Calendario del sprint", systemImage: "calendar.day.timeline.left") {
                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: TazkleSpacing.small, verticalSpacing: TazkleSpacing.medium) {
                        GridRow {
                            Text("Trabajo").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            ForEach(1 ... 4, id: \.self) { week in
                                Text("Semana \(week)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        ForEach(WorkPrototype.calendarItems) { item in
                            GridRow {
                                Label(item.title, systemImage: item.systemImage)
                                    .font(.callout)
                                    .lineLimit(1)
                                    .frame(width: 190, alignment: .leading)
                                ForEach(1 ... 4, id: \.self) { week in
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(item.weeks.contains(week) ? item.color : Color.secondary.opacity(0.08))
                                        .frame(height: 18)
                                        .overlay {
                                            if week == item.weeks.last {
                                                Image(systemName: "diamond.fill")
                                                    .font(.system(size: 7))
                                                    .foregroundStyle(item.color)
                                                    .offset(x: 24)
                                            }
                                        }
                                        .accessibilityLabel("Semana \(week)")
                                        .accessibilityValue(item.weeks.contains(week) ? "Planificada" : "Sin trabajo")
                                }
                            }
                        }
                    }
                    .frame(minWidth: 760, alignment: .leading)
                }
            }

            ProjectSectionCard(title: "Lectura del calendario", systemImage: "info.circle") {
                Text("Autenticación y API se superponen durante dos semanas. Datos continúa una semana adicional y define el final probable del sprint.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WorkBoardView: View {
    @State private var tasks = WorkPrototype.tasks

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                ForEach(WorkTaskStatus.allCases) { status in
                    WorkBoardColumn(
                        status: status,
                        tasks: tasks.filter { $0.status == status },
                        moveTask: moveTask
                    )
                }
            }
            .padding(.bottom, TazkleSpacing.small)
        }
        .accessibilityLabel("Tablero del sprint")
    }

    private func moveTask(_ id: UUID, to status: WorkTaskStatus) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            tasks[index].status = status
        }
    }
}

private struct WorkBoardColumn: View {
    let status: WorkTaskStatus
    let tasks: [WorkTask]
    let moveTask: (UUID, WorkTaskStatus) -> Void

    var body: some View {
        ProjectSectionCard(title: "\(status.title) · \(tasks.count)", systemImage: status.systemImage) {
            ForEach(tasks) { task in
                WorkTaskCard(task: task, moveTask: moveTask)
                    .draggable(task.id.uuidString)
            }

            if tasks.isEmpty {
                Text("Suelta una tarea aquí")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 72)
            }
        }
        .frame(width: 270, alignment: .top)
        .dropDestination(for: String.self) { values, _ in
            guard let rawID = values.first, let id = UUID(uuidString: rawID) else { return false }
            moveTask(id, status)
            return true
        }
        .accessibilityHint("Las tareas también pueden moverse desde su menú de estado.")
    }
}

private struct WorkTaskCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    let task: WorkTask
    let moveTask: (UUID, WorkTaskStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            HStack(alignment: .top) {
                Text(task.title)
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Menu {
                    ForEach(WorkTaskStatus.allCases) { status in
                        Button(status.title) { moveTask(task.id, status) }
                            .disabled(status == task.status)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Cambiar estado de \(task.title)")
            }

            Label(task.module, systemImage: task.systemImage)
                .font(.caption)
                .foregroundStyle(task.color)
            HStack {
                Label(task.owner, systemImage: "person.crop.circle")
                Spacer()
                Text("\(task.hours) h").monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if task.blocked {
                ProjectStatusPill(
                    title: "Bloqueada",
                    systemImage: "exclamationmark.triangle.fill",
                    color: TazkleColors.warning
                )
            }
        }
        .padding(TazkleSpacing.medium)
        .background(
            TazkleColors.elevated(
                for: colorScheme,
                highContrast: highContrast
            )
            .opacity(highContrast ? 1 : 0.72)
        )
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.control))
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.control)
                .stroke(
                    task.blocked
                        ? TazkleColors.warning.opacity(0.7)
                        : TazkleColors.separator(
                            for: colorScheme,
                            highContrast: highContrast
                        ),
                    lineWidth: highContrast ? 1.5 : 1
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title), \(task.status.title)")
        .accessibilityValue("\(task.owner), \(task.hours) horas\(task.blocked ? ", bloqueada" : "")")
    }
}

private struct WorkBacklogView: View {
    @State private var priority = "Todas"

    private var items: [WorkBacklogItem] {
        priority == "Todas"
            ? WorkPrototype.backlog
            : WorkPrototype.backlog.filter { $0.priority == priority }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.large) {
            Picker("Prioridad", selection: $priority) {
                Text("Todas").tag("Todas")
                Text("Alta").tag("Alta")
                Text("Media").tag("Media")
                Text("Baja").tag("Baja")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            ProjectSectionCard(title: "Backlog priorizado", systemImage: "list.bullet.rectangle") {
                ForEach(items) { item in
                    ProjectListRow {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(.callout.weight(.semibold))
                            Text("\(item.module) · \(item.reason)").font(.caption).foregroundStyle(.secondary)
                        }
                    } trailing: {
                        HStack {
                            Text("\(item.hours) h").font(.callout.monospacedDigit())
                            ProjectStatusPill(
                                title: item.priority,
                                systemImage: "flag.fill",
                                color: item.priority == "Alta" ? TazkleColors.warning : TazkleColors.actionPrimary
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct WorkDeliverablesView: View {
    var body: some View {
        VStack(spacing: TazkleSpacing.medium) {
            ForEach(WorkPrototype.deliverables) { deliverable in
                ProjectSectionCard(title: deliverable.title, systemImage: deliverable.systemImage) {
                    HStack {
                        ProjectStatusPill(
                            title: deliverable.status,
                            systemImage: deliverable.status == "Aceptado" ? "checkmark.circle.fill" : "clock",
                            color: deliverable.status == "Aceptado" ? TazkleColors.success : TazkleColors.warning
                        )
                        Spacer()
                        Text(deliverable.date)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(deliverable.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Label(deliverable.owner, systemImage: "person.crop.circle")
                        .font(.caption)
                }
            }
        }
    }
}

private struct WorkApprovalsView: View {
    @State private var designApproved = true
    @State private var technicalApproved = false
    @State private var qaApproved = false
    @State private var deliverableClosed = false

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            ProjectSectionCard(title: "Aprobaciones del sprint", systemImage: "checkmark.shield") {
                approval(
                    title: "Flujo de autenticación",
                    responsible: "María López · Producto",
                    approved: $designApproved
                )
                approval(
                    title: "Implementación técnica",
                    responsible: "Carlos Ruiz · Responsable técnico",
                    approved: $technicalApproved
                )
                approval(
                    title: "Criterios de aceptación y pruebas",
                    responsible: "Lucía Fernández · QA",
                    approved: $qaApproved
                )
            }

            ProjectSectionCard(title: "Estado de la puerta", systemImage: "lock.shield") {
                let completed = [designApproved, technicalApproved, qaApproved].filter { $0 }.count
                ProjectProgressRow(
                    title: "\(completed) de 3 aprobaciones",
                    detail: completed == 3 ? "El entregable puede cerrarse." : "Faltan responsables por revisar.",
                    value: Double(completed) / 3,
                    color: TazkleColors.success
                )
                if deliverableClosed {
                    Label("Entregable cerrado en el escenario de prototipo", systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(TazkleColors.success)
                }
                Button("Cerrar entregable") {
                    deliverableClosed = true
                }
                    .buttonStyle(.borderedProminent)
                    .tint(TazkleColors.relationship)
                    .disabled(completed < 3 || deliverableClosed)
            }
        }
    }

    private func approval(
        title: String,
        responsible: String,
        approved: Binding<Bool>
    ) -> some View {
        Toggle(isOn: approved) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.callout.weight(.semibold))
                Text(responsible).font(.caption).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, TazkleSpacing.small)
    }
}

private enum WorkTaskStatus: String, CaseIterable, Identifiable {
    case todo
    case inProgress
    case review
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todo: "Por hacer"
        case .inProgress: "En progreso"
        case .review: "En revisión"
        case .done: "Completado"
        }
    }

    var systemImage: String {
        switch self {
        case .todo: "circle"
        case .inProgress: "arrow.triangle.2.circlepath"
        case .review: "eye"
        case .done: "checkmark.circle.fill"
        }
    }
}

private struct WorkTask: Identifiable {
    let id: UUID
    let title: String
    let owner: String
    let module: String
    let systemImage: String
    let hours: Int
    let color: Color
    let blocked: Bool
    var status: WorkTaskStatus
}

private struct WorkCalendarItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let weeks: [Int]
    let color: Color
}

private struct WorkBacklogItem: Identifiable {
    let id = UUID()
    let title: String
    let module: String
    let reason: String
    let hours: Int
    let priority: String
}

private struct WorkDeliverable: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let owner: String
    let date: String
    let status: String
    let systemImage: String
}

private enum WorkPrototype {
    static let tasks = [
        WorkTask(id: UUID(), title: "Diseñar flujo de autenticación", owner: "María López", module: "Usuarios", systemImage: "person.2", hours: 16, color: TazkleColors.relationship, blocked: false, status: .todo),
        WorkTask(id: UUID(), title: "Recuperación de contraseña", owner: "Diego Ramírez", module: "Usuarios", systemImage: "lock", hours: 24, color: TazkleColors.relationship, blocked: true, status: .todo),
        WorkTask(id: UUID(), title: "Implementar autenticación", owner: "Carlos Ruiz", module: "API", systemImage: "chevron.left.forwardslash.chevron.right", hours: 32, color: TazkleColors.actionPrimary, blocked: false, status: .inProgress),
        WorkTask(id: UUID(), title: "Diseñar endpoint de perfil", owner: "Laura Méndez", module: "API", systemImage: "chevron.left.forwardslash.chevron.right", hours: 16, color: TazkleColors.actionPrimary, blocked: false, status: .inProgress),
        WorkTask(id: UUID(), title: "Migración de datos", owner: "Ana Torres", module: "Datos", systemImage: "cylinder", hours: 32, color: TazkleColors.success, blocked: false, status: .inProgress),
        WorkTask(id: UUID(), title: "Endpoint de perfil", owner: "Javier Morales", module: "API", systemImage: "chevron.left.forwardslash.chevron.right", hours: 32, color: TazkleColors.actionPrimary, blocked: false, status: .review),
        WorkTask(id: UUID(), title: "Base de esquemas", owner: "Diego Sánchez", module: "Datos", systemImage: "cylinder", hours: 16, color: TazkleColors.success, blocked: false, status: .review),
        WorkTask(id: UUID(), title: "Servicio de correos", owner: "Ana Torres", module: "Notificaciones", systemImage: "envelope", hours: 16, color: TazkleColors.assistantProposal, blocked: false, status: .done),
        WorkTask(id: UUID(), title: "Configuración del entorno", owner: "Javier Morales", module: "Operación", systemImage: "cloud", hours: 12, color: TazkleColors.assistantProposal, blocked: false, status: .done),
    ]

    static let calendarItems = [
        WorkCalendarItem(title: "Módulo de usuarios", systemImage: "person.2", weeks: [1, 2], color: TazkleColors.relationship),
        WorkCalendarItem(title: "API", systemImage: "chevron.left.forwardslash.chevron.right", weeks: [2, 3], color: TazkleColors.actionPrimary),
        WorkCalendarItem(title: "Base de datos", systemImage: "cylinder", weeks: [1, 2, 3, 4], color: TazkleColors.success),
        WorkCalendarItem(title: "Servicio de correos", systemImage: "envelope", weeks: [1, 2], color: TazkleColors.assistantProposal),
    ]

    static let backlog = [
        WorkBacklogItem(title: "Inicio de sesión con proveedor externo", module: "Usuarios", reason: "Pendiente de decisión", hours: 24, priority: "Alta"),
        WorkBacklogItem(title: "Panel de auditoría", module: "Gobierno", reason: "Después del MVP", hours: 40, priority: "Media"),
        WorkBacklogItem(title: "Exportación CSV", module: "Reportes", reason: "Sin criterio de aceptación", hours: 12, priority: "Baja"),
        WorkBacklogItem(title: "Alertas de consumo", module: "Operación", reason: "Requiere métricas", hours: 20, priority: "Media"),
    ]

    static let deliverables = [
        WorkDeliverable(title: "Módulo de autenticación", detail: "Registro, inicio de sesión y recuperación con criterios de aceptación.", owner: "Carlos Ruiz", date: "19 mayo", status: "En revisión", systemImage: "lock.shield"),
        WorkDeliverable(title: "API de perfil", detail: "Contrato, implementación y pruebas de integración.", owner: "Javier Morales", date: "24 mayo", status: "En progreso", systemImage: "chevron.left.forwardslash.chevron.right"),
        WorkDeliverable(title: "Esquema inicial de datos", detail: "Migraciones, respaldo y recuperación comprobados.", owner: "Ana Torres", date: "26 mayo", status: "Aceptado", systemImage: "cylinder"),
    ]

    static func destination(_ id: String) -> SectionDestination {
        AppSection.workPlan.contextualDestinations.first { $0.id == id }
            ?? AppSection.workPlan.contextualDestinations[0]
    }
}
