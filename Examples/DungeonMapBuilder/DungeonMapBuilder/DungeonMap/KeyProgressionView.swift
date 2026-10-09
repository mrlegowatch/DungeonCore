//
//  KeyProgressionView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 10/5/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// A read-only sheet showing the step-by-step key unlocking order from the current flow start room.
struct KeyProgressionView: View {
    let viewModel: DungeonMapViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Party finds secret doors", isOn: Binding(
                        get: { viewModel.findsSecrets },
                        set: { viewModel.findsSecrets = $0 }
                    ))
                }
                if let progression = viewModel.keyProgression {
                    let roomsByKey = keyRoomMap(progression)
                    ForEach(Array(progression.steps.enumerated()), id: \.offset) { index, step in
                        Section(index == 0 ? "Start" : "Then") {
                            ForEach(step.doorsOpened, id: \.id) { door in
                                Text("Opens \(doorLabel(door)) with \(keyLabel(door.keyID, roomsByKey: roomsByKey))")
                            }
                            ForEach(step.roomsReached, id: \.id) { room in
                                Button {
                                    dismiss()
                                } label: {
                                    Text(roomLabel(room))
                                }
                            }
                            ForEach(step.keysFound, id: \.keyID) { pickup in
                                Text("\(keyName(pickup.keyID, in: pickup.room)) in \(roomLabel(pickup.room))")
                            }
                        }
                    }
                    if !progression.unopenedDoors.isEmpty {
                        Section("Never opens") {
                            ForEach(progression.unopenedDoors, id: \.id) { door in
                                Text("\(doorLabel(door)) (\(door.keyID == nil ? "no key exists" : "key not found"))")
                            }
                        }
                    }
                    if !progression.lockedOut.isEmpty {
                        Section("Out of reach") {
                            ForEach(progression.lockedOut, id: \.id) { room in
                                Text(roomLabel(room))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Key Progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers

    private func roomLabel(_ room: DungeonRoom) -> String {
        if let key = room.keyNumber {
            if let name = room.name { return "\(key): \(name)" }
            return key
        }
        return room.name ?? room.id
    }

    private func doorLabel(_ door: DungeonDoor) -> String {
        door.name ?? "door"
    }

    /// Maps each found keyID to the room it was found in, across every step.
    private func keyRoomMap(_ progression: KeyProgression) -> [String: DungeonRoom] {
        var result: [String: DungeonRoom] = [:]
        for step in progression.steps {
            for pickup in step.keysFound {
                result[pickup.keyID] = pickup.room
            }
        }
        return result
    }

    private func keyLabel(_ keyID: String?, roomsByKey: [String: DungeonRoom]) -> String {
        guard let keyID else { return "key" }
        guard let room = roomsByKey[keyID] else { return keyID }
        return keyName(keyID, in: room)
    }

    /// Looks up `keyID`'s item name in `room`'s treasure, then its encounters' carried treasure.
    private func keyName(_ keyID: String, in room: DungeonRoom) -> String {
        if let item = room.treasure?.items.first(where: { $0.keyID == keyID }) {
            return item.name
        }
        for encounter in room.encounters {
            for treasure in [encounter.carriedEach, encounter.carried].compactMap({ $0 }) {
                if let item = treasure.items.first(where: { $0.keyID == keyID }) {
                    return item.name
                }
            }
        }
        return keyID
    }
}
