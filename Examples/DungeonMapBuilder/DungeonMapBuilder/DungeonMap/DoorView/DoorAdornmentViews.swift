//
//  DoorAdornmentViews.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/6/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// A view that draws the background areas (fromArea and toArea) for a door
struct DoorAreaView: View {
    let viewModel: DungeonDoorViewModel
    
    var body: some View {
        Canvas { context, size in
            drawDoorAreas(in: context)
        }
    }
    
    private func drawDoorAreas(in context: GraphicsContext) {
        let fromAreaPath = createPolygonPath(from: viewModel.door.fromArea)
        context.fill(fromAreaPath, with: .color(.green.opacity(0.10)))
        
        let toAreaPath = createPolygonPath(from: viewModel.door.toArea)
        context.fill(toAreaPath, with: .color(.red.opacity(0.10)))
    }
    
    private func createPolygonPath(from points: [MapPoint]) -> Path {
        var path = Path()
        
        guard !points.isEmpty else { return path }
        
        let firstPoint = CGPoint(points[0] * viewModel.scale)
        path.move(to: firstPoint)
        
        for i in 1..<points.count {
            let point = CGPoint(points[i] * viewModel.scale)
            path.addLine(to: point)
        }
        
        path.closeSubpath()
        
        return path
    }
}

/// A view that draws a one-way arrow on a door
struct OneWayArrowView: View {
    let viewModel: DungeonDoorViewModel
    
    var body: some View {
        Canvas { context, size in
            let rect = viewModel.boundingRect
            let fontSize = MapViewConfiguration.oneWayArrowBaseFontSize * viewModel.scale / MapViewConfiguration.baseTileSize
            let text = Text(viewModel.oneWayArrowText)
                .font(.system(size: fontSize))
                .foregroundColor(.white)
            context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY))
        }
    }
}

/// A view that draws a lock indicator on a door
struct LockIndicatorView: View {
    let viewModel: DungeonDoorViewModel

    var body: some View {
        Canvas { context, size in
            let rect = viewModel.boundingRect
            let lockSize = viewModel.scale * MapViewConfiguration.lockIndicatorSizeRatio
            var center = CGPoint(x: rect.midX, y: rect.midY)

            // A secret door already has its "S" glyph at the center; move the lock
            // beside it along the door's own direction so the two don't overlap.
            let door = viewModel.door
            if door.hasAttribute(.isSecret), door.kind != .passage {
                let direction = (door.rightEdge - door.leftEdge).normalized()
                let besideOffset = max(viewModel.scale * 0.4, lockSize * 0.75)
                center = CGPoint(x: center.x + CGFloat(direction.x) * besideOffset,
                                  y: center.y + CGFloat(direction.y) * besideOffset)
            }

            let lockText = Text(door.keyID != nil ? "🔑" : "🔒").font(.system(size: lockSize))
            context.draw(lockText, at: center)
        }
    }
}

/// A view that draws a bold "S" glyph for a secret door, in place of its normal body.
///
/// The surrounding wall is already drawn continuously by the room's own border; a secret
/// door simply omits its usual slab or gap and marks itself with the classic map "S".
struct SecretDoorGlyphView: View {
    let viewModel: DungeonDoorViewModel

    var body: some View {
        Canvas { context, size in
            let rect = viewModel.boundingRect
            let glyphSize = viewModel.scale * MapViewConfiguration.secretGlyphHeightRatio
            let text = Text("S").font(.system(size: glyphSize, weight: .regular)).foregroundColor(.darkGray)
            context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY))
        }
    }
}
