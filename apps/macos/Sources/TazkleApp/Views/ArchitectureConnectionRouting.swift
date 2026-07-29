import SwiftUI
import TazkleDomain

struct ArchitectureConnectionRoute {
    let points: [CGPoint]
    let arrowLeft: CGPoint
    let arrowRight: CGPoint

    var start: CGPoint {
        points.first ?? .zero
    }

    var end: CGPoint {
        points.last ?? .zero
    }

    var label: CGPoint {
        guard points.count > 1 else { return start }
        let segmentLengths = zip(points, points.dropFirst()).map { pair in
            hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
        }
        let halfLength = segmentLengths.reduce(0, +) / 2
        var traversed: CGFloat = 0

        for (index, length) in segmentLengths.enumerated() {
            guard traversed + length < halfLength else {
                let start = points[index]
                let end = points[index + 1]
                let progress = length > 0 ? (halfLength - traversed) / length : 0
                return CGPoint(
                    x: start.x + (end.x - start.x) * progress,
                    y: start.y + (end.y - start.y) * progress
                )
            }
            traversed += length
        }
        return end
    }
}

func architectureConnectionRoute(
    source: CGPoint,
    target: CGPoint,
    cardSize: CGSize,
    sourcePort: ConnectionPort,
    targetPort: ConnectionPort
) -> ArchitectureConnectionRoute {
    let start = connectionPortPoint(center: source, cardSize: cardSize, port: sourcePort)
    let end = connectionPortPoint(center: target, cardSize: cardSize, port: targetPort)
    let stubLength: CGFloat = 26
    let sourceVector = sourcePort.outwardVector
    let targetVector = targetPort.outwardVector
    let sourceLead = CGPoint(
        x: start.x + sourceVector.dx * stubLength,
        y: start.y + sourceVector.dy * stubLength
    )
    let targetLead = CGPoint(
        x: end.x + targetVector.dx * stubLength,
        y: end.y + targetVector.dy * stubLength
    )
    let horizontalClearance = cardSize.width + stubLength
    let verticalClearance = cardSize.height + stubLength
    let laneSeparation: CGFloat = 7

    var points = [start, sourceLead]

    switch (sourcePort.axis, targetPort.axis) {
    case (.vertical, .vertical):
        let hasClearGap = abs(source.x - target.x) >= horizontalClearance
        let corridorX: CGFloat
        if hasClearGap {
            let directionalOffset = source.x < target.x ? -laneSeparation : laneSeparation
            corridorX = (source.x + target.x) / 2 + directionalOffset
        } else {
            let routesRight = sourcePort == .top
            corridorX = routesRight
                ? max(source.x, target.x) + cardSize.width / 2 + stubLength
                : min(source.x, target.x) - cardSize.width / 2 - stubLength
        }
        points.append(CGPoint(x: corridorX, y: sourceLead.y))
        points.append(CGPoint(x: corridorX, y: targetLead.y))
    case (.horizontal, .horizontal):
        let hasClearGap = abs(source.y - target.y) >= verticalClearance
        let corridorY: CGFloat
        if hasClearGap {
            let directionalOffset = source.y < target.y ? -laneSeparation : laneSeparation
            corridorY = (source.y + target.y) / 2 + directionalOffset
        } else {
            let routesBelow = sourcePort == .right
            corridorY = routesBelow
                ? max(source.y, target.y) + cardSize.height / 2 + stubLength
                : min(source.y, target.y) - cardSize.height / 2 - stubLength
        }
        points.append(CGPoint(x: sourceLead.x, y: corridorY))
        points.append(CGPoint(x: targetLead.x, y: corridorY))
    case (.horizontal, .vertical):
        points.append(CGPoint(x: sourceLead.x, y: targetLead.y))
    case (.vertical, .horizontal):
        points.append(CGPoint(x: targetLead.x, y: sourceLead.y))
    }

    points.append(targetLead)
    points.append(end)
    return makeArchitectureRoute(points: points)
}

func liveArchitectureConnectionRoute(
    start: CGPoint,
    end: CGPoint,
    sourcePort: ConnectionPort
) -> ArchitectureConnectionRoute {
    let stubLength: CGFloat = 26
    let sourceVector = sourcePort.outwardVector
    let sourceLead = CGPoint(
        x: start.x + sourceVector.dx * stubLength,
        y: start.y + sourceVector.dy * stubLength
    )

    var points = [start, sourceLead]
    switch sourcePort.axis {
    case .horizontal:
        points.append(CGPoint(x: end.x, y: sourceLead.y))
    case .vertical:
        points.append(CGPoint(x: sourceLead.x, y: end.y))
    }
    points.append(end)
    return makeArchitectureRoute(points: points)
}

