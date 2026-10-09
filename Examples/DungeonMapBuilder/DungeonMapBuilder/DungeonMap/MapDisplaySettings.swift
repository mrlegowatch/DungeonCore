//
//  MapDisplaySettings.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 8/3/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import Foundation

/// Which map overlays are visible — persisted as a single @AppStorage value in
/// DungeonMapView, passed as a value to child views that only need to read it.
struct MapDisplaySettings: Codable {
    var showRuler: Bool = false
    var showRoomLabels: Bool = true
    var showHallwayLabels: Bool = false
    var showDoorLabels: Bool = false
    /// Whether to tint each door's `fromArea`/`toArea` green/red, for debugging. Default off.
    var showDoorSides: Bool = false
    var showFeatures: Bool = true

    init() {}

    // Explicit Codable conformance. Without it, RawRepresentable's default
    // encode(to:) and init(from:) take over and go through `rawValue`, which
    // itself uses JSONEncoder/JSONDecoder: infinite recursion.
    private enum CodingKeys: String, CodingKey {
        case showRuler, showRoomLabels, showHallwayLabels, showDoorLabels, showDoorSides, showFeatures
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = MapDisplaySettings()
        // Missing keys fall back to defaults, so adding a setting later doesn't reset the others.
        showRuler = try container.decodeIfPresent(Bool.self, forKey: .showRuler) ?? defaults.showRuler
        showRoomLabels = try container.decodeIfPresent(Bool.self, forKey: .showRoomLabels) ?? defaults.showRoomLabels
        showHallwayLabels = try container.decodeIfPresent(Bool.self, forKey: .showHallwayLabels) ?? defaults.showHallwayLabels
        showDoorLabels = try container.decodeIfPresent(Bool.self, forKey: .showDoorLabels) ?? defaults.showDoorLabels
        showDoorSides = try container.decodeIfPresent(Bool.self, forKey: .showDoorSides) ?? defaults.showDoorSides
        showFeatures = try container.decodeIfPresent(Bool.self, forKey: .showFeatures) ?? defaults.showFeatures
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showRuler, forKey: .showRuler)
        try container.encode(showRoomLabels, forKey: .showRoomLabels)
        try container.encode(showHallwayLabels, forKey: .showHallwayLabels)
        try container.encode(showDoorLabels, forKey: .showDoorLabels)
        try container.encode(showDoorSides, forKey: .showDoorSides)
        try container.encode(showFeatures, forKey: .showFeatures)
    }
}

/// Stores `MapDisplaySettings` as a JSON string under a single @AppStorage key.
extension MapDisplaySettings: RawRepresentable {
    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        self = decoded
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}
