import SwiftUI
import TazkleDesignSystem
import TazkleDomain

struct ArchitectureView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    private var warningCount: Int {
        let warningBlocks = appState.graph.blocks.count { $0.state == .warning && $0.architectureLayer != nil }
        let criticalRelations = appState.graph.relations.count { $0.isCritical }
        return warningBlocks + criticalRelations
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            Group {
                switch appState.architectureProjection {
                case .diagram:
                    ArchitectureDiagramView()
                case .list:
                    ArchitectureListView()
                }
            }
            .background(TazkleColors.canvas(for: colorScheme, highContrast: highContrast))
        }
    }

    private var toolbar: some View {
        HStack(spacing: TazkleSpacing.medium) {
            Picker("Proyección de arquitectura", selection: $appState.architectureProjection) {
                ForEach(ArchitectureProjection.allCases) { projection in
                    Label(projection.title, systemImage: projection.systemImage)
                        .tag(projection)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 190)

            if appState.architectureProjection == .diagram {
                Picker("Herramienta del lienzo", selection: $appState.architectureTool) {
                    ForEach(CanvasInteractionTool.allCases) { tool in
                        Image(systemName: tool.systemImage)
                            .accessibilityLabel(tool.title)
                            .tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 84)
                .help(appState.architectureTool.title)
            }

            Menu {
                Button("Todas las capas") {
                    appState.selectedArchitectureLayer = nil
                }
                Divider()
                ForEach(ArchitectureLayer.allCases) { layer in
                    Button(layer.displayName) {
                        appState.selectedArchitectureLayer = layer
                    }
                }
            } label: {
                Label(
                    appState.selectedArchitectureLayer?.displayName ?? "Todas las capas",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }
            .accessibilityLabel("Filtrar arquitectura")
            .accessibilityValue(appState.selectedArchitectureLayer?.displayName ?? "Todas las capas")

            Spacer()

            Label(
                warningCount == 1 ? "1 advertencia" : "\(warningCount) advertencias",
                systemImage: warningCount == 0 ? "checkmark.circle" : "exclamationmark.triangle"
            )
            .font(.callout.weight(.medium))
            .foregroundStyle(warningCount == 0 ? TazkleColors.success : TazkleColors.warning)
            .fixedSize()
            .accessibilityLabel(
                warningCount == 0
                    ? "Arquitectura sin advertencias locales"
                    : "Arquitectura con \(warningCount) advertencias locales"
            )

            Button {
                appState.presentNewBlock(family: .technology)
            } label: {
                Label("Nuevo bloque técnico", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            Button {
                appState.isInspectorPresented.toggle()
            } label: {
                Image(systemName: "sidebar.right")
            }
            .buttonStyle(.bordered)
            .disabled(appState.selectedBlock == nil && appState.selectedRelation == nil)
            .accessibilityLabel(
                appState.isInspectorPresented ? "Contraer detalle técnico" : "Mostrar detalle técnico"
            )
            .help(
                appState.selectedBlock == nil && appState.selectedRelation == nil
                    ? "Selecciona un bloque o una relación para consultar su detalle técnico"
                    : appState.isInspectorPresented ? "Contraer detalle técnico" : "Mostrar detalle técnico"
            )
        }
        .controlSize(.small)
        .padding(.horizontal, TazkleSpacing.large)
        .frame(height: 44)
        .background(TazkleColors.panel(for: colorScheme, highContrast: highContrast))
    }
}

private struct ArchitectureDiagramView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeDropLayer: ArchitectureLayer?
    @State private var connectionDraft: CanvasConnectionDraft?
    @State private var blockDrag: CanvasBlockDragSession?
    @State private var dropLayer: ArchitectureLayer?
    @State private var dropTargetID: UUID?
    @State private var hoveredBlockID: UUID?
    @State private var canvasOffset = CGSize.zero
    @State private var panOrigin: CGSize?
    @State private var zoom: CGFloat = 1
    @State private var magnificationOrigin: CGFloat?

    private let bandHeight: CGFloat = 190
    private let labelWidth: CGFloat = 180
    private let cardWidth: CGFloat = 236
    private let cardHeight: CGFloat = 148
    private let cardSpacing: CGFloat = 34

    private var visibleLayers: [ArchitectureLayer] {
        if let selected = appState.selectedArchitectureLayer {
            return [selected]
        }
        return ArchitectureLayer.allCases
    }

    private var visibleBlocks: [ProjectBlock] {
        appState.graph.blocks.filter { block in
            guard let layer = block.architectureLayer else { return false }
            return appState.selectedArchitectureLayer == nil || layer == appState.selectedArchitectureLayer
        }
    }

    private var maximumBlocksInLayer: Int {
        visibleLayers.map { layer in
            visibleBlocks.count { $0.architectureLayer == layer }
        }.max() ?? 0
    }

    private var canvasWidth: CGFloat {
        let previewSlot = blockDrag == nil ? 0 : 1
        return max(
            2_400,
            labelWidth + 64 + CGFloat(maximumBlocksInLayer + previewSlot) * (cardWidth + cardSpacing)
        )
    }

    private var canvasHeight: CGFloat {
        max(900, CGFloat(visibleLayers.count) * bandHeight + 32)
    }

    private var positions: [UUID: CGPoint] {
        var result: [UUID: CGPoint] = [:]
        for (layerIndex, layer) in visibleLayers.enumerated() {
            let blocks = visibleBlocks.filter { $0.architectureLayer == layer }
            for (blockIndex, block) in blocks.enumerated() {
                result[block.id] = CGPoint(
                    x: labelWidth + 56 + cardWidth / 2 + CGFloat(blockIndex) * (cardWidth + cardSpacing),
                    y: 16 + CGFloat(layerIndex) * bandHeight + bandHeight / 2
                )
            }
        }
        return result
    }

    var body: some View {
        if visibleBlocks.isEmpty {
            ContentUnavailableView {
                Label("Sin bloques arquitectónicos", systemImage: "square.3.layers.3d")
            } description: {
                Text("Asigna una capa a un bloque existente o crea un bloque técnico.")
            } actions: {
                Button("Crear bloque técnico") {
                    appState.presentNewBlock(family: .technology)
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            GeometryReader { viewport in
                ZStack(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        layerBands
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                TapGesture()
                                    .onEnded { appState.clearCanvasSelection() }
                            )
                            .gesture(
                                panGesture(viewportSize: viewport.size),
                                including: appState.architectureTool == .select ? .gesture : .none
                            )
                        relationshipLayer
                            .allowsHitTesting(false)
                        relationshipControls
                            .allowsHitTesting(appState.architectureTool == .select)
                            .zIndex(3)
                        blockCards
                    }
                    .frame(width: canvasWidth, height: canvasHeight)
                    .coordinateSpace(name: "architectureCanvas")
                    .scaleEffect(zoom, anchor: .topLeading)
                    .offset(canvasOffset)
                }
                .frame(
                    width: viewport.size.width,
                    height: viewport.size.height,
                    alignment: .topLeading
                )
                .contentShape(Rectangle())
                .background {
                    CanvasScrollCapture { delta in
                        scrollCanvas(by: delta, viewportSize: viewport.size)
                    }
                }
                .simultaneousGesture(
                    panGesture(viewportSize: viewport.size),
                    including: appState.architectureTool == .pan ? .all : .none
                )
                .simultaneousGesture(magnificationGesture(viewportSize: viewport.size))
                .clipped()
                .overlay(alignment: .topLeading) {
                    CanvasNavigationHUD(
                        canvasSize: CGSize(width: canvasWidth, height: canvasHeight),
                        viewportSize: viewport.size,
                        canvasOffset: canvasOffset,
                        zoom: zoom,
                        items: visibleBlocks.compactMap { block in
                            guard let position = displayedPositions[block.id] else { return nil }
                            return CanvasMiniMapItem(
                                id: block.id,
                                position: position,
                                color: block.architectureLayer?.accentColor ?? block.family.accentColor
                            )
                        },
                        onNavigate: { point in
                            navigate(to: point, viewportSize: viewport.size)
                        },
                        onZoomChange: { newZoom in
                            setZoom(newZoom, viewportSize: viewport.size)
                        },
                        onFit: {
                            fitCanvas(in: viewport.size)
                        }
                    )
                    .offset(
                        x: TazkleSpacing.large,
                        y: max(
                            TazkleSpacing.large,
                            viewport.size.height - 159
                        )
                    )
                }
                .onChange(of: appState.canvasResetRevision) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        canvasOffset = .zero
                        zoom = 1
                    }
                }
            }
            .accessibilityRotor("Bloques de arquitectura") {
                ForEach(visibleBlocks) { block in
                    AccessibilityRotorEntry(block.title, id: block.id)
                }
            }
        }
    }

    private var layerBands: some View {
        ForEach(Array(visibleLayers.enumerated()), id: \.element) { index, layer in
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: TazkleSpacing.small) {
                    Label(layer.displayName, systemImage: layer.systemImage)
                        .font(.headline)
                    Text(layer.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(TazkleSpacing.large)
                .frame(width: labelWidth, height: bandHeight - 12, alignment: .topLeading)

                Divider()

                if visibleBlocks.contains(where: { $0.architectureLayer == layer }) {
                    Color.clear
                } else {
                    Text("Sin bloques asignados")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.leading, TazkleSpacing.xLarge)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: canvasWidth, height: bandHeight - 12)
            .background(
                TazkleColors.panel(
                    for: colorScheme,
                    highContrast: highContrast
                )
                .opacity(highContrast ? 1 : 0.72)
            )
            .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.panel))
            .overlay {
                RoundedRectangle(cornerRadius: TazkleRadius.panel)
                    .stroke(
                        activeDropLayer == layer
                            ? layer.accentColor
                            : TazkleColors.separator(
                                for: colorScheme,
                                highContrast: highContrast
                            ),
                        lineWidth: activeDropLayer == layer ? 2.5 : (highContrast ? 1.5 : 1)
                    )
            }
            .offset(y: CGFloat(index) * bandHeight + 6)
            .dropDestination(for: String.self) { items, _ in
                guard let blockID = droppedBlockID(from: items) else { return false }
                appState.moveArchitectureBlock(blockID, to: layer)
                return true
            } isTargeted: { isTargeted in
                activeDropLayer = isTargeted ? layer : nil
            }
            .accessibilityLabel("Capa \(layer.displayName)")
            .accessibilityHint("Destino para bloques de arquitectura")
        }
    }

    private var relationshipLayer: some View {
        Canvas { context, _ in
            let selectedBlockID = appState.selectedBlockID
            let selectedRelationID = appState.selectedRelationID
            let orderedRelations = appState.graph.relations.sorted {
                relationPriority($0, selectedBlockID: selectedBlockID)
                    < relationPriority($1, selectedBlockID: selectedBlockID)
            }

            for relation in orderedRelations {
                guard
                    let start = displayedPositions[relation.sourceID],
                    let end = displayedPositions[relation.targetID]
                else {
                    continue
                }
                let isSelected = relation.id == selectedRelationID
                let isDimmed = selectedRelationID != nil
                    ? !isSelected
                    : selectedBlockID != nil
                        && relation.sourceID != selectedBlockID
                        && relation.targetID != selectedBlockID

                let route = architectureConnectionRoute(
                    source: start,
                    target: end,
                    cardSize: CGSize(width: cardWidth, height: cardHeight),
                    sourcePort: relation.sourcePort,
                    targetPort: relation.targetPort
                )
                let path = architectureConnectionPath(for: route)

                let baseColor = relation.isCritical ? TazkleColors.warning : TazkleColors.assistantProposal
                let color = baseColor.opacity(isDimmed ? 0.16 : 1)
                context.stroke(
                    path,
                    with: .color(
                        TazkleColors.canvas(
                            for: colorScheme,
                            highContrast: highContrast
                        )
                    ),
                    style: StrokeStyle(
                        lineWidth: isSelected ? 7.8 : (relation.isCritical ? 6.6 : 5.8),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(
                        lineWidth: isSelected ? 3.3 : (relation.isCritical ? 2.6 : 1.8),
                        lineCap: .round,
                        lineJoin: .round,
                        dash: relation.isCritical ? [7, 5] : []
                    )
                )

                context.stroke(
                    architectureArrowPath(for: route),
                    with: .color(color),
                    style: StrokeStyle(lineWidth: relation.isCritical ? 2.6 : 1.8, lineCap: .round)
                )
                drawConnectionVertex(
                    in: &context,
                    at: route.start,
                    color: color,
                    surface: TazkleColors.panel(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
                drawConnectionVertex(
                    in: &context,
                    at: route.end,
                    color: color,
                    surface: TazkleColors.panel(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )

            }

            if let draft = connectionDraft,
               let start = displayedPositions[draft.sourceID] {
                let liveRoute: ArchitectureConnectionRoute
                if let targetID = draft.targetID,
                   let targetPort = draft.targetPort,
                   let end = displayedPositions[targetID] {
                    liveRoute = architectureConnectionRoute(
                        source: start,
                        target: end,
                        cardSize: CGSize(width: cardWidth, height: cardHeight),
                        sourcePort: draft.sourcePort,
                        targetPort: targetPort
                    )
                } else {
                    liveRoute = liveArchitectureConnectionRoute(
                        start: connectionPortPoint(
                            center: start,
                            cardSize: CGSize(width: cardWidth, height: cardHeight),
                            port: draft.sourcePort
                        ),
                        end: draft.currentPoint,
                        sourcePort: draft.sourcePort
                    )
                }

                let livePath = architectureConnectionPath(for: liveRoute)
                context.stroke(
                    livePath,
                    with: .color(TazkleColors.assistantProposal),
                    style: StrokeStyle(
                        lineWidth: 2.5,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [8, 6]
                    )
                )

                context.stroke(
                    architectureArrowPath(for: liveRoute),
                    with: .color(TazkleColors.assistantProposal),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                drawConnectionVertex(
                    in: &context,
                    at: liveRoute.start,
                    color: TazkleColors.assistantProposal,
                    surface: TazkleColors.panel(
                        for: colorScheme,
                        highContrast: highContrast
                    ),
                    emphasized: true
                )
                drawConnectionVertex(
                    in: &context,
                    at: liveRoute.end,
                    color: TazkleColors.assistantProposal,
                    surface: TazkleColors.panel(
                        for: colorScheme,
                        highContrast: highContrast
                    ),
                    emphasized: true
                )
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var relationshipControls: some View {
        ZStack {
            ForEach(appState.graph.relations) { relation in
                if let start = displayedPositions[relation.sourceID],
                   let end = displayedPositions[relation.targetID] {
                    let route = architectureConnectionRoute(
                        source: start,
                        target: end,
                        cardSize: CGSize(width: cardWidth, height: cardHeight),
                        sourcePort: relation.sourcePort,
                        targetPort: relation.targetPort
                    )
                    RelationCanvasHitTarget(
                        relation: relation,
                        path: architectureConnectionPath(for: route)
                    )
                }
            }

            let labelFractionByRelation = labelFractions(for: appState.graph.relations)
            ForEach(appState.graph.relations) { relation in
                if let start = displayedPositions[relation.sourceID],
                   let end = displayedPositions[relation.targetID] {
                    let route = architectureConnectionRoute(
                        source: start,
                        target: end,
                        cardSize: CGSize(width: cardWidth, height: cardHeight),
                        sourcePort: relation.sourcePort,
                        targetPort: relation.targetPort
                    )
                    RelationCanvasControl(relation: relation)
                        .position(route.label(fraction: labelFractionByRelation[relation.id] ?? 0.5))
                }
            }
        }
    }

    /// Relaciones que comparten origen o destino comparten también un tramo de su recorrido
    /// ortogonal; separa la fracción de etiqueta de cada una para que no se superpongan sobre
    /// ese tramo compartido (ver `ArchitectureConnectionRoute.label(fraction:)`).
    private func labelFractions(for relations: [BlockRelation]) -> [UUID: CGFloat] {
        var bySource: [UUID: [UUID]] = [:]
        var byTarget: [UUID: [UUID]] = [:]
        for relation in relations {
            bySource[relation.sourceID, default: []].append(relation.id)
            byTarget[relation.targetID, default: []].append(relation.id)
        }

        func spread(_ siblings: [UUID]?, for id: UUID, ascending: Bool) -> CGFloat? {
            guard let siblings, siblings.count > 1,
                  let index = siblings.firstIndex(of: id) else { return nil }
            let step = 0.3 / CGFloat(siblings.count - 1)
            let offset = CGFloat(index) * step - 0.15
            return ascending ? 0.5 + offset : 0.5 - offset
        }

        var fractions: [UUID: CGFloat] = [:]
        for relation in relations {
            let fromSource = spread(bySource[relation.sourceID], for: relation.id, ascending: true)
            let fromTarget = spread(byTarget[relation.targetID], for: relation.id, ascending: false)
            switch (fromSource, fromTarget) {
            case let (source?, target?):
                fractions[relation.id] = (source + target) / 2
            case let (source?, nil):
                fractions[relation.id] = source
            case let (nil, target?):
                fractions[relation.id] = target
            case (nil, nil):
                continue
            }
        }
        return fractions
    }

    private var blockCards: some View {
        ForEach(visibleBlocks) { block in
            if let position = positions[block.id] {
                if let session = blockDrag, session.blockID == block.id {
                    CanvasDropPlaceholder(
                        size: CGSize(width: cardWidth, height: cardHeight),
                        accent: block.architectureLayer?.accentColor ?? block.family.accentColor
                    )
                    .position(session.origin)

                    CanvasLandingShadow(
                        size: CGSize(width: cardWidth, height: cardHeight),
                        accent: dropLayer?.accentColor
                            ?? block.architectureLayer?.accentColor
                            ?? block.family.accentColor
                    )
                    .position(session.destination)
                    .zIndex(4)
                }

                ZStack {
                    ArchitectureBlockCard(
                        block: block,
                        isDragging: blockDrag?.blockID == block.id,
                        isConnectionTarget: connectionDraft?.targetID == block.id,
                        size: CGSize(width: cardWidth, height: cardHeight)
                    )
                    .highPriorityGesture(
                        dragGesture(for: block),
                        including: appState.architectureTool == .select ? .gesture : .none
                    )

                    ForEach(ConnectionPort.allCases) { port in
                        CanvasConnectionPort(
                            port: port,
                            blockTitle: block.title,
                            isActive: connectionDraft?.sourceID == block.id
                                && connectionDraft?.sourcePort == port,
                            isDropTarget: connectionDraft?.targetID == block.id
                                && connectionDraft?.targetPort == port,
                            isRevealed: hoveredBlockID == block.id || connectionDraft != nil
                        ) {
                            appState.selectBlock(block.id)
                            appState.beginRelation(
                                sourceID: block.id,
                                sourcePort: port
                            )
                        }
                        .offset(
                            connectionPortOffset(
                                for: port,
                                cardSize: CGSize(width: cardWidth, height: cardHeight)
                            )
                        )
                        .highPriorityGesture(
                            connectionGesture(from: block, sourcePort: port)
                        )
                        .disabled(appState.architectureTool == .pan)
                    }
                }
                .onHover { isHovering in
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                        if isHovering {
                            hoveredBlockID = block.id
                        } else if hoveredBlockID == block.id {
                            hoveredBlockID = nil
                        }
                    }
                }
                .position(displayedPositions[block.id] ?? position)
                .zIndex(
                    blockDrag?.blockID == block.id
                        ? 10
                        : connectionDraft?.targetID == block.id ? 6 : 1
                )
                .dropDestination(for: String.self) { items, _ in
                    guard
                        let blockID = droppedBlockID(from: items),
                        blockID != block.id,
                        let layer = block.architectureLayer
                    else {
                        return false
                    }
                    appState.moveArchitectureBlock(blockID, to: layer, before: block.id)
                    return true
                }
            }
        }
    }

    private var displayedPositions: [UUID: CGPoint] {
        var result = previewPositions
        if let blockDrag {
            result[blockDrag.blockID] = blockDrag.current
        }
        return result
    }

    private var previewPositions: [UUID: CGPoint] {
        var blocksByLayer: [ArchitectureLayer: [ProjectBlock]] = [:]
        for layer in visibleLayers {
            blocksByLayer[layer] = visibleBlocks.filter { $0.architectureLayer == layer }
        }

        if
            let blockDrag,
            let dropLayer,
            let draggedBlock = visibleBlocks.first(where: { $0.id == blockDrag.blockID })
        {
            for layer in visibleLayers {
                blocksByLayer[layer]?.removeAll { $0.id == blockDrag.blockID }
            }

            var targetBlocks = blocksByLayer[dropLayer] ?? []
            if
                let dropTargetID,
                let targetIndex = targetBlocks.firstIndex(where: { $0.id == dropTargetID })
            {
                targetBlocks.insert(draggedBlock, at: targetIndex)
            } else {
                targetBlocks.append(draggedBlock)
            }
            blocksByLayer[dropLayer] = targetBlocks
        }

        var result: [UUID: CGPoint] = [:]
        for (layerIndex, layer) in visibleLayers.enumerated() {
            for (blockIndex, block) in (blocksByLayer[layer] ?? []).enumerated() {
                result[block.id] = slotPosition(layerIndex: layerIndex, blockIndex: blockIndex)
            }
        }
        return result
    }

    private func dragGesture(for block: ProjectBlock) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("architectureCanvas"))
            .onChanged { value in
                guard let origin = positions[block.id] else { return }
                let sessionOrigin = blockDrag?.blockID == block.id
                    ? blockDrag?.origin ?? origin
                    : origin

                let current = CGPoint(
                    x: min(max(sessionOrigin.x + value.translation.width, cardWidth / 2), canvasWidth - cardWidth / 2),
                    y: min(max(sessionOrigin.y + value.translation.height, cardHeight / 2), canvasHeight - cardHeight / 2)
                )
                let targetLayer = layer(at: value.location) ?? block.architectureLayer ?? .services
                let targetID = insertionTarget(
                    atX: value.location.x,
                    moving: block.id,
                    in: targetLayer
                )
                let destination = destinationPosition(
                    moving: block.id,
                    in: targetLayer,
                    before: targetID
                )

                dropLayer = targetLayer
                dropTargetID = targetID
                blockDrag = CanvasBlockDragSession(
                    blockID: block.id,
                    origin: sessionOrigin,
                    current: current,
                    destination: destination
                )
                activeDropLayer = targetLayer
            }
            .onEnded { _ in
                guard let session = blockDrag, session.blockID == block.id else { return }
                let targetLayer = dropLayer ?? block.architectureLayer ?? .services
                let targetID = dropTargetID
                appState.moveArchitectureBlock(block.id, to: targetLayer, before: targetID)
                appState.selectBlock(block.id)

                withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.84)) {
                    blockDrag = nil
                    activeDropLayer = nil
                    dropLayer = nil
                    dropTargetID = nil
                }
            }
    }

    private func insertionTarget(
        atX x: CGFloat,
        moving blockID: UUID,
        in layer: ArchitectureLayer
    ) -> UUID? {
        guard let layerIndex = visibleLayers.firstIndex(of: layer) else { return nil }
        let candidates = visibleBlocks.filter {
            $0.architectureLayer == layer && $0.id != blockID
        }

        for (index, candidate) in candidates.enumerated() {
            let slot = slotPosition(layerIndex: layerIndex, blockIndex: index)
            if x < slot.x {
                return candidate.id
            }
        }
        return nil
    }

    private func destinationPosition(
        moving blockID: UUID,
        in layer: ArchitectureLayer,
        before targetID: UUID?
    ) -> CGPoint {
        guard let layerIndex = visibleLayers.firstIndex(of: layer) else {
            return blockDrag?.destination ?? .zero
        }
        let candidates = visibleBlocks.filter {
            $0.architectureLayer == layer && $0.id != blockID
        }
        let blockIndex = targetID.flatMap { targetID in
            candidates.firstIndex { $0.id == targetID }
        } ?? candidates.count
        return slotPosition(layerIndex: layerIndex, blockIndex: blockIndex)
    }

    private func slotPosition(layerIndex: Int, blockIndex: Int) -> CGPoint {
        CGPoint(
            x: labelWidth + 56 + cardWidth / 2 + CGFloat(blockIndex) * (cardWidth + cardSpacing),
            y: 16 + CGFloat(layerIndex) * bandHeight + bandHeight / 2
        )
    }

    private func panGesture(viewportSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                let origin = panOrigin ?? canvasOffset
                if panOrigin == nil {
                    panOrigin = origin
                }
                canvasOffset = clampedCanvasOffset(
                    CGSize(
                        width: origin.width + value.translation.width,
                        height: origin.height + value.translation.height
                    ),
                    canvasSize: scaledCanvasSize(
                        CGSize(width: canvasWidth, height: canvasHeight),
                        zoom: zoom
                    ),
                    viewportSize: viewportSize
                )
            }
            .onEnded { _ in
                panOrigin = nil
            }
    }

    private func scrollCanvas(by delta: CGSize, viewportSize: CGSize) {
        canvasOffset = clampedCanvasOffset(
            CGSize(
                width: canvasOffset.width + delta.width,
                height: canvasOffset.height + delta.height
            ),
            canvasSize: scaledCanvasSize(
                CGSize(width: canvasWidth, height: canvasHeight),
                zoom: zoom
            ),
            viewportSize: viewportSize
        )
    }

    private func magnificationGesture(viewportSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let origin = magnificationOrigin ?? zoom
                if magnificationOrigin == nil {
                    magnificationOrigin = origin
                }
                setZoom(origin * value, viewportSize: viewportSize)
            }
            .onEnded { _ in
                magnificationOrigin = nil
            }
    }

    private func setZoom(_ proposedZoom: CGFloat, viewportSize: CGSize) {
        let newZoom = clampedCanvasZoom(proposedZoom)
        guard abs(newZoom - zoom) > 0.001 else { return }

        let logicalCenter = CGPoint(
            x: (viewportSize.width / 2 - canvasOffset.width) / zoom,
            y: (viewportSize.height / 2 - canvasOffset.height) / zoom
        )
        zoom = newZoom
        canvasOffset = clampedCanvasOffset(
            CGSize(
                width: viewportSize.width / 2 - logicalCenter.x * newZoom,
                height: viewportSize.height / 2 - logicalCenter.y * newZoom
            ),
            canvasSize: scaledCanvasSize(
                CGSize(width: canvasWidth, height: canvasHeight),
                zoom: newZoom
            ),
            viewportSize: viewportSize
        )
    }

    private func fitCanvas(in viewportSize: CGSize) {
        let canvasSize = CGSize(width: canvasWidth, height: canvasHeight)
        zoom = clampedCanvasZoom(
            min(
                (viewportSize.width - TazkleSpacing.xxLarge) / canvasSize.width,
                (viewportSize.height - TazkleSpacing.xxLarge) / canvasSize.height
            )
        )
        canvasOffset = .zero
    }

    private func navigate(to point: CGPoint, viewportSize: CGSize) {
        let canvasSize = CGSize(width: canvasWidth, height: canvasHeight)
        canvasOffset = clampedCanvasOffset(
            CGSize(
                width: viewportSize.width / 2 - point.x * zoom,
                height: viewportSize.height / 2 - point.y * zoom
            ),
            canvasSize: scaledCanvasSize(canvasSize, zoom: zoom),
            viewportSize: viewportSize
        )
    }

    private func layer(at point: CGPoint) -> ArchitectureLayer? {
        guard !visibleLayers.isEmpty else { return nil }
        let rawIndex = Int(floor(point.y / bandHeight))
        let index = min(max(rawIndex, 0), visibleLayers.count - 1)
        return visibleLayers[index]
    }

    private func connectionGesture(
        from block: ProjectBlock,
        sourcePort: ConnectionPort
    ) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("architectureCanvas"))
            .onChanged { value in
                let target = targetConnection(at: value.location, excluding: block.id)
                connectionDraft = CanvasConnectionDraft(
                    sourceID: block.id,
                    sourcePort: sourcePort,
                    currentPoint: value.location,
                    targetID: target?.blockID,
                    targetPort: target?.port
                )
            }
            .onEnded { value in
                let target = targetConnection(at: value.location, excluding: block.id)
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) {
                    connectionDraft = nil
                }
                if let target {
                    appState.beginRelation(
                        sourceID: block.id,
                        targetID: target.blockID,
                        sourcePort: sourcePort,
                        targetPort: target.port
                    )
                }
            }
    }

    private func targetConnection(
        at point: CGPoint,
        excluding sourceID: UUID
    ) -> CanvasConnectionTarget? {
        var nearestTarget: CanvasConnectionTarget?
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        let size = CGSize(width: cardWidth, height: cardHeight)

        for block in visibleBlocks where block.id != sourceID {
            guard let position = displayedPositions[block.id] else { continue }
            for port in ConnectionPort.allCases {
                let portPoint = connectionPortPoint(
                    center: position,
                    cardSize: size,
                    port: port
                )
                let distance = hypot(point.x - portPoint.x, point.y - portPoint.y)
                if distance <= 28, distance < nearestDistance {
                    nearestTarget = CanvasConnectionTarget(blockID: block.id, port: port)
                    nearestDistance = distance
                }
            }
        }

        return nearestTarget
    }

    private func droppedBlockID(from items: [String]) -> UUID? {
        items.lazy.compactMap { item in
            guard case let .existingBlock(id) = CanvasDragPayload(rawValue: item) else {
                return nil
            }
            return id
        }.first
    }
}

