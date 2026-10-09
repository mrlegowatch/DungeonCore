//
//  DungeonMapBuilderApp.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/2/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore
import RolePlayingCore

@main
struct DungeonMapBuilderApp: App {
    @State private var dungeonStore: DungeonStore

    init() {
        _dungeonStore = State(wrappedValue: DungeonStore(context: Self.loadContext()))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dungeonStore)
        }
    }

    private static func loadContext() -> DungeonCodingContext {
        guard let url = Bundle.main.url(forResource: "Currencies", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let currencies = try? JSONDecoder().decode(Currencies.self, from: data) else {
            return DungeonCodingContext()
        }
        return DungeonCodingContext(currencies: currencies)
    }
}
