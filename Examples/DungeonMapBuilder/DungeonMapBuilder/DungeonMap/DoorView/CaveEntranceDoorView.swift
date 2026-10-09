//
//  CaveEntranceDoorView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 8/3/26.
//  Copyright © 2026 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// A view that renders a cave entrance as a thick arch shape.
///
/// The lower half has straight tapered walls that sharpen to a point at each door edge.
/// The upper half is a rounded arch connecting both walls. Even-odd fill hollows out
/// the arch opening. The arch extends toward `toArea` (into the cave); the opening
/// faces `fromArea` (outside).
struct CaveEntranceDoorView: View {
    let viewModel: DungeonDoorViewModel

    var body: some View {
        Canvas { context, size in
            let door = viewModel.door
            let scale = viewModel.scale
            let t = viewModel.doorThickness

            let doorVec = door.rightEdge - door.leftEdge
            let doorDirN = doorVec.normalized()
            // Right-hand perpendicular of door vector points toward toArea (into the cave).
            let perpN = MapPoint(x: doorVec.y, y: -doorVec.x).normalized()

            let depth    = door.doorWidth * 0.5   // total arch depth in map units
            let halfDepth = depth * 0.5            // height of the straight (tapered) section

            let L = CGPoint(x: CGFloat(door.leftEdge.x)  * scale, y: CGFloat(door.leftEdge.y)  * scale)
            let R = CGPoint(x: CGFloat(door.rightEdge.x) * scale, y: CGFloat(door.rightEdge.y) * scale)

            let px = CGFloat(perpN.x)      // perp unit-vector components (dimensionless)
            let py = CGFloat(perpN.y)
            let dx = CGFloat(doorDirN.x)   // door unit-vector components (dimensionless)
            let dy = CGFloat(doorDirN.y)

            let halfDepthPx = CGFloat(halfDepth) * scale
            let depthPx     = CGFloat(depth)     * scale

            // Four wall-top corners: ±(t/2) along door direction from each wall centre-line,
            // all sitting at halfDepth along the perp direction.
            let OTL = CGPoint(x: L.x + halfDepthPx * px - (t / 2) * dx,   // outer top-left
                              y: L.y + halfDepthPx * py - (t / 2) * dy)
            let ITL = CGPoint(x: L.x + halfDepthPx * px + (t / 2) * dx,   // inner top-left
                              y: L.y + halfDepthPx * py + (t / 2) * dy)
            let OTR = CGPoint(x: R.x + halfDepthPx * px + (t / 2) * dx,   // outer top-right
                              y: R.y + halfDepthPx * py + (t / 2) * dy)
            let ITR = CGPoint(x: R.x + halfDepthPx * px - (t / 2) * dx,   // inner top-right
                              y: R.y + halfDepthPx * py - (t / 2) * dy)

            // Quadratic Bezier control point that positions the arch peak at midpoint(L,R) + depth*perp.
            // Derived from: peak = 0.25*P0 + 0.5*ctrl + 0.25*P2, solved for ctrl.
            let midX = (L.x + R.x) / 2
            let midY = (L.y + R.y) / 2
            let archCtrl = CGPoint(x: midX + (2 * depthPx - halfDepthPx) * px,
                                   y: midY + (2 * depthPx - halfDepthPx) * py)

            // Outer contour (one winding direction):
            //   L → OTL → outer arch → OTR → R
            // Inner contour (opposite winding direction):
            //   R → ITR → inner arch → ITL → L
            //
            // The inverted-V at each door edge (e.g. OTR→R→ITR) creates the tapered
            // sharp-point effect. Even-odd fill hollows out the arch opening.
            var path = Path()
            path.move(to: L)
            path.addLine(to: OTL)
            path.addQuadCurve(to: OTR, control: archCtrl)
            path.addLine(to: R)
            path.addLine(to: ITR)
            path.addQuadCurve(to: ITL, control: archCtrl)
            path.addLine(to: L)
            path.closeSubpath()

            context.fill(path, with: .color(viewModel.doorColor), style: FillStyle(eoFill: true))

            // Opening strip rendered identically to a regular opening door
            let openingRect = viewModel.boundingRect
            var openingPath = Path(openingRect)
            if viewModel.needsRotation {
                let angle = viewModel.computedRotationAngle
                let rotationCenter = CGPoint(x: openingRect.minX, y: openingRect.midY)
                let transform = CGAffineTransform(translationX: rotationCenter.x, y: rotationCenter.y)
                    .rotated(by: angle)
                    .translatedBy(x: -rotationCenter.x, y: -rotationCenter.y)
                openingPath = openingPath.applying(transform)
            }
            context.fill(openingPath, with: .color(.white.opacity(0.9)))
        }
    }
}
