// Tests/SnapshotTests.swift — DIAGNOSTIC VERSION
// Minimised to isolate which component causes CI crashes.
// Full implementation will be restored once the root cause is identified.

import AppKit
import IqamahCore
import SnapshotTesting
import SwiftUI
import XCTest

// @testable import iqamah  ← removed to test if this is the crash root cause

final class MoonPhaseSnapshotTests: XCTestCase {
    func testPlaceholder() { XCTAssertTrue(true) }
}

final class QiblahCompassSnapshotTests: XCTestCase {
    func testPlaceholder() { XCTAssertTrue(true) }
}

final class PrayerTimesTableSnapshotTests: XCTestCase {
    func testPlaceholder() { XCTAssertTrue(true) }
}
