import SwiftUI
import TazkleDesignSystem

struct WorkspaceTrailingPanelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    private var canShowInspector: Bool {
        appState.isInspectorPresented
            && (appState.selectedBlock != nil || appState.selectedRelation != nil)
            && (appState.selectedSection == .projectMap
                || appState.selectedSection == .architecture)
    }

    private var visibleMode: WorkspacePanelMode {
        if appState.workspacePanelMode == .inspector, !canShowInspector {
            return .tazki
        }
        return appState.workspacePanelMode
    }

    var body: some View {
        VStack(spacing: 0) {
            if canShowInspector, appState.isTazkiPresented {
                Picker("Panel lateral", selection: $appState.workspacePanelMode) {
                    ForEach(WorkspacePanelMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(TazkleSpacing.medium)
                .accessibilityLabel("Contenido del panel lateral")

                Divider()
            }

            switch visibleMode {
            case .inspector:
                if appState.selectedRelation != nil {
                    RelationInspectorView()
                } else if appState.selectedSection == .architecture {
                    ArchitectureInspectorView()
                } else {
                    BlockInspectorView()
                }
            case .tazki:
                TazkiPanelView()
            }
        }
        .background(
            TazkleColors.panel(
                for: colorScheme,
                highContrast: highContrast
            )
        )
    }
}

struct TazkiFloatingButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        TazkleColors.panel(
                            for: colorScheme,
                            highContrast: highContrast
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Circle()
                            .stroke(
                                TazkleColors.assistantProposal.opacity(
                                    isHovering ? 0.92 : (highContrast ? 0.76 : 0.58)
                                ),
                                lineWidth: isHovering || highContrast ? 2 : 1
                            )
                    }

                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(TazkleColors.assistantProposal)
                    .shadow(
                        color: TazkleColors.assistantProposal.opacity(highContrast ? 0.7 : 0.4),
                        radius: isHovering ? 5 : 2
                    )
                    .accessibilityHidden(true)
            }
            .frame(width: 52, height: 52)
            .contentShape(Circle())
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.16),
                radius: isHovering ? 12 : 7,
                y: isHovering ? 5 : 3
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering && !reduceMotion ? 1.035 : 1)
        .animation(
            reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.82),
            value: isHovering
        )
        .onHover { isHovering = $0 }
        .accessibilityLabel("Abrir Tazki")
        .accessibilityValue("Asistente del proyecto")
        .accessibilityHint("Abre el chat y muestra alternativas sin modificar el proyecto")
        .help("Abrir Tazki · ⌥⌘T")
    }
}

