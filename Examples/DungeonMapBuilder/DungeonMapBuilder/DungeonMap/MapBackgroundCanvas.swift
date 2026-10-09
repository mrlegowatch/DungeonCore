//
//  MapBackgroundCanvas.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/2/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI

/// A viewport-filling canvas that draws a parchment-colored background with a dungeon
/// grid, scrolling in phase with the map by shifting line origins with `scrollOffset`.
///
/// Grid lines are drawn at intervals of `scale` points (one map unit), so they align
/// exactly with the room/hallway grids drawn by `TiledRoomShape`.
struct MapBackgroundCanvas: View {
    let scrollOffset: CGPoint
    let scale: CGFloat
    let showGridLines = false // TODO: Make this a UI toggle

    // TODO: Provide a color palette, also add variations such as visual darkening around the edges
    private static let parchmentColor = Color(red: 0.96, green: 0.92, blue: 0.82)

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Self.parchmentColor)
            )
            if showGridLines {
                let phaseX = (-scrollOffset.x).truncatingRemainder(dividingBy: scale)
                let phaseY = (-scrollOffset.y).truncatingRemainder(dividingBy: scale)
                var gridPath = Path()
                
                var x = phaseX - scale
                while x <= size.width {
                    gridPath.move(to: CGPoint(x: x, y: 0))
                    gridPath.addLine(to: CGPoint(x: x, y: size.height))
                    x += scale
                }
                
                var y = phaseY - scale
                while y <= size.height {
                    gridPath.move(to: CGPoint(x: 0, y: y))
                    gridPath.addLine(to: CGPoint(x: size.width, y: y))
                    y += scale
                }
                
                ctx.stroke(
                    gridPath,
                    with: .color(Self.parchmentColor),
                    lineWidth: MapViewConfiguration.gridLineWidth
                )
            }
        }
    }
}
