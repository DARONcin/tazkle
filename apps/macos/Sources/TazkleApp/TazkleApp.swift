import SwiftUI
import TazkleAuthentication

@main
struct TazkleDesktopApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authentication = AuthenticationController()
    @AppStorage("appearancePreference") private var appearance = AppearancePreference.automatic.rawValue

    private var appearancePreference: AppearancePreference {
        AppearancePreference(rawValue: appearance) ?? .automatic
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authentication.state.permitsWorkspace {
                    RootView()
                } else {
                    AuthenticationGateView()
                }
            }
                .environmentObject(appState)
                .environmentObject(authentication)
                .preferredColorScheme(appearancePreference.preferredColorScheme)
                .frame(minWidth: 980, minHeight: 680)
        }
        .defaultSize(width: 1_420, height: 900)
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .newItem) {
                Button("Nuevo proyecto…") {
                    appState.presentNewProject()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!authentication.state.permitsWorkspace)

                Button("Nuevo bloque") {
                    appState.presentNewBlock()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(!authentication.state.permitsWorkspace)
            }

            CommandMenu("Proyecto") {
                Button("Datos de factibilidad y cotización…") {
                    appState.presentPlanningProfile()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!authentication.state.permitsWorkspace)
            }

            CommandMenu("Mapa") {
                Button("Crear relación") {
                    appState.beginRelation(sourceID: appState.selectedBlockID)
                }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(appState.graph.blocks.count < 2)

                Divider()

                Picker("Proyección", selection: $appState.projection) {
                    ForEach(MapProjection.allCases) { projection in
                        Text(projection.title).tag(projection)
                    }
                }

                Button("Volver al origen del lienzo") {
                    appState.canvasResetRevision += 1
                }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(
                    appState.selectedSection != .projectMap
                        && appState.selectedSection != .architecture
                )

                Button("Mostrar u ocultar inspector") {
                    appState.isInspectorPresented.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])

                Divider()

                Button("Eliminar selección", role: .destructive) {
                    appState.requestSelectionDeletion()
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(
                    (appState.selectedRelation == nil && appState.selectedBlock == nil)
                        || (appState.selectedRelation.map { !appState.canDeleteRelation($0) } ?? false)
                        || appState.selectedBlock?.state == .approved
                )
            }

            CommandMenu("Tazki") {
                Button(appState.isTazkiPresented ? "Cerrar Tazki" : "Abrir Tazki") {
                    appState.toggleTazki()
                }
                .keyboardShortcut("t", modifiers: [.command, .option])
                .disabled(appState.selectedSection == .settings)

                Divider()

                Button("Preguntar sobre la selección") {
                    appState.presentTazki()
                }
                .disabled(
                    appState.selectedSection == .settings
                        || (appState.selectedSection != .projectMap
                            && appState.selectedSection != .architecture)
                        || appState.selectedBlock == nil
                )
            }

            CommandMenu("Ayuda de Tazkle") {
                Button("Atajos de teclado") {
                    appState.isPresentingShortcuts = true
                }
                .keyboardShortcut("/", modifiers: .command)
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(appState)
                .environmentObject(authentication)
                .preferredColorScheme(appearancePreference.preferredColorScheme)
                .frame(width: 520, height: 320)
        }
    }
}
