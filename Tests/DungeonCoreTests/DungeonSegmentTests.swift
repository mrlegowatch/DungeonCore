//
//  DungeonSegmentTests.swift
//  DungeonCoreTests
//
//  Created by Brian Arnold on 12/1/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import Testing
import Foundation
@testable import DungeonCore

struct DungeonSegmentTests {

    // Hallway 1: Starting upward, ending leftward
    @Test func hallway1() async throws {
        let segments = [
            MapPoint(x: 5.0, y: 4.0),
            MapPoint(x: 5.0, y: 2.0),
            MapPoint(x: 3.0, y: 2.0),
            MapPoint(x: 3.0, y: 1.0),
            MapPoint(x: 2.0, y: 1.0),
        ]
        let expectedEdges = [
            MapPoint(x: 5.0, y: 4.0),
            MapPoint(x: 5.0, y: 2.0),
            MapPoint(x: 3.0, y: 2.0),
            MapPoint(x: 3.0, y: 1.0),
            MapPoint(x: 2.0, y: 1.0),
            MapPoint(x: 2.0, y: 0.0),
            MapPoint(x: 4.0, y: 0.0),
            MapPoint(x: 4.0, y: 1.0),
            MapPoint(x: 6.0, y: 1.0),
            MapPoint(x: 6.0, y: 4.0),
        ]
        
        let edges = computeEdges(from: segments, width: 1.0)
        #expect(edges.count == expectedEdges.count, "Edge count should match expected count")
        for (index, edge) in edges.enumerated() {
            #expect(edge == expectedEdges[index], "Edge at index \(index) should match expected edge")
        }
    }
    
    // Hallway 2: Starting upward, ending leftward
    @Test func hallway2() async throws {
        let segments = [
            MapPoint(x: 7.0, y: 4.0),
            MapPoint(x: 7.0, y: 1.0),
            MapPoint(x: 9.0, y: 1.0),
            MapPoint(x: 9.0, y: 0.0),
            MapPoint(x: 11.0, y: 0.0),
        ]
        let expectedEdges = [
            MapPoint(x: 7.0, y: 4.0),
            MapPoint(x: 7.0, y: 1.0),
            MapPoint(x: 9.0, y: 1.0),
            MapPoint(x: 9.0, y: 0.0),
            MapPoint(x: 11.0, y: 0.0),
            MapPoint(x: 11.0, y: 1.0),
            MapPoint(x: 10.0, y: 1.0),
            MapPoint(x: 10.0, y: 2.0),
            MapPoint(x: 8.0, y: 2.0),
            MapPoint(x: 8.0, y: 4.0),
        ]
        
        let edges = computeEdges(from: segments, width: 1.0)
        #expect(edges.count == expectedEdges.count, "Edge count should match expected count")
        for (index, edge) in edges.enumerated() {
            #expect(edge == expectedEdges[index], "Edge at index \(index) should match expected edge")
        }
    }
    
    // Hallway 3: Starting rightward, ending upward
    @Test func hallway3() async throws {
        let segments = [
            MapPoint(x: 9.0, y: 5.0),
            MapPoint(x: 11.0, y: 5.0),
            MapPoint(x: 11.0, y: 3.0),
            MapPoint(x: 12.0, y: 3.0),
            MapPoint(x: 12.0, y: 2.0),
        ]
        let expectedEdges = [
            MapPoint(x: 9.0, y: 5.0),
            MapPoint(x: 11.0, y: 5.0),
            MapPoint(x: 11.0, y: 3.0),
            MapPoint(x: 12.0, y: 3.0),
            MapPoint(x: 12.0, y: 2.0),
            MapPoint(x: 13.0, y: 2.0),
            MapPoint(x: 13.0, y: 4.0),
            MapPoint(x: 12.0, y: 4.0),
            MapPoint(x: 12.0, y: 6.0),
            MapPoint(x: 9.0, y: 6.0),
        ]
        
        let edges = computeEdges(from: segments, width: 1.0)
        #expect(edges.count == expectedEdges.count, "Edge count should match expected count")
        for (index, edge) in edges.enumerated() {
            #expect(edge == expectedEdges[index], "Edge at index \(index) should match expected edge")
        }
    }
    
