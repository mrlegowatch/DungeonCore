import Testing
import Foundation
import RolePlayingCore
import SwiftDice
@testable import DungeonCore

private let testContext = DungeonCodingContext(currencies: Currencies([
    UnitCurrency(symbol: "cp", coefficient: 0.01, name: "copper piece", plural: "copper pieces"),
    UnitCurrency(symbol: "sp", coefficient: 0.1, name: "silver piece", plural: "silver pieces"),
    UnitCurrency(symbol: "ep", coefficient: 0.5, name: "electrum piece", plural: "electrum pieces"),
    UnitCurrency(symbol: "gp", coefficient: 1.0, name: "gold piece", plural: "gold pieces", isDefault: true),
    UnitCurrency(symbol: "pp", coefficient: 10.0, name: "platinum piece", plural: "platinum pieces"),
]))

// MARK: - Room metadata decoding

@Test func roomMetadataDecodesFromJSON() throws {
    guard let url = Bundle.module.url(forResource: "SampleMap", withExtension: "json") else {
        Issue.record("SampleMap.json not found in test bundle")
        return
    }
    let data = try Data(contentsOf: url)
    let dungeonData = try JSONDecoder().decode(DungeonData.self, from: data, configuration: testContext)
    let map = DungeonMap(data: dungeonData.maps[0])

    // Room 1: key "1", readAloud + gmNotes, tag [empty]
    let room1 = try #require(map.rooms.first)
    #expect(room1.keyNumber == "1")
    #expect(room1.readAloud == "A bare guardroom. An overturned stool lies in the corner.")
    #expect(room1.gmNotes == "The guards have fled.")
    #expect(room1.contentTags == [.empty])

    // Room 2: encounter + treasure with structured data
    let room2 = map.rooms[1]
    let gp = testContext.currencies["gp"]!
    let sp = testContext.currencies["sp"]!
    #expect(room2.readAloud == "Three goblins crouch around a small fire, dicing for a sack of stolen coins. A locked chest sits against the far wall.")
    #expect(room2.gmNotes == nil)
    #expect(room2.contentTags == [.encounter, .treasure])
    #expect(room2.encounters.count == 1)
    #expect(room2.encounters[0].name == "Goblin")
    #expect(room2.encounters[0].count == 3)
    #expect(room2.encounters[0].alignment?.kind == CharacterAlignment.Kind(.chaotic, .evil))
    #expect(room2.treasure == nil)
    #expect(room2.features.count == 1)
    #expect(room2.features[0].id == "2-chest")
    #expect(room2.features[0].treasure?.coins[gp]?.constant == 40)
    #expect(room2.features[0].treasure?.coins[sp]?.constant == 15)
    #expect(room2.encounters[0].carried?.items.first?.keyID == "guard-key")

    // Room 3: trap only
    #expect(map.rooms[2].readAloud == nil)
    #expect(map.rooms[2].gmNotes == "A pressure plate near the south door triggers a falling-block trap.")
    #expect(map.rooms[2].contentTags == [.trap])
    #expect(map.rooms[2].encounters.isEmpty)
    #expect(map.rooms[2].treasure == nil)

    // Room 4: special, no encounters
    #expect(map.rooms[3].readAloud == "The walls are carved with strange runes that glow faintly blue. The air hums with latent power.")
    #expect(map.rooms[3].gmNotes == nil)
    #expect(map.rooms[3].contentTags == [.special])

    // Room 5: multiple encounters
    let room5 = map.rooms[4]
    #expect(room5.readAloud == "A hobgoblin war-chief holds court in this chamber, flanked by two veteran guards. Sacks of plunder are piled in the corner.")
    #expect(room5.gmNotes == nil)
    #expect(room5.encounters.count == 2)
    #expect(room5.encounters[0].name == "Hobgoblin War-Chief")
    #expect(room5.treasure == nil)
    #expect(room5.features.count == 1)
    #expect(room5.features[0].id == "5-throne")
    #expect(room5.features[0].treasure?.coins[gp]?.constant == 120)
    #expect(room5.features[0].treasure?.items.map(\.name) == ["Potion of Healing"])
}

@Test func roomMetadataDefaultsToNilAndEmptySet() throws {
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 5, height: 5))
    #expect(room.keyNumber == nil)
    #expect(room.readAloud == nil)
    #expect(room.gmNotes == nil)
    #expect(room.contentTags.isEmpty)
    #expect(room.encounters.isEmpty)
    #expect(room.treasure == nil)
}

@Test func existingMapsDecodeWithoutMetadata() throws {
    // TestHallways.json has no metadata fields — confirms backward compatibility
    guard let url = Bundle.module.url(forResource: "TestHallways", withExtension: "json") else {
        Issue.record("TestHallways.json not found in test bundle")
        return
    }
    let data = try Data(contentsOf: url)
    let dungeonData = try JSONDecoder().decode(DungeonData.self, from: data, configuration: testContext)
    let map = DungeonMap(data: dungeonData.maps[0])
    for room in map.rooms {
        #expect(room.keyNumber == nil)
        #expect(room.contentTags.isEmpty)
        #expect(room.encounters.isEmpty)
        #expect(room.treasure == nil)
    }
}

// MARK: - Dungeon decoding

@Test func dungeonRejectsEmptyMapsArray() throws {
    let json = """
    { "id": "d1", "name": "Empty Dungeon", "maps": [] }
    """.data(using: .utf8)!
    #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(DungeonData.self, from: json, configuration: testContext)
    }
}

// MARK: - contains(_:) hit test

@Test func rectangularRoomContainsInteriorPoint() {
    let room = DungeonRoom(location: MapPoint(x: 2, y: 3), size: MapSize(width: 4, height: 5))
    #expect(room.contains(MapPoint(x: 4, y: 5)))     // center
    #expect(room.contains(MapPoint(x: 3, y: 4)))     // interior near top-left
    #expect(room.contains(MapPoint(x: 5, y: 7)))     // interior near bottom-right
}

@Test func rectangularRoomExcludesExteriorPoint() {
    let room = DungeonRoom(location: MapPoint(x: 2, y: 3), size: MapSize(width: 4, height: 5))
    #expect(!room.contains(MapPoint(x: 0, y: 0)))
    #expect(!room.contains(MapPoint(x: 7, y: 5)))
}

@Test func polygonRoomContainsInteriorPoint() {
    // Simple 4x4 square defined as polygon
    let edges = [
        MapPoint(x: 0, y: 0), MapPoint(x: 4, y: 0),
        MapPoint(x: 4, y: 4), MapPoint(x: 0, y: 4)
    ]
    let room = DungeonRoom(edges: edges)
    #expect(room.contains(MapPoint(x: 2, y: 2)))     // center
    #expect(!room.contains(MapPoint(x: 5, y: 2)))    // outside right
    #expect(!room.contains(MapPoint(x: 2, y: 5)))    // outside bottom
}

// MARK: - DungeonDoor.hitTest(_:)

@Test func doorHitTestMatchesOwnPolygon() {
    // leftEdge/rightEdge on different x and y produce a real (non-degenerate) polygon,
    // so hitTest should agree with contains.
    let door = DungeonDoor(kind: .trapDoor, leftEdge: MapPoint(x: 2, y: 2), rightEdge: MapPoint(x: 3, y: 3))
    #expect(door.hitTest(MapPoint(x: 2.5, y: 2.5)))
    #expect(!door.hitTest(MapPoint(x: 10, y: 10)))
}

@Test func doorHitTestFallsBackToFromAndToArea() {
    // A simple door's edges form a zero-area polygon, so contains(_:) always fails;
    // hitTest must fall back to fromArea/toArea to register a hit.
    let door = DungeonDoor(kind: .door, leftEdge: MapPoint(x: 5, y: 4), rightEdge: MapPoint(x: 5, y: 3))
    #expect(!door.contains(MapPoint(x: 5.5, y: 3.5)))
    #expect(door.hitTest(MapPoint(x: 5.5, y: 3.5)))  // inside toArea
    #expect(door.hitTest(MapPoint(x: 4.5, y: 3.5)))  // inside fromArea
    #expect(!door.hitTest(MapPoint(x: 100, y: 100)))
}

// MARK: - Encoding round-trip

@Test func dungeonRoundTripsViaJSON() throws {
    guard let url = Bundle.module.url(forResource: "SampleMap", withExtension: "json") else {
        Issue.record("SampleMap.json not found in test bundle")
        return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let map = dungeon.maps[0]

    // Encode back to JSON then decode again
    let encoded = try dungeon.encoded(context: testContext)
    let dungeonData2 = try JSONDecoder().decode(DungeonData.self, from: encoded, configuration: testContext)
    let map2 = DungeonMap(data: dungeonData2.maps[0])

    // Counts must survive the round-trip
    #expect(map2.rooms.count == map.rooms.count)
    #expect(map2.hallways.count == map.hallways.count)
    #expect(map2.doors.count == map.doors.count)

    // Key metadata must survive
    let gp = testContext.currencies["gp"]!
    #expect(map2.rooms[0].keyNumber == map.rooms[0].keyNumber)
    #expect(map2.rooms[0].id == map.rooms[0].id)
    #expect(map2.rooms[1].encounters.count == map.rooms[1].encounters.count)
    #expect(map2.rooms[1].features.first?.treasure?.coins[gp]?.constant == map.rooms[1].features.first?.treasure?.coins[gp]?.constant)
    #expect(map2.rooms[4].features.first?.treasure?.items.map(\.name) == map.rooms[4].features.first?.treasure?.items.map(\.name))

    // Door attributes and keyID must survive
    let door0 = map.doors[0]
    let door0rt = map2.doors[0]
    #expect(door0rt.attributes == door0.attributes)
    #expect(door0rt.keyID == door0.keyID)
}

@Test func rectangularRoomSerializesAsLocationAndSize() throws {
    let room = DungeonRoom(location: MapPoint(x: 2, y: 3), size: MapSize(width: 4, height: 5))
    let data = RoomData(room)
    #expect(data.location != nil)
    #expect(data.size != nil)
    #expect(data.edges == nil)
}

@Test func polygonRoomSerializesAsEdges() throws {
    let edges = [
        MapPoint(x: 0, y: 0), MapPoint(x: 3, y: 0),
        MapPoint(x: 3, y: 2), MapPoint(x: 1, y: 2),
        MapPoint(x: 1, y: 4), MapPoint(x: 0, y: 4)
    ]
    let room = DungeonRoom(edges: edges)
    let data = RoomData(room)
    #expect(data.edges != nil)
    #expect(data.location == nil)
    #expect(data.size == nil)
}

// MARK: - translate(by:)

@Test func translateShiftsRoomGeometry() {
    let room = DungeonRoom(location: MapPoint(x: 2, y: 3), size: MapSize(width: 4, height: 5))
    let delta = MapPoint(x: 10, y: 5)
    room.translate(by: delta)
    #expect(room.location == MapPoint(x: 12, y: 8))
    #expect(room.edges.allSatisfy { $0.x >= 12 && $0.y >= 8 })
}

@Test func translateShiftsHallwaySegments() {
    let hallway = DungeonHallway(segments: [
        MapPoint(x: 0, y: 0),
        MapPoint(x: 5, y: 0)
    ], width: 1.0)
    let delta = MapPoint(x: 3, y: 2)
    hallway.translate(by: delta)
    #expect(hallway.segments?[0] == MapPoint(x: 3, y: 2))
    #expect(hallway.segments?[1] == MapPoint(x: 8, y: 2))
    #expect(hallway.location == MapPoint(x: 3, y: 2))
}

// MARK: - DungeonMap mutation primitives

@Test func mapAddRemoveRoom() {
    let map = DungeonMap(index: 1)
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    map.addRoom(room)
    #expect(map.rooms.count == 1)
    #expect(map.rooms[0] === room)

    map.removeRoom(room)
    #expect(map.rooms.isEmpty)
}

@Test func mapInsertRoomAtIndex() {
    let map = DungeonMap(index: 1)
    let roomA = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 2, height: 2))
    let roomB = DungeonRoom(location: MapPoint(x: 5, y: 5), size: MapSize(width: 2, height: 2))
    map.addRoom(roomA)
    map.insertRoom(roomB, at: 0)
    #expect(map.rooms[0] === roomB)
    #expect(map.rooms[1] === roomA)
}

