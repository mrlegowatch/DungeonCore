//
//  EncounterEditView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 8/12/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore
import RolePlayingCore
import SwiftDice

struct EncounterEditView: View {
    @Binding var encounter: RoomEncounter

    @State private var armorClassText: String
    @State private var armorClassIsValid = true
    @State private var hitDiceText: String
    @State private var hitPointsText: String
    @State private var hitPointsIsValid = true
    @State private var attacksText: String
    @State private var attacksIsValid = true
    @State private var damageText: String
    @State private var damageIsValid = true
    @State private var specialText: String
    @State private var statTextText: String

    init(encounter: Binding<RoomEncounter>) {
        self._encounter = encounter
        let stats = encounter.wrappedValue.stats
        _armorClassText = State(initialValue: stats?.armorClass.map(String.init) ?? "")
        _hitDiceText = State(initialValue: stats?.hitDice ?? "")
        _hitPointsText = State(initialValue: stats?.hitPoints.map(String.init).joined(separator: ", ") ?? "")
        _attacksText = State(initialValue: stats?.attacks.map(String.init) ?? "")
        _damageText = State(initialValue: stats?.damage.map(\.description).joined(separator: ", ") ?? "")
        _specialText = State(initialValue: stats?.special ?? "")
        _statTextText = State(initialValue: stats?.text ?? "")
    }

    var body: some View {
        Form {
            Section("Creature") {
                TextField("Name", text: $encounter.name)
                TextField("Count (e.g. 2d6, 3)", text: Binding(
                    get: { encounter.count.description },
                    set: { if let parsed = try? AnyRollable(parsing: $0) { encounter.count = parsed } }
                ))
                TextField("Creature Type (e.g. Undead, Beast)", text: Binding(
                    get: { encounter.creatureType?.name ?? "" },
                    set: { encounter.creatureType = $0.isEmpty ? nil : CreatureType($0) }
                ))
            }
            Section("Stats") {
                Picker("Size", selection: Binding(
                    get: { encounter.size },
                    set: { encounter.size = $0 }
                )) {
                    Text("—").tag(Optional<CreatureSize>.none)
                    ForEach(CreatureSize.allCases, id: \.self) { size in
                        Text(size.rawValue.capitalized).tag(Optional<CreatureSize>.some(size))
                    }
                }
            }
            Section("Stat line") {
                TextField("Armor Class", text: Binding(
                    get: { armorClassText },
                    set: { armorClassText = $0; updateArmorClass() }
                ))
                .foregroundStyle(armorClassIsValid ? Color.primary : Color.red)
                TextField("Hit Dice (e.g. 1, 1+1, 1/4, 2d8+2)", text: $hitDiceText)
                    .onChange(of: hitDiceText) { updateHitDice() }
                TextField("Hit Points (comma-separated, e.g. 6, 5, 5)", text: Binding(
                    get: { hitPointsText },
                    set: { hitPointsText = $0; updateHitPoints() }
                ))
                .foregroundStyle(hitPointsIsValid ? Color.primary : Color.red)
                TextField("Attacks", text: Binding(
                    get: { attacksText },
                    set: { attacksText = $0; updateAttacks() }
                ))
                .foregroundStyle(attacksIsValid ? Color.primary : Color.red)
                TextField("Damage (comma-separated, e.g. 1d6+2, d4)", text: Binding(
                    get: { damageText },
                    set: { damageText = $0; updateDamage() }
                ))
                .foregroundStyle(damageIsValid ? Color.primary : Color.red)
                TextField("Special (e.g. poison)", text: $specialText)
                    .onChange(of: specialText) { updateSpecial() }
                TextField("Text (verbatim from source)", text: $statTextText)
                    .onChange(of: statTextText) { updateStatText() }
            }
            Section("Notes") {
                TextField("Notes", text: Binding(
                    get: { encounter.notes ?? "" },
                    set: { encounter.notes = $0.isEmpty ? nil : $0 }
                ))
            }
        }
        .navigationTitle(encounter.name.isEmpty ? "New Encounter" : encounter.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Stat line field updates

    /// Mutates `encounter.stats`, creating it if needed and clearing it back to nil when every field is empty.
    private func setStats(_ mutate: (inout StatLine) -> Void) {
        var stats = encounter.stats ?? StatLine()
        mutate(&stats)
        encounter.stats = stats == StatLine() ? nil : stats
    }

    private func updateArmorClass() {
        if armorClassText.isEmpty {
            armorClassIsValid = true
            setStats { $0.armorClass = nil }
        } else if let value = Int(armorClassText) {
            armorClassIsValid = true
            setStats { $0.armorClass = value }
        } else {
            armorClassIsValid = false
        }
    }

    private func updateHitDice() {
        setStats { $0.hitDice = hitDiceText.isEmpty ? nil : hitDiceText }
    }

    private func updateHitPoints() {
        let trimmed = hitPointsText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            hitPointsIsValid = true
            setStats { $0.hitPoints = [] }
            return
        }
        let parsed = trimmed.split(separator: ",").map { Int($0.trimmingCharacters(in: .whitespaces)) }
        if parsed.allSatisfy({ $0 != nil }) {
            hitPointsIsValid = true
            setStats { $0.hitPoints = parsed.compactMap { $0 } }
        } else {
            hitPointsIsValid = false
        }
    }

    private func updateAttacks() {
        if attacksText.isEmpty {
            attacksIsValid = true
            setStats { $0.attacks = nil }
        } else if let value = Int(attacksText) {
            attacksIsValid = true
            setStats { $0.attacks = value }
        } else {
            attacksIsValid = false
        }
    }

    private func updateDamage() {
        let trimmed = damageText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            damageIsValid = true
            setStats { $0.damage = [] }
            return
        }
        let parsed = trimmed.split(separator: ",").map { try? AnyRollable(parsing: $0.trimmingCharacters(in: .whitespaces)) }
        if parsed.allSatisfy({ $0 != nil }) {
            damageIsValid = true
            setStats { $0.damage = parsed.compactMap { $0 } }
        } else {
            damageIsValid = false
        }
    }

    private func updateSpecial() {
        setStats { $0.special = specialText.isEmpty ? nil : specialText }
    }

    private func updateStatText() {
        setStats { $0.text = statTextText.isEmpty ? nil : statTextText }
    }
}
