//
//  ItemEditView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 10/5/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore
import RolePlayingCore
import SwiftDice

/// Form for editing a single treasure item's name, quantity, value, key ID, magic flag, and notes.
struct ItemEditView: View {
    @Binding var item: TreasureItem
    let currencies: Currencies

    @State private var quantityText: String
    @State private var valueText: String
    @State private var quantityInvalid = false
    @State private var valueInvalid = false

    init(item: Binding<TreasureItem>, currencies: Currencies) {
        self._item = item
        self.currencies = currencies
        _quantityText = State(initialValue: item.wrappedValue.quantity.description)
        _valueText = State(initialValue: item.wrappedValue.value?.description ?? "")
    }

    var body: some View {
        Form {
            Section("Item") {
                TextField("Name", text: $item.name)
                TextField("Quantity", text: Binding(
                    get: { quantityText },
                    set: { newValue in
                        quantityText = newValue
                        if let parsed = try? AnyRollable(parsing: newValue) {
                            item.quantity = parsed
                            quantityInvalid = false
                        } else {
                            quantityInvalid = true
                        }
                    }
                ))
                .foregroundStyle(quantityInvalid ? .red : .primary)
                TextField("Value (e.g. 5 gp)", text: Binding(
                    get: { valueText },
                    set: { newValue in
                        valueText = newValue
                        if newValue.isEmpty {
                            item.value = nil
                            valueInvalid = false
                        } else if let parsed = newValue.parseMoney(currencies) {
                            item.value = parsed
                            valueInvalid = false
                        } else {
                            valueInvalid = true
                        }
                    }
                ))
                .foregroundStyle(valueInvalid ? .red : .primary)
                TextField("Key ID", text: Binding(
                    get: { item.keyID ?? "" },
                    set: { item.keyID = $0.isEmpty ? nil : $0 }
                ))
                Toggle("Magic", isOn: $item.isMagic)
                TextField("Notes", text: Binding(
                    get: { item.notes ?? "" },
                    set: { item.notes = $0.isEmpty ? nil : $0 }
                ))
            }
        }
        .navigationTitle(item.name.isEmpty ? "New Item" : item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