private struct ArchitectureBlockCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    let block: ProjectBlock
    let isDragging: Bool
    let isConnectionTarget: Bool
    let size: CGSize

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            HStack(alignment: .top) {
                Image(systemName: block.architectureLayer?.systemImage ?? block.family.systemImage)
                    .font(.headline)
                    .foregroundStyle(block.architectureLayer?.accentColor ?? block.family.accentColor)
                Text(block.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: TazkleSpacing.small)
                Image(systemName: block.state.systemImage)
                    .foregroundStyle(block.state == .warning ? TazkleColors.warning : .secondary)
            }

            Text(block.summary.isEmpty ? "Sin descripción técnica." : block.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(block.architectureLayer?.displayName ?? "Sin capa")
                .font(.caption.weight(.medium))
                .foregroundStyle(block.architectureLayer?.accentColor ?? .secondary)
        }
        .padding(TazkleSpacing.large)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(
            TazkleColors.elevated(
                for: colorScheme,
                highContrast: highContrast
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
        .overlay {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: TazkleRadius.card)
                    .stroke(
                        isConnectionTarget || appState.selectedBlockID == block.id || isFocused
                            ? TazkleColors.assistantProposal
                            : (block.architectureLayer?.accentColor ?? block.family.accentColor).opacity(0.7),
                        lineWidth: isConnectionTarget || appState.selectedBlockID == block.id || isFocused ? 2.5 : 1
                    )

                if isConnectionTarget {
                    CanvasConnectionDropHint()
                        .offset(y: 18)
                }
            }
        }
        .shadow(
            color: isConnectionTarget
                ? TazkleColors.assistantProposal.opacity(0.28)
                : .black.opacity(isDragging ? 0.24 : 0),
            radius: isDragging ? 24 : (isConnectionTarget ? 18 : 0),
            y: isDragging ? 12 : 4
        )
        .contentShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
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
        .scaleEffect(isDragging && !reduceMotion ? 1.035 : 1)
        .opacity(isDragging ? 0.97 : 1)
        .animation(
            reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.82),
            value: isDragging
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(block.title)
        .accessibilityValue(
            "\(block.architectureLayer?.displayName ?? "Sin capa"), \(block.state.displayName), "
                + "\(appState.graph.relationshipCount(for: block.id)) relaciones"
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            appState.selectBlock(block.id)
        }
        .accessibilityHint("Selecciona el bloque o muévelo mediante las acciones disponibles")
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
        .contextMenu {
            ArchitectureBlockContextMenu(block: block)
        }
        .accessibilityAction(named: "Eliminar bloque") {
            appState.requestBlockDeletion(block.id)
        }
    }
}