func architectureConnectionPath(
    for route: ArchitectureConnectionRoute,
    cornerRadius: CGFloat = 12
) -> Path {
    let points = route.points
    guard let first = points.first else { return Path() }
    guard points.count > 2 else {
        var path = Path()
        path.move(to: first)
        if let last = points.last {
            path.addLine(to: last)
        }
        return path
    }

    var path = Path()
    path.move(to: first)

    for index in 1 ..< points.count - 1 {
        let previous = points[index - 1]
        let corner = points[index]
        let next = points[index + 1]
        let incomingLength = hypot(corner.x - previous.x, corner.y - previous.y)
        let outgoingLength = hypot(next.x - corner.x, next.y - corner.y)

        guard incomingLength > 0.5, outgoingLength > 0.5 else { continue }

        let radius = min(cornerRadius, incomingLength / 2, outgoingLength / 2)
        let before = CGPoint(
            x: corner.x - (corner.x - previous.x) / incomingLength * radius,
            y: corner.y - (corner.y - previous.y) / incomingLength * radius
        )
        let after = CGPoint(
            x: corner.x + (next.x - corner.x) / outgoingLength * radius,
            y: corner.y + (next.y - corner.y) / outgoingLength * radius
        )

        path.addLine(to: before)
        path.addQuadCurve(to: after, control: corner)
    }

    if let last = points.last {
        path.addLine(to: last)
    }
    return path
}

func architectureArrowPath(
    for route: ArchitectureConnectionRoute,
    inset: CGFloat = 7
) -> Path {
    guard route.points.count >= 2 else { return Path() }
    let end = route.end
    let previous = route.points[route.points.count - 2]
    let dx = end.x - previous.x
    let dy = end.y - previous.y
    let length = max(0.001, hypot(dx, dy))
    let shift = CGSize(
        width: -dx / length * inset,
        height: -dy / length * inset
    )

    var path = Path()
    path.move(to: CGPoint(
        x: route.arrowLeft.x + shift.width,
        y: route.arrowLeft.y + shift.height
    ))
    path.addLine(to: CGPoint(
        x: end.x + shift.width,
        y: end.y + shift.height
    ))
    path.addLine(to: CGPoint(
        x: route.arrowRight.x + shift.width,
        y: route.arrowRight.y + shift.height
    ))
    return path
}

private func makeArchitectureRoute(points rawPoints: [CGPoint]) -> ArchitectureConnectionRoute {
    let points = normalizedOrthogonalPoints(rawPoints)
    let end = points.last ?? .zero
    let previous = points.dropLast().last ?? end
    let angle = atan2(end.y - previous.y, end.x - previous.x)
    let arrowLength: CGFloat = 8
    let spread: CGFloat = 0.58

    return ArchitectureConnectionRoute(
        points: points,
        arrowLeft: CGPoint(
            x: end.x + arrowLength * cos(angle + .pi - spread),
            y: end.y + arrowLength * sin(angle + .pi - spread)
        ),
        arrowRight: CGPoint(
            x: end.x + arrowLength * cos(angle + .pi + spread),
            y: end.y + arrowLength * sin(angle + .pi + spread)
        )
    )
}

private func normalizedOrthogonalPoints(_ rawPoints: [CGPoint]) -> [CGPoint] {
    var unique: [CGPoint] = []
    for point in rawPoints {
        guard unique.last.map({ hypot($0.x - point.x, $0.y - point.y) > 0.5 }) ?? true else {
            continue
        }
        unique.append(point)
    }

    guard unique.count > 2 else { return unique }

    var result: [CGPoint] = [unique[0]]
    for index in 1 ..< unique.count - 1 {
        let previous = result.last ?? unique[index - 1]
        let current = unique[index]
        let next = unique[index + 1]
        let isVertical = abs(previous.x - current.x) < 0.5
            && abs(current.x - next.x) < 0.5
        let isHorizontal = abs(previous.y - current.y) < 0.5
            && abs(current.y - next.y) < 0.5
        if !isVertical && !isHorizontal {
            result.append(current)
        }
    }
    result.append(unique[unique.count - 1])
    return result
}

private enum ConnectionAxis {
    case horizontal
    case vertical
}

private extension ConnectionPort {
    var axis: ConnectionAxis {
        switch self {
        case .left, .right:
            .horizontal
        case .top, .bottom:
            .vertical
        }
    }
}
