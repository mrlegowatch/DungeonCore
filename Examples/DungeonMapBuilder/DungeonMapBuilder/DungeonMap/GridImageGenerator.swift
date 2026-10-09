//
//  GridImageGenerator.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/5/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI

/// Generates a grid pattern image using Core Graphics.
func makeGridImage(size: CGSize, foreground: CGColor, background: CGColor, scaleFactor: CGFloat = 3.0) -> Image? {
    // Calculate scaled size for retina display
    let scaledSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
    let area = CGRect(origin: .zero, size: scaledSize)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    guard let context = CGContext(
        data: nil,
        width: Int(scaledSize.width),
        height: Int(scaledSize.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo().rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    ) else {
        return nil
    }
    
    // Fill background
    context.saveGState()
    context.setFillColor(background)
    context.fill(area)
    context.restoreGState()
    
    // Draw grid lines (left and top edges only - tiling will complete the grid)
    context.saveGState()
    context.setLineCap(.square)
    context.setStrokeColor(foreground)
    context.setLineWidth(MapViewConfiguration.gridLineWidth)
    
    // Vertical line on left edge (from top to bottom)
    let height = Int(scaledSize.height) - 1
    context.move(to: CGPoint(x: 0.5, y: 0.5))
    context.addLine(to: CGPoint(x: 0.5, y: CGFloat(height) + 0.5))
    context.strokePath()
    
    // Horizontal line on top edge (from left to right)
    let width = Int(scaledSize.width) - 1
    context.move(to: CGPoint(x: 0.5, y: 0.5))
    context.addLine(to: CGPoint(x: CGFloat(width) + 0.5, y: 0.5))
    context.strokePath()
    
    context.restoreGState()
    
    guard let cgImage = context.makeImage() else {
        return nil
    }
    
    return Image(decorative: cgImage, scale: scaleFactor, orientation: .up)
}

/// Shared grid tile used by `TiledRoomShape` and `DungeonMapContentView`.
///
/// Evaluated once at module load; the inputs are all compile-time constants.
let mapGridImage: Image? = makeGridImage(
    size: CGSize(width: MapViewConfiguration.baseTileSize, height: MapViewConfiguration.baseTileSize),
    foreground: .gray,
    background: .white,
    scaleFactor: MapViewConfiguration.gridImageScaleFactor
)
