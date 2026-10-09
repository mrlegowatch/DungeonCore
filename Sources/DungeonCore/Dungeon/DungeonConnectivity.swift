//
//  DungeonConnectivity.swift
//  DungeonCore
//
//  Created by Brian Arnold on 8/2/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import Foundation

/// Configures which door attributes are treated as passable in a reachability query.
public struct Traversal: Sendable {
    /// When true, locked, barred, and magic-sealed doors are passable.
    public var opensLocks: Bool
    /// When true, secret doors are passable.
    public var opensSecrets: Bool
    /// When true, one-way doors block reverse traversal.
    public var respectsOneWay: Bool
    /// Key IDs currently held; a key-gated connection naming one of these is passable.
    public var heldKeys: Set<String>

    public init(opensLocks: Bool = false, opensSecrets: Bool = false, respectsOneWay: Bool = true, heldKeys: Set<String> = []) {
        self.opensLocks = opensLocks
        self.opensSecrets = opensSecrets
        self.respectsOneWay = respectsOneWay
        self.heldKeys = heldKeys
    }

    /// No keys, no secrets found, one-way respected — the baseline "party just arrived" view.
    public static let keyless = Traversal()
    /// All gates open — used to classify unreachable vs. key-gated nodes.
    public static let allGatesOpen = Traversal(opensLocks: true, opensSecrets: true, respectsOneWay: false)
}

/// The reachability classification of a map node relative to a chosen start.
public enum DungeonReachability {
    /// Reachable without any keys or secret-door knowledge.
    case reachable
    /// Not freely reachable, but reachable when all gates are open.
    case keyGated
    /// Not reachable even when all gates are open (isolated or blocked by one-way doors).
    case unreachable
}

/// A resolved connection between two map nodes through a door.
public struct Connection {
    public let door: DungeonDoor
    public let from: DungeonRoom
    public let to: DungeonRoom
    /// True when the door is locked, barred, or magically sealed.
    public let keyGated: Bool
    /// True when the door is secret.
    public let secretGated: Bool
    /// True when the door only allows passage from → to.
    public let isOneWay: Bool
    /// The key that opens this door, when gated. Matches `DungeonDoor.keyID`.
    public let keyID: String?

    /// Returns the neighbor reachable from `node` through this connection under `traversal`, or nil.
    func neighbor(of node: DungeonRoom, traversal: Traversal) -> DungeonRoom? {
        if keyGated {
            let hasKey = keyID.map { traversal.heldKeys.contains($0) } ?? false
            if !traversal.opensLocks && !hasKey { return nil }
        }
        if secretGated && !traversal.opensSecrets { return nil }
        if node === from { return to }
        if node === to && (!isOneWay || !traversal.respectsOneWay) { return from }
        return nil
    }
}

/// A derived adjacency graph for a single `DungeonMap`, built from door geometry.
///
/// For each `DungeonDoor`, probe points derived from `fromArea`/`toArea` (or nudged segment
/// endpoints for path-based doors) are resolved via `DungeonRoom.contains(_:)` to identify
/// the two nodes on either side. The result supports adjacency queries, reachability BFS,
/// and the three-way classification needed for DM flow analysis.
///
/// Rebuild this struct after any mutation to the map.
public struct DungeonConnectivity {
    /// All rooms and hallways on the map (the graph nodes).
    public let nodes: [DungeonRoom]
    /// All doors on the map, in map order.
    public let doors: [DungeonDoor]
    /// All successfully resolved door connections.
    public let connections: [Connection]
    /// Doors with only one resolved side (exterior openings / map boundary entrances).
    public let entranceDoors: [DungeonDoor]
    /// Doors connecting to other maps or levels.
    public let portalDoors: [DungeonDoor]

    private let adjacency: [ObjectIdentifier: [Connection]]

    /// Builds the connectivity graph from `map`.
    public init(map: DungeonMap) {
        let allNodes: [DungeonRoom] = map.rooms + map.hallways
        self.nodes = allNodes
        self.doors = map.doors

        var resolvedConnections: [Connection] = []
        var entrances: [DungeonDoor] = []
        var portals: [DungeonDoor] = []
        var adj: [ObjectIdentifier: [Connection]] = [:]

        for door in map.doors {
            // A door with a remote connection is always a portal, regardless of how its
            // probes resolve (e.g. a staircase drawn wholly inside one room).
            if door.connection != nil {
                portals.append(door)
                continue
            }

            let (fromProbe, toProbe) = DungeonConnectivity.probePoints(for: door)
            let fromNode = fromProbe.flatMap { DungeonConnectivity.resolveNode(at: $0, in: allNodes) }
            let toNode   = toProbe.flatMap   { DungeonConnectivity.resolveNode(at: $0, in: allNodes) }

            if let from = fromNode, let to = toNode {
                guard from !== to else { continue }  // no self-connections
                let connection = Connection(
                    door: door,
                    from: from,
                    to: to,
                    keyGated: door.hasAttribute(.isLocked) || door.hasAttribute(.isBarred) || door.hasAttribute(.hasMagicSeal),
                    secretGated: door.hasAttribute(.isSecret),
                    isOneWay: door.hasAttribute(.isOneWay),
                    keyID: door.keyID
                )
                resolvedConnections.append(connection)
                adj[ObjectIdentifier(from), default: []].append(connection)
                adj[ObjectIdentifier(to),   default: []].append(connection)
            } else if fromNode != nil || toNode != nil {
                // One side exterior — entrance
                entrances.append(door)
            }
            // else: neither side resolved, and no remote connection — dropped.
        }

        self.connections    = resolvedConnections
        self.entranceDoors  = entrances
        self.portalDoors    = portals
        self.adjacency      = adj
    }

