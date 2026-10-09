//
//  DungeonDoor.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 3/29/15.
//  Copyright © 2015-2025 Brian Arnold. Licensed under the MIT License.
//

import Foundation

public struct RemoteConnection: Codable {
    let mapID: String
    let end: MapPoint
}

struct DoorData: Codable {
    let kind: String?

    // For simple doors
    let leftEdge: MapPoint?
    let rightEdge: MapPoint?
    let width: Double?
    let rotation: Double?
    let attributes: Set<DungeonDoor.Attribute>?

    // For path-based doors (staircase, passage)
    let segments: [MapPoint]?
    let edges: [MapPoint]?

    // For rectangular doors (trapDoor, elevator)
    let location: MapPoint?
    let size: MapSize?

    // For exits
    let connection: RemoteConnection?

    // Optional name
    let name: String?

    // Optional key that opens this door, when gated
    let keyID: String?

    // Meaningful only for staircase and ladder: travel from the first segment point
    // to the last goes up, or down.
    let stairDirection: DungeonDoor.StairDirection?

    var doorAttributes: Set<DungeonDoor.Attribute> {
        return attributes ?? []
    }

    var doorRotationRadians: Double {
        guard let rotation = rotation else { return 0.0 }
        return rotation * Double.pi / 180.0
    }

    var doorWidth: Double {
        return width ?? 1.0
    }

    init(_ door: DungeonDoor) {
        kind = door.kind.rawValue
        name = door.name
        attributes = door.attributes.isEmpty ? nil : door.attributes
        connection = door.connection
        keyID = door.keyID
        stairDirection = door.stairDirection

        let degrees = door.rotation * 180.0 / .pi
        rotation = abs(degrees) < 1e-10 ? nil : degrees

        switch door.kind {
        case .opening, .door, .portcullis, .slidingDoor, .ladder, .magicPortal, .caveEntrance:
            leftEdge = door.leftEdge
            rightEdge = door.rightEdge
            width = door.doorWidth == 1.0 ? nil : door.doorWidth
            segments = nil
            edges = nil
            location = nil
            size = nil

        case .trapDoor, .elevator:
            location = door.location
            size = door.size
            leftEdge = door.leftEdge
            rightEdge = door.rightEdge
            width = door.doorWidth == 1.0 ? nil : door.doorWidth
            segments = nil
            edges = nil

        case .staircase, .passage:
            if let segs = door.segments {
                segments = segs
                edges = nil
            } else {
                segments = nil
                edges = door.edges
            }
            leftEdge = nil
            rightEdge = nil
            width = door.doorWidth == 1.0 ? nil : door.doorWidth
            location = nil
            size = nil
        }
    }
}

/// A door or passage element within a dungeon map.
///
/// `DungeonDoor` represents various types of connections between rooms or areas in a dungeon,
/// ranging from simple doors to complex passages and staircases. Doors can be defined in multiple ways
/// depending on their type:
///
/// - Simple doors (opening, door, portcullis, slidingDoor, ladder): Defined by two edge points (leftEdge and rightEdge)
/// - Area-based doors (trapDoor, elevator): Defined by a rectangular area
/// - Path-based doors (staircase, passage): Defined by segments or edges, similar to hallways
/// - Special doors (magicPortal): Support remote connections to other maps
///
/// ## Door Types
///
/// The ``Kind`` enum defines the following door types:
/// - `opening`: An open doorway with no physical door
/// - `door`: A standard hinged door
/// - `portcullis`: A heavy vertical gate
/// - `slidingDoor`: A horizontally or vertically sliding door
/// - `ladder`: A vertical climbing element
/// - `trapDoor`: A floor or ceiling hatch (1x1 or larger square)
/// - `elevator`: A vertical transport platform (typically 2x2)
/// - `staircase`: A set of stairs connecting different levels
/// - `passage`: A corridor-like connection between rooms
/// - `magicPortal`: A magical transport mechanism
///
/// ## Properties
///
/// Door-specific properties:
/// - ``leftEdge``: The left edge point of the door (for simple door types)
/// - ``rightEdge``: The right edge point of the door (for simple door types)
/// - ``fromArea``: Computed polygon representing the area "behind" the door
/// - ``toArea``: Computed polygon representing the area "in front" of the door
/// - ``doorWidth``: The width of the door
/// - ``hitTest(_:)``: Whether a point falls on the door, its `fromArea`, or its `toArea`
///
/// In addition, `DungeonDoor` inherits the following from ``DungeonRoom``:
/// - ``DungeonRoom/edges``: The boundary vertices (computed from segments for path-based doors)
/// - ``DungeonRoom/location``: The origin point of the door's bounding box (used for area-based doors)
/// - ``DungeonRoom/size``: The dimensions of the door's bounding box (used for area-based doors)
/// - ``DungeonRoom/rotation``: The rotation angle in radians
///
/// ## Creating Doors
///
/// Doors are typically created from JSON data via the `DoorData` structure:
///
/// ```swift
/// // Simple door between two edge points
/// let doorData = DoorData(start: MapPoint(x: 5, y: 4), end: MapPoint(x: 5, y: 3), kind: "door")
///
/// // Staircase with segments
/// let stairData = DoorData(kind: "staircase", width: 1.0, segments: [MapPoint(...), MapPoint(...)])
///
/// // Create the door
/// if let door = DungeonDoor(doorData: doorData) {
///     // Use door
/// }
/// ```
public class DungeonDoor: DungeonRoom {
 
