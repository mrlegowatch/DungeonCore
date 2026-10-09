# ``DungeonCore``

Reusable core logic for creating, managing, and running tabletop RPG dungeon maps.

## Overview

DungeonCore represents a dungeon module the way a GM encounters it in print: multi-level maps
made of rooms, hallways, and doors, each keyed to the module's text with read-aloud passages, GM
notes, encounters, treasure, point features (levers, idols, pools, traps), and occupancy checks.
On top of that, a derived connectivity graph answers reachability questions — which areas are
freely reachable, which are gated behind a key or a secret door, and which are unreachable even
once every gate is open — to help a GM or map author reason about key progression and pacing.

Dungeons round-trip to JSON via ``Dungeon/init(contentsOf:context:)`` and
``Dungeon/write(to:context:)``. A ``DungeonCodingContext`` threads a `Currencies` registry
through the decode/encode chain so a room's treasure resolves coin amounts against the host
app's currency symbols. See the JSON Quick Reference article for the on-disk format.

The included DungeonMapBuilder example app demonstrates iOS/macOS usage with a SwiftUI map
viewer and room-content editor.

## Topics

### Dungeons & Maps

- ``Dungeon``
- ``DungeonMap``
- ``DungeonSection``
- ``DungeonCodingContext``

### Map Elements

- ``DungeonRoom``
- ``DungeonHallway``
- ``DungeonDoor``
- ``MapPoint``
- ``MapSize``
- ``MapRect``

### Room Content

- ``RoomFeature``
- ``RoomEncounter``
- ``Treasure``
- ``TreasureItem``
- ``Occupancy``
- ``Chance``
- ``EncounterTable``

### Connectivity

- ``DungeonConnectivity``
- ``Traversal``
- ``DungeonReachability``
- ``KeyProgression``
- ``KeyPickup``
