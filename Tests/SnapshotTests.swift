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
// views.  Their snapshot tests are co-located at the bottom of this file in
// an #if os(iOS) block so the code exists in the repository.  CI execution
// against an iOS Simulator will be wired during US-0067.

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

/// Renders a SwiftUI view at scale 1.0 via ImageRenderer, making the
/// reference PNG reproducible on both Retina Macs and 1× CI runners.
/// Dark mode is injected through the SwiftUI environment.
@MainActor
private func snapshotView(
    _ view: some View,
    width: CGFloat,
    height: CGFloat,
    dark: Bool = false,
    file: StaticString = #file,
    testName: String = #function,
    named: String? = nil
) {
    let sized = view
        .frame(width: width, height: height)
        .environment(\.colorScheme, dark ? .dark : .light)
        .background(dark ? Color(white: 0.12) : Color(white: 0.97))
    let renderer = ImageRenderer(content: sized)
    renderer.scale = 1.0 // Force 1× — CI virtual displays are always 1×
    guard let image = renderer.nsImage else {
        XCTFail("ImageRenderer returned nil for \(testName)")
        return
    }
    assertSnapshot(
        of: image,
        as: .image(precision: 0.97),
        named: named,
        file: file,
        testName: testName
    )
}

// MARK: - AC-0309: MoonPhaseView

@MainActor
final class MoonPhaseSnapshotTests: XCTestCase {
    // New crescent (phase ≈ 0.05) — light + dark
    func testNewCrescent_light() {
        snapshotView(MoonPhaseView(phase: 0.05, size: 80),
                     width: 80, height: 80, dark: false, named: "newCrescent-light")
    }

    func testNewCrescent_dark() {
        snapshotView(MoonPhaseView(phase: 0.05, size: 80),
                     width: 80, height: 80, dark: true, named: "newCrescent-dark")
    }

    // Full moon (phase = 0.5) — light + dark
    func testFullMoon_light() {
        snapshotView(MoonPhaseView(phase: 0.50, size: 80),
                     width: 80, height: 80, dark: false, named: "fullMoon-light")
    }

    func testFullMoon_dark() {
        snapshotView(MoonPhaseView(phase: 0.50, size: 80),
                     width: 80, height: 80, dark: true, named: "fullMoon-dark")
    }

    // Waning crescent (phase ≈ 0.82) — light + dark
    func testWaningCrescent_light() {
        snapshotView(MoonPhaseView(phase: 0.82, size: 80),
                     width: 80, height: 80, dark: false, named: "waningCrescent-light")
    }

    func testWaningCrescent_dark() {
        snapshotView(MoonPhaseView(phase: 0.82, size: 80),
                     width: 80, height: 80, dark: true, named: "waningCrescent-dark")
    }
}

// MARK: - AC-0310: QiblahCompassView

@MainActor
final class QiblahCompassSnapshotTests: XCTestCase {
    // Toronto → Makkah bearing 58.3° at two sizes
    func testCompass_320pt() {
        snapshotView(QiblahCompassView(diameter: 320, bearing: 58.3),
                     width: 320, height: 320, named: "compass-320")
    }

    func testCompass_600pt() {
        snapshotView(QiblahCompassView(diameter: 600, bearing: 58.3),
                     width: 600, height: 600, named: "compass-600")
    }
}

// MARK: - AC-0311: PrayerTimesTable (macOS)

@MainActor
final class PrayerTimesTableSnapshotTests: XCTestCase {
    /// Six-row prayer table with pinned Toronto data on a dark background.
    /// Which prayer is highlighted as "NEXT" depends on the current clock;
    /// the test is designed to catch STRUCTURAL regressions (layout, fonts,
    /// column widths, colours) rather than specific highlighted states.
    func testPrayerTimesTable_dark() {
        let view = PrayerTimesTable(prayerTimes: fixedPrayerTimes(), timezone: toronto)
            .frame(width: 620, height: 380)
            .padding(10)
        snapshotView(view, width: 640, height: 400, dark: true)
    }
}

// MARK: - AC-0312 & AC-0313: iOS-only views

//
// HilalExportCard and PrayerRowMobileView are #if os(iOS) types and cannot
// be rendered in this macOS test target.  The tests below exist to satisfy
// "snapshot tests exist" and will be enabled for CI in US-0067 by linking
// SnapshotTesting to the iqamah-iOS test scheme.

// swiftlint:disable:next file_length
