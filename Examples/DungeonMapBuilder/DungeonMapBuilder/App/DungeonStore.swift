//
//  DungeonStore.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/2/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore
import RolePlayingCore

struct DefaultMapsData: Codable {
    var dungeons: [String]
}

@MainActor
@Observable
final class DungeonStore {
    var dungeons: [Dungeon] = []
    private(set) var context: DungeonCodingContext

    init(context: DungeonCodingContext = DungeonCodingContext()) {
        self.context = context
        do {
            try loadDefaultMaps()
        } catch {
            print("Error loading default maps: \(error)")
        }
        loadDocuments()
        // When a bundle map has been saved to documents, drop the bundle copy.
        let documentIDs = Set(dungeons.compactMap { $0.url != nil ? $0.id : nil })
        dungeons.removeAll { $0.url == nil && documentIDs.contains($0.id) }
    }

    // MARK: - Loading

    func loadDefaultMaps() throws {
        guard let url = Bundle.main.url(forResource: "DefaultMaps", withExtension: "json") else {
            fatalError("DefaultMaps.json is missing")
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let mapData = try decoder.decode(DefaultMapsData.self, from: data)
        for name in mapData.dungeons {
            do {
                let dungeon = try Dungeon(fileName: name, context: context)
                dungeons.append(dungeon)
            } catch {
                print("Error loading map \"\(name)\": \(error)")
            }
        }
    }

    // MARK: - Documents persistence

    private var dungeonDocumentsURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Dungeons")
    }

    private func documentURL(for dungeon: Dungeon) -> URL {
        dungeonDocumentsURL.appendingPathComponent("\(dungeon.id).json")
    }

    func loadDocuments() {
        let fm = FileManager.default
        try? fm.createDirectory(at: dungeonDocumentsURL, withIntermediateDirectories: true)
        guard let urls = try? fm.contentsOfDirectory(at: dungeonDocumentsURL,
                                                      includingPropertiesForKeys: nil) else { return }
        for url in urls where url.pathExtension == "json" {
            if let dungeon = try? Dungeon(contentsOf: url, context: context) {
                dungeons.append(dungeon)
            }
        }
    }

    func save(_ dungeon: Dungeon) {
        if dungeon.url == nil {
            dungeon.url = documentURL(for: dungeon)
        }
        do {
            try dungeon.save(context: context)
        } catch {
            print("Error saving dungeon \(dungeon.name): \(error)")
        }
    }

    // MARK: - Dungeon list mutations

    func addNewDungeon() {
        let dungeon = Dungeon()
        dungeons.insert(dungeon, at: 0)
        save(dungeon)
    }

    func deleteDungeon(at offsets: IndexSet) {
        for index in offsets {
            let dungeon = dungeons[index]
            if let url = dungeon.url {
                try? FileManager.default.removeItem(at: url)
            }
        }
        dungeons.remove(atOffsets: offsets)
    }

