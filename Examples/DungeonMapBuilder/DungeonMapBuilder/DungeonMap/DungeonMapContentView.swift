//
//  DungeonMapContentView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 8/1/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// Transient state for the room-add flow: the room being animated in, its animation
/// progress, and a flag preventing the gesture from adding a second room mid-drag.
private struct RoomAdditionState {
    var room: DungeonRoom? = nil
    var scale: CGFloat = 0.01
    var addedThisGesture = false
}

/// Layered canvas rendered inside the dungeon map scroll view.
///
/// Draws hallways, rooms, doors, and labels, and handles gestures according to the
/// active `MapTool`. In edit mode, each tool routes taps and drags differently:
/// - `.select`: tap to select any element; drag a room to move it.
/// - `.room`: tap/drag empty space to add rooms; drag a room to move it.
/// - `.hallway`: tap to place centerline waypoints; tap near first point or use the
///   toolbar Finish button to commit.
/// - `.door`: drag across a wall to place a simple door.
struct DungeonMapContentView: View {
    let viewModel: DungeonMapViewModel
    let isEditing: Bool
    let isSnapping: Bool
    let isFlowMode: Bool
    let activeTool: MapTool
    let displaySettings: MapDisplaySettings
    var minimumSize: CGSize = .zero

    @Environment(\.undoManager) private var undoManager

    @State private var additionState = RoomAdditionState()

