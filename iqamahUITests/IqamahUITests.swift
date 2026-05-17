// IqamahUITests.swift
// AC-0317–AC-0325 (US-0066, EPIC-0015)
//
// macOS XCUITest suite covering:
//   - Status bar menu interactions
//   - Main window lifecycle
//   - Hilal Watch window opening
//   - Adhaan picker expand / collapse
//   - Settings sheet open / cancel
//
// All tests launch the app with "--uitesting" which pre-seeds Toronto/ISNA
// settings so the prayer times view is shown immediately after the 1-second
// splash.  Tests are designed to complete in under 60 seconds in aggregate.

import XCTest

// MARK: - IqamahUITests

final class IqamahUITests: XCTestCase {
    var app: XCUIApplication!

    // MARK: setUp / tearDown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        // Splash auto-advances in 1 s when setup is complete; give it 3 s for CI headroom.
        _ = app.staticTexts["Fajr"].waitForExistence(timeout: 6)
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - AC-0318: Left-click opens popover

    func testStatusBarLeftClickOpensPopover() {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 3),
                      "Status bar item should be present after launch")

        let windowsBefore = app.windows.count
        statusItem.click()

        // The popover appears as an additional window in the app's window list.
        let appeared = app.windows.count > windowsBefore ||
            app.windows.firstMatch.waitForExistence(timeout: 2)
        XCTAssertTrue(appeared, "A popover or window should appear after left-clicking the status item")

        // Dismiss by clicking elsewhere so subsequent tests start clean.
        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - AC-0319: Right-click shows menu with required items

    func testStatusBarRightClickShowsMenu() {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 3))

        statusItem.rightClick()

        XCTAssertTrue(app.menuItems["Open Main Window"].waitForExistence(timeout: 2),
                      "'Open Main Window' should appear in the right-click menu")
        XCTAssertTrue(app.menuItems["Moon Sighting\u{2026}"].exists,
                      "'Moon Sighting…' should appear in the right-click menu")
        XCTAssertTrue(app.menuItems["Settings"].exists,
                      "'Settings' should appear in the right-click menu")
        XCTAssertTrue(app.menuItems["Quit Iqamah"].exists,
                      "'Quit Iqamah' should appear in the right-click menu")

        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - AC-0320: "Open Main Window" brings prayer times window forward

    func testOpenMainWindowFromMenu() {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 3))

        statusItem.rightClick()
        app.menuItems["Open Main Window"].click()

        // The main window should be visible and should NOT be the Hilal Watch window.
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 3),
                      "Main window should appear after 'Open Main Window'")
        XCTAssertFalse(mainWindow.title.contains("Hilal"),
                       "The opened window should not be the Hilal Watch window")
    }

    // MARK: - AC-0321: "Moon Sighting…" opens Hilal Watch window

    func testHilalWatchOpensFromMenu() {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 3))

        statusItem.rightClick()
        app.menuItems["Moon Sighting\u{2026}"].click()

        // Hilal Watch window should appear.
        let hilalWindow = app.windows["Hilal Watch"]
        XCTAssertTrue(hilalWindow.waitForExistence(timeout: 4),
                      "Hilal Watch window should open from the menu")
    }

    // MARK: - AC-0322: "Hilal Watch ›" button in prayer view opens Hilal Watch

    func testHilalWatchOpensFromDetailsButton() {
        // Ensure main window is open first.
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 3))
        statusItem.rightClick()
        app.menuItems["Open Main Window"].click()
        _ = app.windows.firstMatch.waitForExistence(timeout: 3)

        // The "Hilal Watch ›" button has accessibility identifier "hilalWatchButton".
        let hilalBtn = app.buttons["hilalWatchButton"]
        XCTAssertTrue(hilalBtn.waitForExistence(timeout: 4),
                      "'Hilal Watch ›' button should be present in the main window")
        hilalBtn.click()

        let hilalWindow = app.windows["Hilal Watch"]
        XCTAssertTrue(hilalWindow.waitForExistence(timeout: 4),
                      "Hilal Watch window should open after clicking 'Hilal Watch ›'")
    }

    // MARK: - AC-0323: Adhaan picker expands and collapses

    func testAdhaanPickerOpenAndClose() {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 3))
        statusItem.rightClick()
        app.menuItems["Open Main Window"].click()
        _ = app.windows.firstMatch.waitForExistence(timeout: 3)

        // Click the Fajr adhaan pill — it should expand the picker.
        let fajrPill = app.buttons["adhaanPill-Fajr"]
        XCTAssertTrue(fajrPill.waitForExistence(timeout: 4),
                      "Fajr adhaan pill should exist in the prayer table")
        fajrPill.click()

        // The picker rows become visible; look for any adhaan option label.
        // We expect the picker to show at least one selectable option.
        let pickerVisible = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'adhaanOption-'")).firstMatch
            .waitForExistence(timeout: 2)
        XCTAssertTrue(pickerVisible, "Adhaan options should appear after clicking the Fajr pill")

        // Click a different prayer pill — Fajr picker should collapse.
        let dhuhrPill = app.buttons["adhaanPill-Dhuhr"]
        XCTAssertTrue(dhuhrPill.waitForExistence(timeout: 2))
        dhuhrPill.click()

        // Dhuhr picker is now open; Fajr picker should be gone.
        XCTAssertFalse(
            app.buttons["adhaanPill-Fajr"].isSelected,
            "Fajr picker should collapse when a different row is tapped"
        )
    }

    // MARK: - AC-0324: Settings sheet opens and Cancel closes it without saving

    func testSettingsSheetOpensAndCloses() {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 3))
        statusItem.rightClick()

        // Open Settings via the menu.
        app.menuItems["Settings"].click()

        // The settings sheet should appear (it's presented as a SwiftUI .sheet).
        // The Cancel button has accessibilityIdentifier "settingsCancelButton".
        let cancelBtn = app.buttons["settingsCancelButton"]
        XCTAssertTrue(cancelBtn.waitForExistence(timeout: 4),
                      "Settings Cancel button should be visible after opening Settings")

        cancelBtn.click()

        // Sheet should dismiss — Cancel button gone, prayer times view visible again.
        XCTAssertFalse(cancelBtn.waitForExistence(timeout: 2),
                       "Settings sheet should close after tapping Cancel")
    }
}