    // Hallway 4: Starting rightward, ending downward
    @Test func hallway4() async throws {
        let segments = [
            MapPoint(x: 9.0, y: 7.0),
            MapPoint(x: 12.0, y: 7.0),
            MapPoint(x: 12.0, y: 9.0),
            MapPoint(x: 13.0, y: 9.0),
            MapPoint(x: 13.0, y: 11.0),
        ]
        let expectedEdges = [
            MapPoint(x: 9.0, y: 7.0),
            MapPoint(x: 12.0, y: 7.0),
            MapPoint(x: 12.0, y: 9.0),
            MapPoint(x: 13.0, y: 9.0),
            MapPoint(x: 13.0, y: 11.0),
            MapPoint(x: 12.0, y: 11.0),
            MapPoint(x: 12.0, y: 10.0),
            MapPoint(x: 11.0, y: 10.0),
            MapPoint(x: 11.0, y: 8.0),
            MapPoint(x: 9.0, y: 8.0),
        ]
        
        let edges = computeEdges(from: segments, width: 1.0)
        #expect(edges.count == expectedEdges.count, "Edge count should match expected count")
        for (index, edge) in edges.enumerated() {
            #expect(edge == expectedEdges[index], "Edge at index \(index) should match expected edge")
        }
    }
    
    // Hallway 5: Starting downward, ending rightward
    @Test func hallway5() async throws {
        let segments = [
            MapPoint(x: 8.0, y: 9.0),
            MapPoint(x: 8.0, y: 11.0),
            MapPoint(x: 10.0, y: 11.0),
            MapPoint(x: 10.0, y: 12.0),
            MapPoint(x: 11.0, y: 12.0),
        ]
        let expectedEdges = [
            MapPoint(x: 8.0, y: 9.0),
            MapPoint(x: 8.0, y: 11.0),
            MapPoint(x: 10.0, y: 11.0),
            MapPoint(x: 10.0, y: 12.0),
            MapPoint(x: 11.0, y: 12.0),
            MapPoint(x: 11.0, y: 13.0),
            MapPoint(x: 9.0, y: 13.0),
            MapPoint(x: 9.0, y: 12.0),
            MapPoint(x: 7.0, y: 12.0),
            MapPoint(x: 7.0, y: 9.0),
        ]
        
        let edges = computeEdges(from: segments, width: 1.0)
        #expect(edges.count == expectedEdges.count, "Edge count should match expected count")
        for (index, edge) in edges.enumerated() {
            #expect(edge == expectedEdges[index], "Edge at index \(index) should match expected edge")
        }
    }
    
    // Hallway 6: Starting downward, ending leftward
    @Test func hallway6() async throws {
        let segments = [
            MapPoint(x: 6.0, y: 9.0),
            MapPoint(x: 6.0, y: 12.0),
            MapPoint(x: 4.0, y: 12.0),
            MapPoint(x: 4.0, y: 13.0),
            MapPoint(x: 2.0, y: 13.0),
        ]
        let expectedEdges = [
            MapPoint(x: 6.0, y: 9.0),
            MapPoint(x: 6.0, y: 12.0),
            MapPoint(x: 4.0, y: 12.0),
            MapPoint(x: 4.0, y: 13.0),
            MapPoint(x: 2.0, y: 13.0),
            MapPoint(x: 2.0, y: 12.0),
            MapPoint(x: 3.0, y: 12.0),
            MapPoint(x: 3.0, y: 11.0),
            MapPoint(x: 5.0, y: 11.0),
            MapPoint(x: 5.0, y: 9.0),
        ]
        
        let edges = computeEdges(from: segments, width: 1.0)
        #expect(edges.count == expectedEdges.count, "Edge count should match expected count")
        for (index, edge) in edges.enumerated() {
            #expect(edge == expectedEdges[index], "Edge at index \(index) should match expected edge")
        }
    }
    
