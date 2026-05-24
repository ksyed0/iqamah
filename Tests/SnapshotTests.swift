// Tests/SnapshotTests.swift
// AC-0308–AC-0316 (US-0065, EPIC-0015)
//
// Snapshot tests for key Iqamah views.  Reference images live alongside this
// file in Tests/__Snapshots__/ and are committed to the repository.
//
// ── Running ──────────────────────────────────────────────────────────────────
// Normal:  xcodebuild test -scheme iqamah -destination 'platform=macOS'
// Record:  bash scripts/update-snapshots.sh
//
// ── Threading model ──────────────────────────────────────────────────────────
// Xcode 26 / Swift 6 XCTest runs test methods on the cooperative thread pool
// (NOT the main thread). All AppKit / SwiftUI rendering must be dispatched to
// DispatchQueue.main explicitly; the assertions then happen back on the test
// thread via XCTestExpectation.
//
// ── Why no @testable import ──────────────────────────────────────────────────
// @testable import iqamah triggers a Swift 6 runtime actor-isolation crash
// during iqamah module initialization.  MoonPhaseView, QiblahCompassView,
// and PrayerTimesTable are declared `public` so a plain `import iqamah` works.
//
// ── Platform notes ───────────────────────────────────────────────────────────
// AC-0309–AC-0311 run in this macOS target.
// AC-0312/0313 (iOS-only) deferred to US-0067.

import AppKit
import IqamahCore
import SnapshotTesting
import SwiftUI
import XCTest
import iqamah // public types only

// MARK: - Helpers

/// Fixed prayer times (Toronto, ISNA, 21 Jun 2024 — summer solstice).
private func fixedPrayerTimes() -> PrayerTimes {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/Toronto")!
    let ref = cal.date(from: DateComponents(year: 2024, month: 6, day: 21))!
    func at(_ h: Int, _ m: Int) -> Date {
        cal.date(bySettingHour: h, minute: m, second: 0, of: ref)!
    }
    return PrayerTimes(fajr: at(5, 15), sunrise: at(6, 38), dhuhr: at(12, 11),
                       asr: at(15, 31), maghrib: at(17, 44), isha: at(19, 7), date: ref)
}

private let toronto = TimeZone(identifier: "America/Toronto")!

/// Renders `view` on the MAIN QUEUE at 1× scale (1 logical point = 1 pixel)
/// and calls `assertion` with the resulting `NSImage` on the main queue.
/// Executes synchronously from the caller's perspective using XCTestExpectation.
private func onMain(in test: XCTestCase,
                    _ body: @escaping @Sendable (XCTestExpectation) -> Void) {
    let exp = test.expectation(description: "main-queue rendering")
    DispatchQueue.main.async { body(exp) }
    test.waitForExpectations(timeout: 10)
}

/// Render a SwiftUI view into an NSImage at exactly 1× scale using SwiftUI's
/// native `ImageRenderer` (macOS 13+). Triggers a full layout pass so Text,
/// Toggle, Form, and other content-bearing views render their actual content
/// rather than coming back empty (which `NSHostingView.draw(_:)` produces
/// when no window is attached).
/// MUST be called from DispatchQueue.main — use `onMain(in:)` to ensure this.
@available(macOS 13.0, *)
private func render1xImageRenderer(_ view: some View, width: CGFloat, height: CGFloat, dark: Bool) -> NSImage? {
    // Caller dispatches via `onMain`, so we're already on the main queue.
    // `ImageRenderer.nsImage` is @MainActor; assume isolation to silence the
    // compiler check.
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

/// Render a SwiftUI view into an NSImage at exactly 1× scale.
/// MUST be called from DispatchQueue.main — use `onMain(in:)` to ensure this.
private func render1x(_ view: some View, width: CGFloat, height: CGFloat, dark: Bool) -> NSImage? {
    let sized = view
        .frame(width: width, height: height)
        .environment(\.colorScheme, dark ? .dark : .light)
        .background(dark ? Color(white: 0.12) : Color(white: 0.97))
    let hosting = NSHostingView(rootView: sized)
    hosting.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)

    // Create an explicit 1-point-per-pixel bitmap; the view has no window so
    // bitmapImageRepForCachingDisplay uses the screen scale factor. Creating
    // the bitmap rep manually bypasses that and forces 1× regardless of display.
    guard let bmp = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: Int(width), pixelsHigh: Int(height),
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    bmp.size = NSSize(width: width, height: height) // 1pt = 1px
    guard let ctx = NSGraphicsContext(bitmapImageRep: bmp) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    hosting.draw(hosting.bounds)
    NSGraphicsContext.restoreGraphicsState()
    let image = NSImage(size: NSSize(width: width, height: height))
    image.addRepresentation(bmp)
    return image
}

// MARK: - AC-0309: MoonPhaseView

