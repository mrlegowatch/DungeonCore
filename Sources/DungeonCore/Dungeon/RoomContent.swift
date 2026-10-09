//
//  RoomContent.swift
//  DungeonCore
//
//  Created by Brian Arnold on 8/1/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import Foundation
import RolePlayingCore
import SwiftDice

/// A group of creatures inhabiting a dungeon room.
///
/// `RoomEncounter` represents a single creature group for use in keyed dungeon modules.
/// The `count` field accepts an integer or standard dice notation (e.g. "2d6", "1d4+2").
///
/// ## JSON Example
/// ```json
/// {
///   "name": "Goblin",
///   "count": "2d6",
///   "alignment": "Chaotic Evil",
///   "notes": "One carries the key to area 4"
/// }
/// ```
public struct RoomEncounter: Equatable, Sendable {
    /// The creature type name (e.g. "Goblin", "Orc Chieftain").
    public var name: String
    /// The number of creatures, as an integer or dice expression (e.g. 2, "2d6", "1d4+2").
    public var count: AnyRollable
    /// The alignment of these creatures. Decoded from either a human-readable string
    /// ("Chaotic Evil") or a `{"ethics": ..., "morals": ...}` dictionary.
    public var alignment: CharacterAlignment?
    /// Optional DM notes about this creature group.
    public var notes: String?
    /// Optional creature type classification (e.g. "Undead", "Beast").
    public var creatureType: CreatureType?
    /// Optional size classification.
    public var size: CreatureSize?
    /// Optional compact stat line (armor class, hit dice, hit points, attacks, damage) as printed in the key.
    public var stats: StatLine?
    /// Treasure rolled once per creature in the group (e.g. "d6 gp each").
    public var carriedEach: Treasure?
    /// Treasure held by the group as a whole (e.g. "one has a small silver key").
    public var carried: Treasure?

    public init(name: String, count: AnyRollable = 1, alignment: CharacterAlignment? = nil, notes: String? = nil,
                creatureType: CreatureType? = nil, size: CreatureSize? = nil, stats: StatLine? = nil,
                carriedEach: Treasure? = nil, carried: Treasure? = nil) {
        self.name = name
        self.count = count
        self.alignment = alignment
        self.notes = notes
        self.creatureType = creatureType
        self.size = size
        self.stats = stats
        self.carriedEach = carriedEach
        self.carried = carried
    }

    /// The keyIDs carried by this encounter, from `carriedEach` then `carried`, without duplicates.
    public var keyIDs: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for treasure in [carriedEach, carried].compactMap({ $0 }) {
            for keyID in treasure.keyIDs where seen.insert(keyID).inserted {
                result.append(keyID)
            }
        }
        return result
    }
}

extension RoomEncounter: CodableWithConfiguration {
    public typealias DecodingConfiguration = DungeonCodingContext
    public typealias EncodingConfiguration = DungeonCodingContext

    private enum CodingKeys: String, CodingKey {
        case name, count, alignment, notes, creatureType, size, stats, carriedEach, carried
    }

    public init(from decoder: any Decoder, configuration: DungeonCodingContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        count = try container.decodeIfPresent(AnyRollable.self, forKey: .count) ?? 1
        alignment = try container.decodeIfPresent(CharacterAlignment.self, forKey: .alignment)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        creatureType = try container.decodeIfPresent(CreatureType.self, forKey: .creatureType)
        size = try container.decodeIfPresent(CreatureSize.self, forKey: .size)
        stats = try container.decodeIfPresent(StatLine.self, forKey: .stats)
        carriedEach = try container.decodeIfPresent(Treasure.self, forKey: .carriedEach, configuration: configuration)
        carried = try container.decodeIfPresent(Treasure.self, forKey: .carried, configuration: configuration)
    }

    public func encode(to encoder: any Encoder, configuration: DungeonCodingContext) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(count, forKey: .count)
        try container.encodeIfPresent(alignment, forKey: .alignment)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(creatureType, forKey: .creatureType)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(stats, forKey: .stats)
        if let carriedEach {
            try container.encode(carriedEach, forKey: .carriedEach, configuration: configuration)
        }
        if let carried {
            try container.encode(carried, forKey: .carried, configuration: configuration)
        }
    }
}

