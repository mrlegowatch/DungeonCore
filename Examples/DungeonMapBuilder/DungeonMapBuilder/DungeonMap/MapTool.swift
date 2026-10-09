//
//  MapTool.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 8/12/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import Foundation

/// The active drawing/editing tool in map edit mode.
enum MapTool: CaseIterable {
    case select
    case room
    case hallway
    case door

    var systemImage: String {
        switch self {
        case .select:  return "cursorarrow"
        case .room:    return "rectangle"
        case .hallway: return "line.diagonal"
        case .door:    return "door.left.hand.closed"
        }
    }

    var label: String {
        switch self {
        case .select:  return "Select"
        case .room:    return "Room"
        case .hallway: return "Hallway"
        case .door:    return "Door"
        }
    }
}
