//
//  WallRuns.swift
//  DungeonCore
//
//  Created by Brian Arnold on 8/20/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import Foundation

extension DungeonMap {

    /// The parts of a room's outline that are wall, after removing the spans its doors
    /// occupy. Each run is a polyline of two or more points. A room with no gaps returns
    /// one closed run (first point repeated at the end).
    ///
    /// Works on `room.edges`, so it applies uniformly to rooms and hallways. An ellipse
    /// room returns the single closed run of its generated edges, uncut — cutting an arc
    /// for a door is out of scope here (see `TiledRoomShape` in the app).
    ///
    /// A door cuts an edge only where its span lies on that edge: collinear within `1e-6`
    /// and overlapping by more than `1e-6`. The span is clipped to the edge before cutting.
    public func wallRuns(for room: DungeonRoom, doorGapRatio: Double) -> [[MapPoint]] {
        let edges = room.edges
        let n = edges.count
        guard n >= 2 else { return [] }

        if room.shape == .ellipse {
            return [edges + [edges[0]]]
        }

        struct Cut {
            var edgeIndex: Int
            var t0: Double
            var t1: Double
        }
        var cuts: [Cut] = []

        // Finds every edge the span (p, q) is collinear with and overlaps, clips the span
        // to each such edge, and records the clipped cut.
        func addCut(_ p: MapPoint, _ q: MapPoint) {
            guard (q - p).length() > 1e-6 else { return }
            for i in 0..<n {
                let a = edges[i]
                let b = edges[(i + 1) % n]
                let d = b - a
                let lengthSquared = d.dot(d)
                guard lengthSquared > 1e-12 else { continue }
                let length = lengthSquared.squareRoot()

                // Collinearity: the cross product magnitude, normalized by edge length,
                // is the perpendicular distance from each point to the edge's line.
                let crossP = (p - a).x * d.y - (p - a).y * d.x
                let crossQ = (q - a).x * d.y - (q - a).y * d.x
                guard abs(crossP) / length < 1e-6, abs(crossQ) / length < 1e-6 else { continue }

                let tP = (p - a).dot(d) / lengthSquared
                let tQ = (q - a).dot(d) / lengthSquared
                let t0 = max(0, min(tP, tQ))
                let t1 = min(1, max(tP, tQ))
                guard (t1 - t0) * length > 1e-6 else { continue }
                cuts.append(Cut(edgeIndex: i, t0: t0, t1: t1))
            }
        }

        for door in doors {
            guard !door.hasAttribute(.isSecret) else { continue }
            switch door.kind {
            case .opening:
                addCut(door.leftEdge, door.rightEdge)

            case .door, .portcullis, .slidingDoor, .ladder, .magicPortal, .caveEntrance:
                let full = door.rightEdge - door.leftEdge
                let mid = door.leftEdge + full * 0.5
                let half = full * (doorGapRatio / 2)
                addCut(mid - half, mid + half)

            case .staircase, .passage:
                guard let segments = door.segments, segments.count >= 2 else { continue }
                let width = door.doorWidth
                let startDirection = (segments[1] - segments[0]).normalized()
                addCut(segments[0], segments[0] + startDirection.perpendicular() * width)
                let endDirection = (segments[segments.count - 1] - segments[segments.count - 2]).normalized()
                addCut(segments[segments.count - 1], segments[segments.count - 1] + endDirection.perpendicular() * width)

            case .trapDoor, .elevator:
                continue
            }
        }

        guard !cuts.isEmpty else {
            return [edges + [edges[0]]]
        }

        // Merge cuts (expressed in global "edge index + fraction" units) into a sorted,
        // non-overlapping list, then take the complement within [0, n) for the kept pieces.
        let sortedCuts = cuts
            .map { (Double($0.edgeIndex) + $0.t0, Double($0.edgeIndex) + $0.t1) }
            .sorted { $0.0 < $1.0 }
        var mergedCuts: [(Double, Double)] = []
        for (start, end) in sortedCuts {
            if let last = mergedCuts.last, start <= last.1 + 1e-9 {
                mergedCuts[mergedCuts.count - 1].1 = max(last.1, end)
            } else {
                mergedCuts.append((start, end))
            }
        }

        var kept: [(Double, Double)] = []
        var cursor = 0.0
        for (start, end) in mergedCuts {
            if start - cursor > 1e-9 { kept.append((cursor, start)) }
            cursor = max(cursor, end)
        }
        if Double(n) - cursor > 1e-9 { kept.append((cursor, Double(n))) }
        guard !kept.isEmpty else { return [] }

        // A kept piece touching both seams (param 0 and param n) wraps around the polygon's
        // start point into one run with the piece at the opposite seam.
        if kept.count > 1,
           kept[0].0 <= 1e-9,
           kept[kept.count - 1].1 >= Double(n) - 1e-9 {
            let first = kept.removeFirst()
            let last = kept.removeLast()
            kept.append((last.0, first.1 + Double(n)))
        }

        func point(at t: Double) -> MapPoint {
            let nd = Double(n)
            var tt = t.truncatingRemainder(dividingBy: nd)
            if tt < 0 { tt += nd }
            let i = Int(tt)
            let frac = tt - Double(i)
            let a = edges[i % n]
            guard frac > 1e-9 else { return a }
            let b = edges[(i + 1) % n]
            return a + (b - a) * frac
        }

        func polyline(from a: Double, to b: Double) -> [MapPoint] {
            var points: [MapPoint] = [point(at: a)]
            var k = Int(floor(a + 1e-9)) + 1
            while Double(k) < b - 1e-9 {
                points.append(edges[k % n])
                k += 1
            }
            points.append(point(at: b))
            return points
        }

        return kept.compactMap { (a, b) in
            guard b - a > 1e-9 else { return nil }
            return polyline(from: a, to: b)
        }
    }
}
