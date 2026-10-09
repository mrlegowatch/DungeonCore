# Quick Reference: JSON Dungeon Map Format

## Loading a Dungeon

```swift
// Load from a JSON file in a bundle
let dungeon = try Dungeon(fileName: "MyDungeon", from: .main, context: myContext)

// Or load from a file URL
let dungeon = try Dungeon(contentsOf: url, context: myContext)

// Or manually decode JSON (DungeonData is the coding-only mirror of Dungeon)
let jsonData = try Data(contentsOf: url)
let dungeonData = try JSONDecoder().decode(DungeonData.self, from: jsonData, configuration: myContext)

// Build DungeonMap values from the decoded maps
let maps = dungeonData.maps.map { DungeonMap(data: $0) }
```

`myContext` is a `DungeonCodingContext`, which carries the `Currencies` registry used to decode
coin amounts (`Treasure.coins`, `TreasureItem.value`). Pass `DungeonCodingContext()` for an empty
registry if the dungeon has no currency-valued fields.

## Top-Level Structure

A dungeon JSON document is a single object: an `id`, a `name`, and one or more `maps` (floors/levels).

```json
{
  "id": "swamp-king-lair-level-1",
  "name": "Lair of the Swamp King: First Level",
  "maps": [
    {
      "id": "first_level",
      "name": "First Level",
      "sections": [],
      "rooms": [],
      "hallways": [],
      "doors": []
    }
  ]
}
```

## Creating JSON Manually

### Simple Rectangular Room
```json
{
  "id": "floor_1",
  "name": "floor 1",
  "maps": [
    {
      "id": "floor_1",
      "name": "floor 1",
      "rooms": [
        {
          "id": "1",
          "location": {"x": 0, "y": 0},
          "size": {"width": 20, "height": 15}
        }
      ],
      "hallways": [],
      "doors": []
    }
  ]
}
```

### Polygon Room (Custom Shape)
```json
{
  "id": "1",
  "edges": [
    {"x": 0, "y": 0},
    {"x": 20, "y": 0},
    {"x": 20, "y": 15},
    {"x": 10, "y": 20},
    {"x": 0, "y": 15}
  ]
}
```

### Ellipse Room
A room inscribed in the `location`/`size` bounding box, instead of a rectangle.
```json
{
  "id": "32",
  "shape": "ellipse",
  "location": {"x": 11.0, "y": 27.0},
  "size": {"width": 5.0, "height": 5.0}
}
```

### Interior Walls
Freestanding wall segments drawn inside a room. Drawing-only: they do not affect containment,
connectivity, or reachability.
```json
{
  "id": "4",
  "location": {"x": 10, "y": 1},
  "size": {"width": 4, "height": 4},
  "walls": [
    [{"x": 11, "y": 1}, {"x": 11, "y": 3}],
    [{"x": 13, "y": 1}, {"x": 13, "y": 3}]
  ]
}
```

### Hallway from Segments
```json
{
  "segments": [
    {"x": 0, "y": 0},
    {"x": 10, "y": 0},
    {"x": 10, "y": 10}
  ],
  "width": 5
}
```

### Hallway with Pre-computed Edges
```json
{
  "edges": [
    {"x": 0, "y": 0},
    {"x": 10, "y": 0},
    {"x": 10, "y": 10},
    {"x": 5, "y": 10},
    {"x": 5, "y": 5},
    {"x": 0, "y": 5}
  ]
}
```

### Keyed Room with Metadata
```json
{
  "id": "4",
  "location": {"x": 0, "y": 0},
  "size": {"width": 10, "height": 10},
  "keyNumber": "4",
  "readAloud": "Three goblins crouch around a locked chest.",
  "gmNotes": "The chest holds 40 gp.",
  "contentTags": ["encounter", "treasure"],
  "sectionID": "gatehouse"
}
```

