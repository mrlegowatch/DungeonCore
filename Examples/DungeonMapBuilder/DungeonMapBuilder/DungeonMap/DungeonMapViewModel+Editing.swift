//
//  DungeonMapViewModel+Editing.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/5/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import Foundation
import CoreGraphics
import DungeonCore

extension DungeonMapViewModel {

    // MARK: - Room mutations

    /// Adds a new 4×4 rectangular room centered at the given map-coordinate point and selects it.
    ///
    /// Returns `nil` without doing anything if there is no current map to add it to.
    @discardableResult
    func addRoom(at mapPoint: MapPoint, undoManager: UndoManager?) -> DungeonRoom? {
        guard let currentMap else { return nil }
        let size = MapSize(width: 4, height: 4)
        let origin = MapPoint(x: mapPoint.x - size.width / 2, y: mapPoint.y - size.height / 2)
        let room = DungeonRoom(location: origin, size: size)
        store.addRoom(room, to: currentMap, in: dungeon, undoManager: undoManager)
        selectedElement = room
        revision += 1
        return room
    }

    /// Removes the currently selected element (room, hallway, or door).
    func removeSelectedElement(undoManager: UndoManager?) {
        if let currentMap {
            if let door = selectedElement as? DungeonDoor {
                store.removeDoor(door, from: currentMap, in: dungeon, undoManager: undoManager)
            } else if let hallway = selectedElement as? DungeonHallway {
                store.removeHallway(hallway, from: currentMap, in: dungeon, undoManager: undoManager)
            } else if let room = selectedElement {
                store.removeRoom(room, from: currentMap, in: dungeon, undoManager: undoManager)
            }
        }
        selectedElement = nil
        revision += 1
    }

    /// Handles a drag-changed event, selecting the room under the drag's start point on the
    /// first call and moving it incrementally on subsequent calls.
    ///
    /// - Parameters:
    ///   - startLocation: The drag's initial position in map coordinates. Used only on the
    ///     first call to find which room to drag.
    ///   - translation: Total translation from drag start in screen points.
    ///   - snapping: When `true`, the room's origin is rounded to the nearest grid unit.
    func handleRoomDragChanged(startLocation: MapPoint, translation: CGSize, snapping: Bool) {
        if dragStartRoomLocation == nil {
            selectedElement = currentMap?.rooms.last(where: { $0.contains(startLocation) })
        }
        guard let room = selectedElement else { return }
        if dragStartRoomLocation == nil {
            dragStartRoomLocation = room.location
        }
        guard let startLoc = dragStartRoomLocation else { return }
        let rawX = startLoc.x + Double(translation.width / scale)
        let rawY = startLoc.y + Double(translation.height / scale)
        dragGhostLocation = MapPoint(x: rawX, y: rawY)
        var targetX = rawX
        var targetY = rawY
        if snapping {
            targetX = targetX.rounded()
            targetY = targetY.rounded()
        }
        room.translate(by: MapPoint(x: targetX - room.location.x, y: targetY - room.location.y))
        revision += 1
    }

    /// Finalizes a drag gesture, registering the move for undo and resetting drag state.
    func endRoomDrag(undoManager: UndoManager?) {
        defer {
            dragStartRoomLocation = nil
            dragGhostLocation = nil
        }
        guard let startLoc = dragStartRoomLocation, let room = selectedElement else { return }
        finalizeRoomMove(room: room, originalLocation: startLoc, undoManager: undoManager)
    }

    /// Finalizes a room move after a drag gesture completes, registering it for undo.
    ///
    /// The room must already be at its new position (moved incrementally during the drag).
    /// This method only records the original location so undo can reverse the move.
    func finalizeRoomMove(room: DungeonRoom, originalLocation: MapPoint, undoManager: UndoManager?) {
        store.registerMoveUndo(room: room, originalLocation: originalLocation, in: dungeon, undoManager: undoManager)
        revision += 1
    }

    /// Moves the corner at `cornerIndex` to `mapPoint`, keeping bounding box in sync.
    ///
    /// For axis-aligned rectangular rooms, dragging a corner propagates the new x and y
    /// to the two adjacent corners so the rectangle stays rectangular. For polygon rooms,
    /// only the dragged vertex moves.
    func handleCornerDragChanged(cornerIndex: Int, to mapPoint: MapPoint, snapping: Bool) {
        guard let room = selectedElement else { return }
        if resizingCornerIndex == nil {
            resizeStartEdges = room.edges
            resizeStartLocation = room.location
            resizeStartSize = room.size
            resizingCornerIndex = cornerIndex
        }
        let x = snapping ? mapPoint.x.rounded() : mapPoint.x
        let y = snapping ? mapPoint.y.rounded() : mapPoint.y
        if room.shape == .ellipse {
            resizeEllipseBoundingBox(room: room, cornerIndex: cornerIndex, x: x, y: y)
            revision += 1
            return
        }
        if room.isAxisAlignedRectangle {
            // Edges are clockwise: [TL(0), TR(1), BR(2), BL(3)].
            // Each corner shares its x with one neighbour and its y with the other.
            var edges = room.edges
            switch cornerIndex {
            case 0: // TL — propagate x→BL, y→TR
                edges[0] = MapPoint(x: x, y: y)
                edges[1] = MapPoint(x: edges[1].x, y: y)
                edges[3] = MapPoint(x: x, y: edges[3].y)
            case 1: // TR — propagate x→BR, y→TL
                edges[1] = MapPoint(x: x, y: y)
                edges[0] = MapPoint(x: edges[0].x, y: y)
                edges[2] = MapPoint(x: x, y: edges[2].y)
            case 2: // BR — propagate x→TR, y→BL
                edges[2] = MapPoint(x: x, y: y)
                edges[1] = MapPoint(x: x, y: edges[1].y)
                edges[3] = MapPoint(x: edges[3].x, y: y)
            case 3: // BL — propagate x→TL, y→BR
                edges[3] = MapPoint(x: x, y: y)
                edges[0] = MapPoint(x: x, y: edges[0].y)
                edges[2] = MapPoint(x: edges[2].x, y: y)
            default: break
            }
            room.edges = edges
        } else {
            room.edges[cornerIndex] = MapPoint(x: x, y: y)
        }
        syncBoundingBox(for: room)
        revision += 1
    }

