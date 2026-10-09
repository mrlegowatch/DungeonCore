//
//  DungeonListView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/2/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

struct DungeonListView: View {
    @Environment(DungeonStore.self) private var dungeonStore
    @Environment(\.undoManager) private var undoManager
    @Binding var selectedDungeon: Dungeon?
    @State private var renamingDungeon: Dungeon? = nil
    @State private var newName = ""

    var body: some View {
        List(selection: $selectedDungeon) {
            ForEach(dungeonStore.dungeons) { dungeon in
                NavigationLink(value: dungeon) {
                    Text(dungeon.name)
                }
                .swipeActions(edge: .leading) {
                    Button("Rename") {
                        newName = dungeon.name
                        renamingDungeon = dungeon
                    }
                    .tint(.blue)
                }
            }
            .onDelete { offsets in
                dungeonStore.deleteDungeon(at: offsets)
            }
            .onMove { source, destination in
                dungeonStore.moveDungeon(from: source, to: destination)
            }
        }
        .navigationTitle("Dungeons")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            if FeatureFlags.isMapEditingEnabled {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dungeonStore.addNewDungeon()
                    } label: {
                        Label("Add Dungeon", systemImage: "plus")
                    }
                }
            }
        }
        .alert("Rename Dungeon", isPresented: Binding(
            get: { renamingDungeon != nil },
            set: { if !$0 { renamingDungeon = nil } }
        )) {
            TextField("Dungeon name", text: $newName)
            Button("Save") {
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                if let dungeon = renamingDungeon, !trimmed.isEmpty {
                    dungeonStore.renameDungeon(dungeon, to: trimmed, undoManager: undoManager)
                }
                renamingDungeon = nil
            }
            Button("Cancel", role: .cancel) { renamingDungeon = nil }
        }
    }
}

#Preview {
    NavigationStack {
        DungeonListView(selectedDungeon: .constant(nil))
            .environment(DungeonStore())
    }
}