    // Hallway 7: Starting leftward, ending downward
    @Test func hallway7() async throws {
        let segments = [
            MapPoint(x: 4.0, y: 8.0),
            MapPoint(x: 2.0, y: 8.0),
            MapPoint(x: 2.0, y: 10.0),
            MapPoint(x: 1.0, y: 10.0),
            MapPoint(x: 1.0, y: 11.0),
        ]
        let expectedEdges = [
            MapPoint(x: 4.0, y: 8.0),
            MapPoint(x: 2.0, y: 8.0),
            MapPoint(x: 2.0, y: 10.0),
            MapPoint(x: 1.0, y: 10.0),
            MapPoint(x: 1.0, y: 11.0),
            MapPoint(x: 0.0, y: 11.0),
            MapPoint(x: 0.0, y: 9.0),
            MapPoint(x: 1.0, y: 9.0),
            MapPoint(x: 1.0, y: 7.0),
            MapPoint(x: 4.0, y: 7.0),
        ]
        
        let edges = computeEdges(from: segments, width: 1.0)
        #expect(edges.count == expectedEdges.count, "Edge count should match expected count")
        for (index, edge) in edges.enumerated() {
            #expect(edge == expectedEdges[index], "Edge at index \(index) should match expected edge")
        }
    }
    
    // Hallway 8: Starting leftward, ending upward
    @Test func hallway8() async throws {
        let segments = [
            MapPoint(x: 4.0, y: 6.0),
            MapPoint(x: 1.0, y: 6.0),
            MapPoint(x: 1.0, y: 4.0),
            MapPoint(x: 0.0, y: 4.0),
            MapPoint(x: 0.0, y: 2.0),
        ]
        let expectedEdges = [
            MapPoint(x: 4.0, y: 6.0),
            MapPoint(x: 1.0, y: 6.0),
            MapPoint(x: 1.0, y: 4.0),
            MapPoint(x: 0.0, y: 4.0),
            MapPoint(x: 0.0, y: 2.0),
            MapPoint(x: 1.0, y: 2.0),
            MapPoint(x: 1.0, y: 3.0),
            MapPoint(x: 2.0, y: 3.0),
            MapPoint(x: 2.0, y: 5.0),
            MapPoint(x: 4.0, y: 5.0),
        ]
        
        let edges = computeEdges(from: segments, width: 1.0)
        #expect(edges.count == expectedEdges.count, "Edge count should match expected count")
        for (index, edge) in edges.enumerated() {
            #expect(edge == expectedEdges[index], "Edge at index \(index) should match expected edge")
        }
    }

    @Test func diagonalHallway1() async throws {
        let segments = [
            MapPoint(x: 10.0, y: 9.0),
            MapPoint(x: 10.0, y: 8.0),
            MapPoint(x: 8.0, y: 6.0),
            MapPoint(x: 8.0, y: 3.0),
            MapPoint(x: 11.0, y: 3.0),
            MapPoint(x: 11.0, y: 5.0),
        ]
        
        // Calculate expected Y values for the diagonal turn points:
        // At index 2 (8.0, 6.0): diagonal turn from (-√2/2, -√2/2) to (0, -1)
        // perpIn = (√2/2, -√2/2), perpOut = (1, 0)
        // bisector = (√2/2 + 1, -√2/2) normalized
        // After calculation: Y ≈ 6.0 - 0.4142135623730951 (which is 6 - (√2 - 1))
        let sqrt2 = sqrt(2.0)
        let diagonalOffsetY = sqrt2 - 1.0  // ≈ 0.4142135623730951
        
        // At index 1 (10.0, 8.0): straight to diagonal turn
        // perpIn = (1, 0), perpOut = (√2/2, -√2/2)
        // bisector = (√2/2 + 1, -√2/2) normalized
        // After calculation: Y ≈ 8.0 + 0.4142135623730951
        
        let expectedEdges = [
            MapPoint(x: 10.0, y: 9.0),
            MapPoint(x: 10.0, y: 8.0),
            MapPoint(x: 8.0, y: 6.0),
            MapPoint(x: 8.0, y: 3.0),
            MapPoint(x: 11.0, y: 3.0),
            MapPoint(x: 11.0, y: 5.0),
            MapPoint(x: 10.0, y: 5.0),
            MapPoint(x: 10.0, y: 4.0),
            MapPoint(x: 9.0, y: 4.0),
            MapPoint(x: 9.0, y: 6.0 - diagonalOffsetY),
            MapPoint(x: 11.0, y: 8.0 - diagonalOffsetY),
            MapPoint(x: 11.0, y: 9.0),
        ]
        
        let edges = computeEdges(from: segments, width: 1.0)
        #expect(edges.count == expectedEdges.count, "Edge count should match expected count")
        for (index, edge) in edges.enumerated() {
            #expect(abs(edge.x - expectedEdges[index].x) < 0.0001, "Edge X at index \(index) should match expected edge")
            #expect(abs(edge.y - expectedEdges[index].y) < 0.0001, "Edge Y at index \(index) should match expected edge")
        }
    }

