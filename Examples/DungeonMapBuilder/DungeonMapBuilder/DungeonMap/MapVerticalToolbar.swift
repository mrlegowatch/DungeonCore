//
//  MapVerticalToolbar.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/2/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

struct MapVerticalToolbar: View {
    let viewModel: DungeonMapViewModel
    @Binding var isEditing: Bool
    @Binding var isSnapping: Bool
    @Binding var isFlowMode: Bool
    @Binding var displaySettings: MapDisplaySettings
    @Binding var activeTool: MapTool
    let onRemoveElement: () -> Void
    let onFinishHallway: () -> Void
    let onCancelDraft: () -> Void
    let onEditDoor: () -> Void

    private var hallwayCanFinish: Bool {
        (viewModel.hallwayDraftPoints?.count ?? 0) >= 2
    }

    var body: some View {
        VStack(spacing: 4) {
            if isEditing {
                // Hallway draft controls appear above the tool picker while drawing
                if activeTool == .hallway, viewModel.hallwayDraftPoints != nil {
                    if hallwayCanFinish {
                        Button(action: onFinishHallway) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.green)
                                .frame(width: 36, height: 36)
                        }
                        .accessibilityLabel("Finish Hallway")
                        .accessibilityIdentifier("tool.finish")
                    }
                    Button(action: onCancelDraft) {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.red)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Cancel Draft")
                    .accessibilityIdentifier("tool.cancel")
                    Divider()
                }

                // Tool picker — one button per tool, vertical like the rest of the toolbar
                ForEach(MapTool.allCases, id: \.self) { tool in
                    Button {
                        activeTool = tool
                    } label: {
                        Image(systemName: tool.systemImage)
                            .foregroundStyle(activeTool == tool ? Color.accentColor : Color.primary)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel(tool.label)
                    .accessibilityIdentifier("tool.\(tool.label.lowercased())")
                }

                Divider()

                // Selected element actions
                if viewModel.selectedElement != nil {
                    Button(role: .destructive, action: onRemoveElement) {
                        Image(systemName: "trash").frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Delete")
                    .accessibilityIdentifier("element.delete")
                }
                if viewModel.selectedElement is DungeonDoor {
                    Button(action: onEditDoor) {
                        Image(systemName: "pencil").frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Edit Door")
                    .accessibilityIdentifier("element.editDoor")
                }

                Button {
                    isSnapping.toggle()
                } label: {
                    Image(systemName: "grid")
                        .foregroundStyle(isSnapping ? Color.accentColor : Color.primary)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel(isSnapping ? "Snap On" : "Snap Off")
                .accessibilityIdentifier("tool.snap")

                Divider()
            }

            Button { displaySettings.showRuler.toggle() } label: {
                Image(systemName: "ruler")
                    .foregroundStyle(displaySettings.showRuler ? Color.accentColor : Color.primary)
                    .frame(width: 36, height: 36)
            }

            Menu {
                Toggle("Rooms", isOn: $displaySettings.showRoomLabels)
                Toggle("Hallways", isOn: $displaySettings.showHallwayLabels)
                Toggle("Doors", isOn: $displaySettings.showDoorLabels)
                Toggle("Features", isOn: $displaySettings.showFeatures)
                Divider()
                Toggle("Door Sides", isOn: $displaySettings.showDoorSides)
                Divider()
                Button("None") {
                    displaySettings.showRoomLabels = false
                    displaySettings.showHallwayLabels = false
                    displaySettings.showDoorLabels = false
                }
                .disabled(!displaySettings.showRoomLabels && !displaySettings.showHallwayLabels && !displaySettings.showDoorLabels)
            } label: {
                Image(systemName: "tag")
                    .foregroundStyle((displaySettings.showRoomLabels || displaySettings.showHallwayLabels || displaySettings.showDoorLabels) ? Color.accentColor : Color.primary)
                    .frame(width: 36, height: 36)
            }

            if !isEditing {
                Button {
                    withAnimation { isFlowMode.toggle() }
                    if isFlowMode { viewModel.enterFlowMode() } else { viewModel.exitFlowMode() }
                } label: {
                    Image(systemName: "network")
                        .foregroundStyle(isFlowMode ? Color.accentColor : Color.primary)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
}
