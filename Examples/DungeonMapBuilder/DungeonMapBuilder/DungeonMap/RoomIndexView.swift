//
//  RoomIndexView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 10/6/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// A sheet listing the current map's rooms grouped by section, in section order, with
/// unsectioned rooms first under the map's name.
///
/// Tapping a room dismisses this sheet and selects it, so its detail sheet opens. Section
/// editing (add, rename, delete, reorder) is revealed via the Edit button.
struct RoomIndexView: View {
    let viewModel: DungeonMapViewModel

    @Environment(DungeonStore.self) private var dungeonStore
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dismiss) private var dismiss

    @State private var isEditingSections = false
    @State private var isAddingSection = false
    @State private var newSectionName = ""
    @State private var renamingSection: DungeonSection?
    @State private var renamedSectionName = ""

    var body: some View {
        // Reading revision ensures the list re-renders after section/room mutations.
        let _ = viewModel.revision

        NavigationStack {
            Group {
                if let map = viewModel.currentMap {
                    roomList(for: map)
                } else {
                    ContentUnavailableView("No Map", systemImage: "map")
                }
            }
            .navigationTitle("Room Index")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditingSections ? "Done" : "Edit") {
                        withAnimation { isEditingSections.toggle() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Room list

    @ViewBuilder
    private func roomList(for map: DungeonMap) -> some View {
        List {
            if isEditingSections {
                sectionsEditingSection(for: map)
            }
            if !map.unsectionedRooms.isEmpty {
                Section(map.name) {
                    ForEach(map.unsectionedRooms) { room in
                        roomRow(room)
                    }
                }
            }
            ForEach(map.sections) { section in
                Section(section.name) {
                    ForEach(map.rooms(in: section)) { room in
                        roomRow(room)
                    }
                }
            }
        }
        .environment(\.editMode, .constant(isEditingSections ? .active : .inactive))
        .alert("Add Section", isPresented: $isAddingSection) {
            TextField("Section name", text: $newSectionName)
            Button("Add") {
                let trimmed = newSectionName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let section = DungeonSection(id: UUID().uuidString, name: trimmed)
                    dungeonStore.addSection(section, to: map, in: viewModel.dungeon, undoManager: undoManager)
                    viewModel.revision += 1
                }
                newSectionName = ""
            }
            Button("Cancel", role: .cancel) { newSectionName = "" }
        }
        .alert("Rename Section", isPresented: Binding(
            get: { renamingSection != nil },
            set: { if !$0 { renamingSection = nil } }
        )) {
            TextField("Section name", text: $renamedSectionName)
            Button("Save") {
                let trimmed = renamedSectionName.trimmingCharacters(in: .whitespaces)
                if let section = renamingSection, !trimmed.isEmpty {
                    dungeonStore.renameSection(section, name: trimmed, on: map, in: viewModel.dungeon, undoManager: undoManager)
                    viewModel.revision += 1
                }
                renamingSection = nil
            }
            Button("Cancel", role: .cancel) { renamingSection = nil }
        }
    }

    // MARK: - Section editing

    private func sectionsEditingSection(for map: DungeonMap) -> some View {
        Section("Sections") {
            ForEach(map.sections) { section in
                Button {
                    renamedSectionName = section.name
                    renamingSection = section
                } label: {
                    Text(section.name)
                }
                .foregroundStyle(.primary)
            }
            .onDelete { offsets in
                let sectionsToRemove = offsets.map { map.sections[$0] }
                for section in sectionsToRemove {
                    dungeonStore.removeSection(section, from: map, in: viewModel.dungeon, undoManager: undoManager)
                }
                viewModel.revision += 1
            }
            .onMove { source, destination in
                dungeonStore.moveSection(on: map, from: source, to: destination, in: viewModel.dungeon, undoManager: undoManager)
                viewModel.revision += 1
            }
            Button {
                isAddingSection = true
            } label: {
                Label("Add Section", systemImage: "plus")
            }
        }
    }

    // MARK: - Room rows

    private func roomRow(_ room: DungeonRoom) -> some View {
        Button {
            dismiss()
            viewModel.selectedElement = room
        } label: {
            HStack {
                if let key = room.keyNumber {
                    Text(key)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 28, alignment: .leading)
                }
                Text(room.name ?? "Room")
                Spacer()
            }
        }
        .foregroundStyle(.primary)
    }
}

#Preview {
    let dungeon = try! Dungeon(fileName: "Sample")
    let store = DungeonStore()
    let viewModel = DungeonMapViewModel(dungeon: dungeon, store: store)
    RoomIndexView(viewModel: viewModel)
        .environment(store)
}
