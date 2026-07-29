import SwiftUI
import TazkleDesignSystem
import TazkleDomain
import TazklePersistence

struct NewProjectFlow: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    @FocusState private var focusedField: Field?

    @State private var step = Step.details
    @State private var projectName = ""
    @State private var selectedTemplate = ProjectTemplateKey.webApplication
    @State private var webTechnologies = WebTechnologySelection.defaultSelection

    private enum Field {
        case projectName
    }

    private enum Step: Int, CaseIterable {
        case details = 1
        case template
        case technologies
        case confirmation

        var title: String {
            switch self {
            case .details: "Proyecto"
            case .template: "Plantilla"
            case .technologies: "Tecnologías"
            case .confirmation: "Confirmar"
            }
        }
    }

    private struct TechnologySummaryItem: Identifiable {
        let title: String
        let value: String
        let systemImage: String

        var id: String { title }
    }

    private var normalizedProjectName: String {
        projectName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Group {
                switch step {
                case .details:
                    detailsStep
                case .template:
                    templateStep
                case .technologies:
                    technologiesStep
                case .confirmation:
                    confirmationStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()
            footer
        }
        .frame(width: 960, height: 720)
        .background(TazkleColors.canvas(for: colorScheme, highContrast: highContrast))
        .onAppear {
            focusedField = .projectName
        }
    }

    private var header: some View {
        VStack(spacing: TazkleSpacing.medium) {
            HStack {
                HStack(spacing: TazkleSpacing.medium) {
                    BrandMarkView()
                        .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nuevo proyecto")
                            .font(.headline)
                        Text("Espacio personal · guardado localmente")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("Paso \(step.rawValue) de \(Step.allCases.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: TazkleSpacing.small) {
                ForEach(Step.allCases, id: \.rawValue) { item in
                    HStack(spacing: TazkleSpacing.small) {
                        ZStack {
                            Circle()
                                .fill(step.rawValue >= item.rawValue
                                    ? TazkleColors.relationship
                                    : TazkleColors.elevated(
                                        for: colorScheme,
                                        highContrast: highContrast
                                    ))
                                .frame(width: 26, height: 26)

                            if step.rawValue > item.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                            } else {
                                Text("\(item.rawValue)")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        .foregroundStyle(
                            step.rawValue >= item.rawValue
                                ? Color.white
                                : TazkleColors.secondaryContent(
                                    for: colorScheme,
                                    highContrast: highContrast
                                )
                        )

                        Text(item.title)
                            .font(.caption.weight(step == item ? .semibold : .regular))
                            .foregroundStyle(step == item ? .primary : .secondary)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Paso \(item.rawValue), \(item.title)")
                    .accessibilityValue(
                        step == item
                            ? "Actual"
                            : step.rawValue > item.rawValue ? "Completado" : "Pendiente"
                    )

                    if item != Step.allCases.last {
                        Rectangle()
                            .fill(TazkleColors.separator(
                                for: colorScheme,
                                highContrast: highContrast
                            ))
                            .frame(minWidth: 24, maxWidth: .infinity, minHeight: 1, maxHeight: 1)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.horizontal, TazkleSpacing.xLarge)
        .padding(.vertical, TazkleSpacing.medium)
        .frame(height: 104)
        .background(TazkleColors.panel(for: colorScheme, highContrast: highContrast))
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            stepIntroduction(
                title: "Dale identidad al proyecto",
                subtitle: "La plantilla se elegirá antes de crear el espacio de trabajo."
            )

            VStack(alignment: .leading, spacing: TazkleSpacing.small) {
                Text("Nombre del proyecto")
                    .font(.callout.weight(.semibold))
                TextField("Ej. Portal de clientes", text: $projectName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .projectName)
                    .onSubmit {
                        guard !normalizedProjectName.isEmpty else { return }
                        step = .template
                    }
                Text("Máximo 120 caracteres. Podrás cambiarlo posteriormente.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 560, alignment: .leading)

            Label(
                "El proyecto se creará primero en esta Mac. La sincronización se incorporará después.",
                systemImage: "internaldrive"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(TazkleSpacing.large)
            .frame(maxWidth: 560, alignment: .leading)
            .background(
                TazkleColors.panel(for: colorScheme, highContrast: highContrast)
            )
            .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
        }
        .padding(TazkleSpacing.xxLarge)
    }

    private var templateStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
                stepIntroduction(
                    title: "Elige una plantilla base",
                    subtitle: "Define la estructura inicial; podrás adaptarla después."
                )

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: TazkleSpacing.large),
                        GridItem(.flexible(), spacing: TazkleSpacing.large),
                    ],
                    spacing: TazkleSpacing.large
                ) {
                    templateCard(.webApplication)
                    templateCard(.blankCanvas)
                    unavailableTemplateCard(
                        title: "Aplicación móvil",
                        summary: "Plantilla prevista para una versión posterior.",
                        systemImage: "iphone"
                    )
                    unavailableTemplateCard(
                        title: "Software empresarial",
                        summary: "Plantilla prevista para una versión posterior.",
                        systemImage: "building.2"
                    )
                }
            }
            .padding(TazkleSpacing.xxLarge)
        }
    }

    private var technologiesStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
                stepIntroduction(
                    title: "Configura la arquitectura inicial",
                    subtitle: selectedTemplate == .webApplication
                        ? "Cada elección se convertirá en un bloque conectado del proyecto."
                        : "El lienzo vacío no incorpora tecnologías ni relaciones iniciales."
                )

                if selectedTemplate == .webApplication {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: TazkleSpacing.large),
                            GridItem(.flexible(), spacing: TazkleSpacing.large),
                        ],
                        spacing: TazkleSpacing.large
                    ) {
                        technologySelector(
                            title: "Frontend",
                            systemImage: "macwindow",
                            selection: $webTechnologies.frontend
                        )
                        technologySelector(
                            title: "Lenguaje backend",
                            systemImage: "chevron.left.forwardslash.chevron.right",
                            selection: $webTechnologies.language
                        )
                        technologySelector(
                            title: "API",
                            systemImage: "network",
                            selection: $webTechnologies.api,
                            warning: webTechnologies.compatibilityWarnings.first
                        )
                        technologySelector(
                            title: "Autenticación",
                            systemImage: "person.badge.key",
                            selection: $webTechnologies.authentication
                        )
                        technologySelector(
                            title: "Base de datos",
                            systemImage: "cylinder.split.1x2",
                            selection: $webTechnologies.database
                        )
                        technologySelector(
                            title: "Infraestructura",
                            systemImage: "cloud",
                            selection: $webTechnologies.deployment
                        )
                    }

                    architecturePreview

                } else {
                    Label(
                        "Podrás agregar y conectar tecnologías posteriormente desde Arquitectura.",
                        systemImage: "square.dashed"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(TazkleSpacing.xLarge)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TazkleColors.panel(for: colorScheme, highContrast: highContrast))
                    .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
                }
            }
            .padding(TazkleSpacing.xxLarge)
        }
    }

    private func technologySelector<Option>(
        title: String,
        systemImage: String,
        selection: Binding<Option>,
        warning: String? = nil
    ) -> some View where Option: WebTechnologyOption {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))

            HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                    Text(selection.wrappedValue.displayName)
                        .font(.headline)
                    Text(selection.wrappedValue.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: TazkleSpacing.small)

                Picker(title, selection: selection) {
                    ForEach(Array(Option.allCases), id: \.id) { option in
                        Text(option.displayName)
                            .tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 132)
            }

            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(TazkleColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(TazkleSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(TazkleColors.panel(for: colorScheme, highContrast: highContrast))
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.card)
                .stroke(
                    TazkleColors.separator(for: colorScheme, highContrast: highContrast),
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityValue(selection.wrappedValue.displayName)
    }

    private var architecturePreview: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            Label("Relaciones que se crearán", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.headline)

            Text(
                "\(webTechnologies.frontend.displayName) → "
                    + "\(webTechnologies.api.displayName) → "
                    + "\(webTechnologies.language.displayName) → "
                    + "\(webTechnologies.database.displayName)"
            )
            .font(.callout.weight(.semibold))

            Text(
                "\(webTechnologies.authentication.displayName) validará el acceso; "
                    + "\(webTechnologies.deployment.displayName) soportará backend y datos."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            Label(
                "6 bloques · 7 relaciones tipadas · 4 capas de arquitectura",
                systemImage: "checkmark.circle"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(TazkleColors.success)
        }
        .padding(TazkleSpacing.xLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            TazkleColors.assistantProposal.opacity(0.08),
            in: RoundedRectangle(cornerRadius: TazkleRadius.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.card)
                .stroke(TazkleColors.assistantProposal.opacity(0.34), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var confirmationStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
                stepIntroduction(
                    title: "Confirma el proyecto",
                    subtitle: "Nada se crea hasta que confirmes esta pantalla."
                )

                HStack(alignment: .top, spacing: TazkleSpacing.xLarge) {
                    summaryCard(
                        title: normalizedProjectName,
                        detail: "Nombre del proyecto",
                        systemImage: "folder",
                        accent: TazkleColors.actionPrimary
                    )
                    summaryCard(
                        title: selectedTemplate.title,
                        detail: selectedTemplate.creationSummary,
                        systemImage: selectedTemplate.systemImage,
                        accent: TazkleColors.relationship
                    )
                }

                if selectedTemplate == .webApplication {
                    technologySummary
                }

                VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
                    Label("Incluido al crear", systemImage: "checkmark.seal")
                        .font(.headline)

                    ForEach(selectedTemplate.includedItems, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(TazkleSpacing.xLarge)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TazkleColors.panel(for: colorScheme, highContrast: highContrast))
                .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))

                Label(
                    "La creación es local y no envía la idea, la plantilla ni los datos del proyecto a servicios externos.",
                    systemImage: "lock.shield"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .padding(TazkleSpacing.xxLarge)
        }
    }

    private var technologySummary: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            Label("Stack inicial", systemImage: "square.3.layers.3d")
                .font(.headline)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: TazkleSpacing.large),
                    GridItem(.flexible(), spacing: TazkleSpacing.large),
                ],
                spacing: TazkleSpacing.medium
            ) {
                ForEach(technologySummaryItems) { item in
                    HStack(spacing: TazkleSpacing.small) {
                        Image(systemName: item.systemImage)
                            .foregroundStyle(TazkleColors.assistantProposal)
                            .frame(width: 20)
                            .accessibilityHidden(true)
                        Text(item.title)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.value)
                            .fontWeight(.semibold)
                    }
                    .font(.callout)
                    .accessibilityElement(children: .combine)
                }
            }

            ForEach(webTechnologies.compatibilityWarnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(TazkleColors.warning)
            }
        }
        .padding(TazkleSpacing.xLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TazkleColors.panel(for: colorScheme, highContrast: highContrast))
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
    }

    private var technologySummaryItems: [TechnologySummaryItem] {
        [
            TechnologySummaryItem(
                title: "Frontend",
                value: webTechnologies.frontend.displayName,
                systemImage: "macwindow"
            ),
            TechnologySummaryItem(
                title: "Backend",
                value: webTechnologies.language.displayName,
                systemImage: "chevron.left.forwardslash.chevron.right"
            ),
            TechnologySummaryItem(
                title: "API",
                value: webTechnologies.api.displayName,
                systemImage: "network"
            ),
            TechnologySummaryItem(
                title: "Auth",
                value: webTechnologies.authentication.displayName,
                systemImage: "person.badge.key"
            ),
            TechnologySummaryItem(
                title: "Datos",
                value: webTechnologies.database.displayName,
                systemImage: "cylinder.split.1x2"
            ),
            TechnologySummaryItem(
                title: "Infraestructura",
                value: webTechnologies.deployment.displayName,
                systemImage: "cloud"
            ),
        ]
    }

    private var footer: some View {
        HStack {
            Button("Cancelar") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if step != .details {
                Button("Atrás") {
                    withAnimation(.easeOut(duration: 0.16)) {
                        step = Step(rawValue: step.rawValue - 1) ?? .details
                    }
                }
            }

            Button(step == .confirmation ? "Crear proyecto" : "Continuar") {
                advance()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(step == .details && normalizedProjectName.isEmpty)
        }
        .padding(TazkleSpacing.xLarge)
        .background(TazkleColors.panel(for: colorScheme, highContrast: highContrast))
    }

    private func stepIntroduction(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            Text(title)
                .font(.largeTitle.weight(.semibold))
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func templateCard(_ template: ProjectTemplateKey) -> some View {
        Button {
            selectedTemplate = template
        } label: {
            VStack(alignment: .leading, spacing: TazkleSpacing.large) {
                HStack {
                    Image(systemName: template.systemImage)
                        .font(.title2)
                        .foregroundStyle(TazkleColors.relationship)
                    Spacer()
                    Image(systemName: selectedTemplate == template
                        ? "checkmark.circle.fill"
                        : "circle")
                        .font(.title3)
                        .foregroundStyle(
                            selectedTemplate == template
                                ? TazkleColors.relationship
                                : .secondary
                        )
                }

                Text(template.title)
                    .font(.title3.weight(.semibold))
                Text(template.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(template.creationSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TazkleColors.relationship)
            }
            .padding(TazkleSpacing.xLarge)
            .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
            .background(TazkleColors.panel(for: colorScheme, highContrast: highContrast))
            .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: TazkleRadius.card)
                    .stroke(
                        selectedTemplate == template
                            ? TazkleColors.relationship
                            : TazkleColors.separator(
                                for: colorScheme,
                                highContrast: highContrast
                            ),
                        lineWidth: selectedTemplate == template ? 2 : 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.title)
        .accessibilityValue(selectedTemplate == template ? "Seleccionada" : "No seleccionada")
        .accessibilityHint(template.summary)
    }

    private func unavailableTemplateCard(
        title: String,
        summary: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.large) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)
                Spacer()
                Text("Próximamente")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, TazkleSpacing.small)
                    .padding(.vertical, TazkleSpacing.xSmall)
                    .background(.quaternary, in: Capsule())
            }

            Text(title)
                .font(.title3.weight(.semibold))
            Text(summary)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(TazkleSpacing.xLarge)
        .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
        .background(TazkleColors.panel(for: colorScheme, highContrast: highContrast))
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.card)
                .stroke(
                    TazkleColors.separator(for: colorScheme, highContrast: highContrast),
                    lineWidth: 1
                )
        }
        .opacity(0.58)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("No disponible")
    }

    private func summaryCard(
        title: String,
        detail: String,
        systemImage: String,
        accent: Color
    ) -> some View {
        HStack(spacing: TazkleSpacing.large) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: TazkleRadius.control))

            VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(TazkleSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TazkleColors.panel(for: colorScheme, highContrast: highContrast))
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
        .accessibilityElement(children: .combine)
    }

    private func advance() {
        switch step {
        case .details:
            guard !normalizedProjectName.isEmpty else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                step = .template
            }
        case .template:
            withAnimation(.easeOut(duration: 0.16)) {
                step = .technologies
            }
        case .technologies:
            withAnimation(.easeOut(duration: 0.16)) {
                step = .confirmation
            }
        case .confirmation:
            if appState.createProject(
                name: normalizedProjectName,
                template: selectedTemplate,
                webTechnologies: webTechnologies
            ) {
                dismiss()
            }
        }
    }
}

