import SwiftUI
import TazkleDesignSystem
import TazkleDomain

struct RelationInspectorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    @State private var isEditing = false
    @State private var sourceID = UUID()
    @State private var targetID = UUID()
    @State private var sourcePort = ConnectionPort.right
    @State private var targetPort = ConnectionPort.left
    @State private var type = RelationType.requires
    @State private var isCritical = false

    var body: some View {
        Group {
            if let relation = appState.selectedRelation {
                InspectorShell {
                    identity(relation)
                    endpoints(relation)
                    definition(relation)
                    localState(relation)
                    deletion(relation)
                }
                .onAppear { load(relation) }
                .onChange(of: relation.id) {
                    isEditing = false
                    load(relation)
                }
            } else {
                ContentUnavailableView(
                    "Sin selección",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("Selecciona una relación para consultar o editar su información.")
                )
            }
        }
    }

    private func identity(_ relation: BlockRelation) -> some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: TazkleRadius.control)
                        .fill(TazkleColors.relationship.opacity(0.17))
                        .frame(width: 42, height: 42)
                    Image(systemName: relation.isCritical
                        ? "exclamationmark.triangle.fill"
                        : "point.3.connected.trianglepath.dotted")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(
                            relation.isCritical ? TazkleColors.warning : TazkleColors.relationship
                        )
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                    Text(relation.type.displayName)
                        .font(.title3.weight(.semibold))
                    Text("Relación del proyecto")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TazkleColors.relationship)
                }

                Spacer(minLength: 0)

                Button {
                    appState.isInspectorPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Contraer inspector")
                .help("Contraer inspector")
            }

            Text(accessibleDescription(relation))
                .font(.callout)
                .foregroundStyle(
                    TazkleColors.secondaryContent(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Label(
                    relation.isCritical ? "Crítica" : "Normal",
                    systemImage: relation.isCritical
                        ? "exclamationmark.triangle.fill"
                        : "checkmark.circle"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    relation.isCritical ? TazkleColors.warning : TazkleColors.success
                )

                Spacer()

                if !isEditing {
                    Button("Editar", systemImage: "pencil") {
                        load(relation)
                        isEditing = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(!appState.canEditRelation(relation))
                    .help(
                        appState.canEditRelation(relation)
                            ? "Editar la relación"
                            : "Crea una nueva versión para editar alcance aprobado"
                    )
                }
            }
        }
        .padding(TazkleSpacing.large)
        .background(
            LinearGradient(
                colors: [
                    TazkleColors.relationship.opacity(0.17),
                    TazkleColors.elevated(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                    .opacity(highContrast ? 1 : 0.78),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.panel))
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.panel)
                .stroke(TazkleColors.relationship.opacity(0.42), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Relación seleccionada")
        .accessibilityValue(accessibleDescription(relation))
    }

    private func endpoints(_ relation: BlockRelation) -> some View {
        InspectorSectionCard(title: "Extremos", systemImage: "arrow.left.and.right") {
            if isEditing {
                Picker("Origen", selection: $sourceID) {
                    ForEach(appState.graph.blocks) { block in
                        Label(
                            block.title,
                            systemImage: block.state == .approved ? "lock.fill" : block.family.systemImage
                        )
                        .tag(block.id)
                        .disabled(block.state == .approved && block.id != relation.sourceID)
                    }
                }

                Picker("Puerto de salida", selection: $sourcePort) {
                    ForEach(ConnectionPort.allCases) { port in
                        Text(port.displayName).tag(port)
                    }
                }

                Divider()

                Picker("Destino", selection: $targetID) {
                    ForEach(appState.graph.blocks) { block in
                        Label(
                            block.title,
                            systemImage: block.state == .approved ? "lock.fill" : block.family.systemImage
                        )
                        .tag(block.id)
                        .disabled(block.state == .approved && block.id != relation.targetID)
                    }
                }

                Picker("Puerto de entrada", selection: $targetPort) {
                    ForEach(ConnectionPort.allCases) { port in
                        Text(port.displayName).tag(port)
                    }
                }

                if sourceID == targetID {
                    Label(
                        "El origen y el destino deben ser bloques distintos.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(TazkleColors.warning)
                }
            } else {
                LabeledContent("Origen") {
                    Text(blockTitle(relation.sourceID))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Salida", value: relation.sourcePort.displayName)
                Divider()
                LabeledContent("Destino") {
                    Text(blockTitle(relation.targetID))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Entrada", value: relation.targetPort.displayName)
            }
        }
    }

    private func definition(_ relation: BlockRelation) -> some View {
        InspectorSectionCard(title: "Definición", systemImage: "slider.horizontal.3") {
            if isEditing {
                Picker("Tipo de relación", selection: $type) {
                    ForEach(RelationType.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }

                Toggle("Marcar como relación crítica", isOn: $isCritical)

                HStack {
                    Button("Cancelar", role: .cancel) {
                        load(relation)
                        isEditing = false
                    }
                    Spacer()
                    Button("Guardar cambios") {
                        if appState.updateRelationDetails(
                            for: relation.id,
                            sourceID: sourceID,
                            targetID: targetID,
                            sourcePort: sourcePort,
                            targetPort: targetPort,
                            type: type,
                            isCritical: isCritical
                        ) {
                            isEditing = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TazkleColors.actionPrimary)
                    .disabled(sourceID == targetID)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            } else {
                LabeledContent("Tipo", value: relation.type.displayName)
                LabeledContent("Prioridad") {
                    Label(
                        relation.isCritical ? "Crítica" : "Normal",
                        systemImage: relation.isCritical
                            ? "exclamationmark.triangle.fill"
                            : "checkmark.circle"
                    )
                    .foregroundStyle(
                        relation.isCritical ? TazkleColors.warning : TazkleColors.success
                    )
                }
            }
        }
    }

    private func localState(_ relation: BlockRelation) -> some View {
        InspectorSectionCard(title: "Copia local", systemImage: appState.saveState.systemImage) {
            LabeledContent("Estado", value: appState.saveState.title)
            LabeledContent("Versión", value: "\(relation.rowVersion)")
        }
    }

    private func deletion(_ relation: BlockRelation) -> some View {
        Button("Eliminar relación", systemImage: "trash", role: .destructive) {
            appState.requestRelationDeletion(relation.id)
        }
        .buttonStyle(.borderless)
        .disabled(!appState.canDeleteRelation(relation))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TazkleSpacing.small)
        .help(
            appState.canDeleteRelation(relation)
                ? "Elimina la relación después de confirmar"
                : "Las relaciones aprobadas requieren una nueva versión"
        )
    }

    private func load(_ relation: BlockRelation) {
        sourceID = relation.sourceID
        targetID = relation.targetID
        sourcePort = relation.sourcePort
        targetPort = relation.targetPort
        type = relation.type
        isCritical = relation.isCritical
    }

    private func blockTitle(_ id: UUID) -> String {
        appState.graph.block(id: id)?.title ?? "Bloque desconocido"
    }

    private func accessibleDescription(_ relation: BlockRelation) -> String {
        "\(blockTitle(relation.sourceID)), \(relation.type.displayName.lowercased()), "
            + "\(blockTitle(relation.targetID)). Sale por \(relation.sourcePort.displayName.lowercased()) "
            + "y entra por \(relation.targetPort.displayName.lowercased()). "
            + (relation.isCritical ? "Relación crítica." : "Relación normal.")
    }
}
