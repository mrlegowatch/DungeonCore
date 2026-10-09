//
//  DungeonMapViewModel.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/5/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// View model for managing dungeon map view state
@MainActor
@Observable
final class DungeonMapViewModel {
    let dungeon: Dungeon
    /// Not private: used by the mutation methods in DungeonMapViewModel+Editing.swift.
    let store: DungeonStore

    var currentMapIndex: Int = 0
    var scale: CGFloat = MapViewConfiguration.defaultScale
    var offset: CGSize = .zero
    var selectedElement: DungeonRoom?

    // The following drag/resize session state is mutated from DungeonMapViewModel+Editing.swift,
    // so (unlike wallRunsCache below) it can't be private to this file.
    var dragStartRoomLocation: MapPoint?
    var dragGhostLocation: MapPoint?
    var resizingCornerIndex: Int?
    var resizeStartEdges: [MapPoint]?
    var resizeStartLocation: MapPoint?
    var resizeStartSize: MapSize?

    private var wallRunsCache: [ObjectIdentifier: (revision: Int, runs: [[MapPoint]])] = [:]
    /// Backing cache for `connectivityGraph` in DungeonMapViewModel+Flow.swift, so it can't be private to this file.
    ///
    /// Keyed by map identity as well as `revision`: switching maps via `nextMap()`/`previousMap()`
    /// changes `currentMap` without bumping `revision`.
    var connectivityCache: (mapID: ObjectIdentifier, revision: Int, graph: DungeonConnectivity)?

    /// Incremented after every mutation so the canvas re-reads the current map state.
    ///
    /// Because `DungeonMap` and `DungeonRoom` are plain classes, SwiftUI does not observe
    /// their array mutations automatically. Views that display map content should read this
    /// token in their `body` to ensure they re-render when rooms/doors are added, removed,
    /// or moved.
    var revision: Int = 0

    // MARK: - Hallway drawing state
    //
    // Mutated from DungeonMapViewModel+Editing.swift, so not private(set) to this file.

    var hallwayDraftPoints: [MapPoint]?
    var hallwayPreviewPoint: MapPoint?

    // MARK: - Door drawing state
    //
    // Mutated from DungeonMapViewModel+Editing.swift, so not private(set) to this file.

    var doorDraftStart: MapPoint?
    var doorDraftEnd: MapPoint?

    // MARK: - Flow analysis state
    //
    // Mutated from DungeonMapViewModel+Flow.swift, so not private to this file.

    var flowStartRoom: DungeonRoom?
    var reachabilityMap: [ObjectIdentifier: DungeonReachability]?

    /// Whether the party is assumed to find secret doors while exploring. Affects `keyProgression`.
    var findsSecrets: Bool = true

    /// The map at `currentMapIndex`.
    ///
    /// `dungeon.maps` is never empty: `DungeonCore` rejects a dungeon with no maps while
    /// decoding, and the app always creates and maintains at least one. This only falls
    /// back to the first map when `currentMapIndex` is out of range.
    var currentMap: DungeonMap? {
        guard currentMapIndex >= 0, currentMapIndex < dungeon.maps.count else {
            return dungeon.maps.first
        }
        return dungeon.maps[currentMapIndex]
    }

    /// The wall runs for `room` on the current map, cached against `revision` so repeated
    /// calls during a pan/zoom (which re-render every frame but don't mutate the map) don't
    /// re-walk every door on the map each time.
    func wallRuns(for room: DungeonRoom) -> [[MapPoint]] {
        let id = ObjectIdentifier(room)
        if let cached = wallRunsCache[id], cached.revision == revision {
            return cached.runs
        }
        guard let currentMap else { return [] }
        let runs = currentMap.wallRuns(for: room, doorGapRatio: Double(MapViewConfiguration.doorLengthRatio))
        wallRunsCache[id] = (revision, runs)
        return runs
    }

    init(dungeon: Dungeon, store: DungeonStore) {
        self.dungeon = dungeon
        self.store = store
        let session = UserDefaults.standard.dungeonSession(forID: dungeon.id)
        self.currentMapIndex = min(session.currentMapIndex, max(0, dungeon.maps.count - 1))
        self.scale = min(MapViewConfiguration.maxScale, max(MapViewConfiguration.minScale, session.scale))
    }

    func saveSession() {
        UserDefaults.standard.save(
            DungeonSession(currentMapIndex: currentMapIndex, scale: scale),
            forID: dungeon.id
        )
    }

    // MARK: - Map navigation

    func nextMap() {
        guard !dungeon.maps.isEmpty else { return }
        currentMapIndex = min(dungeon.maps.count - 1, currentMapIndex + 1)
    }

    func previousMap() {
        guard !dungeon.maps.isEmpty else { return }
        currentMapIndex = max(0, currentMapIndex - 1)
    }

    // MARK: - Map mutations

    func renameCurrentMap(to name: String, undoManager: UndoManager?) {
        guard let currentMap else { return }
        store.renameMap(currentMap, to: name, in: dungeon, undoManager: undoManager)
        revision += 1
    }

    func addMap(undoManager: UndoManager?) {
        store.addMap(to: dungeon, undoManager: undoManager)
        currentMapIndex = dungeon.maps.count - 1
        revision += 1
    }

    func removeCurrentMap(undoManager: UndoManager?) {
        guard dungeon.maps.count > 1, let map = currentMap else { return }
        store.removeMap(map, from: dungeon, undoManager: undoManager)
        currentMapIndex = min(currentMapIndex, dungeon.maps.count - 1)
        revision += 1
    }
}