### Room Encounters and Treasure
```json
{
  "id": "2",
  "location": {"x": 2, "y": 2},
  "size": {"width": 4, "height": 7},
  "encounters": [
    {
      "name": "Goblin",
      "count": 3,
      "alignment": "Chaotic Evil",
      "stats": { "armorClass": 13, "hitPoints": [7], "attacks": 1, "damage": ["1d6+2"], "text": "AC 13, HP 7, ATK +4, DMG 1d6+2" },
      "carried": { "items": [ { "name": "Guardroom key", "keyID": "guard-key" } ] }
    }
  ],
  "treasure": {
    "coins": { "gp": 40, "sp": 15 },
    "items": [ { "name": "Potion of Healing" } ]
  }
}
```

### Room Occupancy (Wandering Group Chance)
A chance that a wandering group occupies the room, separate from any `encounters` (which are
always present). `table` is optional — when absent, rolling occupied leaves who's there up to
the GM.
```json
{
  "id": "entrance",
  "occupancy": {
    "chance": { "die": "d10", "atMost": 2 },
    "table": {
      "die": "d4",
      "rows": [
        { "from": 1, "to": 2, "encounter": { "name": "Bracken-folk", "count": 8 } },
        { "from": 3, "to": 4, "encounter": { "name": "Glubbin", "count": 8 } }
      ]
    },
    "notes": "Optional."
  }
}
```

A room with no table of its own can borrow another room's table instead, via `tableRoomID`
(resolved one hop only — the named room's own `tableRoomID`, if any, is not followed):
```json
{
  "id": "1",
  "occupancy": {
    "chance": { "die": "d10", "atMost": 3, "per": "turn" },
    "tableRoomID": "entrance"
  }
}
```

### Room Label Location
Overrides automatic corner placement for a room's number label; the point is where the
label's center is drawn, and may lie outside the room (e.g. a corridor's name in the
margin beside it).
```json
{ "id": "entrance", "name": "Entrance", "labelLocation": { "x": 11.5, "y": 1.5 }, "location": { "x": 13.0, "y": 1.0 }, "size": { "width": 1.0, "height": 7.0 } }
```

### Basic Door
```json
{
  "leftEdge": {"x": 10, "y": 5},
  "rightEdge": {"x": 11, "y": 5}
}
```

### Door with All Options
```json
{
  "leftEdge": {"x": 10, "y": 5},
  "rightEdge": {"x": 11, "y": 5},
  "kind": "door",
  "width": 1,
  "rotation": 90,
  "attributes": ["isLocked", "isSecret"],
  "keyID": "brass-key"
}
```

### Opening (Doorway without a door)
```json
{
  "leftEdge": {"x": 10, "y": 5},
  "rightEdge": {"x": 12, "y": 5},
  "kind": "opening",
  "width": 2
}
```

### Trap Door (Area-based)
```json
{
  "kind": "trapDoor",
  "location": {"x": 5, "y": 5},
  "size": {"width": 1, "height": 1}
}
```

### Staircase with Segments and Direction
```json
{
  "kind": "staircase",
  "segments": [
    {"x": 0, "y": 0},
    {"x": 5, "y": 0},
    {"x": 5, "y": 10}
  ],
  "width": 3,
  "stairDirection": "down"
}
```

### Magic Portal with Remote Connection
```json
{
  "kind": "magicPortal",
  "leftEdge": {"x": 10, "y": 5},
  "rightEdge": {"x": 11, "y": 5},
  "connection": {
    "mapID": "floor_2",
    "end": {"x": 20, "y": 15}
  }
}
```

## Field Reference

### DungeonData Fields (top-level document)
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique identifier for the dungeon |
| name | String | Yes | Display name for the dungeon |
| maps | Array | Yes | Array of map objects (floors/levels), see DungeonMapData Fields; must contain at least one map |

### DungeonMapData Fields
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique identifier for the map |
| name | String | Yes | Display name for the map |
| sections | Array | No | Named groupings of rooms, see Map Section Fields |
| rooms | Array | Yes | Array of Room objects |
| hallways | Array | No | Array of Hallway objects; defaults to empty |
| doors | Array | No | Array of Door objects; defaults to empty |