    // MARK: - Queries

    /// Returns all connections touching `node`.
    public func connections(from node: DungeonRoom) -> [Connection] {
        adjacency[ObjectIdentifier(node)] ?? []
    }

    /// Returns the room neighbors of `node`, collapsing hallway nodes transparently.
    ///
    /// Two rooms linked only through a hallway are reported as adjacent to each other.
    public func adjacentRooms(to node: DungeonRoom) -> [DungeonRoom] {
        var visited = Set<ObjectIdentifier>()
        var result: [DungeonRoom] = []

        func expand(_ current: DungeonRoom) {
            let id = ObjectIdentifier(current)
            guard visited.insert(id).inserted else { return }
            for connection in connections(from: current) {
                let neighbor = connection.from === current ? connection.to : connection.from
                if neighbor is DungeonHallway {
                    expand(neighbor)
                } else if neighbor !== node {
                    result.append(neighbor)
                }
            }
        }

        expand(node)
        return result
    }

    /// Returns the set of node identifiers reachable from `start` under `traversal`.
    public func reachable(from start: DungeonRoom, traversal: Traversal = .keyless) -> Set<ObjectIdentifier> {
        var visited = Set<ObjectIdentifier>()
        var queue: [DungeonRoom] = [start]
        visited.insert(ObjectIdentifier(start))

        while !queue.isEmpty {
            let current = queue.removeFirst()
            for connection in connections(from: current) {
                if let neighbor = connection.neighbor(of: current, traversal: traversal),
                   visited.insert(ObjectIdentifier(neighbor)).inserted {
                    queue.append(neighbor)
                }
            }
        }

        return visited
    }

    /// Returns a three-way reachability classification for every node, rooted at `start`.
    public func classify(from start: DungeonRoom) -> [ObjectIdentifier: DungeonReachability] {
        let freeReachable = reachable(from: start, traversal: .keyless)
        let allReachable  = reachable(from: start, traversal: .allGatesOpen)

        var result: [ObjectIdentifier: DungeonReachability] = [:]
        for node in nodes {
            let id = ObjectIdentifier(node)
            if freeReachable.contains(id)      { result[id] = .reachable }
            else if allReachable.contains(id)  { result[id] = .keyGated  }
            else                               { result[id] = .unreachable }
        }
        return result
    }

    /// Returns doors that open to the map exterior (one resolved side, one exterior).
    public func entrances() -> [DungeonDoor] { entranceDoors }

    /// Rooms (not hallways) that hold each key, in map order.
    public func keyLocations() -> [String: [DungeonRoom]] {
        var result: [String: [DungeonRoom]] = [:]
        for room in nodes where !(room is DungeonHallway) {
            for keyID in room.keyIDs {
                result[keyID, default: []].append(room)
            }
        }
        return result
    }

    /// Doors that name this key, in map order.
    public func doors(openedBy keyID: String) -> [DungeonDoor] {
        doors.filter { $0.keyID == keyID }
    }

    /// keyIDs named by doors that no room on this map holds.
    public var keyIDsWithoutKeys: Set<String> {
        let available = Set(keyLocations().keys)
        let needed = Set(doors.compactMap { $0.keyID })
        return needed.subtracting(available)
    }

    // MARK: - Private helpers

    private static func probePoints(for door: DungeonDoor) -> (from: MapPoint?, to: MapPoint?) {
        switch door.kind {
        case .staircase, .passage:
            // Path-based: each probe starts from the center of the end cap (the end segment
            // point offset by half the door's width to the right of travel, using the same
            // perpendicular `computeEdges` uses), then moves outward along the local tangent.
            if let segs = door.segments, segs.count >= 2 {
                let width = door.doorWidth

                let startDirection = (segs[1] - segs[0]).normalized()
                let startCenter = segs[0] + startDirection.perpendicular() * (width / 2)
                let start = startCenter - startDirection * 0.5

                let endDirection = (segs[segs.count - 1] - segs[segs.count - 2]).normalized()
                let endCenter = segs[segs.count - 1] + endDirection.perpendicular() * (width / 2)
                let end = endCenter + endDirection * 0.5

                return (start, end)
            }
            fallthrough
        default:
            return (centroid(door.fromArea), centroid(door.toArea))
        }
    }

