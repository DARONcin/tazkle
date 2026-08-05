import Foundation
import TazkleAuthentication
import TazkleDomain
import TazklePersistence

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case overview
    case projectMap
    case architecture
    case team
    case feasibility
    case costs
    case workPlan
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Resumen"
        case .projectMap: "Mapa del proyecto"
        case .architecture: "Arquitectura"
        case .team: "Equipo"
        case .feasibility: "Factibilidad"
        case .costs: "Costos"
        case .workPlan: "Plan de trabajo"
        case .settings: "Configuración"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "house"
        case .projectMap: "map"
        case .architecture: "square.3.layers.3d"
        case .team: "person.2"
        case .feasibility: "checkmark.seal"
        case .costs: "dollarsign.circle"
        case .workPlan: "calendar"
        case .settings: "gearshape"
        }
    }
}

struct SectionDestination: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
}

extension AppSection {
    var contextualTitle: String {
        switch self {
        case .overview: "Navegación de resumen"
        case .projectMap: "Biblioteca de bloques"
        case .architecture: "Bloques de arquitectura"
        case .team: "Vistas de equipo"
        case .feasibility: "Evaluación"
        case .costs: "Desglose de costos"
        case .workPlan: "Vistas del plan"
        case .settings: "Configuración de cuenta"
        }
    }

    var contextualDestinations: [SectionDestination] {
        switch self {
        case .overview:
            [
                SectionDestination(id: "overview.general", title: "Vista general", systemImage: "clock"),
                SectionDestination(id: "overview.milestones", title: "Hitos", systemImage: "signpost.right"),
                SectionDestination(id: "overview.risks", title: "Riesgos", systemImage: "exclamationmark.triangle"),
                SectionDestination(id: "overview.activity", title: "Actividad", systemImage: "waveform.path.ecg"),
                SectionDestination(id: "overview.approvals", title: "Aprobaciones", systemImage: "checkmark.shield"),
            ]
        case .projectMap, .architecture:
            []
        case .team:
            [
                SectionDestination(id: "team.general", title: "Vista general", systemImage: "person.2"),
                SectionDestination(id: "team.coverage", title: "Cobertura de roles", systemImage: "person.badge.shield.checkmark"),
                SectionDestination(id: "team.capacity", title: "Capacidad", systemImage: "gauge.with.dots.needle.50percent"),
                SectionDestination(id: "team.assignments", title: "Asignaciones", systemImage: "person.line.dotted.person"),
                SectionDestination(id: "team.pending", title: "Roles pendientes", systemImage: "person.crop.circle.badge.questionmark"),
            ]
        case .feasibility:
            [
                SectionDestination(id: "feasibility.summary", title: "Resumen", systemImage: "checkmark.seal"),
                SectionDestination(id: "feasibility.dimensions", title: "Dimensiones", systemImage: "square.grid.2x2"),
                SectionDestination(id: "feasibility.evidence", title: "Evidencias", systemImage: "doc.text.magnifyingglass"),
                SectionDestination(id: "feasibility.assumptions", title: "Supuestos", systemImage: "text.bubble"),
                SectionDestination(id: "feasibility.alternatives", title: "Alternativas", systemImage: "arrow.triangle.branch"),
                SectionDestination(id: "feasibility.approval", title: "Aprobación", systemImage: "checkmark.shield"),
            ]
        case .costs:
            [
                SectionDestination(id: "costs.summary", title: "Resumen", systemImage: "dollarsign.circle"),
                SectionDestination(id: "costs.roles", title: "Por rol", systemImage: "person.2"),
                SectionDestination(id: "costs.modules", title: "Por módulo", systemImage: "square.3.layers.3d"),
                SectionDestination(id: "costs.services", title: "Servicios y licencias", systemImage: "shippingbox"),
                SectionDestination(id: "costs.history", title: "Historial", systemImage: "clock.arrow.circlepath"),
                SectionDestination(id: "costs.proposal", title: "Propuesta comercial", systemImage: "doc.text"),
            ]
        case .workPlan:
            [
                SectionDestination(id: "work.summary", title: "Resumen", systemImage: "calendar"),
                SectionDestination(id: "work.calendar", title: "Calendario", systemImage: "calendar.day.timeline.left"),
                SectionDestination(id: "work.board", title: "Tablero", systemImage: "rectangle.3.group"),
                SectionDestination(id: "work.backlog", title: "Backlog", systemImage: "list.bullet.rectangle"),
                SectionDestination(id: "work.deliverables", title: "Entregables", systemImage: "shippingbox"),
                SectionDestination(id: "work.approvals", title: "Aprobaciones", systemImage: "checkmark.shield"),
            ]
        case .settings:
            [
                SectionDestination(id: "settings.profile", title: "Perfil", systemImage: "person.crop.circle"),
                SectionDestination(id: "settings.security", title: "Seguridad", systemImage: "lock"),
                SectionDestination(id: "settings.availability", title: "Disponibilidad", systemImage: "calendar.badge.clock"),
                SectionDestination(id: "settings.notifications", title: "Notificaciones", systemImage: "bell"),
                SectionDestination(id: "settings.appearance", title: "Apariencia", systemImage: "circle.lefthalf.filled"),
                SectionDestination(id: "settings.shortcuts", title: "Atajos de teclado", systemImage: "command"),
                SectionDestination(id: "settings.organization", title: "Organización", systemImage: "building.2"),
                SectionDestination(id: "settings.members", title: "Miembros y roles", systemImage: "person.3"),
                SectionDestination(id: "settings.permissions", title: "Permisos", systemImage: "lock.shield"),
                SectionDestination(id: "settings.templates", title: "Plantillas", systemImage: "doc.on.doc"),
                SectionDestination(id: "settings.rates", title: "Costos y tarifas", systemImage: "banknote"),
                SectionDestination(id: "settings.ai", title: "IA", systemImage: "sparkles"),
                SectionDestination(id: "settings.sync", title: "Sincronización", systemImage: "arrow.triangle.2.circlepath"),
            ]
        }
    }
}