    // Acute corner (interior angle ~20.6 degrees) in isolation: the plain miter formula would
    // place this point 5.6x the width away from the vertex. It should bevel instead, with the
    // bevel cut itself exactly `width` from the vertex (not wherever the raw perpendiculars from
    // each wall happen to land, which can be much closer than `width`).
    @Test func acuteCornerBevelsWithinMiterLimit() async throws {
        let segments = [
            MapPoint(x: 7.0, y: 4.0),
            MapPoint(x: 7.0, y: 1.0),
            MapPoint(x: 10.0, y: 9.0),
            MapPoint(x: 10.0, y: 12.0),
            MapPoint(x: 12.0, y: 12.0),
            MapPoint(x: 12.0, y: 9.0),
        ]

        let edges = computeEdges(from: segments, width: 1.0)
        // One extra point versus the usual segments.count * 2, from the single beveled corner.
        #expect(edges.count == segments.count * 2 + 1, "Beveling the acute corner should add exactly one point")

        let vertex = MapPoint(x: 7.0, y: 1.0)
        let outgoingBevelPoint = edges[10]
        let incomingBevelPoint = edges[11]

        // The bevel cut line (not each endpoint) should be exactly `width` from the vertex.
        let bevelNormal = (incomingBevelPoint - outgoingBevelPoint).normalized().perpendicular()
        let bevelLineDistance = abs((vertex - outgoingBevelPoint).dot(bevelNormal))
        #expect(abs(bevelLineDistance - 1.0) < 0.0001, "Bevel cut should be widened to exactly `width` from the vertex")

        // Still bounded close to the vertex, nowhere near the old unbounded miter's ~5.6 units.
        #expect((outgoingBevelPoint - vertex).length() < 2.0, "Bevel point should stay close to the vertex")
        #expect((incomingBevelPoint - vertex).length() < 2.0, "Bevel point should stay close to the vertex")
    }

    // Exact 180-degree reversal: the degenerate-dot-product fallback used to collapse both wall
    // points onto the vertex itself (zero width). It should bevel instead, with the cut widened
    // to exactly `width` from the vertex and the two points distinct from each other.
    @Test func exactReversalBevelsInsteadOfPinching() async throws {
        let segments = [
            MapPoint(x: 9.0, y: 5.0),
            MapPoint(x: 12.0, y: 5.0),
            MapPoint(x: 10.0, y: 5.0),
            MapPoint(x: 10.0, y: 2.0),
        ]
        let expectedEdges = [
            MapPoint(x: 9.0, y: 5.0),
            MapPoint(x: 12.0, y: 5.0),
            MapPoint(x: 10.0, y: 5.0),
            MapPoint(x: 10.0, y: 2.0),
            MapPoint(x: 11.0, y: 2.0),
            MapPoint(x: 11.0, y: 4.0),
            MapPoint(x: 13.0, y: 4.0),
            MapPoint(x: 13.0, y: 6.0),
            MapPoint(x: 9.0, y: 6.0),
        ]

        let edges = computeEdges(from: segments, width: 1.0)
        #expect(edges.count == expectedEdges.count, "Edge count should match expected count")
        for (index, edge) in edges.enumerated() {
            #expect(edge == expectedEdges[index], "Edge at index \(index) should match expected edge")
        }

        let vertex = MapPoint(x: 12.0, y: 5.0)
        #expect(abs(edges[6].x - vertex.x) == 1.0, "Bevel cut should be widened to exactly `width` from the vertex, not pinched to zero")
        #expect(edges[6] != edges[7], "The two bevel points should be distinct, giving the corner a nonzero opening")
    }

