//
//  SimpleDoorView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/6/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// A view that renders simple doors (opening, door, portcullis, slidingDoor, ladder, magicPortal)
struct SimpleDoorView: View {
    let viewModel: DungeonDoorViewModel
    
    var body: some View {
        Canvas { context, size in
            // An opening has no physical door: the gap cut into both neighbors' wall runs
            // (TiledRoomShape) is the opening. Draw nothing here.
            guard viewModel.door.kind != .opening else { return }
            drawSimpleDoor(in: context)
        }
    }

    private func drawSimpleDoor(in context: GraphicsContext) {
        let rect = viewModel.boundingRect
        var path = Path(rect)
        
        // Apply rotation if needed
        if viewModel.needsRotation {
            let angle = viewModel.computedRotationAngle
            let rotationCenter = CGPoint(x: rect.minX, y: rect.midY)
            let rotationTransform = CGAffineTransform(translationX: rotationCenter.x, y: rotationCenter.y)
                .rotated(by: angle)
                .translatedBy(x: -rotationCenter.x, y: -rotationCenter.y)
            path = path.applying(rotationTransform)
        }
        
        // Fill the door
        context.fill(path, with: .color(viewModel.doorColor.opacity(viewModel.alpha)))
        
        // Add border if needed
        if viewModel.borderWidth > 0 {
            context.stroke(path, with: .color(viewModel.doorColor), lineWidth: viewModel.borderWidth)
        }
        
        // Draw type-specific patterns
        switch viewModel.door.kind {
        case .portcullis:
            drawPortcullisPattern(in: context, rect: rect)
        case .slidingDoor:
            drawSlidingDoorIndicator(in: context, rect: rect)
        case .ladder:
            drawLadderRungs(in: context, rect: rect)
        default:
            break
        }
    }
    
    // MARK: - Type-Specific Patterns
    
    private func drawPortcullisPattern(in context: GraphicsContext, rect: CGRect) {
        let lineCount = 5
        let spacing = rect.width / CGFloat(lineCount + 1)
        
        var path = Path()
        
        // Draw vertical bars
        for i in 1...lineCount {
            let x = rect.minX + spacing * CGFloat(i)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        
        // Draw horizontal bars
        let horizontalCount = max(2, lineCount / 2)
        let horizontalSpacing = rect.height / CGFloat(horizontalCount + 1)
        for i in 1...horizontalCount {
            let y = rect.minY + horizontalSpacing * CGFloat(i)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        
        // Apply rotation if needed
        if viewModel.needsRotation {
            let angle = viewModel.computedRotationAngle
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let transform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: angle)
                .translatedBy(x: -center.x, y: -center.y)
            path = path.applying(transform)
        }
        
        context.stroke(path, with: .color(.darkGray), lineWidth: 1.0)
    }
    
    private func drawSlidingDoorIndicator(in context: GraphicsContext, rect: CGRect) {
        let arrowText = viewModel.needsRotation ? "⇄" : "⇅"
        let fontSize = viewModel.scale * 0.3
        let text = Text(arrowText)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(.white)
        context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY))
    }
    
    private func drawLadderRungs(in context: GraphicsContext, rect: CGRect) {
        var path = Path()
        
        if viewModel.needsRotation {
            // Vertical ladder - draw horizontal rungs
            let rungCount = max(3, Int(rect.height / (viewModel.scale * 0.2)))
            let spacing = rect.height / CGFloat(rungCount + 1)
            
            for i in 1...rungCount {
                let y = rect.minY + spacing * CGFloat(i)
                let inset = rect.width * 0.1
                path.move(to: CGPoint(x: rect.minX + inset, y: y))
                path.addLine(to: CGPoint(x: rect.maxX - inset, y: y))
            }
        } else {
            // Horizontal ladder - draw vertical rungs
            let rungCount = max(3, Int(rect.width / (viewModel.scale * 0.2)))
            let spacing = rect.width / CGFloat(rungCount + 1)
            
            for i in 1...rungCount {
                let x = rect.minX + spacing * CGFloat(i)
                let inset = rect.height * 0.1
                path.move(to: CGPoint(x: x, y: rect.minY + inset))
                path.addLine(to: CGPoint(x: x, y: rect.maxY - inset))
            }
        }
        
        context.stroke(path, with: .color(.black), lineWidth: 2.0)
    }
}
