//
//  ContentView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/2/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

struct ContentView: View {
    @Environment(DungeonStore.self) private var dungeonStore
    @State private var selectedDungeon: Dungeon?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            DungeonListView(selectedDungeon: $selectedDungeon)
        } detail: {
            if let dungeon = selectedDungeon {
                DungeonMapView(dungeon: dungeon, store: dungeonStore)
                    .navigationTitle(dungeon.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .id(dungeon.id) // Reset view state when dungeon changes
            } else {
                VStack {
                    Image(systemName: "map")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("Select a dungeon to view its map")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Dungeon Map")
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(DungeonStore())
}
