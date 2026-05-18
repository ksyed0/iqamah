// Tests/SnapshotTests.swift
// AC-0308–AC-0316 (US-0065, EPIC-0015)
//
// Snapshot tests for key Iqamah views.  Reference images live alongside this
// file in Tests/__Snapshots__/ and are committed to the repository.
//
// ── Running ──────────────────────────────────────────────────────────────────
// Normal:  xcodebuild test -scheme iqamah -destination 'platform=macOS'
//          (run automatically by PR CI and nightly; diffs = test failure)
// Record:  bash scripts/update-snapshots.sh
//
// ── Platform notes ───────────────────────────────────────────────────────────
// AC-0309–AC-0311 (MoonPhaseView, QiblahCompassView, PrayerTimesTable)
//   run in this macOS test target.
//
// AC-0312 (HilalExportCard) and AC-0313 (PrayerRowMobileView) are iOS-only
// views.  Their snapshot tests will be wired into the iqamah-iOS scheme
// during US-0067.

import AppKit
import IqamahCore
import SnapshotTesting
import SwiftUI
import XCTest
@testable import iqamah

// MARK: - Helpers

/// Fixed prayer times (Toronto, ISNA, 21 Jun 2024 — summer solstice).
/// Fajr 05:15 · Sunrise 06:38 · Dhuhr 12:11 · Asr 15:31 · Maghrib 17:44 · Isha 19:07
private func fixedPrayerTimes() -> PrayerTimes {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/Toronto")!
    let ref = cal.date(from: DateComponents(year: 2024, month: 6, day: 21))!
    func at(_ h: Int, _ m: Int) -> Date {
        cal.date(bySettingHour: h, minute: m, second: 0, of: ref)!
    }
    return PrayerTimes(
        fajr: at(5, 15), sunrise: at(6, 38), dhuhr: at(12, 11),
        asr: at(15, 31), maghrib: at(17, 44), isha: at(19, 7), date: ref
    )
}

private let toronto = TimeZone(identifier: "America/Toronto")!

/// Renders a SwiftUI view at exactly scale 1.0 so the reference PNG is
/// identical across Retina Macs and CI's 1× virtual display.
///
/// Uses `MainActor.assumeIsolated` rather than `await MainActor.run` to avoid
/// the deadlock that occurs inside BUNDLE_LOADER tests: those tests run on the
/// NSApplication main run loop, which cannot be re-entered by an async
/// continuation.  XCTest always calls synchronous test methods on the main
/// thread, so `assumeIsolated` is safe here.
private func renderAt1x(_ view: some View, width: CGFloat, height: CGFloat, dark: Bool) -> NSImage? {
    MainActor.assumeIsolated {
        let sized = view
            .frame(width: width, height: height)
            .environment(\.colorScheme, dark ? .dark : .light)
            .background(dark ? Color(white: 0.12) : Color(white: 0.97))
        let renderer = ImageRenderer(content: sized)
        renderer.scale = 1.0
        return renderer.nsImage
    }
}

// MARK: - AC-0309: MoonPhaseView

final class MoonPhaseSnapshotTests: XCTestCase {
    private func snap(_ view: some View, width: CGFloat, height: CGFloat, dark: Bool,
                      precision: Float, named: String,
                      file: StaticString = #file, testName: String = #function) {
        guard let image = renderAt1x(view, width: width, height: height, dark: dark) else {
            XCTFail("renderAt1x returned nil", file: file)
            return
        }
        assertSnapshot(of: image, as: .image(precision: precision),
                       named: named, file: file, testName: testName)
    }

    func testNewCrescent_light() {
        snap(MoonPhaseView(phase: 0.05, size: 80), width: 80, height: 80, dark: false,
             precision: 0.95, named: "newCrescent-light")
    }

    func testNewCrescent_dark() {
        snap(MoonPhaseView(phase: 0.05, size: 80), width: 80, height: 80, dark: true,
             precision: 0.95, named: "newCrescent-dark")
    }

    func testFullMoon_light() {
        snap(MoonPhaseView(phase: 0.50, size: 80), width: 80, height: 80, dark: false,
             precision: 0.95, named: "fullMoon-light")
    }

    func testFullMoon_dark() {
        snap(MoonPhaseView(phase: 0.50, size: 80), width: 80, height: 80, dark: true,
             precision: 0.95, named: "fullMoon-dark")
    }

    func testWaningCrescent_light() {
        snap(MoonPhaseView(phase: 0.82, size: 80), width: 80, height: 80, dark: false,
             precision: 0.95, named: "waningCrescent-light")
    }

    func testWaningCrescent_dark() {
        snap(MoonPhaseView(phase: 0.82, size: 80), width: 80, height: 80, dark: true,
             precision: 0.95, named: "waningCrescent-dark")
    }
}

// MARK: - AC-0310: QiblahCompassView

final class QiblahCompassSnapshotTests: XCTestCase {
    // Toronto → Makkah bearing 58.3° at two sizes
    func testCompass_320pt() {
        guard let image = renderAt1x(QiblahCompassView(diameter: 320, bearing: 58.3),
                                     width: 320, height: 320, dark: false) else {
            XCTFail("renderAt1x returned nil"); return
        }
        assertSnapshot(of: image, as: .image(precision: 0.92), named: "compass-320")
    }

    func testCompass_600pt() {
        guard let image = renderAt1x(QiblahCompassView(diameter: 600, bearing: 58.3),
                                     width: 600, height: 600, dark: false) else {
            XCTFail("renderAt1x returned nil"); return
        }
        assertSnapshot(of: image, as: .image(precision: 0.92), named: "compass-600")
    }
}

// MARK: - AC-0311: PrayerTimesTable (macOS)

final class PrayerTimesTableSnapshotTests: XCTestCase {
    /// Six-row prayer table with pinned Toronto data.
    /// Which prayer is highlighted as "NEXT" depends on the current clock;
    /// this test catches STRUCTURAL regressions (layout, fonts, spacing) rather
    /// than specific highlighted states.
    func testPrayerTimesTable_dark() {
        let view = PrayerTimesTable(prayerTimes: fixedPrayerTimes(), timezone: toronto)
            .frame(width: 620, height: 380)
            .padding(10)
        guard let image = renderAt1x(view, width: 640, height: 400, dark: true) else {
            XCTFail("renderAt1x returned nil"); return
        }
        assertSnapshot(of: image, as: .image(precision: 0.90))
    }
}

// MARK: - AC-0312 & AC-0313: iOS-only views

//
// HilalExportCard and PrayerRowMobileView are #if os(iOS) types and cannot
// be rendered in this macOS test target.  CI wiring deferred to US-0067.