@Test func mapRemoveNonMemberRoomIsNoop() {
    let map = DungeonMap(index: 1)
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 2, height: 2))
    map.removeRoom(room)  // not added — must not crash
    #expect(map.rooms.isEmpty)
}

@Test func mapIndexOfRoom() {
    let map = DungeonMap(index: 1)
    let roomA = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 2, height: 2))
    let roomB = DungeonRoom(location: MapPoint(x: 5, y: 5), size: MapSize(width: 2, height: 2))
    map.addRoom(roomA)
    map.addRoom(roomB)
    #expect(map.indexOfRoom(roomA) == 0)
    #expect(map.indexOfRoom(roomB) == 1)
}

@Test func mapRoomWithIDSearchesRoomsOnly() {
    let map = DungeonMap(index: 1)
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 2, height: 2))
    let hallway = DungeonHallway(segments: [MapPoint(x: 0, y: 0), MapPoint(x: 5, y: 0)], width: 1.0)
    map.addRoom(room)
    map.addHallway(hallway)
    #expect(map.room(withID: room.id) === room)
    #expect(map.room(withID: hallway.id) == nil)
    #expect(map.room(withID: "nonexistent") == nil)
}

// MARK: - DungeonMap.bounds

@Test func mapBoundsIsNilWhenEmpty() {
    let map = DungeonMap(index: 1)
    #expect(map.bounds == nil)
}

@Test func mapBoundsSpansRoomsAndHallways() {
    let map = DungeonMap(index: 1)
    map.addRoom(DungeonRoom(location: MapPoint(x: 2, y: 3), size: MapSize(width: 4, height: 4)))
    map.addRoom(DungeonRoom(location: MapPoint(x: -1, y: 10), size: MapSize(width: 2, height: 2)))
    map.addHallway(DungeonHallway(segments: [MapPoint(x: 6, y: 5), MapPoint(x: 9, y: 5)], width: 1.0))

    let bounds = try! #require(map.bounds)
    #expect(bounds.origin == MapPoint(x: -1, y: 3))
    #expect(bounds.size == MapSize(width: 10, height: 9))
}

// MARK: - DungeonMap.decodingIssues

@Test func decodingIssuesRecordsSkippedElements() throws {
    let json = """
    {
        "id": "floor_1",
        "name": "Floor 1",
        "rooms": [
            { "id": "r0", "location": { "x": 0, "y": 0 }, "size": { "width": 4, "height": 4 } },
            { "id": "bad-room" }
        ],
        "hallways": [
            { "segments": [{ "x": 0, "y": 0 }, { "x": 5, "y": 0 }], "width": 1.0 },
            { }
        ],
        "doors": [
            { "kind": "door", "leftEdge": { "x": 1, "y": 1 }, "rightEdge": { "x": 1, "y": 2 } },
            { "kind": "door" }
        ]
    }
    """.data(using: .utf8)!
    let mapData = try JSONDecoder().decode(DungeonMapData.self, from: json, configuration: testContext)
    let map = DungeonMap(data: mapData)

    #expect(map.rooms.count == 1)
    #expect(map.hallways.count == 1)
    #expect(map.doors.count == 1)

    #expect(map.decodingIssues.count == 3)
    #expect(map.decodingIssues[0] == DecodingIssue(kind: .room, index: 1, reason: "no edges, and no location/size pair"))
    #expect(map.decodingIssues[1] == DecodingIssue(kind: .hallway, index: 1, reason: "no edges and no segments"))
    #expect(map.decodingIssues[2] == DecodingIssue(kind: .door, index: 1, reason: "missing required fields for kind door"))
}

@Test func decodingIssuesEmptyWhenEverythingDecodes() throws {
    guard let url = Bundle.module.url(forResource: "SampleMap", withExtension: "json") else {
        Issue.record("SampleMap.json not found in test bundle"); return
    }
    let data = try Data(contentsOf: url)
    let dungeonData = try JSONDecoder().decode(DungeonData.self, from: data, configuration: testContext)
    let map = DungeonMap(data: dungeonData.maps[0])
    #expect(map.decodingIssues.isEmpty)
}

// MARK: - Treasure & encounter coding

@Test func treasureItemCodingRoundTrips() throws {
    let json = """
    { "name": "Bronze key", "quantity": 2, "value": "5 gp", "keyID": "portcullis-bronze-key", "isMagic": false, "notes": "Open the portcullises at 9." }
    """.data(using: .utf8)!
    let item = try JSONDecoder().decode(TreasureItem.self, from: json, configuration: testContext)
    #expect(item.quantity.constant == 2)
    #expect(item.value?[testContext.currencies["gp"]!] == 5)
    #expect(item.keyID == "portcullis-bronze-key")
    #expect(item.isMagic == false)

    let defaultItem = TreasureItem(name: "Potion of Healing")
    let encoded = try JSONEncoder().encode(defaultItem, configuration: testContext)
    let obj = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    #expect(Array(obj?.keys ?? [:].keys) == ["name"])
}

@Test func treasureRejectsUnknownCurrency() throws {
    let json = #"{"coins": {"zz": 1}}"#.data(using: .utf8)!
    #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(Treasure.self, from: json, configuration: testContext)
    }
}

@Test func encounterDecodesIntegerAndDiceCounts() throws {
    let intJSON = #"{"name": "Orc", "count": 6}"#.data(using: .utf8)!
    let intEncounter = try JSONDecoder().decode(RoomEncounter.self, from: intJSON, configuration: testContext)
    #expect(intEncounter.count.constant == 6)

    let diceJSON = #"{"name": "Orc", "count": "4d2+4"}"#.data(using: .utf8)!
    let diceEncounter = try JSONDecoder().decode(RoomEncounter.self, from: diceJSON, configuration: testContext)
    #expect(diceEncounter.count.constant == nil)
}

@Test func roomIDsAreUniquePerMap() throws {
    let names = ["SampleMap", "TestHallways", "Swamp King Lair Level 1"]
    for name in names {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            Issue.record("\(name).json not found in test bundle")
            continue
        }
        let data = try Data(contentsOf: url)
        let dungeonData = try JSONDecoder().decode(DungeonData.self, from: data, configuration: testContext)
        for mapData in dungeonData.maps {
            let map = DungeonMap(data: mapData)
            let ids = map.rooms.map(\.id)
            #expect(Set(ids).count == ids.count, "Duplicate room id in map \(map.id) of \(name).json")
        }
    }
}

// MARK: - DungeonConnectivity

/// Builds a `DungeonDoor` from two edge points via JSON round-trip through `DoorData`.
private func makeDoor(left: MapPoint, right: MapPoint, kind: String, attributes: [String] = [], keyID: String? = nil) -> DungeonDoor? {
    var dict: [String: Any] = [
        "leftEdge": ["x": left.x, "y": left.y],
        "rightEdge": ["x": right.x, "y": right.y],
        "kind": kind
    ]
    if !attributes.isEmpty { dict["attributes"] = attributes }
    if let keyID { dict["keyID"] = keyID }
    guard let data = try? JSONSerialization.data(withJSONObject: dict),
          let doorData = try? JSONDecoder().decode(DoorData.self, from: data) else { return nil }
    return DungeonDoor(doorData: doorData)
}

/// Builds a path-based `DungeonDoor` (staircase, passage) from segments via JSON round-trip.
private func makeSegmentDoor(kind: String, segments: [MapPoint], width: Double, attributes: [String] = []) -> DungeonDoor? {
    var dict: [String: Any] = [
        "kind": kind,
        "segments": segments.map { ["x": $0.x, "y": $0.y] },
        "width": width
    ]
    if !attributes.isEmpty { dict["attributes"] = attributes }
    guard let data = try? JSONSerialization.data(withJSONObject: dict),
          let doorData = try? JSONDecoder().decode(DoorData.self, from: data) else { return nil }
    return DungeonDoor(doorData: doorData)
}

/// Sum of segment lengths along a polyline.
private func totalLength(_ points: [MapPoint]) -> Double {
    guard points.count >= 2 else { return 0 }
    var total = 0.0
    for i in 1..<points.count { total += (points[i] - points[i - 1]).length() }
    return total
}

