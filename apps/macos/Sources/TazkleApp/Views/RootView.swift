import SwiftUI
import TazkleAuthentication
import TazkleDesignSystem
import TazkleDomain

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authentication: AuthenticationController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.undoManager) private var undoManager
    @AppStorage("appearancePreference") private var appearance = AppearancePreference.automatic.rawValue

    private var highContrast: Bool {
        AppearancePreference(rawValue: appearance)?.usesHighContrastTokens == true
            || colorSchemeContrast == .increased
    }

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 238, max: 280)
        } detail: {
            detail
                .navigationTitle("")
                .background(TazkleColors.canvas(for: colorScheme, highContrast: highContrast))
                .overlay(alignment: .bottomTrailing) {
                    if appState.selectedSection != .settings,
                       !appState.isTazkiPresented {
                        TazkiFloatingButton {
                            appState.presentTazki()
                        }
                        .padding(TazkleSpacing.xLarge)
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(TazkleColors.actionPrimary)
        .environment(\.tazkleHighContrast, highContrast)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ProjectNavigationMenu()
            }
            ToolbarItem {
                SessionModeBadge()
            }
        }
        .inspector(isPresented: trailingPanelPresentation) {
            WorkspaceTrailingPanelView()
                .inspectorColumnWidth(min: 300, ideal: 332, max: 380)
        }
        .sheet(isPresented: $appState.isPresentingNewProject) {
            NewProjectFlow()
        }
        .sheet(isPresented: $appState.isPresentingPlanningProfile) {
            PlanningProfileSheet(profile: appState.planningProfile)
        }
        .sheet(isPresented: $appState.isPresentingNewBlock) {
            NewBlockSheet(initialFamily: appState.pendingFamily)
        }
        .sheet(isPresented: $appState.isPresentingNewRelation) {
            NewRelationSheet()
        }
        .sheet(isPresented: $appState.isPresentingShortcuts) {
            ShortcutsSheet()
        }
        .alert(
            "Eliminar bloque",
            isPresented: Binding(
                get: { appState.pendingBlockDeletion != nil },
                set: { if !$0 { appState.cancelBlockDeletion() } }
            ),
            presenting: appState.pendingBlockDeletion
        ) { block in
            Button("Cancelar", role: .cancel) {
                appState.cancelBlockDeletion()
            }
            Button("Eliminar bloque", role: .destructive) {
                deletePendingBlock()
            }
        } message: { block in
            Text(blockDeletionMessage(for: block))
        }
        .alert(
            "Eliminar relación",
            isPresented: Binding(
                get: { appState.pendingRelationDeletion != nil },
                set: { if !$0 { appState.cancelRelationDeletion() } }
            ),
            presenting: appState.pendingRelationDeletion
        ) { _ in
            Button("Cancelar", role: .cancel) {
                appState.cancelRelationDeletion()
            }
            Button("Eliminar relación", role: .destructive) {
                deletePendingRelation()
            }
        } message: { relation in
            Text(
                "Se eliminará “\(appState.relationDescription(relation))”. "
                    + "Podrás deshacer esta acción con ⌘Z."
            )
        }
        .alert(
            "No se pudo completar la operación",
            isPresented: Binding(
                get: { appState.lastError != nil },
                set: { if !$0 { appState.lastError = nil } }
            )
        ) {
            Button("Aceptar", role: .cancel) {
                appState.lastError = nil
            }
        } message: {
            Text(appState.lastError ?? "Error desconocido")
        }
    }

    private var trailingPanelPresentation: Binding<Bool> {
        Binding(
            get: {
                guard appState.selectedSection != .settings else { return false }
                let inspectorVisible = appState.isInspectorPresented
                    && (appState.selectedBlock != nil || appState.selectedRelation != nil)
                    && (appState.selectedSection == .projectMap
                        || appState.selectedSection == .architecture)
                return appState.isTazkiPresented || inspectorVisible
            },
            set: { isPresented in
                if !isPresented {
                    appState.isInspectorPresented = false
                    appState.dismissTazki()
                }
            }
        )
    }

    private func deletePendingBlock() {
        guard let snapshot = appState.confirmBlockDeletion() else { return }
        undoManager?.registerUndo(withTarget: appState) { target in
            target.restoreDeletedBlock(snapshot)
        }
        undoManager?.setActionName("Eliminar \(snapshot.block.title)")
    }

    private func deletePendingRelation() {
        guard let snapshot = appState.confirmRelationDeletion() else { return }
        undoManager?.registerUndo(withTarget: appState) { target in
            target.restoreDeletedRelation(snapshot)
        }
        undoManager?.setActionName("Eliminar relación")
    }

    private func blockDeletionMessage(for block: ProjectBlock) -> String {
        switch appState.graph.relationshipCount(for: block.id) {
        case 0:
            "Se eliminará “\(block.title)”. Podrás deshacer esta acción con ⌘Z."
        case 1:
            "Se eliminará “\(block.title)” y su relación. Podrás deshacer esta acción con ⌘Z."
        case let relationCount:
            "Se eliminará “\(block.title)” y sus \(relationCount) relaciones. Podrás deshacer esta acción con ⌘Z."
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch appState.selectedSection {
        case .overview:
            SummaryView()
        case .projectMap:
            ProjectMapView()
        case .architecture:
            ArchitectureView()
        case .team:
            TeamView()
        case .feasibility:
            FeasibilityView()
        case .costs:
            CostsView()
        case .workPlan:
            WorkPlanView()
        case .settings:
            AccountOrganizationView()
        }
    }
}

private struct SessionModeBadge: View {
    @EnvironmentObject private var authentication: AuthenticationController

    var body: some View {
        switch authentication.state {
        case .offline:
            Label("Sin conexión", systemImage: "wifi.slash")
                .foregroundStyle(TazkleColors.warning)
                .help("El trabajo permanece local hasta recuperar conexión")
                .accessibilityHint("La sincronización y la colaboración están pausadas.")
        case .localOnly:
            Label("Sólo en esta Mac", systemImage: "internaldrive")
                .foregroundStyle(TazkleColors.relationship)
                .help("No hay una sesión remota activa")
                .accessibilityHint("La sincronización y la colaboración no están habilitadas.")
        default:
            EmptyView()
        }
    }
}

private struct ProjectNavigationMenu: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Menu {
            Section("Proyectos locales") {
                ForEach(appState.availableProjects) { project in
                    Button {
                        appState.switchProject(to: project.id)
                    } label: {
                        if project.id == appState.graph.id {
                            Label(project.name, systemImage: "checkmark")
                        } else {
                            Text(project.name)
                        }
                    }
                    .help(project.template.title)
                }
            }

            Divider()

            Button("Nuevo proyecto…", systemImage: "plus") {
                appState.presentNewProject()
            }
        } label: {
            HStack(spacing: TazkleSpacing.small) {
                Image(systemName: "square.stack.3d.up")
                    .foregroundStyle(TazkleColors.actionPrimary)
                    .accessibilityHidden(true)

                Text(appState.graph.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel("Proyecto actual")
        .accessibilityValue(appState.graph.name)
        .accessibilityHint("Abre la lista para cambiar de proyecto o crear uno nuevo")
        .help("Cambiar proyecto")
    }
}
