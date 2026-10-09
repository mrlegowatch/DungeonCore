//
//  DungeonMapViewModel+Flow.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/5/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import DungeonCore

extension DungeonMapViewModel {

    // MARK: - Flow analysis

    /// The connectivity graph for the current map, cached against map identity and `revision`
    /// so flow-mode taps and key-progression lookups don't each rebuild it from scratch.
    ///
    /// `nil` when there is no current map.
    private var connectivityGraph: DungeonConnectivity? {
        guard let currentMap else { return nil }
        let mapID = ObjectIdentifier(currentMap)
        if let cached = connectivityCache, cached.mapID == mapID, cached.revision == revision {
            return cached.graph
        }
        let graph = DungeonConnectivity(map: currentMap)
        connectivityCache = (mapID, revision, graph)
        return graph
    }

    /// The step-by-step key unlocking walk from the current flow start room, or `nil` if flow mode isn't active.
    ///
    /// Recomputed on every access from `flowStartRoom`, `findsSecrets`, and the current map state
    /// (tracked via `revision`), so it always reflects the latest mutation.
    var keyProgression: KeyProgression? {
        guard let start = flowStartRoom, let connectivityGraph else { return nil }
        return connectivityGraph.keyProgression(from: start, findsSecrets: findsSecrets)
    }

    /// Returns the reachability status of `room` under the current flow analysis, or nil if not in flow mode.
    func reachabilityStatus(for room: DungeonRoom) -> DungeonReachability? {
        reachabilityMap?[ObjectIdentifier(room)]
    }

    /// Sets the flow analysis root to `room` and rebuilds the reachability classification.
    ///
    /// Pass `nil` to clear the analysis (e.g. when exiting flow mode).
    func setFlowStart(_ room: DungeonRoom?) {
        flowStartRoom = room
        if let start = room, let connectivityGraph {
            reachabilityMap = connectivityGraph.classify(from: start)
        } else {
            reachabilityMap = nil
        }
        revision += 1
    }

    /// Enters flow mode, defaulting the start to the first room in the map.
    func enterFlowMode() {
        setFlowStart(currentMap?.rooms.first)
    }

    /// Clears flow analysis state when exiting flow mode.
    func exitFlowMode() {
        setFlowStart(nil)
    }
}