    private static func centroid(_ polygon: [MapPoint]) -> MapPoint? {
        guard !polygon.isEmpty else { return nil }
        let sum = polygon.reduce(MapPoint(x: 0, y: 0)) { $0 + $1 }
        return sum * (1.0 / Double(polygon.count))
    }

    private static func resolveNode(at point: MapPoint, in nodes: [DungeonRoom]) -> DungeonRoom? {
        // Check non-hallway rooms first; hallways may share boundary pixels with rooms.
        for node in nodes where !(node is DungeonHallway) {
            if node.contains(point) { return node }
        }
        for node in nodes where node is DungeonHallway {
            if node.contains(point) { return node }
        }
        return nil
    }
}

/// A key found in a room during a `keyProgression` walk.
public struct KeyPickup {
    public let keyID: String
    public let room: DungeonRoom
}

/// The step-by-step unlocking of a map, starting from a given room and finding keys as they
/// become reachable.
public struct KeyProgression {
    public struct Step {
        /// Doors opened at the start of this step by keys found in the previous step. Empty for step 0.
        public let doorsOpened: [DungeonDoor]
        /// Rooms (not hallways) reached for the first time in this step, in map order.
        public let roomsReached: [DungeonRoom]
        /// Keys not already held that are found in this step's rooms, in map order of the rooms.
        public let keysFound: [KeyPickup]
    }
    public let steps: [Step]
    public let heldKeys: Set<String>
    /// Rooms (not hallways) that are reachable with every gate open but were never reached, in map order.
    public let lockedOut: [DungeonRoom]
    /// Key-gated doors that connect two nodes and were never passable, in map order.
    public let unopenedDoors: [DungeonDoor]
}

extension DungeonConnectivity {

    /// Walks the map from `start`, collecting keys as they become reachable and opening the
    /// doors they unlock, until no new keys are found.
    public func keyProgression(from start: DungeonRoom, findsSecrets: Bool = true) -> KeyProgression {
        var held = Set<String>()
        var steps: [KeyProgression.Step] = []
        var reachedIDs = Set<ObjectIdentifier>()

        func roomsInOrder(_ ids: Set<ObjectIdentifier>) -> [DungeonRoom] {
            nodes.filter { !($0 is DungeonHallway) && ids.contains(ObjectIdentifier($0)) }
        }

        func newKeys(in rooms: [DungeonRoom]) -> [KeyPickup] {
            var seen = Set<String>()
            var result: [KeyPickup] = []
            for room in rooms {
                for keyID in room.keyIDs where !held.contains(keyID) && seen.insert(keyID).inserted {
                    result.append(KeyPickup(keyID: keyID, room: room))
                }
            }
            return result
        }

        // Step 0
        var traversal = Traversal(opensLocks: false, opensSecrets: findsSecrets, respectsOneWay: true, heldKeys: held)
        var reachableSet = reachable(from: start, traversal: traversal)
        var roomsReached = roomsInOrder(reachableSet)
        reachedIDs = reachableSet
        var keysFound = newKeys(in: roomsReached)
        steps.append(KeyProgression.Step(doorsOpened: [], roomsReached: roomsReached, keysFound: keysFound))

        while !keysFound.isEmpty {
            let foundKeyIDs = Set(keysFound.map { $0.keyID })
            held.formUnion(foundKeyIDs)
            traversal = Traversal(opensLocks: false, opensSecrets: findsSecrets, respectsOneWay: true, heldKeys: held)
            reachableSet = reachable(from: start, traversal: traversal)

            let doorsOpened = connections.filter { conn in
                guard conn.keyGated, let keyID = conn.keyID, foundKeyIDs.contains(keyID) else { return false }
                guard conn.neighbor(of: conn.from, traversal: traversal) != nil else { return false }
                return reachableSet.contains(ObjectIdentifier(conn.from)) || reachableSet.contains(ObjectIdentifier(conn.to))
            }.map { $0.door }

            roomsReached = roomsInOrder(reachableSet.subtracting(reachedIDs))
            reachedIDs = reachableSet
            keysFound = newKeys(in: roomsReached)

            if !roomsReached.isEmpty || !doorsOpened.isEmpty {
                steps.append(KeyProgression.Step(doorsOpened: doorsOpened, roomsReached: roomsReached, keysFound: keysFound))
            }
        }

        let fullyReachable = reachable(from: start, traversal: .allGatesOpen)
        let lockedOut = roomsInOrder(fullyReachable.subtracting(reachedIDs))

        let finalTraversal = Traversal(opensLocks: false, opensSecrets: findsSecrets, respectsOneWay: true, heldKeys: held)
        let unopenedDoors = connections.filter {
            $0.keyGated && $0.neighbor(of: $0.from, traversal: finalTraversal) == nil
        }.map { $0.door }

        return KeyProgression(steps: steps, heldKeys: held, lockedOut: lockedOut, unopenedDoors: unopenedDoors)
    }
}