extension ProjectTemplateKey {
    var title: String {
        switch self {
        case .webApplication: "Aplicación web"
        case .blankCanvas: "Lienzo vacío"
        }
    }

    var summary: String {
        switch self {
        case .webApplication:
            "Inicia con módulos de producto, servicios, datos y relaciones técnicas."
        case .blankCanvas:
            "Crea un proyecto sin bloques para estructurarlo manualmente."
        }
    }

    var creationSummary: String {
        switch self {
        case .webApplication: "6 bloques · 7 relaciones · 4 capas"
        case .blankCanvas: "Sin bloques ni relaciones iniciales"
        }
    }

    var systemImage: String {
        switch self {
        case .webApplication: "globe"
        case .blankCanvas: "square.dashed"
        }
    }

    var includedItems: [String] {
        switch self {
        case .webApplication:
            [
                "Frontend, backend, API, autenticación, datos e infraestructura",
                "Capas de experiencia, servicios, datos e infraestructura",
                "Siete relaciones tipadas entre todos los servicios",
                "Evaluación de factibilidad pendiente",
            ]
        case .blankCanvas:
            [
                "Lienzo vacío de gran formato",
                "Catálogo de siete familias de bloques",
                "Arquitectura y mapa conectados al mismo modelo",
                "Evaluación de factibilidad pendiente",
            ]
        }
    }
}
