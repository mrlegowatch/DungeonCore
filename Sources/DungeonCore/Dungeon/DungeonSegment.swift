//
//  DungeonSegment.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 3/30/15.
//  Copyright © 2015-2025 Brian Arnold. Licensed under the MIT License.
//

import Foundation


/// Computes the edge points that form a polygon representing a hallway with the specified width.
///
/// This function takes a sequence of left-side points and generates a polygon by creating
/// a path with the right side points at a distance of the specified width. The result is suitable for
/// rendering a hallway, staircase, or corridor shape in a dungeon map.
///
/// - Parameters:
///   - segments: An array of ``MapPoint`` values representing the left side of the hallway.
///     Must contain at least 2 points to produce a valid result.
///   - width: The offset distance from the left side to the right side of the hallway.
///
/// - Returns: An array of ``MapPoint`` values forming a polygon. The first half of the
///   array contains the original left side points, and the second half contains the offset right side
///   points in reverse order. Returns an empty array if fewer than 2 segments are provided.
func computeEdges(from segments: [MapPoint], width: Double) -> [MapPoint] {
    guard segments.count >= 2 else { return [] }
    
    let count = segments.count
    var result: [MapPoint] = []
    result.reserveCapacity(count * 2)
    
    // Add the segments representing the left side
    result.append(contentsOf: segments)
    
    // Build the offset path representing the right side, going backwards
    for index in stride(from: count - 1, through: 0, by: -1) {
        let current = segments[index]
        
        if index == count - 1 {
            // Last point: offset perpendicular to the last segment direction
            let direction = (current - segments[index - 1]).normalized()
            let perpendicular = direction.perpendicular()
            result.append(current + perpendicular * width)
            
        } else if index == 0 {
            // First point: offset perpendicular to the first segment direction
            let direction = (segments[1] - current).normalized()
            let perpendicular = direction.perpendicular()
            result.append(current + perpendicular * width)
            
        } else {
            // Middle points (corners): use miter join to maintain constant width
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
            
            // Avoid division by zero or near-zero (would indicate a 180-degree turn)
            guard abs(dotProduct) > 0.001 else {
                // Fallback for extreme cases: just use the average
                result.append(current + (perpIn + perpOut) * width)
                continue
            }
            
            let miterLength = width / dotProduct
            result.append(current + bisector * miterLength)
        }
    }
    
    return result
}
