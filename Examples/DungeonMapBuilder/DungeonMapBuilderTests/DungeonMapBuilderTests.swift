//
//  DungeonMapBuilderTests.swift
//  DungeonMapBuilderTests
//
//  Created by Brian Arnold on 12/2/25.
//

@testable import DungeonMapBuilder
import Testing
import DungeonCore
import SwiftDice
import CoreGraphics

@MainActor
struct DungeonMapViewModelTests {

    private func makeViewModel(scale: CGFloat = MapViewConfiguration.defaultScale) -> DungeonMapViewModel {
        let dungeon = Dungeon()
        let vm = DungeonMapViewModel(dungeon: dungeon, store: DungeonStore())
        vm.scale = scale
        return vm
    }

    // MARK: - currentMap with zero maps

    /// `Dungeon()` always seeds one map and the app's own UI never empties `maps`, but
    /// `Dungeon.init(contentsOf:)` doesn't guarantee a non-empty `maps` either (a JSON file
    /// with `"maps": []` would decode to one), so `currentMap` must degrade gracefully.
    @Test func currentMapIsNilAndMethodsNoOpWhenDungeonHasNoMaps() {
        let dungeon = Dungeon()
        dungeon.maps = []
        let vm = DungeonMapViewModel(dungeon: dungeon, store: DungeonStore())

        #expect(vm.currentMap == nil)
        #expect(vm.canvasOffset == .zero)
        #expect(vm.room(at: .zero) == nil)
        #expect(vm.element(at: .zero) == nil)
        #expect(!vm.isInHallway(at: .zero))
        #expect(vm.keyProgression == nil)

        // These must not crash.
        vm.nextMap()
        vm.previousMap()
        vm.setFlowStart(nil)
        vm.renameCurrentMap(to: "New Name", undoManager: nil)
        vm.removeCurrentMap(undoManager: nil)
        #expect(vm.addRoom(at: MapPoint(x: 0, y: 0), undoManager: nil) == nil)
    }

    // MARK: - mapPoint(for:)

    @Test func mapPointAtOriginIsOrigin() {
        let vm = makeViewModel()
        let result = vm.mapPoint(for: .zero)
        #expect(result.x == 0)
        #expect(result.y == 0)
    }

    @Test func mapPointDividesScreenCoordsByScale() {
        let vm = makeViewModel(scale: 40)
        let result = vm.mapPoint(for: CGPoint(x: 80, y: 120))
        #expect(result.x == 2.0)
        #expect(result.y == 3.0)
    }

    // MARK: - screenPoint(for:)

    @Test func screenPointMultipliesMapCoordsByScale() {
        let vm = makeViewModel(scale: 40)
        let result = vm.screenPoint(for: MapPoint(x: 5, y: 7))
        #expect(result.x == 200)
        #expect(result.y == 280)
    }

    // MARK: - Round-trip

    @Test func coordinateConversionRoundTrips() {
        let vm = makeViewModel(scale: 40)
        let original = MapPoint(x: 3.5, y: 8.25)
        let roundTripped = vm.mapPoint(for: vm.screenPoint(for: original))
        #expect(abs(roundTripped.x - original.x) < 1e-10)
        #expect(abs(roundTripped.y - original.y) < 1e-10)
    }

    // MARK: - contentSize

    @Test func contentSizeForEmptyDungeonUsesMinimumCanvasSize() {
        let vm = makeViewModel(scale: 40)
        let expectedSide = MapViewConfiguration.minimumCanvasSize * 40
        #expect(vm.contentSize.width == expectedSide)
        #expect(vm.contentSize.height == expectedSide)
    }

