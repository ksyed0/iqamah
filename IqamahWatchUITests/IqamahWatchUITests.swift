// IqamahWatchUITests.swift
// AC-0336–AC-0342 (US-0068, EPIC-0015)
//
// watchOS XCUITest suite — tab navigation, prayer list, settings, Qibla.
//
// Note on Digital Crown: XCUITest cannot programmatically rotate the Crown;
// tests are limited to verifying views load and key elements are accessible.
// Tab switching uses swipeLeft() / swipeRight() (page-style TabView).
//
// Launch argument "--uitesting" pre-seeds Toronto/ISNA and marks location
// setup as ready so the app starts directly on the Times tab.
// Total timing budget: ≤ 60 seconds aggregate (AC-0342).

import XCTest

// MARK: - IqamahWatchUITests

final class IqamahWatchUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        // Give the app time to reach the prayer times tab
        _ = app.staticTexts["Fajr"].waitForExistence(timeout: 10)
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - AC-0337: Times tab shows at least one prayer row

    func testPrayerTimesTabLoads() {
        // The first tab is PrayerTimesTab — verify at least one prayer name and a time
        XCTAssertTrue(
            app.staticTexts["Fajr"].waitForExistence(timeout: 5),
            "Times tab should show Fajr after launch with --uitesting"
        )
        // At least one time string should be visible (non-empty, formatted as HH:mm or h:mm)
        let timeTexts = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '^[0-9]{1,2}:[0-9]{2}( [AP]M)?$'")
        )
        XCTAssertTrue(
            timeTexts.firstMatch.waitForExistence(timeout: 3),
            "A time string should be visible on the Times tab"
        )
    }

    // MARK: - AC-0338: All visible prayers present (Sunrise may be off-screen)

    func testAllVisiblePrayersPresent() {
        let requiredPrayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        for prayer in requiredPrayers {
            XCTAssertTrue(
                app.staticTexts[prayer].waitForExistence(timeout: 4),
                "\(prayer) should be accessible on the Times tab"
            )
        }
    }

    // MARK: - AC-0339: Settings tab has Location section and GPS button

    func testSettingsTabLoads() {
        // Navigate to the third tab (Settings) with two left-swipes
        app.swipeLeft()
        app.swipeLeft()

        XCTAssertTrue(
            app.staticTexts["Location"].waitForExistence(timeout: 4),
            "Settings tab should show a 'Location' section header"
        )
        XCTAssertTrue(
            app.buttons["Update via GPS"].waitForExistence(timeout: 3),
            "'Update via GPS' button should be present in the Settings tab"
        )
    }

    // MARK: - AC-0340: Set City Manually navigation link visible when DB loaded

    func testSetCityManuallyNavigationVisible() {
        app.swipeLeft()
        app.swipeLeft()

        XCTAssertTrue(
            app.buttons["Set City Manually"].waitForExistence(timeout: 5),
            "'Set City Manually' navigation link should appear once city database is loaded"
        )
    }

    // MARK: - AC-0341: Qibla tab shows a compass element

    func testQiblaTabLoads() {
        // Navigate to the second tab (Qibla) with one left-swipe
        app.swipeLeft()

        // The compass ZStack has the accessibility identifier "qiblahCompass"
        // In watchOS XCUITest, it appears as an "other" element.
        let compass = app.otherElements["qiblahCompass"]
        XCTAssertTrue(
            compass.waitForExistence(timeout: 5),
            "Qiblah compass should be visible on the Qibla tab"
        )
    }
}
