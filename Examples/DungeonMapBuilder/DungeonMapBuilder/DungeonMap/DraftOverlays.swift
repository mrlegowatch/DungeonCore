//
//  DraftOverlays.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 8/12/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// Live preview canvas for an in-progress hallway: placed waypoints as filled dots,
/// dashed segments between them, and a dashed line to the current preview position.
struct HallwayDraftOverlay: View {
    let viewModel: DungeonMapViewModel
    let scale: CGFloat

    var body: some View {
        let _ = viewModel.revision
        Canvas { context, _ in
            guard let points = viewModel.hallwayDraftPoints, !points.isEmpty else { return }

            // Dashed line through placed points + preview endpoint
            var path = Path()
            path.move(to: CGPoint(points[0] * scale))
            for p in points.dropFirst() {
                path.addLine(to: CGPoint(p * scale))
            }
            if let preview = viewModel.hallwayPreviewPoint {
                path.addLine(to: CGPoint(preview * scale))
            }
            context.stroke(
                path,
                with: .color(.accentColor),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 3])
            )

            // Filled dots at each placed waypoint
            for p in points {
                let center = CGPoint(p * scale)
                let rect = CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)
                let dot = Path(ellipseIn: rect)
                context.fill(dot, with: .color(.accentColor))
                context.stroke(dot, with: .color(.white), lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Live preview canvas for an in-progress door: a short colored line between the
/// two drag endpoints with dot markers at each end.
struct DoorDraftOverlay: View {
    let viewModel: DungeonMapViewModel
    let scale: CGFloat

    var body: some View {
        let _ = viewModel.revision
        Canvas { context, _ in
            guard let start = viewModel.doorDraftStart,
                  let end = viewModel.doorDraftEnd else { return }

            var path = Path()
            path.move(to: CGPoint(start * scale))
            path.addLine(to: CGPoint(end * scale))
            context.stroke(
                path,
                with: .color(.orange),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 2])
            )

            for p in [start, end] {
                let center = CGPoint(p * scale)
                let rect = CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)
                context.fill(Path(ellipseIn: rect), with: .color(.orange))
                context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
    }
}
