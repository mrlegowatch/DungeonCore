# DungeonCore

![Swift Version](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-lightgrey.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Swift package providing reusable core logic for creating, managing, and running tabletop RPG dungeon maps. It is a work in progress; capabilities are being added incrementally.

The short-term goal is to represent a dungeon module the way a GM encounters it in print: multi-level maps made of rooms, hallways, and doors, each keyed to the module's text with read-aloud passages, GM notes, encounters, treasure, point features (levers, idols, pools, traps), and occupancy checks. On top of that, a derived connectivity graph answers reachability questions—which areas are freely reachable, which are gated behind a key or a secret door, and which are unreachable even once every gate is open—to help a GM or map author reason about key progression and pacing.

The library is a generic Swift Package. The included DungeonMapBuilder example app demonstrates iOS/macOS usage with a SwiftUI map viewer and room-content editor.

## Installation

Add DungeonCore as a Swift package dependency, pointing at a released version:

```swift
dependencies: [
    .package(url: "https://github.com/mrlegowatch/DungeonCore.git", from: "0.1.0"),
],
```

Then add `"DungeonCore"` to your target's `dependencies`.

## Dependencies

DungeonCore depends on [RolePlayingCore](https://github.com/mrlegowatch/RolePlayingCore) and [SwiftDice](https://github.com/mrlegowatch/SwiftDice), both resolved as versioned Swift packages from GitHub (not local paths). RolePlayingCore provides `Treasure`'s currency types (`Money`, `Currencies`), `CharacterAlignment`, `CreatureType`, `CreatureSize`, and `StatLine`, and the `CodableWithConfiguration` pattern used throughout DungeonCore's JSON coding. SwiftDice is used directly, via RolePlayingCore, for `AnyRollable`—the dice-or-constant type behind encounter counts, treasure amounts, and occupancy checks.

## Organization

The source code is grouped into the following areas under `Sources/DungeonCore`:

| Group | What's inside |
|---|---|
| **Dungeons & Maps** | `Dungeon`, `DungeonMap`, `DungeonSection`, `DungeonCodingContext`, `UntitledCounter` |
| **Map Elements** | `DungeonRoom`, `DungeonHallway`, `DungeonDoor`; `MapPoint`, `MapSize`; `WallRuns` |
| **Room Content** | `RoomFeature`; `RoomEncounter`, `Treasure`, `TreasureItem` (in `RoomContent`); `Occupancy`, `Chance`, `EncounterTable` |
| **Connectivity** | `DungeonConnectivity`, `Traversal`, `DungeonReachability` |

## Example App

`Examples/DungeonMapBuilder` is a SwiftUI iOS/macOS (Mac Catalyst) app that demonstrates the library. It loads dungeons from JSON via `Dungeon(fileName:)` and provides:

- A **map viewer**—a zoomable, pannable canvas rendering rooms, hallways, doors, and labels, with per-overlay show/hide toggles (room/hallway/door labels, feature markers, door-side debug tinting)
- A **room detail panel**—shown as a trailing inspector on Mac Catalyst/iPad and a bottom sheet on iPhone, displaying a room's read-aloud text, GM notes, occupancy roll, encounters, treasure, point features, and content tags
- A **room content editor**—edits a room's text, encounters, treasure, and occupancy in place
- A **flow mode**—highlights reachable, key-gated, and unreachable areas from a chosen starting room via `DungeonConnectivity`, with a key-progression summary

Geometry editing (adding and moving rooms, hallways, and doors) exists in the app but is unfinished, so it stays behind a `-enableMapEditing` launch argument rather than shipping in the default build.

## Persistence

Dungeons round-trip to JSON via `Dungeon.init(contentsOf:context:)` / `Dungeon.write(to:context:)`. A `DungeonCodingContext` threads a `Currencies` registry through the decode/encode chain so `Treasure`'s coin amounts resolve against the host app's currency symbols—see `CodableWithConfiguration` in RolePlayingCore. Rooms serialize compactly: an axis-aligned rectangular room writes `location`/`size`, an ellipse writes `location`/`size`/`shape`, and an arbitrary polygon falls back to its raw `edges` array.

## What Is Implemented

### Dungeons & Maps

- **`Dungeon`**—the top-level container: an `id`, a `name`, an optional `url`, and an array of `DungeonMap` levels. Create a new empty dungeon, or load/save one as JSON (`init(contentsOf:)`, `init(fileName:from:)`, `write(to:)`, `save()`).
- **`DungeonMap`**—a single floor: `rooms`, `hallways`, `doors`, and named `sections`. Provides mutation (`addRoom`/`removeRoom`/`insertRoom`, same for hallways/doors/sections), lookup (`room(withID:)`, `feature(withID:)`, `section(for:)`, `rooms(in:)`), consistency checks (`duplicateFeatureIDs`, `featuresOutsideTheirRooms`, `unknownSectionIDs`, `unknownOccupancyTableRoomIDs`), and occupancy rolls (`rollOccupancy(for:)`, `rollOccupancyDetail(for:)`, `encounterTable(for:)`).
- **`DungeonSection`**—a named grouping of rooms under a module heading (e.g. "Lair of the Bracken-folk"), referenced by `DungeonRoom.sectionID`.
- **`DungeonCodingContext`**—the single configuration type threaded through the `CodableWithConfiguration` chain for dungeon JSON (currently just a `Currencies` registry), so new registries can be added without changing every type's coding signature.
- **`UntitledCounter`**—thread-safe counter (via `Synchronization.Atomic`) that names new, unsaved dungeons "Untitled", "Untitled 2", and so on.

### Map Elements

- **`DungeonRoom`**—a room defined by `location`/`size` (rectangle), an `edges` polygon, or an ellipse bounding box. Carries a module `keyNumber`, `name`, `readAloud` text, `gmNotes`, `contentTags` (encounter/treasure/trap/hazard/empty/special), `encounters`, `treasure`, point `features`, `occupancy`, interior decorative `walls`, and an optional manual `labelLocation`. `contains(_:)` does ray-casting point-in-polygon hit testing; `translate(by:)` moves the room and everything attached to it.
- **`DungeonHallway`**—a `DungeonRoom` subclass for corridors, built either from centerline `segments` plus a `width` (edges are computed by `computeEdges(from:width:)` in `DungeonSegment.swift`, with mitered corners) or from explicit `edges`.
- **`DungeonDoor`**—a `DungeonRoom` subclass covering ten door/passage kinds (`opening`, `door`, `portcullis`, `slidingDoor`, `ladder`, `trapDoor`, `elevator`, `staircase`, `passage`, `magicPortal`, `caveEntrance`), each with its own geometry convention (two edge points, a rectangular area, or a path). Attributes (`isLocked`, `hasTrap`, `isSecret`, `isOneWay`, `isStuck`, `isBarred`, `hasMagicSeal`) and an optional `keyID` describe gating; `fromArea`/`toArea` compute the polygons on either side for connectivity probing; `connection` supports a remote link to another map.
- **`MapPoint`** / **`MapSize`**—2D point and size types with vector operations (`+`, `-`, unary `-`, `*`, `length()`, `normalized()`, `perpendicular()`, `dot(_:)`) used throughout the map geometry.
- **`WallRuns`**—`DungeonMap.wallRuns(for:doorGapRatio:)` returns a room's outline as wall polylines with the spans its doors occupy cut out, for rendering walls that visibly open at each door.

### Room Content

- **`RoomFeature`**—a single keyed point feature inside a room (lever, idol, pool, pit, trap, hazard, hearth, floor/ceiling hatch, container, furnishing, decoration, stairs, other), with its own `location`, optional footprint `size`, read-aloud text, GM notes, and `treasure`.
- **`RoomEncounter`** / **`Treasure`** / **`TreasureItem`** (`RoomContent.swift`)—`RoomEncounter` describes a creature group (name, `AnyRollable` count, alignment, notes, creature type/size, a compact `StatLine`, and treasure carried by the group or by each member). `Treasure` pairs coin amounts (a `MoneyRoll`, so amounts can be dice expressions) with a list of `TreasureItem`s, any of which may double as a door key via `keyID`.
- **`Occupancy`** / **`Chance`** / **`EncounterTable`**—`Chance` is a threshold check ("1-3 on d10 per turn"); `EncounterTable` picks a row by rolling its `die` and looking up the matching range. `Occupancy` combines a `Chance` with either its own table or a reference to another room's table (`tableRoomID`), rolled via `DungeonMap.rollOccupancyDetail(for:)`.

### Connectivity

- **`DungeonConnectivity`**—a derived adjacency graph built from a map's doors. Resolves each door's two sides against room/hallway geometry, exposing `connections`, `entranceDoors` (one side resolved—exterior openings), and `portalDoors` (remote map links). Queries: `connections(from:)`, `adjacentRooms(to:)` (collapsing hallways transparently), `reachable(from:traversal:)`, and `classify(from:)`, which three-way classifies every node as `.reachable`, `.keyGated`, or `.unreachable` relative to a start room. `Traversal` configures whether locks, secrets, and one-way doors are passable, and which keys are held.

## Coming Soon

Dungeon connectivity and occupancy are new; expect refinement as the DungeonMapBuilder example's geometry editor and flow-mode tooling further develop.

## Sample Content

The "Swamp King Lair Level 1.json" sample dungeon (in the example app and in the test resources) is not covered by this repository's MIT License — see [CONTENT-NOTICE.md](CONTENT-NOTICE.md).
