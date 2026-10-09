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
}
