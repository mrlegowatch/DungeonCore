//
//  DungeonMap.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 3/28/15.
//  Copyright © 2015-2025 Brian Arnold. Licensed under the MIT License.
//

import Foundation
import RolePlayingCore

public struct DungeonMapData: CodableWithConfiguration {
    let id: String
    let name: String
    let rooms: [RoomData]
    let hallways: [HallwayData]
    let doors: [DoorData]
    let sections: [DungeonSection]

    init(_ map: DungeonMap) {
        id = map.id
        name = map.name
        rooms = map.rooms.map { RoomData($0) }
        hallways = map.hallways.map { HallwayData($0) }
        doors = map.doors.map { DoorData($0) }
        sections = map.sections
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, rooms, hallways, doors, sections
    }

    public init(from decoder: any Decoder, configuration: DungeonCodingContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

        var roomsContainer = try container.nestedUnkeyedContainer(forKey: .rooms)
        var decodedRooms: [RoomData] = []
        while !roomsContainer.isAtEnd {
            decodedRooms.append(try roomsContainer.decode(RoomData.self, configuration: configuration))
        }
        rooms = decodedRooms

        hallways = try container.decodeIfPresent([HallwayData].self, forKey: .hallways) ?? []
        doors = try container.decodeIfPresent([DoorData].self, forKey: .doors) ?? []
        sections = try container.decodeIfPresent([DungeonSection].self, forKey: .sections) ?? []
    }

    public func encode(to encoder: any Encoder, configuration: DungeonCodingContext) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)

        var roomsContainer = container.nestedUnkeyedContainer(forKey: .rooms)
        for room in rooms {
            try roomsContainer.encode(room, configuration: configuration)
        }

        try container.encode(hallways, forKey: .hallways)
        try container.encode(doors, forKey: .doors)
        if !sections.isEmpty {
            try container.encode(sections, forKey: .sections)
        }
    }
}

/// A room, hallway, or door that failed to initialize while decoding a ``DungeonMap``, along
/// with its position in the source data and a short reason, recorded in ``DungeonMap/decodingIssues``.
public struct DecodingIssue: Equatable, Sendable {
    /// Which element collection the failure occurred in.
    public enum Kind: String, Sendable {
        case room, hallway, door
    }

    /// Which kind of element failed to decode.
    public let kind: Kind
    /// The element's position within its collection in the source data.
    public let index: Int
    /// A short, human-readable explanation of why the element could not be created.
    public let reason: String
}

/// Represents a complete dungeon floor with rooms, hallways, and doors.
///
/// A `DungeonMap` serves as the container for all dungeon elements on a single floor,
/// managing the spatial relationships between rooms connected by hallways and doors.
///
/// ## Topics
///
/// ### Creating a Dungeon Map
///
/// - ``init(index:)``
/// - ``init(data:)``
///
/// ### Identifying the Map
///
/// - ``id``
/// - ``name``
///
/// ### Map Elements
///
/// - ``rooms``
/// - ``hallways``
/// - ``doors``
/// - ``bounds``
/// - ``decodingIssues``
public class DungeonMap {
    public var id: String
    public var name: String
    public var rooms: [DungeonRoom] = []
    public var hallways: [DungeonHallway] = []
    public var doors: [DungeonDoor] = []
    /// Named groupings of rooms under a module heading, in display order.
    public var sections: [DungeonSection] = []
    /// Elements from ``init(data:)`` that failed to initialize and were skipped, in the
    /// order they were encountered. Empty when decoding every element succeeded, or when
    /// this map was not created via ``init(data:)``.
    public private(set) var decodingIssues: [DecodingIssue] = []

    /// Creates a new dungeon map with a default name based on the given index.
    ///
    /// This initializer creates a dungeon map with an automatically generated name
    /// and identifier in the format "floor N" and "floor_N" respectively, where N
    /// is the provided index.
    ///
    /// The map is initially empty, containing no rooms, hallways, or doors. These
    /// elements should be added after initialization.
    ///
    /// - Parameter index: The floor number to use for generating the map's name and identifier.
    public init(index: Int) {
        self.name = "floor \(index)"
        self.id = "floor_\(index)"
    }
        
