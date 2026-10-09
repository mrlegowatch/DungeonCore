//
//  Occupancy.swift
//  DungeonCore
//
//  Created by Brian Arnold on 10/6/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import Foundation
import SwiftDice

/// A chance that something is true or present, checked by rolling a die against a threshold.
///
/// "1-3 on d10 per turn" succeeds when `die` rolls `atMost` or lower.
///
/// ## JSON Example
/// ```json
/// { "die": "d10", "atMost": 2 }
/// ```
public struct Chance: Codable, Equatable, Sendable {
    public var die: AnyRollable
    public var atMost: Int
    /// How often this is checked, e.g. "turn", "four hours". `nil` for a single check on arrival.
    public var per: String?

    public init(die: AnyRollable, atMost: Int, per: String? = nil) {
        self.die = die
        self.atMost = atMost
        self.per = per
    }

    /// Rolls `die` once, returning whether it succeeded (`result <= atMost`) along with
    /// the rolled value. Use this instead of `check()` when the rolled number must also
    /// be shown, so the die is only rolled once.
    public func checkRoll() -> (succeeded: Bool, rolled: Int) {
        let rolled = die.roll().result
        return (rolled <= atMost, rolled)
    }

    /// Rolls `die` and returns whether the result is `atMost` or lower.
    public func check() -> Bool {
        checkRoll().succeeded
    }

    /// "1-3" or "1": the range of rolls that succeed.
    public var neededRange: String {
        atMost <= 1 ? "\(atMost)" : "1-\(atMost)"
    }

    /// The die as a single plain die: one `Dice`, times 1, not exploding, no reroll.
    private var plainDie: Dice? {
        guard let dice = die.rollable as? Dice,
              dice.times == 1, !dice.isExploding, dice.rerollThreshold == nil else { return nil }
        return dice
    }

    /// Exact probability when `die` is a single plain die; otherwise `nil`.
    public var probability: Double? {
        guard let dice = plainDie else { return nil }
        let successes = Swift.min(Swift.max(atMost, 0), dice.sides)
        return Double(successes) / Double(dice.sides)
    }

    /// "1-3 on d10 per turn", "1 on d20".
    public var description: String {
        let base = "\(neededRange) on \(die.description)"
        guard let per else { return base }
        return "\(base) per \(per)"
    }
}

/// A table of possible encounters, chosen by rolling `die` and looking up the matching row.
///
/// ## JSON Example
/// ```json
/// {
///     "die": "d4",
///     "rows": [
///         { "from": 1, "to": 2, "encounter": { "name": "Bracken-folk", "count": 8 } },
///         { "from": 3, "to": 4, "encounter": { "name": "Glubbin", "count": 8 } }
///     ]
/// }
/// ```
public struct EncounterTable: Equatable, Sendable {
    /// A single row of an `EncounterTable`, covering die results `from` through `to`.
    public struct Row: Equatable, Sendable {
        public var from: Int
        public var to: Int
        public var encounter: RoomEncounter

        public init(from: Int, to: Int, encounter: RoomEncounter) {
            self.from = from
            self.to = to
            self.encounter = encounter
        }
    }

    public var die: AnyRollable
    public var rows: [Row]

    public init(die: AnyRollable, rows: [Row]) {
        self.die = die
        self.rows = rows
    }

    /// The row whose `from`...`to` range contains `roll`, if any.
    public func row(for roll: Int) -> Row? {
        rows.first { roll >= $0.from && roll <= $0.to }
    }

    /// Rolls `die` once, returning the matching row (if any) along with the rolled value.
    /// Use this instead of `roll()` when the rolled number must also be shown, so the
    /// die is only rolled once.
    public func rollRow() -> (row: Row?, rolled: Int) {
        let rolled = die.roll().result
        return (row(for: rolled), rolled)
    }

    /// Rolls `die` and returns the matching row's encounter, if any.
    public func roll() -> RoomEncounter? {
        rollRow().row?.encounter
    }

    /// The die as a single plain die: one `Dice`, times 1, not exploding, no reroll.
    private var plainDie: Dice? {
        guard let dice = die.rollable as? Dice,
              dice.times == 1, !dice.isExploding, dice.rerollThreshold == nil else { return nil }
        return dice
    }

