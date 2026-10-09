//
//  DungeonCodingContext.swift
//  DungeonCore
//
//  Created by Brian Arnold on 8/12/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import RolePlayingCore

/// Configuration threaded through the dungeon JSON coding chain.
///
/// Bundling all game-system registries into a single context type means the
/// `CodableWithConfiguration` signatures on `DungeonData`, `DungeonMapData`,
/// `RoomData`, and `RoomTreasure` remain stable as new registries are added —
/// only this struct gains a new property.
public struct DungeonCodingContext: Sendable {
    public var currencies: Currencies

    public init(currencies: Currencies = Currencies()) {
        self.currencies = currencies
    }
}
