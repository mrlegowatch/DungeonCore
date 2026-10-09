//
//  DungeonRoom.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 3/28/15.
//  Copyright © 2015-2025 Brian Arnold. Licensed under the MIT License.
//

import Foundation
import RolePlayingCore

struct RoomData: CodableWithConfiguration {
    let id: String
    let location: MapPoint?
    let size: MapSize?
    let edges: [MapPoint]?
    let shape: DungeonRoom.Shape?
    let walls: [[MapPoint]]?
    let name: String?
    let keyNumber: String?
    let readAloud: String?
    let gmNotes: String?
    let contentTags: Set<DungeonRoom.ContentTag>?
    let encounters: [RoomEncounter]?
    let treasure: Treasure?
    let sectionID: String?
    let features: [RoomFeature]?
    let occupancy: Occupancy?
    let labelLocation: MapPoint?

    init(_ room: DungeonRoom) {
        id = room.id
        if room.shape == .ellipse {
            location = room.location
            size = room.size
            edges = nil
            shape = .ellipse
        } else if room.isAxisAlignedRectangle {
            location = room.location
            size = room.size
            edges = nil
            shape = nil
        } else {
            location = nil
            size = nil
            edges = room.edges
            shape = nil
        }
        walls = room.walls.isEmpty ? nil : room.walls
        name = room.name
        keyNumber = room.keyNumber
        readAloud = room.readAloud
        gmNotes = room.gmNotes
        contentTags = room.contentTags.isEmpty ? nil : room.contentTags
        encounters = room.encounters.isEmpty ? nil : room.encounters
        treasure = room.treasure
        sectionID = room.sectionID
        features = room.features.isEmpty ? nil : room.features
        occupancy = room.occupancy
        labelLocation = room.labelLocation
    }

    private enum CodingKeys: String, CodingKey {
        case id, location, size, edges, shape, walls, name, keyNumber, readAloud, gmNotes, contentTags, encounters, treasure, sectionID, features, occupancy, labelLocation
    }

    init(from decoder: any Decoder, configuration: DungeonCodingContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        location = try container.decodeIfPresent(MapPoint.self, forKey: .location)
        size = try container.decodeIfPresent(MapSize.self, forKey: .size)
        edges = try container.decodeIfPresent([MapPoint].self, forKey: .edges)
        shape = try container.decodeIfPresent(DungeonRoom.Shape.self, forKey: .shape)
        walls = try container.decodeIfPresent([[MapPoint]].self, forKey: .walls)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        keyNumber = try container.decodeIfPresent(String.self, forKey: .keyNumber)
        readAloud = try container.decodeIfPresent(String.self, forKey: .readAloud)
        gmNotes = try container.decodeIfPresent(String.self, forKey: .gmNotes)
        contentTags = try container.decodeIfPresent(Set<DungeonRoom.ContentTag>.self, forKey: .contentTags)
        encounters = try container.decodeIfPresent([RoomEncounter].self, forKey: .encounters, configuration: configuration)
        treasure = try container.decodeIfPresent(Treasure.self, forKey: .treasure, configuration: configuration)
        sectionID = try container.decodeIfPresent(String.self, forKey: .sectionID)
        features = try container.decodeIfPresent([RoomFeature].self, forKey: .features, configuration: configuration)
        occupancy = try container.decodeIfPresent(Occupancy.self, forKey: .occupancy, configuration: configuration)
        labelLocation = try container.decodeIfPresent(MapPoint.self, forKey: .labelLocation)
    }

    func encode(to encoder: any Encoder, configuration: DungeonCodingContext) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(edges, forKey: .edges)
        try container.encodeIfPresent(shape, forKey: .shape)
        try container.encodeIfPresent(walls, forKey: .walls)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(keyNumber, forKey: .keyNumber)
        try container.encodeIfPresent(readAloud, forKey: .readAloud)
        try container.encodeIfPresent(gmNotes, forKey: .gmNotes)
        if let tags = contentTags, !tags.isEmpty {
            try container.encode(tags, forKey: .contentTags)
        }
        if let encs = encounters, !encs.isEmpty {
            try container.encode(encs, forKey: .encounters, configuration: configuration)
        }
        if let t = treasure {
            try container.encode(t, forKey: .treasure, configuration: configuration)
        }
        try container.encodeIfPresent(sectionID, forKey: .sectionID)
        if let features, !features.isEmpty {
            try container.encode(features, forKey: .features, configuration: configuration)
        }
        if let occupancy {
            try container.encode(occupancy, forKey: .occupancy, configuration: configuration)
        }
        try container.encodeIfPresent(labelLocation, forKey: .labelLocation)
    }
}

