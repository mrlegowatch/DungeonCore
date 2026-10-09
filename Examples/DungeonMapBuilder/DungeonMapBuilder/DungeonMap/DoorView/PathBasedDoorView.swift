//
//  PathBasedDoorView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/6/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// A view that renders path-based doors (staircase, passage)
struct PathBasedDoorView: View {
    let viewModel: DungeonDoorViewModel

    var body: some View {
        Canvas { context, size in
            drawPathBasedDoor(in: context)
        }
    }

    private func drawPathBasedDoor(in context: GraphicsContext) {
        let door = viewModel.door
        guard door.edges.count > 0 else { return }

        switch door.kind {
        case .staircase:
            drawFilledPolygon(in: context)
            drawStaircaseTreads(in: context)
            drawStaircaseArrow(in: context)
        case .passage:
            if door.hasAttribute(.isSecret) {
                drawSecretTunnel(in: context)
                drawSecretGlyphsAtEnds(in: context)
            } else {
                drawFilledPolygon(in: context)
            }
        default:
            break
        }
    }

    // MARK: - Shared polygon fill

    private func drawFilledPolygon(in context: GraphicsContext) {
        let door = viewModel.door
        var path = Path()
        for (index, edge) in door.edges.enumerated() {
            let point = CGPoint(edge * viewModel.scale)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        context.fill(path, with: .color(viewModel.doorColor.opacity(viewModel.alpha)))
        if viewModel.borderWidth > 0 {
            context.stroke(path, with: .color(viewModel.doorColor), lineWidth: viewModel.borderWidth)
        }
    }

    // MARK: - Staircase

    /// The door's centerline, in map units: `segments` when present, otherwise an
    /// approximation using the left half of `edges` (mirrors how `edges` were computed).
    private func centerline(for door: DungeonDoor) -> [MapPoint] {
        if let segments = door.segments, segments.count >= 2 {
            return segments
        }
        let half = door.edges.count / 2
        guard half >= 2 else { return door.edges }
        return Array(door.edges[0..<half])
    }

    /// Cumulative arc length at each centerline point.
    private func cumulativeLengths(_ points: [MapPoint]) -> [Double] {
        var cumulative: [Double] = [0]
        for i in 1..<points.count {
            cumulative.append(cumulative[i - 1] + (points[i] - points[i - 1]).length())
        }
        return cumulative
    }

    /// Interpolates a point and local unit direction at the given arc-length distance.
    private func pointAndDirection(on points: [MapPoint], cumulative: [Double], at distance: Double) -> (point: MapPoint, direction: MapPoint)? {
        guard points.count >= 2 else { return nil }
        for i in 1..<points.count {
            if distance <= cumulative[i] || i == points.count - 1 {
                let segStart = cumulative[i - 1]
                let segLength = cumulative[i] - segStart
                let t = segLength > 0 ? (distance - segStart) / segLength : 0
                let a = points[i - 1], b = points[i]
                let point = MapPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                return (point, (b - a).normalized())
            }
        }
        return nil
    }

    /// Draws treads across the stair's full width, spaced evenly by distance along the
    /// whole path (about every 0.25 grid units), each oriented perpendicular to the
    /// local direction of travel so curved stairs read as an arc of treads.
    private func drawStaircaseTreads(in context: GraphicsContext) {
        let door = viewModel.door
        let points = centerline(for: door)
        guard points.count >= 2 else { return }

        let cumulative = cumulativeLengths(points)
        let totalLength = cumulative.last ?? 0
        guard totalLength > 0 else { return }

        let scale = viewModel.scale
        let width = door.doorWidth
        let spacing = 0.25

        var path = Path()
        var distance = spacing / 2
        while distance < totalLength {
            if let (point, direction) = pointAndDirection(on: points, cumulative: cumulative, at: distance) {
                let perpendicular = direction.perpendicular()
                let leftPoint = CGPoint(point * scale)
                let rightPoint = CGPoint((point + perpendicular * width) * scale)
                path.move(to: leftPoint)
                path.addLine(to: rightPoint)
            }
            distance += spacing
        }

        context.stroke(path, with: .color(.black.opacity(0.7)), lineWidth: 1.5)
    }

    /// Draws a small arrowhead at the stair's upper end, pointing further up along the
    /// path. `stairDirection == .up` means the last centerline point is the top;
    /// `.down` means the first point is. With no `stairDirection`, draws nothing.
    private func drawStaircaseArrow(in context: GraphicsContext) {
        guard let stairDirection = viewModel.door.stairDirection else { return }
        let points = centerline(for: viewModel.door)
        guard points.count >= 2 else { return }

        let topPoint: MapPoint
        let upwardDirection: MapPoint
        switch stairDirection {
        case .up:
            topPoint = points[points.count - 1]
            upwardDirection = (points[points.count - 1] - points[points.count - 2]).normalized()
        case .down:
            topPoint = points[0]
            upwardDirection = (points[0] - points[1]).normalized()
        }

        let scale = viewModel.scale
        let base = CGPoint(topPoint * scale)
        let tip = CGPoint((topPoint + upwardDirection * 0.3) * scale)
        drawArrowhead(in: context, from: base, to: tip)
    }

    private func drawArrowhead(in context: GraphicsContext, from base: CGPoint, to tip: CGPoint) {
        let dx = tip.x - base.x, dy = tip.y - base.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return }
        let ux = dx / length, uy = dy / length
        let perpX = -uy, perpY = ux

        let scale = viewModel.scale
        let headLength = scale * 0.25
        let headWidth = scale * 0.18
        let backPoint = CGPoint(x: tip.x - ux * headLength, y: tip.y - uy * headLength)
        let left = CGPoint(x: backPoint.x + perpX * headWidth, y: backPoint.y + perpY * headWidth)
        let right = CGPoint(x: backPoint.x - perpX * headWidth, y: backPoint.y - perpY * headWidth)

        var shaft = Path()
        shaft.move(to: base)
        shaft.addLine(to: backPoint)
        context.stroke(shaft, with: .color(.black), lineWidth: 2.0)

        var head = Path()
        head.move(to: tip)
        head.addLine(to: left)
        head.addLine(to: right)
        head.closeSubpath()
        context.fill(head, with: .color(.black))
    }