/// A single named item found in a dungeon room, optionally a key.
///
/// ## JSON Example
/// ```json
/// { "name": "Bronze key", "quantity": 2, "value": "5 gp", "keyID": "portcullis-bronze-key", "isMagic": false, "notes": "Open the portcullises at 9." }
/// ```
public struct TreasureItem: Equatable, Sendable {
    /// The item's name (e.g. "Potion of Healing", "Bronze key").
    public var name: String
    /// How many of this item are present, as an integer or dice expression. Defaults to 1.
    public var quantity: AnyRollable
    /// The value of a single item, if known.
    public var value: Money?
    /// When set, this item is a key matching a `DungeonDoor.keyID`.
    public var keyID: String?
    /// Whether this item is magical. Defaults to false.
    public var isMagic: Bool
    /// Optional DM notes about this item.
    public var notes: String?

    public init(name: String, quantity: AnyRollable = 1, value: Money? = nil, keyID: String? = nil,
                isMagic: Bool = false, notes: String? = nil) {
        self.name = name
        self.quantity = quantity
        self.value = value
        self.keyID = keyID
        self.isMagic = isMagic
        self.notes = notes
    }
}

extension TreasureItem: CodableWithConfiguration {
    public typealias DecodingConfiguration = DungeonCodingContext
    public typealias EncodingConfiguration = DungeonCodingContext

    private enum CodingKeys: String, CodingKey {
        case name, quantity, value, keyID, isMagic, notes
    }

    public init(from decoder: any Decoder, configuration: DungeonCodingContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decodeIfPresent(AnyRollable.self, forKey: .quantity) ?? 1
        value = try container.decodeIfPresent(Money.self, forKey: .value, configuration: configuration.currencies)
        keyID = try container.decodeIfPresent(String.self, forKey: .keyID)
        isMagic = try container.decodeIfPresent(Bool.self, forKey: .isMagic) ?? false
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    public func encode(to encoder: any Encoder, configuration: DungeonCodingContext) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        if quantity.constant != 1 {
            try container.encode(quantity, forKey: .quantity)
        }
        if let value {
            try container.encode(value, forKey: .value, configuration: configuration.currencies)
        }
        try container.encodeIfPresent(keyID, forKey: .keyID)
        if isMagic {
            try container.encode(isMagic, forKey: .isMagic)
        }
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

/// Coins and items found in a dungeon room.
///
/// `Treasure` represents the monetary and material rewards available in a room.
/// Coins are stored as a `MoneyRoll`, so amounts can be dice expressions ("d6 gp each")
/// as well as fixed quantities. Items are structured ``TreasureItem`` values, which may
/// themselves be keys.
///
/// ## JSON Example
/// ```json
/// { "coins": { "sp": "2d8", "gp": "d10", "cp": 175 }, "items": [ ... ], "notes": "Hides under the larger male's bed." }
/// ```
public struct Treasure: Equatable, Sendable {
    /// Coin amounts per denomination, as dice expressions.
    public var coins: MoneyRoll
    /// Named items found in this room.
    public var items: [TreasureItem]
    /// Optional DM notes about where or how the treasure is concealed.
    public var notes: String?

    public init(coins: MoneyRoll = MoneyRoll(), items: [TreasureItem] = [], notes: String? = nil) {
        self.coins = coins
        self.items = items
        self.notes = notes
    }

    /// True when there are no coins and no items.
    public var isEmpty: Bool {
        coins.isEmpty && items.isEmpty
    }

    /// The keyIDs of `items`, in order, without duplicates.
    public var keyIDs: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in items {
            if let keyID = item.keyID, seen.insert(keyID).inserted {
                result.append(keyID)
            }
        }
        return result
    }
}

extension Treasure: CodableWithConfiguration {
    public typealias DecodingConfiguration = DungeonCodingContext
    public typealias EncodingConfiguration = DungeonCodingContext

    private enum CodingKeys: String, CodingKey {
        case coins, items, notes
    }

    /// Decodes coins as a `MoneyRoll`; unknown currency symbols throw an error.
    public init(from decoder: any Decoder, configuration: DungeonCodingContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coins = try container.decodeIfPresent(MoneyRoll.self, forKey: .coins, configuration: configuration.currencies) ?? MoneyRoll()
        items = try container.decodeIfPresent([TreasureItem].self, forKey: .items, configuration: configuration) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    public func encode(to encoder: any Encoder, configuration: DungeonCodingContext) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !coins.isEmpty {
            try container.encode(coins, forKey: .coins, configuration: configuration.currencies)
        }
        if !items.isEmpty {
            try container.encode(items, forKey: .items, configuration: configuration)
        }
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}
