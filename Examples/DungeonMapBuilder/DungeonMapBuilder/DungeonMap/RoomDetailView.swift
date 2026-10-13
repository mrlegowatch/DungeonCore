//
//  RoomDetailView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 8/1/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore
import RolePlayingCore
import SwiftDice

/// A read-only inspector sheet showing a room's key number, description, encounters, treasure, and content tags.
///
/// Pass an `onDelete` closure to enable the destructive Delete Room button. If `nil`, the button is hidden.
/// Pass `viewModel` to enable the Edit button; the dungeon is accessed via `viewModel.dungeon`.
struct RoomDetailView: View {
    let room: DungeonRoom
    let roomIndex: Int
    var viewModel: DungeonMapViewModel? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var isEditingRoom = false
    @State private var isGMNotesExpanded: Bool
    @State private var occupancyOutcome: Occupancy.Outcome?
    @State private var occupancyRollDescription: String?

    init(room: DungeonRoom, roomIndex: Int, viewModel: DungeonMapViewModel? = nil, onDelete: (() -> Void)? = nil) {
        self.room = room
        self.roomIndex = roomIndex
        self.viewModel = viewModel
        self.onDelete = onDelete
        _isGMNotesExpanded = State(initialValue: !room.hasStructuredRoomContent)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                List {
                    descriptionSection
                    if let occupancy = room.occupancy { occupancySection(occupancy) }
                    if !room.features.isEmpty { featuresSection }
                    if !room.encounters.isEmpty { encountersSection }
                    if let treasure = room.treasure, !treasure.isEmpty { treasureSection(treasure) }
                    if !room.contentTags.isEmpty { contentTagsSection }
                    if onDelete != nil { deleteSection }
                }
            }
            // Hidden because on Mac Catalyst an inspector's title and toolbar items merge
            // into the window toolbar, away from the panel. `header` is the panel's own
            // always-visible heading instead.
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isEditingRoom) {
                if let viewModel {
                    RoomEditView(room: room, viewModel: viewModel)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// The panel's own heading, independent of the navigation bar/toolbar: the room title,
    /// its section name, and the Edit/Close buttons, all attached to the panel's content.
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(roomTitle)
                    .font(.title3.bold())
                if let sectionName {
                    Text(sectionName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 12) {
                if viewModel != nil {
                    Button("Edit") { isEditingRoom = true }
                }
                closeButton
            }
        }
        .padding()
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.secondary, .quaternary)
                .font(.title2)
        }
        .accessibilityLabel("Close")
    }

    // MARK: - Sections

    @ViewBuilder
    private var descriptionSection: some View {
        Section {
            let readAloud = room.readAloud?.isEmpty == false ? room.readAloud : nil
            let gmNotes = room.gmNotes?.isEmpty == false ? room.gmNotes : nil
            if readAloud == nil && gmNotes == nil {
                Text("No description.")
                    .foregroundStyle(.secondary)
            } else {
                if let readAloud {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Read aloud")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(.secondary)
                                .frame(width: 3)
                            Text(readAloud)
                                .italic()
                        }
                    }
                }
                if let gmNotes {
                    DisclosureGroup(isExpanded: $isGMNotesExpanded) {
                        Text(gmNotes)
                    } label: {
                        Text("GM notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func occupancySection(_ occupancy: Occupancy) -> some View {
        Section("Occupancy") {
            HStack {
                Text(occupancy.chance.description)
                if let probability = occupancy.chance.probability {
                    Spacer()
                    Text("\(Int((probability * 100).rounded()))%")
                        .foregroundStyle(.secondary)
                }
            }
            if let borrowedFromLabel {
                Text("Table from \(borrowedFromLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let table = resolvedTable {
                ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rangeText(row))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        EncounterRow(encounter: row.encounter, doorsOpened: doorsOpened(by:))
                    }
                }
            }
            if let notes = occupancy.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Roll") {
                rollOccupancy()
            }
            if let occupancyOutcome {
                outcomeView(occupancyOutcome)
                if let occupancyRollDescription {
                    Text(occupancyRollDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// The table that applies to this room, resolved through `tableRoomID` when `viewModel`
    /// is available; otherwise just the room's own table.
    private var resolvedTable: EncounterTable? {
        guard let viewModel, let currentMap = viewModel.currentMap else { return room.occupancy?.table }
        return currentMap.encounterTable(for: room)
    }

    /// The label and name of the room `occupancy.tableRoomID` names, when this room has no
    /// table of its own and that room resolves, else `nil`.
    private var borrowedFromLabel: String? {
        guard let occupancy = room.occupancy, occupancy.table == nil,
              let tableRoomID = occupancy.tableRoomID,
              let viewModel, let currentMap = viewModel.currentMap,
              let sourceRoom = currentMap.room(withID: tableRoomID) else { return nil }
        if let key = sourceRoom.keyNumber {
            if let name = sourceRoom.name { return "\(key): \(name)" }
            return key
        }
        return sourceRoom.name ?? "the room"
    }

    private func rollOccupancy() {
        guard let viewModel else {
            occupancyOutcome = room.occupancy?.roll()
            occupancyRollDescription = nil
            return
        }
        guard let currentMap = viewModel.currentMap, let result = currentMap.rollOccupancyDetail(for: room) else { return }
        occupancyOutcome = result.outcome
        occupancyRollDescription = result.rollDescription
    }

    private func rangeText(_ row: EncounterTable.Row) -> String {
        row.from == row.to ? "\(row.from)" : "\(row.from)-\(row.to)"
    }

    @ViewBuilder
    private func outcomeView(_ outcome: Occupancy.Outcome) -> some View {
        switch outcome {
        case .empty:
            Text("Empty")
                .font(.subheadline.weight(.medium))
        case .occupied(let encounter):
            Text("Occupied")
                .font(.subheadline.weight(.medium))
            if let encounter {
                EncounterRow(encounter: encounter, doorsOpened: doorsOpened(by:))
            }
        }
    }

    @ViewBuilder
    private var featuresSection: some View {
        Section("Features") {
            ForEach(room.features) { feature in
                FeatureRow(feature: feature, doorsOpened: doorsOpened(by:))
            }
        }
    }

    @ViewBuilder
    private var encountersSection: some View {
        Section("Encounters") {
            ForEach(Array(room.encounters.enumerated()), id: \.offset) { _, encounter in
                EncounterRow(encounter: encounter, doorsOpened: doorsOpened(by:))
            }
        }
    }

    @ViewBuilder
    private func treasureSection(_ treasure: Treasure) -> some View {
        Section("Treasure") {
            if !treasure.coins.quantities.isEmpty {
                let sortedCoins = treasure.coins.quantities
                    .sorted { coinOrder($0.key.symbol) < coinOrder($1.key.symbol) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 8) {
                    ForEach(sortedCoins, id: \.key) { entry in
                        CoinChip(amount: entry.value.description, symbol: entry.key.symbol)
                    }
                }
                .padding(.vertical, 4)
            }
            ForEach(Array(treasure.items.enumerated()), id: \.offset) { _, item in
                ItemRow(item: item, doorsOpened: item.keyID.map(doorsOpened(by:)))
            }
            if let notes = treasure.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                dismiss()
                onDelete?()
            } label: {
                Label("Delete Room", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private var contentTagsSection: some View {
        Section("Tags") {
            FlowLayout(spacing: 8) {
                ForEach(Array(room.contentTags).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { tag in
                    ContentTagChip(tag: tag)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private var roomTitle: String {
        if let key = room.keyNumber {
            if let name = room.name {
                return "Room \(key): \(name)"
            }
            return "Room \(key)"
        }
        if let name = room.name { return name }
        return "Room \(roomIndex)"
    }

    /// Doors on the current map opened by `keyID`, or 0 when `viewModel` is unavailable (e.g. previews).
    private func doorsOpened(by keyID: String) -> Int {
        guard let viewModel, let currentMap = viewModel.currentMap else { return 0 }
        return DungeonConnectivity(map: currentMap).doors(openedBy: keyID).count
    }

    /// The name of the section `room` belongs to, or nil when unsectioned or `viewModel` is unavailable.
    private var sectionName: String? {
        guard let viewModel, let currentMap = viewModel.currentMap else { return nil }
        return currentMap.section(for: room)?.name
    }
}

private func coinOrder(_ symbol: String) -> Int {
    ["pp", "gp", "ep", "sp", "cp"].firstIndex(of: symbol) ?? 99
}

extension DungeonRoom {
    /// Whether this room has Features, Encounters, Treasure, or Occupancy content, i.e. the
    /// structured sections below `RoomDetailView`'s description that would duplicate GM notes.
    var hasStructuredRoomContent: Bool {
        !features.isEmpty || !encounters.isEmpty || treasure?.isEmpty == false || occupancy != nil
    }
}

// MARK: - Sub-views

private struct EncounterRow: View {
    let encounter: RoomEncounter
    let doorsOpened: (String) -> Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(encounter.name, systemImage: "figure.fencing")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("×\(encounter.count.description)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let alignment = encounter.alignment {
                Text(alignment.description)
                    .font(.caption)
                    .foregroundStyle(alignmentColor(alignment))
            }
            if let stats = encounter.stats {
                Text(stats.summary)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            if let notes = encounter.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let carriedEach = encounter.carriedEach, !carriedEach.isEmpty {
                carriedView(label: "Each carries", treasure: carriedEach)
            }
            if let carried = encounter.carried, !carried.isEmpty {
                carriedView(label: "Carries", treasure: carried)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func carriedView(label: String, treasure: Treasure) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(coinSummary(label: label, treasure: treasure))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(treasure.items.enumerated()), id: \.offset) { _, item in
                ItemRow(item: item, doorsOpened: item.keyID.map(doorsOpened))
                    .padding(.leading, 16)
            }
        }
    }

    private func coinSummary(label: String, treasure: Treasure) -> String {
        let sortedCoins = treasure.coins.quantities
            .sorted { coinOrder($0.key.symbol) < coinOrder($1.key.symbol) }
        let coinText = sortedCoins.map { "\($0.value.description) \($0.key.symbol)" }.joined(separator: ", ")
        return coinText.isEmpty ? "\(label):" : "\(label): \(coinText)"
    }

    private func alignmentColor(_ alignment: CharacterAlignment) -> Color {
        switch alignment.kind.morals {
        case .good:    .blue
        case .neutral: .secondary
        case .evil:    .red
        }
    }
}

private struct FeatureRow: View {
    let feature: RoomFeature
    let doorsOpened: (String) -> Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: feature.kind.systemImageName)
                .font(.subheadline.weight(.medium))
            if let size = feature.size {
                Text("\(formatted(size.width)) × \(formatted(size.height)) squares")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let readAloud = feature.readAloud {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(.secondary)
                        .frame(width: 3)
                    Text(readAloud)
                        .italic()
                        .font(.caption)
                }
            }
            if let gmNotes = feature.gmNotes {
                Text(gmNotes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let treasure = feature.treasure, !treasure.isEmpty {
                treasureView(treasure)
            }
        }
        .padding(.vertical, 2)
    }

    /// Trims a trailing ".0" so whole numbers of squares don't show a decimal point.
    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }

    /// The feature's key label when it looks like a module letter, its name, or both.
    private var title: String {
        let shownID = feature.keyLabel
        switch (shownID, feature.name) {
        case let (id?, name?): return "\(id): \(name)"
        case let (id?, nil):   return id
        case let (nil, name?): return name
        case (nil, nil):       return feature.id
        }
    }

    @ViewBuilder
    private func treasureView(_ treasure: Treasure) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if !treasure.coins.quantities.isEmpty {
                let sortedCoins = treasure.coins.quantities
                    .sorted { coinOrder($0.key.symbol) < coinOrder($1.key.symbol) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 8) {
                    ForEach(sortedCoins, id: \.key) { entry in
                        CoinChip(amount: entry.value.description, symbol: entry.key.symbol)
                    }
                }
                .padding(.vertical, 4)
            }
            ForEach(Array(treasure.items.enumerated()), id: \.offset) { _, item in
                ItemRow(item: item, doorsOpened: item.keyID.map(doorsOpened))
            }
            if let notes = treasure.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ItemRow: View {
    let item: TreasureItem
    /// Number of doors on the current map this item's key opens, or nil when it isn't a key.
    let doorsOpened: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Label(title, systemImage: iconName)
                    .font(.subheadline)
                Spacer()
                if let value = item.value {
                    Text(value.description)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if let notes = item.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if item.keyID != nil, let doorsOpened {
                Text("Opens \(doorsOpened) door(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var title: String {
        item.quantity.constant == 1 ? item.name : "\(item.quantity.description) × \(item.name)"
    }

    private var iconName: String {
        if item.keyID != nil { return "key.fill" }
        if item.isMagic { return "sparkles" }
        return "shippingbox"
    }
}

private struct CoinChip: View {
    let amount: String
    let symbol: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundStyle(coinColor)
            Text("\(amount) \(symbol)")
                .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(coinColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var coinColor: Color {
        switch symbol {
        case "pp": .purple
        case "gp": .yellow
        case "ep": .mint
        case "sp": .secondary
        case "cp": .brown
        default:   .secondary
        }
    }
}

private struct ContentTagChip: View {
    let tag: DungeonRoom.ContentTag

    var body: some View {
        Label(tag.label, systemImage: tag.systemImage)
            .font(.caption)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tag.color.opacity(0.15))
            .foregroundStyle(tag.color)
            .clipShape(Capsule())
    }
}

extension DungeonRoom.ContentTag {
    var label: String {
        switch self {
        case .encounter: "Encounter"
        case .treasure:  "Treasure"
        case .trap:      "Trap"
        case .hazard:    "Hazard"
        case .empty:     "Empty"
        case .special:   "Special"
        }
    }

    var systemImage: String {
        switch self {
        case .encounter: "figure.fencing"
        case .treasure:  "crown.fill"
        case .trap:      "exclamationmark.triangle.fill"
        case .hazard:    "flame.fill"
        case .empty:     "square.dashed"
        case .special:   "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .encounter: .red
        case .treasure:  .yellow
        case .trap:      .orange
        case .hazard:    .purple
        case .empty:     .secondary
        case .special:   .blue
        }
    }
}

#Preview {
    let previewCurrencies = Currencies([
        UnitCurrency(symbol: "cp", coefficient: 0.01, name: "copper piece", plural: "copper pieces"),
        UnitCurrency(symbol: "sp", coefficient: 0.1, name: "silver piece", plural: "silver pieces"),
        UnitCurrency(symbol: "gp", coefficient: 1.0, name: "gold piece", plural: "gold pieces", isDefault: true),
    ])
    let room: DungeonRoom = {
        let r = DungeonRoom(location: MapPoint(x: 0, y: 0), size: MapSize(width: 5, height: 5))
        r.keyNumber = "7"
        r.readAloud = "Three goblins guard a locked chest."
        r.gmNotes = "A crude trap has been set near the door."
        r.encounters = [
            RoomEncounter(name: "Goblin", count: 3, alignment: CharacterAlignment(.chaotic, .evil)),
            RoomEncounter(name: "Goblin Boss", count: 1, alignment: CharacterAlignment(.chaotic, .evil), notes: "Carries the chest key")
        ]
        r.treasure = Treasure(
            coins: MoneyRoll(Money(coins: ["gp": 40, "sp": 120, "cp": 300], currencies: previewCurrencies)),
            items: [TreasureItem(name: "Potion of Healing")]
        )
        r.contentTags = [.encounter, .treasure, .trap]
        return r
    }()
    RoomDetailView(room: room, roomIndex: 7) { }
}
