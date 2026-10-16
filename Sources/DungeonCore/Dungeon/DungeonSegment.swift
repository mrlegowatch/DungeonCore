//
//  DungeonSegment.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 3/30/15.
//  Copyright © 2015-2025 Brian Arnold. Licensed under the MIT License.
//

import Foundation


/// Maximum ratio of miter length to width before a corner is beveled instead of mitered.
///
/// A right-angle turn miters to exactly `sqrt(2) * width` (~1.41), so this is set just above
/// that: every turn sharper than a right angle (any acute interior angle) bevels, while right
/// angles and obtuse turns keep their clean miter point. A looser, general-purpose-graphics
/// limit (e.g. SVG/Cairo's default of 4) still lets moderately acute corners stretch several
/// times the hallway's width, which reads as a long spike rather than a one-cell-wide corridor.
private let hallwayMiterLimit = 1.5

/// The point where the line through `p1` in direction `d1` crosses the line through `p2` in
/// direction `d2`. The two directions must not be parallel.
private func lineIntersection(_ p1: MapPoint, _ d1: MapPoint, _ p2: MapPoint, _ d2: MapPoint) -> MapPoint {
    let diff = p2 - p1
    let denom = d1.x * d2.y - d1.y * d2.x
    let t = (diff.x * d2.y - diff.y * d2.x) / denom
    return p1 + d1 * t
}