private struct ArchitectureBlockContextMenu: View {
    @EnvironmentObject private var appState: AppState
    let block: ProjectBlock

    var body: some View {
        Menu("Mover a capa") {
            ForEach(ArchitectureLayer.allCases) { layer in
                Button(layer.displayName) {
                    appState.moveArchitectureBlock(block.id, to: layer)
                }
                .disabled(block.architectureLayer == layer)
            }
        }

        Divider()

        Button("Eliminar bloque", systemImage: "trash", role: .destructive) {
            appState.requestBlockDeletion(block.id)
        }
        .disabled(block.state == .approved)
    }
}

private struct ArchitectureListView: View {
    @EnvironmentObject private var appState: AppState

    private var visibleLayers: [ArchitectureLayer] {
        appState.selectedArchitectureLayer.map { [$0] } ?? ArchitectureLayer.allCases
    }

    var body: some View {
        List {
            ForEach(visibleLayers) { layer in
                Section {
                    let blocks = appState.graph.blocks.filter { $0.architectureLayer == layer }
                    if blocks.isEmpty {
                        Text("Sin bloques asignados.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(blocks) { block in
                            Button {
                                appState.selectBlock(block.id)
                            } label: {
                                HStack(spacing: TazkleSpacing.medium) {
                                    Image(systemName: layer.systemImage)
                                        .foregroundStyle(layer.accentColor)
                                    VStack(alignment: .leading) {
                                        Text(block.title)
                                            .font(.headline)
                                        Text(block.summary.isEmpty ? "Sin descripción técnica" : block.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Text("\(appState.graph.relationshipCount(for: block.id)) relaciones")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Eliminar bloque", systemImage: "trash", role: .destructive) {
                                    appState.requestBlockDeletion(block.id)
                                }
                                .disabled(block.state == .approved)
                            }
                        }
                    }
                } header: {
                    Label(layer.displayName, systemImage: layer.systemImage)
                }
            }

            Section("Relaciones visibles") {
                let visibleIDs = Set(
                    appState.graph.blocks
                        .filter { block in
                            guard let layer = block.architectureLayer else { return false }
                            return appState.selectedArchitectureLayer == nil || layer == appState.selectedArchitectureLayer
                        }
                        .map(\.id)
                )
                let relations = appState.graph.relations.filter {
                    visibleIDs.contains($0.sourceID) && visibleIDs.contains($0.targetID)
                }

                if relations.isEmpty {
                    Text("No hay relaciones entre los bloques visibles.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(relations) { relation in
                        HStack {
                            Button {
                                appState.selectRelation(relation.id)
                            } label: {
                                HStack {
                                    Image(systemName: relation.isCritical ? "exclamationmark.triangle" : "arrow.right")
                                        .foregroundStyle(
                                            relation.isCritical ? TazkleColors.warning : TazkleColors.assistantProposal
                                        )
                                    Text(appState.relationDescription(relation))
                                    Spacer()
                                    Text(relation.type.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

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
        .listStyle(.inset)
    }
}

extension ArchitectureLayer {
    var systemImage: String {
        switch self {
        case .experience: "display"
        case .services: "gearshape.2"
        case .data: "cylinder.split.1x2"
        case .infrastructure: "cloud"
        }
    }

    var accentColor: Color {
        switch self {
        case .experience: TazkleColors.actionPrimary
        case .services: TazkleColors.assistantProposal
        case .data: TazkleColors.success
        case .infrastructure: TazkleColors.relationship
        }
    }
}