    // Acute corner (interior 45 degrees) immediately followed by a short stub segment: on-device
    // rendering showed this still looked like a long spike, because the miter limit alone only
    // bevels turns sharper than ~80 degrees of overshoot ratio, not every acute angle. The corner
    // should now bevel directly, with the cut widened to exactly `width` from the vertex, while
    // the short stub's own (unrelated, obtuse) corner stays a clean, untouched miter.
    @Test func acuteCornerOnShortSegmentBevelsCleanly() async throws {
        let segments = [
            MapPoint(x: 5.0, y: 4.0),
            MapPoint(x: 5.0, y: 1.0),
            MapPoint(x: 7.0, y: 3.0),
            MapPoint(x: 7.0, y: 3.5),
        ]

        let sqrt2 = sqrt(2.0)
        let farMiterPoint = MapPoint(x: 6.0, y: 2.0 + sqrt2) // unaffected obtuse (135 degree) corner
        let bevelPointA = MapPoint(x: 4.765366864730179, y: 2.1795804271032746)
        let bevelPointB = MapPoint(x: 6.0, y: 1.6681786379192989)

        let expectedEdges = [
            MapPoint(x: 5.0, y: 4.0),
            MapPoint(x: 5.0, y: 1.0),
            MapPoint(x: 7.0, y: 3.0),
            MapPoint(x: 7.0, y: 3.5),
            MapPoint(x: 6.0, y: 3.5),
            farMiterPoint,
            bevelPointA,
            bevelPointB,
            MapPoint(x: 6.0, y: 4.0),
        ]

        let edges = computeEdges(from: segments, width: 1.0)
        #expect(edges.count == expectedEdges.count, "Edge count should match expected count")
        for (index, edge) in edges.enumerated() {
            #expect(abs(edge.x - expectedEdges[index].x) < 0.0001, "Edge X at index \(index) should match expected edge")
            #expect(abs(edge.y - expectedEdges[index].y) < 0.0001, "Edge Y at index \(index) should match expected edge")
        }

        // The bevel cut line should be exactly `width` from the vertex.
        let vertex = MapPoint(x: 5.0, y: 1.0)
        let bevelNormal = (bevelPointB - bevelPointA).normalized().perpendicular()
        let bevelLineDistance = abs((vertex - bevelPointA).dot(bevelNormal))
        #expect(abs(bevelLineDistance - 1.0) < 0.0001, "Bevel cut should be widened to exactly `width` from the vertex")
    }

    // Two obtuse corners (135 degrees each, individually well under the miter limit) joined by a
    // short segment: neither corner looks pathological alone, but their independently-computed
    // miter points still overshoot past each other on the short connecting segment. The
    // shared-midpoint clip should unify them into a single, deliberate point instead of leaving
    // the wall crossed or duplicated by coincidence.
    @Test func obtuseCornersOnShortSegmentClipToSharedMidpoint() async throws {
        let sqrt2 = sqrt(2.0)
        let segments = [
            MapPoint(x: 5.0, y: 4.0),
            MapPoint(x: 5.0, y: 1.0),
            MapPoint(x: 5.0 + sqrt2 / 4.0, y: 1.0 - sqrt2 / 4.0),
            MapPoint(x: 8.0 + sqrt2 / 4.0, y: 1.0 - sqrt2 / 4.0),
        ]

        let edges = computeEdges(from: segments, width: 1.0)
        // Both corners end up split (clipped on the shared side, untouched on the far side).
        #expect(edges.count == segments.count * 2 + 2, "Both corners should be split by the clip")

        let farMiterA = MapPoint(x: 6.0, y: sqrt2) // corner 1's untouched far side
        let farMiterB = MapPoint(x: 4.0 + 5.0 * sqrt2 / 4.0, y: 2.0 - sqrt2 / 4.0) // corner 2's untouched far side
        #expect(abs(edges[8].x - farMiterA.x) < 0.0001 && abs(edges[8].y - farMiterA.y) < 0.0001, "Corner 1's far side should be unaffected")
        #expect(abs(edges[5].x - farMiterB.x) < 0.0001 && abs(edges[5].y - farMiterB.y) < 0.0001, "Corner 2's far side should be unaffected")

        // The shared short segment's two ends should have been unified into the same point.
        #expect(edges[6] == edges[7], "The clip should unify both corners' contribution to the shared segment")
    }
}