    @Test func contentSizeGrowsWithRoomBeyondMinimum() {
        let vm = makeViewModel(scale: 40)
        vm.dungeon.maps[0].addRoom(
            DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 25, height: 30))
        )
        let size = vm.contentSize
        // width  = max(20, 25 + 2) * 40 = 27 * 40 = 1080
        // height = max(20, 30 + 2) * 40 = 32 * 40 = 1280
        #expect(size.width == (25 + MapViewConfiguration.canvasMargin) * 40)
        #expect(size.height == (30 + MapViewConfiguration.canvasMargin) * 40)
    }

    // MARK: - canvasOffset

    @Test func canvasOffsetForEmptyDungeonIsZero() {
        let vm = makeViewModel(scale: 40)
        #expect(vm.canvasOffset == .zero)
    }

    @Test func canvasOffsetForRoomAtOriginIsFullMargin() {
        let vm = makeViewModel(scale: 40)
        vm.dungeon.maps[0].addRoom(
            DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
        )
        let margin = MapViewConfiguration.canvasMargin * 40
        #expect(vm.canvasOffset == CGPoint(x: margin, y: margin))
    }

    @Test func canvasOffsetForRoomBeyondMarginIsZero() {
        let vm = makeViewModel(scale: 40)
        // Room at (3, 3): both axes exceed canvasMargin (2), so no pre-margin needed
        vm.dungeon.maps[0].addRoom(
            DungeonRoom(location: MapPoint(x: 3, y: 3), size: MapSize(width: 4, height: 4))
        )
        #expect(vm.canvasOffset == .zero)
    }

    @Test func canvasOffsetForRoomPartiallyInsideMargin() {
        let vm = makeViewModel(scale: 40)
        // Room at (1, 0): x needs 1 unit of pre-margin, y needs the full 2
        vm.dungeon.maps[0].addRoom(
            DungeonRoom(location: MapPoint(x: 1, y: 0), size: MapSize(width: 4, height: 4))
        )
        let expectedX = (MapViewConfiguration.canvasMargin - 1) * 40  // 1 * 40 = 40
        let expectedY = MapViewConfiguration.canvasMargin * 40         // 2 * 40 = 80
        #expect(vm.canvasOffset.x == expectedX)
        #expect(vm.canvasOffset.y == expectedY)
    }

    // MARK: - room(at:) integration

    @Test func roomAtHitsRoomAtScreenCenter() {
        let vm = makeViewModel(scale: 40)
        let room = DungeonRoom(location: MapPoint(x: 5, y: 5), size: MapSize(width: 4, height: 4))
        vm.dungeon.maps[0].addRoom(room)
        // Center of room: map (7, 7) → screen (280, 280)
        #expect(vm.room(at: CGPoint(x: 280, y: 280)) === room)
    }

    @Test func roomAtMissesOutsideRoomBounds() {
        let vm = makeViewModel(scale: 40)
        let room = DungeonRoom(location: MapPoint(x: 5, y: 5), size: MapSize(width: 4, height: 4))
        vm.dungeon.maps[0].addRoom(room)
        #expect(vm.room(at: .zero) == nil)
    }

    // MARK: - keyProgression

    @Test func keyProgressionTwoRoomsOneLockedDoor() throws {
        let vm = makeViewModel()
        let map = try #require(vm.currentMap)

        let room1 = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
        room1.treasure = Treasure(items: [TreasureItem(name: "Rusty key", keyID: "door-key")])
        let room2 = DungeonRoom(location: MapPoint(x: 4, y: 0), size: MapSize(width: 4, height: 4))
        map.addRoom(room1)
        map.addRoom(room2)

        let door = DungeonDoor(kind: .door, leftEdge: MapPoint(x: 4, y: 1), rightEdge: MapPoint(x: 4, y: 2))
        door.attributes = [.isLocked]
        door.keyID = "door-key"
        map.addDoor(door)

        vm.setFlowStart(room1)
        #expect(vm.keyProgression?.steps.count == 2)

        vm.findsSecrets.toggle()
        #expect(vm.keyProgression?.steps.count == 2)
    }

    /// Regression test for the connectivity-graph cache added to speed up `keyProgression`
    /// and `setFlowStart`: switching maps via `nextMap()` does not bump `revision`, so the
    /// cache must key on map identity too, or it would keep serving the previous map's graph.
    @Test func keyProgressionReflectsCurrentMapAfterSwitchingMaps() {
        let vm = makeViewModel()
        let dungeon = vm.dungeon

        let map1Room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
        dungeon.maps[0].addRoom(map1Room)

        let map2 = DungeonMap(index: 2)
        let map2Room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 4, height: 4))
        map2.addRoom(map2Room)
        dungeon.maps.append(map2)

        // Populate the connectivity cache for map 1.
        vm.setFlowStart(map1Room)
        _ = vm.keyProgression

        // Switch to map 2 without any map mutation (so `revision` does not change)...
        vm.nextMap()
        vm.setFlowStart(map2Room)

        let reachedRooms = vm.keyProgression?.steps.first?.roomsReached ?? []
        #expect(reachedRooms.contains(where: { $0 === map2Room }))
        #expect(!reachedRooms.contains(where: { $0 === map1Room }))
    }
}

/// Ray-casting point-in-polygon test, mirroring `DungeonRoom.contains(_:)`, so
/// `LabelPlacement` can be exercised against a non-rectangular outline without a live
/// `DungeonRoom`.
private func polygonContains(_ point: CGPoint, edges: [CGPoint]) -> Bool {
    var inside = false
    var j = edges.count - 1
    for i in 0..<edges.count {
        let xi = edges[i].x, yi = edges[i].y
        let xj = edges[j].x, yj = edges[j].y
        if (yi > point.y) != (yj > point.y),
           point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi {
            inside.toggle()
        }
        j = i
    }
    return inside
}