/// Point equality with a tolerance, since cut points are computed via floating-point arithmetic.
private func approx(_ a: MapPoint, _ b: MapPoint, tolerance: Double = 1e-6) -> Bool {
    abs(a.x - b.x) < tolerance && abs(a.y - b.y) < tolerance
}

@Test func connectivityDerivesConnectionsFromSampleMap() throws {
    guard let url = Bundle.module.url(forResource: "SampleMap", withExtension: "json") else {
        Issue.record("SampleMap.json not found"); return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let map = dungeon.maps[0]
    let graph = DungeonConnectivity(map: map)

    // SampleMap has 8 doors; all connect interior rooms/hallways with no exterior openings.
    #expect(graph.connections.count == 8)
    #expect(graph.entranceDoors.isEmpty)

    // Door 0 (isLocked) at (2,2)-(2,3): connects Room 0 (x∈[0,2]) and Room 1 (x∈[2,6]).
    let conn0 = try #require(graph.connections.first(where: { $0.door === map.doors[0] }))
    let room0 = map.rooms[0]
    let room1 = map.rooms[1]
    let ids = Set([ObjectIdentifier(conn0.from), ObjectIdentifier(conn0.to)])
    #expect(ids.contains(ObjectIdentifier(room0)))
    #expect(ids.contains(ObjectIdentifier(room1)))
    #expect(conn0.keyGated == true)
    #expect(conn0.secretGated == false)
    #expect(conn0.isOneWay == false)
    #expect(conn0.keyID == "guard-key")
}

@Test func connectivityAdjacencyCollapsingHallway() {
    // RoomA (x∈[0,4]) — door — Hallway (x∈[4,8], y∈[2,3]) — door — RoomB (x∈[8,12]).
    // adjacentRooms(to: roomA) must contain roomB (hallway collapsed), not the hallway itself.
    let map = DungeonMap(index: 1)
    let roomA = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    let roomB = DungeonRoom(location: MapPoint(x: 8, y: 0), size: MapSize(width: 4, height: 4))
    // Segments are the left (north) side; width extends south (+y), so hallway covers y∈[2,3].
    let hallway = DungeonHallway(segments: [MapPoint(x: 4, y: 2), MapPoint(x: 8, y: 2)], width: 1.0)
    map.addRoom(roomA); map.addRoom(roomB); map.addHallway(hallway)

    // Door at x=4, y∈[2,3]: fromArea centroid (3.5,2.5)→RoomA; toArea centroid (4.5,2.5)→Hallway.
    if let d = makeDoor(left: MapPoint(x: 4, y: 2), right: MapPoint(x: 4, y: 3), kind: "opening") { map.addDoor(d) }
    // Door at x=8, y∈[2,3]: fromArea centroid (7.5,2.5)→Hallway; toArea centroid (8.5,2.5)→RoomB.
    if let d = makeDoor(left: MapPoint(x: 8, y: 2), right: MapPoint(x: 8, y: 3), kind: "opening") { map.addDoor(d) }

    let graph = DungeonConnectivity(map: map)
    #expect(graph.connections.count == 2)
    let adjA = graph.adjacentRooms(to: roomA)
    let adjB = graph.adjacentRooms(to: roomB)
    #expect(adjA.contains(where: { $0 === roomB }))
    #expect(adjB.contains(where: { $0 === roomA }))
    #expect(!adjA.contains(where: { $0 === hallway }))   // hallway is collapsed, not listed
}

@Test func connectivityReachabilityAndClassify() {
    // RoomA — locked door — RoomB — open door — RoomC; RoomD isolated.
    let map = DungeonMap(index: 1)
    let roomA = DungeonRoom(location: MapPoint(x: 0,  y: 0), size: MapSize(width: 3, height: 3))
    let roomB = DungeonRoom(location: MapPoint(x: 3,  y: 0), size: MapSize(width: 3, height: 3))
    let roomC = DungeonRoom(location: MapPoint(x: 6,  y: 0), size: MapSize(width: 3, height: 3))
    let roomD = DungeonRoom(location: MapPoint(x: 20, y: 0), size: MapSize(width: 3, height: 3))
    [roomA, roomB, roomC, roomD].forEach { map.addRoom($0) }

    // Locked door at x=3 between RoomA and RoomB; open door at x=6 between RoomB and RoomC.
    if let d = makeDoor(left: MapPoint(x: 3, y: 1), right: MapPoint(x: 3, y: 2), kind: "door", attributes: ["isLocked"]) { map.addDoor(d) }
    if let d = makeDoor(left: MapPoint(x: 6, y: 1), right: MapPoint(x: 6, y: 2), kind: "opening") { map.addDoor(d) }

    let graph = DungeonConnectivity(map: map)

    // Without keys from RoomA: only RoomA reachable.
    let freeFromA = graph.reachable(from: roomA, traversal: .keyless)
    #expect(freeFromA.count == 1)
    #expect(freeFromA.contains(ObjectIdentifier(roomA)))

    // With all gates open from RoomA: A, B, C reachable; D isolated.
    let allFromA = graph.reachable(from: roomA, traversal: .allGatesOpen)
    #expect(allFromA.count == 3)
    #expect(!allFromA.contains(ObjectIdentifier(roomD)))

    // classify: A=reachable, B/C=keyGated, D=unreachable.
    let status = graph.classify(from: roomA)
    #expect(status[ObjectIdentifier(roomA)] == .reachable)
    #expect(status[ObjectIdentifier(roomB)] == .keyGated)
    #expect(status[ObjectIdentifier(roomC)] == .keyGated)
    #expect(status[ObjectIdentifier(roomD)] == .unreachable)
}

@Test func connectivityOneWayDoor() {
    // RoomA — one-way door → RoomB: A reaches B but B cannot reach A (one-way respected).
    let map = DungeonMap(index: 1)
    let roomA = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 3, height: 3))
    let roomB = DungeonRoom(location: MapPoint(x: 3, y: 0), size: MapSize(width: 3, height: 3))
    [roomA, roomB].forEach { map.addRoom($0) }
    if let d = makeDoor(left: MapPoint(x: 3, y: 1), right: MapPoint(x: 3, y: 2), kind: "door", attributes: ["isOneWay"]) { map.addDoor(d) }

    let graph = DungeonConnectivity(map: map)
    let conn = try! #require(graph.connections.first)
    #expect(conn.isOneWay == true)

    // The "from" side (fromArea centroid x<3) is RoomA; "to" side is RoomB.
    let fromSource = graph.reachable(from: conn.from, traversal: .keyless)
    #expect(fromSource.contains(ObjectIdentifier(conn.to)))

    // Reverse traversal is blocked by one-way.
    let fromDest = graph.reachable(from: conn.to, traversal: .keyless)
    #expect(!fromDest.contains(ObjectIdentifier(conn.from)))

    // With respectsOneWay=false, reverse works.
    let fromDestOpen = graph.reachable(from: conn.to, traversal: .allGatesOpen)
    #expect(fromDestOpen.contains(ObjectIdentifier(conn.from)))
}

@Test func connectivityEntranceDoor() {
    // Room with a door on its left wall (x=2). The exterior probe (1.5,3.5) finds no node.
    let map = DungeonMap(index: 1)
    let room = DungeonRoom(location: MapPoint(x: 2, y: 2), size: MapSize(width: 4, height: 4))
    map.addRoom(room)
    // Door at leftEdge (2,3), rightEdge (2,4): fromArea centroid (1.5,3.5) exterior, toArea (2.5,3.5) interior.
    if let d = makeDoor(left: MapPoint(x: 2, y: 3), right: MapPoint(x: 2, y: 4), kind: "opening") { map.addDoor(d) }

    let graph = DungeonConnectivity(map: map)
    #expect(graph.connections.isEmpty)
    #expect(graph.entrances().count == 1)
}

@Test func connectivityTreatsConnectionDoorsAsPortals() throws {
    // A staircase with a remote connection, drawn wholly inside one room, must become a
    // portal and never a self-connection, even though both probes resolve to the same room.
    let map = DungeonMap(index: 1)
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 10, height: 10))
    map.addRoom(room)

    let json = """
    { "kind": "staircase", "width": 1.0, "segments": [{"x": 3, "y": 3}, {"x": 3, "y": 6}],
      "connection": {"mapID": "other_map", "end": {"x": 0, "y": 0}} }
    """.data(using: .utf8)!
    let doorData = try JSONDecoder().decode(DoorData.self, from: json)
    let door = try #require(DungeonDoor(doorData: doorData))
    map.addDoor(door)

    let graph = DungeonConnectivity(map: map)
    #expect(graph.connections.isEmpty)
    #expect(graph.portalDoors.count == 1)
}

@Test func connectivityHeldKeysOpenMatchingDoorsOnly() throws {
    // RoomA — locked door (keyID "a") — RoomB — locked door (keyID "b") — RoomC.
    let map = DungeonMap(index: 1)
    let roomA = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 3, height: 3))
    let roomB = DungeonRoom(location: MapPoint(x: 3, y: 0), size: MapSize(width: 3, height: 3))
    let roomC = DungeonRoom(location: MapPoint(x: 6, y: 0), size: MapSize(width: 3, height: 3))
    [roomA, roomB, roomC].forEach { map.addRoom($0) }

    if let d = makeDoor(left: MapPoint(x: 3, y: 1), right: MapPoint(x: 3, y: 2), kind: "door", attributes: ["isLocked"], keyID: "a") { map.addDoor(d) }
    if let d = makeDoor(left: MapPoint(x: 6, y: 1), right: MapPoint(x: 6, y: 2), kind: "door", attributes: ["isLocked"], keyID: "b") { map.addDoor(d) }

    let graph = DungeonConnectivity(map: map)
    let traversal = Traversal(opensLocks: false, opensSecrets: false, respectsOneWay: true, heldKeys: ["a"])
    let reached = graph.reachable(from: roomA, traversal: traversal)
    #expect(reached.contains(ObjectIdentifier(roomA)))
    #expect(reached.contains(ObjectIdentifier(roomB)))
    #expect(!reached.contains(ObjectIdentifier(roomC)))
}

// MARK: - Key progression

