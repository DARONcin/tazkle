import SwiftUI
import TazkleAuthentication
import TazkleDesignSystem
import TazkleDomain

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            BrandHeader()

            GeometryReader { geometry in
                let sectionHeight = max(0, (geometry.size.height - 1) / 2)

                VStack(spacing: 0) {
                    List {
                        Section("Apartados del proyecto") {
                            ForEach(AppSection.allCases.filter { $0 != .settings }) { section in
                                SidebarRow(section: section)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .frame(height: sectionHeight)
                    .accessibilityLabel("Apartados del proyecto")

                    Divider()

                    Group {
                        switch appState.selectedSection {
                        case .projectMap:
                            BlockLibraryView()
                        case .architecture:
                            ArchitectureLibraryView()
                        default:
                            ContextualNavigationView(section: appState.selectedSection)
                        }
                    }
                    .frame(height: sectionHeight)
                }
            }

            Divider()
            ProfileAccessCard()
        }
    }
}

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: TazkleSpacing.medium) {
            BrandMarkView()
                .frame(width: 28, height: 28)
                .clipped()

            BrandWordmarkView()
                .frame(width: 104, height: 18)
                .clipped()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: 60)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tazkle")
    }
}

private struct ContextualNavigationView: View {
    @EnvironmentObject private var appState: AppState
    let section: AppSection

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            Text(section.contextualTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ScrollView {
                LazyVStack(spacing: TazkleSpacing.xSmall) {
                    ForEach(section.contextualDestinations) { destination in
                        Button {
                            appState.selectDestination(destination)
                        } label: {
                            Label(destination.title, systemImage: destination.systemImage)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, TazkleSpacing.medium)
                        .padding(.vertical, TazkleSpacing.small)
                        .background(
                            appState.selectedDestination?.id == destination.id
                                ? TazkleColors.actionPrimary.opacity(0.18)
                                : .clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.control))
                        .accessibilityAddTraits(
                            appState.selectedDestination?.id == destination.id
                                ? .isSelected
                                : []
                        )
                    }
                }
            }
        }
        .padding(TazkleSpacing.large)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(section.contextualTitle)
    }
}

private struct ProfileAccessCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authentication: AuthenticationController

    var body: some View {
        Button {
            appState.selectSection(.settings)
        } label: {
            HStack(spacing: TazkleSpacing.medium) {
                Image(systemName: identitySystemImage)
                    .font(.title2)
                    .foregroundStyle(TazkleColors.assistantProposal)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(identityTitle)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(identityDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(TazkleSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                appState.selectedSection == .settings
                    ? TazkleColors.actionPrimary.opacity(0.18)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.control))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, TazkleSpacing.medium)
        .padding(.vertical, TazkleSpacing.small)
        .accessibilityLabel("Perfil y configuración")
        .accessibilityValue("\(identityTitle), \(identityDetail)")
        .accessibilityHint("Abre el perfil y las preferencias de Tazkle")
        .accessibilityAddTraits(appState.selectedSection == .settings ? .isSelected : [])
    }

    private var identityTitle: String {
        if let user = authentication.user {
            return user.displayName
        }
        return switch authentication.state {
        case .localOnly: "Espacio local"
        case .offline: "Sesión sin conexión"
        default: "Cuenta de Tazkle"
        }
    }

    private var identityDetail: String {
        if let email = authentication.user?.email {
            return email
        }
        return switch authentication.state {
        case .localOnly: "Sin cuenta conectada"
        case .offline: "Identidad no disponible"
        case .authenticated: "Identidad conectada"
        default: "Configurar acceso"
        }
    }

    private var identitySystemImage: String {
        switch authentication.state {
        case .authenticated: "person.crop.circle.badge.checkmark"
        case .offline: "person.crop.circle.badge.exclamationmark"
        case .localOnly: "internaldrive"
        default: "person.crop.circle"
        }
    }
}