    // MARK: - Passage

    /// Draws a secret passage as an unfilled tunnel: a dashed outline along both long
    /// sides of the path only, skipping the two end caps, in a mid gray.
    private func drawSecretTunnel(in context: GraphicsContext) {
        let door = viewModel.door
        let scale = viewModel.scale
        let edges = door.edges
        guard edges.count >= 4 else { return }

        let halfCount = door.segments?.count ?? edges.count / 2
        guard halfCount >= 2, halfCount * 2 <= edges.count else { return }

        var leftPath = Path()
        for i in 0..<halfCount {
            let point = CGPoint(edges[i] * scale)
            if i == 0 { leftPath.move(to: point) } else { leftPath.addLine(to: point) }
        }

        var rightPath = Path()
        for i in halfCount..<(halfCount * 2) {
            let point = CGPoint(edges[i] * scale)
            if i == halfCount { rightPath.move(to: point) } else { rightPath.addLine(to: point) }
        }

        let style = StrokeStyle(lineWidth: 1.5, dash: [5, 4])
        context.stroke(leftPath, with: .color(.mediumGray), style: style)
        context.stroke(rightPath, with: .color(.mediumGray), style: style)
    }

    /// Draws the classic "S" secret-door glyph at each end of a secret passage's path.
    private func drawSecretGlyphsAtEnds(in context: GraphicsContext) {
        let door = viewModel.door
        let scale = viewModel.scale
        let glyphSize = scale * MapViewConfiguration.secretGlyphHeightRatio
        for point in [door.leftEdge, door.rightEdge] {
            let text = Text("S").font(.system(size: glyphSize, weight: .bold)).foregroundColor(.darkGray)
            context.draw(text, at: CGPoint(point * scale))
        }
    }
}