@Test func sampleMapKeyProgression() throws {
    guard let url = Bundle.module.url(forResource: "SampleMap", withExtension: "json") else {
        Issue.record("SampleMap.json not found"); return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let map = dungeon.maps[0]
    let graph = DungeonConnectivity(map: map)
    let start = try #require(map.room(withID: "3"))
    let progression = graph.keyProgression(from: start)

    #expect(progression.steps.count == 2)
    #expect(progression.steps[0].roomsReached.map(\.id) == ["2", "3", "4", "5"])
    #expect(progression.steps[0].keysFound.map(\.keyID) == ["guard-key"])
    #expect(progression.steps[0].keysFound.first?.room.id == "2")
    #expect(progression.steps[1].roomsReached.map(\.id) == ["1"])
    #expect(progression.steps[1].doorsOpened.count == 1)
    #expect(progression.steps[1].keysFound.isEmpty)
    #expect(progression.lockedOut.isEmpty)
    #expect(progression.unopenedDoors.count == 1)
}

// MARK: - Swamp King Lair Level 1 (reference file)

@Test func swampKingDecodes() throws {
    guard let url = Bundle.module.url(forResource: "Swamp King Lair Level 1", withExtension: "json") else {
        Issue.record("Swamp King Lair Level 1.json not found in test bundle")
        return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    #expect(dungeon.maps.count == 2)
    #expect(dungeon.maps[0].id == "first_level")
    #expect(dungeon.maps[1].id == "tower_top")

    let firstLevel = dungeon.maps[0]
    #expect(firstLevel.rooms.count == 42)
    #expect(firstLevel.hallways.count == 19)
    #expect(firstLevel.doors.count == 73)

    let graph = DungeonConnectivity(map: firstLevel)
    #expect(graph.connections.count == 70)
    #expect(graph.entranceDoors.count == 1)
    #expect(graph.portalDoors.count == 2)
    #expect(graph.keyIDsWithoutKeys.isEmpty)

    let room18A = try #require(firstLevel.room(withID: "18A"))
    #expect(room18A.keyIDs == ["store-gold-key", "store-silver-key", "store-bronze-key", "store-iron-key"])

    let room4 = try #require(firstLevel.room(withID: "4"))
    #expect(room4.treasure?.coins.description == "d10 gp 2d8 sp")

    let room8 = try #require(firstLevel.room(withID: "8"))
    let carried = try #require(room8.encounters.first?.carried)
    #expect(carried.items.count == 4)
    #expect(carried.items[0].quantity.constant == 2)
    #expect(carried.items[0].keyID == "portcullis-bronze-key")

    #expect(graph.doors(openedBy: "store-iron-key").count == 6)
    #expect(graph.doors(openedBy: "portcullis-bronze-key").count == 2)
}

@Test func swampKingRoomText() throws {
    guard let url = Bundle.module.url(forResource: "Swamp King Lair Level 1", withExtension: "json") else {
        Issue.record("Swamp King Lair Level 1.json not found in test bundle")
        return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let firstLevel = try #require(dungeon.maps.first(where: { $0.id == "first_level" }))

    let room1 = try #require(firstLevel.room(withID: "1"))
    #expect(room1.readAloud?.hasPrefix("This 30x30") == true)
    #expect(room1.gmNotes?.contains("1-3 on d10") == true)

    let entrance = try #require(firstLevel.room(withID: "entrance"))
    #expect(entrance.gmNotes?.contains("\n") == true)

    let room18A = try #require(firstLevel.room(withID: "18A"))
    #expect(room18A.readAloud == nil)
    #expect(room18A.gmNotes?.contains("ANY IRON KEY OPENS ROOMS 19 thru 22") == true)

    for room in firstLevel.rooms where room.keyNumber != nil {
        if room.id == "17-pools" {
            #expect(room.readAloud == nil)
            #expect(room.gmNotes == nil)
        } else {
            #expect(room.readAloud != nil || room.gmNotes != nil, "Room \(room.id) has a keyNumber but no readAloud or gmNotes")
        }
    }
}

@Test func swampKingKeyProgression() throws {
    guard let url = Bundle.module.url(forResource: "Swamp King Lair Level 1", withExtension: "json") else {
        Issue.record("Swamp King Lair Level 1.json not found in test bundle")
        return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let map = dungeon.maps[0]
    let graph = DungeonConnectivity(map: map)
    let start = try #require(map.room(withID: "entrance"))

    // findsSecrets: true
    do {
        let progression = graph.keyProgression(from: start, findsSecrets: true)
        #expect(progression.steps.count == 3)

        let step0RoomIDs = ["entrance", "1", "2", "3", "4", "5", "7", "10", "11", "12", "12A", "12B", "12C", "12D", "12E", "13", "14", "17", "17-pools", "18", "18A", "26"]
        #expect(progression.steps[0].roomsReached.map(\.id) == step0RoomIDs)

        let step0Keys = Dictionary(uniqueKeysWithValues: progression.steps[0].keysFound.map { ($0.keyID, $0.room.id) })
        #expect(step0Keys["brass-key"] == "4")
        #expect(step0Keys["storeroom-iron-key"] == "5")
        #expect(step0Keys["watch-silver-key"] == "7")
        #expect(step0Keys["store-gold-key"] == "18A")
        #expect(step0Keys["store-silver-key"] == "18A")
        #expect(step0Keys["store-bronze-key"] == "18A")
        #expect(step0Keys["store-iron-key"] == "18A")
        #expect(step0Keys.count == 7)
        #expect(progression.steps[0].keysFound.first?.keyID == "brass-key")

        #expect(progression.steps[1].doorsOpened.count == 13)
        let step1RoomIDs = ["6", "8", "9", "9A", "9B", "19", "20", "21", "22", "23", "24", "25", "27", "28", "29", "30", "31", "32"]
        #expect(progression.steps[1].roomsReached.map(\.id) == step1RoomIDs)
        #expect(progression.steps[1].keysFound.map(\.keyID) == ["portcullis-bronze-key"])
        #expect(progression.steps[1].keysFound.first?.room.id == "8")

        #expect(progression.steps[2].doorsOpened.map(\.name) == ["Feeding hatch, 9A", "Feeding hatch, 9B"])
        #expect(progression.steps[2].roomsReached.isEmpty)
        #expect(progression.steps[2].keysFound.isEmpty)

        #expect(progression.lockedOut.map(\.id) == ["15", "16"])
        #expect(progression.unopenedDoors.map(\.name) == ["Leader's door"])
    }

    // findsSecrets: false
    do {
        let progression = graph.keyProgression(from: start, findsSecrets: false)
        #expect(progression.steps.count == 2)

        let step0RoomIDs = ["entrance", "1", "2", "3", "4", "5", "7", "10", "11", "12", "12A", "12B", "12C", "12D", "12E", "13", "14", "17", "17-pools", "18", "26"]
        #expect(progression.steps[0].roomsReached.map(\.id) == step0RoomIDs)
        let step0Keys = Dictionary(uniqueKeysWithValues: progression.steps[0].keysFound.map { ($0.keyID, $0.room.id) })
        #expect(step0Keys["brass-key"] == "4")
        #expect(step0Keys["storeroom-iron-key"] == "5")
        #expect(step0Keys["watch-silver-key"] == "7")
        #expect(step0Keys.count == 3)
        #expect(progression.steps[0].keysFound.first?.keyID == "brass-key")

        #expect(progression.steps[1].doorsOpened.count == 2)
        #expect(progression.steps[1].roomsReached.map(\.id) == ["6", "8"])
        #expect(progression.steps[1].keysFound.map(\.keyID) == ["portcullis-bronze-key"])

        let lockedOutIDs: Set<String> = ["9", "9A", "9B", "15", "16", "18A", "19", "20", "21", "22", "23", "24", "25", "27", "28", "29", "30", "31", "32"]
        #expect(Set(progression.lockedOut.map(\.id)) == lockedOutIDs)
    }

    // One-way portcullises both go from room 9 into the pens.
    let portcullis9A = try #require(graph.doors.first(where: { $0.name == "Portcullis, 9A (raised by the levers)" }))
    let portcullis9B = try #require(graph.doors.first(where: { $0.name == "Portcullis, 9B (raised by the levers)" }))
    for door in [portcullis9A, portcullis9B] {
        let conn = try #require(graph.connections.first(where: { $0.door === door }))
        #expect(conn.from.id == "9")
    }
}

@Test func swampKingRoundTrips() throws {
    guard let url = Bundle.module.url(forResource: "Swamp King Lair Level 1", withExtension: "json") else {
        Issue.record("Swamp King Lair Level 1.json not found in test bundle")
        return
    }
    let data = try Data(contentsOf: url)
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let encoded = try dungeon.encoded(context: testContext)
    let dungeonData2 = try JSONDecoder().decode(DungeonData.self, from: encoded, configuration: testContext)

    for (mapIndex, map) in dungeon.maps.enumerated() {
        let map2 = DungeonMap(data: dungeonData2.maps[mapIndex])
        #expect(map2.rooms.count == map.rooms.count)
        #expect(map2.hallways.count == map.hallways.count)
        #expect(map2.doors.count == map.doors.count)
        #expect(map2.sections == map.sections)

        for room in map.rooms {
            let room2 = try #require(map2.room(withID: room.id))
            #expect(room2.name == room.name, "room \(room.id) name")
            #expect(room2.keyNumber == room.keyNumber, "room \(room.id) keyNumber")
            #expect(room2.readAloud == room.readAloud, "room \(room.id) readAloud")
            #expect(room2.gmNotes == room.gmNotes, "room \(room.id) gmNotes")
            #expect(room2.contentTags == room.contentTags, "room \(room.id) contentTags")
            #expect(room2.sectionID == room.sectionID, "room \(room.id) section")
            #expect(room2.shape == room.shape, "room \(room.id) shape")
            #expect(room2.walls == room.walls, "room \(room.id) walls")
            #expect(room2.encounters == room.encounters, "room \(room.id) encounters")
            #expect(room2.treasure == room.treasure, "room \(room.id) treasure")
            #expect(room2.features == room.features, "room \(room.id) features")
            #expect(room2.occupancy == room.occupancy, "room \(room.id) occupancy")
            #expect(room2.occupancy?.tableRoomID == room.occupancy?.tableRoomID, "room \(room.id) occupancy.tableRoomID")
            #expect(room2.labelLocation == room.labelLocation, "room \(room.id) labelLocation")
        }

        for (hallway, hallway2) in zip(map.hallways, map2.hallways) {
            #expect(hallway2.name == hallway.name)
            #expect(hallway2.segments == hallway.segments)
            #expect(hallway2.width == hallway.width)
            #expect(hallway2.edges == hallway.edges)
        }

        for (door, door2) in zip(map.doors, map2.doors) {
            let label = door.name ?? door.id
            #expect(door2.kind == door.kind, "door \(label) kind")
            #expect(door2.attributes == door.attributes, "door \(label) attributes")
            #expect(door2.keyID == door.keyID, "door \(label) keyID")
            #expect(door2.stairDirection == door.stairDirection, "door \(label) stairDirection")
            #expect(door2.connection?.mapID == door.connection?.mapID, "door \(label) connection.mapID")
            #expect(door2.connection?.end == door.connection?.end, "door \(label) connection.end")
            #expect(door2.leftEdge == door.leftEdge, "door \(label) leftEdge")
            #expect(door2.rightEdge == door.rightEdge, "door \(label) rightEdge")
            #expect(door2.edges == door.edges, "door \(label) edges")
            #expect(door2.segments == door.segments, "door \(label) segments")
            #expect(door2.location == door.location, "door \(label) location")
            #expect(door2.size == door.size, "door \(label) size")
            #expect(door2.rotation == door.rotation, "door \(label) rotation")
        }
    }

    // Second check: report (do not fail on) any key the encoder dropped, other than
    // zero-valued defaults that are legitimately omitted.
    let original = try JSONSerialization.jsonObject(with: data)
    let reencoded = try JSONSerialization.jsonObject(with: encoded)
    let dropped = droppedKeyPaths(original: original, reencoded: reencoded)
    if !dropped.isEmpty {
        print("swampKingRoundTrips: keys dropped by round-trip: \(dropped.sorted())")
    }
}

/// Key paths present in `original` but absent from `reencoded` at the matching structural
/// position, excluding keys whose original value is a "zero" default (0, false, "", [], {}, null)
/// that is legitimately omitted on encode.
private func droppedKeyPaths(original: Any, reencoded: Any, path: String = "") -> [String] {
    if let originalDict = original as? [String: Any] {
        let reencodedDict = reencoded as? [String: Any] ?? [:]
        var dropped: [String] = []
        for (key, value) in originalDict {
            let keyPath = path.isEmpty ? key : "\(path).\(key)"
            if let matchingValue = reencodedDict[key] {
                dropped += droppedKeyPaths(original: value, reencoded: matchingValue, path: keyPath)
            } else if !isZeroDefault(value) {
                dropped.append(keyPath)
            }
        }
        return dropped
    }
    if let originalArray = original as? [Any] {
        let reencodedArray = reencoded as? [Any] ?? []
        var dropped: [String] = []
        for (index, value) in originalArray.enumerated() where index < reencodedArray.count {
            dropped += droppedKeyPaths(original: value, reencoded: reencodedArray[index], path: "\(path)[\(index)]")
        }
        return dropped
    }
    return []
}

private func isZeroDefault(_ value: Any) -> Bool {
    switch value {
    case let number as NSNumber:
        return number == 0 || number == false
    case let string as String:
        return string.isEmpty
    case let array as [Any]:
        return array.isEmpty
    case let dict as [String: Any]:
        return dict.isEmpty
    case is NSNull:
        return true
    default:
        return false
    }
}

// MARK: - Stat lines (Prompt 8)

@Test func sampleMapStatLines() throws {
    guard let url = Bundle.module.url(forResource: "SampleMap", withExtension: "json") else {
        Issue.record("SampleMap.json not found in test bundle")
        return
    }
    let data = try Data(contentsOf: url)
    let dungeonData = try JSONDecoder().decode(DungeonData.self, from: data, configuration: testContext)
    let map = DungeonMap(data: dungeonData.maps[0])

    let goblin = try #require(map.rooms[1].encounters.first)
    let stats = try #require(goblin.stats)
    #expect(stats.armorClass == 13)
    #expect(stats.damage.map(\.description) == ["d6+2"])
}

@Test func swampKingStatLines() throws {
    guard let url = Bundle.module.url(forResource: "Swamp King Lair Level 1", withExtension: "json") else {
        Issue.record("Swamp King Lair Level 1.json not found in test bundle")
        return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let firstLevel = try #require(dungeon.maps.first(where: { $0.id == "first_level" }))
    let allEncounters = firstLevel.rooms.flatMap(\.encounters)
    #expect(allEncounters.count == 44)
    #expect(allEncounters.filter { $0.stats != nil }.count == 37)

    let room23 = try #require(firstLevel.room(withID: "23"))
    let stonewaders = try #require(room23.encounters.first?.stats)
    #expect(stonewaders.hitPoints == [6, 5, 5, 5, 5])
    #expect(stonewaders.hitPoints(forCreatureAt: 4) == 5)
    #expect(stonewaders.armorClass == 2)
    #expect(stonewaders.attacks == 2)

    let room13 = try #require(firstLevel.room(withID: "13"))
    let centipedes = try #require(room13.encounters.first?.stats)
    #expect(centipedes.hitDice == "1/4")
    #expect(centipedes.special == "poison")

    let room14 = try #require(firstLevel.room(withID: "14"))
    let guards = try #require(room14.encounters.first?.stats)
    #expect(guards.damage.map(\.description) == ["d6", "2d4"])

    let room28 = try #require(firstLevel.room(withID: "28"))
    let burningCoins = try #require(room28.encounters.first?.stats)
    #expect(burningCoins.text?.contains("until washed with water") == true)

    for encounter in allEncounters {
        if let text = encounter.stats?.text {
            #expect(!text.isEmpty, "Encounter \(encounter.name) has empty stats.text")
        }
    }
}

// MARK: - Sections (Prompt 6)

@Test func sectionsDecodeAndGroupRooms() throws {
    guard let url = Bundle.module.url(forResource: "SampleMap", withExtension: "json") else {
        Issue.record("SampleMap.json not found in test bundle"); return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let map = dungeon.maps[0]

    #expect(map.sections.count == 2)
    let gatehouse = try #require(map.sections.first(where: { $0.id == "gatehouse" }))
    let warrens = try #require(map.sections.first(where: { $0.id == "warrens" }))

    #expect(map.rooms(in: gatehouse).map(\.id) == ["1", "3"])
    #expect(map.rooms(in: warrens).map(\.id) == ["2", "5"])
    #expect(map.unsectionedRooms.map(\.id) == ["4"])
    #expect(map.unknownSectionIDs.isEmpty)
}

@Test func removingSectionClearsRoomSectionIDs() throws {
    guard let url = Bundle.module.url(forResource: "SampleMap", withExtension: "json") else {
        Issue.record("SampleMap.json not found in test bundle"); return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let map = dungeon.maps[0]
    let gatehouse = try #require(map.sections.first(where: { $0.id == "gatehouse" }))

    map.removeSection(gatehouse)

    #expect(map.sections.map(\.id) == ["warrens"])
    #expect(map.room(withID: "1")?.sectionID == nil)
    #expect(map.room(withID: "3")?.sectionID == nil)
    #expect(map.room(withID: "2")?.sectionID == "warrens")
}

@Test func unknownSectionIDsReportsDanglingReferences() {
    let map = DungeonMap(index: 1)
    let room1 = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 2, height: 2))
    room1.sectionID = "ghost-section"
    let room2 = DungeonRoom(location: MapPoint(x: 5, y: 5), size: MapSize(width: 2, height: 2))
    room2.sectionID = "declared"
    map.addRoom(room1)
    map.addRoom(room2)
    map.addSection(DungeonSection(id: "declared", name: "Declared Section"))

    #expect(map.unknownSectionIDs == ["ghost-section"])
}

@Test func swampKingSections() throws {
    guard let url = Bundle.module.url(forResource: "Swamp King Lair Level 1", withExtension: "json") else {
        Issue.record("Swamp King Lair Level 1.json not found in test bundle"); return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let firstLevel = try #require(dungeon.maps.first(where: { $0.id == "first_level" }))
    let towerTop = try #require(dungeon.maps.first(where: { $0.id == "tower_top" }))

    #expect(firstLevel.sections.map(\.name) == ["Lair of the Bracken-folk", "Lair of the Glubbins", "Storage Rooms"])

    let brackenFolk = try #require(firstLevel.sections.first(where: { $0.name == "Lair of the Bracken-folk" }))
    let glubbins = try #require(firstLevel.sections.first(where: { $0.name == "Lair of the Glubbins" }))
    let storage = try #require(firstLevel.sections.first(where: { $0.name == "Storage Rooms" }))

    #expect(firstLevel.rooms(in: brackenFolk).map(\.id) == ["2", "3", "4", "5", "6", "7", "8", "9", "9A", "9B"])
    #expect(firstLevel.rooms(in: glubbins).map(\.id) == ["10", "11", "12", "12A", "12B", "12C", "12D", "12E", "13", "14", "15", "16"])

    let storageRooms = firstLevel.rooms(in: storage)
    #expect(storageRooms.count == 18)
    #expect(storageRooms.first?.id == "17")
    #expect(storageRooms.last?.id == "32")

    #expect(firstLevel.unsectionedRooms.map(\.id) == ["entrance", "1"])
    #expect(firstLevel.unknownSectionIDs.isEmpty)

    #expect(towerTop.sections.isEmpty)
}

// MARK: - Room features (Prompt 7)

@Test func featureCodingRoundTrips() throws {
    let json = """
    {
        "id": "17A",
        "kind": "lever",
        "name": "Blue wooden lever",
        "location": { "x": 10.5, "y": 11.5 },
        "gmNotes": "When it is up (as it normally is), the water level is up to 10', and when it is down, so is the water."
    }
    """.data(using: .utf8)!
    let feature = try JSONDecoder().decode(RoomFeature.self, from: json, configuration: testContext)
    #expect(feature.id == "17A")
    #expect(feature.kind == .lever)
    #expect(feature.name == "Blue wooden lever")
    #expect(feature.location == MapPoint(x: 10.5, y: 11.5))
    #expect(feature.gmNotes?.hasPrefix("When it is up") == true)
    #expect(feature.treasure == nil)

    let encoded = try JSONEncoder().encode(feature, configuration: testContext)
    let decoded = try JSONDecoder().decode(RoomFeature.self, from: encoded, configuration: testContext)
    #expect(decoded == feature)

    let missingLocation = """
    { "id": "17A", "kind": "lever" }
    """.data(using: .utf8)!
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(RoomFeature.self, from: missingLocation, configuration: testContext)
    }
}

@Test func featureSizeRoundTrips() throws {
    let json = """
    { "id": "13-pit", "kind": "pit", "name": "Pit", "location": { "x": 9.5, "y": 7.5 }, "size": { "width": 1.0, "height": 1.0 } }
    """.data(using: .utf8)!
    let feature = try JSONDecoder().decode(RoomFeature.self, from: json, configuration: testContext)
    #expect(feature.size == MapSize(width: 1.0, height: 1.0))
    let footprint = try #require(feature.footprint)
    #expect(footprint.origin == MapPoint(x: 9, y: 7))
    #expect(footprint.size == MapSize(width: 1.0, height: 1.0))

    let encoded = try JSONEncoder().encode(feature, configuration: testContext)
    let decoded = try JSONDecoder().decode(RoomFeature.self, from: encoded, configuration: testContext)
    #expect(decoded == feature)

    let pointFeature = RoomFeature(id: "17A", kind: .lever, location: MapPoint(x: 10.5, y: 11.5))
    #expect(pointFeature.footprint == nil)
    let pointEncoded = try JSONEncoder().encode(pointFeature, configuration: testContext)
    let pointJSON = try #require(String(data: pointEncoded, encoding: .utf8))
    #expect(!pointJSON.contains("size"))
}

@Test func keyLabelIsIDForModuleKeys() {
    let feature = RoomFeature(id: "17A", kind: .lever, location: MapPoint(x: 0, y: 0))
    #expect(feature.keyLabel == "17A")
}

@Test func keyLabelIsNilForGeneratedIDs() {
    let feature = RoomFeature(id: "13-pit", kind: .pit, location: MapPoint(x: 0, y: 0))
    #expect(feature.keyLabel == nil)
}

@Test func translateMovesFeatures() {
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 10, height: 10))
    room.features = [RoomFeature(id: "f1", kind: .lever, location: MapPoint(x: 2, y: 3))]
    let delta = MapPoint(x: 5, y: 1)
    room.translate(by: delta)
    #expect(room.features[0].location == MapPoint(x: 7, y: 4))
}

@Test func sampleMapFeatures() throws {
    guard let url = Bundle.module.url(forResource: "SampleMap", withExtension: "json") else {
        Issue.record("SampleMap.json not found in test bundle"); return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let map = dungeon.maps[0]
    let gp = testContext.currencies["gp"]!

    let room2 = try #require(map.room(withID: "2"))
    #expect(room2.features.count == 1)
    #expect(room2.features[0].treasure?.coins[gp]?.constant == 40)
    #expect(room2.treasure == nil)
}

@Test func swampKingFeatures() throws {
    guard let url = Bundle.module.url(forResource: "Swamp King Lair Level 1", withExtension: "json") else {
        Issue.record("Swamp King Lair Level 1.json not found in test bundle"); return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let firstLevel = try #require(dungeon.maps.first(where: { $0.id == "first_level" }))
    let towerTop = try #require(dungeon.maps.first(where: { $0.id == "tower_top" }))

    let totalFeatures = firstLevel.rooms.reduce(0) { $0 + $1.features.count }
    #expect(totalFeatures == 33)
    #expect(firstLevel.duplicateFeatureIDs.isEmpty)
    #expect(firstLevel.featuresOutsideTheirRooms.isEmpty)
    #expect(towerTop.duplicateFeatureIDs.isEmpty)
    #expect(towerTop.featuresOutsideTheirRooms.isEmpty)

    let room17 = try #require(firstLevel.room(withID: "17"))
    #expect(room17.features.map(\.id) == ["17A", "17B"])
    #expect(room17.features.allSatisfy { $0.kind == .lever })

    let room26 = try #require(firstLevel.room(withID: "26"))
    #expect(room26.features.map(\.id) == ["26A", "26B", "26C", "26D"])
    #expect(room26.features.map(\.name) == ["MUGAMBI", "GWTHPLK", "HHHWD", "ERRBOLK"])
    #expect(room26.features.allSatisfy { $0.kind == .idol })

    let room4 = try #require(firstLevel.room(withID: "4"))
    #expect(room4.features.filter { $0.kind == .area }.count == 4)
    let quarterD = try #require(room4.features.first(where: { $0.id == "4D" }))
    #expect(quarterD.treasure?.items.count == 1)
    #expect(quarterD.treasure?.items.first?.keyID == "brass-key")

    let found = try #require(firstLevel.feature(withID: "8-chest"))
    #expect(found.room.id == "8")
    #expect(found.feature.treasure?.coins.fixed?.totalValue == 57.75)
}

@Test func swampKingFeatureFootprints() throws {
    guard let url = Bundle.module.url(forResource: "Swamp King Lair Level 1", withExtension: "json") else {
        Issue.record("Swamp King Lair Level 1.json not found in test bundle"); return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let firstLevel = try #require(dungeon.maps.first(where: { $0.id == "first_level" }))

    let allFeatures = firstLevel.rooms.flatMap(\.features)
    #expect(allFeatures.count == 33)
    let sized = allFeatures.filter { $0.size != nil }
    #expect(sized.count == 7)

    let pools = allFeatures.filter { $0.kind == .pool }
    #expect(pools.count == 5)
    #expect(pools.allSatisfy { $0.size != nil })

    let room10 = try #require(firstLevel.room(withID: "10"))
    let room10Pools = room10.features.filter { $0.kind == .pool }
    #expect(room10Pools.count == 2)
    #expect(room10Pools.allSatisfy { $0.size == MapSize(width: 3.8, height: 0.8) })

    let poolRoom = try #require(firstLevel.room(withID: "17-pools"))
    let poolRoomPools = poolRoom.features.filter { $0.kind == .pool }
    #expect(poolRoomPools.count == 2)
    #expect(poolRoomPools.allSatisfy { $0.size == MapSize(width: 1.8, height: 1.8) })

    let pit = try #require(firstLevel.feature(withID: "13-pit"))
    #expect(pit.feature.size == MapSize(width: 1.0, height: 1.0))
    #expect(pit.feature.footprint?.origin == MapPoint(x: 9, y: 7))

    let spikes = try #require(firstLevel.feature(withID: "17-spikes"))
    #expect(spikes.feature.kind == .trap)
    #expect(spikes.feature.size == MapSize(width: 1.0, height: 2.0))
}

// MARK: - Wall runs (Prompt 3b)

@Test func wallRunsUncutRoomIsOneClosedRun() {
    let map = DungeonMap(index: 1)
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    map.addRoom(room)
    let runs = map.wallRuns(for: room, doorGapRatio: 0.7)
    #expect(runs.count == 1)
    #expect(runs[0].count == 5)
    #expect(runs[0].first == runs[0].last)
}

@Test func wallRunsOpeningRemovesWholeSpan() {
    let map = DungeonMap(index: 1)
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    map.addRoom(room)
    if let d = makeDoor(left: MapPoint(x: 4, y: 1), right: MapPoint(x: 4, y: 2), kind: "opening") { map.addDoor(d) }

    let runs = map.wallRuns(for: room, doorGapRatio: 0.7)
    #expect(runs.count == 1)
    let run = runs[0]
    #expect(approx(run.first!, MapPoint(x: 4, y: 2)))
    #expect(approx(run.last!, MapPoint(x: 4, y: 1)))
    #expect(abs(totalLength(run) - 15.0) < 1e-6)
}

@Test func wallRunsDoorRemovesCenteredFraction() {
    let map = DungeonMap(index: 1)
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    map.addRoom(room)
    if let d = makeDoor(left: MapPoint(x: 4, y: 1), right: MapPoint(x: 4, y: 2), kind: "door") { map.addDoor(d) }

    let runs = map.wallRuns(for: room, doorGapRatio: 0.7)
    #expect(runs.count == 1)
    let run = runs[0]
    #expect(approx(run.first!, MapPoint(x: 4, y: 1.85)))
    #expect(approx(run.last!, MapPoint(x: 4, y: 1.15)))
    #expect(abs(totalLength(run) - 15.3) < 1e-6)
}

@Test func wallRunsSecretDoorDoesNotCut() {
    let map = DungeonMap(index: 1)
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    map.addRoom(room)
    if let d = makeDoor(left: MapPoint(x: 4, y: 1), right: MapPoint(x: 4, y: 2), kind: "door", attributes: ["isSecret"]) { map.addDoor(d) }

    let runs = map.wallRuns(for: room, doorGapRatio: 0.7)
    #expect(runs.count == 1)
    #expect(runs[0].count == 5)
    #expect(runs[0].first == runs[0].last)
}

@Test func wallRunsTwoCutsOnOneEdge() {
    let map = DungeonMap(index: 1)
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    map.addRoom(room)
    if let d = makeDoor(left: MapPoint(x: 4, y: 0.5), right: MapPoint(x: 4, y: 1), kind: "opening") { map.addDoor(d) }
    if let d = makeDoor(left: MapPoint(x: 4, y: 2), right: MapPoint(x: 4, y: 2.5), kind: "opening") { map.addDoor(d) }

    let runs = map.wallRuns(for: room, doorGapRatio: 0.7)
    #expect(runs.count == 2)
    for run in runs {
        for i in 1..<run.count {
            #expect((run[i] - run[i - 1]).length() > 1e-6)
        }
    }
    let total = runs.reduce(0.0) { $0 + totalLength($1) }
    #expect(abs(total - 15.0) < 1e-6)
}

@Test func wallRunsCutAtCorner() {
    let map = DungeonMap(index: 1)
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    map.addRoom(room)
    if let d = makeDoor(left: MapPoint(x: 4, y: 0), right: MapPoint(x: 4, y: 1), kind: "opening") { map.addDoor(d) }

    let runs = map.wallRuns(for: room, doorGapRatio: 0.7)
    #expect(runs.count == 1)
    let run = runs[0]
    for i in 1..<run.count {
        #expect((run[i] - run[i - 1]).length() > 1e-6)
    }
    #expect(abs(totalLength(run) - 15.0) < 1e-6)
}

@Test func wallRunsWrapAround() {
    let map = DungeonMap(index: 1)
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    map.addRoom(room)
    if let d = makeDoor(left: MapPoint(x: 0, y: 2), right: MapPoint(x: 0, y: 3), kind: "opening") { map.addDoor(d) }

    let runs = map.wallRuns(for: room, doorGapRatio: 0.7)
    #expect(runs.count == 1)
    #expect(abs(totalLength(runs[0]) - 15.0) < 1e-6)
}

@Test func wallRunsSharedWall() {
    let map = DungeonMap(index: 1)
    let roomA = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    let roomB = DungeonRoom(location: MapPoint(x: 4, y: 0), size: MapSize(width: 4, height: 4))
    map.addRoom(roomA); map.addRoom(roomB)
    if let d = makeDoor(left: MapPoint(x: 4, y: 1), right: MapPoint(x: 4, y: 2), kind: "opening") { map.addDoor(d) }

    let runsA = map.wallRuns(for: roomA, doorGapRatio: 0.7)
    let runsB = map.wallRuns(for: roomB, doorGapRatio: 0.7)
    #expect(runsA.count == 1)
    #expect(runsB.count == 1)
    #expect(abs(totalLength(runsA[0]) - 15.0) < 1e-6)
    #expect(abs(totalLength(runsB[0]) - 15.0) < 1e-6)
}

@Test func wallRunsStairEndCaps() throws {
    let map = DungeonMap(index: 1)
    let roomA = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    let roomB = DungeonRoom(location: MapPoint(x: 8, y: 0), size: MapSize(width: 4, height: 4))
    map.addRoom(roomA); map.addRoom(roomB)
    let stair = try #require(makeSegmentDoor(kind: "staircase", segments: [MapPoint(x: 4, y: 1), MapPoint(x: 8, y: 1)], width: 1.0))
    map.addDoor(stair)

    let runsA = map.wallRuns(for: roomA, doorGapRatio: 0.7)
    let runsB = map.wallRuns(for: roomB, doorGapRatio: 0.7)
    #expect(runsA.count == 1)
    #expect(runsB.count == 1)
    #expect(abs(totalLength(runsA[0]) - 15.0) < 1e-6)
    #expect(abs(totalLength(runsB[0]) - 15.0) < 1e-6)
}

@Test func pathDoorProbesUseCenterline() throws {
    let map = DungeonMap(index: 1)
    let eastCorridor = DungeonHallway(edges: [
        MapPoint(x: 19, y: 25), MapPoint(x: 20, y: 25),
        MapPoint(x: 20, y: 30), MapPoint(x: 19, y: 30)
    ])
    let landing = DungeonHallway(edges: [
        MapPoint(x: 16, y: 26), MapPoint(x: 17, y: 26),
        MapPoint(x: 17, y: 27), MapPoint(x: 16, y: 27)
    ])
    map.addHallway(eastCorridor)
    map.addHallway(landing)

    let stair = try #require(makeSegmentDoor(
        kind: "staircase",
        segments: [MapPoint(x: 19, y: 27), MapPoint(x: 17, y: 27)],
        width: 1.0
    ))
    map.addDoor(stair)

    let graph = DungeonConnectivity(map: map)
    #expect(graph.connections.count == 1)
    let conn = try #require(graph.connections.first)
    let ids = Set([ObjectIdentifier(conn.from), ObjectIdentifier(conn.to)])
    #expect(ids.contains(ObjectIdentifier(eastCorridor)))
    #expect(ids.contains(ObjectIdentifier(landing)))
}

@Test func swampKingWallRuns() throws {
    guard let url = Bundle.module.url(forResource: "Swamp King Lair Level 1", withExtension: "json") else {
        Issue.record("Swamp King Lair Level 1.json not found in test bundle")
        return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let firstLevel = try #require(dungeon.maps.first(where: { $0.id == "first_level" }))
    let ratio = 0.7

    let landing = try #require(firstLevel.hallways.first(where: { $0.name == "Stair landing, blocked by rubble" }))
    let landingRuns = firstLevel.wallRuns(for: landing, doorGapRatio: ratio)
    #expect(landingRuns.count == 1)
    #expect(abs(totalLength(landingRuns[0]) - 7.0) < 1e-6)

    let room1 = try #require(firstLevel.room(withID: "1"))
    let room1Runs = firstLevel.wallRuns(for: room1, doorGapRatio: ratio)
    #expect(room1Runs.count == 4)
    let room1Total = room1Runs.reduce(0.0) { $0 + totalLength($1) }
    #expect(abs(room1Total - 9.2) < 1e-6)

    let room18A = try #require(firstLevel.room(withID: "18A"))
    let room18ARuns = firstLevel.wallRuns(for: room18A, doorGapRatio: ratio)
    #expect(room18ARuns.count == 1)
    #expect(room18ARuns[0].first == room18ARuns[0].last)
    #expect(abs(totalLength(room18ARuns[0]) - 4.0) < 1e-6)

    let storageCorridor = try #require(firstLevel.hallways.first(where: { $0.name == "Storage corridor, north" }))
    let storageRuns = firstLevel.wallRuns(for: storageCorridor, doorGapRatio: ratio)
    let storageTotal = storageRuns.reduce(0.0) { $0 + totalLength($1) }
    #expect(abs(storageTotal - 13.3) < 1e-6)

    let room32 = try #require(firstLevel.room(withID: "32"))
    let room32Runs = firstLevel.wallRuns(for: room32, doorGapRatio: ratio)
    #expect(room32Runs.count == 1)
    #expect(room32Runs[0].first == room32Runs[0].last)
}

// MARK: - Elliptical rooms

@Test func ellipseRoomGeometry() {
    let room = DungeonRoom(ellipseIn: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 2))
    #expect(room.edges.count == 32)
    #expect(room.contains(MapPoint(x: 2, y: 1)))       // center
    #expect(room.contains(MapPoint(x: 3.9, y: 1.0)))
    #expect(!room.contains(MapPoint(x: 0.1, y: 0.1)))  // bounding box corner
    #expect(!room.isAxisAlignedRectangle)

    let data = RoomData(room)
    #expect(data.shape == .ellipse)
    #expect(data.edges == nil)
    #expect(data.location == room.location)
    #expect(data.size?.width == room.size.width && data.size?.height == room.size.height)
}

@Test func ellipseRoomRoundTrips() throws {
    let room = DungeonRoom(ellipseIn: MapPoint(x: 1, y: 2), size: MapSize(width: 6, height: 4), name: "Oval Room")
    let data = RoomData(room)
    let encoded = try JSONEncoder().encode(data, configuration: testContext)
    let decoded = try JSONDecoder().decode(RoomData.self, from: encoded, configuration: testContext)
    let room2 = try #require(DungeonRoom(roomData: decoded))

    #expect(room2.shape == .ellipse)
    #expect(room2.location == room.location)
    #expect(room2.size.width == room.size.width && room2.size.height == room.size.height)
    #expect(room2.edges == room.edges)

    let delta = MapPoint(x: 3, y: -1)
    let originalEdges = room2.edges
    room2.translate(by: delta)
    for (original, translated) in zip(originalEdges, room2.edges) {
        #expect(translated == original + delta)
    }
}

// MARK: - Interior walls

@Test func interiorWallsRoundTripAndTranslate() throws {
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 10, height: 10))
    room.walls = [
        [MapPoint(x: 5, y: 0), MapPoint(x: 5, y: 10)],
        [MapPoint(x: 0, y: 5), MapPoint(x: 3, y: 5)]
    ]

    let data = RoomData(room)
    let encoded = try JSONEncoder().encode(data, configuration: testContext)
    let decoded = try JSONDecoder().decode(RoomData.self, from: encoded, configuration: testContext)
    let room2 = try #require(DungeonRoom(roomData: decoded))
    #expect(room2.walls == room.walls)

    // The dividing wall at x=5 does not affect contains(_:); the far side still reads as inside.
    #expect(room2.contains(MapPoint(x: 8, y: 5)))

    let delta = MapPoint(x: 2, y: 3)
    room2.translate(by: delta)
    #expect(room2.walls == [
        [MapPoint(x: 7, y: 3), MapPoint(x: 7, y: 13)],
        [MapPoint(x: 2, y: 8), MapPoint(x: 5, y: 8)]
    ])
}