/// A room within a dungeon map, defined by its location, size, and edge points.
///
/// `DungeonRoom` represents a rectangular or polygonal room that can be placed
/// within a dungeon map. Rooms can be initialized either with a location and size
/// (for rectangular rooms) or with an array of edge points (for rooms with
/// arbitrary shapes).
///
/// ## Creating a Room
///
/// You can create a room in several ways:
///
/// ```swift
/// // From location and size
/// let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 10, height: 10))
///
/// // From edge points
/// let room = DungeonRoom(edges: [MapPoint(x: 0, y: 0), MapPoint(x: 10, y: 0), ...])
///
/// // From decoded room data
/// if let room = DungeonRoom(roomData: decodedData) {
///     // Use room
/// }
/// ```
///
/// ## Properties
///
/// - ``location``: The origin point of the room on the map.
/// - ``size``: The width and height dimensions of the room.
/// - ``edges``: An array of points defining the room's boundary vertices.
/// - ``name``: An optional name for the room.
/// - ``keyNumber``: An optional key identifier linking this room to module text (e.g. "4", "12a").
/// - ``readAloud``: An optional passage to read aloud to players when they enter the room.
/// - ``gmNotes``: An optional GM-only description of the room's contents.
/// - ``contentTags``: A set of content categories describing what the room contains.
public class DungeonRoom: Identifiable {

    /// Classifies the kind of content a room holds, for use in keyed dungeon modules.
    public enum ContentTag: String, Codable, CaseIterable, Sendable {
        case encounter, treasure, trap, hazard, empty, special
    }

    /// The geometric shape of a room's boundary.
    public enum Shape: String, Codable, Sendable {
        case polygon, ellipse
    }

    public var id: String
    public var location: MapPoint
    public var size: MapSize
    public var rotation: Double = 0.0
    public var edges: [MapPoint]
    public var shape: Shape = .polygon
    /// Interior walls drawn inside the room, each a polyline of two or more points.
    ///
    /// Walls are drawing only: they do not affect ``contains(_:)``, connectivity, or reachability.
    public var walls: [[MapPoint]] = []
    public var name: String?
    public var keyNumber: String?
    public var readAloud: String?
    public var gmNotes: String?
    public var contentTags: Set<ContentTag> = []
    public var encounters: [RoomEncounter] = []
    public var treasure: Treasure?
    /// The id of the ``DungeonSection`` this room belongs to, or `nil` if unsectioned.
    public var sectionID: String?
    /// Point features inside this room (levers, idols, pools, etc.). Always empty for
    /// ``DungeonHallway`` and ``DungeonDoor``.
    public var features: [RoomFeature] = []
    /// A chance that a wandering group occupies this room, with an optional table of who shows up.
    /// Separate from ``encounters``, which are always present; occupancy is rolled.
    public var occupancy: Occupancy?
    /// Where the center of this room's number label is drawn, overriding automatic corner
    /// placement. May lie outside the room (e.g. a narrow corridor's name in the margin
    /// beside it). `nil` means automatic placement.
    public var labelLocation: MapPoint?

