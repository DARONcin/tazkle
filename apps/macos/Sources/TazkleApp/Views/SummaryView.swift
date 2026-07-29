import SwiftUI
import TazkleDesignSystem
import TazkleDomain

struct SummaryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    private var destinationID: String {
        appState.selectedDestinationID ?? "overview.general"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
                SummaryHeader()

                switch destinationID {
                case "overview.milestones":
                    SummaryMilestonesView()
                case "overview.risks":
                    SummaryRisksView()
                case "overview.activity":
                    SummaryActivityView()
                case "overview.approvals":
                    SummaryApprovalsView()
                default:
                    SummaryDashboardView()
                }
            }
            .padding(TazkleSpacing.xLarge)
        }
        .background(
            TazkleColors.canvas(
                for: colorScheme,
                highContrast: highContrast
            )
        )
    }
}

private struct SummaryHeader: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    var body: some View {
        HStack(alignment: .center, spacing: TazkleSpacing.large) {
            ZStack {
                RoundedRectangle(cornerRadius: TazkleRadius.card)
                    .fill(TazkleColors.actionPrimary.opacity(0.16))
                    .frame(width: 50, height: 50)
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title2)
                    .foregroundStyle(TazkleColors.actionPrimary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                Text(appState.graph.name)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(
                        TazkleColors.primaryContent(
                            for: colorScheme,
                            highContrast: highContrast
                        )
                    )
                Text("Lectura actual del proyecto · datos guardados localmente")
                    .font(.callout)
                    .foregroundStyle(
                        TazkleColors.secondaryContent(
                            for: colorScheme,
                            highContrast: highContrast
                        )
                    )
            }

            Spacer()

            Label(appState.saveState.title, systemImage: appState.saveState.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(appState.saveState == .failed ? TazkleColors.warning : TazkleColors.success)
                .padding(.horizontal, TazkleSpacing.medium)
                .padding(.vertical, TazkleSpacing.small)
                .background(
                    (appState.saveState == .failed ? TazkleColors.warning : TazkleColors.success)
                        .opacity(0.1)
                )
                .clipShape(Capsule())
        }
    }
}

private struct SummaryDashboardView: View {
    @EnvironmentObject private var appState: AppState

