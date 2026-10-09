//
//  TiledRoomShape.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/5/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

extension CGPoint {

    /// Returns a CGPoint from a Dungeon MapPoint.
    init(_ mapPoint: MapPoint) {
        self.init(x: CGFloat(mapPoint.x), y: CGFloat(mapPoint.y))
    }
}

extension DungeonRoom {
    /// The room's outline in screen space: a true ellipse for an ellipse room, otherwise
    /// the polygon through `edges`. Shared by tiling, selection, and drag-ghost rendering.
    func outlinePath(scale: CGFloat) -> Path {
        if shape == .ellipse {
            let rect = CGRect(
                x: CGFloat(location.x) * scale,
                y: CGFloat(location.y) * scale,
                width: CGFloat(size.width) * scale,
                height: CGFloat(size.height) * scale
            )
            return Path(ellipseIn: rect)
        }
        var path = Path()
        for (index, edge) in edges.enumerated() {
            let point = CGPoint(edge * scale)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// A view that draws a room with a tiled grid pattern, supporting rectangular, polygon,
/// and elliptical shapes.
struct TiledRoomShape: View {
    let room: DungeonRoom
    let scale: CGFloat
    let gridImage: Image
    let viewModel: DungeonMapViewModel

    var body: some View {
        Canvas { context, size in
            let outline = room.outlinePath(scale: scale)
            let bounds = outline.boundingRect

            // Tile the floor, clipped to the room's full shape (never cut by doors).
            var clippedContext = context
            clippedContext.clip(to: outline)
            drawTiledPattern(in: clippedContext, bounds: bounds)

            // Area features (pools, pits, spike strips, ...): above the floor, below
            // wall lines, doors, markers, and labels.
            for feature in room.features {
                drawAreaFeature(feature, in: clippedContext)
            }

            if room.shape == .ellipse {
                // Ellipse rooms keep the true-ellipse border and shadow, uncut: doors on a
                // round room draw over its border as they do for polygon rooms. Cutting an
                // arc where a door sits is out of scope for this prompt.
                drawInnerShadow(in: context, clipPath: outline, strokePath: outline)
                context.stroke(outline, with: .color(.darkGray), lineWidth: MapViewConfiguration.roomBorderWidth)
            } else {
                // Border and shadow are stroked along the wall runs, not the closed outline,
                // so a door's gap shows continuous floor instead of a wall segment.
                let wallPath = path(for: viewModel.wallRuns(for: room))
                drawInnerShadow(in: context, clipPath: outline, strokePath: wallPath)
                context.stroke(
                    wallPath,
                    with: .color(.darkGray),
                    style: StrokeStyle(lineWidth: MapViewConfiguration.roomBorderWidth, lineCap: .butt, lineJoin: .round)
                )
            }

            // Draw interior walls, above the floor and below doors and labels
            drawWalls(in: context, clipPath: outline)
        }
    }

    private func path(for runs: [[MapPoint]]) -> Path {
        var path = Path()
        for run in runs where run.count >= 2 {
            for (index, point) in run.enumerated() {
                let cgPoint = CGPoint(point * scale)
                if index == 0 {
                    path.move(to: cgPoint)
                } else {
                    path.addLine(to: cgPoint)
                }
            }
        }
        return path
    }

    private func drawWalls(in context: GraphicsContext, clipPath: Path) {
        guard !room.walls.isEmpty else { return }
        var wallsPath = Path()
        for wall in room.walls where wall.count >= 2 {
            for (index, point) in wall.enumerated() {
                let cgPoint = CGPoint(point * scale)
                if index == 0 {
                    wallsPath.move(to: cgPoint)
                } else {
                    wallsPath.addLine(to: cgPoint)
                }
            }
        }
        // Shadow first so it falls on both sides of the wall line, then the line itself.
        drawInnerShadow(in: context, clipPath: clipPath, strokePath: wallsPath)
        context.stroke(
            wallsPath,
            with: .color(.darkGray),
            style: StrokeStyle(lineWidth: MapViewConfiguration.roomBorderWidth, lineCap: .round)
        )
    }

    private func drawInnerShadow(in context: GraphicsContext, clipPath: Path, strokePath: Path) {
        // Create a clipped context for the shadow effect
        var shadowContext = context
        shadowContext.clip(to: clipPath)

        // Apply blur filter for smooth shadow, scaled appropriately
        let blurRadius = 3 * scale / MapViewConfiguration.baseTileSize
        shadowContext.addFilter(.blur(radius: blurRadius))

        // Draw an inset stroke to create the shadow effect, scaled appropriately
        let shadowLineWidth = 8 * scale / MapViewConfiguration.baseTileSize
        shadowContext.stroke(
            strokePath,
            with: .color(.darkGray.opacity(0.4)),
            lineWidth: shadowLineWidth
        )
    }

    /// Draws a sized `RoomFeature`'s footprint (pool, pit, spike strip, or a generic
    /// dashed-outline area). Point features (no `size`) are drawn by `FeatureMarkersView`
    /// instead and are ignored here.
    private func drawAreaFeature(_ feature: RoomFeature, in context: GraphicsContext) {
        guard let footprint = feature.footprint else { return }
        let rect = CGRect(
            x: CGFloat(footprint.origin.x) * scale,
            y: CGFloat(footprint.origin.y) * scale,
            width: CGFloat(footprint.size.width) * scale,
            height: CGFloat(footprint.size.height) * scale
        )
        switch feature.kind {
        case .pool: drawPool(rect, in: context)
        case .pit: drawPit(rect, in: context)
        case .trap: drawSpikeStrip(rect, in: context)
        default: drawGenericArea(rect, kind: feature.kind, in: context)
        }
    }

    /// A footprint filled with alternating light/medium blue-green horizontal stripes,
    /// so it reads as ruled water at any zoom, outlined in a thin mid blue-green.
    private func drawPool(_ rect: CGRect, in context: GraphicsContext) {
        var stripeContext = context
        stripeContext.clip(to: Path(rect))
        let stripeHeight = scale * MapViewConfiguration.poolStripeHeightRatio
        var y = rect.minY
        var isLight = true
        while y < rect.maxY {
            let stripeRect = CGRect(x: rect.minX, y: y, width: rect.width, height: min(stripeHeight, rect.maxY - y))
            stripeContext.fill(Path(stripeRect), with: .color(isLight ? .poolStripeLight : .poolStripeMedium))
            y += stripeHeight
            isLight.toggle()
        }
        context.stroke(Path(rect), with: .color(.poolOutline), lineWidth: MapViewConfiguration.roomBorderWidth * 0.75)
    }

    /// A footprint inset on each side, outlined like a room border, with both diagonals
    /// drawn corner to corner. No fill, no glyph.
    private func drawPit(_ rect: CGRect, in context: GraphicsContext) {
        let insetRect = rect.insetBy(dx: scale * MapViewConfiguration.pitInsetRatio, dy: scale * MapViewConfiguration.pitInsetRatio)
        var path = Path()
        path.addRect(insetRect)
        path.move(to: CGPoint(x: insetRect.minX, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.maxY))
        path.move(to: CGPoint(x: insetRect.maxX, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.maxY))
        context.stroke(path, with: .color(.darkGray), lineWidth: MapViewConfiguration.roomBorderWidth)
    }

    /// A regular grid of small filled dots in the wall color: the map's spike strip.
    /// No outline, no glyph.
    private func drawSpikeStrip(_ rect: CGRect, in context: GraphicsContext) {
        let inset = scale * MapViewConfiguration.trapInsetRatio
        let insetRect = rect.insetBy(dx: inset, dy: inset)
        guard insetRect.width > 0, insetRect.height > 0 else { return }
        let spacing = scale * MapViewConfiguration.trapDotSpacingRatio
        let dotDiameter = scale * MapViewConfiguration.trapDotDiameterRatio
        let columns = max(1, Int((insetRect.width / spacing).rounded()) + 1)
        let rows = max(1, Int((insetRect.height / spacing).rounded()) + 1)
        let colSpacing = columns > 1 ? insetRect.width / CGFloat(columns - 1) : 0
        let rowSpacing = rows > 1 ? insetRect.height / CGFloat(rows - 1) : 0
        for row in 0..<rows {
            for col in 0..<columns {
                let x = columns > 1 ? insetRect.minX + CGFloat(col) * colSpacing : insetRect.midX
                let y = rows > 1 ? insetRect.minY + CGFloat(row) * rowSpacing : insetRect.midY
                let dot = Path(ellipseIn: CGRect(x: x - dotDiameter / 2, y: y - dotDiameter / 2, width: dotDiameter, height: dotDiameter))
                context.fill(dot, with: .color(.darkGray))
            }
        }
    }

    /// A thin dashed outline of the footprint in mid gray, with the kind's glyph centered.
    private func drawGenericArea(_ rect: CGRect, kind: RoomFeature.Kind, in context: GraphicsContext) {
        let dash = StrokeStyle(lineWidth: MapViewConfiguration.roomBorderWidth, dash: [4, 3])
        context.stroke(Path(rect), with: .color(.mediumGray), style: dash)
        let glyphSize = min(rect.width, rect.height) * 0.6
        let glyph = Text(Image(systemName: kind.systemImageName))
            .font(.system(size: glyphSize))
            .foregroundColor(.mediumGray)
        context.draw(glyph, at: CGPoint(x: rect.midX, y: rect.midY))
    }

    private func drawTiledPattern(in context: GraphicsContext, bounds: CGRect) {
        // Calculate tile size based on scale
        let scaledTileSize = MapViewConfiguration.baseTileSize * scale / MapViewConfiguration.baseTileSize
        
        // Resolve the image from the Image type
        let resolvedImage = context.resolve(gridImage)
        
        // Calculate how many tiles we need (extend beyond bounds to ensure full coverage)
        let startX = floor(bounds.minX / scaledTileSize) * scaledTileSize
        let startY = floor(bounds.minY / scaledTileSize) * scaledTileSize
        let tilesX = Int(ceil((bounds.maxX - startX) / scaledTileSize)) + 1
        let tilesY = Int(ceil((bounds.maxY - startY) / scaledTileSize)) + 1
        
        // Draw tiles to fill the bounds
        for row in 0..<tilesY {
            for col in 0..<tilesX {
                let x = startX + CGFloat(col) * scaledTileSize
                let y = startY + CGFloat(row) * scaledTileSize
                let rect = CGRect(x: x, y: y, width: scaledTileSize, height: scaledTileSize)
                
                context.draw(resolvedImage, in: rect)
            }
        }
    }
}