    /// Die results from 1 through the die's maximum that no row covers. Empty when `die` is not a single plain die.
    public var uncoveredResults: [Int] {
        guard let dice = plainDie else { return [] }
        return (1...dice.sides).filter { row(for: $0) == nil }
    }
}

extension EncounterTable.Row: CodableWithConfiguration {
    public typealias DecodingConfiguration = DungeonCodingContext
    public typealias EncodingConfiguration = DungeonCodingContext

    private enum CodingKeys: String, CodingKey {
        case from, to, encounter
    }

    public init(from decoder: any Decoder, configuration: DungeonCodingContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        from = try container.decode(Int.self, forKey: .from)
        to = try container.decode(Int.self, forKey: .to)
        encounter = try container.decode(RoomEncounter.self, forKey: .encounter, configuration: configuration)
    }

    public func encode(to encoder: any Encoder, configuration: DungeonCodingContext) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encode(encounter, forKey: .encounter, configuration: configuration)
    }
}

extension EncounterTable: CodableWithConfiguration {
    public typealias DecodingConfiguration = DungeonCodingContext
    public typealias EncodingConfiguration = DungeonCodingContext

    private enum CodingKeys: String, CodingKey {
        case die, rows
    }

    public init(from decoder: any Decoder, configuration: DungeonCodingContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        die = try container.decode(AnyRollable.self, forKey: .die)
        rows = try container.decode([Row].self, forKey: .rows, configuration: configuration)
    }

    public func encode(to encoder: any Encoder, configuration: DungeonCodingContext) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(die, forKey: .die)
        try container.encode(rows, forKey: .rows, configuration: configuration)
    }
}

/// A chance that a wandering group occupies a room, with an optional table of who shows up.
///
/// `Occupancy` is separate from a room's ``DungeonRoom/encounters``: encounters are always
/// present, occupancy is rolled.
///
/// ## JSON Example
/// ```json
/// {
///     "chance": { "die": "d10", "atMost": 2 },
///     "table": {
///         "die": "d4",
///         "rows": [
///             { "from": 1, "to": 2, "encounter": { "name": "Bracken-folk", "count": 8 } },
///             { "from": 3, "to": 4, "encounter": { "name": "Glubbin", "count": 8 } }
///         ]
///     },
///     "notes": "Optional."
/// }
/// ```
public struct Occupancy: Equatable, Sendable {
    public var chance: Chance
    public var table: EncounterTable?
    /// Names a room on the same map whose encounter table this room uses, when this room
    /// has no table of its own. Resolved by ``DungeonMap/encounterTable(for:)``, which
    /// follows one hop only. A room's own `table`, when present, wins.
    public var tableRoomID: String?
    public var notes: String?

    /// The result of rolling an `Occupancy`.
    public enum Outcome: Equatable, Sendable {
        case empty
        /// Occupied; `nil` when there is no table and the GM chooses who is here.
        case occupied(RoomEncounter?)
    }

    public init(chance: Chance, table: EncounterTable? = nil, tableRoomID: String? = nil, notes: String? = nil) {
        self.chance = chance
        self.table = table
        self.tableRoomID = tableRoomID
        self.notes = notes
    }

    /// Checks `chance`, then rolls `table` if present.
    public func roll() -> Outcome {
        guard chance.check() else { return .empty }
        guard let table else { return .occupied(nil) }
        return .occupied(table.roll())
    }
}

extension Occupancy: CodableWithConfiguration {
    public typealias DecodingConfiguration = DungeonCodingContext
    public typealias EncodingConfiguration = DungeonCodingContext

    private enum CodingKeys: String, CodingKey {
        case chance, table, tableRoomID, notes
    }

    public init(from decoder: any Decoder, configuration: DungeonCodingContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chance = try container.decode(Chance.self, forKey: .chance)
        table = try container.decodeIfPresent(EncounterTable.self, forKey: .table, configuration: configuration)
        tableRoomID = try container.decodeIfPresent(String.self, forKey: .tableRoomID)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    public func encode(to encoder: any Encoder, configuration: DungeonCodingContext) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(chance, forKey: .chance)
        if let table {
            try container.encode(table, forKey: .table, configuration: configuration)
        }
        try container.encodeIfPresent(tableRoomID, forKey: .tableRoomID)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}