    func moveDungeon(from source: IndexSet, to destination: Int) {
        dungeons.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Room mutations (undo-aware)

    func addRoom(_ room: DungeonRoom, to map: DungeonMap, in dungeon: Dungeon, undoManager: UndoManager?) {
        map.addRoom(room)
        undoManager?.registerUndo(withTarget: map) { [weak self, weak dungeon] m in
            m.removeRoom(room)
            if let d = dungeon { self?.save(d) }
        }
        undoManager?.setActionName("Add Room")
        save(dungeon)
    }

    func removeRoom(_ room: DungeonRoom, from map: DungeonMap, in dungeon: Dungeon, undoManager: UndoManager?) {
        guard let index = map.indexOfRoom(room) else { return }
        map.removeRoom(room)
        undoManager?.registerUndo(withTarget: map) { [weak self, weak dungeon] m in
            m.insertRoom(room, at: index)
            if let d = dungeon { self?.save(d) }
        }
        undoManager?.setActionName("Delete Room")
        save(dungeon)
    }

    /// Registers an undo operation for a room resize that has already been applied visually.
    func registerResizeUndo(room: DungeonRoom, originalEdges: [MapPoint], originalLocation: MapPoint, originalSize: MapSize, in dungeon: Dungeon, undoManager: UndoManager?) {
        let newEdges = room.edges
        let newLocation = room.location
        let newSize = room.size
        undoManager?.registerUndo(withTarget: room) { [weak self, weak dungeon] r in
            r.edges = originalEdges
            r.location = originalLocation
            r.size = originalSize
            if let d = dungeon {
                self?.save(d)
                self?.registerResizeUndo(room: r, originalEdges: newEdges, originalLocation: newLocation, originalSize: newSize, in: d, undoManager: undoManager)
            }
        }
        undoManager?.setActionName("Resize Room")
        save(dungeon)
    }

    /// Registers an undo operation for a room move that has already been applied visually.
    ///
    /// Call this after completing a drag gesture to make the move undoable. The room
    /// is already at its new position; this method records the original location so
    /// that undo can return it there.
    func registerMoveUndo(room: DungeonRoom, originalLocation: MapPoint, in dungeon: Dungeon, undoManager: UndoManager?) {
        let movedTo = room.location
        undoManager?.registerUndo(withTarget: room) { [weak self, weak dungeon] r in
            let delta = MapPoint(x: originalLocation.x - movedTo.x, y: originalLocation.y - movedTo.y)
            r.translate(by: delta)
            if let d = dungeon {
                self?.save(d)
                self?.registerMoveUndo(room: r, originalLocation: movedTo, in: d, undoManager: undoManager)
            }
        }
        undoManager?.setActionName("Move Room")
        save(dungeon)
    }

    // MARK: - Room content mutations (undo-aware)

    func updateRoomContent(_ room: DungeonRoom,
                           keyNumber: String?,
                           name: String?,
                           readAloud: String?,
                           gmNotes: String?,
                           contentTags: Set<DungeonRoom.ContentTag>,
                           encounters: [RoomEncounter],
                           treasure: Treasure?,
                           sectionID: String?,
                           features: [RoomFeature],
                           occupancy: Occupancy?,
                           labelLocation: MapPoint?,
                           in dungeon: Dungeon,
                           undoManager: UndoManager?) {
        let oldKeyNumber = room.keyNumber
        let oldName = room.name
        let oldReadAloud = room.readAloud
        let oldGMNotes = room.gmNotes
        let oldContentTags = room.contentTags
        let oldEncounters = room.encounters
        let oldTreasure = room.treasure
        let oldSectionID = room.sectionID
        let oldFeatures = room.features
        let oldOccupancy = room.occupancy
        let oldLabelLocation = room.labelLocation

        room.keyNumber = keyNumber
        room.name = name
        room.readAloud = readAloud
        room.gmNotes = gmNotes
        room.contentTags = contentTags
        room.encounters = encounters
        room.treasure = treasure
        room.sectionID = sectionID
        room.features = features
        room.occupancy = occupancy
        room.labelLocation = labelLocation

        undoManager?.registerUndo(withTarget: room) { [weak self, weak dungeon] r in
            if let d = dungeon {
                self?.updateRoomContent(
                    r,
                    keyNumber: oldKeyNumber,
                    name: oldName,
                    readAloud: oldReadAloud,
                    gmNotes: oldGMNotes,
                    contentTags: oldContentTags,
                    encounters: oldEncounters,
                    treasure: oldTreasure,
                    sectionID: oldSectionID,
                    features: oldFeatures,
                    occupancy: oldOccupancy,
                    labelLocation: oldLabelLocation,
                    in: d,
                    undoManager: undoManager
                )
            }
        }
        undoManager?.setActionName("Edit Room")
        save(dungeon)
    }

    // MARK: - Door mutations (undo-aware)

    func addDoor(_ door: DungeonDoor, to map: DungeonMap, in dungeon: Dungeon, undoManager: UndoManager?) {
        map.addDoor(door)
        undoManager?.registerUndo(withTarget: map) { [weak self, weak dungeon] m in
            m.removeDoor(door)
            if let d = dungeon { self?.save(d) }
        }
        undoManager?.setActionName("Add Door")
        save(dungeon)
    }

    func removeDoor(_ door: DungeonDoor, from map: DungeonMap, in dungeon: Dungeon, undoManager: UndoManager?) {
        guard let index = map.indexOfDoor(door) else { return }
        map.removeDoor(door)
        undoManager?.registerUndo(withTarget: map) { [weak self, weak dungeon] m in
            m.insertDoor(door, at: index)
            if let d = dungeon { self?.save(d) }
        }
        undoManager?.setActionName("Delete Door")
        save(dungeon)
    }

    func updateDoorProperties(_ door: DungeonDoor,
                              kind: DungeonDoor.Kind,
                              attributes: Set<DungeonDoor.Attribute>,
                              keyID: String?,
                              in dungeon: Dungeon,
                              undoManager: UndoManager?) {
        let oldKind = door.kind
        let oldAttributes = door.attributes
        let oldKeyID = door.keyID

        door.kind = kind
        door.attributes = attributes
        door.keyID = keyID

        undoManager?.registerUndo(withTarget: door) { [weak self, weak dungeon] d in
            if let dungeon {
                self?.updateDoorProperties(d, kind: oldKind, attributes: oldAttributes, keyID: oldKeyID, in: dungeon, undoManager: undoManager)
            }
        }
        undoManager?.setActionName("Edit Door")
        save(dungeon)
    }

    // MARK: - Hallway mutations (undo-aware)

    func addHallway(_ hallway: DungeonHallway, to map: DungeonMap, in dungeon: Dungeon, undoManager: UndoManager?) {
        map.addHallway(hallway)
        undoManager?.registerUndo(withTarget: map) { [weak self, weak dungeon] m in
            m.removeHallway(hallway)
            if let d = dungeon { self?.save(d) }
        }
        undoManager?.setActionName("Add Hallway")
        save(dungeon)
    }

    func removeHallway(_ hallway: DungeonHallway, from map: DungeonMap, in dungeon: Dungeon, undoManager: UndoManager?) {
        guard let index = map.indexOfHallway(hallway) else { return }
        map.removeHallway(hallway)
        undoManager?.registerUndo(withTarget: map) { [weak self, weak dungeon] m in
            m.insertHallway(hallway, at: index)
            if let d = dungeon { self?.save(d) }
        }
        undoManager?.setActionName("Delete Hallway")
        save(dungeon)
    }

    // MARK: - Section mutations (undo-aware)

    func addSection(_ section: DungeonSection, to map: DungeonMap, in dungeon: Dungeon, undoManager: UndoManager?) {
        map.addSection(section)
        undoManager?.registerUndo(withTarget: map) { [weak self, weak dungeon] m in
            m.removeSection(section)
            if let d = dungeon { self?.save(d) }
        }
        undoManager?.setActionName("Add Section")
        save(dungeon)
    }

    func removeSection(_ section: DungeonSection, from map: DungeonMap, in dungeon: Dungeon, undoManager: UndoManager?) {
        guard let index = map.sections.firstIndex(where: { $0.id == section.id }) else { return }
        let affectedRoomIDs = map.rooms.filter { $0.sectionID == section.id }.map(\.id)
        map.removeSection(section)
        undoManager?.registerUndo(withTarget: map) { [weak self, weak dungeon] m in
            m.sections.insert(section, at: min(index, m.sections.count))
            for room in m.rooms where affectedRoomIDs.contains(room.id) {
                room.sectionID = section.id
            }
            if let d = dungeon { self?.save(d) }
        }
        undoManager?.setActionName("Delete Section")
        save(dungeon)
    }

    func renameSection(_ section: DungeonSection, name: String, on map: DungeonMap, in dungeon: Dungeon, undoManager: UndoManager?) {
        guard let index = map.sections.firstIndex(where: { $0.id == section.id }) else { return }
        let old = map.sections[index]
        var updated = old
        updated.name = name
        map.sections[index] = updated

        undoManager?.registerUndo(withTarget: map) { [weak self, weak dungeon] m in
            if let d = dungeon {
                self?.renameSection(updated, name: old.name, on: m, in: d, undoManager: undoManager)
            }
        }
        undoManager?.setActionName("Rename Section")
        save(dungeon)
    }

    func moveSection(on map: DungeonMap, from source: IndexSet, to destination: Int, in dungeon: Dungeon, undoManager: UndoManager?) {
        let before = map.sections
        map.moveSection(fromOffsets: source, toOffset: destination)
        registerSectionOrderUndo(before: before, on: map, in: dungeon, undoManager: undoManager)
        undoManager?.setActionName("Reorder Sections")
        save(dungeon)
    }

    /// Registers an undo that restores `before`'s section order, re-registering itself
    /// with the current (post-move) order so redo also works.
    private func registerSectionOrderUndo(before: [DungeonSection], on map: DungeonMap, in dungeon: Dungeon, undoManager: UndoManager?) {
        let after = map.sections
        undoManager?.registerUndo(withTarget: map) { [weak self, weak dungeon] m in
            m.sections = before
            if let d = dungeon {
                self?.save(d)
                self?.registerSectionOrderUndo(before: after, on: m, in: d, undoManager: undoManager)
            }
        }
    }

    // MARK: - Naming mutations (undo-aware)

    func renameDungeon(_ dungeon: Dungeon, to name: String, undoManager: UndoManager?) {
        let oldName = dungeon.name
        dungeon.name = name
        dungeons = dungeons  // Dungeon is not @Observable; reassigning the array fires SwiftUI observation
        undoManager?.registerUndo(withTarget: dungeon) { [weak self] d in
            d.name = oldName
            self?.dungeons = self?.dungeons ?? []
            self?.save(d)
        }
        undoManager?.setActionName("Rename Dungeon")
        save(dungeon)
    }

    func renameMap(_ map: DungeonMap, to name: String, in dungeon: Dungeon, undoManager: UndoManager?) {
        let oldName = map.name
        map.name = name
        undoManager?.registerUndo(withTarget: map) { [weak self, weak dungeon] m in
            m.name = oldName
            if let d = dungeon { self?.save(d) }
        }
        undoManager?.setActionName("Rename Map")
        save(dungeon)
    }

    // MARK: - Map mutations (undo-aware)

    func addMap(to dungeon: Dungeon, undoManager: UndoManager?) {
        let map = DungeonMap(index: dungeon.maps.count + 1)
        dungeon.maps.append(map)
        undoManager?.registerUndo(withTarget: dungeon) { [weak self] d in
            d.maps.removeLast()
            self?.save(d)
        }
        undoManager?.setActionName("Add Map")
        save(dungeon)
    }

    func removeMap(_ map: DungeonMap, from dungeon: Dungeon, undoManager: UndoManager?) {
        guard dungeon.maps.count > 1,
              let index = dungeon.maps.firstIndex(where: { $0 === map }) else { return }
        dungeon.maps.remove(at: index)
        undoManager?.registerUndo(withTarget: dungeon) { [weak self] d in
            d.maps.insert(map, at: min(index, d.maps.count))
            self?.save(d)
        }
        undoManager?.setActionName("Remove Map")
        save(dungeon)
    }
}
