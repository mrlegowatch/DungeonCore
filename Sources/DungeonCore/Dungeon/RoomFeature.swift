//
//  RoomFeature.swift
//  DungeonCore
//
//  Created by Brian Arnold on 10/6/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import Foundation

/// A single point feature inside a room — a lever, idol, pool, trap door, or other
/// keyed element a module calls out by its own letter (e.g. "17A", "26C").
///
/// A room describes itself as a whole; `RoomFeature` lets it also describe the
/// individual things inside it, each with its own position, text, and optional treasure.
///
/// ## JSON Example
/// ```json
/// {
///   "id": "17A",
///   "kind": "lever",
///   "name": "Blue wooden lever",
///   "location": { "x": 10.5, "y": 11.5 },
///   "gmNotes": "When it is up (as it normally is), the water level is up to 10', and when it is down, so is the water."
/// }
/// ```
public struct RoomFeature: Equatable, Identifiable, Sendable {
    /// What kind of thing this feature represents.
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case area, lever, idol, pool, pit, trap, hazard, hearth, floorHatch, ceilingHatch, container, furnishing, decoration, stairs, other
    }

    /// Unique within the map (e.g. "17A", "26C", "8-chest").
    public var id: String
    public var kind: Kind
    public var name: String?
    /// Map coordinates, inside the owning room.
    public var location: MapPoint
    /// When present, the feature covers a rectangle of this size, centered on `location`.
    public var size: MapSize?
    public var readAloud: String?
    public var gmNotes: String?
    public var treasure: Treasure?

    public init(id: String, kind: Kind, name: String? = nil, location: MapPoint, size: MapSize? = nil,
                readAloud: String? = nil, gmNotes: String? = nil, treasure: Treasure? = nil) {
        self.id = id
        self.kind = kind
        self.name = name
        self.location = location
        self.size = size
        self.readAloud = readAloud
        self.gmNotes = gmNotes
        self.treasure = treasure
    }

    /// The feature's footprint rectangle (top-left corner and size), or `nil` for a point feature.
    public var footprint: (origin: MapPoint, size: MapSize)? {
        guard let size else { return nil }
        let origin = MapPoint(x: location.x - size.width / 2, y: location.y - size.height / 2)
        return (origin, size)
    }

    /// The feature's `id`, when it reads as a module key (e.g. "17A", "26C") rather than a
    /// generated id (e.g. "13-pit", "2-chest"). `nil` for generated ids.
    ///
    /// Generated ids contain a "-"; module key ids do not.
    public var keyLabel: String? {
        id.contains("-") ? nil : id
    }
}

extension RoomFeature: CodableWithConfiguration {
    public typealias DecodingConfiguration = DungeonCodingContext
    public typealias EncodingConfiguration = DungeonCodingContext

    private enum CodingKeys: String, CodingKey {
        case id, kind, name, location, size, readAloud, gmNotes, treasure
    }

    public init(from decoder: any Decoder, configuration: DungeonCodingContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        location = try container.decode(MapPoint.self, forKey: .location)
        size = try container.decodeIfPresent(MapSize.self, forKey: .size)
        readAloud = try container.decodeIfPresent(String.self, forKey: .readAloud)
        gmNotes = try container.decodeIfPresent(String.self, forKey: .gmNotes)
        treasure = try container.decodeIfPresent(Treasure.self, forKey: .treasure, configuration: configuration)
    }

    public func encode(to encoder: any Encoder, configuration: DungeonCodingContext) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(location, forKey: .location)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(readAloud, forKey: .readAloud)
        try container.encodeIfPresent(gmNotes, forKey: .gmNotes)
        if let treasure {
            try container.encode(treasure, forKey: .treasure, configuration: configuration)
        }
    }
}
