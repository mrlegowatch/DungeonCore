//
//  FeatureMarkersView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 10/6/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// Draws a small point marker for every `RoomFeature` on the current map that has no
/// `size`, above rooms and below labels. Features with a `size` draw their footprint
/// instead; see `TiledRoomShape`. Markers do not take taps.
struct FeatureMarkersView: View {
    let rooms: [DungeonRoom]
    let scale: CGFloat
    var revision: Int = 0
    var showLabels: Bool = true
    var showFeatures: Bool = true

    init(viewModel: DungeonMapViewModel, displaySettings: MapDisplaySettings) {
        self.rooms = viewModel.currentMap?.rooms ?? []
        self.scale = viewModel.scale
        self.revision = viewModel.revision
        self.showLabels = displaySettings.showRoomLabels
        self.showFeatures = displaySettings.showFeatures
    }

    var body: some View {
        Canvas { context, _ in
            guard showFeatures else { return }
            let fontSize = MapViewConfiguration.labelBaseFontSize * scale / MapViewConfiguration.baseTileSize
            for room in rooms {
                for feature in room.features where feature.footprint == nil {
                    draw(feature, in: context, fontSize: fontSize)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ feature: RoomFeature, in context: GraphicsContext, fontSize: CGFloat) {
        let center = CGPoint(feature.location * scale)
        let showsLabel = showLabels && feature.keyLabel != nil

        switch feature.kind {
        case .floorHatch:
            drawHatchMark(context: context, center: center, letter: "F")
        case .ceilingHatch:
            drawHatchMark(context: context, center: center, letter: "C")
        case .area:
            // Quarters and similar zone markers: no dot, just a centered id label.
            if showsLabel {
                context.draw(
                    Text(feature.id).font(.system(size: fontSize)).foregroundColor(.darkGray),
                    at: center
                )
            }
            return
        default:
            drawPointMarker(feature, center: center, in: context)
        }

        if showsLabel {
            let radius = scale * MapViewConfiguration.featureMarkerDiameterRatio / 2
            let labelPoint = CGPoint(x: center.x + radius + MapViewConfiguration.featureLabelGap, y: center.y)
            context.draw(
                Text(feature.id).font(.system(size: fontSize)).foregroundColor(.darkGray),
                at: labelPoint, anchor: .leading
            )
        }
    }

    /// Draws a single-color marker that reads as a map symbol: a dark gray circle
    /// outline with the kind's glyph centered inside, no fill, no per-kind color.
    private func drawPointMarker(_ feature: RoomFeature, center: CGPoint, in context: GraphicsContext) {
        let diameter = scale * MapViewConfiguration.featureMarkerDiameterRatio
        let circle = Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter))
        context.stroke(circle, with: .color(.darkGray), lineWidth: MapViewConfiguration.roomBorderWidth)
        let glyph = Text(Image(systemName: feature.kind.systemImageName))
            .font(.system(size: diameter * MapViewConfiguration.featureGlyphSizeRatio))
            .foregroundColor(.darkGray)
        context.draw(glyph, at: center)
    }

    /// Draws a circled letter outlined in the wall color, with no fill — read as a
    /// map symbol, the same way the secret-door "S" is drawn.
    private func drawHatchMark(context: GraphicsContext, center: CGPoint, letter: String) {
        let diameter = scale * MapViewConfiguration.featureHatchMarkDiameterRatio
        let circle = Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter))
        context.stroke(circle, with: .color(.darkGray), lineWidth: MapViewConfiguration.roomBorderWidth)
        let text = Text(letter).font(.system(size: diameter * 0.6, weight: .regular)).foregroundColor(.darkGray)
        context.draw(text, at: center)
    }
}

extension RoomFeature.Kind {
    /// A one-glyph SF Symbol representing this kind. `floorHatch` and `ceilingHatch` are
    /// drawn as classic circled-letter map marks instead and never use this symbol.
    /// `area` draws no marker at all and never uses this symbol either.
    var systemImageName: String {
        switch self {
        case .area:         "square.dashed"
        case .lever:        "switch.2"
        case .idol:         "figure.stand"
        case .pool:         "drop.fill"
        case .pit:          "arrow.down.to.line"
        case .trap:         "exclamationmark.triangle.fill"
        case .hazard:       "flame.fill"
        case .hearth:       "flame.circle.fill"
        case .container:    "shippingbox.fill"
        case .furnishing:   "bed.double.fill"
        case .decoration:   "sparkles"
        case .stairs:       "figure.stairs"
        case .floorHatch, .ceilingHatch: "questionmark.circle.fill"
        case .other:        "questionmark.circle.fill"
        }
    }
}

/// Shared screen-space geometry for a feature's point marker and id label, used by
/// `FeatureMarkersView` to draw them and by `RoomLabelView` to avoid overlapping them.
enum FeatureMarkerGeometry {
    /// The marker circle's bounding rect, or `nil` for a sized (area) feature or an
    /// `.area`-kind feature, neither of which draws a dot.
    static func markerRect(for feature: RoomFeature, scale: CGFloat) -> CGRect? {
        guard feature.footprint == nil, feature.kind != .area else { return nil }
        let center = CGPoint(feature.location * scale)
        let diameter = scale * MapViewConfiguration.featureMarkerDiameterRatio
        return CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
    }

    /// The approximate bounding rect of a feature's id label, or `nil` when it has none
    /// (a generated id, i.e. one with no `keyLabel`) or `showLabels` is false.
    static func labelRect(for feature: RoomFeature, scale: CGFloat, showLabels: Bool) -> CGRect? {
        guard showLabels, feature.keyLabel != nil else { return nil }
        let fontSize = MapViewConfiguration.labelBaseFontSize * scale / MapViewConfiguration.baseTileSize
        let center = CGPoint(feature.location * scale)
        let height = fontSize * 1.1
        let width = CGFloat(feature.id.count) * fontSize * 0.65
        if feature.footprint == nil, feature.kind == .area {
            return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
        }
        let radius = scale * MapViewConfiguration.featureMarkerDiameterRatio / 2
        let x = center.x + radius + MapViewConfiguration.featureLabelGap
        return CGRect(x: x, y: center.y - height / 2, width: width, height: height)
    }

    /// The feature's area footprint rect in screen space, or `nil` for a point feature.
    static func footprintRect(for feature: RoomFeature, scale: CGFloat) -> CGRect? {
        guard let footprint = feature.footprint else { return nil }
        return CGRect(
            x: CGFloat(footprint.origin.x) * scale,
            y: CGFloat(footprint.origin.y) * scale,
            width: CGFloat(footprint.size.width) * scale,
            height: CGFloat(footprint.size.height) * scale
        )
    }
}
