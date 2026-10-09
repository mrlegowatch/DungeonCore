//
//  DungeonMapViewModel+Viewport.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/5/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import CoreGraphics
import DungeonCore

extension DungeonMapViewModel {

    // MARK: - Viewport

    /// Pixel offset applied before all map-coordinate rendering to ensure at least
    /// `canvasMargin` grid units of scrollable space before the nearest room or hallway.
    ///
    /// Zero on both axes when the map is empty or all content already starts at or beyond `canvasMargin`.
    var canvasOffset: CGPoint {
        guard let bounds = currentMap?.bounds else { return .zero }
        return CGPoint(
            x: max(0, MapViewConfiguration.canvasMargin - CGFloat(bounds.origin.x)) * scale,
            y: max(0, MapViewConfiguration.canvasMargin - CGFloat(bounds.origin.y)) * scale
        )
    }

    var contentSize: CGSize {
        guard let bounds = currentMap?.bounds else {
            let side = MapViewConfiguration.minimumCanvasSize * scale
            return CGSize(width: side, height: side)
        }
        let maxX = CGFloat(bounds.origin.x + bounds.size.width)
        let maxY = CGFloat(bounds.origin.y + bounds.size.height)
        let width = max(MapViewConfiguration.minimumCanvasSize, maxX + MapViewConfiguration.canvasMargin)
        let height = max(MapViewConfiguration.minimumCanvasSize, maxY + MapViewConfiguration.canvasMargin)
        return CGSize(width: width * scale, height: height * scale)
    }

    // MARK: - Coordinate conversion

    /// Converts a map-coordinate point to its screen position within the content view.
    func screenPoint(for mapPoint: MapPoint) -> CGPoint {
        let o = canvasOffset
        return CGPoint(x: CGFloat(mapPoint.x) * scale + o.x, y: CGFloat(mapPoint.y) * scale + o.y)
    }

    /// Converts a screen point in the "dungeonMap" coordinate space to map coordinates.
    func mapPoint(for screenPoint: CGPoint) -> MapPoint {
        let o = canvasOffset
        return MapPoint(x: Double((screenPoint.x - o.x) / scale), y: Double((screenPoint.y - o.y) / scale))
    }

    // MARK: - Hit testing

    /// Returns the topmost room containing the given point in screen coordinates.
    func room(at screenPoint: CGPoint) -> DungeonRoom? {
        let point = mapPoint(for: screenPoint)
        return currentMap?.rooms.last(where: { $0.contains(point) })
    }

    /// Returns true if the given screen point falls inside any hallway.
    func isInHallway(at screenPoint: CGPoint) -> Bool {
        let point = mapPoint(for: screenPoint)
        return currentMap?.hallways.contains(where: { $0.contains(point) }) ?? false
    }

    /// Returns the topmost door, hallway, or room at the given screen point.
    ///
    /// Doors are hit-tested via `DungeonDoor.hitTest(_:)`, which also checks their
    /// `fromArea`/`toArea`, because simple two-edge doors have degenerate zero-width
    /// bounding boxes that make the standard ray-cast always fail.
    func element(at screenPoint: CGPoint) -> DungeonRoom? {
        guard let currentMap else { return nil }
        let point = mapPoint(for: screenPoint)
        if let door = currentMap.doors.last(where: { $0.hitTest(point) }) { return door }
        if let hallway = currentMap.hallways.last(where: { $0.contains(point) }) { return hallway }
        return currentMap.rooms.last(where: { $0.contains(point) })
    }
}