### Map Section Fields
A section is a named grouping of rooms under a module heading (e.g. "Lair of the Bracken-folk"),
declared once on the map and referenced by each room's `sectionID`.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique within the map; referenced by room `sectionID` |
| name | String | Yes | Display name for the section |
| gmNotes | String | No | GM-only notes about the section |

```json
{ "id": "bracken-folk", "name": "Lair of the Bracken-folk" }
```

### Room Fields
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique identifier for the room within the map |
| location | Object | Conditional* | Top-left corner {x, y} |
| size | Object | Conditional* | Dimensions {width, height} |
| edges | Array | Conditional* | Array of {x, y} points defining polygon |
| shape | String | No | `"ellipse"` to inscribe an ellipse in `location`/`size`; omitted for rectangle/polygon rooms |
| walls | Array | No | Array of polylines (each an array of {x, y} points): freestanding interior walls, drawing-only |
| name | String | No | Display name for the room |
| keyNumber | String | No | Key identifier linking this room to module text (e.g. "4", "12a") |
| readAloud | String | No | Passage to read aloud to players when they enter the room |
| gmNotes | String | No | GM-only description of the room's contents |
| contentTags | Array | No | Content categories: `"encounter"`, `"treasure"`, `"trap"`, `"hazard"`, `"empty"`, `"special"` |
| sectionID | String | No | Id of a section declared in the map's `sections`, grouping this room under a module heading |
| encounters | Array | No | Array of Room Encounter objects (see Room Encounter Fields) |
| treasure | Object | No | Treasure found in the room (see Treasure Fields) |
| features | Array | No | Array of Room Feature objects: point features inside the room (see Room Feature Fields) |
| occupancy | Object | No | Chance a wandering group occupies the room (see Room Occupancy Fields) |
| labelLocation | Object | No | Map point {x, y} where the center of the room's number label is drawn, overriding automatic corner placement; may lie outside the room |

*Either (location + size) OR edges is required

### Room Feature Fields

A `RoomFeature` is a single keyed point inside a room — a lever, idol, pool, trap door, or
similar element a module calls out by its own letter (e.g. `"17A"`, `"26C"`), as opposed to
`"8-chest"` which has no module letter of its own.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Unique within the map (e.g. `"17A"`, `"26C"`, `"8-chest"`) |
| kind | String | Yes | One of `"area"`, `"lever"`, `"idol"`, `"pool"`, `"pit"`, `"trap"`, `"hazard"`, `"hearth"`, `"floorHatch"`, `"ceilingHatch"`, `"container"`, `"furnishing"`, `"decoration"`, `"stairs"`, `"other"` |
| location | Object | Yes | Map coordinates {x, y}, inside the owning room |
| name | String | No | Display name for the feature |
| size | Object | No | {width, height}; when present, the feature covers a rectangle of this size centered on `location` instead of being a single point |
| readAloud | String | No | Passage to read aloud when players discover this feature |
| gmNotes | String | No | GM-only notes about this feature |
| treasure | Object | No | Treasure held by this feature, same shape as room `treasure` |

```json
{
  "id": "17A",
  "kind": "lever",
  "name": "Blue wooden lever",
  "location": {"x": 10.5, "y": 11.5},
  "gmNotes": "When it is up (as it normally is), the water level is up to 10', and when it is down, so is the water."
}
```

### Room Encounter Fields

A room's `encounters` are groups of creatures that are always present (as opposed to
`occupancy`, which is rolled).

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| name | String | Yes | - | The creature type name (e.g. "Goblin", "Orc Chieftain") |
| count | Number or dice String | No | 1 | Number of creatures, as an integer or dice expression (e.g. `2`, `"2d6"`, `"1d4+2"`) |
| alignment | String or Object | No | - | `"Chaotic Evil"`, or `{"ethics": ..., "morals": ...}` |
| notes | String | No | - | DM notes about this creature group (e.g. "One carries the key to area 4") |
| creatureType | String | No | - | Creature type classification (e.g. "Undead", "Beast") |
| size | String | No | - | Creature size classification |
| stats | Object | No | - | Compact stat line as printed in the key (see Room Encounter Stat Line Fields) |
| carried | Object | No | - | Treasure held by the group as a whole (e.g. "one has a small silver key"), same shape as room `treasure` |
| carriedEach | Object | No | - | Treasure rolled once per creature in the group (e.g. "d6 gp each"), same shape as room `treasure` |

