import SwiftUI
import TazkleDesignSystem
import TazkleDomain

struct ArchitectureInspectorView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let block = appState.selectedBlock {
                InspectorShell {
                    BlockIdentityInspector(
                        block: block,
                        showsArchitectureLayer: true,
                        collapseLabel: "Contraer detalle técnico"
                    )

                    classification(block)
                    dependencies(block)
                    localEvidence(block)
                }
            } else {
                ContentUnavailableView(
                    "Sin selección",
                    systemImage: "square.3.layers.3d",
                    description: Text("Selecciona un bloque para consultar o editar su definición técnica.")
                )
            }
        }
    }

    private func classification(_ block: ProjectBlock) -> some View {
        InspectorSectionCard(title: "Clasificación técnica", systemImage: "square.3.layers.3d") {
            LabeledContent("Capa") {
                Label(
                    block.architectureLayer?.displayName ?? "Sin asignar",
                    systemImage: block.architectureLayer?.systemImage ?? "questionmark.square.dashed"
                )
                .foregroundStyle(block.architectureLayer?.accentColor ?? .secondary)
            }
            LabeledContent("Familia", value: block.family.displayName)
            LabeledContent("Estado") {
                InspectorStatusChip(state: block.state)
            }
        }
    }

    private func dependencies(_ block: ProjectBlock) -> some View {
        let outgoing = appState.graph.relations.filter { $0.sourceID == block.id }
        let incoming = appState.graph.relations.filter { $0.targetID == block.id }

        return InspectorSectionCard(title: "Dependencias", systemImage: "arrow.triangle.branch") {
            HStack {
                Text("\(outgoing.count) salientes · \(incoming.count) entrantes")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Añadir", systemImage: "plus") {
                    appState.beginRelation(sourceID: block.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            dependencyGroup("Salientes", relations: outgoing)
            dependencyGroup("Entrantes", relations: incoming)
        }
    }

    private func dependencyGroup(_ title: String, relations: [BlockRelation]) -> some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            if relations.isEmpty {
                Text("Ninguna")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(relations) { relation in
                    HStack(alignment: .top, spacing: TazkleSpacing.small) {
                        Button {
                            appState.selectRelation(relation.id)
                        } label: {
                            HStack(alignment: .top, spacing: TazkleSpacing.small) {
                                Image(systemName: relation.isCritical ? "exclamationmark.triangle.fill" : "arrow.turn.down.right")
                                    .foregroundStyle(
                                        relation.isCritical ? TazkleColors.warning : TazkleColors.assistantProposal
                                    )
                                Text(appState.relationDescription(relation))
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Abrir inspector de la relación")
                        Spacer(minLength: TazkleSpacing.small)
                        Button("Eliminar relación", systemImage: "trash", role: .destructive) {
                            appState.requestRelationDeletion(relation.id)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .disabled(!appState.canDeleteRelation(relation))
                    }
                    .contextMenu {
                        Button("Eliminar relación", systemImage: "trash", role: .destructive) {
                            appState.requestRelationDeletion(relation.id)
                        }
                        .disabled(!appState.canDeleteRelation(relation))
                    }
                }
            }
        }
    }

    private func localEvidence(_ block: ProjectBlock) -> some View {
        InspectorSectionCard(title: "Evidencia local", systemImage: appState.saveState.systemImage) {
            LabeledContent("Versión", value: "\(block.rowVersion)")
            LabeledContent("Relaciones", value: "\(appState.graph.relationshipCount(for: block.id))")
            Label(appState.saveState.title, systemImage: appState.saveState.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