struct LabelPlacementTests {
    private let boundingBox = CGRect(x: 0, y: 0, width: 10, height: 10)
    private let rectEdges = [
        CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10), CGPoint(x: 0, y: 10),
    ]
    private let labelSize = CGSize(width: 2, height: 1)
    private let inset = CGSize(width: 0.5, height: 0.5)

    private func rectContains(_ point: CGPoint) -> Bool {
        boundingBox.contains(point)
    }

    @Test func rectangleNoObstaclesGivesTopLeft() {
        let rect = LabelPlacement.automaticLabelRect(
            isEllipse: false, boundingBox: boundingBox, edges: rectEdges,
            labelSize: labelSize, inset: inset, obstacles: [], contains: rectContains
        )
        #expect(rect == CGRect(x: 0.5, y: 0.5, width: 2, height: 1))
    }

    @Test func rectangleObstacleAtTopLeftGivesTopRight() {
        let obstacleAtTopLeft = CGRect(x: 0.5, y: 0.5, width: 2, height: 1)
        let rect = LabelPlacement.automaticLabelRect(
            isEllipse: false, boundingBox: boundingBox, edges: rectEdges,
            labelSize: labelSize, inset: inset, obstacles: [obstacleAtTopLeft], contains: rectContains
        )
        let expected = CGRect(x: boundingBox.maxX - inset.width - labelSize.width, y: inset.height, width: 2, height: 1)
        #expect(rect == expected)
        #expect(boundingBox.contains(rect))
    }

    @Test func crossShapeAnchorsAtVertexNotBoundingBoxCorner() {
        // (1,1) (2,1) (2,0) (4,0) (4,1) (5,1) (5,2) (4,2) (4,3) (2,3) (2,2) (1,2)
        let edges = [
            CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 1), CGPoint(x: 2, y: 0), CGPoint(x: 4, y: 0),
            CGPoint(x: 4, y: 1), CGPoint(x: 5, y: 1), CGPoint(x: 5, y: 2), CGPoint(x: 4, y: 2),
            CGPoint(x: 4, y: 3), CGPoint(x: 2, y: 3), CGPoint(x: 2, y: 2), CGPoint(x: 1, y: 2),
        ]
        let crossBoundingBox = CGRect(x: 1, y: 0, width: 4, height: 3)
        let crossLabelSize = CGSize(width: 0.6, height: 0.3)
        let crossInset = CGSize(width: 0.25, height: 0.25)
        let contains: (CGPoint) -> Bool = { polygonContains($0, edges: edges) }

        let rect = LabelPlacement.automaticLabelRect(
            isEllipse: false, boundingBox: crossBoundingBox, edges: edges,
            labelSize: crossLabelSize, inset: crossInset, obstacles: [], contains: contains
        )

        // Anchored at vertex (2,0), below-right: top-left of the label at (2,0) + inset.
        let expected = CGRect(x: 2.25, y: 0.25, width: 0.6, height: 0.3)
        #expect(rect == expected)
        #expect(contains(CGPoint(x: rect.midX, y: rect.midY)))
        // Not the bounding-box corner (1,0).
        #expect(rect.origin != CGPoint(x: 1 + crossInset.width, y: 0 + crossInset.height))
    }

    @Test func crossShapeObstacleOnTopArmMovesLabelButStaysInsideRoom() {
        let edges = [
            CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 1), CGPoint(x: 2, y: 0), CGPoint(x: 4, y: 0),
            CGPoint(x: 4, y: 1), CGPoint(x: 5, y: 1), CGPoint(x: 5, y: 2), CGPoint(x: 4, y: 2),
            CGPoint(x: 4, y: 3), CGPoint(x: 2, y: 3), CGPoint(x: 2, y: 2), CGPoint(x: 1, y: 2),
        ]
        let crossBoundingBox = CGRect(x: 1, y: 0, width: 4, height: 3)
        let crossLabelSize = CGSize(width: 0.6, height: 0.3)
        let crossInset = CGSize(width: 0.25, height: 0.25)
        let contains: (CGPoint) -> Bool = { polygonContains($0, edges: edges) }
        // Covers the whole north (top) arm.
        let obstacleOnTopArm = CGRect(x: 2, y: 0, width: 2, height: 1)

        let rect = LabelPlacement.automaticLabelRect(
            isEllipse: false, boundingBox: crossBoundingBox, edges: edges,
            labelSize: crossLabelSize, inset: crossInset, obstacles: [obstacleOnTopArm], contains: contains
        )

        #expect(contains(CGPoint(x: rect.midX, y: rect.midY)))
        #expect(rect.origin != CGPoint(x: 2.25, y: 0.25))
        #expect(!obstacleOnTopArm.intersects(rect))
    }

    @Test func ellipseCentersHorizontallyWithTopInset() {
        let ellipseBoundingBox = CGRect(x: 11, y: 27, width: 5, height: 5)
        let ellipseLabelSize = CGSize(width: 0.6, height: 0.3)
        let ellipseInset = CGSize(width: 0.25, height: 0.25)

        let rect = LabelPlacement.automaticLabelRect(
            isEllipse: true, boundingBox: ellipseBoundingBox, edges: [],
            labelSize: ellipseLabelSize, inset: ellipseInset, obstacles: [CGRect(x: 0, y: 0, width: 100, height: 100)],
            contains: { _ in false }
        )

        #expect(rect.midX == 13.5)
        #expect(rect.minY == 27.25)
    }

    @Test func everyCandidateObstructedReturnsFirstCandidate() {
        let obstacles = [
            CGRect(x: 0.5, y: 0.5, width: 2, height: 1),
            CGRect(x: boundingBox.maxX - inset.width - labelSize.width, y: inset.height, width: 2, height: 1),
            CGRect(x: inset.width, y: boundingBox.maxY - inset.height - labelSize.height, width: 2, height: 1),
            CGRect(x: boundingBox.maxX - inset.width - labelSize.width, y: boundingBox.maxY - inset.height - labelSize.height, width: 2, height: 1),
        ]
        let rect = LabelPlacement.automaticLabelRect(
            isEllipse: false, boundingBox: boundingBox, edges: rectEdges,
            labelSize: labelSize, inset: inset, obstacles: obstacles, contains: rectContains
        )
        #expect(rect == CGRect(x: 0.5, y: 0.5, width: 2, height: 1))
    }
}

