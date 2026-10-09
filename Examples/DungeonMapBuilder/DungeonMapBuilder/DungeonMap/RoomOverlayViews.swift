//
//  RoomOverlayViews.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 8/1/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// Draws a colored selection border around a room's polygon.
struct RoomSelectionOverlay: View {
    let room: DungeonRoom
    let scale: CGFloat
    var revision: Int = 0

    var body: some View {
        Canvas { context, _ in
            guard room.shape == .ellipse || room.edges.count > 1 else { return }
            let path = room.outlinePath(scale: scale)
            context.stroke(
                path,
                with: .color(.accentColor),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

/// A single circular drag handle used by `RoomResizeHandlesView`.
private struct ResizeHandleView: View {
    let position: CGPoint
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: () -> Void

    var body: some View {
        Circle()
            .fill(.white)
            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2))
            .frame(width: 18, height: 18)
            .position(position)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("dungeonMap"))
                    .onChanged { value in onDragChanged(value.location) }
                    .onEnded { _ in onDragEnded() }
            )
    }
}

/// Shows draggable handles at each corner of the selected room for resizing.
///
/// Rectangular rooms (4 edges) show one handle per corner. Polygon rooms show
/// one handle per vertex. Ellipse rooms show one handle per bounding-box corner,
/// in the same index order (TL, TR, BR, BL). Each handle is a small circle that
/// can be dragged to resize the room.
struct RoomResizeHandlesView: View {
    let room: DungeonRoom
    let scale: CGFloat
    var revision: Int = 0
    let onHandleDragChanged: (Int, CGPoint) -> Void
    let onHandleDragEnded: () -> Void

    private var handlePositions: [CGPoint] {
        if room.shape == .ellipse {
            let minX = CGFloat(room.location.x) * scale
            let minY = CGFloat(room.location.y) * scale
            let maxX = CGFloat(room.location.x + room.size.width) * scale
            let maxY = CGFloat(room.location.y + room.size.height) * scale
            return [
                CGPoint(x: minX, y: minY),
                CGPoint(x: maxX, y: minY),
                CGPoint(x: maxX, y: maxY),
                CGPoint(x: minX, y: maxY)
            ]
        }
        return room.edges.map { CGPoint(x: CGFloat($0.x) * scale, y: CGFloat($0.y) * scale) }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(handlePositions.enumerated()), id: \.offset) { index, position in
                ResizeHandleView(
                    position: position,
                    onDragChanged: { location in onHandleDragChanged(index, location) },
                    onDragEnded: onHandleDragEnded
                )
            }
        }
    }
}

/// Draws a semi-transparent ghost of a room at its un-snapped drag position.
///
/// Provides live finger-position feedback when snapping is active — the ghost
/// follows the touch freely while the room itself moves to the nearest grid point.
struct RoomDragGhostView: View {
    let room: DungeonRoom
    let ghostLocation: MapPoint
    let scale: CGFloat

    var body: some View {
        Canvas { context, _ in
            let path: Path
            if room.shape == .ellipse {
                let rect = CGRect(
                    x: CGFloat(ghostLocation.x) * scale,
                    y: CGFloat(ghostLocation.y) * scale,
                    width: CGFloat(room.size.width) * scale,
                    height: CGFloat(room.size.height) * scale
                )
                path = Path(ellipseIn: rect)
            } else {
                guard room.edges.count > 1 else { return }
                let offset = ghostLocation - room.location
                var p = Path()
                for (index, edge) in room.edges.enumerated() {
                    let point = CGPoint((edge + offset) * scale)
                    if index == 0 { p.move(to: point) } else { p.addLine(to: point) }
                }
                p.closeSubpath()
                path = p
            }
            context.fill(path, with: .color(.accentColor.opacity(0.2)))
            context.stroke(
                path,
                with: .color(.accentColor.opacity(0.6)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 3])
            )
        }
    }
}
