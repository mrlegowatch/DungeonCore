//
//  RectangularDoorView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/6/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// A view that renders rectangular doors (trapDoor, elevator).
struct RectangularDoorView: View {
    let viewModel: DungeonDoorViewModel
    
    var body: some View {
        Canvas { context, size in
            drawRectangularDoor(in: context)
        }
    }
    
    private func drawRectangularDoor(in context: GraphicsContext) {
        let rect = viewModel.boundingRect
        let path = Path(rect)
        
        // Fill the door
        context.fill(path, with: .color(viewModel.doorColor.opacity(viewModel.alpha)))
        
        // Add border
        if viewModel.borderWidth > 0 {
            context.stroke(path, with: .color(viewModel.doorColor), lineWidth: viewModel.borderWidth)
        }
        
        // Draw type-specific patterns
        switch viewModel.door.kind {
        case .trapDoor:
            drawTrapDoorPattern(in: context, rect: rect)
        case .elevator:
            drawElevatorPattern(in: context, rect: rect)
        default:
            break
        }
    }
    
    // MARK: - Type-Specific Patterns
    
    private func drawTrapDoorPattern(in context: GraphicsContext, rect: CGRect) {
        var path = Path()
        
        // Draw inset rectangle
        let insetAmount = min(rect.width, rect.height) * 0.1
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let insetRectPath = Path(insetRect)
        context.stroke(insetRectPath, with: .color(.black.opacity(0.6)), lineWidth: 1.5)
        
        // Draw X pattern
        path.move(to: CGPoint(x: insetRect.minX, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.maxY))
        path.move(to: CGPoint(x: insetRect.maxX, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.maxY))
        
        context.stroke(path, with: .color(.black.opacity(0.6)), lineWidth: 1.5)
        
        // Draw handle
        let handleSize = min(rect.width, rect.height) * 0.2
        let handleRect = CGRect(
            x: rect.midX - handleSize / 2,
            y: rect.midY - handleSize / 2,
            width: handleSize,
            height: handleSize
        )
        let handlePath = Path(ellipseIn: handleRect)
        context.stroke(handlePath, with: .color(.black), lineWidth: 2.0)
        context.fill(handlePath, with: .color(.white.opacity(0.5)))
    }
    
    private func drawElevatorPattern(in context: GraphicsContext, rect: CGRect) {
        // Draw border for shaft walls
        let insetRect = rect.insetBy(dx: viewModel.scale * 0.1, dy: viewModel.scale * 0.1)
        let innerBorderPath = Path(insetRect)
        context.stroke(innerBorderPath, with: .color(.black), lineWidth: 2.0)
        
        // Draw elevator doors
        var doorPath = Path()
        let doorGap = rect.width * 0.05
        doorPath.move(to: CGPoint(x: rect.midX - doorGap / 2, y: rect.minY))
        doorPath.addLine(to: CGPoint(x: rect.midX - doorGap / 2, y: rect.maxY))
        doorPath.move(to: CGPoint(x: rect.midX + doorGap / 2, y: rect.minY))
        doorPath.addLine(to: CGPoint(x: rect.midX + doorGap / 2, y: rect.maxY))
        context.stroke(doorPath, with: .color(.black.opacity(0.7)), lineWidth: 2.0)
        
        // Draw up/down arrows
        let arrowSize = min(rect.width, rect.height) * 0.25
        let upArrowY = rect.midY - arrowSize * 0.6
        let downArrowY = rect.midY + arrowSize * 0.6
        
        let upArrowText = Text("↑")
            .font(.system(size: arrowSize, weight: .bold))
            .foregroundColor(.black)
        context.draw(upArrowText, at: CGPoint(x: rect.midX, y: upArrowY))
        
        let downArrowText = Text("↓")
            .font(.system(size: arrowSize, weight: .bold))
            .foregroundColor(.black)
        context.draw(downArrowText, at: CGPoint(x: rect.midX, y: downArrowY))
    }
}