```json
{
  "name": "Goblin",
  "count": "2d6",
  "alignment": "Chaotic Evil",
  "notes": "One carries the key to area 4"
}
```

### Room Encounter Stat Line Fields

A compact creature stat line as printed in an adventure key (armor class, hit dice, hit points,
attacks, damage), with the source's own wording preserved verbatim in `text`.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| armorClass | Number | No | Armor class |
| hitDice | String | No | Hit dice in the source's own notation: `"1"`, `"1+1"`, `"1-1"`, `"1/4"`, `"4+3"`, or `"2d8+2"` |
| hitPoints | Array | No | Hit points for the group; one value applies to every creature, several values list individuals |
| attacks | Number | No | Number of attacks per round |
| damage | Array | No | Damage per attack, or per alternative weapon, in dice notation (e.g. `"1d6+2"`) |
| special | String | No | Whatever does not fit a number: `"poison"`, `"battle axe"`, `"per round until washed with water"` |
| text | String | No | The stat line exactly as the source prints it |

```json
{
  "name": "Goblin",
  "count": 3,
  "stats": { "armorClass": 13, "hitPoints": [7], "attacks": 1, "damage": ["1d6+2"], "special": "ATK +4", "text": "AC 13, HP 7, ATK +4, DMG 1d6+2" }
}
```

### Room Occupancy Fields

A chance that a wandering group occupies a room, with an optional table of who shows up.
Occupancy is separate from `encounters`: encounters are always present, occupancy is rolled.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| chance | Object | Yes | How likely a group is present (see Chance Fields) |
| table | Object | No | Who shows up on a success (see Encounter Table Fields); when absent, the GM chooses |
| tableRoomID | String | No | Id of another room on the same map whose table to use instead, when this room has no `table` of its own. Resolved one hop only; this room's own `table`, when present, wins |
| notes | String | No | GM notes about the occupancy (e.g. source of the wandering group) |

#### Chance Fields
"1-3 on d10 per turn" succeeds when `die` rolls `atMost` or lower.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| die | Number or dice String | Yes | The die to roll, e.g. `"d10"` |
| atMost | Number | Yes | Succeeds when the roll is this value or lower |
| per | String | No | How often this is checked, e.g. `"turn"`, `"four hours"`; omitted for a single check on arrival |

#### Encounter Table Fields
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| die | Number or dice String | Yes | The die rolled to select a row, e.g. `"d4"` |
| rows | Array | Yes | Array of `{from, to, encounter}` objects |

Each row's `from`/`to` are inclusive integer bounds on the `die` roll, and `encounter` is a
Room Encounter object (see Room Encounter Fields).

```json
{
  "die": "d4",
  "rows": [
    { "from": 1, "to": 2, "encounter": { "name": "Bracken-folk", "count": 8 } },
    { "from": 3, "to": 4, "encounter": { "name": "Glubbin", "count": 8 } }
  ]
}
```

### Treasure Fields
Coins and items found in a dungeon room, a room feature, or carried by an encounter.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| coins | Object | No | Coin amounts per denomination, keyed by currency symbol: an integer or dice expression, e.g. `{"gp": "d10", "sp": "2d8", "cp": 175}` |
| items | Array | No | Array of Treasure Item objects |
| notes | String | No | Notes about where or how the treasure is concealed |

```json
{ "coins": { "sp": "2d8", "gp": "d10", "cp": 175 }, "items": [ ... ], "notes": "Hides under the larger male's bed." }
```

### Treasure Item Fields
A single named item found in a dungeon room, optionally a key.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| name | String | Yes | - | The item's name (e.g. "Potion of Healing", "Bronze key") |
| quantity | Number or dice String | No | 1 | How many of this item are present, as an integer or dice expression |
| value | String or Number | No | - | The value of a single item, e.g. `"5 gp"` |
| keyID | String | No | - | When set, this item is a key matching a door's `keyID` |
| isMagic | Bool | No | false | Whether this item is magical |
| notes | String | No | - | Notes about this item |

