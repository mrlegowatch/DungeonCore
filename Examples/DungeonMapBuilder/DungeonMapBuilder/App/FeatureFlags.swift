//
//  FeatureFlags.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 10/7/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import Foundation

/// Flags controlled by launch arguments, read once at process start.
enum FeatureFlags {
    /// Enables map geometry editing (rooms, hallways, doors). Unfinished for public release,
    /// so it stays off unless the app is launched with `-enableMapEditing`.
    static let isMapEditingEnabled = ProcessInfo.processInfo.arguments.contains("-enableMapEditing")
}
