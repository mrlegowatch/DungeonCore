//
//  MapNavigationBar.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/5/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// Navigation bar for paging through dungeon maps, with rename and add/remove map support.
struct MapNavigationBar: View {
    let viewModel: DungeonMapViewModel

    @Environment(\.undoManager) private var undoManager
    @State private var isRenamingMap = false
    @State private var newMapName = ""
    @State private var isPresentingRoomIndex = false

    var body: some View {
        // Reading revision ensures the bar re-renders after map renames and add/remove.
        let _ = viewModel.revision

        HStack {
            Button {
                isPresentingRoomIndex = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title2)
            }
            .sheet(isPresented: $isPresentingRoomIndex) {
                RoomIndexView(viewModel: viewModel)
            }

            Button {
                withAnimation { viewModel.previousMap() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            .disabled(viewModel.currentMapIndex == 0)

            Spacer()

            Button {
                newMapName = viewModel.currentMap?.name ?? ""
                isRenamingMap = true
            } label: {
                VStack(spacing: 2) {
                    Text(viewModel.currentMap?.name ?? "No Map")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("(\(viewModel.currentMapIndex + 1) of \(viewModel.dungeon.maps.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .alert("Rename Map", isPresented: $isRenamingMap) {
                TextField("Map name", text: $newMapName)
                Button("Save") {
                    let trimmed = newMapName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        viewModel.renameCurrentMap(to: trimmed, undoManager: undoManager)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }

            Spacer()

            Button {
                withAnimation { viewModel.nextMap() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .disabled(viewModel.currentMapIndex >= viewModel.dungeon.maps.count - 1)

            if FeatureFlags.isMapEditingEnabled {
                Button {
                    viewModel.addMap(undoManager: undoManager)
                } label: {
                    Image(systemName: "plus")
                }

                if viewModel.dungeon.maps.count > 1 {
                    Button(role: .destructive) {
                        viewModel.removeCurrentMap(undoManager: undoManager)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}
