//
//  LabelPlacement.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 10/6/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import CoreGraphics

/// Pure corner-placement logic for an automatic room label, entirely in map units
/// (independent of on-screen scale or font metrics), so it can be unit-tested without a
/// live view.
enum LabelPlacement {
    /// The chosen label rectangle for a room's number or name.
    ///
    /// Ellipse rooms get a single candidate: centered horizontally on the room, with the
    /// label's top edge at `inset.height` below the top of the bounding box. No fallback —
    /// `obstacles` and `contains` are ignored.
    ///
    /// Every other room (rectangles included) anchors candidates at the room's own outline
    /// vertices in `edges`, so a candidate always starts on the room — never at a
    /// bounding-box corner that may sit outside a non-rectangular shape. Candidates are
    /// tried in this order: the vertices with the minimum y, in `edges` order, then the
    /// vertices with the maximum y, in `edges` order. For a minimum-y vertex, the label is
    /// tried below-right (its top-left corner at the vertex plus `inset`), then below-left
    /// (its top-right corner at the vertex, minus `inset` horizontally). For a maximum-y
    /// vertex, the label is tried above-right, then above-left. A candidate whose center
    /// fails `contains` is discarded. The first remaining candidate that intersects none of
    /// `obstacles` wins; if every remaining candidate collides, the first remaining one is
    /// used; if nothing remains (every candidate's center failed `contains`), the first
    /// minimum-y vertex's below-right candidate is used regardless.
    ///
    /// - Parameters:
    ///   - isEllipse: Whether the room is an ellipse (see above).
    ///   - boundingBox: The room's bounding box, in map units.
    ///   - edges: The room's own outline vertices, in map units, in order. Ignored for an
    ///     ellipse room.
    ///   - labelSize: The label's measured size, in map units.
    ///   - inset: How far below/beside a vertex (or the bounding box, for an ellipse) the
    ///     label sits, in map units.
    ///   - obstacles: Obstacle rectangles (point markers, marker labels, area footprints)
    ///     to avoid, in map units.
    ///   - contains: Whether a given point (a candidate's center) falls inside the room's
    ///     shape. Defaults to always `true`.
    static func automaticLabelRect(
        isEllipse: Bool,
        boundingBox: CGRect,
        edges: [CGPoint],
        labelSize: CGSize,
        inset: CGSize,
        obstacles: [CGRect],
        contains: (CGPoint) -> Bool = { _ in true }
    ) -> CGRect {
        if isEllipse {
            return CGRect(
                x: boundingBox.midX - labelSize.width / 2,
                y: boundingBox.minY + inset.height,
                width: labelSize.width,
                height: labelSize.height
            )
        }

        func rect(at vertex: CGPoint, below: Bool, right: Bool) -> CGRect {
            let y = below ? vertex.y + inset.height : vertex.y - inset.height - labelSize.height
            let x = right ? vertex.x + inset.width : vertex.x - inset.width - labelSize.width
            return CGRect(x: x, y: y, width: labelSize.width, height: labelSize.height)
        }

        guard !edges.isEmpty else {
            return rect(at: CGPoint(x: boundingBox.minX, y: boundingBox.minY), below: true, right: true)
        }

        let minY = edges.map(\.y).min()!
        let maxY = edges.map(\.y).max()!
        let minYVertices = edges.filter { $0.y == minY }
        let maxYVertices = edges.filter { $0.y == maxY }

        var candidates: [CGRect] = []
        for vertex in minYVertices {
            candidates.append(rect(at: vertex, below: true, right: true))
            candidates.append(rect(at: vertex, below: true, right: false))
        }
        for vertex in maxYVertices {
            candidates.append(rect(at: vertex, below: false, right: true))
            candidates.append(rect(at: vertex, below: false, right: false))
        }

        let remaining = candidates.filter { contains(CGPoint(x: $0.midX, y: $0.midY)) }
        guard let first = remaining.first else {
            return rect(at: minYVertices[0], below: true, right: true)
        }
        for candidate in remaining where !obstacles.contains(where: { $0.intersects(candidate) }) {
            return candidate
        }
        return first
    }
}
