import SwiftUI
import TazkleDesignSystem
import TazkleDomain

struct NewRelationSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var sourceID: UUID?
    @State private var targetID: UUID?
    @State private var sourcePort: ConnectionPort = .right
    @State private var targetPort: ConnectionPort = .left
    @State private var relationType: RelationType = .requires
    @State private var isCritical = false

    private var usesDroppedEndpoints: Bool {
        appState.pendingRelationSourceID != nil && appState.pendingRelationTargetID != nil
    }

    private var canCreate: Bool {
        guard let sourceID, let targetID else { return false }
        return sourceID != targetID
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                Text(usesDroppedEndpoints ? "Confirmar relación" : "Definir relación")
                    .font(.title2.weight(.semibold))
                Text(
                    usesDroppedEndpoints
                        ? "Los extremos ya están conectados. Define el significado antes de guardar."
                        : "Confirma el significado de la conexión entre los bloques."
                )
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TazkleSpacing.xLarge)

            Form {
                if usesDroppedEndpoints {
                    Section {
                        LabeledContent("Origen", value: blockTitle(for: sourceID))
                        LabeledContent("Punto de salida", value: sourcePort.displayName)
                        LabeledContent("Destino", value: blockTitle(for: targetID))
                        LabeledContent("Punto de entrada", value: targetPort.displayName)
                    } header: {
                        Label("Conexión creada por arrastre", systemImage: "cursorarrow.motionlines")
                    }
                } else {
                    Picker("Origen", selection: $sourceID) {
                        Text("Seleccionar bloque").tag(nil as UUID?)
                        ForEach(appState.graph.blocks) { block in
                            Text(block.title).tag(block.id as UUID?)
                        }
                    }
                }

                if !usesDroppedEndpoints {
                    Picker("Punto de salida", selection: $sourcePort) {
                        ForEach(ConnectionPort.allCases) { port in
                            Text(port.displayName).tag(port)
                        }
                    }
                }

                Picker("Tipo de relación", selection: $relationType) {
                    ForEach(RelationType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                if !usesDroppedEndpoints {
                    Picker("Destino", selection: $targetID) {
                        Text("Seleccionar bloque").tag(nil as UUID?)
                        ForEach(appState.graph.blocks) { block in
                            Text(block.title).tag(block.id as UUID?)
                        }
                    }

                    Picker("Punto de entrada", selection: $targetPort) {
                        ForEach(ConnectionPort.allCases) { port in
                            Text(port.displayName).tag(port)
                        }
                    }
                }

                Toggle("Dependencia crítica", isOn: $isCritical)

                Section("Vista previa") {
                    Text(previewText)
                        .foregroundStyle(canCreate ? .primary : .secondary)
                    if sourceID == targetID, sourceID != nil {
                        Label("El origen y el destino deben ser diferentes.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(TazkleColors.warning)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancelar", role: .cancel) {
                    appState.clearPendingRelation()
                    dismiss()
                }
                Spacer()
                Button("Crear relación") {
                    guard let sourceID, let targetID else { return }
                    appState.addRelation(
                        sourceID: sourceID,
                        targetID: targetID,
                        sourcePort: sourcePort,
                        targetPort: targetPort,
                        type: relationType,
                        isCritical: isCritical
                    )
                    appState.clearPendingRelation()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate)
            }
            .padding(TazkleSpacing.large)
        }
        .frame(width: 560, height: usesDroppedEndpoints ? 500 : 560)
        .onAppear {
            sourceID = appState.pendingRelationSourceID
                ?? appState.selectedBlockID
                ?? appState.graph.blocks.first?.id
            targetID = appState.pendingRelationTargetID
                ?? appState.graph.blocks.first { $0.id != sourceID }?.id
            sourcePort = appState.pendingRelationSourcePort ?? .right
            targetPort = appState.pendingRelationTargetPort ?? .left
        }
        .onDisappear {
            appState.clearPendingRelation()
        }
    }

    private var previewText: String {
        guard
            let sourceID,
            let targetID,
            let source = appState.graph.block(id: sourceID),
            let target = appState.graph.block(id: targetID)
        else {
            return "Selecciona dos bloques para describir la relación."
        }
        return "\(source.title) \(relationType.displayName.lowercased()) \(target.title)."
    }

    private func blockTitle(for blockID: UUID?) -> String {
        guard let blockID, let block = appState.graph.block(id: blockID) else {
            return "Bloque no disponible"
        }
        return block.title
    }
}
