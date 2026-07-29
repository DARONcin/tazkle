import SwiftUI
import TazkleDesignSystem
import TazkleDomain

struct ProjectMapView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            Group {
                switch appState.projection {
                case .canvas:
                    ProjectCanvasView()
                case .list:
                    ProjectListView()
                }
            }
            .background(TazkleColors.canvas(for: colorScheme, highContrast: highContrast))
        }
    }

    private var toolbar: some View {
        HStack(spacing: TazkleSpacing.medium) {
            Picker("Proyección del proyecto", selection: $appState.projection) {
                ForEach(MapProjection.allCases) { projection in
                    Label(projection.title, systemImage: projection.systemImage)
                        .tag(projection)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 190)

            if appState.projection == .canvas {
                Picker("Herramienta del lienzo", selection: $appState.projectMapTool) {
                    ForEach(CanvasInteractionTool.allCases) { tool in
                        Image(systemName: tool.systemImage)
                            .accessibilityLabel(tool.title)
                            .tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 84)
                .help(appState.projectMapTool.title)
            }

            Divider().frame(height: 18)

            Label(appState.saveState.title, systemImage: appState.saveState.systemImage)
                .font(.callout)
                .foregroundStyle(appState.saveState == .failed ? TazkleColors.warning : .secondary)
                .accessibilityLabel("Estado local: \(appState.saveState.title)")
                .fixedSize()

            Spacer()

            Button {
                appState.beginRelation(sourceID: appState.selectedBlockID)
            } label: {
                Label("Crear relación", systemImage: "point.3.connected.trianglepath.dotted")
            }
            .disabled(appState.graph.blocks.count < 2)

            Button {
                appState.presentNewBlock()
            } label: {
                Label("Nuevo bloque", systemImage: "plus")
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
                appState.isInspectorPresented ? "Contraer inspector" : "Mostrar inspector"
            )
            .help(
                appState.selectedBlock == nil && appState.selectedRelation == nil
                    ? "Selecciona un bloque o una relación para consultar sus detalles"
                    : appState.isInspectorPresented ? "Contraer inspector" : "Mostrar inspector"
            )
        }
        .controlSize(.small)
        .padding(.horizontal, TazkleSpacing.large)
        .frame(height: 44)
        .background(TazkleColors.panel(for: colorScheme, highContrast: highContrast))
    }
}

private struct ProjectCanvasView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blockDrag: CanvasBlockDragSession?
    @State private var connectionDraft: CanvasConnectionDraft?
    @State private var isReceivingTemplate = false
    @State private var hoveredBlockID: UUID?
    @State private var canvasOffset = CGSize.zero
    @State private var panOrigin: CGSize?
    @State private var zoom: CGFloat = 1
    @State private var magnificationOrigin: CGFloat?

    private let cardSize = CGSize(width: 224, height: 148)
    private let canvasSize = CGSize(width: 3_200, height: 2_200)

    var body: some View {
        GeometryReader { viewport in
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    grid
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded { appState.clearCanvasSelection() }
                        )
                        .gesture(
                            panGesture(viewportSize: viewport.size),
                            including: appState.projectMapTool == .select ? .gesture : .none
                        )

                    relationshipLayer
                        .allowsHitTesting(false)

                    relationshipControls
                        .allowsHitTesting(appState.projectMapTool == .select)
                        .zIndex(3)

                    ForEach(appState.graph.blocks) { block in
                        if let session = blockDrag, session.blockID == block.id {
                            CanvasDropPlaceholder(
                                size: cardSize,
                                accent: block.family.accentColor
                            )
                            .position(point(for: block.position))

                            CanvasLandingShadow(
                                size: cardSize,
                                accent: block.family.accentColor
                            )
                            .position(session.destination)
                            .zIndex(4)
                        }

                        ZStack {
                            MapBlockCard(
                                block: block,
                                isSelected: appState.selectedBlockID == block.id,
                                isDragging: blockDrag?.blockID == block.id,
                                isConnectionTarget: connectionDraft?.targetID == block.id
                            )
                            .highPriorityGesture(
                                dragGesture(for: block),
                                including: appState.projectMapTool == .select ? .gesture : .none
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
                                .offset(connectionPortOffset(for: port, cardSize: cardSize))
                                .highPriorityGesture(connectionGesture(from: block, sourcePort: port))
                                .disabled(appState.projectMapTool == .pan)
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
                        .position(displayedPosition(for: block))
                        .zIndex(
                            blockDrag?.blockID == block.id
                                ? 10
                                : connectionDraft?.targetID == block.id ? 6 : 1
                        )
                    }

                    if isReceivingTemplate {
                        Label("Suelta para crear el bloque aquí", systemImage: "plus.circle.fill")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, TazkleSpacing.large)
                            .padding(.vertical, TazkleSpacing.medium)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                            .overlay { Capsule().stroke(TazkleColors.assistantProposal, lineWidth: 2) }
                            .shadow(color: .black.opacity(0.2), radius: 14, y: 7)
                            .position(x: canvasSize.width / 2, y: 42)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .coordinateSpace(name: "projectCanvas")
                .dropDestination(for: String.self) { items, location in
                    guard let family = droppedTemplate(from: items) else { return false }
                    appState.addBlock(
                        from: family,
                        at: safePosition(
                            BlockPosition(x: location.x, y: location.y)
                        )
                    )
                    return true
                } isTargeted: { isTargeted in
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) {
                        isReceivingTemplate = isTargeted
                    }
                }
                .overlay {
                    if isReceivingTemplate {
                        RoundedRectangle(cornerRadius: TazkleRadius.panel)
                            .stroke(TazkleColors.assistantProposal.opacity(0.8), lineWidth: 2)
                            .padding(3)
                        .allowsHitTesting(false)
                    }
                }
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
                including: appState.projectMapTool == .pan ? .all : .none
            )
            .simultaneousGesture(magnificationGesture(viewportSize: viewport.size))
            .clipped()
            .overlay(alignment: .topLeading) {
                CanvasNavigationHUD(
                    canvasSize: canvasSize,
                    viewportSize: viewport.size,
                    canvasOffset: canvasOffset,
                    zoom: zoom,
                    items: appState.graph.blocks.map { block in
                        CanvasMiniMapItem(
                            id: block.id,
                            position: displayedPosition(for: block),
                            color: block.family.accentColor
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
        .accessibilityRotor("Bloques") {
            ForEach(appState.graph.blocks) { block in
                AccessibilityRotorEntry(block.title, id: block.id)
            }
        }
    }

    private var grid: some View {
        Canvas { context, size in
            let color = TazkleColors.separator(
                for: colorScheme,
                highContrast: highContrast
            )
            .opacity(highContrast ? 0.55 : 0.35)
            for x in stride(from: 20.0, through: size.width, by: 24.0) {
                for y in stride(from: 20.0, through: size.height, by: 24.0) {
                    let rect = CGRect(x: x, y: y, width: 1.5, height: 1.5)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
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
                    let source = appState.graph.block(id: relation.sourceID),
                    let target = appState.graph.block(id: relation.targetID)
                else { continue }
                let isSelected = relation.id == selectedRelationID
                let isDimmed = selectedRelationID != nil
                    ? !isSelected
                    : selectedBlockID != nil
                        && relation.sourceID != selectedBlockID
                        && relation.targetID != selectedBlockID

                let geometry = connectionGeometry(
                    source: displayedPosition(for: source),
                    target: displayedPosition(for: target),
                    cardSize: cardSize,
                    sourcePort: relation.sourcePort,
                    targetPort: relation.targetPort
                )
                let path = projectConnectionPath(for: geometry)

                let baseColor = relation.isCritical ? TazkleColors.warning : TazkleColors.relationship
                let lineColor = baseColor.opacity(isDimmed ? 0.16 : 1)
                context.stroke(
                    path,
                    with: .color(
                        TazkleColors.canvas(
                            for: colorScheme,
                            highContrast: highContrast
                        )
                    ),
                    style: StrokeStyle(
                        lineWidth: isSelected ? 7.5 : (relation.isCritical ? 6.5 : 5.5),
                        lineCap: .round
                    )
                )
                context.stroke(
                    path,
                    with: .color(lineColor),
                    style: StrokeStyle(
                        lineWidth: isSelected ? 3.2 : (relation.isCritical ? 2.5 : 1.6),
                        lineCap: .round,
                        dash: relation.isCritical ? [7, 5] : []
                    )
                )

                context.stroke(
                    connectionArrowPath(for: geometry),
                    with: .color(lineColor),
                    style: StrokeStyle(lineWidth: relation.isCritical ? 2.5 : 1.8, lineCap: .round)
                )
                drawConnectionVertex(
                    in: &context,
                    at: geometry.start,
                    color: lineColor,
                    surface: TazkleColors.panel(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
                drawConnectionVertex(
                    in: &context,
                    at: geometry.end,
                    color: lineColor,
                    surface: TazkleColors.panel(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )

            }

            if let draft = connectionDraft,
               let source = appState.graph.block(id: draft.sourceID) {
                let sourceCenter = displayedPosition(for: source)
                let liveGeometry: ConnectionGeometry

                if let targetID = draft.targetID,
                   let targetPort = draft.targetPort,
                   let target = appState.graph.block(id: targetID) {
                    liveGeometry = connectionGeometry(
                        source: sourceCenter,
                        target: displayedPosition(for: target),
                        cardSize: cardSize,
                        sourcePort: draft.sourcePort,
                        targetPort: targetPort
                    )
                } else {
                    liveGeometry = liveConnectionGeometry(
                        start: connectionPortPoint(
                            center: sourceCenter,
                            cardSize: cardSize,
                            port: draft.sourcePort
                        ),
                        end: draft.currentPoint,
                        sourcePort: draft.sourcePort
                    )
                }

                var livePath = Path()
                livePath.move(to: liveGeometry.start)
                livePath.addCurve(
                    to: liveGeometry.end,
                    control1: liveGeometry.control1,
                    control2: liveGeometry.control2
                )
                context.stroke(
                    livePath,
                    with: .color(TazkleColors.assistantProposal),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [8, 6])
                )

                context.stroke(
                    connectionArrowPath(for: liveGeometry),
                    with: .color(TazkleColors.assistantProposal),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                drawConnectionVertex(
                    in: &context,
                    at: liveGeometry.start,
                    color: TazkleColors.assistantProposal,
                    surface: TazkleColors.panel(
                        for: colorScheme,
                        highContrast: highContrast
                    ),
                    emphasized: true
                )
                drawConnectionVertex(
                    in: &context,
                    at: liveGeometry.end,
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
                if let source = appState.graph.block(id: relation.sourceID),
                   let target = appState.graph.block(id: relation.targetID) {
                    let geometry = connectionGeometry(
                        source: displayedPosition(for: source),
                        target: displayedPosition(for: target),
                        cardSize: cardSize,
                        sourcePort: relation.sourcePort,
                        targetPort: relation.targetPort
                    )
                    RelationCanvasHitTarget(
                        relation: relation,
                        path: projectConnectionPath(for: geometry)
                    )
                }
            }

            ForEach(appState.graph.relations) { relation in
                if let source = appState.graph.block(id: relation.sourceID),
                   let target = appState.graph.block(id: relation.targetID) {
                    let geometry = connectionGeometry(
                        source: displayedPosition(for: source),
                        target: displayedPosition(for: target),
                        cardSize: cardSize,
                        sourcePort: relation.sourcePort,
                        targetPort: relation.targetPort
                    )
                    RelationCanvasControl(relation: relation)
                        .position(geometry.label)
                }
            }
        }
    }

    private func dragGesture(for block: ProjectBlock) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("projectCanvas"))
            .onChanged { value in
                let origin = blockDrag?.blockID == block.id
                    ? blockDrag?.origin ?? point(for: block.position)
                    : point(for: block.position)
                let current = safePosition(
                    BlockPosition(
                        x: origin.x + value.translation.width,
                        y: origin.y + value.translation.height
                    )
                )
                let destination = snappedPosition(current)
                blockDrag = CanvasBlockDragSession(
                    blockID: block.id,
                    origin: origin,
                    current: point(for: current),
                    destination: point(for: destination)
                )
            }
            .onEnded { _ in
                guard let session = blockDrag, session.blockID == block.id else { return }
                appState.moveBlock(
                    block.id,
                    to: BlockPosition(x: session.destination.x, y: session.destination.y),
                    persist: true
                )
                appState.selectBlock(block.id)
                withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.84)) {
                    blockDrag = nil
                }
            }
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
                    canvasSize: scaledCanvasSize(canvasSize, zoom: zoom),
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
            canvasSize: scaledCanvasSize(canvasSize, zoom: zoom),
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
            canvasSize: scaledCanvasSize(canvasSize, zoom: newZoom),
            viewportSize: viewportSize
        )
    }

    private func fitCanvas(in viewportSize: CGSize) {
        let fittedZoom = clampedCanvasZoom(
            min(
                (viewportSize.width - TazkleSpacing.xxLarge) / canvasSize.width,
                (viewportSize.height - TazkleSpacing.xxLarge) / canvasSize.height
            )
        )
        zoom = fittedZoom
        canvasOffset = .zero
    }

    private func navigate(to point: CGPoint, viewportSize: CGSize) {
        canvasOffset = clampedCanvasOffset(
            CGSize(
                width: viewportSize.width / 2 - point.x * zoom,
                height: viewportSize.height / 2 - point.y * zoom
            ),
            canvasSize: scaledCanvasSize(canvasSize, zoom: zoom),
            viewportSize: viewportSize
        )
    }

    private func displayedPosition(for block: ProjectBlock) -> CGPoint {
        if let session = blockDrag, session.blockID == block.id {
            return session.current
        }
        return point(for: block.position)
    }

    private func point(for position: BlockPosition) -> CGPoint {
        CGPoint(x: position.x, y: position.y)
    }

    private func safePosition(_ position: BlockPosition) -> BlockPosition {
        BlockPosition(
            x: min(max(position.x, 130), canvasSize.width - 130),
            y: min(max(position.y, 100), canvasSize.height - 110)
        )
    }

    private func snappedPosition(_ position: BlockPosition) -> BlockPosition {
        safePosition(
            BlockPosition(
                x: (position.x / 24).rounded() * 24,
                y: (position.y / 24).rounded() * 24
            )
        )
    }

    private func connectionGesture(
        from block: ProjectBlock,
        sourcePort: ConnectionPort
    ) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("projectCanvas"))
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

        for block in appState.graph.blocks where block.id != sourceID {
            for port in ConnectionPort.allCases {
                let portPoint = connectionPortPoint(
                    center: displayedPosition(for: block),
                    cardSize: cardSize,
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

    private func droppedTemplate(from items: [String]) -> BlockFamily? {
        items.lazy.compactMap { item in
            guard case let .blockTemplate(family) = CanvasDragPayload(rawValue: item) else {
                return nil
            }
            return family
        }.first
    }
}

private struct MapBlockCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    let block: ProjectBlock
    let isSelected: Bool
    let isDragging: Bool
    let isConnectionTarget: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            HStack {
                Image(systemName: block.family.systemImage)
                    .font(.headline)
                    .foregroundStyle(block.family.accentColor)
                Text(block.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }

            Text(block.summary.isEmpty ? "Sin descripción" : block.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Label(block.state.displayName, systemImage: block.state.systemImage)
                    .font(.caption)
                Spacer()
                Text(block.family.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(block.family.accentColor)
            }
        }
        .padding(TazkleSpacing.large)
        .frame(width: 224, height: 148, alignment: .topLeading)
        .background(
            TazkleColors.panel(
                for: colorScheme,
                highContrast: highContrast
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
        .overlay {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: TazkleRadius.card)
                    .stroke(
                        isConnectionTarget || isSelected || isFocused
                            ? TazkleColors.assistantProposal
                            : block.family.accentColor.opacity(0.65),
                        lineWidth: isConnectionTarget || isSelected || isFocused ? 2.5 : 1
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
                : .black.opacity(colorScheme == .dark ? 0.22 : 0.08),
            radius: isDragging ? 24 : (isConnectionTarget ? 18 : 10),
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
        .scaleEffect(isDragging ? 1.035 : 1)
        .opacity(isDragging ? 0.97 : 1)
        .animation(
            reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.82),
            value: isDragging
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(block.title)
        .accessibilityValue(
            "\(block.family.displayName), \(block.state.displayName), \(appState.graph.relationshipCount(for: block.id)) relaciones"
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            appState.selectBlock(block.id)
        }
        .accessibilityHint("Selecciona el bloque y abre su inspector")
        .accessibilityAction(named: "Mover arriba") {
            appState.nudgeBlock(block.id, x: 0, y: -24)
        }
        .accessibilityAction(named: "Mover abajo") {
            appState.nudgeBlock(block.id, x: 0, y: 24)
        }
        .accessibilityAction(named: "Mover a la izquierda") {
            appState.nudgeBlock(block.id, x: -24, y: 0)
        }
        .accessibilityAction(named: "Mover a la derecha") {
            appState.nudgeBlock(block.id, x: 24, y: 0)
        }
        .accessibilityAction(named: "Eliminar bloque") {
            appState.requestBlockDeletion(block.id)
        }
        .contextMenu {
            Button("Eliminar bloque", systemImage: "trash", role: .destructive) {
                appState.requestBlockDeletion(block.id)
            }
            .disabled(block.state == .approved)
        }
    }
}

struct CanvasConnectionPort: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    let port: ConnectionPort
    let blockTitle: String
    let isActive: Bool
    let isDropTarget: Bool
    let isRevealed: Bool
    let action: () -> Void

    private var isVisible: Bool {
        isActive || isDropTarget || isRevealed || isFocused
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isActive || isDropTarget {
                    Circle()
                        .fill(
                            isDropTarget
                                ? TazkleColors.assistantProposal.opacity(0.22)
                                : TazkleColors.relationship.opacity(0.18)
                        )
                        .frame(width: 25, height: 25)
                    Circle()
                        .stroke(
                            isDropTarget
                                ? TazkleColors.assistantProposal
                                : TazkleColors.relationship,
                            lineWidth: 2
                        )
                        .frame(width: 23, height: 23)
                }
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 13, height: 13)
                Circle()
                    .stroke(
                        isDropTarget
                            ? TazkleColors.assistantProposal
                            : TazkleColors.relationship,
                        lineWidth: 1.5
                    )
                    .frame(width: 13, height: 13)
                Circle()
                    .fill(
                        isDropTarget
                            ? TazkleColors.assistantProposal
                            : TazkleColors.relationship
                    )
                    .frame(width: 3.5, height: 3.5)
            }
            .opacity(isVisible ? 1 : 0)
            .frame(width: 32, height: 32)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .scaleEffect((isActive || isDropTarget) && !reduceMotion ? 1.08 : 1)
        .animation(
            reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.78),
            value: isVisible
        )
        .help("Conectar desde \(port.displayName.lowercased())")
        .accessibilityLabel(
            "Puerto \(port.displayName.lowercased()) de \(blockTitle)"
        )
        .accessibilityValue(isDropTarget ? "Destino de la nueva relación" : "")
        .accessibilityHint(
            "Activa para abrir el formulario o arrastra hasta uno de los cuatro puertos de otro bloque"
        )
    }
}

struct CanvasConnectionDraft {
    let sourceID: UUID
    let sourcePort: ConnectionPort
    let currentPoint: CGPoint
    let targetID: UUID?
    let targetPort: ConnectionPort?
}

struct CanvasConnectionTarget {
    let blockID: UUID
    let port: ConnectionPort
}

struct ConnectionGeometry {
    let start: CGPoint
    let end: CGPoint
    let control1: CGPoint
    let control2: CGPoint
    let label: CGPoint
    let arrowLeft: CGPoint
    let arrowRight: CGPoint
}

func drawConnectionVertex(
    in context: inout GraphicsContext,
    at point: CGPoint,
    color: Color,
    surface: Color,
    emphasized: Bool = false
) {
    let diameter: CGFloat = emphasized ? 12 : 10
    let outerRect = CGRect(
        x: point.x - diameter / 2,
        y: point.y - diameter / 2,
        width: diameter,
        height: diameter
    )
    let outerPath = Path(ellipseIn: outerRect)
    context.fill(outerPath, with: .color(surface))
    context.stroke(
        outerPath,
        with: .color(color),
        style: StrokeStyle(lineWidth: emphasized ? 2.5 : 2)
    )

    let centerDiameter: CGFloat = emphasized ? 4 : 3
    context.fill(
        Path(ellipseIn: CGRect(
            x: point.x - centerDiameter / 2,
            y: point.y - centerDiameter / 2,
            width: centerDiameter,
            height: centerDiameter
        )),
        with: .color(color)
    )
}

func connectionArrowPath(for geometry: ConnectionGeometry, inset: CGFloat = 7) -> Path {
    let base = CGPoint(
        x: (geometry.arrowLeft.x + geometry.arrowRight.x) / 2,
        y: (geometry.arrowLeft.y + geometry.arrowRight.y) / 2
    )
    let dx = geometry.end.x - base.x
    let dy = geometry.end.y - base.y
    let length = max(0.001, hypot(dx, dy))
    let shift = CGSize(
        width: -dx / length * inset,
        height: -dy / length * inset
    )

    var path = Path()
    path.move(to: CGPoint(
        x: geometry.arrowLeft.x + shift.width,
        y: geometry.arrowLeft.y + shift.height
    ))
    path.addLine(to: CGPoint(
        x: geometry.end.x + shift.width,
        y: geometry.end.y + shift.height
    ))
    path.addLine(to: CGPoint(
        x: geometry.arrowRight.x + shift.width,
        y: geometry.arrowRight.y + shift.height
    ))
    return path
}

func connectionGeometry(
    source: CGPoint,
    target: CGPoint,
    cardSize: CGSize,
    sourcePort: ConnectionPort,
    targetPort: ConnectionPort
) -> ConnectionGeometry {
    let start = connectionPortPoint(center: source, cardSize: cardSize, port: sourcePort)
    let end = connectionPortPoint(center: target, cardSize: cardSize, port: targetPort)
    let distance = min(180, max(52, hypot(end.x - start.x, end.y - start.y) * 0.38))
    let sourceVector = sourcePort.outwardVector
    let targetVector = targetPort.outwardVector
    let control1 = CGPoint(
        x: start.x + sourceVector.dx * distance,
        y: start.y + sourceVector.dy * distance
    )
    let control2 = CGPoint(
        x: end.x + targetVector.dx * distance,
        y: end.y + targetVector.dy * distance
    )
    return makeConnectionGeometry(start: start, end: end, control1: control1, control2: control2)
}

func projectConnectionPath(for geometry: ConnectionGeometry) -> Path {
    var path = Path()
    path.move(to: geometry.start)
    path.addCurve(
        to: geometry.end,
        control1: geometry.control1,
        control2: geometry.control2
    )
    return path
}

func liveConnectionGeometry(
    start: CGPoint,
    end: CGPoint,
    sourcePort: ConnectionPort
) -> ConnectionGeometry {
    let controlDistance = min(160, max(48, hypot(end.x - start.x, end.y - start.y) * 0.38))
    let vector = sourcePort.outwardVector
    let deltaX = end.x - start.x
    let deltaY = end.y - start.y
    let length = max(0.001, hypot(deltaX, deltaY))
    return makeConnectionGeometry(
        start: start,
        end: end,
        control1: CGPoint(
            x: start.x + vector.dx * controlDistance,
            y: start.y + vector.dy * controlDistance
        ),
        control2: CGPoint(
            x: end.x - deltaX / length * min(64, controlDistance),
            y: end.y - deltaY / length * min(64, controlDistance)
        )
    )
}

func connectionPortPoint(
    center: CGPoint,
    cardSize: CGSize,
    port: ConnectionPort
) -> CGPoint {
    let offset = connectionPortOffset(for: port, cardSize: cardSize)
    return CGPoint(x: center.x + offset.width, y: center.y + offset.height)
}

func connectionPortOffset(
    for port: ConnectionPort,
    cardSize: CGSize
) -> CGSize {
    switch port {
    case .top:
        CGSize(width: 0, height: -cardSize.height / 2)
    case .right:
        CGSize(width: cardSize.width / 2, height: 0)
    case .bottom:
        CGSize(width: 0, height: cardSize.height / 2)
    case .left:
        CGSize(width: -cardSize.width / 2, height: 0)
    }
}

extension ConnectionPort {
    var outwardVector: CGVector {
        switch self {
        case .top:
            CGVector(dx: 0, dy: -1)
        case .right:
            CGVector(dx: 1, dy: 0)
        case .bottom:
            CGVector(dx: 0, dy: 1)
        case .left:
            CGVector(dx: -1, dy: 0)
        }
    }
}

func relationPriority(
    _ relation: BlockRelation,
    selectedBlockID: UUID?
) -> Int {
    guard let selectedBlockID else { return 0 }
    return relation.sourceID == selectedBlockID || relation.targetID == selectedBlockID
        ? 1
        : 0
}

func makeConnectionGeometry(
    start: CGPoint,
    end: CGPoint,
    control1: CGPoint,
    control2: CGPoint
) -> ConnectionGeometry {
    let label = cubicPoint(start, control1, control2, end, t: 0.5)
    let angle = atan2(end.y - control2.y, end.x - control2.x)
    let arrowLength: CGFloat = 8
    let spread: CGFloat = 0.58
    let arrowLeft = CGPoint(
        x: end.x + arrowLength * cos(angle + .pi - spread),
        y: end.y + arrowLength * sin(angle + .pi - spread)
    )
    let arrowRight = CGPoint(
        x: end.x + arrowLength * cos(angle + .pi + spread),
        y: end.y + arrowLength * sin(angle + .pi + spread)
    )
    return ConnectionGeometry(
        start: start,
        end: end,
        control1: control1,
        control2: control2,
        label: label,
        arrowLeft: arrowLeft,
        arrowRight: arrowRight
    )
}

func cubicPoint(
    _ start: CGPoint,
    _ control1: CGPoint,
    _ control2: CGPoint,
    _ end: CGPoint,
    t: CGFloat
) -> CGPoint {
    let inverse = 1 - t
    let x = inverse * inverse * inverse * start.x
        + 3 * inverse * inverse * t * control1.x
        + 3 * inverse * t * t * control2.x
        + t * t * t * end.x
    let y = inverse * inverse * inverse * start.y
        + 3 * inverse * inverse * t * control1.y
        + 3 * inverse * t * t * control2.y
        + t * t * t * end.y
    return CGPoint(x: x, y: y - 13)
}

private struct ProjectListView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section("Bloques") {
                ForEach(appState.graph.blocks) { block in
                    Button {
                        appState.selectBlock(block.id)
                    } label: {
                        HStack(spacing: TazkleSpacing.medium) {
                            Image(systemName: block.family.systemImage)
                                .foregroundStyle(block.family.accentColor)
                            VStack(alignment: .leading) {
                                Text(block.title)
                                    .font(.headline)
                                Text("\(block.family.displayName) · \(block.state.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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

            Section("Relaciones") {
                if appState.graph.relations.isEmpty {
                    Text("Todavía no hay relaciones.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.graph.relations) { relation in
                        HStack(alignment: .firstTextBaseline) {
                            Button {
                                appState.selectRelation(relation.id)
                            } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    Image(systemName: relation.isCritical ? "exclamationmark.triangle.fill" : "arrow.right")
                                        .foregroundStyle(
                                            relation.isCritical ? TazkleColors.warning : TazkleColors.relationship
                                        )
                                    Text(appState.relationDescription(relation))
                                    Spacer()
                                    if relation.isCritical {
                                        Text("Crítica")
                                            .font(.caption.weight(.semibold))
                                    }
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

struct RelationCanvasControl: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    let relation: BlockRelation

    private var isSelected: Bool {
        appState.selectedRelationID == relation.id
    }

    private var isDimmed: Bool {
        if let selectedRelationID = appState.selectedRelationID {
            return selectedRelationID != relation.id
        }
        guard let selectedBlockID = appState.selectedBlockID else { return false }
        return relation.sourceID != selectedBlockID && relation.targetID != selectedBlockID
    }

    var body: some View {
        HStack(spacing: 2) {
            Button {
                appState.selectRelation(relation.id)
            } label: {
                Text(relation.type.displayName)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.leading, 8)
                    .padding(.trailing, isSelected ? 4 : 8)
                    .frame(minHeight: 26)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            if isSelected {
                Button("Eliminar relación", systemImage: "trash", role: .destructive) {
                    appState.requestRelationDeletion(relation.id)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .disabled(!appState.canDeleteRelation(relation))
            }
        }
        .foregroundStyle(
            TazkleColors.primaryContent(
                for: colorScheme,
                highContrast: highContrast
            )
        )
        .background(
            TazkleColors.panel(
                for: colorScheme,
                highContrast: highContrast
            )
            .opacity(highContrast ? 1 : 0.96)
        )
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(
                    isSelected
                        ? (relation.isCritical ? TazkleColors.warning : TazkleColors.relationship)
                        : TazkleColors.separator(for: colorScheme, highContrast: highContrast),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .shadow(color: .black.opacity(isSelected ? 0.18 : 0.08), radius: isSelected ? 8 : 3, y: 2)
        .opacity(isDimmed ? 0.28 : 1)
        .contextMenu {
            Button("Eliminar relación", systemImage: "trash", role: .destructive) {
                appState.requestRelationDeletion(relation.id)
            }
            .disabled(!appState.canDeleteRelation(relation))
        }
        .help("Selecciona la relación; pulsa Suprimir o usa el botón de eliminar")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appState.relationDescription(relation))
        .accessibilityValue(
            "\(relation.isCritical ? "Crítica" : "Normal"). "
                + "\(isSelected ? "Seleccionada" : "No seleccionada")."
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            appState.selectRelation(relation.id)
        }
        .accessibilityAction(named: "Eliminar relación") {
            appState.requestRelationDeletion(relation.id)
        }
    }
}

struct RelationCanvasHitTarget: View {
    @EnvironmentObject private var appState: AppState

    let relation: BlockRelation
    let path: Path

    private let hitStyle = StrokeStyle(
        lineWidth: 18,
        lineCap: .round,
        lineJoin: .round
    )

    var body: some View {
        path
            .stroke(Color.clear, style: hitStyle)
            .contentShape(path.strokedPath(hitStyle))
            .onTapGesture {
                appState.selectRelation(relation.id)
            }
            .contextMenu {
                Button("Eliminar relación", systemImage: "trash", role: .destructive) {
                    appState.requestRelationDeletion(relation.id)
                }
                .disabled(!appState.canDeleteRelation(relation))
            }
            .help("Selecciona la relación o usa clic derecho para eliminarla")
            .accessibilityHidden(true)
    }
}
