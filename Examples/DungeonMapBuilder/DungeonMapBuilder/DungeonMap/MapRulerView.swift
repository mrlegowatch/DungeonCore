//
//  MapRulerView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 8/2/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI

/// Grid-coordinate ruler strips pinned to the top and left edges of the map viewport.
///
/// Ticks appear at every grid unit; labels at every 5th unit (0, 5, 10, …).
/// Tick length equals half a grid unit (`scale / 2`), which is also the ruler thickness.
///
/// The top strip scrolls horizontally with the map but stays pinned to the top of the
/// viewport. The left strip scrolls vertically with the map but stays pinned to the left.
struct MapRulerView: View {
    let scale: CGFloat
    let scrollOffset: CGPoint
    var canvasOffset: CGPoint = .zero

    /// Ruler thickness = half a grid unit = tick mark length.
    private var thickness: CGFloat { scale / 2 }

    /// Label font size, clamped so text fits inside the ruler strip.
    private var labelFontSize: CGFloat { min(11, max(8, thickness - 3)) }

    /// Only show labels when the ruler strip is tall/wide enough to fit them.
    private var showLabels: Bool { thickness >= 11 }

    var body: some View {
        GeometryReader { geo in
            // Top horizontal ruler: ticks move with horizontal scroll, fixed to top.
            Canvas { context, size in
                let startCoord = (scrollOffset.x - canvasOffset.x) / scale
                let endCoord = (scrollOffset.x + size.width - canvasOffset.x) / scale
                let firstTick = Int(ceil(startCoord))
                let lastTick = Int(floor(endCoord))
                guard firstTick <= lastTick else { return }
                for tick in firstTick...lastTick {
                    let x = CGFloat(tick) * scale + canvasOffset.x - scrollOffset.x
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(.primary.opacity(0.5)), lineWidth: 1)
                    if showLabels, tick % 5 == 0 {
                        context.draw(
                            Text(verbatim: "\(tick)")
                                .font(.system(size: labelFontSize))
                                .foregroundStyle(.secondary),
                            at: CGPoint(x: x + 2, y: size.height / 2),
                            anchor: .leading
                        )
                    }
                }
            }
            .frame(width: geo.size.width, height: thickness)
            .background(.regularMaterial)
            .position(x: geo.size.width / 2, y: thickness / 2)

            // Left vertical ruler: ticks move with vertical scroll, fixed to left.
            Canvas { context, size in
                let startCoord = (scrollOffset.y - canvasOffset.y) / scale
                let endCoord = (scrollOffset.y + size.height - canvasOffset.y) / scale
                let firstTick = Int(ceil(startCoord))
                let lastTick = Int(floor(endCoord))
                guard firstTick <= lastTick else { return }
                for tick in firstTick...lastTick {
                    let y = CGFloat(tick) * scale + canvasOffset.y - scrollOffset.y
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.primary.opacity(0.5)), lineWidth: 1)
                    if showLabels, tick % 5 == 0 {
                        context.draw(
                            Text(verbatim: "\(tick)")
                                .font(.system(size: labelFontSize))
                                .foregroundStyle(.secondary),
                            at: CGPoint(x: size.width / 2, y: y + 2),
                            anchor: .top
                        )
                    }
                }
            }
            .frame(width: thickness, height: geo.size.height)
            .background(.regularMaterial)
            .position(x: thickness / 2, y: geo.size.height / 2)

            // Corner cap: covers the intersection of both ruler strips.
            Color.clear
                .background(.regularMaterial)
                .frame(width: thickness, height: thickness)
                .position(x: thickness / 2, y: thickness / 2)
        }
        .allowsHitTesting(false)
    }
}
