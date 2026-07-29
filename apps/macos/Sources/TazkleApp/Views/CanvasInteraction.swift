import AppKit
import SwiftUI
import TazkleDesignSystem

enum CanvasInteractionTool: String, CaseIterable, Identifiable {
    case select
    case pan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: "Seleccionar"
        case .pan: "Mover lienzo"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .pan: "hand.draw"
        }
    }
}

struct CanvasBlockDragSession {
    let blockID: UUID
    let origin: CGPoint
    var current: CGPoint
    var destination: CGPoint
}

struct CanvasDropPlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    let size: CGSize
    let accent: Color

    var body: some View {
        RoundedRectangle(cornerRadius: TazkleRadius.card)
            .fill(
                TazkleColors.panel(
                    for: colorScheme,
                    highContrast: highContrast
                )
                .opacity(highContrast ? 0.5 : 0.28)
            )
            .frame(width: size.width, height: size.height)
            .overlay {
                RoundedRectangle(cornerRadius: TazkleRadius.card)
                    .stroke(
                        accent.opacity(0.82),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8, 7])
                    )
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

struct CanvasLandingShadow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    let size: CGSize
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: TazkleRadius.card + 2)
                .fill(accent.opacity(colorScheme == .dark ? 0.16 : 0.1))
                .frame(width: size.width + 12, height: size.height + 12)
                .overlay {
                    RoundedRectangle(cornerRadius: TazkleRadius.card + 2)
                        .stroke(
                            accent,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [10, 6])
                        )
                }
                .shadow(color: accent.opacity(0.34), radius: 18)

            Text("Soltar aquí")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(
                    TazkleColors.primaryContent(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    TazkleColors.elevated(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                    .opacity(highContrast ? 1 : 0.96)
                )
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(accent.opacity(0.85), lineWidth: 1)
                }
                .offset(y: size.height / 2 + 18)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct CanvasConnectionDropHint: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    var body: some View {
        Label("Soltar para conectar", systemImage: "link.badge.plus")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(
                TazkleColors.primaryContent(
                    for: colorScheme,
                    highContrast: highContrast
                )
            )
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                TazkleColors.elevated(
                    for: colorScheme,
                    highContrast: highContrast
                )
                .opacity(highContrast ? 1 : 0.98)
            )
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(TazkleColors.assistantProposal, lineWidth: 1.5)
            }
            .shadow(color: TazkleColors.assistantProposal.opacity(0.28), radius: 10)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

struct CanvasMiniMapItem: Identifiable {
    let id: UUID
    let position: CGPoint
    let color: Color
}

