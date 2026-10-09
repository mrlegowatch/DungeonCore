//
//  FeatureEditView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 10/6/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// Form for editing a single room feature's id, kind, name, size, read-aloud, and GM notes.
///
/// Position editing by dragging on the map is out of scope for this view; the current
/// coordinates are shown read-only instead.
struct FeatureEditView: View {
    @Binding var feature: RoomFeature

    @State private var widthText: String
    @State private var heightText: String

    init(feature: Binding<RoomFeature>) {
        self._feature = feature
        _widthText = State(initialValue: feature.wrappedValue.size.map { formatted($0.width) } ?? "")
        _heightText = State(initialValue: feature.wrappedValue.size.map { formatted($0.height) } ?? "")
    }

    var body: some View {
        Form {
            Section("Feature") {
                TextField("ID", text: $feature.id)
                Picker("Kind", selection: $feature.kind) {
                    ForEach(RoomFeature.Kind.allCases, id: \.self) { kind in
                        Text(kind.rawValue.capitalized).tag(kind)
                    }
                }
                TextField("Name", text: Binding(
                    get: { feature.name ?? "" },
                    set: { feature.name = $0.isEmpty ? nil : $0 }
                ))
            }
            Section("Size") {
                TextField("Width (squares)", text: Binding(
                    get: { widthText },
                    set: { widthText = $0; updateSize() }
                ))
                .keyboardType(.decimalPad)
                TextField("Height (squares)", text: Binding(
                    get: { heightText },
                    set: { heightText = $0; updateSize() }
                ))
                .keyboardType(.decimalPad)
                Text("A point feature has no size. Clear both fields to make this one a point feature again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Read aloud") {
                TextEditor(text: Binding(
                    get: { feature.readAloud ?? "" },
                    set: { feature.readAloud = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 60)
            }
            Section("GM notes") {
                TextEditor(text: Binding(
                    get: { feature.gmNotes ?? "" },
                    set: { feature.gmNotes = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 60)
            }
            Section("Position") {
                Text(String(format: "x: %.1f, y: %.1f", feature.location.x, feature.location.y))
                Text("Position editing by dragging on the map is out of scope.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(feature.name?.isEmpty == false ? feature.name! : feature.id)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Commits `widthText`/`heightText` to `feature.size`. Clearing both fields makes the
    /// feature a point feature again; otherwise a size only commits once both parse.
    private func updateSize() {
        if widthText.isEmpty && heightText.isEmpty {
            feature.size = nil
            return
        }
        guard let width = Double(widthText), let height = Double(heightText) else { return }
        feature.size = MapSize(width: width, height: height)
    }
}

/// Trims a trailing ".0" so whole numbers of squares don't show a decimal point.
private func formatted(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
}