enum MapProjection: String, CaseIterable, Identifiable {
    case canvas
    case list

    var id: String { rawValue }
    var title: String { self == .canvas ? "Lienzo" : "Lista" }
    var systemImage: String { self == .canvas ? "point.3.connected.trianglepath.dotted" : "list.bullet" }
}

enum ArchitectureProjection: String, CaseIterable, Identifiable {
    case diagram
    case list

    var id: String { rawValue }
    var title: String { self == .diagram ? "Diagrama" : "Lista" }
    var systemImage: String { self == .diagram ? "square.3.layers.3d" : "list.bullet" }
}

enum LocalSaveState: Equatable {
    case saving
    case saved
    case failed

    var title: String {
        switch self {
        case .saving: "Guardando localmente"
        case .saved: "Guardado localmente"
        case .failed: "No se pudo guardar"
        }
    }

    var systemImage: String {
        switch self {
        case .saving: "arrow.triangle.2.circlepath"
        case .saved: "checkmark.circle"
        case .failed: "exclamationmark.triangle"
        }
    }
}

enum WorkspacePanelMode: String, CaseIterable, Identifiable {
    case inspector
    case tazki

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inspector: "Inspector"
        case .tazki: "Tazki"
        }
    }
}

enum WorkspaceContentState: Equatable {
    case loading
    case empty
    case project
}

enum TeamLoadState: Equatable {
    case idle
    case loading
    case loaded
    case offline
    case error(String)
}

enum RoleRatesLoadState: Equatable {
    case idle
    case loading
    case loaded
    case offline
    case error(String)
}

enum RoleRateSaveState: Equatable {
    case idle
    case saving
    case error(String)
}

enum OrganizationPlanningDefaultsLoadState: Equatable {
    case idle
    case loading
    case loaded
    case offline
    case error(String)
}