```json
{ "name": "Bronze key", "quantity": 2, "value": "5 gp", "keyID": "portcullis-bronze-key", "isMagic": false, "notes": "Open the portcullises at 9." }
```

### Dice-Valued Amounts
Several fields accept either a plain JSON integer or a string in standard dice notation
(e.g. `"2d6"`, `"d10"`, `"1d4+2"`): `RoomEncounter.count`, `TreasureItem.quantity`,
`StatLine.damage` entries, `Treasure.coins` amounts, and `Chance`/`EncounterTable`'s `die`.
On encode, a constant value is written as a plain integer and anything else as its dice
notation string.

### Hallway Fields
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| segments | Array | Conditional* | Centerline points {x, y} |
| width | Number | With segments | Width of hallway |
| edges | Array | Conditional* | Pre-computed polygon points |

*Either (segments + width) OR edges is required

### Door Fields
| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| leftEdge | Object | Conditional** | - | Left edge point {x, y} |
| rightEdge | Object | Conditional** | - | Right edge point {x, y} |
| kind | String | No | "door" | Door type (see Door Types below) |
| name | String | No | - | Display name for the door |
| width | Number | No | 1 | Width of door |
| rotation | Number | No | 0 | Rotation in degrees |
| attributes | Array | No | [] | Array of attribute strings (see Door Attributes below) |
| segments | Array | No | - | Path segments for staircase/passage |
| edges | Array | No | - | Pre-computed edges for staircase/passage |
| location | Object | No | - | Location for trapDoor/elevator |
| size | Object | No | - | Size for trapDoor/elevator |
| connection | Object | No | - | Remote connection for magicPortal |
| keyID | String | No | - | The key that opens this door, when gated; `nil` even on a locked/barred/sealed door without one |
| stairDirection | String | No | - | `"up"` or `"down"`: meaningful only for `staircase` and `ladder`, travel from the first segment point to the last |

**Required fields vary by door kind (see Door Types below)

### Door Types and Required Fields

| Kind | Required Fields | Optional Fields | Description |
|------|----------------|-----------------|-------------|
| opening | leftEdge, rightEdge | width, rotation, attributes | Open doorway |
| door | leftEdge, rightEdge | width, rotation, attributes, keyID | Standard hinged door |
| portcullis | leftEdge, rightEdge | width, rotation, attributes, keyID | Heavy vertical gate |
| slidingDoor | leftEdge, rightEdge | width, rotation, attributes, keyID | Sliding door |
| ladder | leftEdge, rightEdge | width, rotation, attributes, stairDirection | Vertical climbing element |
| trapDoor | location, size | leftEdge, rightEdge, width, attributes, keyID | Floor/ceiling hatch |
| elevator | location, size | leftEdge, rightEdge, width, attributes | Vertical transport platform |
| staircase | edges OR segments | width, leftEdge, rightEdge, attributes, stairDirection | Set of stairs |
| passage | edges OR segments | width, leftEdge, rightEdge, attributes | Corridor-like connection |
| magicPortal | leftEdge, rightEdge | width, rotation, attributes, connection | Magical transport |
| caveEntrance | leftEdge, rightEdge | width, rotation, attributes | Natural cave opening |

### Door Attributes

Valid values for the `attributes` array:
- `"isLocked"` - Door is locked
- `"hasTrap"` - Door has a trap
- `"isSecret"` - Door is hidden/secret
- `"isOneWay"` - Door only opens one direction
- `"isStuck"` - Door is stuck/jammed
- `"isBarred"` - Door is barred
- `"hasMagicSeal"` - Door has a magical seal

### Remote Connection Fields

Used with `magicPortal` doors:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| mapID | String | Yes | Target map identifier |
| end | Object | Yes | Destination point {x, y} |

## Complete Example

