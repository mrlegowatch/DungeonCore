//
//  DoorView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/5/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// A view that renders a dungeon door with visual indicators for its properties
///
/// This view uses a composable architecture with separate views for different door types
/// and adornments, coordinated through a `DungeonDoorViewModel`.
struct DoorView: View {
    let viewModel: DungeonDoorViewModel
    
    init(viewModel: DungeonDoorViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            // Background areas (fromArea and toArea), a debugging aid gated by showsDoorSides
            if viewModel.showsDoorSides {
                DoorAreaView(viewModel: viewModel)
            }

            // Door body based on type
            doorBodyView

            // Adornments
            if viewModel.hasOneWayArrow {
                OneWayArrowView(viewModel: viewModel)
            }

            if viewModel.hasLockIndicator {
                LockIndicatorView(viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private var doorBodyView: some View {
        // A secret door (any kind but passage) draws the wall unbroken with just an "S"
        // glyph; a secret passage instead becomes a tunnel, handled inside PathBasedDoorView.
        if viewModel.door.hasAttribute(.isSecret), viewModel.door.kind != .passage {
            SecretDoorGlyphView(viewModel: viewModel)
        } else {
            switch viewModel.doorType {
            case .simple:
                SimpleDoorView(viewModel: viewModel)
            case .rectangular:
                RectangularDoorView(viewModel: viewModel)
            case .pathBased:
                PathBasedDoorView(viewModel: viewModel)
                    .blendMode(.multiply)
            case .caveEntrance:
                CaveEntranceDoorView(viewModel: viewModel)
            }
        }
    }
}