    /// Moves one of the four bounding-box corners of an ellipse room, keeping the
    /// opposite corner fixed, then regenerates the ellipse's vertices from the new box.
    fileprivate func resizeEllipseBoundingBox(room: DungeonRoom, cornerIndex: Int, x: Double, y: Double) {
        var topLeft = room.location
        var bottomRight = MapPoint(x: room.location.x + room.size.width, y: room.location.y + room.size.height)
        switch cornerIndex {
        case 0: // TL — propagate x→BL, y→TR (opposite corner BR stays fixed)
            topLeft = MapPoint(x: x, y: y)
        case 1: // TR
            topLeft = MapPoint(x: topLeft.x, y: y)
            bottomRight = MapPoint(x: x, y: bottomRight.y)
        case 2: // BR
            bottomRight = MapPoint(x: x, y: y)
        case 3: // BL
            topLeft = MapPoint(x: x, y: topLeft.y)
            bottomRight = MapPoint(x: bottomRight.x, y: y)
        default:
            break
        }
        room.location = topLeft
        room.size = MapSize(width: max(0.1, bottomRight.x - topLeft.x), height: max(0.1, bottomRight.y - topLeft.y))
        room.regenerateEllipseEdges()
    }

    /// Finalizes a corner drag, registering the resize for undo and resetting resize state.
    func endCornerResize(undoManager: UndoManager?) {
        defer {
            resizingCornerIndex = nil
            resizeStartEdges = nil
            resizeStartLocation = nil
            resizeStartSize = nil
        }
        guard let startEdges = resizeStartEdges,
              let startLocation = resizeStartLocation,
              let startSize = resizeStartSize,
              let room = selectedElement else { return }
        store.registerResizeUndo(room: room, originalEdges: startEdges, originalLocation: startLocation, originalSize: startSize, in: dungeon, undoManager: undoManager)
    }

    // MARK: - Hallway drawing

    /// Appends a snapped point to the in-progress hallway centerline.
    func appendHallwayPoint(_ point: MapPoint, snapping: Bool) {
        let p = snapping ? MapPoint(x: point.x.rounded(), y: point.y.rounded()) : point
        if hallwayDraftPoints == nil {
            hallwayDraftPoints = [p]
        } else {
            hallwayDraftPoints?.append(p)
        }
        hallwayPreviewPoint = p
        revision += 1
    }

    /// Updates the live preview endpoint during a hallway drawing drag.
    func updateHallwayPreview(_ point: MapPoint, snapping: Bool) {
        hallwayPreviewPoint = snapping ? MapPoint(x: point.x.rounded(), y: point.y.rounded()) : point
        revision += 1
    }

    /// Commits the hallway draft if it has at least two points, then clears draft state.
    func finishHallway(undoManager: UndoManager?) {
        defer {
            hallwayDraftPoints = nil
            hallwayPreviewPoint = nil
        }
        guard let points = hallwayDraftPoints, points.count >= 2, let currentMap else { return }
        let hallway = DungeonHallway(segments: points, width: 1.0)
        store.addHallway(hallway, to: currentMap, in: dungeon, undoManager: undoManager)
        selectedElement = hallway
        revision += 1
    }

    /// Discards the current hallway draft.
    func cancelHallwayDraft() {
        hallwayDraftPoints = nil
        hallwayPreviewPoint = nil
        revision += 1
    }

    // MARK: - Door drawing

    /// Begins a door draft at the given map coordinate.
    func beginDoorDraft(at point: MapPoint) {
        doorDraftStart = point
        doorDraftEnd = point
        revision += 1
    }

    /// Updates the far endpoint of the door draft.
    func updateDoorDraft(to point: MapPoint, snapping: Bool) {
        doorDraftEnd = snapping ? MapPoint(x: point.x.rounded(), y: point.y.rounded()) : point
        revision += 1
    }

    /// Commits the door draft if its two endpoints are meaningfully distinct, then clears draft state.
    func finishDoorDraft(undoManager: UndoManager?) {
        defer {
            doorDraftStart = nil
            doorDraftEnd = nil
        }
        guard let start = doorDraftStart, let end = doorDraftEnd, let currentMap else { return }
        let dx = end.x - start.x
        let dy = end.y - start.y
        guard dx * dx + dy * dy > 0.25 else { return }
        let door = DungeonDoor(kind: .door, leftEdge: start, rightEdge: end)
        store.addDoor(door, to: currentMap, in: dungeon, undoManager: undoManager)
        selectedElement = door
        revision += 1
    }

    /// Discards the current door draft.
    func cancelDoorDraft() {
        doorDraftStart = nil
        doorDraftEnd = nil
        revision += 1
    }

    // MARK: - Private helpers

    fileprivate func syncBoundingBox(for room: DungeonRoom) {
        guard !room.edges.isEmpty else { return }
        let xs = room.edges.map(\.x)
        let ys = room.edges.map(\.y)
        room.location = MapPoint(x: xs.min()!, y: ys.min()!)
        room.size = MapSize(width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
}