private struct ArchitectureLibraryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchQuery = ""

    private var matchingBlocks: [ProjectBlock] {
        appState.graph.blocks.filter { block in
            guard block.architectureLayer != nil else { return false }
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            return query.isEmpty
                || block.title.localizedCaseInsensitiveContains(query)
                || block.summary.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            Text("Bloques de arquitectura")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextField("Buscar bloques", text: $searchQuery)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: TazkleSpacing.medium) {
                    ForEach(ArchitectureLayer.allCases) { layer in
                        let blocks = matchingBlocks.filter { $0.architectureLayer == layer }
                        if !blocks.isEmpty {
                            Label(layer.displayName, systemImage: layer.systemImage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(blocks) { block in
                                ArchitectureLibraryRow(block: block, layer: layer)
                            }
                        }
                    }

                    if matchingBlocks.isEmpty {
                        Text("No se encontraron bloques.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, TazkleSpacing.medium)
                    }
                }
            }

            Button {
                appState.presentNewBlock(family: .technology)
            } label: {
                Label("Nuevo bloque técnico", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(TazkleSpacing.large)
    }
}

private struct SidebarRow: View {
    @EnvironmentObject private var appState: AppState
    let section: AppSection

    var body: some View {
        Button {
            appState.selectSection(section)
        } label: {
            Label(section.title, systemImage: section.systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: TazkleRadius.control)
                .fill(
                    appState.selectedSection == section
                        ? TazkleColors.actionPrimary.opacity(0.18)
                        : .clear
                )
        )
        .accessibilityAddTraits(appState.selectedSection == section ? .isSelected : [])
    }
}

private struct BlockLibraryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            Text("Biblioteca de bloques")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ScrollView {
                VStack(spacing: TazkleSpacing.xSmall) {
                    ForEach(BlockFamily.allCases) { family in
                        BlockLibraryRow(family: family)
                    }
                }
            }

            Button {
                appState.presentNewBlock()
            } label: {
                Label("Nuevo bloque", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(TazkleSpacing.large)
    }
}

private struct ArchitectureLibraryRow: View {
    @EnvironmentObject private var appState: AppState
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    let block: ProjectBlock
    let layer: ArchitectureLayer

    private var backgroundColor: Color {
        if appState.selectedBlockID == block.id {
            return layer.accentColor.opacity(0.16)
        }
        return isHovered ? layer.accentColor.opacity(0.08) : .clear
    }

    var body: some View {
        HStack(spacing: TazkleSpacing.small) {
            Image(systemName: layer.systemImage)
                .foregroundStyle(layer.accentColor)
            Text(block.title)
                .lineLimit(1)
            Spacer()
            Image(systemName: "hand.draw")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isHovered ? layer.accentColor : .secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, TazkleSpacing.small)
        .padding(.horizontal, TazkleSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.control))
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: TazkleRadius.control)
                    .stroke(TazkleColors.actionPrimary, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectBlock(block.id)
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(.return) {
            appState.selectBlock(block.id)
            return .handled
        }
        .onKeyPress(.space) {
            appState.selectBlock(block.id)
            return .handled
        }
        .onDrag {
            NSItemProvider(
                object: CanvasDragPayload.existingBlock(block.id).rawValue as NSString
            )
        } preview: {
            ArchitectureLibraryDragPreview(block: block, layer: layer)
        }
        .onHover { isHovered = $0 }
        .help("Arrastra \(block.title) al lienzo o selecciónalo para ver su detalle")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(block.title)
        .accessibilityValue("\(layer.displayName), \(block.state.displayName)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            appState.selectBlock(block.id)
        }
        .accessibilityHint(
            "Arrastra el componente al lienzo. También puedes seleccionarlo y cambiar su capa con las acciones del diagrama."
        )
        .accessibilityAction(named: "Mover a Experiencia") {
            appState.moveArchitectureBlock(block.id, to: .experience)
        }
        .accessibilityAction(named: "Mover a Servicios") {
            appState.moveArchitectureBlock(block.id, to: .services)
        }
        .accessibilityAction(named: "Mover a Datos") {
            appState.moveArchitectureBlock(block.id, to: .data)
        }
        .accessibilityAction(named: "Mover a Infraestructura") {
            appState.moveArchitectureBlock(block.id, to: .infrastructure)
        }
    }
}

private struct BlockLibraryRow: View {
    @EnvironmentObject private var appState: AppState
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    let family: BlockFamily

    var body: some View {
        HStack(spacing: TazkleSpacing.small) {
            Image(systemName: family.systemImage)
                .foregroundStyle(family.accentColor)
            Text(family.displayName)
            Spacer()
            Text("\(appState.graph.blocks.count { $0.family == family })")
                .foregroundStyle(.secondary)
            Image(systemName: "hand.draw")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isHovered ? family.accentColor : .secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, TazkleSpacing.small)
        .padding(.horizontal, TazkleSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovered ? family.accentColor.opacity(0.08) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.control))
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: TazkleRadius.control)
                    .stroke(TazkleColors.actionPrimary, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            appState.presentNewBlock(family: family)
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(.return) {
            appState.presentNewBlock(family: family)
            return .handled
        }
        .onKeyPress(.space) {
            appState.presentNewBlock(family: family)
            return .handled
        }
        .onDrag {
            NSItemProvider(
                object: CanvasDragPayload.blockTemplate(family).rawValue as NSString
            )
        } preview: {
            BlockTemplateDragPreview(family: family)
        }
        .onHover { isHovered = $0 }
        .help("Arrastra \(family.displayName) al lienzo o selecciónalo para configurarlo")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(family.displayName)
        .accessibilityValue(
            "\(appState.graph.blocks.count { $0.family == family }) bloques en el proyecto"
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            appState.presentNewBlock(family: family)
        }
        .accessibilityHint(
            "Arrastra esta familia al lienzo para crear un bloque en el punto de caída. Actívala para abrir el formulario."
        )
    }
}

private struct ArchitectureLibraryDragPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    let block: ProjectBlock
    let layer: ArchitectureLayer

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            HStack {
                Image(systemName: layer.systemImage)
                    .font(.headline)
                    .foregroundStyle(layer.accentColor)
                Text(block.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "hand.draw.fill")
                    .foregroundStyle(layer.accentColor)
                    .accessibilityHidden(true)
            }

            Text(block.summary.isEmpty ? "Sin descripción técnica." : block.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(layer.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(layer.accentColor)
        }
        .padding(TazkleSpacing.large)
        .frame(width: 218, height: 128, alignment: .topLeading)
        .background(
            TazkleColors.elevated(
                for: colorScheme,
                highContrast: highContrast
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.card)
                .stroke(layer.accentColor, lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.28), radius: 20, y: 10)
    }
}

private struct BlockTemplateDragPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    let family: BlockFamily

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            HStack {
                Image(systemName: family.systemImage)
                    .font(.headline)
                    .foregroundStyle(family.accentColor)
                Text(family.displayName)
                    .font(.headline)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(family.accentColor)
                    .accessibilityHidden(true)
            }

            Text("Nuevo bloque")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Suelta en el lienzo para colocarlo")
                .font(.caption.weight(.medium))
                .foregroundStyle(family.accentColor)
        }
        .padding(TazkleSpacing.large)
        .frame(width: 224, height: 148, alignment: .topLeading)
        .background(
            TazkleColors.elevated(
                for: colorScheme,
                highContrast: highContrast
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.card)
                .stroke(family.accentColor, lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.28), radius: 20, y: 10)
    }
}

extension BlockFamily {
    var systemImage: String {
        switch self {
        case .strategy: "scope"
        case .product: "shippingbox"
        case .process: "arrow.triangle.branch"
        case .technology: "cpu"
        case .people: "person.2"
        case .economy: "dollarsign.circle"
        case .governance: "building.columns"
        }
    }

    var accentColor: Color {
        switch self {
        case .strategy: TazkleColors.relationship
        case .product: TazkleColors.warning
        case .process: TazkleColors.actionPrimary
        case .technology: TazkleColors.success
        case .people: TazkleColors.relationship
        case .economy: TazkleColors.warning
        case .governance: TazkleColors.assistantProposal
        }
    }
}

extension BlockState {
    var systemImage: String {
        switch self {
        case .draft: "circle.dotted"
        case .ready: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .approved: "checkmark.seal.fill"
        }
    }
}
