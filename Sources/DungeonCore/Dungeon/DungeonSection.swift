//
//  DungeonSection.swift
//  DungeonCore
//
//  Created by Brian Arnold on 10/6/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import Foundation

/// A named grouping of rooms under a module heading, such as "Lair of the Bracken-folk".
///
/// A section is declared once on a ``DungeonMap`` (``DungeonMap/sections``) and referenced
/// by each ``DungeonRoom`` via its ``DungeonRoom/sectionID``.
public struct DungeonSection: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var gmNotes: String?

    public init(id: String, name: String, gmNotes: String? = nil) {
        self.id = id
        self.name = name
        self.gmNotes = gmNotes
    }
}