final class MoonPhaseSnapshotTests: XCTestCase {
    func testNewCrescent_light() {
        onMain(in: self) { exp in
            if let img = render1x(MoonPhaseView(phase: 0.05, size: 80), width: 80, height: 80, dark: false) {
                assertSnapshot(of: img, as: .image(precision: 0.95), named: "newCrescent-light")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testNewCrescent_dark() {
        onMain(in: self) { exp in
            if let img = render1x(MoonPhaseView(phase: 0.05, size: 80), width: 80, height: 80, dark: true) {
                assertSnapshot(of: img, as: .image(precision: 0.95), named: "newCrescent-dark")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testFullMoon_light() {
        onMain(in: self) { exp in
            if let img = render1x(MoonPhaseView(phase: 0.50, size: 80), width: 80, height: 80, dark: false) {
                assertSnapshot(of: img, as: .image(precision: 0.95), named: "fullMoon-light")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testFullMoon_dark() {
        onMain(in: self) { exp in
            if let img = render1x(MoonPhaseView(phase: 0.50, size: 80), width: 80, height: 80, dark: true) {
                assertSnapshot(of: img, as: .image(precision: 0.95), named: "fullMoon-dark")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testWaningCrescent_light() {
        onMain(in: self) { exp in
            if let img = render1x(MoonPhaseView(phase: 0.82, size: 80), width: 80, height: 80, dark: false) {
                assertSnapshot(of: img, as: .image(precision: 0.95), named: "waningCrescent-light")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testWaningCrescent_dark() {
        onMain(in: self) { exp in
            if let img = render1x(MoonPhaseView(phase: 0.82, size: 80), width: 80, height: 80, dark: true) {
                assertSnapshot(of: img, as: .image(precision: 0.95), named: "waningCrescent-dark")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }
}

// MARK: - AC-0310: QiblahCompassView

final class QiblahCompassSnapshotTests: XCTestCase {
    func testCompass_320pt() {
        onMain(in: self) { exp in
            if let img = render1x(QiblahCompassView(diameter: 320, bearing: 58.3), width: 320, height: 320, dark: false) {
                assertSnapshot(of: img, as: .image(precision: 0.92), named: "compass-320")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testCompass_600pt() {
        onMain(in: self) { exp in
            if let img = render1x(QiblahCompassView(diameter: 600, bearing: 58.3), width: 600, height: 600, dark: false) {
                assertSnapshot(of: img, as: .image(precision: 0.92), named: "compass-600")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }
}

// MARK: - AC-0311: PrayerTimesTable (macOS)

final class PrayerTimesTableSnapshotTests: XCTestCase {
    func testPrayerTimesTable_dark() {
        let times = fixedPrayerTimes()
        onMain(in: self) { exp in
            let view = PrayerTimesTable(prayerTimes: times, timezone: toronto)
                .frame(width: 620, height: 380).padding(10)
            if let img = render1x(view, width: 640, height: 400, dark: true) {
                assertSnapshot(of: img, as: .image(precision: 0.90))
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }
}

// MARK: - AC-0312 & AC-0313: iOS-only views

//
// HilalExportCard and PrayerRowMobileView are #if os(iOS) types.
// CI wiring deferred to US-0067.

// MARK: - Fasting helpers

/// A fixed reference date used for Fasting banner snapshots so the formatted
/// times in the rendered image are deterministic across machines / locales.
private func fastingFixedDate() -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = toronto
    return cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
}

private func fastingFajr() -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = toronto
    return cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 4, minute: 30))!
}

private func fastingMaghrib() -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = toronto
    return cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 20, minute: 30))!
}

/// Build a Fasting banner ready for rendering at fixed size 320×96.
private func fastingBannerView(trigger: FastingTriggerKind?,
                               prohibition: ProhibitedDay?) -> some View {
    let state = FastingDayState(
        isActive: prohibition == nil,
        trigger: trigger,
        prohibition: prohibition,
        date: fastingFixedDate()
    )
    return FastingBanner(
        state: state,
        fajrTime: fastingFajr(),
        maghribTime: fastingMaghrib(),
        isShiaMethod: false
    )
    .padding(8)
}

/// Build a fresh, isolated SettingsManager backed by a unique in-memory
/// UserDefaults suite so tests never read or mutate user state.
private func makeFastingSettings(enabled: Bool, shia: Bool, suiteName: String) -> SettingsManager {
    let suite = UserDefaults(suiteName: suiteName)!
    suite.removePersistentDomain(forName: suiteName)
    let mgr = SettingsManager(userDefaults: suite)
    mgr.calculationMethod = shia ? .jafari : .muslimWorldLeague
    var s = mgr.fastingModeSettings
    s.enabled = enabled
    mgr.fastingModeSettings = s
    return mgr
}

// MARK: - FastingBanner snapshots

final class FastingBannerSnapshotTests: XCTestCase {
    func testActiveRamadan_light() {
        onMain(in: self) { exp in
            let view = fastingBannerView(trigger: .autoRamadan, prohibition: nil)
            if let img = render1xImageRenderer(view, width: 320, height: 96, dark: false) {
                assertSnapshot(of: img, as: .image(precision: 0.93), named: "activeRamadan-light")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testActiveRamadan_dark() {
        onMain(in: self) { exp in
            let view = fastingBannerView(trigger: .autoRamadan, prohibition: nil)
            if let img = render1xImageRenderer(view, width: 320, height: 96, dark: true) {
                assertSnapshot(of: img, as: .image(precision: 0.93), named: "activeRamadan-dark")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testActiveNawafil_light() {
        onMain(in: self) { exp in
            let view = fastingBannerView(trigger: .weeklySchedule, prohibition: nil)
            if let img = render1xImageRenderer(view, width: 320, height: 96, dark: false) {
                assertSnapshot(of: img, as: .image(precision: 0.93), named: "activeNawafil-light")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testActiveNawafil_dark() {
        onMain(in: self) { exp in
            let view = fastingBannerView(trigger: .weeklySchedule, prohibition: nil)
            if let img = render1xImageRenderer(view, width: 320, height: 96, dark: true) {
                assertSnapshot(of: img, as: .image(precision: 0.93), named: "activeNawafil-dark")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testProhibitionEidAlFitr_light() {
        onMain(in: self) { exp in
            let view = fastingBannerView(trigger: nil, prohibition: .eidAlFitr)
            if let img = render1xImageRenderer(view, width: 320, height: 96, dark: false) {
                assertSnapshot(of: img, as: .image(precision: 0.93), named: "prohibitionEidAlFitr-light")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testProhibitionEidAlFitr_dark() {
        onMain(in: self) { exp in
            let view = fastingBannerView(trigger: nil, prohibition: .eidAlFitr)
            if let img = render1xImageRenderer(view, width: 320, height: 96, dark: true) {
                assertSnapshot(of: img, as: .image(precision: 0.93), named: "prohibitionEidAlFitr-dark")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testProhibitionTashriq_light() {
        onMain(in: self) { exp in
            let view = fastingBannerView(trigger: nil, prohibition: .tashriq12)
            if let img = render1xImageRenderer(view, width: 320, height: 96, dark: false) {
                assertSnapshot(of: img, as: .image(precision: 0.93), named: "prohibitionTashriq-light")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testProhibitionTashriq_dark() {
        onMain(in: self) { exp in
            let view = fastingBannerView(trigger: nil, prohibition: .tashriq12)
            if let img = render1xImageRenderer(view, width: 320, height: 96, dark: true) {
                assertSnapshot(of: img, as: .image(precision: 0.93), named: "prohibitionTashriq-dark")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }
}

// MARK: - FastingModeSection snapshots

final class FastingModeSectionSnapshotTests: XCTestCase {
    func testFastingDisabled_light() {
        onMain(in: self) { exp in
            let s = makeFastingSettings(enabled: false, shia: false,
                                        suiteName: "iqamah.tests.fasting.disabled.light")
            let view = Form { FastingModeSection(settings: s) }
            if let img = render1xImageRenderer(view, width: 420, height: 620, dark: false) {
                assertSnapshot(of: img, as: .image(precision: 0.92), named: "fastingDisabled-light")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testFastingDisabled_dark() {
        onMain(in: self) { exp in
            let s = makeFastingSettings(enabled: false, shia: false,
                                        suiteName: "iqamah.tests.fasting.disabled.dark")
            let view = Form { FastingModeSection(settings: s) }
            if let img = render1xImageRenderer(view, width: 420, height: 620, dark: true) {
                assertSnapshot(of: img, as: .image(precision: 0.92), named: "fastingDisabled-dark")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testFastingEnabledSunni_light() {
        onMain(in: self) { exp in
            let s = makeFastingSettings(enabled: true, shia: false,
                                        suiteName: "iqamah.tests.fasting.sunni.light")
            let view = Form { FastingModeSection(settings: s) }
            if let img = render1xImageRenderer(view, width: 420, height: 620, dark: false) {
                assertSnapshot(of: img, as: .image(precision: 0.92), named: "fastingEnabledSunni-light")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testFastingEnabledSunni_dark() {
        onMain(in: self) { exp in
            let s = makeFastingSettings(enabled: true, shia: false,
                                        suiteName: "iqamah.tests.fasting.sunni.dark")
            let view = Form { FastingModeSection(settings: s) }
            if let img = render1xImageRenderer(view, width: 420, height: 620, dark: true) {
                assertSnapshot(of: img, as: .image(precision: 0.92), named: "fastingEnabledSunni-dark")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testFastingEnabledShia_light() {
        onMain(in: self) { exp in
            let s = makeFastingSettings(enabled: true, shia: true,
                                        suiteName: "iqamah.tests.fasting.shia.light")
            let view = Form { FastingModeSection(settings: s) }
            if let img = render1xImageRenderer(view, width: 420, height: 620, dark: false) {
                assertSnapshot(of: img, as: .image(precision: 0.92), named: "fastingEnabledShia-light")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }

    func testFastingEnabledShia_dark() {
        onMain(in: self) { exp in
            let s = makeFastingSettings(enabled: true, shia: true,
                                        suiteName: "iqamah.tests.fasting.shia.dark")
            let view = Form { FastingModeSection(settings: s) }
            if let img = render1xImageRenderer(view, width: 420, height: 620, dark: true) {
                assertSnapshot(of: img, as: .image(precision: 0.92), named: "fastingEnabledShia-dark")
            } else { XCTFail("render returned nil") }
            exp.fulfill()
        }
    }
}