private struct TazkiPanelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    @FocusState private var isComposerFocused: Bool
    @State private var showsComparison = false
    @State private var proposalPrepared = false
    @State private var suggestionDismissed = false
    @State private var question = ""
    @State private var preparedQuestion: String?

    private var recommendation: TazkiRecommendation {
        TazkiRecommendation.forSection(appState.selectedSection)
    }

    private var contextTitle: String {
        if let selectedBlock = appState.selectedBlock,
           appState.selectedSection == .projectMap
            || appState.selectedSection == .architecture {
            return "\(appState.selectedSection.title) · \(selectedBlock.title)"
        }
        return appState.selectedDestination?.title ?? appState.selectedSection.title
    }

    private var mascotState: TazkiMotionState {
        if isComposerFocused {
            return .listening
        }
        if proposalPrepared {
            return .validating
        }
        return .suggesting
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: TazkleSpacing.large) {
                    contextStrip

                    if suggestionDismissed {
                        dismissedState
                    } else {
                        assistantRecommendation
                    }

                    if let preparedQuestion {
                        preparedConversation(preparedQuestion)
                    }

                    safetyDisclosure
                }
                .padding(TazkleSpacing.large)
            }

            composer
        }
        .background(
            TazkleColors.panel(
                for: colorScheme,
                highContrast: highContrast
            )
        )
        .onChange(of: appState.selectedSection) {
            resetProposalState()
        }
        .onChange(of: appState.selectedDestinationID) {
            resetProposalState()
        }
    }

    private var header: some View {
        HStack(spacing: TazkleSpacing.medium) {
            TazkiAnimatedMarkView(state: mascotState, size: 74)

            VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                Text("Tazki")
                    .font(.title2.weight(.semibold))
                Text("Asistente del proyecto")
                    .font(.callout)
                    .foregroundStyle(
                        TazkleColors.secondaryContent(
                            for: colorScheme,
                            highContrast: highContrast
                        )
                    )
                Label("Modo local · solo propone", systemImage: "lock.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(TazkleColors.assistantProposal)
            }

            Spacer()

            Button {
                appState.dismissTazki()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .frame(width: 30, height: 30)
                    .background(
                        TazkleColors.elevated(
                            for: colorScheme,
                            highContrast: highContrast
                        )
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar Tazki")
            .help("Cerrar Tazki")
        }
        .padding(TazkleSpacing.large)
        .background {
            LinearGradient(
                colors: [
                    TazkleColors.assistantProposal.opacity(colorScheme == .dark ? 0.13 : 0.09),
                    TazkleColors.panel(
                        for: colorScheme,
                        highContrast: highContrast
                    ),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(
                    TazkleColors.separator(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
                .frame(height: 1)
        }
    }

    private var contextStrip: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            DisclosureGroup("Ver información utilizada") {
                VStack(alignment: .leading, spacing: TazkleSpacing.small) {
                    Label("Apartado y subvista visibles", systemImage: "rectangle.on.rectangle")
                    if let selectedBlock = appState.selectedBlock,
                       appState.selectedSection == .projectMap
                        || appState.selectedSection == .architecture {
                        Label("Bloque seleccionado: \(selectedBlock.title)", systemImage: "square.dashed")
                    }
                    Label("Sin documentos, secretos ni credenciales", systemImage: "key.slash")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, TazkleSpacing.small)
            }
            .font(.caption)

            HStack(spacing: TazkleSpacing.small) {
                Label(contextTitle, systemImage: "scope")
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                Spacer()
                Label("Lectura", systemImage: "eye")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(TazkleColors.success)
            }
        }
        .padding(TazkleSpacing.medium)
        .background(
            TazkleColors.elevated(
                for: colorScheme,
                highContrast: highContrast
            )
            .opacity(highContrast ? 1 : 0.64)
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

    private var assistantRecommendation: some View {
        HStack(alignment: .top, spacing: TazkleSpacing.small) {
            TazkiAnimatedMarkView(state: mascotState, size: 34)
                .padding(.top, TazkleSpacing.xSmall)

            VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
                Label("Alternativa sugerida", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TazkleColors.assistantProposal)

                Text(recommendation.title)
                    .font(.headline)
                Text(recommendation.summary)
                    .font(.callout)
                    .foregroundStyle(
                        TazkleColors.secondaryContent(
                            for: colorScheme,
                            highContrast: highContrast
                        )
                    )
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TazkleSpacing.small) {
                        impactChips
                    }
                    VStack(alignment: .leading, spacing: TazkleSpacing.small) {
                        impactChips
                    }
                }

                if showsComparison {
                    comparison
                }

                if proposalPrepared {
                    Label(
                        "Variante preparada localmente; el proyecto no cambió.",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TazkleColors.success)
                    .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: TazkleSpacing.small) {
                    Button(showsComparison ? "Ocultar" : "Comparar") {
                        showsComparison.toggle()
                    }
                    .buttonStyle(.bordered)

                    Button(proposalPrepared ? "Preparada" : "Preparar") {
                        proposalPrepared = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TazkleColors.assistantProposal)
                    .disabled(proposalPrepared)

                    Menu {
                        Button("Descartar propuesta", systemImage: "archivebox") {
                            suggestionDismissed = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .menuStyle(.borderlessButton)
                    .accessibilityLabel("Más acciones de la propuesta")
                }
            }
            .padding(TazkleSpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                TazkleColors.elevated(
                    for: colorScheme,
                    highContrast: highContrast
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.panel))
            .overlay {
                RoundedRectangle(cornerRadius: TazkleRadius.panel)
                    .stroke(
                        TazkleColors.assistantProposal.opacity(highContrast ? 0.8 : 0.34),
                        lineWidth: highContrast ? 1.5 : 1
                    )
            }
        }
    }

    @ViewBuilder
    private var impactChips: some View {
        TazkiImpactChip(
            title: recommendation.time,
            systemImage: "clock",
            color: TazkleColors.actionPrimary
        )
        TazkiImpactChip(
            title: recommendation.cost,
            systemImage: "banknote",
            color: TazkleColors.warning
        )
        TazkiImpactChip(
            title: recommendation.risk,
            systemImage: "shield",
            color: TazkleColors.success
        )
    }

    private var comparison: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            Divider()
            Text("Comparación conceptual")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TazkiComparisonRow(
                title: "Plan actual",
                detail: recommendation.currentPlan,
                color: TazkleColors.relationship
            )
            TazkiComparisonRow(
                title: "Alternativa",
                detail: recommendation.alternativePlan,
                color: TazkleColors.assistantProposal
            )
            Text("Estimaciones ilustrativas con confianza baja; faltan datos persistidos del dominio.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var dismissedState: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            Label("Propuesta descartada", systemImage: "archivebox")
                .font(.subheadline.weight(.semibold))
            Text("La alternativa se ocultó únicamente en esta sesión.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Mostrar de nuevo") {
                suggestionDismissed = false
            }
            .buttonStyle(.bordered)
        }
        .padding(TazkleSpacing.large)
        .background(
            TazkleColors.elevated(
                for: colorScheme,
                highContrast: highContrast
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
    }

    private func preparedConversation(_ preparedQuestion: String) -> some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            HStack {
                Spacer(minLength: TazkleSpacing.xxLarge)
                Text(preparedQuestion)
                    .font(.callout)
                    .padding(TazkleSpacing.medium)
                    .background(TazkleColors.actionPrimary.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.panel))
                    .overlay {
                        RoundedRectangle(cornerRadius: TazkleRadius.panel)
                            .stroke(TazkleColors.actionPrimary.opacity(0.36), lineWidth: 1)
                    }
            }

            HStack(alignment: .top, spacing: TazkleSpacing.small) {
                TazkiAnimatedMarkView(state: .listening, size: 30)
                Label(
                    "La consulta quedó preparada localmente. Conecta un proveedor para enviarla.",
                    systemImage: "icloud.slash"
                )
                .font(.caption)
                .foregroundStyle(TazkleColors.warning)
                .padding(TazkleSpacing.medium)
                .background(
                    TazkleColors.elevated(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
            }
        }
    }

    private var safetyDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: TazkleSpacing.small) {
                Label("Propone y explica", systemImage: "sparkles")
                Label("No aprueba ni modifica el proyecto", systemImage: "lock")
                Label("Todo cambio material requiere revisión humana", systemImage: "person.crop.circle.badge.checkmark")
            }
            .padding(.top, TazkleSpacing.small)
        } label: {
            Label("Cómo trabaja Tazki", systemImage: "checkmark.shield")
                .font(.caption.weight(.semibold))
        }
        .font(.caption)
        .foregroundStyle(
            TazkleColors.secondaryContent(
                for: colorScheme,
                highContrast: highContrast
            )
        )
        .padding(.horizontal, TazkleSpacing.small)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            HStack(alignment: .bottom, spacing: TazkleSpacing.medium) {
                TextField(
                    "Pregunta o pide una alternativa…",
                    text: $question,
                    axis: .vertical
                )
                .lineLimit(1 ... 4)
                .textFieldStyle(.plain)
                .padding(.horizontal, TazkleSpacing.medium)
                .padding(.vertical, 10)
                .background(
                    TazkleColors.canvas(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: TazkleRadius.card)
                        .stroke(
                            isComposerFocused
                                ? TazkleColors.assistantProposal
                                : TazkleColors.separator(
                                    for: colorScheme,
                                    highContrast: highContrast
                                ),
                            lineWidth: isComposerFocused ? 2 : 1
                        )
                }
                .focused($isComposerFocused)
                .accessibilityLabel("Pregunta para Tazki")

                Button {
                    prepareQuestion()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.callout.weight(.bold))
                        .frame(width: 38, height: 38)
                        .background(
                            question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? TazkleColors.separator(
                                    for: colorScheme,
                                    highContrast: highContrast
                                )
                                : TazkleColors.assistantProposal
                        )
                        .foregroundStyle(
                            TazkleColors.panel(
                                for: colorScheme,
                                highContrast: highContrast
                            )
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Preparar consulta")
                .help("Preparar consulta localmente")
            }

            Label(
                "Modo local: nada se envía todavía.",
                systemImage: "lock.fill"
            )
            .font(.caption2)
            .foregroundStyle(
                TazkleColors.secondaryContent(
                    for: colorScheme,
                    highContrast: highContrast
                )
            )
        }
        .padding(TazkleSpacing.large)
        .background(
            TazkleColors.elevated(
                for: colorScheme,
                highContrast: highContrast
            )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    TazkleColors.separator(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
                .frame(height: 1)
        }
    }

    private func prepareQuestion() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        preparedQuestion = String(trimmed.prefix(500))
        question = ""
        isComposerFocused = false
    }

    private func resetProposalState() {
        showsComparison = false
        proposalPrepared = false
        suggestionDismissed = false
        preparedQuestion = nil
        question = ""
    }
}

private struct TazkiImpactChip: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct TazkiComparisonRow: View {
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: TazkleSpacing.small) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TazkiRecommendation {
    let title: String
    let summary: String
    let time: String
    let cost: String
    let risk: String
    let currentPlan: String
    let alternativePlan: String

    static func forSection(_ section: AppSection) -> TazkiRecommendation {
        switch section {
        case .overview:
            TazkiRecommendation(
                title: "Cerrar los vacíos de factibilidad",
                summary: "Prioriza mercado, presupuesto y responsables antes de ampliar el alcance del proyecto.",
                time: "Siguiente paso",
                cost: "Sin estimar",
                risk: "Reduce incertidumbre",
                currentPlan: "Continuar agregando módulos con evidencia incompleta.",
                alternativePlan: "Completar tres evidencias críticas y volver a evaluar."
            )
        case .projectMap:
            TazkiRecommendation(
                title: "Completar el flujo de autenticación",
                summary: "Añade recuperación de acceso, criterios de aceptación y una dependencia explícita con notificaciones.",
                time: "+1–2 días",
                cost: "Impacto bajo",
                risk: "Cobertura mayor",
                currentPlan: "Autenticación conectada únicamente con API y datos.",
                alternativePlan: "Flujo completo con recuperación, validación y responsable."
            )
        case .architecture:
            TazkiRecommendation(
                title: "Comparar servicios administrados",
                summary: "Una variante administrada podría reducir operación y tiempo inicial a cambio de mayor costo periódico.",
                time: "−3 semanas",
                cost: "+12% mensual",
                risk: "Operación menor",
                currentPlan: "Servicios propios con mayor esfuerzo de operación.",
                alternativePlan: "Servicios administrados con límites y salida documentada."
            )
        case .team:
            TazkiRecommendation(
                title: "Rebalancear ocho horas de desarrollo",
                summary: "Mueve trabajo no crítico al siguiente sprint para evitar una excepción de sobrecarga.",
                time: "+1 sprint parcial",
                cost: "Sin cambio",
                risk: "Carga saludable",
                currentPlan: "Una persona supera 100% de capacidad durante la semana 3.",
                alternativePlan: "Distribución por capacidad sin cambiar el alcance aprobado."
            )
        case .feasibility:
            TazkiRecommendation(
                title: "Viable con condiciones verificables",
                summary: "Mantén el plan como variante condicionada hasta confirmar integraciones, volumen y presupuesto.",
                time: "2 validaciones",
                cost: "Rango abierto",
                risk: "Condicionado",
                currentPlan: "Emitir una conclusión con evidencia parcial.",
                alternativePlan: "Conservar rangos, supuestos y confianza baja hasta validar."
            )
        case .costs:
            TazkiRecommendation(
                title: "Separar lanzamiento y escalamiento",
                summary: "Cotiza un núcleo inicial y deja analítica avanzada como variante posterior para reducir inversión de entrada.",
                time: "−4 semanas",
                cost: "−18% inicial",
                risk: "Alcance explícito",
                currentPlan: "Entregar todos los módulos en una sola propuesta.",
                alternativePlan: "Núcleo aprobado más una variante de escalamiento."
            )
        case .workPlan:
            TazkiRecommendation(
                title: "Dividir el segundo sprint",
                summary: "Separa integración y validación para que QA no dependa de dos entregables simultáneos.",
                time: "+3 días",
                cost: "Impacto bajo",
                risk: "Dependencia menor",
                currentPlan: "Integración y pruebas comienzan al mismo tiempo.",
                alternativePlan: "Entrega técnica, validación y aceptación en secuencia."
            )
        case .settings:
            TazkiRecommendation(
                title: "Sin contexto de proyecto",
                summary: "Tazki no analiza Perfil y configuración para evitar acceso innecesario a identidad y seguridad.",
                time: "No aplica",
                cost: "No aplica",
                risk: "Privacidad",
                currentPlan: "Sin análisis.",
                alternativePlan: "Volver a un apartado del proyecto."
            )
        }
    }
}
