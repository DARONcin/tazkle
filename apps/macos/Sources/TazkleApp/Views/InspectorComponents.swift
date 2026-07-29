import SwiftUI
import TazkleDesignSystem
import TazkleDomain

struct InspectorShell<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TazkleSpacing.medium) {
                content
            }
            .padding(TazkleSpacing.large)
        }
        .background(
            TazkleColors.panel(
                for: colorScheme,
                highContrast: highContrast
            )
        )
    }
}

struct InspectorSectionCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    TazkleColors.primaryContent(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )

            content
        }
        .padding(TazkleSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            TazkleColors.elevated(
                for: colorScheme,
                highContrast: highContrast
            )
            .opacity(highContrast ? 1 : 0.72)
        )
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.card)
                .stroke(
                    TazkleColors.separator(
                        for: colorScheme,
                        highContrast: highContrast
                    ),
                    lineWidth: highContrast ? 1.5 : 1
                )
        }
    }
}

struct InspectorStatusChip: View {
    let state: BlockState

    private var color: Color {
        switch state {
        case .draft: .secondary
        case .ready: TazkleColors.actionPrimary
        case .warning: TazkleColors.warning
        case .approved: TazkleColors.success
        }
    }

    var body: some View {
        Label(state.displayName, systemImage: state.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.34), lineWidth: 1)
            }
    }
}

struct BlockIdentityInspector: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    @FocusState private var focusedField: Field?

    let block: ProjectBlock
    let showsArchitectureLayer: Bool
    let collapseLabel: String

    @State private var title = ""
    @State private var summary = ""
    @State private var family = BlockFamily.product
    @State private var state = BlockState.draft
    @State private var architectureLayer: ArchitectureLayer?

    private enum Field {
        case title
        case summary
    }

    private var isEditing: Bool {
        appState.editingBlockID == block.id
    }

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty
            && title.count <= 80
            && summary.count <= 500
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            header

            if isEditing {
                editor
            } else {
                Text(block.summary.isEmpty ? "Sin descripción." : block.summary)
                    .font(.callout)
                    .foregroundStyle(
                        TazkleColors.secondaryContent(
                            for: colorScheme,
                            highContrast: highContrast
                        )
                    )
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    InspectorStatusChip(state: block.state)
                    Spacer()
                    Button("Editar", systemImage: "pencil") {
                        appState.beginEditingBlock(block.id)
                    }
                    .buttonStyle(.bordered)
                    .disabled(block.state == .approved)
                    .help(
                        block.state == .approved
                            ? "Crea una nueva versión para editar un bloque aprobado"
                            : "Editar información del bloque"
                    )
                }
            }
        }
        .padding(TazkleSpacing.large)
        .background(
            LinearGradient(
                colors: [
                    (block.architectureLayer?.accentColor ?? block.family.accentColor).opacity(0.17),
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
                .stroke(
                    (block.architectureLayer?.accentColor ?? block.family.accentColor).opacity(0.42),
                    lineWidth: 1
                )
        }
        .onAppear { load(block) }
        .onChange(of: block.id) {
            load(block)
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                load(block)
                focusedField = .title
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: TazkleSpacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: TazkleRadius.control)
                    .fill((block.architectureLayer?.accentColor ?? block.family.accentColor).opacity(0.17))
                    .frame(width: 42, height: 42)
                Image(systemName: block.architectureLayer?.systemImage ?? block.family.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(block.architectureLayer?.accentColor ?? block.family.accentColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                Text(block.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(
                        TazkleColors.primaryContent(
                            for: colorScheme,
                            highContrast: highContrast
                        )
                    )
                    .lineLimit(2)
                Text(block.family.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(block.family.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(block.family.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer(minLength: 0)

            Button {
                appState.isInspectorPresented = false
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(collapseLabel)
            .help(collapseLabel)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                Text("Nombre")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Nombre del bloque", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .title)
                    .accessibilityHint("Máximo 80 caracteres")
                characterCount(title.count, limit: 80)
            }

            VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                Text("Descripción")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Propósito, alcance y datos relevantes", text: $summary, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3 ... 6)
                    .focused($focusedField, equals: .summary)
                    .accessibilityHint("Máximo 500 caracteres")
                characterCount(summary.count, limit: 500)
            }

            Picker("Familia", selection: $family) {
                ForEach(BlockFamily.allCases) { option in
                    Label(option.displayName, systemImage: option.systemImage)
                        .tag(option)
                }
            }

            Picker("Estado", selection: $state) {
                ForEach(BlockState.allCases) { option in
                    Label(option.displayName, systemImage: option.systemImage)
                        .tag(option)
                }
            }

            if showsArchitectureLayer {
                Picker("Capa", selection: $architectureLayer) {
                    Text("Sin asignar")
                        .tag(nil as ArchitectureLayer?)
                    ForEach(ArchitectureLayer.allCases) { option in
                        Label(option.displayName, systemImage: option.systemImage)
                            .tag(option as ArchitectureLayer?)
                    }
                }
            }

            HStack {
                Button("Cancelar", role: .cancel) {
                    load(block)
                    appState.cancelEditingBlock()
                }
                Spacer()
                Button("Guardar cambios") {
                    _ = appState.updateBlockDetails(
                        for: block.id,
                        title: title,
                        summary: summary,
                        family: family,
                        state: state,
                        architectureLayer: showsArchitectureLayer
                            ? architectureLayer
                            : block.architectureLayer
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(TazkleColors.actionPrimary)
                .disabled(!canSave)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }

    private func characterCount(_ count: Int, limit: Int) -> some View {
        Text("\(count) de \(limit)")
            .font(.caption2)
            .foregroundStyle(count > limit ? TazkleColors.warning : .secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func load(_ block: ProjectBlock) {
        title = block.title
        summary = block.summary
        family = block.family
        state = block.state
        architectureLayer = block.architectureLayer
    }
}