    public enum Kind: String, CaseIterable {
        case opening
        case door
        case portcullis
        case slidingDoor
        case ladder
        case trapDoor
        case elevator
        case staircase
        case passage
        case magicPortal
        case caveEntrance
       
        init(from kind: String?) {
            if let kind {
                self = .init(rawValue: kind) ?? .door
            } else {
                self = .door
            }
        }
    }
    public var kind: Kind
    
    public enum Attribute: String, Codable, CaseIterable, Sendable {
        case isLocked, hasTrap, isSecret, isOneWay, isStuck, isBarred, hasMagicSeal
    }
    
    public var attributes: Set<Attribute> = []

    public func hasAttribute(_ attribute: Attribute) -> Bool {
        return attributes.contains(attribute)
    }
    
    public var leftEdge: MapPoint
    public var rightEdge: MapPoint
    public var doorWidth: Double
    
    /// The center-line path segments for path-based doors (staircase, passage).
    ///
    /// When a door is created from segments, this property stores the original path points
    /// while the inherited ``DungeonRoom/edges`` property stores the computed boundary edges.
    /// This is `nil` for doors defined by explicit edges or two-point connections.
    public var segments: [MapPoint]?

    public var connection: RemoteConnection?

    /// The key that opens this door, when gated. `nil` means no key exists for this door,
    /// even when it is locked, barred, or magically sealed.
    public var keyID: String?

    /// Which way travel goes along a path-based door, from its first segment point to its last.
    public enum StairDirection: String, Codable, Sendable {
        case up, down
    }

    /// Meaningful only for `staircase` and `ladder` kinds: travelling from the first
    /// segment point to the last goes up, or down. `nil` when not applicable or unknown.
    public var stairDirection: StairDirection?

    /// Returns an array of MapPoint representing the polygon area "behind" the door (relative to leftEdge and rightEdge).
    ///
    /// For simple door types (opening, door, portcullis, slidingDoor, ladder), this computes a polygon
    /// by adding two edges perpendicular to the door, extending one grid unit in the direction "behind"
    /// the door (to the left when facing from leftEdge to rightEdge).
    public var fromArea: [MapPoint] {
        // Calculate direction vector from leftEdge to rightEdge
        let doorVector = rightEdge - leftEdge
        
        // Calculate perpendicular vector (pointing "behind" - to the left of the door direction)
        // Using left-hand perpendicular: rotate 90° counterclockwise
        let perpendicular = MapPoint(x: -doorVector.y, y: doorVector.x).normalized()
        
        // Extend one grid unit behind the door
        let depth = 1.0
        let backLeft = leftEdge + (perpendicular * depth)
        let backRight = rightEdge + (perpendicular * depth)
        
        // Return polygon: leftEdge -> rightEdge -> backRight -> backLeft
        return [leftEdge, rightEdge, backRight, backLeft]
    }
    
    /// Returns an array of MapPoint representing the polygon area "in front of" the door (relative to leftEdge and rightEdge).
    ///
    /// For simple door types (opening, door, portcullis, slidingDoor, ladder), this computes a polygon
    /// by adding two edges perpendicular to the door, extending one grid unit in the direction "in front"
    /// of the door (to the right when facing from leftEdge to rightEdge).
    public var toArea: [MapPoint] {
        // Calculate direction vector from leftEdge to rightEdge
        let doorVector = rightEdge - leftEdge
        
        // Calculate perpendicular vector (pointing "in front" - to the right of the door direction)
        // Using right-hand perpendicular: rotate 90° clockwise
        let perpendicular = MapPoint(x: doorVector.y, y: -doorVector.x).normalized()
        
        // Extend one grid unit in front of the door
        let depth = 1.0
        let frontLeft = leftEdge + (perpendicular * depth)
        let frontRight = rightEdge + (perpendicular * depth)
        
        // Return polygon: leftEdge -> rightEdge -> frontRight -> frontLeft
        return [leftEdge, rightEdge, frontRight, frontLeft]
    }
    
    public override func translate(by delta: MapPoint) {
        super.translate(by: delta)
        leftEdge = leftEdge + delta
        rightEdge = rightEdge + delta
        segments = segments?.map { $0 + delta }
    }

    /// Returns true if `point` falls inside this door's own polygon, or its `fromArea` or `toArea`.
    ///
    /// Simple two-edge doors (opening, door, portcullis, …) have a zero-area bounding polygon,
    /// so door hit-testing also checks the areas immediately behind and in front of the door.
    public func hitTest(_ point: MapPoint) -> Bool {
        contains(point) || fromArea.containsPoint(point) || toArea.containsPoint(point)
    }