    /// The room's treasure keys, then each encounter's, then each feature's, in order,
    /// without duplicates.
    public var keyIDs: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for keyID in treasure?.keyIDs ?? [] where seen.insert(keyID).inserted {
            result.append(keyID)
        }
        for encounter in encounters {
            for keyID in encounter.keyIDs where seen.insert(keyID).inserted {
                result.append(keyID)
            }
        }
        for feature in features {
            for keyID in feature.treasure?.keyIDs ?? [] where seen.insert(keyID).inserted {
                result.append(keyID)
            }
        }
        return result
    }

    /// True when `edges` exactly match the four corners derived from `location` and `size`.
    ///
    /// Used by the serializer to decide whether to emit `location`/`size` (compact JSON) or
    /// the raw `edges` array (for polygon rooms). Polygon rooms that were loaded from `edges`
    /// will have an arbitrary vertex count and always return `false`.
    public var isAxisAlignedRectangle: Bool {
        shape == .polygon && edges == Array(location: location, size: size)
    }

    /// Shifts the room's position by the given delta.
    ///
    /// `location`, every vertex in `edges`, and every point in `walls` are moved by the
    /// same amount, keeping all representations in sync.
    public func translate(by delta: MapPoint) {
        location = location + delta
        edges = edges.map { $0 + delta }
        walls = walls.map { wall in wall.map { $0 + delta } }
        features = features.map { feature in
            var feature = feature
            feature.location = feature.location + delta
            return feature
        }
        if let labelLocation {
            self.labelLocation = labelLocation + delta
        }
    }

    /// Returns a shortened prefix from the name, if it contains a ":" character.
    public var shortName: String? {
        guard let name = name,
              let colonIndex = name.firstIndex(of: ":") else {
            return nil
        }
        return String(name[..<colonIndex])
    }
    
    /// Creates a rectangular dungeon room at the specified location with the given size.
    ///
    /// Creates a rectangular room with four edge points computed from the location and size.
    ///
    /// - Parameters:
    ///   - location: The origin point of the room on the map, representing the
    ///     top-left corner of the rectangular room.
    ///   - size: The dimensions of the room, specifying its width and height.
    ///   - name: An optional name for the room. Defaults to `nil`.
    public init(location: MapPoint, size: MapSize, name: String? = nil) {
        self.id = UUID().uuidString
        self.location = location
        self.size = size
        self.name = name
        self.edges = .init(location: location, size: size)
    }
    
    /// Creates a dungeon room defined by its boundary vertices.
    ///
    /// This initializer creates a room from an array of edge points that define
    /// the room's polygon. The location and size are automatically computed from
    /// the bounding box of the provided edge points.
    ///
    /// - Parameters:
    ///   - edges: An array of ``MapPoint`` values representing the vertices
    ///     of the room's boundary polygon, typically in clockwise or counter-clockwise order.
    ///   - name: An optional name for the room. Defaults to `nil`.
    public init(edges: [MapPoint], name: String? = nil) {
        self.id = UUID().uuidString
        self.edges = edges
        self.name = name
        let (location, size) = edges.computeLocationAndSize()
        self.location = location
        self.size = size
    }

    /// Creates an elliptical dungeon room inscribed in the given bounding box.
    ///
    /// - Parameters:
    ///   - location: The origin (top-left corner) of the ellipse's bounding box.
    ///   - size: The dimensions of the ellipse's bounding box.
    ///   - name: An optional name for the room. Defaults to `nil`.
    public init(ellipseIn location: MapPoint, size: MapSize, name: String? = nil) {
        self.id = UUID().uuidString
        self.location = location
        self.size = size
        self.name = name
        self.shape = .ellipse
        self.edges = DungeonRoom.ellipseEdges(location: location, size: size)
    }

    /// Computes 32 vertices along the ellipse inscribed in the given bounding box.
    ///
    /// Vertex `i` sits at angle `2π(i + 0.5) / 32` measured from +x, so the half-step
    /// offset puts a flat edge at each of the four compass points, where doors sit.
    private static func ellipseEdges(location: MapPoint, size: MapSize) -> [MapPoint] {
        let center = MapPoint(x: location.x + size.width / 2, y: location.y + size.height / 2)
        let a = size.width / 2
        let b = size.height / 2
        return (0..<32).map { i in
            let theta = 2 * Double.pi * (Double(i) + 0.5) / 32
            return MapPoint(x: center.x + a * cos(theta), y: center.y + b * sin(theta))
        }
    }

    /// Regenerates `edges` for an ellipse room from its current `location` and `size`.
    ///
    /// Call this after resizing an ellipse room (e.g. dragging a bounding-box resize
    /// handle) instead of rebuilding the vertices by hand. Has no effect on polygon rooms.
    public func regenerateEllipseEdges() {
        guard shape == .ellipse else { return }
        edges = DungeonRoom.ellipseEdges(location: location, size: size)
    }

    /// Creates a dungeon room from decoded room data.
    ///
    /// This failable initializer attempts to create a room from a ``RoomData`` structure,
    /// which may contain either edge points or a location and size pair. The initializer
    /// prioritizes edge points if both are present.
    ///
    /// - Parameter roomData: A decoded ``RoomData`` structure containing the room's
    ///   definition. Must include either:
    ///   - A non-nil ``RoomData/edges`` array, which will be used to create a
    ///     polygon-based room, or
    ///   - Both a non-nil ``RoomData/location`` and ``RoomData/size``, which will
    ///     be used to create a rectangular room.
    ///
    /// - Returns: A new `DungeonRoom` instance if the room data contains valid
    ///   initialization parameters, or `nil` if neither edges nor a complete
    ///   location/size pair is provided.
    convenience init?(roomData: RoomData) {
        if roomData.shape == .ellipse, let location = roomData.location, let size = roomData.size {
            self.init(ellipseIn: location, size: size, name: roomData.name)
        } else if let edges = roomData.edges {
            self.init(edges: edges, name: roomData.name)
        } else if let location = roomData.location, let size = roomData.size {
            self.init(location: location, size: size, name: roomData.name)
        } else {
            return nil
        }
        self.id = roomData.id
        self.walls = roomData.walls ?? []
        self.keyNumber = roomData.keyNumber
        self.readAloud = roomData.readAloud
        self.gmNotes = roomData.gmNotes
        self.contentTags = roomData.contentTags ?? []
        self.encounters = roomData.encounters ?? []
        self.treasure = roomData.treasure
        self.sectionID = roomData.sectionID
        self.features = roomData.features ?? []
        self.occupancy = roomData.occupancy
        self.labelLocation = roomData.labelLocation
    }

    /// Returns true if the given map point falls inside this room's shape.
    ///
    /// Uses ray-casting point-in-polygon over the room's edges. Because rectangular
    /// rooms always have their four corner edges populated, this works uniformly for
    /// both rectangular and polygon rooms. This is the building block for tap-to-select
    /// and room-adjacency queries.
    public func contains(_ point: MapPoint) -> Bool {
        edges.containsPoint(point)
    }
}
