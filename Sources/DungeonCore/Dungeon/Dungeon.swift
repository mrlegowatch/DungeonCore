//
//  Dungeon.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 10/19/16.
//  Copyright © 2016-2025 Brian Arnold. Licensed under the MIT License.
//

import Foundation
import RolePlayingCore

public struct DungeonData: CodableWithConfiguration {
    let id: String
    let name: String
    let maps: [DungeonMapData]

    init(_ dungeon: Dungeon) {
        id = dungeon.id
        name = dungeon.name
        maps = dungeon.maps.map { DungeonMapData($0) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, maps
    }

    public init(from decoder: any Decoder, configuration: DungeonCodingContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

        var mapsContainer = try container.nestedUnkeyedContainer(forKey: .maps)
        var decodedMaps: [DungeonMapData] = []
        while !mapsContainer.isAtEnd {
            decodedMaps.append(try mapsContainer.decode(DungeonMapData.self, configuration: configuration))
        }
        guard !decodedMaps.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .maps,
                in: container,
                debugDescription: "A dungeon must have at least one map, but \"maps\" is empty."
            )
        }
        maps = decodedMaps
    }

    public func encode(to encoder: any Encoder, configuration: DungeonCodingContext) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)

        var mapsContainer = container.nestedUnkeyedContainer(forKey: .maps)
        for map in maps {
            try mapsContainer.encode(map, configuration: configuration)
        }
    }
}


/// A dungeon represents a collection of maps that together form a multi-level dungeon or location.
///
/// `Dungeon` serves as the top-level container for dungeon maps.
/// Each dungeon has a unique identifier, a name, and contains one or more `DungeonMap` instances
/// that represent individual levels or floors.
///
/// ## Creating a Dungeon
///
/// You can create a new empty dungeon or load one from a JSON file:
///
/// ```swift
/// // Create a new empty dungeon with a default map
/// let newDungeon = Dungeon()
///
/// // Load a dungeon from a JSON file in the bundle
/// let loadedDungeon = try Dungeon(fileName: "example-dungeon", context: myContext)
/// ```
///
/// ## Properties
///
/// - `id`: A unique identifier for the dungeon, automatically generated for new dungeons.
/// - `name`: The display name of the dungeon, which can be customized by the user.
/// - `url`: An optional file URL where the dungeon data is stored.
/// - `maps`: An array of `DungeonMap` objects representing the individual levels or floors.
///
public class Dungeon: Identifiable, Hashable {
    public var id: String
    public var name: String
    public var url: URL?
    public var maps: [DungeonMap] = []
    
    /// Creates a new empty dungeon with default values.
    public init() {
        self.id = UUID().uuidString
        self.name = UntitledCounter.generateUntitledName()
        self.maps = [DungeonMap(index: 1)]
    }
    
    /// Creates a dungeon by loading its data from a JSON file at the given URL.
    ///
    /// - Parameters:
    ///   - url: The file URL of the JSON dungeon file.
    ///   - context: The coding context (currencies registry, etc.) used to decode the dungeon. Defaults to empty.
    /// - Throws: An error if the file cannot be read or the JSON cannot be decoded.
    public init(contentsOf url: URL, context: DungeonCodingContext = DungeonCodingContext()) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let dungeonData = try decoder.decode(DungeonData.self, from: data, configuration: context)

        self.id = dungeonData.id
        self.name = dungeonData.name
        self.url = url

        maps.reserveCapacity(dungeonData.maps.count)
        for mapDataItem in dungeonData.maps {
            maps.append(DungeonMap(data: mapDataItem))
        }
    }

    /// Creates a dungeon by loading its data from a JSON file in the given bundle.
    ///
    /// - Parameters:
    ///   - fileName: The name of the JSON file (without the `.json` extension).
    ///   - bundle: The bundle containing the JSON file. Defaults to `.main`.
    ///   - context: The coding context (currencies registry, etc.) used to decode the dungeon. Defaults to empty.
    /// - Throws: An error if the file cannot be found, read, or decoded.
    public convenience init(fileName: String, from bundle: Bundle = .main, context: DungeonCodingContext = DungeonCodingContext()) throws {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: fileName + ".json"])
        }
        try self.init(contentsOf: url, context: context)
    }

    // MARK: - Encoding & Persistence

    /// Returns the dungeon encoded as pretty-printed JSON data.
    public func encoded(context: DungeonCodingContext = DungeonCodingContext()) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(DungeonData(self), configuration: context)
    }

    /// Writes the dungeon as JSON to the given URL.
    public func write(to url: URL, context: DungeonCodingContext = DungeonCodingContext()) throws {
        let data = try encoded(context: context)
        try data.write(to: url, options: .atomic)
    }

    /// Saves the dungeon to its current `url`, if one is set.
    public func save(context: DungeonCodingContext = DungeonCodingContext()) throws {
        guard let url else { return }
        try write(to: url, context: context)
    }
    
    // MARK: - Hashable & Equatable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Dungeon, rhs: Dungeon) -> Bool {
        lhs.id == rhs.id
    }
}
