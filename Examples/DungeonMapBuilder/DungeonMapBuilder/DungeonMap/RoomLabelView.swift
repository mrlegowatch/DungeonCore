//
//  RoomLabelView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/5/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// A view that renders room, hallway, and door labels on the dungeon map.
struct RoomLabelView: View {
    let rooms: [DungeonRoom]
    let scale: CGFloat
    var revision: Int = 0
    var showRoomLabels: Bool = true
    var hallways: [DungeonRoom] = []
    var showHallwayLabels: Bool = false
    var doors: [DungeonRoom] = []
    var showDoorLabels: Bool = false
    var showFeatures: Bool = true

    init(viewModel: DungeonMapViewModel, displaySettings: MapDisplaySettings) {
        self.rooms = viewModel.currentMap?.rooms ?? []
        self.scale = viewModel.scale
        self.revision = viewModel.revision
        self.showRoomLabels = displaySettings.showRoomLabels
        self.hallways = viewModel.currentMap?.hallways ?? []
        self.showHallwayLabels = displaySettings.showHallwayLabels
        self.doors = viewModel.currentMap?.doors ?? []
        self.showDoorLabels = displaySettings.showDoorLabels
        self.showFeatures = displaySettings.showFeatures
    }

    var body: some View {
        Canvas { context, size in
            let fontSize = MapViewConfiguration.labelBaseFontSize * scale / MapViewConfiguration.baseTileSize
            var placedRects: [CGRect] = []

            // When any room on the map carries a module key number, an index-based fallback
            // ("1", "2", ...) would collide with real key numbers (e.g. the entrance next to
            // room "1"), so unlabeled rooms simply go unlabeled instead.
            let anyRoomHasKeyNumber = rooms.contains { $0.keyNumber != nil }

            for (index, room) in rooms.enumerated() {
                let label: String? = room.keyNumber
                    ?? room.shortName
                    ?? (room.labelLocation != nil ? room.name : nil)
                    ?? (anyRoomHasKeyNumber ? nil : "\(index + 1)")
                guard let label else { continue }

                if showRoomLabels {
                    let resolvedText = context.resolve(Text(label).font(.system(size: fontSize)))
                    let measuredSize = resolvedText.measure(in: CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
                    let center = roomLabelCenter(for: room, measuredSize: measuredSize, fontSize: fontSize)
                    context.draw(
                        Text(label).font(.system(size: fontSize)).foregroundColor(.darkGray),
                        at: center, anchor: .center
                    )
                    if showDoorLabels {
                        placedRects.append(CGRect(
                            x: center.x - measuredSize.width / 2, y: center.y - measuredSize.height / 2,
                            width: measuredSize.width, height: measuredSize.height
                        ))
                    }
                }
            }

            if showHallwayLabels {
                for (index, hallway) in hallways.enumerated() {
                    let point = labelPoint(for: hallway, fontSize: fontSize)
                    let label = "H\(index + 1)"
                    context.draw(
                        Text(label).font(.system(size: fontSize)).foregroundColor(.mediumGray),
                        at: point, anchor: .leading
                    )
                    if showDoorLabels { placedRects.append(approxRect(at: point, charCount: label.count, fontSize: fontSize)) }
                }
            }

            if showDoorLabels {
                for (index, door) in doors.enumerated() {
                    let initialPoint = labelPoint(for: door, fontSize: fontSize)
                    let label = "D\(index + 1)"
                    let point = resolvedPoint(for: initialPoint, charCount: label.count, fontSize: fontSize, avoiding: placedRects)
                    context.draw(
                        Text(label).font(.system(size: fontSize)).foregroundColor(.darkBlue.opacity(0.8)),
                        at: point, anchor: .leading
                    )
                    placedRects.append(approxRect(at: point, charCount: label.count, fontSize: fontSize))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func labelPoint(for room: DungeonRoom, fontSize: CGFloat) -> CGPoint {
        labelPoint(forLocation: bestLabelLocation(for: room), fontSize: fontSize)
    }

    private func labelPoint(forLocation location: MapPoint, fontSize: CGFloat) -> CGPoint {
        CGPoint(
            x: CGFloat(location.x) * scale + MapViewConfiguration.labelOffsetXRatio * scale + MapViewConfiguration.labelOffsetX,
            y: CGFloat(location.y) * scale + MapViewConfiguration.labelOffsetYRatio * scale + fontSize
        )
    }

    /// Point markers, their id labels, and area footprints belonging to `room`, in screen space.
    private func featureObstacles(in room: DungeonRoom) -> [CGRect] {
        room.features.flatMap { feature -> [CGRect] in
            [
                FeatureMarkerGeometry.markerRect(for: feature, scale: scale),
                FeatureMarkerGeometry.labelRect(for: feature, scale: scale, showLabels: showFeatures),
                FeatureMarkerGeometry.footprintRect(for: feature, scale: scale),
            ].compactMap { $0 }
        }
    }

    /// The screen-space center point for `room`'s number label: the author's own
    /// `labelLocation` when set (drawn centered there, no collision avoidance), otherwise
    /// the first bounding-box corner (top-left, top-right, bottom-left, bottom-right)
    /// whose inset rectangle clears every feature obstacle in the room, computed in map
    /// units via `LabelPlacement` and scaled back to screen space.
    private func roomLabelCenter(for room: DungeonRoom, measuredSize: CGSize, fontSize: CGFloat) -> CGPoint {
        if let labelLocation = room.labelLocation {
            return CGPoint(x: CGFloat(labelLocation.x) * scale, y: CGFloat(labelLocation.y) * scale)
        }

        let boundingBox = CGRect(x: room.location.x, y: room.location.y, width: room.size.width, height: room.size.height)
        let edges = room.edges.map { CGPoint(x: $0.x, y: $0.y) }
        let labelSize = CGSize(width: measuredSize.width / scale, height: measuredSize.height / scale)
        let horizontalInset = (MapViewConfiguration.labelOffsetXRatio * scale + MapViewConfiguration.labelOffsetX) / scale
        // Matches the pre-Prompt-10 top-left position exactly: that anchor's vertical
        // center sat at `labelOffsetYRatio*scale + fontSize` below the top wall; the
        // inset here is measured to the rect's top edge, half a label-height above that.
        let verticalInset = (MapViewConfiguration.labelOffsetYRatio * scale + fontSize - measuredSize.height / 2) / scale
        let obstacles = featureObstacles(in: room).map { rect in
            CGRect(x: rect.minX / scale, y: rect.minY / scale, width: rect.width / scale, height: rect.height / scale)
        }

        let rect = LabelPlacement.automaticLabelRect(
            isEllipse: room.shape == .ellipse,
            boundingBox: boundingBox,
            edges: edges,
            labelSize: labelSize,
            inset: CGSize(width: horizontalInset, height: verticalInset),
            obstacles: obstacles,
            contains: { point in room.contains(MapPoint(x: Double(point.x), y: Double(point.y))) }
        )
        return CGPoint(x: rect.midX * scale, y: rect.midY * scale)
    }

    // Approximate bounding rect for a label drawn with .leading anchor.
    // With .leading, the point is at the left-center of the text, so top is point.y - height/2.
    private func approxRect(at point: CGPoint, charCount: Int, fontSize: CGFloat) -> CGRect {
        let height = fontSize * 1.1
        return CGRect(
            x: point.x,
            y: point.y - height / 2,
            width: CGFloat(charCount) * fontSize * 0.65,
            height: height
        )
    }

    private func resolvedPoint(for point: CGPoint, charCount: Int, fontSize: CGFloat, avoiding placed: [CGRect]) -> CGPoint {
        guard placed.contains(where: { $0.intersects(approxRect(at: point, charCount: charCount, fontSize: fontSize)) }) else {
            return point
        }
        let candidates = [
            CGPoint(x: point.x, y: point.y + fontSize * 1.3),
            CGPoint(x: point.x + scale, y: point.y),
            CGPoint(x: point.x, y: point.y + fontSize * 2.6),
            CGPoint(x: point.x + scale, y: point.y + fontSize * 1.3),
        ]
        for candidate in candidates {
            if !placed.contains(where: { $0.intersects(approxRect(at: candidate, charCount: charCount, fontSize: fontSize)) }) {
                return candidate
            }
        }
        return point
    }

    private func bestLabelLocation(for room: DungeonRoom) -> MapPoint {
        if room.edges.count > 0 {
            var bestLocation = room.edges[0]
            for edge in room.edges {
                if edge.y < bestLocation.y {
                    bestLocation = edge
                }
            }
            return bestLocation
        } else {
            return room.location
        }
    }
}
