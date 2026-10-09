//
//  RoomEditView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 8/12/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore
import RolePlayingCore
import SwiftDice

struct RoomEditView: View {
    let room: DungeonRoom
    let viewModel: DungeonMapViewModel

    @Environment(DungeonStore.self) private var store
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dismiss) private var dismiss

    @State private var keyNumber: String
    @State private var name: String
    @State private var sectionID: String?
    @State private var readAloud: String
    @State private var gmNotes: String
    @State private var contentTags: Set<DungeonRoom.ContentTag>
    @State private var encounters: [RoomEncounter]
    @State private var features: [RoomFeature]
    @State private var coinAmounts: [String: String]
    @State private var items: [TreasureItem]
    @State private var treasureNotes: String
    @State private var hasOccupancy: Bool
    @State private var occupancyDieText: String
    @State private var occupancyDieIsValid = true
    @State private var occupancyAtMostText: String
    @State private var occupancyAtMostIsValid = true
    @State private var occupancyPer: String
    @State private var occupancyNotes: String
    @State private var occupancyTableRoomID: String?
    @State private var useCustomLabelLocation: Bool
    @State private var labelLocationXText: String
    @State private var labelLocationYText: String
    @State private var showDiscardAlert = false

    private let originalCoinAmounts: [String: String]
    private let originalItems: [TreasureItem]
    private let originalTreasureNotes: String
    private let originalHasOccupancy: Bool
    private let originalOccupancyDieText: String
    private let originalOccupancyAtMostText: String
    private let originalOccupancyPer: String
    private let originalOccupancyNotes: String
    private let originalOccupancyTableRoomID: String?
    private let originalUseCustomLabelLocation: Bool
    private let originalLabelLocationXText: String
    private let originalLabelLocationYText: String
    private let occupancyTable: EncounterTable?

    init(room: DungeonRoom, viewModel: DungeonMapViewModel) {
        self.room = room
        self.viewModel = viewModel

        _keyNumber = State(initialValue: room.keyNumber ?? "")
        _name = State(initialValue: room.name ?? "")
        _sectionID = State(initialValue: room.sectionID)
        _readAloud = State(initialValue: room.readAloud ?? "")
        _gmNotes = State(initialValue: room.gmNotes ?? "")
        _contentTags = State(initialValue: room.contentTags)
        _encounters = State(initialValue: room.encounters)
        _features = State(initialValue: room.features)

        var amounts: [String: String] = [:]
        for (unit, count) in room.treasure?.coins.quantities ?? [:] where count.constant != 0 {
            amounts[unit.symbol] = count.description
        }
        _coinAmounts = State(initialValue: amounts)
        _items = State(initialValue: room.treasure?.items ?? [])
        _treasureNotes = State(initialValue: room.treasure?.notes ?? "")

        originalCoinAmounts = amounts
        originalItems = room.treasure?.items ?? []
        originalTreasureNotes = room.treasure?.notes ?? ""

        let occupancy = room.occupancy
        _hasOccupancy = State(initialValue: occupancy != nil)
        _occupancyDieText = State(initialValue: occupancy?.chance.die.description ?? "d6")
        _occupancyAtMostText = State(initialValue: occupancy.map { String($0.chance.atMost) } ?? "1")
        _occupancyPer = State(initialValue: occupancy?.chance.per ?? "")
        _occupancyNotes = State(initialValue: occupancy?.notes ?? "")
        _occupancyTableRoomID = State(initialValue: occupancy?.tableRoomID)
        occupancyTable = occupancy?.table

        originalHasOccupancy = occupancy != nil
        originalOccupancyDieText = occupancy?.chance.die.description ?? "d6"
        originalOccupancyAtMostText = occupancy.map { String($0.chance.atMost) } ?? "1"
        originalOccupancyPer = occupancy?.chance.per ?? ""
        originalOccupancyNotes = occupancy?.notes ?? ""
        originalOccupancyTableRoomID = occupancy?.tableRoomID

        let center = MapPoint(x: room.location.x + room.size.width / 2, y: room.location.y + room.size.height / 2)
        let labelLocation = room.labelLocation
        _useCustomLabelLocation = State(initialValue: labelLocation != nil)
        _labelLocationXText = State(initialValue: String(labelLocation?.x ?? center.x))
        _labelLocationYText = State(initialValue: String(labelLocation?.y ?? center.y))

        originalUseCustomLabelLocation = labelLocation != nil
        originalLabelLocationXText = String(labelLocation?.x ?? center.x)
        originalLabelLocationYText = String(labelLocation?.y ?? center.y)
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                descriptionSection
                occupancySection
                contentTagsSection
                featuresSection
                encountersSection
                treasureSection
            }
            .navigationTitle("Edit Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRoom() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancelTapped() }
                }
            }
        }
        .alert("Discard Changes?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) { }
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section("Identity") {
            TextField("Key Number", text: $keyNumber)
            TextField("Name", text: $name)
            Picker("Section", selection: $sectionID) {
                Text("None").tag(String?.none)
                ForEach(viewModel.currentMap?.sections ?? []) { section in
                    Text(section.name).tag(Optional(section.id))
                }
            }
            Picker("Label position", selection: $useCustomLabelLocation) {
                Text("Automatic").tag(false)
                Text("Custom").tag(true)
            }
            if useCustomLabelLocation {
                HStack {
                    Text("X")
                    TextField("X", text: $labelLocationXText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Y")
                    TextField("Y", text: $labelLocationYText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    @ViewBuilder
    private var descriptionSection: some View {
        Section("Read aloud") {
            TextEditor(text: $readAloud)
                .frame(minHeight: 80)
        }
        Section("GM notes") {
            TextEditor(text: $gmNotes)
                .frame(minHeight: 80)
        }
    }

    @ViewBuilder
    private var occupancySection: some View {
        Section("Occupancy") {
            Toggle("A group may be here", isOn: $hasOccupancy)
            if hasOccupancy {
                TextField("Die (e.g. d10)", text: Binding(
                    get: { occupancyDieText },
                    set: { occupancyDieText = $0; occupancyDieIsValid = (try? AnyRollable(parsing: $0)) != nil }
                ))
                .foregroundStyle(occupancyDieIsValid ? Color.primary : Color.red)
                TextField("At Most", text: Binding(
                    get: { occupancyAtMostText },
                    set: { occupancyAtMostText = $0; occupancyAtMostIsValid = Int($0) != nil }
                ))
                .keyboardType(.numberPad)
                .foregroundStyle(occupancyAtMostIsValid ? Color.primary : Color.red)
                TextField("Per (e.g. turn)", text: $occupancyPer)
                if let occupancyTable {
                    Text("Table has \(occupancyTable.rows.count) rows")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Use table from", selection: $occupancyTableRoomID) {
                        Text("This room").tag(String?.none)
                        ForEach(roomsWithTables, id: \.id) { otherRoom in
                            Text(roomLabel(for: otherRoom)).tag(Optional(otherRoom.id))
                        }
                    }
                }
                TextField("Notes", text: $occupancyNotes)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var contentTagsSection: some View {
        Section("Tags") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(DungeonRoom.ContentTag.allCases, id: \.self) { tag in
                    let isOn = contentTags.contains(tag)
                    Button {
                        if isOn { contentTags.remove(tag) } else { contentTags.insert(tag) }
                    } label: {
                        Label(tag.label, systemImage: tag.systemImage)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(isOn ? tag.color.opacity(0.3) : Color.secondary.opacity(0.1))
                            .foregroundStyle(isOn ? tag.color : .secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var featuresSection: some View {
        Section("Features") {
            ForEach(features.indices, id: \.self) { index in
                NavigationLink {
                    FeatureEditView(feature: $features[index])
                } label: {
                    Text(features[index].name?.isEmpty == false ? features[index].name! : features[index].id)
                }
            }
            .onDelete { features.remove(atOffsets: $0) }
            Button {
                addFeature()
            } label: {
                Label("Add Feature", systemImage: "plus")
            }
        }
    }

    private var encountersSection: some View {
        Section("Encounters") {
            ForEach(encounters.indices, id: \.self) { index in
                NavigationLink {
                    EncounterEditView(encounter: $encounters[index])
                } label: {
                    Text(encounters[index].name.isEmpty ? "New Encounter" : encounters[index].name)
                }
            }
            .onDelete { encounters.remove(atOffsets: $0) }
            Button {
                encounters.append(RoomEncounter(name: "", count: 1))
            } label: {
                Label("Add Encounter", systemImage: "plus")
            }
        }
    }

    private var treasureSection: some View {
        Section("Treasure") {
            let sortedCurrencies = store.context.currencies.all.sorted { $0.coefficient > $1.coefficient }
            if !sortedCurrencies.isEmpty {
                ForEach(sortedCurrencies, id: \.symbol) { currency in
                    HStack {
                        Text(currency.plural.capitalized)
                        Spacer()
                        TextField("0", text: Binding(
                            get: { coinAmounts[currency.symbol] ?? "" },
                            set: { coinAmounts[currency.symbol] = $0.isEmpty ? nil : $0 }
                        ))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    }
                }
            }
            ForEach(items.indices, id: \.self) { index in
                NavigationLink {
                    ItemEditView(item: $items[index], currencies: store.context.currencies)
                } label: {
                    Text(items[index].name.isEmpty ? "New Item" : items[index].name)
                }
            }
            .onDelete { items.remove(atOffsets: $0) }
            Button {
                items.append(TreasureItem(name: ""))
            } label: {
                Label("Add Item", systemImage: "plus")
            }
            TextField("Notes", text: $treasureNotes)
                .foregroundStyle(.secondary)
        }
    }

    /// Other rooms on the current map that have a table of their own, available to borrow from.
    private var roomsWithTables: [DungeonRoom] {
        viewModel.currentMap?.rooms.filter { $0.id != room.id && $0.occupancy?.table != nil } ?? []
    }

    private func roomLabel(for otherRoom: DungeonRoom) -> String {
        if let key = otherRoom.keyNumber {
            if let name = otherRoom.name { return "\(key): \(name)" }
            return key
        }
        return otherRoom.name ?? otherRoom.id
    }

    // MARK: - Actions

    private func addFeature() {
        let center = MapPoint(x: room.location.x + room.size.width / 2, y: room.location.y + room.size.height / 2)
        let prefix = keyNumber.isEmpty ? "F" : keyNumber
        let newID = "\(prefix)-\(features.count + 1)"
        features.append(RoomFeature(id: newID, kind: .other, location: center))
    }

    private func cancelTapped() {
        let dirty = keyNumber != (room.keyNumber ?? "") ||
                    name != (room.name ?? "") ||
                    sectionID != room.sectionID ||
                    readAloud != (room.readAloud ?? "") ||
                    gmNotes != (room.gmNotes ?? "") ||
                    contentTags != room.contentTags ||
                    encounters != room.encounters ||
                    features != room.features ||
                    items != originalItems ||
                    coinAmounts != originalCoinAmounts ||
                    treasureNotes != originalTreasureNotes ||
                    hasOccupancy != originalHasOccupancy ||
                    occupancyDieText != originalOccupancyDieText ||
                    occupancyAtMostText != originalOccupancyAtMostText ||
                    occupancyPer != originalOccupancyPer ||
                    occupancyNotes != originalOccupancyNotes ||
                    occupancyTableRoomID != originalOccupancyTableRoomID ||
                    useCustomLabelLocation != originalUseCustomLabelLocation ||
                    labelLocationXText != originalLabelLocationXText ||
                    labelLocationYText != originalLabelLocationYText
        if dirty {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private func saveRoom() {
        var coinDict: [String: Int] = [:]
        for (symbol, text) in coinAmounts {
            if let amount = Int(text), amount > 0 {
                coinDict[symbol] = amount
            }
        }
        let money = Money(coins: coinDict, currencies: store.context.currencies)

        let hasContent = !money.quantities.isEmpty || !items.isEmpty || !treasureNotes.isEmpty
        let treasure: Treasure? = hasContent
            ? Treasure(coins: MoneyRoll(money), items: items,
                       notes: treasureNotes.isEmpty ? nil : treasureNotes)
            : nil

        // Auto-sync encounter and treasure content tags
        var newTags = contentTags
        if !encounters.isEmpty { newTags.insert(.encounter) } else { newTags.remove(.encounter) }
        if treasure != nil { newTags.insert(.treasure) } else { newTags.remove(.treasure) }

        var occupancy: Occupancy?
        if hasOccupancy, let die = try? AnyRollable(parsing: occupancyDieText), let atMost = Int(occupancyAtMostText) {
            occupancy = Occupancy(
                chance: Chance(die: die, atMost: atMost, per: occupancyPer.isEmpty ? nil : occupancyPer),
                table: occupancyTable,
                tableRoomID: occupancyTable == nil ? occupancyTableRoomID : nil,
                notes: occupancyNotes.isEmpty ? nil : occupancyNotes
            )
        }

        let center = MapPoint(x: room.location.x + room.size.width / 2, y: room.location.y + room.size.height / 2)
        let labelLocation: MapPoint? = useCustomLabelLocation
            ? MapPoint(x: Double(labelLocationXText) ?? center.x, y: Double(labelLocationYText) ?? center.y)
            : nil

        store.updateRoomContent(
            room,
            keyNumber: keyNumber.isEmpty ? nil : keyNumber,
            name: name.isEmpty ? nil : name,
            readAloud: readAloud.isEmpty ? nil : readAloud,
            gmNotes: gmNotes.isEmpty ? nil : gmNotes,
            contentTags: newTags,
            encounters: encounters,
            treasure: treasure,
            sectionID: sectionID,
            features: features,
            occupancy: occupancy,
            labelLocation: labelLocation,
            in: viewModel.dungeon,
            undoManager: undoManager
        )
        viewModel.revision += 1
        dismiss()
    }
}
