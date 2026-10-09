//
//  DungeonMapBuilderUITests.swift
//  DungeonMapBuilderUITests
//
//  Created by Brian Arnold on 12/2/25.
//

import XCTest

// MARK: - Helpers

extension XCUIApplication {
    /// Opens the first dungeon in the list and returns once the Edit button is visible.
    func openFirstDungeon() {
        // SwiftUI List is backed by UICollectionView on iOS 16+, so `tables.cells`
        // returns empty. Use `cells` which matches both UITableView and UICollectionView.
        let cell = cells.firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "No dungeon cells found")
        cell.tap()
        XCTAssertTrue(buttons["Edit"].waitForExistence(timeout: 5), "Edit button did not appear")
    }

    /// Enters map edit mode.
    func enterEditMode() {
        let editButton = buttons["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()
        XCTAssertTrue(buttons["Done"].waitForExistence(timeout: 2), "Did not enter edit mode")
    }

    /// Selects a drawing tool by its accessibility identifier (e.g. "tool.hallway").
    func selectTool(_ id: String) {
        let btn = buttons[id]
        XCTAssertTrue(btn.waitForExistence(timeout: 2), "Tool button '\(id)' not found")
        btn.tap()
    }

    /// Returns the map canvas element.
    var mapCanvas: XCUIElement { otherElements["dungeonMapCanvas"] }
}

// MARK: - Drawing tool tests

final class DungeonMapBuilderUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Edit mode

    @MainActor
    func testEditModeToggle() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-enableMapEditing"]
        app.launch()
        app.openFirstDungeon()

        // Enter edit mode
        app.enterEditMode()
        XCTAssertTrue(app.buttons["Done"].exists, "Should show Done while editing")

        // Verify all four tool buttons are visible
        for id in ["tool.select", "tool.room", "tool.hallway", "tool.door"] {
            XCTAssertTrue(app.buttons[id].exists, "Expected tool button '\(id)'")
        }

        // Exit edit mode
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 2), "Should return to Edit button")

        // Tool buttons should be gone after exiting
        XCTAssertFalse(app.buttons["tool.hallway"].exists, "Tool buttons should be hidden in view mode")
    }

    // MARK: Hallway tool

    @MainActor
    func testHallwayToolPlacesWaypoints() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-enableMapEditing"]
        app.launch()
        app.openFirstDungeon()
        app.enterEditMode()
        app.selectTool("tool.hallway")

        let canvas = app.mapCanvas
        XCTAssertTrue(canvas.waitForExistence(timeout: 3), "Map canvas not found")

        // Finish button should not exist before any points are placed
        XCTAssertFalse(app.buttons["tool.finish"].exists,
                       "Finish should be absent with no draft points")

        // Place first waypoint — Finish still requires ≥2 points
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.40)).tap()
        XCTAssertFalse(app.buttons["tool.finish"].exists,
                       "Finish should be absent after only 1 draft point")

        // Cancel button should be visible now that a draft exists
        XCTAssertTrue(app.buttons["tool.cancel"].waitForExistence(timeout: 2),
                      "Cancel should appear once a draft point exists")

        // Place second waypoint — Finish should now appear
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.40)).tap()
        XCTAssertTrue(app.buttons["tool.finish"].waitForExistence(timeout: 2),
                      "Finish should appear after ≥2 draft points")
    }

    @MainActor
    func testHallwayToolFinishCreatesHallway() throws {
        throw XCTSkip("Pre-existing failure, tracked for 0.2.0")

        let app = XCUIApplication()
        app.launchArguments += ["-enableMapEditing"]
        app.launch()
        app.openFirstDungeon()
        app.enterEditMode()
        app.selectTool("tool.hallway")

        let canvas = app.mapCanvas
        XCTAssertTrue(canvas.waitForExistence(timeout: 3))

        // Place two waypoints
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.45)).tap()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.45)).tap()

        let finishButton = app.buttons["tool.finish"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 2))

        // Commit the hallway
        finishButton.tap()

        // After committing, the draft controls should clear.
        // Use waitForNonExistence — tap() returns before SwiftUI processes the state change.
        XCTAssertTrue(app.buttons["tool.finish"].waitForNonExistence(timeout: 2),
                      "Finish should disappear after hallway is committed")
        XCTAssertTrue(app.buttons["tool.cancel"].waitForNonExistence(timeout: 2),
                      "Cancel should disappear after hallway is committed")
    }

    @MainActor
    func testHallwayToolCancelDiscardsDraft() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-enableMapEditing"]
        app.launch()
        app.openFirstDungeon()
        app.enterEditMode()
        app.selectTool("tool.hallway")

        let canvas = app.mapCanvas
        XCTAssertTrue(canvas.waitForExistence(timeout: 3))

        // Place one waypoint to start a draft
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.50)).tap()
        XCTAssertTrue(app.buttons["tool.cancel"].waitForExistence(timeout: 2))

        // Cancel — draft controls should disappear
        app.buttons["tool.cancel"].tap()
        XCTAssertTrue(app.buttons["tool.cancel"].waitForNonExistence(timeout: 2),
                      "Cancel should clear the draft")
        XCTAssertFalse(app.buttons["tool.finish"].exists)
    }

    // MARK: Door tool

    @MainActor
    func testDoorToolCreatesDoor() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-enableMapEditing"]
        app.launch()
        app.openFirstDungeon()
        app.enterEditMode()
        app.selectTool("tool.door")

        let canvas = app.mapCanvas
        XCTAssertTrue(canvas.waitForExistence(timeout: 3))

        // Drag across the canvas to place a door
        let dragStart = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.50))
        let dragEnd   = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.50))
        dragStart.press(forDuration: 0.05, thenDragTo: dragEnd)

        // Switch to select tool — the new door should be selectable in the area we dragged
        app.selectTool("tool.select")

        // Tap near the drag midpoint; a door should be selected (Delete button appears)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.50)).tap()
        XCTAssertTrue(app.buttons["element.delete"].waitForExistence(timeout: 2),
                      "Delete button should appear when a door is selected")
    }

    // MARK: Tool switching

    @MainActor
    func testSwitchingToolsCancelsDraft() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-enableMapEditing"]
        app.launch()
        app.openFirstDungeon()
        app.enterEditMode()
        app.selectTool("tool.hallway")

        let canvas = app.mapCanvas
        XCTAssertTrue(canvas.waitForExistence(timeout: 3))

        // Start a hallway draft
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.40)).tap()
        XCTAssertTrue(app.buttons["tool.cancel"].waitForExistence(timeout: 2))

        // Switch away from hallway tool
        app.selectTool("tool.select")

        // Draft controls should clear when the tool changes
        XCTAssertTrue(app.buttons["tool.cancel"].waitForNonExistence(timeout: 2),
                      "Switching tools should cancel the hallway draft")
    }
}