```json
{
  "id": "floor_1",
  "name": "Main Floor",
  "maps": [
    {
      "id": "floor_1",
      "name": "Main Floor",
      "sections": [
        { "id": "gatehouse", "name": "Gatehouse" }
      ],
      "rooms": [
        {
          "id": "1",
          "location": {"x": 0, "y": 0},
          "size": {"width": 20, "height": 15},
          "sectionID": "gatehouse"
        },
        {
          "id": "2",
          "location": {"x": 25, "y": 0},
          "size": {"width": 15, "height": 15},
          "encounters": [
            { "name": "Goblin", "count": 3, "alignment": "Chaotic Evil" }
          ],
          "treasure": {
            "coins": { "gp": 40, "sp": 15 }
          }
        },
        {
          "id": "3",
          "edges": [
            {"x": 0, "y": 20},
            {"x": 20, "y": 20},
            {"x": 20, "y": 40},
            {"x": 0, "y": 40}
          ]
        }
      ],
      "hallways": [
        {
          "segments": [
            {"x": 20, "y": 7.5},
            {"x": 25, "y": 7.5}
          ],
          "width": 5
        },
        {
          "segments": [
            {"x": 10, "y": 20},
            {"x": 10, "y": 15}
          ],
          "width": 5
        }
      ],
      "doors": [
        {
          "leftEdge": {"x": 20, "y": 7},
          "rightEdge": {"x": 20, "y": 8},
          "kind": "door",
          "attributes": ["isLocked"]
        },
        {
          "leftEdge": {"x": 9, "y": 15},
          "rightEdge": {"x": 11, "y": 15},
          "kind": "opening",
          "width": 2
        }
      ]
    }
  ]
}
```

## Tips

1. **Units**: All coordinates, sizes, and widths are in grid units, where one
   grid square is 1. Fractions such as 0.5 are allowed. What a grid unit
   represents in the world (5 or 10 feet, say) is up to the map author; the
   format doesn't record it.
2. **Polygon edges**: List `edges` in order around the boundary. Either
   direction, clockwise or counterclockwise, works.
3. **Doors connect areas**: Place a door's `leftEdge` and `rightEdge` on the
   wall shared by two rooms or hallways. Connectivity finds the door's two
   sides by looking just past it in each direction, so a door that isn't on
   a shared wall connects nothing.
4. **Door direction**: The order of `leftEdge` and `rightEdge` decides which
   side is `fromArea` and which is `toArea`. This matters only for one-way
   doors (`isOneWay`), which allow passage from `fromArea` to `toArea`.
5. **Hallway width**: In grid units, like everything else. Defaults to 1 (one
   square wide); most corridors are 1 or 2.
6. **Check what loaded**: An element that can't be built from its data is
   skipped, not fatal. `DungeonMap.decodingIssues` lists what was skipped
   and why. A dungeon with no maps fails to load.

## Error Handling

```swift
do {
    let jsonData = try Data(contentsOf: url)
    let dungeonData = try JSONDecoder().decode(DungeonData.self, from: jsonData, configuration: myContext)
    let maps = dungeonData.maps.map { DungeonMap(data: $0) }
} catch {
    print("Failed to load dungeon: \(error)")
}
```

## Programmatic Creation

Build a dungeon with the public model classes, then encode it to JSON. `DungeonData`/`RoomData`/
`DoorData`/`HallwayData` are internal coding-only mirrors used by `Dungeon`'s own encode/decode;
build dungeons through `Dungeon`, `DungeonMap`, `DungeonRoom`, `DungeonHallway`, and `DungeonDoor`
instead.

```swift
let dungeon = Dungeon()
let map = dungeon.maps[0]

let room = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 10, height: 10))
room.keyNumber = "1"
map.addRoom(room)

let door = DungeonDoor(kind: .door, leftEdge: MapPoint(x: 10, y: 5), rightEdge: MapPoint(x: 11, y: 5))
map.addDoor(door)

// Encode to JSON
let jsonData = try dungeon.encoded(context: myContext)
let jsonString = String(data: jsonData, encoding: .utf8)
print(jsonString ?? "")
```
