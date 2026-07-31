import SwiftUI
import TazkleDesignSystem

struct PreferencesView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("appearancePreference") private var appearance = AppearancePreference.automatic.rawValue
    @AppStorage("tazkiAnimationsEnabled") private var tazkiAnimationsEnabled = true
    @AppStorage("interfaceSoundsEnabled") private var interfaceSoundsEnabled = false

    var body: some View {
        Form {
            Section("Apariencia") {
                Picker("Tema", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { preference in
                        Text(preference.title).tag(preference.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text("Automático sigue la configuración de macOS. Mayor contraste utiliza tokens reforzados sin sustituir las preferencias del sistema.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Movimiento y sonido") {
                Toggle("Animaciones de Tazki", isOn: $tazkiAnimationsEnabled)
                Toggle("Sonidos de interfaz", isOn: $interfaceSoundsEnabled)
                Text("Reduce Motion y Reduce Transparency siempre se respetan desde las preferencias de macOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Teclado") {
                Button("Ver atajos de teclado") {
                    appState.isPresentingShortcuts = true
                }
            }
        }
        .formStyle(.grouped)
        .padding(TazkleSpacing.large)
        .navigationTitle(appState.selectedDestination?.title ?? "Configuración")
    }
}
