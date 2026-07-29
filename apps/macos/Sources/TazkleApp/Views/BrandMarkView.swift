import AppKit
import SwiftUI
import TazkleDesignSystem

struct BrandMarkView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        BrandAssetImage(
            resource: colorScheme == .dark ? "tazkle-mark" : "tazkle-mark-mono-dark",
            fallbackSystemImage: "point.3.connected.trianglepath.dotted"
        )
        .accessibilityHidden(true)
    }
}

struct BrandWordmarkView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        BrandAssetImage(
            resource: colorScheme == .dark ? "tazkle-wordmark-light" : "tazkle-wordmark-dark",
            fallbackSystemImage: "textformat"
        )
        .accessibilityLabel("Tazkle")
    }
}

struct TazkiMarkView: View {
    var body: some View {
        BrandAssetImage(resource: "tazki-mascot", fallbackSystemImage: "sparkles")
            .accessibilityLabel("Tazki")
    }
}

enum TazkiMotionState {
    case idle
    case listening
    case thinking
    case suggesting
    case validating
}

struct TazkiAnimatedMarkView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("tazkiAnimationsEnabled") private var animationsEnabled = true

    let state: TazkiMotionState
    let size: CGFloat

    private var shouldAnimate: Bool {
        animationsEnabled && !reduceMotion
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !shouldAnimate)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            mascot(at: shouldAnimate ? time : 0)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func mascot(at time: TimeInterval) -> some View {
        let cycle = time * .pi * 2
        let pieceScale = state == .suggesting && shouldAnimate
            ? 1 + 0.012 * sin(cycle / 1.5)
            : 1
        let pieceRotation = state == .thinking && shouldAnimate
            ? 1.4 * sin(cycle / 1.2)
            : 0

        return GeometryReader { proxy in
            ZStack {
                TazkiMarkView()
                    .scaleEffect(pieceScale)
                    .rotationEffect(.degrees(pieceRotation))

                ForEach(Array(TazkiNode.allCases.enumerated()), id: \.element) { index, node in
                    let nodePulse = nodeScale(
                        node,
                        time: time,
                        phase: Double(index) * 0.42
                    )
                    Circle()
                        .stroke(node.color.opacity(shouldAnimate ? 0.62 : 0), lineWidth: 1.5)
                        .frame(
                            width: proxy.size.width * 0.075,
                            height: proxy.size.width * 0.075
                        )
                        .scaleEffect(nodePulse)
                        .position(
                            x: proxy.size.width * node.position.x,
                            y: proxy.size.height * node.position.y
                        )
                }

                if state == .validating {
                    Circle()
                        .stroke(TazkleColors.success.opacity(shouldAnimate ? 0.48 : 0.3), lineWidth: 2)
                        .scaleEffect(
                            shouldAnimate
                                ? 0.82 + 0.16 * abs(sin(cycle / 0.92))
                                : 0.96
                        )
                        .opacity(shouldAnimate ? 0.9 - 0.35 * abs(sin(cycle / 0.92)) : 0.7)
                        .padding(proxy.size.width * 0.12)
                }
            }
        }
    }

    private func nodeScale(
        _ node: TazkiNode,
        time: TimeInterval,
        phase: Double
    ) -> CGFloat {
        guard shouldAnimate else { return 1 }
        let base = 1.04 + 0.16 * sin(time * .pi * 2 / 2.8 + phase)

        switch state {
        case .idle:
            return base
        case .listening:
            return 1.08 + 0.22 * sin(time * .pi * 2 / 1.05 + phase)
        case .thinking:
            return node == .top ? 1.18 + 0.12 * sin(time * .pi * 2 / 1.2) : base
        case .suggesting:
            return node == .right ? 1.2 + 0.18 * sin(time * .pi * 2 / 1.5) : base
        case .validating:
            return 1.12 + 0.1 * sin(time * .pi * 2 / 0.92 + phase)
        }
    }
}

private enum TazkiNode: CaseIterable {
    case top
    case right
    case bottom
    case left

    var color: Color {
        switch self {
        case .top: TazkleColors.actionPrimary
        case .right: TazkleColors.assistantProposal
        case .bottom: TazkleColors.warning
        case .left: TazkleColors.relationship
        }
    }

    var position: UnitPoint {
        switch self {
        case .top: UnitPoint(x: 0.557, y: 0.274)
        case .right: UnitPoint(x: 0.752, y: 0.557)
        case .bottom: UnitPoint(x: 0.557, y: 0.752)
        case .left: UnitPoint(x: 0.274, y: 0.557)
        }
    }
}

private struct BrandAssetImage: View {
    let resource: String
    let fallbackSystemImage: String

    var body: some View {
        Group {
            if let url = Bundle.module.url(forResource: resource, withExtension: "svg"),
               let image = NSImage(contentsOf: url) {
                ProportionallyScaledImage(image: image)
            } else {
                Image(systemName: fallbackSystemImage)
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

/// `Image(nsImage:)` can preserve the SVG's large intrinsic canvas in some
/// macOS containers. Drawing it into a SwiftUI canvas makes the proposed frame
/// authoritative without changing the approved vector source.
private struct ProportionallyScaledImage: View {
    let image: NSImage

    var body: some View {
        Canvas { context, size in
            guard image.size.width > 0, image.size.height > 0 else { return }

            let imageAspectRatio = image.size.width / image.size.height
            let targetAspectRatio = size.width / max(size.height, 1)
            let targetSize: CGSize

            if imageAspectRatio > targetAspectRatio {
                targetSize = CGSize(
                    width: size.width,
                    height: size.width / imageAspectRatio
                )
            } else {
                targetSize = CGSize(
                    width: size.height * imageAspectRatio,
                    height: size.height
                )
            }

            let targetRect = CGRect(
                x: (size.width - targetSize.width) / 2,
                y: (size.height - targetSize.height) / 2,
                width: targetSize.width,
                height: targetSize.height
            )

            context.draw(Image(nsImage: image), in: targetRect)
        }
    }
}