struct CanvasNavigationHUD: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    let canvasSize: CGSize
    let viewportSize: CGSize
    let canvasOffset: CGSize
    let zoom: CGFloat
    let items: [CanvasMiniMapItem]
    let onNavigate: (CGPoint) -> Void
    let onZoomChange: (CGFloat) -> Void
    let onFit: () -> Void

    private let previewSize = CGSize(width: 176, height: 108)
    private let previewPadding: CGFloat = 8

    private var previewScale: CGFloat {
        min(
            (previewSize.width - previewPadding * 2) / max(canvasSize.width, 1),
            (previewSize.height - previewPadding * 2) / max(canvasSize.height, 1)
        )
    }

    private var visibleRect: CGRect {
        let logicalOrigin = CGPoint(
            x: max(0, -canvasOffset.width / max(zoom, 0.001)),
            y: max(0, -canvasOffset.height / max(zoom, 0.001))
        )
        let logicalSize = CGSize(
            width: min(canvasSize.width, viewportSize.width / max(zoom, 0.001)),
            height: min(canvasSize.height, viewportSize.height / max(zoom, 0.001))
        )
        return CGRect(
            x: previewPadding + logicalOrigin.x * previewScale,
            y: previewPadding + logicalOrigin.y * previewScale,
            width: logicalSize.width * previewScale,
            height: logicalSize.height * previewScale
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: TazkleRadius.control)
                    .fill(
                        TazkleColors.canvas(
                            for: colorScheme,
                            highContrast: highContrast
                        )
                    )

                ForEach(items) { item in
                    CanvasMiniMapBlock(
                        color: item.color,
                        size: CGSize(
                            width: max(4, 224 * previewScale),
                            height: max(3, 148 * previewScale)
                        ),
                        position: CGPoint(
                            x: previewPadding + item.position.x * previewScale,
                            y: previewPadding + item.position.y * previewScale
                        )
                    )
                }

                Rectangle()
                    .fill(TazkleColors.actionPrimary.opacity(0.1))
                    .frame(width: visibleRect.width, height: visibleRect.height)
                    .overlay {
                        Rectangle()
                            .stroke(TazkleColors.actionPrimary, lineWidth: 1.5)
                    }
                    .offset(x: visibleRect.minX, y: visibleRect.minY)
                    .accessibilityHidden(true)
            }
            .frame(width: previewSize.width, height: previewSize.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onNavigate(logicalPoint(for: value.location))
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Minimapa del lienzo")
            .accessibilityValue(
                "Encuadre en \(Int(-canvasOffset.width / max(zoom, 0.001))), "
                    + "\(Int(-canvasOffset.height / max(zoom, 0.001))). "
                    + "Zoom \(Int((zoom * 100).rounded())) por ciento."
            )
            .accessibilityHint("Arrastra para cambiar el encuadre del lienzo")

            Divider()

            HStack(spacing: TazkleSpacing.small) {
                Button("Alejar", systemImage: "minus") {
                    onZoomChange(zoom - 0.1)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .keyboardShortcut("-", modifiers: .command)
                .help("Alejar · ⌘−")

                Button("\(Int((zoom * 100).rounded()))%") {
                    onZoomChange(1)
                }
                .buttonStyle(.plain)
                .monospacedDigit()
                .frame(minWidth: 48)
                .help("Volver a 100%")

                Button("Acercar", systemImage: "plus") {
                    onZoomChange(zoom + 0.1)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .keyboardShortcut("=", modifiers: .command)
                .help("Acercar · ⌘+")

                Spacer(minLength: 0)

                Button("Ajustar lienzo", systemImage: "arrow.down.right.and.arrow.up.left") {
                    onFit()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .help("Mostrar todo el lienzo")
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, TazkleSpacing.medium)
            .frame(height: 34)
        }
        .frame(width: previewSize.width)
        .background(
            TazkleColors.panel(
                for: colorScheme,
                highContrast: highContrast
            )
            .opacity(highContrast ? 1 : 0.96)
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
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 10, y: 4)
    }

    private func logicalPoint(for location: CGPoint) -> CGPoint {
        CGPoint(
            x: min(
                canvasSize.width,
                max(0, (location.x - previewPadding) / max(previewScale, 0.001))
            ),
            y: min(
                canvasSize.height,
                max(0, (location.y - previewPadding) / max(previewScale, 0.001))
            )
        )
    }
}

private struct CanvasMiniMapBlock: View {
    let color: Color
    let size: CGSize
    let position: CGPoint

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color.opacity(0.7))
            .frame(width: size.width, height: size.height)
            .position(position)
            .accessibilityHidden(true)
    }
}

struct CanvasScrollCapture: NSViewRepresentable {
    let onScroll: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }

    func makeNSView(context: Context) -> NSView {
        let view = CanvasScrollSensorView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onScroll = onScroll
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        var onScroll: (CGSize) -> Void
        private weak var view: NSView?
        private var monitor: Any?

        init(onScroll: @escaping (CGSize) -> Void) {
            self.onScroll = onScroll
        }

        func attach(to view: NSView) {
            self.view = view
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard
                    let self,
                    let view = self.view,
                    let window = view.window,
                    event.window === window
                else {
                    return event
                }

                let point = view.convert(event.locationInWindow, from: nil)
                guard view.bounds.contains(point) else { return event }

                self.onScroll(
                    CGSize(
                        width: event.scrollingDeltaX,
                        height: event.scrollingDeltaY
                    )
                )
                return nil
            }
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
            view = nil
        }
    }
}

private final class CanvasScrollSensorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

func clampedCanvasOffset(
    _ proposed: CGSize,
    canvasSize: CGSize,
    viewportSize: CGSize
) -> CGSize {
    CGSize(
        width: min(0, max(viewportSize.width - canvasSize.width, proposed.width)),
        height: min(0, max(viewportSize.height - canvasSize.height, proposed.height))
    )
}

func scaledCanvasSize(_ canvasSize: CGSize, zoom: CGFloat) -> CGSize {
    CGSize(width: canvasSize.width * zoom, height: canvasSize.height * zoom)
}

func clampedCanvasZoom(_ zoom: CGFloat) -> CGFloat {
    min(1.75, max(0.25, zoom))
}
