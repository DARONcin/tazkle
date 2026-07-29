import SwiftUI
import TazkleDesignSystem

struct ShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let shortcuts: [(action: String, keys: String)] = [
        ("Paleta de comandos", "⌘K"),
        ("Nuevo proyecto", "⌘N"),
        ("Nuevo bloque", "⇧⌘B"),
        ("Datos de factibilidad y cotización", "⇧⌘E"),
        ("Crear relación", "⌘L"),
        ("Abrir o cerrar Tazki", "⌥⌘T"),
        ("Mostrar u ocultar sidebar", "⌃⌘S"),
        ("Mostrar u ocultar inspector", "⌥⌘I"),
        ("Atajos de teclado", "⌘/")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Atajos de teclado")
                        .font(.title2.weight(.semibold))
                    Text("Los mismos comandos también aparecen en los menús de macOS.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(TazkleSpacing.xLarge)

            List(shortcuts, id: \.action) { shortcut in
                HStack {
                    Text(shortcut.action)
                    Spacer()
                    Text(shortcut.keys)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .padding(.horizontal, TazkleSpacing.small)
                        .padding(.vertical, TazkleSpacing.xSmall)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: TazkleRadius.control))
                }
                .accessibilityElement(children: .combine)
            }

            HStack {
                Spacer()
                Button("Cerrar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(TazkleSpacing.large)
        }
        .frame(width: 540, height: 470)
    }
}