    /// Creates a dungeon map from serialized data.
    ///
    /// This initializer reconstructs a complete dungeon map from its data representation,
    /// including all rooms, hallways, and doors. The initialization process validates each
    /// element during creation.
    ///
    /// If any individual element (room, hallway, or door) fails to initialize from its
    /// data representation, it is skipped and recorded in ``decodingIssues``. The
    /// initialization continues with the remaining valid elements.
    ///
    /// - Parameter data: The serialized dungeon map data containing the map's identifier,
    ///   name, and collections of room, hallway, and door data.
    public init(data: DungeonMapData) {
        self.name = data.name
        self.id = data.id

        for (index, roomData) in data.rooms.enumerated() {
            if let room = DungeonRoom(roomData: roomData) {
                self.rooms.append(room)
            } else {
                decodingIssues.append(DecodingIssue(kind: .room, index: index, reason: "no edges, and no location/size pair"))
            }
        }

        for (index, hallwayData) in data.hallways.enumerated() {
            if let hallway = DungeonHallway(hallwayData: hallwayData) {
                self.hallways.append(hallway)
            } else {
                decodingIssues.append(DecodingIssue(kind: .hallway, index: index, reason: "no edges and no segments"))
            }
        }

        for (index, doorData) in data.doors.enumerated() {
            if let door = DungeonDoor(doorData: doorData) {
                self.doors.append(door)
            } else {
                let kind = DungeonDoor.Kind(from: doorData.kind)
                decodingIssues.append(DecodingIssue(kind: .door, index: index, reason: "missing required fields for kind \(kind.rawValue)"))
            }
        }

        self.sections = data.sections
    }

    // MARK: - Room mutations

    public func addRoom(_ room: DungeonRoom) {
        rooms.append(room)
    }

    public func insertRoom(_ room: DungeonRoom, at index: Int) {
        rooms.insert(room, at: index)
    }

    public func removeRoom(_ room: DungeonRoom) {
        rooms.removeAll { $0 === room }
    }

    public func indexOfRoom(_ room: DungeonRoom) -> Int? {
        rooms.firstIndex { $0 === room }
    }

    /// Returns the room with the given `id`, searching `rooms` only (not hallways or doors).
    public func room(withID id: String) -> DungeonRoom? {
        rooms.first { $0.id == id }
    }

    /// Returns the room and feature whose feature `id` matches, searching `rooms` only.
    public func feature(withID id: String) -> (room: DungeonRoom, feature: RoomFeature)? {
        for room in rooms {
            if let feature = room.features.first(where: { $0.id == id }) {
                return (room, feature)
            }
        }
        return nil
    }

    /// Feature ids that appear on more than one feature across `rooms`.
    public var duplicateFeatureIDs: Set<String> {
        var seen = Set<String>()
        var duplicates = Set<String>()
        for room in rooms {
            for feature in room.features where !seen.insert(feature.id).inserted {
                duplicates.insert(feature.id)
            }
        }
        return duplicates
    }

    /// Features whose `location` falls outside their owning room's shape.
    public var featuresOutsideTheirRooms: [RoomFeature] {
        rooms.flatMap { room in
            room.features.filter { !room.contains($0.location) }
        }
    }

    /// The bounding rectangle of all rooms and hallways, in map units, or `nil` when
    /// this map has neither rooms nor hallways.
    public var bounds: MapRect? {
        let elements = hallways + rooms
        guard let first = elements.first else { return nil }
        var minX = first.location.x
        var minY = first.location.y
        var maxX = first.location.x + first.size.width
        var maxY = first.location.y + first.size.height
        for element in elements.dropFirst() {
            minX = min(minX, element.location.x)
            minY = min(minY, element.location.y)
            maxX = max(maxX, element.location.x + element.size.width)
            maxY = max(maxY, element.location.y + element.size.height)
        }
        return MapRect(origin: MapPoint(x: minX, y: minY), size: MapSize(width: maxX - minX, height: maxY - minY))
    }

    // MARK: - Hallway mutations

    public func addHallway(_ hallway: DungeonHallway) {
        hallways.append(hallway)
    }

    public func insertHallway(_ hallway: DungeonHallway, at index: Int) {
        hallways.insert(hallway, at: index)
    }

    public func removeHallway(_ hallway: DungeonHallway) {
        hallways.removeAll { $0 === hallway }
    }

    public func indexOfHallway(_ hallway: DungeonHallway) -> Int? {
        hallways.firstIndex { $0 === hallway }
    }

    // MARK: - Door mutations

    public func addDoor(_ door: DungeonDoor) {
        doors.append(door)
    }

    public func insertDoor(_ door: DungeonDoor, at index: Int) {
        doors.insert(door, at: index)
    }

    public func removeDoor(_ door: DungeonDoor) {
        doors.removeAll { $0 === door }
    }

