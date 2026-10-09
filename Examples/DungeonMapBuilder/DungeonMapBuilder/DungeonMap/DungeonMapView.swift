//
//  DungeonMapView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/2/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore


struct DungeonMapView: View {
    @Environment(\.undoManager) private var undoManager
    @State private var viewModel: DungeonMapViewModel
    @State private var isEditing = false
    @State private var isSnapping = true
    @State private var isFlowMode = false
    @State private var activeTool: MapTool = .select
    @State private var isPresentingDoorEdit = false
    @State private var isPresentingKeyProgression = false
    @AppStorage("mapDisplaySettings") private var displaySettings = MapDisplaySettings()
    @State private var scrollOffset: CGPoint = .zero

    init(dungeon: Dungeon, store: DungeonStore) {
        _viewModel = State(initialValue: DungeonMapViewModel(dungeon: dungeon, store: store))
    }

    var body: some View {
        VStack(spacing: 0) {
            MapNavigationBar(viewModel: viewModel)

            // GeometryReader provides the viewport size so the content fills it completely,
            // eliminating SwiftUI's centering of maps smaller than the viewport.
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    DungeonMapContentView(
                        viewModel: viewModel,
                        isEditing: isEditing,
                        isSnapping: isSnapping,
                        isFlowMode: isFlowMode,
                        activeTool: activeTool,
                        displaySettings: displaySettings,
                        minimumSize: proxy.size
                    )
                }
                .background {
                    MapBackgroundCanvas(scrollOffset: scrollOffset, scale: viewModel.scale)
                        .ignoresSafeArea(edges: .bottom)
                }
                .scrollDisabled(isEditing)
                .onScrollGeometryChange(for: CGPoint.self, of: { geo in
                    CGPoint(
                        x: geo.visibleRect.origin.x + geo.contentInsets.leading,
                        y: geo.visibleRect.origin.y + geo.contentInsets.top
                    )
                }) { _, newOffset in
                    scrollOffset = newOffset
                }
                .overlay {
                    if displaySettings.showRuler {
                        MapRulerView(scale: viewModel.scale, scrollOffset: scrollOffset, canvasOffset: viewModel.canvasOffset)
                    }
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 8) {
                        if isFlowMode {
                            HStack(spacing: 8) {
                                FlowLegendView()
                                Button {
                                    isPresentingKeyProgression = true
                                } label: {
                                    Label("Keys", systemImage: "key.fill")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .disabled(viewModel.flowStartRoom == nil)
                            }
                        }
                        ZoomControlBar(viewModel: viewModel)
                    }
                    .padding(.bottom, 12)
                }
                .overlay(alignment: .bottomTrailing) {
                    MapVerticalToolbar(
                        viewModel: viewModel,
                        isEditing: $isEditing,
                        isSnapping: $isSnapping,
                        isFlowMode: $isFlowMode,
                        displaySettings: $displaySettings,
                        activeTool: $activeTool,
                        onRemoveElement: {
                            viewModel.removeSelectedElement(undoManager: undoManager)
                        },
                        onFinishHallway: {
                            viewModel.finishHallway(undoManager: undoManager)
                        },
                        onCancelDraft: {
                            viewModel.cancelHallwayDraft()
                            viewModel.cancelDoorDraft()
                        },
                        onEditDoor: {
                            isPresentingDoorEdit = true
                        }
                    )
                    .padding(12)
                }
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.2)) { viewModel.resetScale() }
                }
                // Door edit sheet (edit mode only)
                .sheet(isPresented: $isPresentingDoorEdit) {
                    if let door = viewModel.selectedElement as? DungeonDoor {
                        DoorEditView(door: door, dungeon: viewModel.dungeon, viewModel: viewModel)
                    }
                }
                .sheet(isPresented: $isPresentingKeyProgression) {
                    KeyProgressionView(viewModel: viewModel)
                }
            }
        }
        .onDisappear {
            viewModel.saveSession()
        }
        // Cancel any in-progress drafts when the active tool changes.
        .onChange(of: activeTool) { _, _ in
            viewModel.cancelHallwayDraft()
            viewModel.cancelDoorDraft()
        }
        // Room detail inspector — a non-modal side panel on regular width, a sheet on compact.
        .inspector(isPresented: Binding(
            get: { !isEditing && !isFlowMode && viewModel.selectedElement != nil },
            set: { isPresented in
                if !isPresented { viewModel.selectedElement = nil }
            }
        )) {
            if let room = viewModel.selectedElement {
                let index = (viewModel.currentMap?.rooms.firstIndex(where: { $0 === room }) ?? 0) + 1
                RoomDetailView(
                    room: room, roomIndex: index, viewModel: viewModel,
                    onDelete: FeatureFlags.isMapEditingEnabled ? {
                        viewModel.removeSelectedElement(undoManager: undoManager)
                    } : nil
                )
                .id(ObjectIdentifier(room))
            }
        }
        .inspectorColumnWidth(min: 320, ideal: 400, max: 520)
        .toolbar {
            if FeatureFlags.isMapEditingEnabled {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { isEditing.toggle() }
                        if !isEditing {
                            viewModel.selectedElement = nil
                            viewModel.cancelHallwayDraft()
                            viewModel.cancelDoorDraft()
                            activeTool = .select
                            isSnapping = true
                        }
                    } label: {
                        Label(isEditing ? "Done" : "Edit",
                              systemImage: isEditing ? "checkmark.circle.fill" : "pencil.circle")
                    }
                    .tint(isEditing ? .green : nil)
                    .disabled(isFlowMode)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        let dungeon = try! Dungeon(fileName: "Sample")
        let store = DungeonStore()
        DungeonMapView(dungeon: dungeon, store: store)
            .environment(store)
    }
}