struct RoomDetailViewTests {

    private func makeRoom() -> DungeonRoom {
        DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 5, height: 5))
    }

    @Test func hasStructuredRoomContentIsFalseWithNoStructuredContent() {
        let room = makeRoom()
        #expect(!room.hasStructuredRoomContent)
    }

    @Test func hasStructuredRoomContentIsTrueWithFeatures() {
        let room = makeRoom()
        room.features = [RoomFeature(id: "1-trap", kind: .trap, location: MapPoint(x: 1, y: 1))]
        #expect(room.hasStructuredRoomContent)
    }

    @Test func hasStructuredRoomContentIsTrueWithEncounters() {
        let room = makeRoom()
        room.encounters = [RoomEncounter(name: "Goblin")]
        #expect(room.hasStructuredRoomContent)
    }

    @Test func hasStructuredRoomContentIsTrueWithNonEmptyTreasure() {
        let room = makeRoom()
        room.treasure = Treasure(items: [TreasureItem(name: "Potion of Healing")])
        #expect(room.hasStructuredRoomContent)
    }

    @Test func hasStructuredRoomContentIsFalseWithEmptyTreasure() {
        let room = makeRoom()
        room.treasure = Treasure()
        #expect(!room.hasStructuredRoomContent)
    }

    @Test func hasStructuredRoomContentIsTrueWithOccupancy() {
        let room = makeRoom()
        room.occupancy = Occupancy(chance: Chance(die: 1, atMost: 1))
        #expect(room.hasStructuredRoomContent)
    }
}

struct MapDisplaySettingsTests {

    @Test func nonDefaultSettingsRoundTripThroughRawValue() {
        var settings = MapDisplaySettings()
        settings.showRuler = true
        settings.showRoomLabels = false
        settings.showHallwayLabels = true
        settings.showDoorLabels = true
        settings.showDoorSides = true
        settings.showFeatures = false

        let roundTripped = MapDisplaySettings(rawValue: settings.rawValue)

        #expect(roundTripped?.showRuler == true)
        #expect(roundTripped?.showRoomLabels == false)
        #expect(roundTripped?.showHallwayLabels == true)
        #expect(roundTripped?.showDoorLabels == true)
        #expect(roundTripped?.showDoorSides == true)
        #expect(roundTripped?.showFeatures == false)
    }

    @Test func emptyJSONObjectYieldsDefaults() {
        let settings = MapDisplaySettings(rawValue: "{}")
        let defaults = MapDisplaySettings()

        #expect(settings?.showRuler == defaults.showRuler)
        #expect(settings?.showRoomLabels == defaults.showRoomLabels)
        #expect(settings?.showHallwayLabels == defaults.showHallwayLabels)
        #expect(settings?.showDoorLabels == defaults.showDoorLabels)
        #expect(settings?.showDoorSides == defaults.showDoorSides)
        #expect(settings?.showFeatures == defaults.showFeatures)
    }
}