    var body: some View {
        // Reading revision ensures the view re-renders after any mutation.
        let _ = viewModel.revision

        ZStack(alignment: .topLeading) {
            Group {
                if let gridImage = mapGridImage {
                    // Layer 2: Tiled hallways (behind rooms)
                    ForEach(viewModel.currentMap?.hallways ?? []) { hallway in
                        TiledRoomShape(room: hallway, scale: viewModel.scale, gridImage: gridImage, viewModel: viewModel)
                    }

                    // Layer 3: Tiled rooms; hidden while appearing so only the animation overlay shows
                    ForEach(viewModel.currentMap?.rooms ?? []) { room in
                        if room !== additionState.room {
                            TiledRoomShape(room: room, scale: viewModel.scale, gridImage: gridImage, viewModel: viewModel)
                        }
                    }
                }

                // Layer 4: Doors overlay
                ForEach(viewModel.currentMap?.doors ?? []) { door in
                    DoorView(viewModel: DungeonDoorViewModel(door: door, scale: viewModel.scale, showDoorSides: displaySettings.showDoorSides))
                }

                // Layer 4b: Room feature markers (above rooms, below labels)
                FeatureMarkersView(viewModel: viewModel, displaySettings: displaySettings)

                // Layer 5: Room labels
                RoomLabelView(viewModel: viewModel, displaySettings: displaySettings)

                // Layer 5b: Reachability heatmap (flow mode only)
                if isFlowMode {
                    ReachabilityOverlayView(viewModel: viewModel, revision: viewModel.revision)
                        .allowsHitTesting(false)
                }

                // Layer 6: Selection highlight; suppressed while the room is still animating in
                if let selected = viewModel.selectedElement, selected !== additionState.room {
                    RoomSelectionOverlay(room: selected, scale: viewModel.scale, revision: viewModel.revision)
                        .allowsHitTesting(false)
                }

                // Layer 7: Drag ghost at raw un-snapped finger position (edit mode only)
                if let ghostLoc = viewModel.dragGhostLocation, let dragging = viewModel.selectedElement {
                    RoomDragGhostView(room: dragging, ghostLocation: ghostLoc, scale: viewModel.scale)
                        .allowsHitTesting(false)
                }

                // Layer 8: In-progress hallway draft preview
                if isEditing, activeTool == .hallway {
                    HallwayDraftOverlay(viewModel: viewModel, scale: viewModel.scale)
                }

                // Layer 9: In-progress door draft preview
                if isEditing, activeTool == .door {
                    DoorDraftOverlay(viewModel: viewModel, scale: viewModel.scale)
                }

                // Layer 10: Room appearance animation when a new room is added
                if let appearing = additionState.room {
                    appearanceAnimationLayer(for: appearing)
                }

                // Layer 11: Resize corner handles — shown only for plain rooms in select mode
                if isEditing, activeTool == .select,
                   let selected = viewModel.selectedElement,
                   !(selected is DungeonHallway), !(selected is DungeonDoor),
                   selected !== additionState.room {
                    RoomResizeHandlesView(
                        room: selected,
                        scale: viewModel.scale,
                        revision: viewModel.revision,
                        onHandleDragChanged: { cornerIndex, screenPoint in
                            viewModel.handleCornerDragChanged(cornerIndex: cornerIndex, to: viewModel.mapPoint(for: screenPoint), snapping: isSnapping)
                        },
                        onHandleDragEnded: {
                            viewModel.endCornerResize(undoManager: undoManager)
                        }
                    )
                }
            }
            .offset(x: viewModel.canvasOffset.x, y: viewModel.canvasOffset.y)
        }
        .frame(
            width: max(viewModel.contentSize.width, minimumSize.width),
            height: max(viewModel.contentSize.height, minimumSize.height)
        )
        .contentShape(Rectangle())
        .coordinateSpace(name: "dungeonMap")
        .accessibilityIdentifier("dungeonMapCanvas")
        .onTapGesture(coordinateSpace: .named("dungeonMap")) { mapTapped(at: $0) }
        .gesture(editGesture(), including: isEditing ? .all : .none)
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    let delta = value.magnification - 1.0
                    viewModel.setScale(viewModel.scale + (delta * 20))
                },
            including: isEditing ? .none : .all
        )
    }

    // MARK: - Private view builders

    @ViewBuilder
    private func appearanceAnimationLayer(for room: DungeonRoom) -> some View {
        let cx = CGFloat(room.location.x + room.size.width / 2) * viewModel.scale
        let cy = CGFloat(room.location.y + room.size.height / 2) * viewModel.scale
        Canvas { context, _ in
            guard room.edges.count > 1 else { return }
            var path = Path()
            for (i, edge) in room.edges.enumerated() {
                let pt = CGPoint(edge * viewModel.scale)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
            context.fill(path, with: .color(.accentColor.opacity(0.4)))
        }
        .scaleEffect(
            additionState.scale,
            anchor: UnitPoint(
                x: cx / viewModel.contentSize.width,
                y: cy / viewModel.contentSize.height
            )
        )
        .allowsHitTesting(false)
    }

    // MARK: - Gesture handlers

    /// Routes taps in all modes.
    ///
    /// `TapGesture` wins gesture arbitration over `DragGesture` for pure taps, so all
    /// tap actions must live here rather than in `editGesture.onEnded`, which only fires
    /// reliably for actual drags.
    private func mapTapped(at location: CGPoint) {
        if isFlowMode {
            if let tapped = viewModel.room(at: location) { viewModel.setFlowStart(tapped) }
            return
        }
        guard isEditing else {
            viewModel.selectedElement = viewModel.room(at: location)
            return
        }
        switch activeTool {
        case .select:
            viewModel.selectedElement = viewModel.element(at: location)

        case .room:
            if viewModel.room(at: location) == nil, !viewModel.isInHallway(at: location) {
                beginRoomAddition(at: snappedMapPoint(from: location))
            } else {
                viewModel.selectedElement = viewModel.room(at: location)
            }

        case .hallway:
            let p = snappedMapPoint(from: location)
            if let points = viewModel.hallwayDraftPoints, points.count >= 2 {
                let first = points[0]
                let dx = p.x - first.x, dy = p.y - first.y
                if dx * dx + dy * dy < 1.0 {
                    viewModel.finishHallway(undoManager: undoManager)
                    return
                }
            }
            viewModel.appendHallwayPoint(p, snapping: isSnapping)

        case .door:
            break  // doors placed by dragging
        }
    }

    /// Unified gesture for edit mode, dispatched by `activeTool`.
    ///
    /// `minimumDistance: 4` ensures `TapGesture` and `DragGesture` never compete for the
    /// same touch: taps (< 4 pt) go exclusively to `mapTapped`; drags (≥ 4 pt) come here.
    private func editGesture() -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("dungeonMap"))
            .onChanged { value in
                guard isEditing else { return }
                let start = value.startLocation
                let t = value.translation

                switch activeTool {
                case .select:
                    viewModel.handleRoomDragChanged(
                        startLocation: viewModel.mapPoint(for: start),
                        translation: t,
                        snapping: isSnapping
                    )

                case .room:
                    // Add room on first touch of empty, non-hallway space.
                    if !additionState.addedThisGesture,
                       viewModel.dragGhostLocation == nil,
                       viewModel.room(at: start) == nil,
                       !viewModel.isInHallway(at: start) {
                        additionState.addedThisGesture = true
                        beginRoomAddition(at: snappedMapPoint(from: start))
                        return
                    }
                    guard !additionState.addedThisGesture else { return }
                    viewModel.handleRoomDragChanged(
                        startLocation: viewModel.mapPoint(for: start),
                        translation: t,
                        snapping: isSnapping
                    )

                case .hallway:
                    viewModel.updateHallwayPreview(viewModel.mapPoint(for: value.location), snapping: isSnapping)

                case .door:
                    if viewModel.doorDraftStart == nil {
                        viewModel.beginDoorDraft(at: snappedMapPoint(from: start))
                    }
                    viewModel.updateDoorDraft(to: snappedMapPoint(from: value.location), snapping: isSnapping)
                }
            }
            .onEnded { value in
                defer { additionState.addedThisGesture = false }
                guard isEditing else { return }
                let t = value.translation
                let distance = sqrt(t.width * t.width + t.height * t.height)

                switch activeTool {
                case .select:
                    // Taps handled by mapTapped; only end a room drag here.
                    guard distance >= 4 else { return }
                    viewModel.endRoomDrag(undoManager: undoManager)

                case .room:
                    if additionState.addedThisGesture { return }
                    // Taps handled by mapTapped; only end a room drag here.
                    guard distance >= 4 else { return }
                    viewModel.endRoomDrag(undoManager: undoManager)

                case .hallway:
                    return  // waypoint placement handled by mapTapped; commit via Finish button

                case .door:
                    viewModel.finishDoorDraft(undoManager: undoManager)
                }
            }
    }

    private func snappedMapPoint(from screenPoint: CGPoint) -> MapPoint {
        var point = viewModel.mapPoint(for: screenPoint)
        if isSnapping { point = MapPoint(x: point.x.rounded(), y: point.y.rounded()) }
        return point
    }

    private func beginRoomAddition(at mapPoint: MapPoint) {
        additionState.room = viewModel.addRoom(at: mapPoint, undoManager: undoManager)
        additionState.scale = 0.01
        withAnimation(.easeOut(duration: 0.5)) {
            additionState.scale = 1.0
        } completion: {
            additionState.room = nil
            additionState.scale = 0.01
        }
    }
}