// MARK: - Stair direction

@Test func stairDirectionRoundTrips() throws {
    let json = """
    { "kind": "staircase", "width": 1.0, "segments": [{"x": 0, "y": 0}, {"x": 0, "y": 5}], "stairDirection": "up" }
    """.data(using: .utf8)!
    let doorData = try JSONDecoder().decode(DoorData.self, from: json)
    let door = try #require(DungeonDoor(doorData: doorData))
    #expect(door.stairDirection == .up)

    let encoded = try JSONEncoder().encode(DoorData(door))
    let doorData2 = try JSONDecoder().decode(DoorData.self, from: encoded)
    let door2 = try #require(DungeonDoor(doorData: doorData2))
    #expect(door2.stairDirection == .up)
}

// MARK: - Swamp King Lair Level 1 shapes, walls, and stair directions

@Test func swampKingShapes() throws {
    guard let url = Bundle.module.url(forResource: "Swamp King Lair Level 1", withExtension: "json") else {
        Issue.record("Swamp King Lair Level 1.json not found in test bundle")
        return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let firstLevel = try #require(dungeon.maps.first(where: { $0.id == "first_level" }))
    let towerTop = try #require(dungeon.maps.first(where: { $0.id == "tower_top" }))

    let room32 = try #require(firstLevel.room(withID: "32"))
    #expect(room32.shape == .ellipse)
    #expect(room32.location == MapPoint(x: 11.0, y: 27.0))
    #expect(room32.size.width == 5.0 && room32.size.height == 5.0)
    #expect(room32.walls.count == 2)

    let room4 = try #require(firstLevel.room(withID: "4"))
    #expect(room4.walls.count == 4)

    let towerTopRoom = try #require(towerTop.room(withID: "tower-top"))
    #expect(towerTopRoom.shape == .ellipse)

    let stairDoors = firstLevel.doors.filter { $0.stairDirection != nil }
    #expect(stairDoors.count == 3)
    #expect(stairDoors.filter { $0.stairDirection == .up }.count == 1)
    #expect(stairDoors.filter { $0.stairDirection == .down }.count == 2)
}

// MARK: - Occupancy (Prompt 9)

@Test func chanceProbabilityAndDescription() throws {
    let d10AtMost3 = Chance(die: AnyRollable(Dice.d10), atMost: 3, per: "turn")
    #expect(d10AtMost3.probability == 0.3)
    #expect(d10AtMost3.description == "1-3 on d10 per turn")

    let d20AtMost1 = Chance(die: AnyRollable(Dice.d20), atMost: 1)
    #expect(d20AtMost1.probability == 0.05)
    #expect(d20AtMost1.description == "1 on d20")

    let twoD6AtMost3 = Chance(die: try AnyRollable(parsing: "2d6"), atMost: 3)
    #expect(twoD6AtMost3.probability == nil)
}

@Test func chanceCheckFrequency() {
    let chance = Chance(die: AnyRollable(Dice.d10), atMost: 3)
    let successes = (0..<4000).filter { _ in chance.check() }.count
    let rate = Double(successes) / 4000.0
    #expect((0.25...0.35).contains(rate))
}

@Test func encounterTableLookup() throws {
    let bracken = RoomEncounter(name: "Bracken-folk", count: 8)
    let glubbin = RoomEncounter(name: "Glubbin", count: 8)
    let table = EncounterTable(die: AnyRollable(Dice.d4), rows: [
        EncounterTable.Row(from: 1, to: 2, encounter: bracken),
        EncounterTable.Row(from: 3, to: 4, encounter: glubbin)
    ])
    #expect(table.row(for: 1)?.encounter.name == "Bracken-folk")
    #expect(table.row(for: 2)?.encounter.name == "Bracken-folk")
    #expect(table.row(for: 3)?.encounter.name == "Glubbin")
    #expect(table.row(for: 4)?.encounter.name == "Glubbin")
    #expect(table.uncoveredResults.isEmpty)

    let gapTable = EncounterTable(die: AnyRollable(Dice.d4), rows: [
        EncounterTable.Row(from: 1, to: 2, encounter: bracken),
        EncounterTable.Row(from: 3, to: 3, encounter: glubbin)
    ])
    #expect(gapTable.uncoveredResults == [4])
}

@Test func occupancyOutcomeWithoutTable() {
    let alwaysOccupied = Occupancy(chance: Chance(die: AnyRollable(Dice.d4), atMost: 4))
    #expect(alwaysOccupied.roll() == .occupied(nil))

    let neverOccupied = Occupancy(chance: Chance(die: AnyRollable(Dice.d4), atMost: 0))
    #expect(neverOccupied.roll() == .empty)
}

@Test func swampKingOccupancy() throws {
    guard let url = Bundle.module.url(forResource: "Swamp King Lair Level 1", withExtension: "json") else {
        Issue.record("Swamp King Lair Level 1.json not found in test bundle")
        return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let firstLevel = try #require(dungeon.maps.first(where: { $0.id == "first_level" }))

    let roomsWithOccupancy = firstLevel.rooms.filter { $0.occupancy != nil }
    #expect(roomsWithOccupancy.map(\.id).sorted() == ["1", "entrance"])

    let entrance = try #require(firstLevel.room(withID: "entrance"))
    let entranceOccupancy = try #require(entrance.occupancy)
    #expect(entranceOccupancy.chance.probability == 0.2)
    #expect(entranceOccupancy.chance.per == nil)

    let table = try #require(entranceOccupancy.table)
    #expect(table.die.description == "d4")
    #expect(table.rows.count == 2)
    #expect(table.uncoveredResults.isEmpty)

    let brackenRow = try #require(table.row(for: 1))
    #expect(brackenRow.from == 1 && brackenRow.to == 2)
    #expect(brackenRow.encounter.count.constant == 8)
    #expect(brackenRow.encounter.carriedEach?.coins.description == "d6 gp")

    let glubbinRow = try #require(table.row(for: 3))
    #expect(glubbinRow.from == 3 && glubbinRow.to == 4)
    #expect(glubbinRow.encounter.count.constant == 8)
    #expect(glubbinRow.encounter.carriedEach?.coins.description == "d6 gp")
    let glubbinStats = try #require(glubbinRow.encounter.stats)
    #expect(glubbinStats.attacks == 3)
    #expect(glubbinStats.damage.map(\.description) == ["d2", "d2", "d4+1"])

    let room1 = try #require(firstLevel.room(withID: "1"))
    let room1Occupancy = try #require(room1.occupancy)
    #expect(room1Occupancy.chance.probability == 0.3)
    #expect(room1Occupancy.chance.per == "turn")
    #expect(room1Occupancy.table == nil)
}

// MARK: - Label location (Prompt 10)

@Test func labelLocationRoundTripsAndTranslates() throws {
    let room = DungeonRoom(location: MapPoint(x: 2, y: 3), size: MapSize(width: 4, height: 5))
    room.labelLocation = MapPoint(x: 1, y: 2)

    let roomData = RoomData(room)
    let encoded = try JSONEncoder().encode(roomData, configuration: testContext)
    let decoded = try JSONDecoder().decode(RoomData.self, from: encoded, configuration: testContext)
    let room2 = try #require(DungeonRoom(roomData: decoded))
    #expect(room2.labelLocation == MapPoint(x: 1, y: 2))

    let delta = MapPoint(x: 10, y: 5)
    room.translate(by: delta)
    #expect(room.labelLocation == MapPoint(x: 11, y: 7))
}

@Test func swampKingLabelLocations() throws {
    guard let url = Bundle.module.url(forResource: "Swamp King Lair Level 1", withExtension: "json") else {
        Issue.record("Swamp King Lair Level 1.json not found in test bundle")
        return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let firstLevel = try #require(dungeon.maps.first(where: { $0.id == "first_level" }))

    let roomsWithLabelLocation = firstLevel.rooms.filter { $0.labelLocation != nil }
    #expect(roomsWithLabelLocation.map(\.id).sorted() == ["10", "26", "entrance"])

    let entrance = try #require(firstLevel.room(withID: "entrance"))
    let entranceLabelLocation = try #require(entrance.labelLocation)
    #expect(entranceLabelLocation == MapPoint(x: 11.5, y: 1.5))
    #expect(entrance.contains(entranceLabelLocation) == false)

    let room10 = try #require(firstLevel.room(withID: "10"))
    let room10LabelLocation = try #require(room10.labelLocation)
    #expect(room10LabelLocation == MapPoint(x: 10.0, y: 9.5))
    #expect(room10.contains(room10LabelLocation) == true)

    let room26 = try #require(firstLevel.room(withID: "26"))
    let room26LabelLocation = try #require(room26.labelLocation)
    #expect(room26LabelLocation == MapPoint(x: 13.5, y: 25.55))
    #expect(room26.contains(room26LabelLocation) == true)
}

// MARK: - Occupancy table borrowing (Prompt 10)

@Test func occupancyBorrowsTable() throws {
    let map = DungeonMap(index: 1)
    let source = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    source.id = "source"
    let table = EncounterTable(die: AnyRollable(Dice.d4), rows: [
        EncounterTable.Row(from: 1, to: 4, encounter: RoomEncounter(name: "Goblin", count: 1))
    ])
    source.occupancy = Occupancy(chance: Chance(die: AnyRollable(Dice.d4), atMost: 0), table: table)
    map.addRoom(source)

    let borrower = DungeonRoom(location: MapPoint(x: 5, y: 0), size: MapSize(width: 4, height: 4))
    borrower.id = "borrower"
    borrower.occupancy = Occupancy(chance: Chance(die: AnyRollable(Dice.d4), atMost: 4), tableRoomID: "source")
    map.addRoom(borrower)

    #expect(map.encounterTable(for: borrower) == table)
    #expect(map.encounterTable(for: source) == table)

    let outcome = try #require(map.rollOccupancy(for: borrower))
    guard case .occupied(let encounter) = outcome else {
        Issue.record("Expected .occupied, got \(outcome)")
        return
    }
    #expect(encounter != nil)
}

@Test func occupancyOwnTableWins() throws {
    let map = DungeonMap(index: 1)
    let source = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    source.id = "source"
    let sourceTable = EncounterTable(die: AnyRollable(Dice.d4), rows: [
        EncounterTable.Row(from: 1, to: 4, encounter: RoomEncounter(name: "Goblin", count: 1))
    ])
    source.occupancy = Occupancy(chance: Chance(die: AnyRollable(Dice.d4), atMost: 4), table: sourceTable)
    map.addRoom(source)

    let ownTable = EncounterTable(die: AnyRollable(Dice.d6), rows: [
        EncounterTable.Row(from: 1, to: 6, encounter: RoomEncounter(name: "Orc", count: 1))
    ])
    let room = DungeonRoom(location: MapPoint(x: 5, y: 0), size: MapSize(width: 4, height: 4))
    room.id = "room"
    room.occupancy = Occupancy(chance: Chance(die: AnyRollable(Dice.d4), atMost: 4), table: ownTable, tableRoomID: "source")
    map.addRoom(room)

    #expect(map.encounterTable(for: room) == ownTable)
}

@Test func occupancyUnknownTableRoomID() {
    let map = DungeonMap(index: 1)
    let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
    room.id = "room"
    room.occupancy = Occupancy(chance: Chance(die: AnyRollable(Dice.d4), atMost: 4), tableRoomID: "nonexistent")
    map.addRoom(room)

    #expect(map.encounterTable(for: room) == nil)
    #expect(map.unknownOccupancyTableRoomIDs == ["nonexistent"])
}

@Test func swampKingOccupancyTables() throws {
    guard let url = Bundle.module.url(forResource: "Swamp King Lair Level 1", withExtension: "json") else {
        Issue.record("Swamp King Lair Level 1.json not found in test bundle")
        return
    }
    let dungeon = try Dungeon(contentsOf: url, context: testContext)
    let firstLevel = try #require(dungeon.maps.first(where: { $0.id == "first_level" }))

    let room1 = try #require(firstLevel.room(withID: "1"))
    #expect(room1.occupancy?.table == nil)
    #expect(room1.occupancy?.tableRoomID == "entrance")

    let resolvedTable = try #require(firstLevel.encounterTable(for: room1))
    #expect(resolvedTable.die.description == "d4")
    #expect(resolvedTable.rows.count == 2)

    #expect(firstLevel.unknownOccupancyTableRoomIDs.isEmpty)
}