    public func indexOfDoor(_ door: DungeonDoor) -> Int? {
        doors.firstIndex { $0 === door }
    }

    // MARK: - Section mutations

    public func addSection(_ section: DungeonSection) {
        sections.append(section)
    }

    /// Removes `section` and clears `sectionID` on any room that referenced it.
    public func removeSection(_ section: DungeonSection) {
        guard let index = sections.firstIndex(where: { $0.id == section.id }) else { return }
        sections.remove(at: index)
        for room in rooms where room.sectionID == section.id {
            room.sectionID = nil
        }
    }

    public func moveSection(fromOffsets source: IndexSet, toOffset destination: Int) {
        let movedSections = source.map { sections[$0] }
        let adjustedDestination = source.reduce(destination) { result, offset in
            offset < result ? result - 1 : result
        }
        for index in source.sorted(by: >) {
            sections.remove(at: index)
        }
        sections.insert(contentsOf: movedSections, at: adjustedDestination)
    }

    // MARK: - Section queries

    /// Returns the declared section `room` belongs to, or `nil` if unsectioned or if
    /// its `sectionID` does not match any declared section.
    public func section(for room: DungeonRoom) -> DungeonSection? {
        guard let sectionID = room.sectionID else { return nil }
        return sections.first { $0.id == sectionID }
    }

    /// Returns the rooms belonging to `section`, in map order.
    public func rooms(in section: DungeonSection) -> [DungeonRoom] {
        rooms.filter { $0.sectionID == section.id }
    }

    /// Rooms with no `sectionID`, in map order.
    public var unsectionedRooms: [DungeonRoom] {
        rooms.filter { $0.sectionID == nil }
    }

    /// Section ids referenced by rooms but not declared in `sections`.
    public var unknownSectionIDs: Set<String> {
        let knownIDs = Set(sections.map(\.id))
        return Set(rooms.compactMap(\.sectionID).filter { !knownIDs.contains($0) })
    }

    // MARK: - Occupancy

    /// The encounter table that applies when `room`'s occupancy rolls occupied: `room`'s
    /// own table when present, else the table of the room named by its
    /// `occupancy.tableRoomID` (one hop only — a referenced room's own `tableRoomID` is
    /// not followed), else `nil`.
    public func encounterTable(for room: DungeonRoom) -> EncounterTable? {
        guard let occupancy = room.occupancy else { return nil }
        if let table = occupancy.table { return table }
        guard let tableRoomID = occupancy.tableRoomID else { return nil }
        return self.room(withID: tableRoomID)?.occupancy?.table
    }

    /// Rolls `room`'s occupancy, resolving its table via ``encounterTable(for:)``: `nil`
    /// when the room has no occupancy; `.empty` when the chance fails; `.occupied(nil)`
    /// only when there is no table to resolve.
    public func rollOccupancy(for room: DungeonRoom) -> Occupancy.Outcome? {
        rollOccupancyDetail(for: room)?.outcome
    }

    /// Rolls `room`'s occupancy exactly once per die involved, returning both the outcome
    /// and a description of the numbers rolled (e.g. "d10 rolled 2 (needs 1-3); d4 rolled 3"),
    /// so a caller can show the roll without rolling again. `nil` when the room has no occupancy.
    public func rollOccupancyDetail(for room: DungeonRoom) -> (outcome: Occupancy.Outcome, rollDescription: String)? {
        guard let occupancy = room.occupancy else { return nil }
        let (succeeded, rolled) = occupancy.chance.checkRoll()
        let chanceDescription = "\(occupancy.chance.die.description) rolled \(rolled) (needs \(occupancy.chance.neededRange))"
        guard succeeded else { return (.empty, chanceDescription) }
        guard let table = encounterTable(for: room) else { return (.occupied(nil), chanceDescription) }
        let (row, tableRolled) = table.rollRow()
        let description = "\(chanceDescription); \(table.die.description) rolled \(tableRolled)"
        return (.occupied(row?.encounter), description)
    }

    /// Room ids named by some room's `occupancy.tableRoomID` that do not exist on this
    /// map, or whose room has no table of its own.
    public var unknownOccupancyTableRoomIDs: Set<String> {
        var result = Set<String>()
        for room in rooms {
            guard let tableRoomID = room.occupancy?.tableRoomID else { continue }
            if self.room(withID: tableRoomID)?.occupancy?.table == nil {
                result.insert(tableRoomID)
            }
        }
        return result
    }
}
