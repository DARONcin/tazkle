import SwiftUI
import TazkleDesignSystem
import TazkleDomain

struct NewBlockSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var title = ""
    @State private var summary = ""
    @State private var family: BlockFamily

    private enum Field {
        case title
        case summary
    }

    init(initialFamily: BlockFamily) {
        _family = State(initialValue: initialFamily)
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 80
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                    Text("Nuevo bloque")
                        .font(.title2.weight(.semibold))
                    Text("El bloque se guardará localmente en este proyecto.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(TazkleSpacing.xLarge)

            Form {
                Picker("Familia", selection: $family) {
                    ForEach(BlockFamily.allCases) { option in
                        Label(option.displayName, systemImage: option.systemImage)
                            .tag(option)
                    }
                }

                TextField("Nombre", text: $title)
                    .focused($focusedField, equals: .title)
                    .accessibilityHint("Máximo 80 caracteres")

                Text("\(title.count) de 80 caracteres")
                    .font(.caption)
                    .foregroundStyle(title.count > 80 ? TazkleColors.warning : .secondary)

                TextField("Descripción", text: $summary, axis: .vertical)
                    .lineLimit(3 ... 6)
                    .focused($focusedField, equals: .summary)
                    .accessibilityHint("Máximo 500 caracteres")

                Text("\(summary.count) de 500 caracteres")
                    .font(.caption)
                    .foregroundStyle(summary.count > 500 ? TazkleColors.warning : .secondary)
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancelar", role: .cancel) {
                    dismiss()
                }
                Spacer()
                Button("Crear bloque") {
                    appState.addBlock(title: title, summary: summary, family: family)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate || summary.count > 500)
            }
            .padding(TazkleSpacing.large)
        }
        .frame(width: 520, height: 520)
        .onAppear { focusedField = .title }
    }
}
