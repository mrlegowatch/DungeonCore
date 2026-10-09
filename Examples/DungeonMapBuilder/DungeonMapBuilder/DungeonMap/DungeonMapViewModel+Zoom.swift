//
//  DungeonMapViewModel+Zoom.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/5/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import CoreGraphics

extension DungeonMapViewModel {

    // MARK: - Zoom

    var canZoomIn: Bool { scale < MapViewConfiguration.maxScale }
    var canZoomOut: Bool { scale > MapViewConfiguration.minScale }

    func zoomIn() {
        scale = min(MapViewConfiguration.maxScale, scale + MapViewConfiguration.scaleStep)
    }

    func zoomOut() {
        scale = max(MapViewConfiguration.minScale, scale - MapViewConfiguration.scaleStep)
    }

    func setScale(_ newScale: CGFloat) {
        scale = min(MapViewConfiguration.maxScale, max(MapViewConfiguration.minScale, newScale))
    }

    func resetScale() {
        scale = MapViewConfiguration.defaultScale
    }
}