enum OrganizationPlanningDefaultsSaveState: Equatable {
    case idle
    case saving
    case error(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published var graph: ProjectGraph
    @Published var planningProfile: ProjectPlanningProfile
    @Published var availableProjects: [StoredProjectSummary] = []
    @Published var selectedProjectTemplate: ProjectTemplateKey = .blankCanvas
    @Published var selectedSection: AppSection = .projectMap
    @Published var selectedDestinationID: String?
    @Published var selectedBlockID: UUID?
    @Published var selectedRelationID: UUID?
    @Published var editingBlockID: UUID?
    @Published var projection: MapProjection = .canvas
    @Published var architectureProjection: ArchitectureProjection = .diagram
    @Published var projectMapTool: CanvasInteractionTool = .select
    @Published var architectureTool: CanvasInteractionTool = .select
    @Published var canvasResetRevision = 0
    @Published var selectedArchitectureLayer: ArchitectureLayer?
    @Published var isInspectorPresented = false
    @Published var isTazkiPresented = false
    @Published var workspacePanelMode = WorkspacePanelMode.inspector
    @Published var isPresentingNewBlock = false
    @Published var isPresentingNewRelation = false
    @Published var pendingRelationSourceID: UUID?
    @Published var pendingRelationTargetID: UUID?
    @Published var pendingRelationSourcePort: ConnectionPort?
    @Published var pendingRelationTargetPort: ConnectionPort?
    @Published var pendingBlockDeletionID: UUID?
    @Published var pendingRelationDeletionID: UUID?
    @Published var isPresentingNewProject = false
    @Published var isPresentingPlanningProfile = false
    @Published var isPresentingShortcuts = false
    @Published var pendingFamily: BlockFamily = .product
    @Published var lastError: String?
    @Published var saveState: LocalSaveState = .saved
    @Published private(set) var workspaceContentState: WorkspaceContentState = .loading
    @Published var isPresentingProductTour = false
    @Published private(set) var teamMembers: [OrganizationMember] = []
    @Published private(set) var teamLoadState: TeamLoadState = .idle
    @Published private(set) var roleRates: [RoleRate] = []
    @Published private(set) var roleRatesLoadState: RoleRatesLoadState = .idle
    @Published private(set) var roleRateSaveState: RoleRateSaveState = .idle
    @Published private(set) var organizationPlanningDefaults: OrganizationPlanningDefaults?
    @Published private(set) var organizationPlanningDefaultsLoadState: OrganizationPlanningDefaultsLoadState = .idle
    @Published private(set) var organizationPlanningDefaultsSaveState: OrganizationPlanningDefaultsSaveState = .idle

    private var store: SQLiteProjectStore?
    private(set) var activeWorkspaceAccountID: String?
    private var memoryProjects: [UUID: ProjectGraph] = [:]
    private var memoryProjectTemplates: [UUID: ProjectTemplateKey] = [:]
    private var memoryProjectUpdatedAt: [UUID: Date] = [:]
    private var memoryPlanningProfiles: [UUID: ProjectPlanningProfile] = [:]

    init() {
        let initialProject = ProjectGraph(name: "Sin proyecto activo")
        graph = initialProject
        // No session exists yet at construction time, so there are no real
        // rates to seed with — this always falls back to the placeholder.
        planningProfile = ProjectPlanningProfile.defaultProfile(for: initialProject)
    }

    func activateWorkspace(for workspaceAccountID: String) {
        guard activeWorkspaceAccountID != workspaceAccountID else { return }
        replaceWorkspaceWithPlaceholder(state: .loading)
        activeWorkspaceAccountID = workspaceAccountID
        do {
            let localStore = try SQLiteProjectStore.applicationSupport(
                workspaceAccountID: workspaceAccountID
            )
            store = localStore
            try localStore.removeLegacySyntheticPlaceholderIfPresent()
            if let latest = try localStore.listProjects().first,
               var saved = try localStore.loadProject(id: latest.id) {
                selectedProjectTemplate = latest.template
                let changed = applySuggestedArchitectureLayers(to: &saved)
                graph = saved
                if changed {
                    try localStore.save(saved, template: latest.template)
                }
                planningProfile = try localStore.loadPlanningProfile(projectID: graph.id)
                    ?? ProjectPlanningProfile.defaultProfile(for: graph, roleRates: planningRoleRateSeeds)
                clearMemoryProjects()
                rememberCurrentProject()
                try refreshAvailableProjects()
                workspaceContentState = .project
            } else {
                clearMemoryProjects()
                availableProjects = []
                workspaceContentState = .empty
            }
            saveState = .saved
        } catch {
            store = nil
            clearMemoryProjects()
            availableProjects = []
            workspaceContentState = .empty
            lastError = "No se pudo abrir el espacio local de esta cuenta. \(error.localizedDescription)"
            saveState = .failed
        }
    }

    func deactivateWorkspace() {
        guard activeWorkspaceAccountID != nil || store != nil else { return }
        store = nil
        activeWorkspaceAccountID = nil
        replaceWorkspaceWithPlaceholder(state: .loading)
    }

    func deleteWorkspace(for workspaceAccountID: String) throws {
        if activeWorkspaceAccountID == workspaceAccountID {
            store = nil
            activeWorkspaceAccountID = nil
            replaceWorkspaceWithPlaceholder(state: .loading)
        }
        do {
            try SQLiteProjectStore.deleteApplicationSupport(
                workspaceAccountID: workspaceAccountID
            )
            lastError = nil
        } catch {
            lastError = "La cuenta se eliminó, pero no fue posible borrar su copia local. \(error.localizedDescription)"
            throw error
        }
    }

    func loadTeamMembers(using authentication: AuthenticationController) async {
        guard let issuer = authentication.configuration?.issuer,
              let baseURL = URL.platformGatewayBaseURL(fromIssuer: issuer)
        else {
            teamLoadState = .error("No hay una sesión configurada para cargar el equipo.")
            return
        }

        teamLoadState = .loading
        do {
            let accessToken = try await authentication.validAccessToken()
            let client = PlatformAPIClient(baseURL: baseURL)
            teamMembers = try await client.fetchMembers(accessToken: accessToken)
            teamLoadState = .loaded
        } catch AuthenticationFailure.providerUnavailable {
            teamLoadState = .offline
        } catch is AuthenticationFailure {
            teamLoadState = .error("Tu sesión ya no es válida. Vuelve a iniciar sesión desde Configuración.")
        } catch PlatformAPIError.unauthorized {
            teamLoadState = .error("Tu sesión ya no es válida. Vuelve a iniciar sesión desde Configuración.")
        } catch {
            teamLoadState = .error("No fue posible cargar el equipo. Inténtalo nuevamente.")
        }
    }

    /// Best-effort current organization: the client has no organization
    /// picker yet, so this borrows whichever organization the team roster or
    /// an existing rate already resolved, matching every other real-data
    /// surface's single-organization assumption for this first slice.
    var currentOrganizationID: UUID? {
        roleRates.first?.organizationId ?? teamMembers.first?.organizationId
    }

    /// Bridges the real organization-wide rates (`roleRates`, keyed by
    /// `OrganizationRole`) into `ProjectPlanningProfile.defaultProfile`'s seed
    /// dictionary (keyed by the narrower `PlanningRole`). Empty until
    /// `loadRoleRates` has actually run, so callers before that (including
    /// `AppState.init()`, which has no session yet) naturally fall back to
    /// the placeholder rates baked into `defaultProfile`. `.operations` has
    /// no `OrganizationRole` counterpart and always falls back.
    private var planningRoleRateSeeds: [PlanningRole: Int] {
        let mapping: [PlanningRole: OrganizationRole] = [
            .product: .product,
            .technicalLead: .technicalLead,
            .design: .design,
            .development: .development,
            .quality: .qa,
        ]
        var seeds: [PlanningRole: Int] = [:]
        for (planningRole, organizationRole) in mapping {
            if let match = roleRates.first(where: { $0.role == organizationRole }) {
                seeds[planningRole] = match.hourlyRateMXN
            }
        }
        return seeds
    }

    func loadRoleRates(using authentication: AuthenticationController) async {
        guard let issuer = authentication.configuration?.issuer,
              let baseURL = URL.platformGatewayBaseURL(fromIssuer: issuer)
        else {
            roleRatesLoadState = .error("No hay una sesión configurada para cargar las tarifas.")
            return
        }

        roleRatesLoadState = .loading
        do {
            let accessToken = try await authentication.validAccessToken()
            let client = PlatformAPIClient(baseURL: baseURL)
            roleRates = try await client.fetchRoleRates(accessToken: accessToken)
            roleRatesLoadState = .loaded
        } catch AuthenticationFailure.providerUnavailable {
            roleRatesLoadState = .offline
        } catch is AuthenticationFailure {
            roleRatesLoadState = .error("Tu sesión ya no es válida. Vuelve a iniciar sesión desde Configuración.")
        } catch PlatformAPIError.unauthorized {
            roleRatesLoadState = .error("Tu sesión ya no es válida. Vuelve a iniciar sesión desde Configuración.")
        } catch {
            roleRatesLoadState = .error("No fue posible cargar las tarifas. Inténtalo nuevamente.")
        }
    }

    func saveRoleRate(
        role: OrganizationRole,
        hourlyRateMXN: Int,
        using authentication: AuthenticationController
    ) async {
        guard let organizationId = currentOrganizationID else {
            roleRateSaveState = .error("Todavía no se pudo determinar tu organización.")
            return
        }
        guard let issuer = authentication.configuration?.issuer,
              let baseURL = URL.platformGatewayBaseURL(fromIssuer: issuer)
        else {
            roleRateSaveState = .error("No hay una sesión configurada para guardar la tarifa.")
            return
        }

        roleRateSaveState = .saving
        do {
            let accessToken = try await authentication.validAccessToken()
            let client = PlatformAPIClient(baseURL: baseURL)
            let saved = try await client.upsertRoleRate(
                UpsertRoleRateCommand(
                    organizationId: organizationId,
                    role: role,
                    hourlyRateMXN: hourlyRateMXN
                ),
                accessToken: accessToken
            )
            roleRates.removeAll { $0.role == saved.role && $0.organizationId == saved.organizationId }
            roleRates.append(saved)
            roleRateSaveState = .idle
        } catch AuthenticationFailure.providerUnavailable {
            roleRateSaveState = .error("Sin conexión; la tarifa no se guardó.")
        } catch is AuthenticationFailure {
            roleRateSaveState = .error("Tu sesión ya no es válida. Vuelve a iniciar sesión desde Configuración.")
        } catch PlatformAPIError.unauthorized {
            roleRateSaveState = .error("Tu sesión ya no es válida. Vuelve a iniciar sesión desde Configuración.")
        } catch PlatformAPIError.forbidden {
            roleRateSaveState = .error("Sólo un administrador de la organización puede capturar tarifas internas.")
        } catch {
            roleRateSaveState = .error("No fue posible guardar la tarifa. Inténtalo nuevamente.")
        }
    }

    func loadOrganizationPlanningDefaults(using authentication: AuthenticationController) async {
        guard let organizationId = currentOrganizationID else {
            organizationPlanningDefaultsLoadState = .error("Todavía no se pudo determinar tu organización.")
            return
        }
        guard let issuer = authentication.configuration?.issuer,
              let baseURL = URL.platformGatewayBaseURL(fromIssuer: issuer)
        else {
            organizationPlanningDefaultsLoadState = .error("No hay una sesión configurada para cargar los valores predeterminados.")
            return
        }

        organizationPlanningDefaultsLoadState = .loading
        do {
            let accessToken = try await authentication.validAccessToken()
            let client = PlatformAPIClient(baseURL: baseURL)
            organizationPlanningDefaults = try await client.fetchOrganizationPlanningDefaults(
                organizationId: organizationId,
                accessToken: accessToken
            )
            organizationPlanningDefaultsLoadState = .loaded
        } catch AuthenticationFailure.providerUnavailable {
            organizationPlanningDefaultsLoadState = .offline
        } catch is AuthenticationFailure {
            organizationPlanningDefaultsLoadState = .error("Tu sesión ya no es válida. Vuelve a iniciar sesión desde Configuración.")
        } catch PlatformAPIError.unauthorized {
            organizationPlanningDefaultsLoadState = .error("Tu sesión ya no es válida. Vuelve a iniciar sesión desde Configuración.")
        } catch PlatformAPIError.forbidden {
            organizationPlanningDefaultsLoadState = .error("No tienes permiso para ver estos valores de costeo interno.")
        } catch {
            organizationPlanningDefaultsLoadState = .error("No fue posible cargar los valores predeterminados. Inténtalo nuevamente.")
        }
    }

    func saveOrganizationPlanningDefaults(
        riskReservePercent: Int,
        targetMarginPercent: Int,
        workdayHours: Int,
        allowFinanceRateEdits: Bool,
        using authentication: AuthenticationController
    ) async {
        guard let organizationId = currentOrganizationID else {
            organizationPlanningDefaultsSaveState = .error("Todavía no se pudo determinar tu organización.")
            return
        }
        guard let issuer = authentication.configuration?.issuer,
              let baseURL = URL.platformGatewayBaseURL(fromIssuer: issuer)
        else {
            organizationPlanningDefaultsSaveState = .error("No hay una sesión configurada para guardar los valores predeterminados.")
            return
        }

        organizationPlanningDefaultsSaveState = .saving
        do {
            let accessToken = try await authentication.validAccessToken()
            let client = PlatformAPIClient(baseURL: baseURL)
            organizationPlanningDefaults = try await client.updateOrganizationPlanningDefaults(
                organizationId: organizationId,
                UpdateOrganizationPlanningDefaultsCommand(
                    riskReservePercent: riskReservePercent,
                    targetMarginPercent: targetMarginPercent,
                    workdayHours: workdayHours,
                    allowFinanceRateEdits: allowFinanceRateEdits
                ),
                accessToken: accessToken
            )
            organizationPlanningDefaultsSaveState = .idle
        } catch AuthenticationFailure.providerUnavailable {
            organizationPlanningDefaultsSaveState = .error("Sin conexión; los valores no se guardaron.")
        } catch is AuthenticationFailure {
            organizationPlanningDefaultsSaveState = .error("Tu sesión ya no es válida. Vuelve a iniciar sesión desde Configuración.")
        } catch PlatformAPIError.unauthorized {
            organizationPlanningDefaultsSaveState = .error("Tu sesión ya no es válida. Vuelve a iniciar sesión desde Configuración.")
        } catch PlatformAPIError.forbidden {
            organizationPlanningDefaultsSaveState = .error("Sólo un administrador de la organización puede capturar estos valores.")
        } catch {
            organizationPlanningDefaultsSaveState = .error("No fue posible guardar los valores. Inténtalo nuevamente.")
        }
    }

    var selectedBlock: ProjectBlock? {
        guard let selectedBlockID else { return nil }
        return graph.block(id: selectedBlockID)
    }

    var selectedRelation: BlockRelation? {
        guard let selectedRelationID else { return nil }
        return graph.relations.first { $0.id == selectedRelationID }
    }

    var selectedDestination: SectionDestination? {
        let destinations = selectedSection.contextualDestinations
        return destinations.first { $0.id == selectedDestinationID } ?? destinations.first
    }

    var pendingBlockDeletion: ProjectBlock? {
        guard let pendingBlockDeletionID else { return nil }
        return graph.block(id: pendingBlockDeletionID)
    }

    var pendingRelationDeletion: BlockRelation? {
        guard let pendingRelationDeletionID else { return nil }
        return graph.relations.first { $0.id == pendingRelationDeletionID }
    }

    var planningAssessment: ProjectPlanningAssessment? {
        guard hasActiveProject else { return nil }
        return try? ProjectPlanningEngine.assess(
            graph: graph,
            profile: planningProfile
        )
    }

    var hasActiveProject: Bool {
        workspaceContentState == .project
    }

    func presentNewProject() {
        isPresentingNewProject = true
    }

    func presentProductTour() {
        isPresentingProductTour = true
    }

    @discardableResult
    func createProject(
        name: String,
        template: ProjectTemplateKey,
        webTechnologies: WebTechnologySelection = .defaultSelection
    ) -> Bool {
        let safeName = ProjectGraphValidator.sanitizedSingleLine(name, limit: 120)
        guard !safeName.isEmpty else {
            lastError = "El proyecto necesita un nombre."
            return false
        }

        let project = ProjectTemplateFactory.make(
            name: safeName,
            template: template,
            webTechnologies: webTechnologies
        )
        let profile = ProjectPlanningProfile.defaultProfile(for: project, roleRates: planningRoleRateSeeds)

        do {
            try ProjectGraphValidator.validate(project)
            if let store {
                try store.save(project, template: template)
                try store.savePlanningProfile(profile)
            }
            graph = project
            planningProfile = profile
            selectedProjectTemplate = template
            rememberCurrentProject()
            try refreshAvailableProjects()
            resetWorkspaceForProjectChange()
            isPresentingNewProject = false
            workspaceContentState = .project
            saveState = store == nil ? .failed : .saved
            return true
        } catch {
            lastError = "No se pudo crear el proyecto. \(error.localizedDescription)"
            return false
        }
    }

    func switchProject(to projectID: UUID) {
        guard projectID != graph.id else { return }
        guard let summary = availableProjects.first(where: { $0.id == projectID }) else {
            lastError = "El proyecto solicitado no está disponible en este espacio."
            return
        }

        do {
            let loaded: ProjectGraph?
            if let store {
                loaded = try store.loadProject(id: projectID)
            } else {
                loaded = memoryProjects[projectID]
            }

            guard var loaded else {
                lastError = "El proyecto ya no está disponible localmente."
                return
            }

            let changed = applySuggestedArchitectureLayers(to: &loaded)
            let loadedProfile: ProjectPlanningProfile
            if let store {
                loadedProfile = try store.loadPlanningProfile(projectID: projectID)
                    ?? ProjectPlanningProfile.defaultProfile(for: loaded, roleRates: planningRoleRateSeeds)
            } else {
                loadedProfile = memoryPlanningProfiles[projectID]
                    ?? ProjectPlanningProfile.defaultProfile(for: loaded, roleRates: planningRoleRateSeeds)
            }
            graph = loaded
            planningProfile = loadedProfile
            selectedProjectTemplate = summary.template
            rememberCurrentProject()
            if changed, let store {
                try store.save(loaded, template: summary.template)
                try refreshAvailableProjects()
            }
            resetWorkspaceForProjectChange()
            workspaceContentState = .project
            saveState = store == nil ? .failed : .saved
        } catch {
            lastError = "No se pudo abrir el proyecto. \(error.localizedDescription)"
        }
    }

    func selectSection(_ section: AppSection) {
        selectedSection = section
        selectedDestinationID = section.contextualDestinations.first?.id
        editingBlockID = nil
        selectedRelationID = nil
        if section == .settings {
            dismissTazki()
        }
    }

    func selectDestination(_ destination: SectionDestination) {
        guard selectedSection.contextualDestinations.contains(destination) else { return }
        selectedDestinationID = destination.id
    }

    func presentNewBlock(family: BlockFamily = .product) {
        pendingFamily = family
        isPresentingNewBlock = true
    }

    func presentPlanningProfile() {
        isPresentingPlanningProfile = true
    }

    @discardableResult
    func updatePlanningProfile(_ profile: ProjectPlanningProfile) -> Bool {
        guard profile.projectID == graph.id else {
            lastError = PlanningValidationError.projectMismatch.localizedDescription
            return false
        }

        var candidate = profile
        candidate.prepareForSave()

        do {
            try PlanningValidator.validate(candidate, projectID: graph.id)
            if let store {
                saveState = .saving
                try store.savePlanningProfile(candidate)
                saveState = .saved
            } else {
                saveState = .failed
            }
            planningProfile = candidate
            memoryPlanningProfiles[graph.id] = candidate
            isPresentingPlanningProfile = false
            return true
        } catch {
            saveState = .failed
            lastError = "No se pudieron guardar los datos de planeación. \(error.localizedDescription)"
            return false
        }
    }

    func selectBlock(_ blockID: UUID) {
        if selectedBlockID != blockID {
            editingBlockID = nil
        }
        selectedBlockID = blockID
        selectedRelationID = nil
        isInspectorPresented = true
        if !isTazkiPresented {
            workspacePanelMode = .inspector
        }
    }

    func clearBlockSelection() {
        selectedBlockID = nil
        editingBlockID = nil
        isInspectorPresented = false
    }

    func clearCanvasSelection() {
        clearBlockSelection()
        selectedRelationID = nil
    }

    func selectRelation(_ relationID: UUID) {
        guard graph.relations.contains(where: { $0.id == relationID }) else { return }
        selectedRelationID = relationID
        selectedBlockID = nil
        editingBlockID = nil
        isInspectorPresented = true
        if !isTazkiPresented {
            workspacePanelMode = .inspector
        }
    }

    func presentTazki() {
        guard selectedSection != .settings else { return }
        isTazkiPresented = true
        workspacePanelMode = .tazki
    }

    func dismissTazki() {
        isTazkiPresented = false
        workspacePanelMode = .inspector
    }

    func toggleTazki() {
        if isTazkiPresented {
            dismissTazki()
        } else {
            presentTazki()
        }
    }

    func beginEditingBlock(_ blockID: UUID) {
        guard let block = graph.block(id: blockID) else { return }
        guard block.state != .approved else {
            lastError = "Un bloque aprobado es inmutable. Crea una nueva versión del proyecto para modificarlo."
            return
        }
        selectedBlockID = blockID
        editingBlockID = blockID
        isInspectorPresented = true
    }

    func cancelEditingBlock() {
        editingBlockID = nil
    }

    func requestBlockDeletion(_ blockID: UUID) {
        guard let block = graph.block(id: blockID) else { return }
        guard block.state != .approved else {
            lastError = "Un bloque aprobado no puede eliminarse directamente. Debe modificarse mediante una nueva versión del proyecto."
            return
        }
        pendingBlockDeletionID = blockID
    }

    func cancelBlockDeletion() {
        pendingBlockDeletionID = nil
    }

    @discardableResult
    func confirmBlockDeletion() -> RemovedBlockSnapshot? {
        guard let blockID = pendingBlockDeletionID else { return nil }
        pendingBlockDeletionID = nil

        var candidate = graph
        guard let snapshot = candidate.removeBlock(id: blockID) else { return nil }

        do {
            try ProjectGraphValidator.validate(candidate)
            graph = candidate
            if let selectedRelationID,
               snapshot.relations.contains(where: { $0.id == selectedRelationID }) {
                self.selectedRelationID = nil
            }
            if selectedBlockID == blockID {
                clearBlockSelection()
            }
            persistGraph()
            return snapshot
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func restoreDeletedBlock(_ snapshot: RemovedBlockSnapshot) {
        var candidate = graph
        candidate.restoreBlock(from: snapshot)

        do {
            try ProjectGraphValidator.validate(candidate)
            graph = candidate
            selectedBlockID = snapshot.block.id
            selectedRelationID = nil
            isInspectorPresented = true
            persistGraph()
        } catch {
            lastError = "No se pudo restaurar el bloque. \(error.localizedDescription)"
        }
    }

    func addBlock(
        title: String,
        summary: String,
        family: BlockFamily,
        position: BlockPosition? = nil
    ) {
        let safeTitle = ProjectGraphValidator.sanitizedSingleLine(title, limit: 80)
        let safeSummary = ProjectGraphValidator.sanitizedSingleLine(summary, limit: 500)
        let index = graph.blocks.count
        let column = index % 3
        let row = index / 3
        let block = ProjectBlock(
            title: safeTitle,
            summary: safeSummary,
            family: family,
            architectureLayer: family.suggestedArchitectureLayer,
            position: position ?? BlockPosition(
                x: 210 + Double(column * 310),
                y: 170 + Double(row * 220)
            )
        )

        mutate { candidate in
            candidate.blocks.append(block)
            candidate.rowVersion += 1
        }
        selectedBlockID = block.id
        selectedRelationID = nil
        isInspectorPresented = true
    }

    func addBlock(from family: BlockFamily, at position: BlockPosition) {
        addBlock(
            title: "Nuevo bloque de \(family.displayName.lowercased())",
            summary: "Define el propósito y los datos de este bloque.",
            family: family,
            position: position
        )
        editingBlockID = selectedBlockID
    }

    func beginRelation(
        sourceID: UUID? = nil,
        targetID: UUID? = nil,
        sourcePort: ConnectionPort? = nil,
        targetPort: ConnectionPort? = nil
    ) {
        pendingRelationSourceID = sourceID
        pendingRelationTargetID = targetID
        pendingRelationSourcePort = sourcePort
        pendingRelationTargetPort = targetPort
        isPresentingNewRelation = true
    }

    func clearPendingRelation() {
        pendingRelationSourceID = nil
        pendingRelationTargetID = nil
        pendingRelationSourcePort = nil
        pendingRelationTargetPort = nil
    }

    func addRelation(
        sourceID: UUID,
        targetID: UUID,
        sourcePort: ConnectionPort,
        targetPort: ConnectionPort,
        type: RelationType,
        isCritical: Bool
    ) {
        let relation = BlockRelation(
            sourceID: sourceID,
            targetID: targetID,
            sourcePort: sourcePort,
            targetPort: targetPort,
            type: type,
            isCritical: isCritical
        )
        mutate { candidate in
            candidate.relations.append(relation)
            candidate.rowVersion += 1
        }
        selectedRelationID = relation.id
        selectedBlockID = nil
        isInspectorPresented = true
        if !isTazkiPresented {
            workspacePanelMode = .inspector
        }
    }

    func canEditRelation(_ relation: BlockRelation) -> Bool {
        let sourceIsApproved = graph.block(id: relation.sourceID)?.state == .approved
        let targetIsApproved = graph.block(id: relation.targetID)?.state == .approved
        return !sourceIsApproved && !targetIsApproved
    }

    func canDeleteRelation(_ relation: BlockRelation) -> Bool {
        canEditRelation(relation)
    }

    @discardableResult
    func updateRelationDetails(
        for relationID: UUID,
        sourceID: UUID,
        targetID: UUID,
        sourcePort: ConnectionPort,
        targetPort: ConnectionPort,
        type: RelationType,
        isCritical: Bool
    ) -> Bool {
        guard let relation = graph.relations.first(where: { $0.id == relationID }) else {
            lastError = GraphValidationError.missingRelation.localizedDescription
            return false
        }
        guard canEditRelation(relation) else {
            lastError = GraphValidationError.approvedRelationImmutable.localizedDescription
            return false
        }

        var candidate = graph
        do {
            try candidate.updateRelationDetails(
                id: relationID,
                sourceID: sourceID,
                targetID: targetID,
                sourcePort: sourcePort,
                targetPort: targetPort,
                type: type,
                isCritical: isCritical
            )
            graph = candidate
            selectedRelationID = relationID
            selectedBlockID = nil
            persistGraph()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func requestRelationDeletion(_ relationID: UUID) {
        guard let relation = graph.relations.first(where: { $0.id == relationID }) else { return }
        guard canDeleteRelation(relation) else {
            lastError = "Esta relación forma parte de un bloque aprobado. Crea una nueva versión del proyecto para modificarla."
            return
        }
        selectedRelationID = relationID
        pendingRelationDeletionID = relationID
    }

    func cancelRelationDeletion() {
        pendingRelationDeletionID = nil
    }

    @discardableResult
    func confirmRelationDeletion() -> RemovedRelationSnapshot? {
        guard let relationID = pendingRelationDeletionID else { return nil }
        pendingRelationDeletionID = nil

        var candidate = graph
        guard let snapshot = candidate.removeRelation(id: relationID) else { return nil }

        do {
            try ProjectGraphValidator.validate(candidate)
            graph = candidate
            if selectedRelationID == relationID {
                selectedRelationID = nil
            }
            persistGraph()
            return snapshot
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func restoreDeletedRelation(_ snapshot: RemovedRelationSnapshot) {
        var candidate = graph
        candidate.restoreRelation(from: snapshot)

        do {
            try ProjectGraphValidator.validate(candidate)
            graph = candidate
            selectedRelationID = snapshot.relation.id
            selectedBlockID = nil
            isInspectorPresented = true
            workspacePanelMode = .inspector
            persistGraph()
        } catch {
            lastError = "No se pudo restaurar la relación. \(error.localizedDescription)"
        }
    }

    func requestSelectionDeletion() {
        if let selectedRelationID {
            requestRelationDeletion(selectedRelationID)
        } else if let selectedBlockID {
            requestBlockDeletion(selectedBlockID)
        }
    }

    func moveBlock(_ blockID: UUID, to position: BlockPosition, persist: Bool) {
        guard let index = graph.blocks.firstIndex(where: { $0.id == blockID }) else { return }
        let safePosition = BlockPosition(
            x: min(max(position.x, 130), 3_070),
            y: min(max(position.y, 100), 2_090)
        )
        graph.blocks[index].position = safePosition

        if persist {
            graph.blocks[index].rowVersion += 1
            graph.rowVersion += 1
            persistGraph()
        }
    }

    func nudgeBlock(_ blockID: UUID, x: Double, y: Double) {
        guard let block = graph.block(id: blockID) else { return }
        moveBlock(
            blockID,
            to: BlockPosition(x: block.position.x + x, y: block.position.y + y),
            persist: true
        )
    }

    func updateState(for blockID: UUID, state: BlockState) {
        mutate { candidate in
            guard let index = candidate.blocks.firstIndex(where: { $0.id == blockID }) else { return }
            candidate.blocks[index].state = state
            candidate.blocks[index].rowVersion += 1
            candidate.rowVersion += 1
        }
    }

    @discardableResult
    func updateBlockDetails(
        for blockID: UUID,
        title: String,
        summary: String,
        family: BlockFamily,
        state: BlockState,
        architectureLayer: ArchitectureLayer?
    ) -> Bool {
        guard let current = graph.block(id: blockID) else { return false }
        guard current.state != .approved else {
            lastError = "Un bloque aprobado es inmutable. Crea una nueva versión del proyecto para modificarlo."
            return false
        }

        let safeTitle = ProjectGraphValidator.sanitizedSingleLine(title, limit: 80)
        let safeSummary = ProjectGraphValidator.sanitizedSingleLine(summary, limit: 500)
        guard !safeTitle.isEmpty else {
            lastError = "El bloque necesita un nombre."
            return false
        }

        var candidate = graph

        do {
            try candidate.updateBlockDetails(
                id: blockID,
                title: safeTitle,
                summary: safeSummary,
                family: family,
                state: state,
                architectureLayer: architectureLayer
            )
            graph = candidate
            editingBlockID = nil
            persistGraph()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func updateArchitectureLayer(for blockID: UUID, layer: ArchitectureLayer?) {
        mutate { candidate in
            guard let index = candidate.blocks.firstIndex(where: { $0.id == blockID }) else { return }
            candidate.blocks[index].architectureLayer = layer
            candidate.blocks[index].rowVersion += 1
            candidate.rowVersion += 1
        }
    }

    func moveArchitectureBlock(
        _ blockID: UUID,
        to layer: ArchitectureLayer,
        before targetID: UUID? = nil
    ) {
        var candidate = graph
        do {
            try candidate.moveArchitectureBlock(id: blockID, to: layer, before: targetID)
            try ProjectGraphValidator.validate(candidate)
            graph = candidate
            selectedBlockID = blockID
            selectedRelationID = nil
            persistGraph()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func relationDescription(_ relation: BlockRelation) -> String {
        let source = graph.block(id: relation.sourceID)?.title ?? "Bloque desconocido"
        let target = graph.block(id: relation.targetID)?.title ?? "Bloque desconocido"
        return "\(source) \(relation.type.displayName.lowercased()) \(target) · "
            + "\(relation.sourcePort.displayName.lowercased()) → "
            + "\(relation.targetPort.displayName.lowercased())"
    }

    private func mutate(_ operation: (inout ProjectGraph) -> Void) {
        var candidate = graph
        operation(&candidate)

        do {
            try ProjectGraphValidator.validate(candidate)
            graph = candidate
            persistGraph()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func persistGraph() {
        guard hasActiveProject else { return }
        rememberCurrentProject()
        guard let store else {
            saveState = .failed
            refreshAvailableProjectsFromMemory()
            return
        }

        saveState = .saving
        do {
            try store.save(graph, template: selectedProjectTemplate)
            try refreshAvailableProjects()
            saveState = .saved
        } catch {
            saveState = .failed
            lastError = "El cambio permanece visible, pero no se pudo guardar. \(error.localizedDescription)"
        }
    }

    private func rememberCurrentProject() {
        memoryProjects[graph.id] = graph
        memoryProjectTemplates[graph.id] = selectedProjectTemplate
        memoryProjectUpdatedAt[graph.id] = Date()
        memoryPlanningProfiles[graph.id] = planningProfile
    }

    private func refreshAvailableProjects() throws {
        if let store {
            availableProjects = try store.listProjects()
        } else {
            refreshAvailableProjectsFromMemory()
        }
    }

    private func refreshAvailableProjectsFromMemory() {
        availableProjects = memoryProjects.values
            .map { project in
                StoredProjectSummary(
                    id: project.id,
                    name: project.name,
                    template: memoryProjectTemplates[project.id] ?? .webApplication,
                    updatedAt: memoryProjectUpdatedAt[project.id] ?? .distantPast
                )
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func replaceWorkspaceWithPlaceholder(state: WorkspaceContentState) {
        let placeholder = ProjectGraph(name: "Sin proyecto activo")
        graph = placeholder
        planningProfile = ProjectPlanningProfile.defaultProfile(for: placeholder, roleRates: planningRoleRateSeeds)
        selectedProjectTemplate = .blankCanvas
        clearMemoryProjects()
        availableProjects = []
        workspaceContentState = state
        lastError = nil
        saveState = .saved
        resetWorkspaceForProjectChange()
    }

    private func clearMemoryProjects() {
        memoryProjects.removeAll()
        memoryProjectTemplates.removeAll()
        memoryProjectUpdatedAt.removeAll()
        memoryPlanningProfiles.removeAll()
    }

    private func resetWorkspaceForProjectChange() {
        selectedSection = .overview
        selectedDestinationID = AppSection.overview.contextualDestinations.first?.id
        selectedBlockID = nil
        selectedRelationID = nil
        editingBlockID = nil
        pendingBlockDeletionID = nil
        pendingRelationDeletionID = nil
        isInspectorPresented = false
        dismissTazki()
        selectedArchitectureLayer = nil
        projection = .canvas
        architectureProjection = .diagram
        projectMapTool = .select
        architectureTool = .select
        canvasResetRevision += 1
    }

}

private func applySuggestedArchitectureLayers(to graph: inout ProjectGraph) -> Bool {
    var changed = false
    for index in graph.blocks.indices where graph.blocks[index].architectureLayer == nil {
        guard let layer = graph.blocks[index].suggestedArchitectureLayer else { continue }
        graph.blocks[index].architectureLayer = layer
        changed = true
    }
    return changed
}

private extension ProjectBlock {
    var suggestedArchitectureLayer: ArchitectureLayer? {
        let searchable = "\(title) \(summary)".localizedLowercase
        if searchable.contains("base de datos") || searchable.contains("persistencia") {
            return .data
        }
        if searchable.contains("infraestructura") || searchable.contains("monitoreo") {
            return .infrastructure
        }
        return family.suggestedArchitectureLayer
    }
}

private extension BlockFamily {
    var suggestedArchitectureLayer: ArchitectureLayer? {
        switch self {
        case .product:
            .experience
        case .process, .technology:
            .services
        case .strategy, .people, .economy, .governance:
            nil
        }
    }
}

private enum ProjectTemplateFactory {
    static func make(
        name: String,
        template: ProjectTemplateKey,
        webTechnologies: WebTechnologySelection
    ) -> ProjectGraph {
        switch template {
        case .webApplication:
            WebProjectTemplateFactory.make(
                name: name,
                technologies: webTechnologies
            )
        case .blankCanvas:
            ProjectGraph(name: name)
        }
    }
}
