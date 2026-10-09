//
//  ReachabilityOverlayView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 8/2/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// Fills each room's polygon with a translucent color indicating its reachability status.
///
/// Green = freely reachable, orange = key/secret-gated, red = unreachable from the chosen start.
/// The start room itself is highlighted with a white border.
struct ReachabilityOverlayView: View {
    let viewModel: DungeonMapViewModel
    var revision: Int = 0

    var body: some View {
        Canvas { context, _ in
            for room in viewModel.currentMap?.rooms ?? [] {
                guard room.edges.count > 1 else { continue }

                var path = Path()
                for (i, edge) in room.edges.enumerated() {
                    let pt = CGPoint(edge * viewModel.scale)
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                path.closeSubpath()

                let fillColor: Color
                switch viewModel.reachabilityStatus(for: room) {
                case .reachable:   fillColor = .green.opacity(0.35)
                case .keyGated:    fillColor = .orange.opacity(0.35)
                case .unreachable: fillColor = .red.opacity(0.35)
                case nil:          fillColor = .clear
                }
                if fillColor != .clear {
                    context.fill(path, with: .color(fillColor))
                }

                // White ring on the start room so the DM knows the current root.
                if room === viewModel.flowStartRoom {
                    context.stroke(
                        path,
                        with: .color(.white.opacity(0.85)),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
    }
}