    convenience init?(doorData: DoorData) {
        let kind = Kind(from: doorData.kind)
        
        // Determine initialization strategy based on door kind and available data
        switch kind {
        case .opening, .door, .portcullis, .slidingDoor, .ladder, .caveEntrance:
            // Simple doors defined by two edge points (leftEdge and rightEdge)
            guard let leftEdge = doorData.leftEdge, let rightEdge = doorData.rightEdge else { return nil }
            self.init(kind, leftEdge: leftEdge, rightEdge: rightEdge, width: doorData.doorWidth, name: doorData.name)
            
        case .trapDoor, .elevator:
            // Area-based doors defined by rectangular area using location and size
            guard let location = doorData.location, let size = doorData.size else { return nil }
            self.init(kind, location: location, size: size, 
                     leftEdge: doorData.leftEdge,
                     rightEdge: doorData.rightEdge,
                     width: doorData.doorWidth,
                     name: doorData.name)
            
        case .staircase, .passage:
            // Path-based doors that can use edges or segments like hallways
            if let edges = doorData.edges {
                self.init(kind, edges: edges, width: doorData.doorWidth, name: doorData.name)
            } else if let segments = doorData.segments {
                self.init(kind, segments: segments, width: doorData.doorWidth, name: doorData.name)
            } else if let leftEdge = doorData.leftEdge, let rightEdge = doorData.rightEdge {
                // Fallback to simple two-point definition
                self.init(kind, leftEdge: leftEdge, rightEdge: rightEdge, width: doorData.doorWidth, name: doorData.name)
            } else {
                return nil
            }
            
        case .magicPortal:
            // Magic portals support remote connections
            guard let leftEdge = doorData.leftEdge, let rightEdge = doorData.rightEdge else { return nil }
            self.init(kind, leftEdge: leftEdge, rightEdge: rightEdge, width: doorData.doorWidth, name: doorData.name)
        }
        
        self.attributes = doorData.doorAttributes
        self.rotation = doorData.doorRotationRadians
        self.connection = doorData.connection
        self.keyID = doorData.keyID
        self.stairDirection = doorData.stairDirection
    }
    
    // MARK: - Public Initializers

    /// Creates a simple door defined by two edge points and a width.
    public convenience init(kind: Kind, leftEdge: MapPoint, rightEdge: MapPoint, width: Double = 1.0, name: String? = nil) {
        self.init(kind, leftEdge: leftEdge, rightEdge: rightEdge, width: width, name: name)
    }

    // MARK: - Private Initializers

    /// Initializer for simple doors defined by two edge points and a width.
    private init(_ kind: Kind, leftEdge: MapPoint, rightEdge: MapPoint, width: Double, name: String? = nil) {
        self.kind = kind
        self.leftEdge = leftEdge
        self.rightEdge = rightEdge
        self.doorWidth = width
        self.segments = nil

        // Calculate location and size based on the two edge points
        let location = MapPoint(x: min(leftEdge.x, rightEdge.x), y: min(leftEdge.y, rightEdge.y))
        let maxLocation = MapPoint(x: max(leftEdge.x, rightEdge.x), y: max(leftEdge.y, rightEdge.y))
        
        let delta = maxLocation - location
        let size = MapSize(width: delta.x, height: delta.y)

        super.init(location: location, size: size, name: name)
    }
    
    /// Initializer for area-based doors (trapDoor, elevator) defined by location and size
    ///
    /// These door types are treated as rectangular areas rather than linear connections.
    /// If leftEdge and rightEdge are provided, they are used; otherwise, they default
    /// to the top-left and bottom-right corners of the rectangular area.
    /// If width is not provided, it defaults to 1.0 as it's not meaningful for area-based doors.
    private init(_ kind: Kind, location: MapPoint, size: MapSize,
                 leftEdge: MapPoint?, rightEdge: MapPoint?, width: Double = 1.0, name: String? = nil) {
        self.kind = kind
        self.leftEdge = leftEdge ?? location
        self.rightEdge = rightEdge ?? MapPoint(x: location.x + size.width, y: location.y + size.height)
        self.doorWidth = width
        self.segments = nil
        
        super.init(location: location, size: size, name: name)
    }
    
    /// Initializer for path-based doors (staircases, passages) defined by edge points
    ///
    /// The edge points are stored in the inherited ``DungeonRoom/edges`` property.
    private init(_ kind: Kind, edges: [MapPoint], width: Double, name: String? = nil) {
        self.kind = kind
        self.leftEdge = edges.first!
        self.rightEdge = edges.last!
        self.doorWidth = width
        self.segments = nil
        
        super.init(edges: edges, name: name)
    }
    
    /// Initializer for path-based doors (staircases, passages) defined by segment points
    ///
    /// The segment points are stored in ``segments``, and the computed boundary edges
    /// are stored in the inherited ``DungeonRoom/edges`` property.
    private init(_ kind: Kind, segments: [MapPoint], width: Double, name: String? = nil) {
        self.kind = kind
        self.leftEdge = segments.first!
        self.rightEdge = segments.last!
        self.doorWidth = width
        self.segments = segments
        
        // Compute edges from segments, similar to DungeonHallway
        let edges = computeEdges(from: segments, width: width)
        super.init(edges: edges, name: name)
    }
}
