//
//  DungeonDoorViewModel.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/6/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI
import DungeonCore

/// Door rendering approaches.
enum DoorRenderType {
    /// Simple door drawn from leftEdge to rightEdge
    case simple
    /// Area-based door using a rectangular area
    case rectangular
    /// Path-based door using edges or segments
    case pathBased
    /// Cave entrance drawn as a U shape from leftEdge to rightEdge
    case caveEntrance
}

/// View model that encapsulates door rendering logic and visual properties.
@MainActor
@Observable
final class DungeonDoorViewModel {
    let door: DungeonDoor
    let scale: CGFloat
    /// Whether the green/red `fromArea`/`toArea` debugging tint should be drawn, per `MapDisplaySettings.showDoorSides`.
    let showDoorSides: Bool

    init(door: DungeonDoor, scale: CGFloat, showDoorSides: Bool = false) {
        self.door = door
        self.scale = scale
        self.showDoorSides = showDoorSides
    }

    // MARK: - Door Classification

    var doorType: DoorRenderType {
        switch door.kind {
        case .trapDoor, .elevator:
            return .rectangular
        case .staircase, .passage:
            return .pathBased
        case .caveEntrance:
            return .caveEntrance
        case .opening, .door, .portcullis, .slidingDoor, .ladder, .magicPortal:
            return .simple
        }
    }

    /// `showDoorSides` is honored only for simple and cave-entrance doors. Path-based
    /// doors (staircase, passage) and area doors (trapDoor, elevator) compute `fromArea`/
    /// `toArea` from their first and last path points, which comes out as a large skewed
    /// quadrilateral rather than a wall-adjacent patch, so it never reads as useful here.
    var showsDoorSides: Bool {
        showDoorSides && (doorType == .simple || doorType == .caveEntrance)
    }

    // MARK: - Visual Properties

    var doorThickness: CGFloat {
        let baseThickness = MapViewConfiguration.doorThicknessRatio * scale
        return (door.kind == .portcullis || door.kind == .caveEntrance) ? baseThickness * 1.5 : baseThickness
    }
    
    var doorColor: Color {
        switch door.kind {
        case .door:
            if door.hasAttribute(.isLocked) {
                return .blue
            } else if door.hasAttribute(.hasTrap) {
                return .red
            } else {
                return .gray
            }
        case .opening:
            return .white
        case .portcullis:
            return .veryLightGray
        case .slidingDoor:
            return .brown
        case .ladder:
            return .orange
        case .trapDoor:
            return .brown
        case .elevator:
            return Color(red: 0.5, green: 0.5, blue: 0.6)
        case .staircase:
            return Color(red: 0.85, green: 0.78, blue: 0.68)
        case .passage:
            return Color(red: 0.96, green: 0.96, blue: 0.9)
        case .magicPortal:
            return Color(red: 0.6, green: 0.3, blue: 0.8)
        case .caveEntrance:
            return Color(red: 0.35, green: 0.28, blue: 0.2)
        }
    }
    
    var alpha: CGFloat {
        switch door.kind {
        case .ladder:
            return 0.8
        case .trapDoor:
            return 0.9
        case .elevator:
            return 0.95
        case .staircase:
            return 0.6
        case .passage:
            return 0.85
        case .magicPortal:
            return 0.9
        default:
            return 1.0
        }
    }
    
    var borderWidth: CGFloat {
        switch door.kind {
        case .opening:
            return 0.0
        case .trapDoor, .elevator:
            return MapViewConfiguration.doorBorderWidth * 2
        case .staircase:
            return MapViewConfiguration.doorBorderWidth * 1.5
        default:
            return MapViewConfiguration.doorBorderWidth
        }
    }
    
    // MARK: - Geometry
    
    var boundingRect: CGRect {
        switch doorType {
        case .rectangular:
            return CGRect(
                x: CGFloat(door.location.x) * scale,
                y: CGFloat(door.location.y) * scale,
                width: CGFloat(door.size.width) * scale,
                height: CGFloat(door.size.height) * scale
            )
        case .pathBased:
            return CGRect(
                x: CGFloat(door.location.x) * scale,
                y: CGFloat(door.location.y) * scale,
                width: CGFloat(door.size.width) * scale,
                height: CGFloat(door.size.height) * scale
            )
        case .simple, .caveEntrance:
            return computeSimpleDoorRect()
        }
    }
    
    private func computeSimpleDoorRect() -> CGRect {
        let doorVector = door.rightEdge - door.leftEdge
        let doorDirection = doorVector.normalized()
        let inset = doorVector.length() * (1 - MapViewConfiguration.doorLengthRatio) / 2

        let insetLeftEdge = door.leftEdge + (doorDirection * inset)
        let insetRightEdge = door.rightEdge - (doorDirection * inset)
        
        let leftPoint = insetLeftEdge * scale
        let rightPoint = insetRightEdge * scale
        
        let insetDoorVector = insetRightEdge - insetLeftEdge
        let doorLength = insetDoorVector.length() * scale
        
        let isVertical = abs(doorVector.x) < 0.01
        let isHorizontal = abs(doorVector.y) < 0.01
        
        if isVertical {
            return CGRect(
                x: leftPoint.x - doorThickness / 2.0,
                y: min(leftPoint.y, rightPoint.y),
                width: doorThickness,
                height: doorLength
            )
        } else if isHorizontal {
            return CGRect(
                x: min(leftPoint.x, rightPoint.x),
                y: leftPoint.y - doorThickness / 2.0,
                width: doorLength,
                height: doorThickness
            )
        } else {
            return CGRect(
                x: leftPoint.x,
                y: leftPoint.y - doorThickness / 2.0,
                width: doorLength,
                height: doorThickness
            )
        }
    }
    
    var needsRotation: Bool {
        guard doorType == .simple || doorType == .caveEntrance else { return false }

        let doorVector = door.rightEdge - door.leftEdge
        let isVertical = abs(doorVector.x) < 0.01
        let isHorizontal = abs(doorVector.y) < 0.01

        return !isVertical && !isHorizontal
    }

    var computedRotationAngle: CGFloat {
        let doorVector = door.rightEdge - door.leftEdge
        return CGFloat(atan2(doorVector.y, doorVector.x))
    }
    
    // MARK: - Adornment Properties
    
    var hasOneWayArrow: Bool {
        door.hasAttribute(.isOneWay)
    }
    
    var hasLockIndicator: Bool {
        door.hasAttribute(.isLocked)
    }
    
    var oneWayArrowText: String {
        let doorVector = door.rightEdge - door.leftEdge
        let perpX = doorVector.y
        let perpY = -doorVector.x
        
        if abs(doorVector.x) < 0.01 {
            return perpX > 0 ? "→" : "←"
        } else if abs(doorVector.y) < 0.01 {
            return perpY > 0 ? "↓" : "↑"
        } else {
            if abs(perpX) > abs(perpY) {
                return perpX > 0 ? "→" : "←"
            } else {
                return perpY > 0 ? "↓" : "↑"
            }
        }
    }
}
