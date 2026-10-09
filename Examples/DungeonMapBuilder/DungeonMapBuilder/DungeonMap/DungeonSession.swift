//
//  DungeonSession.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 8/3/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import Foundation

/// Per-dungeon UI state that survives navigation but is not part of the dungeon document.
struct DungeonSession: Codable {
    var currentMapIndex: Int = 0
    var scale: CGFloat = MapViewConfiguration.defaultScale
}

extension UserDefaults {
    private static let sessionKeyPrefix = "dungeonSession."

    func dungeonSession(forID id: String) -> DungeonSession {
        guard let data = data(forKey: Self.sessionKeyPrefix + id),
              let session = try? JSONDecoder().decode(DungeonSession.self, from: data)
        else { return DungeonSession() }
        return session
    }

    func save(_ session: DungeonSession, forID id: String) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        set(data, forKey: Self.sessionKeyPrefix + id)
    }
}