/// Computes the edge points that form a polygon representing a hallway with the specified width.
///
/// This function takes a sequence of left-side points and generates a polygon by creating
/// a path with the right side points at a distance of the specified width. The result is suitable for
/// rendering a hallway, staircase, or corridor shape in a dungeon map.
///
/// Most corners contribute a single mitered point to the right side. A corner contributes two
/// points instead (a bevel) when mitering it would either be undefined (an exact 180-degree
/// reversal) or stretch disproportionately far from the path (an acute turn), or when its
/// computed offset would overshoot past a neighboring corner on a short segment. Because of
/// this, the result is not always exactly `segments.count * 2` long.
///
/// - Parameters:
///   - segments: An array of ``MapPoint`` values representing the left side of the hallway.
///     Must contain at least 2 points to produce a valid result.
///   - width: The offset distance from the left side to the right side of the hallway.
///
/// - Returns: An array of ``MapPoint`` values forming a polygon. The first `segments.count`
///   points are the original left side points; the rest are the offset right side points,
///   traversed in reverse. Returns an empty array if fewer than 2 segments are provided.
func computeEdges(from segments: [MapPoint], width: Double) -> [MapPoint] {
    guard segments.count >= 2 else { return [] }

    let count = segments.count

    // The offset point ending the wall of the segment before this index, and starting the
    // wall of the segment after it. These differ only where a corner is beveled or clipped below.
    var incoming = [MapPoint](repeating: MapPoint(x: 0, y: 0), count: count)
    var outgoing = [MapPoint](repeating: MapPoint(x: 0, y: 0), count: count)

    for index in 0..<count {
        let current = segments[index]

        if index == 0 {
            // First point: offset perpendicular to the first segment direction
            let direction = (segments[1] - current).normalized()
            let point = current + direction.perpendicular() * width
            incoming[index] = point
            outgoing[index] = point

        } else if index == count - 1 {
            // Last point: offset perpendicular to the last segment direction
            let direction = (current - segments[index - 1]).normalized()
            let point = current + direction.perpendicular() * width
            incoming[index] = point
            outgoing[index] = point

        } else {
            // Middle points (corners): try a miter join first, to maintain constant width.
            // Direction coming in (from i-1 to i)
            let directionIn = (current - segments[index - 1]).normalized()
            // Direction going out (from i to i+1)
            let directionOut = (segments[index + 1] - current).normalized()

            // Get perpendiculars (right-hand side)
            let perpIn = directionIn.perpendicular()
            let perpOut = directionOut.perpendicular()

            // Calculate the bisector by averaging the perpendiculars
            let bisector = (perpIn + perpOut).normalized()

            // Calculate the miter length
            // The miter length is: width / dot(bisector, perpendicular)
            // This ensures the perpendicular distance to the hallway edge is exactly 'width'
            let dotProduct = bisector.dot(perpIn)

            // A miter join is undefined at (or near) a 180-degree reversal, and its length
            // grows without bound as the turn sharpens even short of that. Past the limit,
            // bevel the corner instead: use each wall's own perpendicular endpoint rather than
            // extending both to a single, arbitrarily distant point.
            if abs(dotProduct) > 0.001 {
                let miterLength = width / dotProduct
                if abs(miterLength) <= hallwayMiterLimit * width {
                    let miterPoint = current + bisector * miterLength
                    incoming[index] = miterPoint
                    outgoing[index] = miterPoint
                    continue
                }
            }

            // Bevel: cut the corner with the two walls' own perpendicular endpoints. On a sharp
            // enough turn, that raw cut can still sit closer to the vertex than `width` itself
            // (the cut line's distance from the vertex is `width * dotProduct`, which is below
            // `width` for every corner reaching this branch) — closer than a hallway this wide
            // should ever pinch. Push the cut line outward, keeping its angle, until it's at
            // least `width` from the vertex, then re-derive the two bevel points as where that
            // line now crosses each wall's own offset line (which is where they already were).
            let rawIncoming = current + perpIn * width
            let rawOutgoing = current + perpOut * width
            let bevelDirection = (rawIncoming - rawOutgoing).normalized()
            let bevelNormal = bevelDirection.perpendicular()
            let signedDistance = (current - rawOutgoing).dot(bevelNormal)
            let shortfall = width - abs(signedDistance)

            if shortfall > 0 {
                let shiftedPoint = rawOutgoing + bevelNormal * (shortfall * (signedDistance < 0 ? 1 : -1))
                outgoing[index] = lineIntersection(shiftedPoint, bevelDirection, rawOutgoing, directionOut)
                incoming[index] = lineIntersection(shiftedPoint, bevelDirection, rawIncoming, directionIn)
            } else {
                incoming[index] = rawIncoming
                outgoing[index] = rawOutgoing
            }
        }
    }

    // A corner's join is computed from its own angle alone, independent of how long the
    // segments on either side of it are. On a short segment between two sharp corners, the
    // corners' offset points can independently overshoot past each other, collapsing or
    // inverting that segment's wall even though neither corner looked pathological by itself.
    // Detect this by checking whether the two points, projected onto the segment, are still in
    // the segment's order; if not, replace both with a single offset at the segment's midpoint.
    for index in 0..<(count - 1) {
        let start = segments[index]
        let segmentVector = segments[index + 1] - start
        let segmentLength = segmentVector.length()
        guard segmentLength > 0.0001 else { continue }
        let direction = segmentVector.normalized()

        let startOffset = (outgoing[index] - start).dot(direction)
        let endOffset = (incoming[index + 1] - start).dot(direction)

        // Use a small tolerance: two independently-computed corners can land at the same
        // projected position up to floating-point rounding, which a strict `>=` would miss.
        if startOffset >= endOffset - 0.0001 {
            let midpointOffset = start + segmentVector * 0.5 + direction.perpendicular() * width
            outgoing[index] = midpointOffset
            incoming[index + 1] = midpointOffset
        }
    }

    var result: [MapPoint] = []
    result.reserveCapacity(count * 2)

    // Add the segments representing the left side
    result.append(contentsOf: segments)

    // Build the offset path representing the right side, going backwards
    for index in stride(from: count - 1, through: 0, by: -1) {
        if outgoing[index] == incoming[index] {
            result.append(outgoing[index])
        } else {
            result.append(outgoing[index])
            result.append(incoming[index])
        }
    }

    return result
}