    private var blocks: [ProjectBlock] { appState.graph.blocks }
    private var warnings: [ProjectBlock] { blocks.filter { $0.state == .warning } }
    private var reviewedBlocks: Int {
        blocks.count { $0.state == .ready || $0.state == .approved }
    }
    private var architectureBlocks: [ProjectBlock] {
        blocks.filter { $0.architectureLayer != nil }
    }
    private var definedBlocks: Int {
        blocks.count {
            !$0.title.localizedCaseInsensitiveContains("nuevo bloque")
                && !$0.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            projectStages

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(minimum: 140), spacing: TazkleSpacing.medium),
                    count: 4
                ),
                spacing: TazkleSpacing.medium
            ) {
                SummaryMetricCard(
                    title: "Bloques definidos",
                    value: "\(definedBlocks)/\(blocks.count)",
                    detail: "Con nombre y propósito",
                    systemImage: "square.3.layers.3d",
                    color: TazkleColors.actionPrimary
                )
                SummaryMetricCard(
                    title: "Listos para revisión",
                    value: "\(reviewedBlocks)",
                    detail: "\(blocks.count) bloques en total",
                    systemImage: "checkmark.circle",
                    color: TazkleColors.success
                )
                SummaryMetricCard(
                    title: "Cobertura técnica",
                    value: percentage(architectureBlocks.count, of: blocks.count),
                    detail: "Bloques con capa asignada",
                    systemImage: "square.3.layers.3d.top.filled",
                    color: TazkleColors.assistantProposal
                )
                SummaryMetricCard(
                    title: "Atención requerida",
                    value: "\(warnings.count)",
                    detail: "Advertencias en el mapa",
                    systemImage: "exclamationmark.triangle",
                    color: warnings.isEmpty ? TazkleColors.success : TazkleColors.warning
                )
            }

            ViewThatFits(in: .horizontal) {
                VStack(spacing: TazkleSpacing.medium) {
                    HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                        SummaryBlockStatusCard()
                        VStack(spacing: TazkleSpacing.medium) {
                            SummaryNextActionCard()
                            SummaryRiskCard()
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }

                    SummaryArchitectureCard()
                }

                VStack(spacing: TazkleSpacing.medium) {
                    SummaryNextActionCard()
                    SummaryBlockStatusCard()
                    SummaryArchitectureCard()
                    SummaryRiskCard()
                }
            }
        }
    }

    private var projectStages: some View {
        SummaryCard(title: "Lectura del ciclo", systemImage: "point.topleft.down.curvedto.point.bottomright.up") {
            SummaryCycleTimeline(
                stages: [
                    SummaryCycleStage(
                        title: "Iniciación",
                        detail: "Completada",
                        state: .complete
                    ),
                    SummaryCycleStage(
                        title: "Factibilidad",
                        detail: blocks.isEmpty ? "Pendiente" : "Sin evaluación",
                        state: blocks.isEmpty ? .pending : .attention
                    ),
                    SummaryCycleStage(
                        title: "Preproducción",
                        detail: blocks.isEmpty ? "Pendiente" : "En curso",
                        state: blocks.isEmpty ? .pending : .active
                    ),
                    SummaryCycleStage(
                        title: "Producción",
                        detail: "Pendiente",
                        state: .pending
                    ),
                ]
            )

            if !blocks.isEmpty {
                Label(
                    "La estructura está en preproducción; todavía no existe una evaluación de factibilidad persistida.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(TazkleColors.warning)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func percentage(_ value: Int, of total: Int) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int((Double(value) / Double(total)) * 100))%"
    }
}

private struct SummaryBlockStatusCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SummaryCard(title: "Estado de los bloques", systemImage: "list.bullet.rectangle") {
            if appState.graph.blocks.isEmpty {
                SummaryEmptyState(
                    title: "Todavía no hay bloques",
                    detail: "Crea el primero desde el Mapa del proyecto."
                )
            } else {
                ForEach(appState.graph.blocks.prefix(5)) { block in
                    HStack(spacing: TazkleSpacing.medium) {
                        Image(systemName: block.family.systemImage)
                            .foregroundStyle(block.family.accentColor)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(block.title)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            Text(block.family.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        InspectorStatusChip(state: block.state)
                    }
                    .padding(.vertical, TazkleSpacing.xSmall)
                }
            }

            Button("Abrir mapa", systemImage: "arrow.right") {
                appState.selectSection(.projectMap)
            }
            .buttonStyle(.link)
        }
    }
}

private struct SummaryNextActionCard: View {
    @EnvironmentObject private var appState: AppState

    private var warningBlock: ProjectBlock? {
        appState.graph.blocks.first { $0.state == .warning }
    }

    private var unfinishedBlock: ProjectBlock? {
        appState.graph.blocks.first {
            $0.title.localizedCaseInsensitiveContains("nuevo bloque")
                || $0.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        SummaryCard(title: "Siguiente acción", systemImage: "arrow.forward.circle") {
            ZStack {
                Circle()
                    .fill(actionColor.opacity(0.14))
                    .frame(width: 64, height: 64)
                Image(systemName: actionIcon)
                    .font(.title)
                    .foregroundStyle(actionColor)
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                Text(actionTitle)
                    .font(.headline)
                Text(actionDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(actionButtonTitle, systemImage: "arrow.right") {
                performAction()
            }
            .buttonStyle(.borderedProminent)
            .tint(TazkleColors.actionPrimary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var actionTitle: String {
        if warningBlock != nil { return "Revisar una advertencia" }
        if unfinishedBlock != nil { return "Completar un bloque" }
        if appState.graph.blocks.isEmpty { return "Construir el mapa inicial" }
        return "Revisar la arquitectura"
    }

    private var actionDetail: String {
        if let warningBlock {
            return "“\(warningBlock.title)” necesita una decisión antes de avanzar."
        }
        if let unfinishedBlock {
            return "“\(unfinishedBlock.title)” todavía necesita nombre o propósito definitivo."
        }
        if appState.graph.blocks.isEmpty {
            return "Agrega los primeros componentes y define cómo se relacionan."
        }
        return "Comprueba que cada componente esté en la capa correcta y que sus dependencias tengan sentido."
    }

    private var actionIcon: String {
        warningBlock != nil ? "exclamationmark.triangle.fill" : "checklist"
    }

    private var actionColor: Color {
        warningBlock != nil ? TazkleColors.warning : TazkleColors.relationship
    }

    private var actionButtonTitle: String {
        warningBlock != nil || unfinishedBlock != nil ? "Revisar bloque" : "Abrir mapa"
    }

    private func performAction() {
        if let block = warningBlock ?? unfinishedBlock {
            appState.selectSection(.projectMap)
            appState.selectBlock(block.id)
            if unfinishedBlock?.id == block.id {
                appState.beginEditingBlock(block.id)
            }
        } else {
            appState.selectSection(appState.graph.blocks.isEmpty ? .projectMap : .architecture)
        }
    }
}

private struct SummaryArchitectureCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SummaryCard(title: "Arquitectura por capa", systemImage: "square.3.layers.3d") {
            ForEach(ArchitectureLayer.allCases) { layer in
                let count = appState.graph.blocks.count { $0.architectureLayer == layer }
                HStack {
                    Label(layer.displayName, systemImage: layer.systemImage)
                        .foregroundStyle(layer.accentColor)
                    Spacer()
                    Text("\(count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ProgressView(
                    value: Double(count),
                    total: Double(max(appState.graph.blocks.count, 1))
                )
                .tint(layer.accentColor)
            }

            Button("Abrir arquitectura", systemImage: "arrow.right") {
                appState.selectSection(.architecture)
            }
            .buttonStyle(.link)
        }
    }
}

private struct SummaryRiskCard: View {
    @EnvironmentObject private var appState: AppState

    private var warningBlocks: [ProjectBlock] {
        appState.graph.blocks.filter { $0.state == .warning }
    }

    private var criticalRelations: [BlockRelation] {
        appState.graph.relations.filter(\.isCritical)
    }

    var body: some View {
        SummaryCard(title: "Riesgos observables", systemImage: "exclamationmark.triangle") {
            if warningBlocks.isEmpty && criticalRelations.isEmpty {
                Label("Sin advertencias locales", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(TazkleColors.success)
                    .font(.callout)
            } else {
                ForEach(warningBlocks.prefix(3)) { block in
                    riskRow(
                        title: block.title,
                        detail: "Bloque marcado con advertencia"
                    )
                }
                ForEach(criticalRelations.prefix(3)) { relation in
                    riskRow(
                        title: appState.relationDescription(relation),
                        detail: "Relación crítica"
                    )
                }
            }

            Button("Ver riesgos", systemImage: "arrow.right") {
                appState.selectDestination(
                    SectionDestination(
                        id: "overview.risks",
                        title: "Riesgos",
                        systemImage: "exclamationmark.triangle"
                    )
                )
            }
            .buttonStyle(.link)
        }
    }

    private func riskRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: TazkleSpacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(TazkleColors.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SummaryMilestonesView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SummaryCard(title: "Hitos estructurales", systemImage: "signpost.right") {
            SummaryMilestoneRow(
                title: "Idea registrada",
                detail: appState.graph.name,
                complete: true
            )
            SummaryMilestoneRow(
                title: "Mapa inicial",
                detail: "\(appState.graph.blocks.count) bloques conectados por \(appState.graph.relations.count) relaciones",
                complete: !appState.graph.blocks.isEmpty
            )
            SummaryMilestoneRow(
                title: "Arquitectura clasificada",
                detail: "\(appState.graph.blocks.count { $0.architectureLayer != nil }) bloques con capa",
                complete: !appState.graph.blocks.isEmpty
                    && appState.graph.blocks.allSatisfy { $0.architectureLayer != nil }
            )
            SummaryMilestoneRow(
                title: "Factibilidad revisada",
                detail: "Aún no existe una evaluación aprobada en el prototipo",
                complete: false
            )
        }
    }
}

private struct SummaryRisksView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SummaryCard(title: "Riesgos y advertencias", systemImage: "exclamationmark.triangle") {
            let warnings = appState.graph.blocks.filter { $0.state == .warning }
            let critical = appState.graph.relations.filter(\.isCritical)

            if warnings.isEmpty && critical.isEmpty {
                SummaryEmptyState(
                    title: "Sin riesgos marcados",
                    detail: "Las revisiones futuras de factibilidad agregarán evidencia y severidad."
                )
            } else {
                ForEach(warnings) { block in
                    SummaryRiskDetailRow(
                        title: block.title,
                        detail: block.summary,
                        badge: "Advertencia"
                    )
                }
                ForEach(critical) { relation in
                    SummaryRiskDetailRow(
                        title: appState.relationDescription(relation),
                        detail: "La relación fue marcada como crítica.",
                        badge: "Crítica"
                    )
                }
            }
        }
    }
}

private struct SummaryActivityView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SummaryCard(title: "Versiones locales", systemImage: "clock.arrow.circlepath") {
            Text("El prototipo todavía no registra una bitácora temporal; esta vista muestra las versiones actuales sin inventar fechas.")
                .font(.callout)
                .foregroundStyle(.secondary)

            ForEach(appState.graph.blocks.sorted { $0.rowVersion > $1.rowVersion }) { block in
                HStack {
                    Image(systemName: block.family.systemImage)
                        .foregroundStyle(block.family.accentColor)
                    Text(block.title)
                    Spacer()
                    Text("v\(block.rowVersion)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, TazkleSpacing.xSmall)
            }
        }
    }
}

private struct SummaryApprovalsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SummaryCard(title: "Estado de aprobación", systemImage: "checkmark.shield") {
            let approved = appState.graph.blocks.filter { $0.state == .approved }
            let ready = appState.graph.blocks.filter { $0.state == .ready }

            LabeledContent("Aprobados", value: "\(approved.count)")
            LabeledContent("Listos para revisión", value: "\(ready.count)")
            LabeledContent(
                "Pendientes",
                value: "\(appState.graph.blocks.count - approved.count - ready.count)"
            )

            Divider()

            Text("La aprobación del proyecto completo se incorporará cuando existan responsables y reglas de gobierno en el modelo.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SummaryMetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: TazkleSpacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: TazkleRadius.control)
                    .fill(color.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(TazkleSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            TazkleColors.panel(
                for: colorScheme,
                highContrast: highContrast
            )
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

private struct SummaryCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(TazkleSpacing.large)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            TazkleColors.panel(
                for: colorScheme,
                highContrast: highContrast
            )
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

private enum SummaryStageState: Equatable {
    case complete
    case active
    case attention
    case pending
}

private struct SummaryCycleStage: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let state: SummaryStageState
}

private struct SummaryCycleTimeline: View {
    let stages: [SummaryCycleStage]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalTimeline
            verticalTimeline
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ciclo del proyecto")
        .accessibilityValue(
            stages
                .map { "\($0.title): \($0.detail)" }
                .joined(separator: ". ")
        )
    }

    private var horizontalTimeline: some View {
        HStack(alignment: .center, spacing: TazkleSpacing.medium) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                SummaryCycleStageView(stage: stage)
                    .frame(minWidth: 142, alignment: .leading)

                if index < stages.count - 1 {
                    SummaryCycleConnector(
                        state: stage.state,
                        direction: .horizontal
                    )
                    .frame(minWidth: 34, maxWidth: .infinity)
                }
            }
        }
    }

    private var verticalTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                SummaryCycleStageView(stage: stage)

                if index < stages.count - 1 {
                    SummaryCycleConnector(
                        state: stage.state,
                        direction: .vertical
                    )
                    .frame(width: 38, height: 28)
                }
            }
        }
    }
}

private struct SummaryCycleStageView: View {
    let stage: SummaryCycleStage

    private var color: Color {
        switch stage.state {
        case .complete: TazkleColors.success
        case .active: TazkleColors.actionPrimary
        case .attention: TazkleColors.warning
        case .pending: .secondary
        }
    }

    private var systemImage: String {
        switch stage.state {
        case .complete: "checkmark"
        case .active: "circle.fill"
        case .attention: "exclamationmark"
        case .pending: ""
        }
    }

    var body: some View {
        HStack(spacing: TazkleSpacing.medium) {
            ZStack {
                Circle()
                    .fill(stage.state == .active ? color.opacity(0.16) : Color.clear)
                    .overlay {
                        Circle()
                            .stroke(color, lineWidth: stage.state == .active ? 3 : 2)
                    }
                    .frame(width: 38, height: 38)

                if !systemImage.isEmpty {
                    Image(systemName: systemImage)
                        .font(stage.state == .active ? .system(size: 10, weight: .bold) : .caption.weight(.bold))
                        .foregroundStyle(color)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(stage.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(stage.state == .active ? color : .primary)
                Text(stage.detail)
                    .font(.caption)
                    .foregroundStyle(color)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stage.title)
        .accessibilityValue(stage.detail)
    }
}

private struct SummaryCycleConnector: View {
    enum Direction: Equatable {
        case horizontal
        case vertical
    }

    let state: SummaryStageState
    let direction: Direction

    private var color: Color {
        switch state {
        case .complete: TazkleColors.success.opacity(0.7)
        case .attention: TazkleColors.warning.opacity(0.8)
        case .active: TazkleColors.actionPrimary.opacity(0.7)
        case .pending: Color.secondary.opacity(0.24)
        }
    }

    private var dash: [CGFloat] {
        state == .attention ? [5, 4] : []
    }

    var body: some View {
        Canvas { context, size in
            var path = Path()
            switch direction {
            case .horizontal:
                path.move(to: CGPoint(x: 0, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            case .vertical:
                path.move(to: CGPoint(x: 19, y: 0))
                path.addLine(to: CGPoint(x: 19, y: size.height))
            }
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: dash)
            )
        }
        .frame(height: direction == .horizontal ? 38 : nil)
        .accessibilityHidden(true)
    }
}

private struct SummaryMilestoneRow: View {
    let title: String
    let detail: String
    let complete: Bool

    var body: some View {
        HStack(alignment: .top, spacing: TazkleSpacing.medium) {
            Image(systemName: complete ? "checkmark.circle.fill" : "circle.dashed")
                .font(.title3)
                .foregroundStyle(complete ? TazkleColors.success : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(complete ? "Completado" : "Pendiente")
                .font(.caption.weight(.semibold))
                .foregroundStyle(complete ? TazkleColors.success : .secondary)
        }
        .padding(.vertical, TazkleSpacing.small)
        .accessibilityElement(children: .combine)
    }
}

private struct SummaryRiskDetailRow: View {
    let title: String
    let detail: String
    let badge: String

    var body: some View {
        HStack(alignment: .top, spacing: TazkleSpacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(TazkleColors.warning)
            VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(TazkleColors.warning)
            }
        }
        .padding(.vertical, TazkleSpacing.small)
        .accessibilityElement(children: .combine)
    }
}

private struct SummaryEmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
            Label(title, systemImage: "tray")
                .font(.callout.weight(.semibold))
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
