//
//  DoorEditView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 8/12/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

private extension DungeonDoor.Kind {
    var displayName: String {
        switch self {
        case .opening:      return "Opening"
        case .door:         return "Door"
        case .portcullis:   return "Portcullis"
        case .slidingDoor:  return "Sliding Door"
        case .ladder:       return "Ladder"
        case .trapDoor:     return "Trap Door"
        case .elevator:     return "Elevator"
        case .staircase:    return "Staircase"
        case .passage:      return "Passage"
        case .magicPortal:  return "Magic Portal"
        case .caveEntrance: return "Cave Entrance"
        }
    }
}

private extension DungeonDoor.Attribute {
    var displayName: String {
        switch self {
        case .isLocked:    return "Locked"
        case .hasTrap:     return "Has Trap"
        case .isSecret:    return "Secret"
        case .isOneWay:    return "One Way"
        case .isStuck:     return "Stuck"
        case .isBarred:    return "Barred"
        case .hasMagicSeal: return "Magic Seal"
        }
    }
}

/// Form for editing a door's kind and attributes.
struct DoorEditView: View {
    let door: DungeonDoor
    let dungeon: Dungeon
    let viewModel: DungeonMapViewModel

    @Environment(DungeonStore.self) private var store
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dismiss) private var dismiss

    @State private var kind: DungeonDoor.Kind
    @State private var attributes: Set<DungeonDoor.Attribute>
    @State private var keyID: String
    @State private var showDiscardAlert = false

    init(door: DungeonDoor, dungeon: Dungeon, viewModel: DungeonMapViewModel) {
        self.door = door
        self.dungeon = dungeon
        self.viewModel = viewModel
        _kind = State(initialValue: door.kind)
        _attributes = State(initialValue: door.attributes)
        _keyID = State(initialValue: door.keyID ?? "")
    }

    private var isDirty: Bool {
        kind != door.kind || attributes != door.attributes || keyID != (door.keyID ?? "")
    }

    /// Rooms on the current map that hold `keyID`, or `nil` when the field is empty.
    private var keyRooms: [DungeonRoom]? {
        guard !keyID.isEmpty, let currentMap = viewModel.currentMap else { return nil }
        let connectivity = DungeonConnectivity(map: currentMap)
        return connectivity.keyLocations()[keyID]
    }

    private func roomLabel(_ room: DungeonRoom) -> String {
        room.keyNumber ?? room.name ?? room.id
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Kind", selection: $kind) {
                        ForEach(DungeonDoor.Kind.allCases, id: \.self) { k in
                            Text(k.displayName).tag(k)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Attributes") {
                    ForEach(DungeonDoor.Attribute.allCases, id: \.self) { attribute in
                        Toggle(attribute.displayName, isOn: Binding(
                            get: { attributes.contains(attribute) },
                            set: { isOn in
                                if isOn { attributes.insert(attribute) }
                                else { attributes.remove(attribute) }
                            }
                        ))
                    }
                }

                Section("Key") {
                    TextField("Key ID", text: $keyID)
                    if let keyRooms {
                        if keyRooms.isEmpty {
                            Text("No room on this map holds this key")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else {
                            Text("Found in \(keyRooms.map(roomLabel).joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Door")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isDirty {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateDoorProperties(door, kind: kind, attributes: attributes, keyID: keyID.isEmpty ? nil : keyID, in: dungeon, undoManager: undoManager)
                        viewModel.revision += 1
                        dismiss()
                    }
                }
            }
            .alert("Discard Changes?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) { }
            }
        }
    }
}
