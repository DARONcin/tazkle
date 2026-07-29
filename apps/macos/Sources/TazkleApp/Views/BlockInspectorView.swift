import SwiftUI
import TazkleDesignSystem
import TazkleDomain

struct BlockInspectorView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let block = appState.selectedBlock {
                InspectorShell {
                    BlockIdentityInspector(
                        block: block,
                        showsArchitectureLayer: false,
                        collapseLabel: "Contraer inspector"
                    )

                    structure(block)
                    relationships(block)
                    localState(block)
                    deletion(block)
                }
            } else {
                ContentUnavailableView(
                    "Sin selección",
                    systemImage: "rectangle.dashed",
                    description: Text("Selecciona un bloque para consultar o editar su información.")
                )
            }
        }
    }

    private func structure(_ block: ProjectBlock) -> some View {
        InspectorSectionCard(title: "Estructura", systemImage: "square.grid.2x2") {
            LabeledContent("Familia", value: block.family.displayName)
            LabeledContent("Estado") {
                InspectorStatusChip(state: block.state)
            }
            LabeledContent("Posición") {
                Text("\(Int(block.position.x)), \(Int(block.position.y))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func relationships(_ block: ProjectBlock) -> some View {
        let relations = appState.graph.relations.filter {
            $0.sourceID == block.id || $0.targetID == block.id
        }

        return InspectorSectionCard(title: "Relaciones", systemImage: "point.3.connected.trianglepath.dotted") {
            HStack {
                Text(
                    relations.isEmpty
                        ? "Sin conexiones todavía"
                        : "\(relations.count) \(relations.count == 1 ? "conexión" : "conexiones")"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                Spacer()
                Button("Añadir", systemImage: "plus") {
                    appState.beginRelation(sourceID: block.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ForEach(relations) { relation in
                HStack(alignment: .top, spacing: TazkleSpacing.small) {
                    Button {
                        appState.selectRelation(relation.id)
                    } label: {
                        HStack(alignment: .top, spacing: TazkleSpacing.small) {
                            Image(systemName: relation.isCritical ? "exclamationmark.triangle.fill" : "arrow.turn.down.right")
                                .foregroundStyle(
                                    relation.isCritical ? TazkleColors.warning : TazkleColors.relationship
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

    private func localState(_ block: ProjectBlock) -> some View {
        InspectorSectionCard(title: "Copia local", systemImage: appState.saveState.systemImage) {
            HStack {
                Text(appState.saveState.title)
                    .font(.callout)
                Spacer()
                Text("v\(block.rowVersion)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func deletion(_ block: ProjectBlock) -> some View {
        Button("Eliminar bloque", systemImage: "trash", role: .destructive) {
            appState.requestBlockDeletion(block.id)
        }
        .buttonStyle(.borderless)
        .disabled(block.state == .approved)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TazkleSpacing.small)
        .help(
            block.state == .approved
                ? "Los bloques aprobados requieren una nueva versión del proyecto"
                : "Elimina el bloque y sus relaciones después de confirmar"
        )
    }
}
