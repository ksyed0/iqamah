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

/// Renders a SwiftUI view at scale 1.0 via ImageRenderer so the reference PNG
/// is reproducible across Retina Macs and headless 1× CI runners alike.
/// MUST be called from the main actor (use `await MainActor.run` in async tests).
@MainActor
private func renderAt1x(_ view: some View, width: CGFloat, height: CGFloat, dark: Bool) -> NSImage? {
    let sized = view
        .frame(width: width, height: height)
        .environment(\.colorScheme, dark ? .dark : .light)
        .background(dark ? Color(white: 0.12) : Color(white: 0.97))
    let renderer = ImageRenderer(content: sized)
    renderer.scale = 1.0
    return renderer.nsImage
}

// MARK: - AC-0309: MoonPhaseView

final class MoonPhaseSnapshotTests: XCTestCase {
    // New crescent (phase ≈ 0.05) — light + dark
    func testNewCrescent_light() async throws {
        let image = try await MainActor.run {
            try XCTUnwrap(renderAt1x(MoonPhaseView(phase: 0.05, size: 80), width: 80, height: 80, dark: false))
        }
        assertSnapshot(of: image, as: .image(precision: 0.95), named: "newCrescent-light",
                       file: #file, testName: #function)
    }

    func testNewCrescent_dark() async throws {
        let image = try await MainActor.run {
            try XCTUnwrap(renderAt1x(MoonPhaseView(phase: 0.05, size: 80), width: 80, height: 80, dark: true))
        }
        assertSnapshot(of: image, as: .image(precision: 0.95), named: "newCrescent-dark",
                       file: #file, testName: #function)
    }

    // Full moon (phase = 0.5) — light + dark
    func testFullMoon_light() async throws {
        let image = try await MainActor.run {
            try XCTUnwrap(renderAt1x(MoonPhaseView(phase: 0.50, size: 80), width: 80, height: 80, dark: false))
        }
        assertSnapshot(of: image, as: .image(precision: 0.95), named: "fullMoon-light",
                       file: #file, testName: #function)
    }

    func testFullMoon_dark() async throws {
        let image = try await MainActor.run {
            try XCTUnwrap(renderAt1x(MoonPhaseView(phase: 0.50, size: 80), width: 80, height: 80, dark: true))
        }
        assertSnapshot(of: image, as: .image(precision: 0.95), named: "fullMoon-dark",
                       file: #file, testName: #function)
    }

    // Waning crescent (phase ≈ 0.82) — light + dark
    func testWaningCrescent_light() async throws {
        let image = try await MainActor.run {
            try XCTUnwrap(renderAt1x(MoonPhaseView(phase: 0.82, size: 80), width: 80, height: 80, dark: false))
        }
        assertSnapshot(of: image, as: .image(precision: 0.95), named: "waningCrescent-light",
                       file: #file, testName: #function)
    }

    func testWaningCrescent_dark() async throws {
        let image = try await MainActor.run {
            try XCTUnwrap(renderAt1x(MoonPhaseView(phase: 0.82, size: 80), width: 80, height: 80, dark: true))
        }
        assertSnapshot(of: image, as: .image(precision: 0.95), named: "waningCrescent-dark",
                       file: #file, testName: #function)
    }
}

// MARK: - AC-0310: QiblahCompassView

final class QiblahCompassSnapshotTests: XCTestCase {
    // Toronto → Makkah bearing 58.3° at two sizes
    func testCompass_320pt() async throws {
        let image = try await MainActor.run {
            try XCTUnwrap(renderAt1x(QiblahCompassView(diameter: 320, bearing: 58.3),
                                     width: 320, height: 320, dark: false))
        }
        assertSnapshot(of: image, as: .image(precision: 0.92), named: "compass-320",
                       file: #file, testName: #function)
    }

    func testCompass_600pt() async throws {
        let image = try await MainActor.run {
            try XCTUnwrap(renderAt1x(QiblahCompassView(diameter: 600, bearing: 58.3),
                                     width: 600, height: 600, dark: false))
        }
        assertSnapshot(of: image, as: .image(precision: 0.92), named: "compass-600",
                       file: #file, testName: #function)
    }
}

// MARK: - AC-0311: PrayerTimesTable (macOS)

final class PrayerTimesTableSnapshotTests: XCTestCase {
    /// Six-row prayer table with pinned Toronto data.
    /// Which prayer is highlighted as "NEXT" depends on the current clock;
    /// this test catches STRUCTURAL regressions (layout, fonts, spacing) rather
    /// than specific highlighted states.
    func testPrayerTimesTable_dark() async throws {
        let view = PrayerTimesTable(prayerTimes: fixedPrayerTimes(), timezone: toronto)
            .frame(width: 620, height: 380)
            .padding(10)
        let image = try await MainActor.run {
            try XCTUnwrap(renderAt1x(view, width: 640, height: 400, dark: true))
        }
        assertSnapshot(of: image, as: .image(precision: 0.90), named: nil,
                       file: #file, testName: #function)
    }
}

// MARK: - AC-0312 & AC-0313: iOS-only views

//
// HilalExportCard and PrayerRowMobileView are #if os(iOS) types and cannot
// be rendered in this macOS test target.  CI wiring deferred to US-0067.
