//
//  DungeonHallway.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 3/29/15.
//  Copyright © 2015-2025 Brian Arnold. Licensed under the MIT License.
//

import Foundation

struct HallwayData: Codable {
    let segments: [MapPoint]?
    let width: Double?
    let edges: [MapPoint]?
    let name: String?

    init(_ hallway: DungeonHallway) {
        if let segs = hallway.segments {
            segments = segs
            width = hallway.width
            edges = nil
        } else {
            segments = nil
            width = nil
            edges = hallway.edges
        }
        name = hallway.name
    }
}

/// A hallway within a dungeon map, defined by path segments and width or explicit edge points.
///
/// `DungeonHallway` is a subclass of ``DungeonRoom`` that represents corridor-style
/// passages connecting rooms. Hallways can be defined either by a series of path segments
/// with a uniform width, or by explicit edge points for custom shapes.
///
/// When initialized with segments and width, the hallway automatically computes its
/// boundary edges by offsetting the path segments perpendicular to the direction of travel.
///
/// ## Creating a Hallway
///
/// You can create a hallway in several ways:
///
/// ```swift
/// // From path segments with a width (edges computed automatically)
/// let hallway = DungeonHallway(segments: [
///     MapPoint(x: 5.0, y: 4.0),
///     MapPoint(x: 5.0, y: 2.0),
///     MapPoint(x: 3.0, y: 2.0)
/// ], width: 1.0)
///
/// // From explicit edge points
/// let hallway = DungeonHallway(edges: [MapPoint(x: 0, y: 0), MapPoint(x: 10, y: 0), ...])
///
/// // From decoded hallway data
/// if let hallway = DungeonHallway(hallwayData: decodedData) {
///     // Use hallway
/// }
/// ```
///
/// ## Properties
///
/// - ``segments``: The left side path points defining the hallway's route, or `nil` if edges were specified directly.
/// - ``width``: The width of the hallway perpendicular to its path, or `nil` if not applicable. Used with segments.
/// - ``edges``: An array of points defining the hallway's boundary vertices (inherited from ``DungeonRoom``).
/// - ``location``: The origin point of the hallway's bounding box (inherited from ``DungeonRoom``).
/// - ``size``: The dimensions of the hallway's bounding box (inherited from ``DungeonRoom``).
public class DungeonHallway: DungeonRoom {
    public var segments: [MapPoint]?
    public let width: Double?
    
    /// Creates a hallway from a series of path segments with a specified width.
    ///
    /// The hallway's boundary edges are automatically computed by offsetting the path segments
    /// perpendicular to the direction of travel. This creates a corridor that follows the
    /// path defined by the segments.
    ///
    /// - Parameters:
    ///   - segments: An array of ``MapPoint`` values defining the left side path of the hallway.
    ///     The hallway will follow this path, with corners at each point.
    ///   - width: The width of the hallway perpendicular to its path. Defaults to `1.0`.
    ///     The total width is applied to the right side of the segments in the direction of the path.
    ///   - name: An optional name for the hallway. Defaults to `nil`.
    public init(segments: [MapPoint], width: Double = 1.0, name: String? = nil) {
        self.segments = segments
        self.width = width
        let edges = computeEdges(from: segments, width: width)
        super.init(edges: edges, name: name)
    }
    
    /// Creates a hallway from explicit edge points.
    ///
    /// Use this initializer when you have pre-computed boundary points for the hallway
    /// rather than path segments. This allows for custom hallway shapes that may not
    /// follow a simple path-with-width pattern.
    ///
    /// - Parameters:
    ///   - edges: An array of ``MapPoint`` values defining the hallway's boundary vertices.
    ///     These points form a polygon representing the hallway's shape.
    ///   - width: An optional width value for the hallway. Defaults to `nil`.
    ///     This is stored for reference but not used in edge computation since
    ///     edges are provided directly.
    ///   - name: An optional name for the hallway. Defaults to `nil`.
    public init(edges: [MapPoint], width: Double? = nil, name: String? = nil) {
        self.segments = nil
        self.width = width
        super.init(edges: edges, name: name)
    }
    
    /// Creates a hallway from decoded hallway data.
    ///
    /// This convenience initializer supports flexible hallway creation from serialized data.
    /// It first attempts to use explicit edge points if available, falling back to
    /// segment-based construction with an optional width.
    ///
    /// - Parameter hallwayData: A ``HallwayData`` instance containing the hallway's
    ///   configuration. Must contain either `edges` or `segments` to succeed.
    ///
    /// - Returns: A new ``DungeonHallway`` instance, or `nil` if `hallwayData`
    ///   contains neither `edges` nor `segments`.
    ///
    /// The initialization priority is:
    /// 1. If `edges` is present, creates the hallway using ``init(edges:width:)``.
    /// 2. Otherwise, if `segments` is present, creates the hallway using
    ///    ``init(segments:width:)`` with the provided width or a default of `1.0`.
    /// 3. Returns `nil` if neither property is available.
    public override func translate(by delta: MapPoint) {
        super.translate(by: delta)
        segments = segments?.map { $0 + delta }
    }

    convenience init?(hallwayData: HallwayData) {
        if let edges = hallwayData.edges {
            self.init(edges: edges, name: hallwayData.name)
        } else if let segments = hallwayData.segments {
            let width = hallwayData.width ?? 1.0
            self.init(segments: segments, width: width, name: hallwayData.name)
        } else {
            return nil
        }
    }
}
