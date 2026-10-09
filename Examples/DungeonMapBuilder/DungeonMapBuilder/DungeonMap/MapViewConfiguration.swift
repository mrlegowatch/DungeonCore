//
//  MapViewConfiguration.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/5/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import CoreGraphics

/// Configuration constants for the dungeon map view
enum MapViewConfiguration {
    // MARK: - Scale Settings
    
    static let minScale: CGFloat = 10
    static let maxScale: CGFloat = 80
    static let defaultScale: CGFloat = 40.0
    static let scaleStep: CGFloat = 5.0
    
    // MARK: - Tile Settings
    
    static let baseTileSize: CGFloat = 40.0
    static let gridLineWidth: CGFloat = 1.0
    
    // MARK: - Grid Image Settings
    
    static let gridImageScaleFactor: CGFloat = 3.0
    
    // MARK: - Canvas Settings

    /// Grid units of empty space reserved before the nearest map element on each axis.
    static let canvasMargin: CGFloat = 2.0
    /// Minimum canvas size in grid units for an otherwise empty map.
    static let minimumCanvasSize: CGFloat = 20.0

    // MARK: - Room Settings

    static let roomInset: CGFloat = 0.0
    static let roomBorderWidth: CGFloat = 1.0
    
    // MARK: - Door Settings

    /// Fraction of the door's span that the door slab covers, for every simple door kind.
    static let doorLengthRatio: CGFloat = 0.5
    static let doorThicknessRatio: CGFloat = 0.14
    static let doorBorderWidth: CGFloat = 1.0

    // MARK: - Secret Door Settings

    /// Height of the "S" glyph drawn on a secret door or tunnel, as a fraction of a grid square.
    static let secretGlyphHeightRatio: CGFloat = 0.5
    
    // MARK: - Label Settings
    
    static let labelOffsetX: CGFloat = 4.0
    static let labelOffsetXRatio: CGFloat = 0.15
    static let labelOffsetYRatio: CGFloat = 0.05
    static let labelBaseFontSize: CGFloat = 16.0
    
    // MARK: - One-Way Door Settings
    
    static let oneWayArrowBaseFontSize: CGFloat = 12.0
    
    // MARK: - Lock Indicator Settings

    static let lockIndicatorSizeRatio: CGFloat = 0.3

    // MARK: - Feature Marker Settings

    /// Diameter of a room feature's point marker circle, as a fraction of a grid square.
    static let featureMarkerDiameterRatio: CGFloat = 0.4
    /// Size of a point marker's glyph, as a fraction of the marker's diameter.
    static let featureGlyphSizeRatio: CGFloat = 0.85
    /// Diameter of a floorHatch/ceilingHatch classic map mark, as a fraction of a grid square.
    static let featureHatchMarkDiameterRatio: CGFloat = 0.6
    /// Gap between a point marker's edge and the start of its id label.
    static let featureLabelGap: CGFloat = 2.0

    // MARK: - Area Feature Settings

    /// Height of each stripe in a pool's fill, as a fraction of a grid square.
    static let poolStripeHeightRatio: CGFloat = 0.2
    /// Inset applied to a pit's footprint on each side, as a fraction of a grid square.
    static let pitInsetRatio: CGFloat = 0.1
    /// Inset applied to a spike-strip trap's footprint on each side, as a fraction of a grid square.
    static let trapInsetRatio: CGFloat = 0.17
    /// Spacing between spike-strip dots, as a fraction of a grid square.
    static let trapDotSpacingRatio: CGFloat = 0.33
    /// Diameter of each spike-strip dot, as a fraction of a grid square.
    static let trapDotDiameterRatio: CGFloat = 0.08
}
