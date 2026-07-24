# Bugs & Defects Register

All bugs and defects tracked here with BUG-XXXX identifiers and status.

---

**Total Active Bugs:** 1
**Critical:** 0
**High:** 0
**Medium:** 0
**Low:** 1

> **BUG-0001 through BUG-0070 resolved as of 2026-05-24.** v1.6.0 (15) submitted to App Store 2026-05-25; awaiting review. One non-blocking flake (BUG-0071, LocationServiceTests) logged 2026-05-25 — does not block submission.

---

## Session — 2026-05-25 (Post-submission audit — v1.6.0 in review)

### Open

*(no open bugs)*

---

### Resolved

**BUG-0071 (macOS): `LocationServiceTests.testInitialization()` intermittently fails on CI**

**Severity:** 🟢 P3 — Low (CI flake; does not affect shipping product)
**Reported:** 2026-05-25 — surfaced by CI on PR #153
**Status:** ✅ Fixed — 2026-07-24
**Affected platforms:** macOS (test target only)
**Affected versions:** Test infrastructure as of v1.6.0 (15)

**Root cause (confirmed):** `locationManagerDidChangeAuthorization` fired immediately after `locationManager.delegate = self` in `LocationService.init()`. On CI macOS runners where location services are `.denied`, the delegate callback queued a `Task { @MainActor in ... }` that set `locationError = "Location access denied..."`. Because `testInitialization()` is async, the `await MainActor.run` calls yielded control — allowing the queued task to run before the test read `locationError`. This caused a non-deterministic `XCTAssertNil(locationError)` failure.

**Fix:** In `locationManagerDidChangeAuthorization` `.denied`/`.restricted` branch, capture `hadPendingRequest = pendingLocationRequest || locationContinuation != nil` before clearing state, and only set `locationError` when `hadPendingRequest` is true. This prevents mere initialization of `LocationService` from populating `locationError` as a side effect. Also fixes a latent production bug where the error message could appear in the UI before the user ever tapped "Detect Location."

Additionally: added `.authorizedWhenInUse` to the valid-statuses array in `testAuthorizationStatus` (previously missing, would fail on devices with when-in-use permission granted).

**Files changed:**
- `Packages/IqamahCore/Sources/IqamahCore/Services/LocationService.swift`
- `testsIqamahTests.swift`

---

## Session — 2026-05-24 (AdhaanBanner anchor — v1.6.0 dev)

### Resolved

**BUG-0070 (macOS): AdhaanBannerController panel appears center-screen instead of dropping from menu-bar status item**

**Severity:** 🟡 P2 — Medium (visual/UX regression; functionality unaffected)
**Reported:** 2026-05-24 — internal QA on v1.6.0 dev build
**Status:** ✅ Fixed — same PR
**Affected platforms:** macOS
**Affected versions:** v1.5 (15) and earlier dev builds with the adhaan banner

**Description:** When an adhaan plays and the floating notification panel appears, it animates down from the top of the screen but is horizontally centered on the entire display rather than under the Iqamah menu-bar status item. On wide displays this makes the panel feel disconnected from its origin — users reported it as "appearing in the middle of the screen" rather than "dropping from the menu bar."

**Root cause:** `AdhaanBannerController.positionPanel(_:size:animated:)` computed `centreX = screenFrame.midX - size.width / 2`, completely ignoring the position of the `NSStatusItem` button window.

**Fix:** Thread the status item's screen-coordinate frame (`statusItem.button?.window?.frame`) through a new optional `statusItemFrame:` parameter on `AdhaanBannerController.show(...)`. `positionPanel` now centers the panel under the anchor's midX, clamped to `[screenFrame.minX + 12, screenFrame.maxX - size.width - 12]` so it never spills off a narrow display. When no anchor is provided (status item not yet created, screen disconnected), falls back to the previous screen-center behaviour — guaranteed never to regress.

**Verification:** Trigger an adhaan when the status item is near the far-right of the menu bar; the banner now drops from directly below it rather than from the centre.

---

## Session — 2026-05-24 (Location detection feedback — v1.5 build 14)

### Resolved

**BUG-0069 (iOS/macOS/watchOS): Location detection cached incorrectly + no auto-detect after first run**

**Severity:** 🟠 P1 — High (user-visible misbehavior; affects prayer-time accuracy in suburbs and after travel)
**Reported:** 2026-05-24 — user feedback on v1.5 (14)
**Status:** ✅ Fixed — PR #140 (commit 860b028)
**Affected platforms:** macOS, iOS, watchOS
**Affected versions:** v1.5 (14) and earlier

**Description:** Three layered gaps in the location-detection flow combine to make Iqamah show the wrong city for users in suburbs and after travel:

1. **Catalog snap masks actual locality.** `LocationSetupView.detectClosestCity()` snaps the picker to the nearest entry in `cities.json` (e.g. "Calgary") even when GPS reports a different suburb (e.g. "Airdrie"). `reverseGeocodeAndUpdate()` exists but runs *after* the user taps Continue, so the picker always shows the catalog name during selection.
2. **Detected city is not in the picker's list.** The user's actual GPS-detected locality is persisted to `SettingsManager.selectedCity*` keys but never appears as a selectable entry in the City picker. Opening the picker later in Settings shows only catalog cities; switching away and back loses the GPS context.
3. **No auto-detect after first launch.** `ContentView` (macOS) and `iOSRootView` skip `LocationSetupView` once `hasCompletedSetup == true`, so re-opening the app in a new city does nothing. The picker continues showing whatever was saved on first run even when the device's GPS reports a clearly different location.

**Reproduction (gap 1):** Install fresh in Airdrie, AB. Tap through onboarding — picker shows "Calgary" despite GPS coordinates being in Airdrie.

**Reproduction (gap 3):** Complete onboarding in Toronto. Travel to Calgary. Re-open the app — still shows Toronto with no prompt to re-detect.

**Fix scope:**
1. Surface a "Current Location" entry at the top of the city picker (macOS+iOS shared `LocationSetupView`, `SettingsSheetView`, and watchOS `SettingsTab`) showing the geocoded locality with the `location.fill` icon. Selecting it persists the refined `City` (locality name + raw GPS coords + geocoded timezone).
2. Pre-resolve `CLGeocoder` immediately when GPS resolves (in the `onChange` handler, not the Continue handler), so the picker shows the refined name before the user interacts.
3. Cache the refined city on `SettingsManager.gpsDetectedCity` (already wired) and read it from every picker.
4. Add an opt-in `autoDetectOnMove` toggle (default `true`, KVS-synced). On launch, if the user has moved > 25 km from their saved city, prompt to switch — never auto-switch silently. Uses one-shot `requestLocation()`, NOT `significantLocationChanges`, and does NOT request "Always" permission.
5. Surface the toggle in `SettingsSheetView` (macOS+iOS) and `SettingsTab` (watchOS) under the Location section.

**Out of scope (follow-ups):** snapshot tests for the new picker UI; significant-location-change monitoring (intentionally one-shot only).

---

## Session — 2026-05-21 (App Store rejection — v1.5 build 13)

### Resolved

**BUG-0068 (watchOS): Watch app icon black background — App Store rejection (Guideline 4 — Design)**

**Severity:** 🔴 Critical (blocks App Store approval of v1.5 (13) submission)
**Discovered:** 2026-05-21 — App Store review feedback
**Status:** ✅ Fixed — accepted in App Store v1.5 (15)
**Submission ID:** b0de0a72-84bc-4693-81df-4d8f7bfac818
**Review device:** Apple Watch and iPhone 17 Pro Max
**Version reviewed:** 1.5 (13)
**Guideline cited:** App Store Review Guideline 4 — Design

**Apple's verbatim feedback:**

> Your Apple Watch app icon's design creates a poor experience when viewed on Apple Watch. Specifically:
> - The app icon does not appear circular because your Apple Watch app icon's background color is black.
>
> Next Steps — Modify the app's Apple Watch app icon to include a lighter background color to ensure that it is recognizable and appears circular on Apple Watch.

**Description:** The current watch app icon (`IqamahWatch/Assets.xcassets/AppIcon.appiconset/`) uses a pure black or near-black background under the minaret artwork. watchOS home screen renders icons on a black wallpaper by default, so the icon's bounding circle blends into the background and the app appears as a floating minaret rather than a clearly-bounded circular icon. Apple's HIG explicitly requires icons to be visually distinct from the watch face background.

**Visual evidence:** Screenshot attached to the review feedback (also captured in the user's bug report) shows Iqamah's icon on the watch home screen — the minaret is visible but the icon's circular boundary is indistinguishable from the surrounding black background. Adjacent third-party icons (Maps, Weather, Compass, Books) all have lighter, visually distinct backgrounds and read as discrete circles.

**Root cause:** The watch icon set was generated to match the iOS/macOS app icon's dark-background design (deep navy gradient), but the gradient's darkest stop sits at nearly the same luminance as `#000000`. On the watch's pure-black wallpaper this produces no contrast at the icon's edge.

**Fix required:**
1. Update the watch icon design in `IqamahWatch/Assets.xcassets/AppIcon.appiconset/` to use a lighter background — options include:
   - Apple's recommended approach: a solid mid-luminance color (e.g. `#1f2a3a` or a deeper gold) that contrasts the black watch wallpaper
   - A radial gradient that brightens toward the centre (similar to how Apple's own watchOS icons handle this)
   - A solid gold (`Color.appGold` / `#d9a52e`) background with the minaret in white/dark to maintain the brand
2. Regenerate all watch-icon sizes (24×24 @2x through 117×117 @2x — see existing `Contents.json` for the exact list).
3. Bump build number to 14 and resubmit.

**Files affected:**
- `IqamahWatch/Assets.xcassets/AppIcon.appiconset/Contents.json` (no change to JSON expected; new images replace existing slots)
- All PNG files in `IqamahWatch/Assets.xcassets/AppIcon.appiconset/` (replace each with the new design)
- iOS/macOS icon sets do NOT need to change (Apple's rejection is watch-specific)

**Verification before resubmit:**
- Install on Apple Watch Series 11 simulator (46mm) — verify icon shows as a clearly-bounded circle on the home screen grid, distinguishable from adjacent app icons against black background
- Check icon at all watch sizes — Series 10 41mm, Series 11 46mm, Ultra 49mm
- Cross-check against Apple's HIG sample circles in `WKInterfaceImage` to ensure full coverage to the circle edge

**Related work:**
- Watch app icons originally added in PR #75 (EPIC-0011 / EPIC-0012 watchOS shipping work, 2026-05-11). The black-background design was a deliberate brand choice that did not anticipate watchOS circular cropping behavior.
- No code changes required — this is purely an asset replacement.

---

## Session — 2026-05-12 to 2026-05-20 (v1.5.0 App Store submission + TestFlight feedback batch)

All bugs below were discovered during App Store validation, CI runs, and TestFlight user feedback on v1.5.0 (builds 10–12). All resolved and shipped in PRs #117–#126.

### Resolved

**BUG-0060 (iOS build): Generic Xcode Archive — IqamahWatch missing SKIP_INSTALL**

**Severity:** High (blocks App Store submission)  
**Discovered:** 2026-05-12 during iOS archive attempt  
**Status:** ✅ Fixed — PR #117

**Description:** Archiving the `iqamah-iOS` scheme produced a "Generic Xcode Archive" instead of an iOS App Archive. Xcode includes every product that doesn't set `SKIP_INSTALL = YES` in the archive bundle; the watchOS companion app binary was being treated as a standalone install target, corrupting the archive type.

**Fix:** Added `SKIP_INSTALL = YES` to the `IqamahWatch` Release build configuration in `project.pbxproj`.

---

**BUG-0061 (iOS): Deprecated ActivityKit APIs causing runtime warnings**

**Severity:** Low  
**Discovered:** 2026-05-12 during code review  
**Status:** ✅ Fixed — PR #118

**Description:** `PrayerActivityManager.swift` used deprecated `Activity.update(_:)`, `Activity.request(attributes:content:pushType:)`, and `Activity.end(_:dismissalPolicy:)` signatures from iOS 16.1. iOS 16.2+ requires the `ActivityContent`-wrapped versions.

**Fix:** Updated all three call sites to use `ActivityContent(state:staleDate:)` wrappers per the iOS 16.2+ API.

---

**BUG-0062 (App Store validation): WKWatchOnly=true blocked by App Store (error 90753)**

**Severity:** High (blocks App Store submission)  
**Discovered:** 2026-05-12 during App Store Connect upload  
**Status:** ✅ Fixed — PR #119

**Description:** `IqamahWatch/Info.plist` contained `WKWatchOnly = true`, which declares the watch app as an independent (standalone) app. Apple's validation rule 90753 rejects this when the watch binary is embedded inside an iOS app bundle — the two declarations contradict each other.

**Fix:** Removed `WKWatchOnly` key. Added `WKCompanionAppBundleIdentifier = com.fablesoft.iqamah` to correctly declare the watch app as a companion to the iOS app.

---

**BUG-0063 (App Store validation): Missing WKCompanionAppBundleIdentifier (error 90536)**

**Severity:** High (blocks App Store submission)  
**Discovered:** 2026-05-12 during App Store Connect upload  
**Status:** ✅ Fixed — PR #120 (bundled with BUG-0062 fix)

**Description:** Companion watch apps require `WKCompanionAppBundleIdentifier` in `Info.plist` to declare their parent iOS app. Without it, App Store Connect cannot establish the app relationship and rejects with error 90536.

**Fix:** Added `WKCompanionAppBundleIdentifier = com.fablesoft.iqamah` to `IqamahWatch/Info.plist`.

---

**BUG-0064 (watchOS): GPS location not triggering when permission already granted**

**Severity:** Medium  
**Discovered:** 2026-05-12 during watchOS testing  
**Status:** ✅ Fixed — PR #121

**Description:** `WatchLocationSetup` called `requestWhenInUseAuthorization()` unconditionally on "Update via GPS" tap. When the user had already granted location permission, CoreLocation silently ignores the redundant request and never calls the delegate, leaving the GPS flow stuck indefinitely with no update.

**Fix:** Added a check against `manager.authorizationStatus` before calling `requestWhenInUseAuthorization()`. When status is already `.authorizedWhenInUse` or `.authorizedAlways`, the flow proceeds directly to `startUpdatingLocation()`.

---

**BUG-0065 (iOS/watchOS): GPS city name not shown in headers and Qibla view**

**Severity:** Medium  
**Discovered:** 2026-05-12 (TestFlight feedback)  
**Status:** ✅ Fixed — PR #122

**Description:** When using GPS location, the iOS prayer times header, watchOS prayer times tab, and Qibla view all displayed a blank or stale city name. `activeCityName` fell back to the manually-selected city rather than the GPS-resolved locality. Additionally, watchOS did not reload prayer times when the city or location source changed.

**Fix:** Added `displayCityName` computed property using `settings.activeCityName` (which resolves GPS locality over mapped city). Added `.onChange(of: settings.locationSource)` and `.onChange(of: settings.gpsLocality)` observers in `PrayerTimesTab.swift` to reload prayers on city change.

---

**BUG-0066 (iOS): Prayer reminder notifications bypass Focus / Do Not Disturb**

**Severity:** Medium  
**Discovered:** 2026-05-12 (user request / TestFlight feedback)  
**Status:** ✅ Fixed — PR #123

**Description:** Prayer time notifications were silenced by iOS Focus modes (DND, Sleep, Work). No Critical Alerts entitlement is available without Apple approval, but `.timeSensitive` interruption level is available to all apps and bypasses Focus filters while respecting DND off — the correct balance for prayer reminders.

**Fix:** Added `content.interruptionLevel = .timeSensitive` to `NotificationScheduler.swift` (iOS), `WatchNotificationScheduler.swift` (watchOS), and the widget notification request in `IqamahWidget.swift`.

---

**BUG-0067 (iOS): Duplicate Live Activity / Dynamic Island banners at prayer times**

**Severity:** High (TestFlight feedback — "Maghrib reminder shows up twice")  
**Discovered:** 2026-05-12 (TestFlight v1.5.0 build 11 feedback)  
**Status:** ✅ Fixed — PR #124

**Description:** On app launch, two code paths called `PrayerActivityManager.startOrUpdateActivity()` concurrently: the `scenePhase` `.active` handler and the 60-second timer firing on first tick. With `currentActivity == nil`, both entered the `else` branch and called `Activity.request()`, producing two independent `Activity<PrayerActivityAttributes>` instances. iOS rendered both — as duplicate lock screen banners and as competing Dynamic Island presentations.

**Fix:** Before creating a new Activity, adopt any surviving instance from the previous session:
```swift
if currentActivity == nil {
    let existing = Activity<PrayerActivityAttributes>.activities
    if existing.count > 1 {
        for stale in existing.dropFirst() {
            await stale.end(dismissalPolicy: .immediate)
        }
    }
    currentActivity = existing.first
}
```
This eliminates both the race condition and any duplicates left from a previous session. The fix covers both lock screen banners and Dynamic Island (same `Activity` object, different presentation surfaces).

---

## Resolved (sprint 2026-05-03)

**BUG-CI-005: cities.json validation not path-filtered in CI**
- **Severity:** Low / maintenance
- **Resolution:** Added `validate-cities.yml` workflow with `paths:` filter on `iqamah/Resources/cities.json` (PR #37)
- **Resolved:** 2026-05-03

**BUG-CI-006: File size guard checked repo files, not .app bundle**
- **Severity:** Medium
- **Resolution:** Replaced `file-size` CI job with Release build + `du -sm` bundle check (50 MB limit) (PR #38)
- **Resolved:** 2026-05-03

**BUG-TEST-004: No prayer time accuracy regression tests**
- **Severity:** High
- **Resolution:** Added `PrayerAccuracyRegressionTests.swift` — 5 cities × 5 prayers on 2024-01-15, ±3 min tolerance (PR #39)
- **Resolved:** 2026-05-03

---

## Resolved (sprint 2026-05-03)

**BUG-CI-005: cities.json validation not path-filtered in CI**
- **Severity:** Low / maintenance
- **Resolution:** Added `validate-cities.yml` workflow with `paths:` filter on `iqamah/Resources/cities.json` (PR #37)
- **Resolved:** 2026-05-03

**BUG-CI-006: File size guard checked repo files, not .app bundle**
- **Severity:** Medium
- **Resolution:** Replaced `file-size` CI job with Release build + `du -sm` bundle check (50 MB limit) (PR #38)
- **Resolved:** 2026-05-03

**BUG-TEST-004: No prayer time accuracy regression tests**
- **Severity:** High
- **Resolution:** Added `PrayerAccuracyRegressionTests.swift` — 5 cities × 5 prayers on 2024-01-15, ±3 min tolerance (PR #39)
- **Resolved:** 2026-05-03

---

## Bugs by Status

### Open

---

**BUG-0001: Missing SplashScreenView, LocationSetupView, CalculationMethodView implementations**

**Severity:** Critical  
**Related Story:** US-0018 (Onboarding & First Launch)  
**Related Task:** TBD  
**Discovered:** 2026-03-12 during code review

**Steps to Reproduce:**
1. Build the app
2. Launch fails with compilation error

**Expected:** App compiles and runs with complete onboarding flow  
**Actual:** Three views referenced but not implemented

**Code Location:**
```swift
// ContentView.swift references but these files don't exist:
case .splash:
    SplashScreenView() // NOT IMPLEMENTED
case .locationSetup:
    LocationSetupView { city in ... } // NOT IMPLEMENTED
case .calculationMethod:
    CalculationMethodView(...) { ... } // NOT IMPLEMENTED
```

**Fix Branch:** bugfix/BUG-0001-implement-setup-views  
**Lesson Encoded:** No

**Priority:** Critical — App won't compile

---

**BUG-0002: No error handling when cities.json fails to load**

**Severity:** Critical  
**Related Story:** US-0002 (City Selection)  
**Related Task:** TBD  
**Discovered:** 2026-03-12 during code review

**Steps to Reproduce:**
1. Remove or corrupt `cities.json` from bundle
2. Launch app
3. Try to select location

**Expected:** Display user-friendly error message and fallback option (manual coordinate entry?)  
**Actual:** App shows empty country/city pickers with no explanation

**Root Cause:** `CitiesLoader.load()` returns `nil` on failure, but `LocationSetupView` doesn't handle nil database gracefully

**Code Location:**
```swift
// Location.swift line ~60
guard let url = Bundle.main.url(forResource: "cities", withExtension: "json") else {
    print("Could not find cities.json") // Only prints to console
    return nil
}
```

**Fix Branch:** bugfix/BUG-0002-cities-error-handling  
**Lesson Encoded:** No

**Priority:** Critical — App unusable without cities database

---

**BUG-0003: fatalError crashes app on invalid date components**

**Severity:** Critical  
**Related Story:** US-0004 (Prayer Time Calculation)  
**Related Task:** TBD  
**Discovered:** 2026-03-12 during code review

**Steps to Reproduce:**
1. Pass invalid date to `PrayerCalculator.calculate(for:)`
2. App crashes

**Expected:** Graceful error handling with IqamahError.invalidDate  
**Actual:** App crashes with fatal error

**Code Location:**
```swift
// PrayerCalculator.swift line ~23
guard let year = components.year,
      let month = components.month,
      let day = components.day else {
    fatalError("Could not extract date components") // CRASH
}
```

**Fix Branch:** bugfix/BUG-0003-prayer-calc-error-handling  
**Lesson Encoded:** No

**Priority:** Critical — Violates error handling standards (AGENTS.md §13)

**Recommended Fix:**
```swift
guard let year = components.year,
      let month = components.month,
      let day = components.day else {
    throw IqamahError.invalidDate("Could not extract date components from \(date)")
}
```

---

**BUG-0004: No validation on coordinate ranges**

**Severity:** High  
**Related Story:** US-0002 (City Selection), US-0003 (Auto-detect location)  
**Related Task:** TBD  
**Discovered:** 2026-03-12 during code review

**Steps to Reproduce:**
1. Create City with invalid coordinates (e.g., latitude = 200°)
2. App accepts invalid data
3. Prayer calculations produce incorrect results

**Expected:** Validate latitude ∈ [-90, 90], longitude ∈ [-180, 180]  
**Actual:** No validation performed

**Code Location:**
- `City` model has no validation
- `PrayerCalculator` accepts any CLLocationCoordinate2D
- `QiblahView` accepts any lat/lon values

**Fix Branch:** bugfix/BUG-0004-coordinate-validation  
**Lesson Encoded:** No

**Priority:** High — Can lead to incorrect prayer times

**Recommended Fix:**
```swift
struct City {
    init(name: String, countryCode: String, latitude: Double, longitude: Double, timezone: String) throws {
        guard latitude >= -90 && latitude <= 90 else {
            throw IqamahError.invalidCoordinates(latitude: latitude, longitude: longitude)
        }
        guard longitude >= -180 && longitude <= 180 else {
            throw IqamahError.invalidCoordinates(latitude: latitude, longitude: longitude)
        }
        // ... assign properties
    }
}
```

---

**BUG-0005: Timer memory leak in PrayerTimesView**

**Severity:** Medium  
**Related Story:** US-0004 (Prayer Times Display)  
**Related Task:** TBD  
**Discovered:** 2026-03-12 during code review

**Steps to Reproduce:**
1. Open prayer times view
2. Navigate away (e.g., to settings and back to location setup)
3. Timer continues running in background

**Expected:** Timer cancels when view disappears  
**Actual:** Timer continues indefinitely, updating state for dismissed view

**Code Location:**
```swift
// PrayerTimesView.swift line ~12
private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
```

**Fix Branch:** bugfix/BUG-0005-timer-cleanup  
**Lesson Encoded:** No

**Priority:** Medium — Memory leak, but impact is low (1-minute interval)

**Recommended Fix:**
```swift
@State private var timerCancellable: AnyCancellable?

.onAppear {
    timerCancellable = timer.sink { _ in
        updateDate()
    }
}
.onDisappear {
    timerCancellable?.cancel()
    timerCancellable = nil
}
```

---

**BUG-0006: AppDelegate timer never cancelled**

**Severity:** Medium  
**Related Story:** US-0019 (Status Bar Menu Integration)  
**Related Task:** TBD  
**Discovered:** 2026-03-12 during code review

**Steps to Reproduce:**
1. Launch app
2. Check system resources
3. Timer runs indefinitely even when window closed

**Expected:** Timer cancelled when appropriate  
**Actual:** Timer runs forever until app quit

**Code Location:**
```swift
// AppDelegate.swift line ~53
updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
    self?.updateStatusBarDisplay()
}
```

**Notes:** Timer only invalidated on `applicationWillTerminate`, not when window closes or app goes to background

**Fix Branch:** bugfix/BUG-0006-appdelegate-timer  
**Lesson Encoded:** No

**Priority:** Medium — Continuous CPU/memory usage

---

**BUG-0007: Status bar text changes color to red with <10 minutes warning but no visual indicator in main app**

**Severity:** Low (Enhancement)  
**Related Story:** US-0004 (Prayer Times Display)  
**Related Task:** TBD  
**Discovered:** 2026-03-12 during code review

**Steps to Reproduce:**
1. Launch app with next prayer <10 minutes away
2. Observe status bar (red text)
3. Open main window
4. No urgency indicator in main window

**Expected:** Consistent urgency indicator across status bar and main window  
**Actual:** Only status bar shows urgency

**Code Location:**
- `AppDelegate.swift` line ~120: Status bar shows red if <10 min
- `PrayerTimesView.swift`: No equivalent urgency indicator

**Fix Branch:** enhancement/BUG-0007-urgency-indicator  
**Lesson Encoded:** No

**Priority:** Low — UX enhancement, not a bug

---

**BUG-0008: cities.json file location unknown / not verified**

**Severity:** High  
**Related Story:** US-0002 (City Selection)  
**Related Task:** TBD  
**Discovered:** 2026-03-12 during code review

**Steps to Reproduce:**
1. Search project for cities.json file
2. File not found in any visible location

**Expected:** cities.json bundled as resource in app target  
**Actual:** File referenced but not found

**Code Location:**
```swift
// Location.swift line ~59
guard let url = Bundle.main.url(forResource: "cities", withExtension: "json") else {
    print("Could not find cities.json")
    return nil
}
```

**Fix Branch:** bugfix/BUG-0008-add-cities-json  
**Lesson Encoded:** No

**Priority:** High — Without this file, city selection won't work

**Notes:** Need to either:
1. Create cities.json with major Islamic cities worldwide
2. Use a different approach (external API, user manual entry only)

---

**BUG-0009: No accessibility labels on interactive elements**

**Severity:** High  
**Related Story:** US-0012 (Accessibility)  
**Related Task:** TBD  
**Discovered:** 2026-03-12 during code review

**Steps to Reproduce:**
1. Enable VoiceOver
2. Navigate through prayer times view
3. Many buttons have no labels or generic labels

**Expected:** All buttons, controls have descriptive accessibility labels  
**Actual:** Missing labels on:
- Prayer time adjustment buttons (+/-)
- Qiblah button
- Settings button  
- Custom shapes (no descriptions)

**Code Location:**
- `PrayerTimesView.swift`: Adjustment buttons have no `.accessibilityLabel()`
- `QiblahView.swift`: Compass elements have no accessibility descriptions
- Custom shapes (PrayerMatShape, KaabahShape, MinaretShape) not accessible

**Fix Branch:** bugfix/BUG-0009-accessibility-labels  
**Lesson Encoded:** No

**Priority:** High — Violates WCAG 2.1 AA requirements (AGENTS.md §16)

**Recommended Fixes:**
```swift
// Prayer adjustment buttons
Button(action: { onAdjust(-1) }) {
    Image(systemName: "minus.circle.fill")
}
.accessibilityLabel("Decrease \(name) time by 1 minute")

// Qiblah button
Button(action: { showQiblah = true }) {
    PrayerMatIcon(size: 20)
}
.accessibilityLabel("Show Qiblah direction")

// Compass in QiblahView
Text("Qiblah Direction")
    .accessibilityLabel("Qiblah direction is \(qiblahBearing) degrees \(cardinalDirection)")
```

---

## Bugs by Severity

### Critical (4)
- BUG-0001: Missing SplashScreenView, LocationSetupView, CalculationMethodView implementations
- BUG-0002: No error handling when cities.json fails to load
- BUG-0003: fatalError crashes app on invalid date components

### High (3)
- BUG-0004: No validation on coordinate ranges
- BUG-0008: cities.json file location unknown / not verified
- BUG-0009: No accessibility labels on interactive elements

### Medium (2)
- BUG-0005: Timer memory leak in PrayerTimesView
- BUG-0006: AppDelegate timer never cancelled

### Low (0)
*[BUG-0007 is enhancement, not tracked in severity]*

---

## Fixed (Awaiting Verification)

*None*

---

## Verified (Awaiting Closure)

*None*

---

## Closed

*None*

---

## Retired/Cancelled Bugs

*None*

---

## Bug Fix Priority Recommendations

**Phase 1 (Blocking Compilation):**
1. **BUG-0001** — Implement missing setup views (app won't compile without these)

**Phase 2 (Blocking MVP Release):**
2. **BUG-0003** — Replace fatalError with proper error handling
3. **BUG-0002** — Handle cities.json load failures gracefully
4. **BUG-0008** — Create or locate cities.json file
5. **BUG-0004** — Add coordinate validation
6. **BUG-0009** — Add accessibility labels

**Phase 3 (Before Beta):**
7. **BUG-0005** — Fix PrayerTimesView timer memory leak
8. **BUG-0006** — Fix AppDelegate timer lifecycle

---

## Missing Implementations Discovered

**Critical Missing Files:**
1. `SplashScreenView.swift` — Splash screen with branding
2. `LocationSetupView.swift` — City selection / GPS location setup
3. `CalculationMethodView.swift` — Calculation method & Asr method selection
4. `cities.json` — Database of cities with coordinates

**These must be implemented for US-0018 (Onboarding & First Launch)**

---

## Testing Notes

All bugs discovered during initial code review. No user-reported bugs yet.

**Next Steps:**
1. Implement missing views (BUG-0001)
2. Create or locate cities.json (BUG-0008)
3. Create bug fix branches for each defect
4. Write test cases to reproduce each bug
5. Implement fixes per ERROR_TAXONOMY.md standards
6. Verify fixes with unit and integration tests
7. Update LESSONS.md with learnings from each fix

---

**Last Updated:** 2026-03-12 (Comprehensive code review completed)

## New Bugs — 2026-04-29 Pre-Release Review

**Total Active Bugs (updated):** 16  
**Critical:** 7 (+3)  
**High:** 6 (+3)  
**Medium:** 3 (+1)

---

**BUG-0010: CitiesLoader.load() return type mismatch — LocationSetupView will not compile**

**Severity:** Critical  
**Related Story:** US-0002 (City Selection from Database)  
**Discovered:** 2026-04-29 pre-release code review  
**Status:** Open

**Description:**  
`LocationSetupView.loadDatabase()` assigns the result of `CitiesLoader.shared.load()` directly to `database: CitiesDatabase?`. However `CitiesLoader.load()` now returns `Result<CitiesDatabase, IqamahError>`, not `CitiesDatabase?`. This is a type mismatch that prevents compilation.

**Code Location:** `iqamah/Views/LocationSetupView.swift:107`

**Steps to Reproduce:**
1. Open project in Xcode
2. Build (`Cmd+B`)
3. Observe compile error on `LocationSetupView.swift:107`

**Expected:** App compiles successfully  
**Actual:** Type error: cannot assign `Result<CitiesDatabase, IqamahError>` to `CitiesDatabase?`

**Fix:**
```swift
private func loadDatabase() {
    switch CitiesLoader.shared.load() {
    case .success(let db):
        database = db
    case .failure(let error):
        // Show error state in UI
        print("Cities DB load failed: \(error.localizedDescription)")
    }
}
```

**Priority:** Must fix before any build

---

**BUG-0011: Timer subscription silently broken — prayer times do not update every 60 seconds**

**Severity:** High  
**Related Story:** US-0004 (Display Accurate Prayer Times)  
**Discovered:** 2026-04-29 pre-release code review  
**Status:** ✅ Fixed — `timerSubscription` changed to `Cancellable?`; `timer.connect()` stored without cast

**Description:**  
`PrayerTimesView` stores its timer subscription as `AnyCancellable?` and attempts `timer.connect() as? AnyCancellable`. The `connect()` call returns `Cancellable` (a protocol), not `AnyCancellable` (a concrete class). The conditional cast **always fails silently**, leaving `timerSubscription = nil`. ARC immediately releases the connection, the timer stops, and `onReceive(timer)` never fires. Prayer times display never refreshes and the "next prayer" highlight never advances.

**Code Location:** `iqamah/Views/PrayerTimesView.swift:114-115`

**Steps to Reproduce:**
1. Open app and note current next prayer
2. Wait 60+ seconds
3. Observe prayer highlight does not advance

**Expected:** Prayer times refresh every 60s; next-prayer row highlights advance in real time  
**Actual:** Display freezes at initial calculation

**Fix:**
```swift
@State private var timerSubscription: Cancellable?
// ...
timerSubscription = timer.connect()
```

**Priority:** Fix before release — core feature is broken

---

**BUG-0012: App Sandbox entitlements missing location permission — CoreLocation silently denied**

**Severity:** Critical  
**Related Story:** US-0001 (Location Permission), US-0003 (Auto-detect City)  
**Discovered:** 2026-04-29 pre-release code review  
**Status:** ✅ Fixed — `iqamah.entitlements` updated with `com.apple.security.personal-information.location`

**Description:**  
`ENABLE_APP_SANDBOX = YES` but `iqamah.entitlements` is empty (`<dict/>`). The Mac App Sandbox blocks CoreLocation access unless `com.apple.security.personal-information.location` is declared. Without this entitlement the OS silently denies location requests with no error — `CLLocationManager` receives `.denied` status and the auto-detect feature is completely non-functional in a sandboxed build.

**Code Location:** `iqamah/iqamah.entitlements`

**Fix:** Add to `iqamah.entitlements`:
```xml
<key>com.apple.security.personal-information.location</key>
<true/>
```

**Priority:** Must fix before App Store submission

---

**BUG-0013: Missing Info.plist NSLocationWhenInUseUsageDescription — App Store rejection**

**Severity:** Critical  
**Related Story:** US-0001 (Location Permission)  
**Discovered:** 2026-04-29 pre-release code review  
**Status:** ✅ Not needed — `GENERATE_INFOPLIST_FILE = YES` with `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` already set in project build settings

**Description:**  
No `Info.plist` with `NSLocationWhenInUseUsageDescription` was found in the project. Apple **requires** this key in every app that calls `CoreLocation` APIs; its absence is an automatic App Store review rejection (and a runtime crash on macOS 14+ when location is first requested).

**Fix:** Add `Info.plist` (or add key to existing build settings `INFOPLIST_FILE`) with:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Iqamah uses your location to find the nearest city and calculate accurate prayer times.</string>
```

**Priority:** Must fix before App Store submission

---

**BUG-0014: Force-unwrap crash on NSApp.currentEvent in AppDelegate**

**Severity:** High  
**Related Story:** US-0019 (Status Bar Integration)  
**Discovered:** 2026-04-29 pre-release code review  
**Status:** ✅ Fixed — `NSApp.currentEvent!` replaced with `guard let event = NSApp.currentEvent else { return }`

**Description:**  
`statusBarButtonClicked(_:)` force-unwraps `NSApp.currentEvent!`. In edge cases (programmatic invocation, unit tests, or rapid repeated clicks during event queue drain) `currentEvent` can be `nil`, causing an unrecoverable crash.

**Code Location:** `iqamah/AppDelegate.swift:147`

**Fix:**
```swift
guard let event = NSApp.currentEvent else { return }
```

**Priority:** Fix before release

---

**BUG-0015: isNextPrayer() ignores per-prayer minute adjustments — main view and status bar disagree**

**Severity:** Medium  
**Related Story:** US-0007 (Prayer Time Adjustments)  
**Discovered:** 2026-04-29 pre-release code review  
**Status:** ✅ Fixed — `isNextPrayer` renamed to `isNextPrayer(adjustedTime:)`, compares adjusted times to match status bar

**Description:**  
`PrayerTimesTable.isNextPrayer(_:)` compares raw (unadjusted) `prayerTime` against `Date()`. The status bar in `AppDelegate.updateStatusBarDisplay()` correctly applies `getAdjustment(for:)` before computing the next prayer. A user who has added a +5 minute adjustment to Fajr will see the main view highlight Fajr as "next" 5 minutes before the status bar does, creating a confusing inconsistency.

**Code Location:** `iqamah/Views/PrayerTimesView.swift:209-221`

**Fix:** Pass `adjustedTime` into `isNextPrayer` or compute adjustments inside the method using `settingsManager.getAdjustment(for:)`.

**Priority:** Fix before release

---

**BUG-0016: PrayerTimeRow DateFormatter missing timezone — wrong times shown for non-local cities**

**Severity:** High  
**Related Story:** US-0004 (Display Accurate Prayer Times)  
**Discovered:** 2026-04-29 pre-release code review  
**Status:** ✅ Fixed — `PrayerTimeRow` now accepts `timezone: TimeZone` parameter; uses `PrayerTimes.timeFormatter(for:)`

**Description:**  
`PrayerTimeRow` creates its own `DateFormatter` with no `.timeZone` set, defaulting to the device's current timezone. A user whose Mac is set to `America/New_York` but whose selected city is `London` will see London prayer times displayed in New York local time. The parent `PrayerTimesTable` already has a timezone-aware formatter via `PrayerTimes.timeFormatter(for:)` but does not pass it to rows.

**Code Location:** `iqamah/Views/PrayerTimesView.swift:233-237`

**Fix:** Pass the timezone-correct `DateFormatter` from `PrayerTimesTable` down to `PrayerTimeRow` as a parameter, or pass `TimeZone` to `PrayerTimeRow` and set it on the formatter.

**Priority:** Fix before release

---

---

## New Bugs — 2026-04-30 Live UI Design Review (All Screens)

**Total Active Bugs (updated):** 21  
**Critical:** 9 (+2)  
**High:** 8 (+2)  
**Medium:** 4 (+1)

---

**BUG-0017: Splash screen text-on-text collision — overlay and baked-in image text are illegible**

**Severity:** Critical  
**Related Story:** US-0019 (Splash screen), US-0025 (Splash UX)  
**Discovered:** 2026-04-30 live UI design review  
**Status:** ✅ Fixed — splash.jpg regenerated from splash_full.png with clean text overlay; Arabic delegated to SwiftUI CoreText

**Description:**  
The original `splash.jpg` had "Your free prayer times app." in large gold text baked into the image. The SwiftUI code then overlaid the charity message text on top. Both sets of text rendered simultaneously in the same vertical zone, making both completely unreadable.

**Fix Applied:**  
- `splash.jpg` regenerated from `splash_full.png` (mosque at golden hour) with PIL composite: dark gradient top zone with "Iqamah" in SFNS 68pt gold, dark panel bottom zone with charity message
- Arabic `إقامة` rendered as SwiftUI `Text()` overlay at ~18% from top — CoreText handles Arabic shaping correctly; PIL cannot
- `SplashScreenView.swift` updated to overlay Arabic text in code

---

**BUG-0018: App icon in PrayerTimesView header shows generic pushpin SF Symbol**

**Severity:** High  
**Related Story:** US-0004 (Prayer Times Display)  
**Discovered:** 2026-04-30 live UI design review  
**Status:** ✅ Fixed — `AppIconView(size:40)` replaced with `Image(nsImage: NSImage(named: NSImage.applicationIconName))`

**Description:**  
The header renders `AppIconView(size: 40, showBackground: true)` clipped to a `RoundedRectangle`. At 40pt the custom minaret illustration is indistinguishable — it renders as a dark navy square with an indeterminate gold shape, visually identical to a pushpin SF Symbol. Users cannot associate this with the app's brand.

**Code Location:** `iqamah/Views/PrayerTimesView.swift:25-28`

**Fix:**  
Replace `AppIconView(size: 40)` with `Image(nsImage: NSImage(named: NSImage.applicationIconName)!)` to use the actual compiled app icon asset, which renders crisply at any size.

```swift
Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
    .resizable()
    .frame(width: 36, height: 36)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
```

**Priority:** Fix before release

---

**BUG-0019: Prayer Times window height too small — Isha row clips at window edge with zero padding**

**Severity:** Critical  
**Related Story:** US-0023 (Window size consistency)  
**Discovered:** 2026-04-30 live UI design review  
**Status:** ✅ Fixed — `defaultSize` changed to 620×680 matching `PrayerTimesView` ideal size

**Description:**  
The app's `defaultSize` is declared as 450×500 in `iqamahApp.swift`, but `PrayerTimesView` sets `minWidth: 580, minHeight: 640`. When the window opens at 450×500 it forces the view to resize immediately and the 6-row prayer table still clips: the Isha row sits flush at the bottom window edge with no bottom padding visible. Confirmed live: Isha at 10:00 PM is cut off.

**Code Location:** `iqamah/iqamahApp.swift:12`, `iqamah/Views/PrayerTimesView.swift:106`

**Fix:**  
```swift
// iqamahApp.swift
.defaultSize(width: 580, height: 640)

// PrayerTimesView.swift — keep minWidth/minHeight at 580/640, remove conflicting frame
```

**Priority:** Fix before release

---

**BUG-0020: Qiblah Ka'bah marker is an unrecognisable black square**

**Severity:** Medium  
**Related Story:** US-0010 (Qiblah compass interface)  
**Discovered:** 2026-04-30 live UI design review  
**Status:** ✅ Fixed — replaced with `KaabahMarker` view: dark cube with gold outline and gold Kiswa band stripe

**Description:**  
`KaabahShape().fill(Color.black)` at 22×22pt rendered as a plain black square. Nothing about it suggests the Ka'bah — it looked like a debug placeholder. Users would not connect it to the direction indicator.

**Fix Applied:** `QiblahView.swift` updated with `KaabahMarker` — a `ZStack` of a dark rounded rect with a gold border and a narrow gold band representing the Kiswa.

---

**BUG-0021: Qiblah sheet too small — compass feels cramped, prayer mat fills ~40% of diameter**

**Severity:** Medium  
**Related Story:** US-0010 (Qiblah compass interface)  
**Discovered:** 2026-04-30 live UI design review  
**Status:** ✅ Fixed — sheet enlarged to 420×520, compass to 340×340, prayer mat reduced to 40×60, close X replaced with "Done" button

**Description:**  
The 380×480 sheet with a 260×260 compass meant the prayer mat (50×70) occupied ~27% of the compass radius, leaving little room to read cardinal labels and tick marks. The X close button in the top-right is an iOS pattern; macOS sheets use a "Done" button at the bottom.

**Fix Applied:** `QiblahView.swift` — enlarged sheet, larger compass ring (280pt), prayer mat image at 40×60, replaced X with "Done" button, reduced tick marks from 36 to 12 (every 30°) for visual clarity.

---

---

## New Bugs — 2026-04-30 Live App UI Design Review (All Screens)

**Total Active Bugs (updated):** 29  
**Critical:** 9  
**High:** 11 (+4)  
**Medium:** 6 (+3)  
**Low:** 3 (+3)

---

**BUG-0022: Ka'bah icon renders with white square background on compass ring**

**Severity:** High  
**Related Story:** US-0030 (Qiblah compass interface)  
**Discovered:** 2026-04-30 live UI review — confirmed in screenshot  
**Status:** Open

**Description:**  
`Image("KaabahIcon")` displays with a visible white rectangular background on the compass ring. At the 28×28pt render size, the white square frame dominates over the icon itself, making it look like a website favicon dropped onto the compass. The root cause is PNG compositing without a clip mask — the system applies a white backing behind the transparent regions before rotation compositing.

**Code Location:** `iqamah/Views/QiblahView.swift` — Ka'bah marker `Image("KaabahIcon")` call

**Fix:**
```swift
Image("KaabahIcon")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 28, height: 28)
    .clipShape(Circle())
    .overlay(Circle().stroke(Color(red: 0.85, green: 0.68, blue: 0.25), lineWidth: 1))
```

**Priority:** Fix before release — visually jarring on the compass

---

**BUG-0023: Prayer mat image shows white border seams when rotated**

**Severity:** Medium  
**Related Story:** US-0030 (Qiblah compass interface)  
**Discovered:** 2026-04-30 live UI review  
**Status:** Open

**Description:**  
The `Image("PrayerMat")` asset shows a faint white border/edge artifact around the mat shape when rendered at a non-zero rotation angle. The PNG compositing applies anti-aliasing against a white backing before the rotation transform is applied, producing a visible white fringe at the image boundary.

**Code Location:** `iqamah/Views/QiblahView.swift` — prayer mat `Image("PrayerMat")` with `.rotationEffect`

**Fix:** Add `.drawingGroup()` before `.rotationEffect` to force offscreen compositing before rotation:
```swift
Image("PrayerMat")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 40, height: 60)
    .drawingGroup()
    .rotationEffect(.degrees(qiblahBearing))
```

**Priority:** Fix before release

---

**BUG-0024: Qiblah compass ring is barely visible against dark background**

**Severity:** Medium  
**Related Story:** US-0010 (Qiblah compass interface)  
**Discovered:** 2026-04-30 live UI review  
**Status:** Open

**Description:**  
The compass ring uses `Color.secondary.opacity(0.25)` with `lineWidth: 1.5`. In dark mode this is nearly invisible — users have to search for the compass boundary. The compass ring is the structural frame of the entire compass view and should be clearly legible.

**Code Location:** `iqamah/Views/QiblahView.swift:53`

**Fix:**
```swift
Circle()
    .stroke(Color.secondary.opacity(0.5), lineWidth: 1.5)
```

**Priority:** Medium — usability issue in dark mode

---

**BUG-0025: Qiblah direction line is too thin and low-contrast to be the primary indicator**

**Severity:** High  
**Related Story:** US-0010 (Qiblah compass interface)  
**Discovered:** 2026-04-30 live UI review  
**Status:** Open

**Description:**  
The green direction line from the compass centre to the Ka'bah is 2pt wide at 80% opacity. It is the primary directional indicator of the entire Qiblah view yet it is visually subordinate to the compass ring and tick marks. Users with any colour vision deficiency or on non-ideal displays may miss it entirely.

**Code Location:** `iqamah/Views/QiblahView.swift:80`

**Fix:** Increase weight and add a gradient fade from centre outward to give it directionality:
```swift
Rectangle()
    .fill(
        LinearGradient(
            colors: [Color.clear, Color(red: 0.2, green: 0.75, blue: 0.35)],
            startPoint: .leading, endPoint: .trailing
        )
    )
    .frame(width: 3, height: 140)
    .offset(y: -70)
    .rotationEffect(.degrees(qiblahBearing))
```

**Priority:** Fix before release

---

**BUG-0026: Qiblah sheet has large dead whitespace above W/E on compass ring**

**Severity:** Low  
**Related Story:** US-0010 (Qiblah compass interface)  
**Discovered:** 2026-04-30 live UI review  
**Status:** Open

**Description:**  
The compass circle occupies approximately 60% of the available sheet area. The blank arcs in the W and E quadrants between the title block and the Done button create large dead zones that make the layout feel unfinished. Increasing the compass diameter from 280pt to ~310pt or adding subtle degree ring elements would fill the space intentionally.

**Code Location:** `iqamah/Views/QiblahView.swift` — `.frame(width: 340, height: 340)` on the ZStack

**Fix:** Increase compass frame size and ring diameter proportionally.

**Priority:** Low — cosmetic

---

**BUG-0027: "Done" button on Qiblah sheet has no visual connection to app gold accent**

**Severity:** Low  
**Related Story:** US-0010 (Qiblah compass interface)  
**Discovered:** 2026-04-30 live UI review  
**Status:** Open

**Description:**  
The "Done" button uses `.borderedProminent` which renders as the system accent colour (teal/blue). The app's brand colour is gold (#DFB00F). The Qiblah screen is branded with an Islamic compass — the Done button should feel cohesive with the overall gold/dark palette rather than reverting to the system accent.

**Code Location:** `iqamah/Views/QiblahView.swift` — Done button

**Fix:** Apply `.tint` to align with app brand:
```swift
Button("Done") { dismiss() }
    .buttonStyle(.borderedProminent)
    .tint(Color(red: 0.88, green: 0.69, blue: 0.06))
```

**Priority:** Low — polish

---

**BUG-0028: Location Setup has large dead space between city picker and Continue button**

**Severity:** Medium  
**Related Story:** US-0026 (Location Setup UX)  
**Discovered:** 2026-04-30 live UI review (confirmed in live run)  
**Status:** Open

**Description:**  
After the City picker, approximately 200pt of empty vertical space exists before the Continue button. This dead zone makes the window feel broken or unfinished — users may think more content should appear there. The layout should vertically centre the content block or use a structured `Form`-style container.

**Code Location:** `iqamah/Views/LocationSetupView.swift` — outer `VStack` with `Spacer()`

**Fix:** Replace the open Spacer with a top-aligned VStack that pushes Continue to a fixed bottom inset, or use `.frame(maxHeight: .infinity, alignment: .top)` on the content block.

**Priority:** Medium — affects first-run impression

---

**BUG-0029: Prayer Times header is visually dense at smaller Dynamic Type sizes**

**Severity:** Low  
**Related Story:** US-0004 (Prayer Times Display)  
**Discovered:** 2026-04-30 live UI review  
**Status:** Open

**Description:**  
The header `HStack` contains: app icon (36×36) + "Iqamah" title + city name + method name + Qiblah button (icon + label) + gear icon — 7 distinct elements in a single horizontal row. At `.body` scale and above, the city name and method caption begin to truncate. The layout has no fallback for text overflow.

**Code Location:** `iqamah/Views/PrayerTimesView.swift:22-83`

**Fix:** Allow city/method `VStack` to use `lineLimit(1)` with `.truncationMode(.tail)`, or move method to a second line that wraps independently.

**Priority:** Low — only affects users with very large accessibility text sizes

---

**BUG-0030: Settings sheet "Times shown as 13:30" subtitle clips under scroll**

**Severity:** Low  
**Related Story:** US-0022 (24-hour time format)  
**Discovered:** 2026-04-30 live UI review  
**Status:** Open

**Description:**  
The 24-Hour Time toggle's subtitle ("Times shown as 13:30" / "Times shown as 1:30 PM") is positioned at the bottom of the ScrollView content in `SettingsSheetView`. When the sheet opens at default size, the Display section is below the visible scroll area, requiring users to scroll to discover the toggle exists. Additionally, the subtitle wraps to the toggle label's `VStack` but clips against the sheet edge at 480pt width.

**Code Location:** `iqamah/Views/SettingsSheetView.swift` — DISPLAY section, Toggle label VStack

**Fix:** Ensure the ScrollView always starts scrolled to top, and add padding to the Toggle label VStack so it doesn't clip.

**Priority:** Low — discoverability issue

---

## Updated Bug Fix Priority (Phase 1 — Before App Store Submission)

1. **BUG-0010** — Compilation blocker
2. **BUG-0012** — Sandbox entitlement (silent location failure)
3. **BUG-0013** — Missing Info.plist key (App Store rejection)
4. **BUG-0011** — Timer broken (core feature non-functional)
5. **BUG-0016** — Wrong timezone in row display
6. **BUG-0014** — Force-unwrap crash
7. **BUG-0015** — Adjustment highlighting mismatch

---

---

## Session Close Status — 2026-04-30 (Previous UI Review Session + Adhaan Session)

### Confirmed Fixed (Code Verified)

| Bug | Description | Fix Verified |
|-----|-------------|--------------|
| BUG-0001 | Missing setup views | ✅ All views exist and compile |
| BUG-0002 | cities.json error handling | ✅ LocationSetupView uses `.success`/`.failure` pattern |
| BUG-0005 | Timer memory leak in PrayerTimesView | ✅ `timerSubscription: Cancellable?` with `timer.connect()` |
| BUG-0008 | cities.json not bundled | ✅ Bundled in Resources |
| BUG-0010 | CitiesLoader return type mismatch | ✅ `if case .success(let db) = CitiesLoader.shared.load()` |
| BUG-0011 | Timer subscription silently nil | ✅ `timerSubscription = timer.connect()` (no cast) |
| BUG-0012 | Sandbox entitlement missing | ✅ `com.apple.security.personal-information.location = true` |
| BUG-0013 | Info.plist location key missing | ✅ `GENERATE_INFOPLIST_FILE` + `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` |
| BUG-0014 | Force-unwrap NSApp.currentEvent | ✅ `guard let event = NSApp.currentEvent else { return }` |
| BUG-0015 | isNextPrayer ignores adjustments | ✅ Compares adjusted times via `isNextPrayer(adjustedTime:)` |
| BUG-0016 | PrayerTimeRow wrong timezone | ✅ Timezone-correct formatter passed from PrayerTimesTable |
| BUG-0017 | Splash text-on-text collision | ✅ Clean splash.jpg + Arabic overlay in separate zones |
| BUG-0018 | App icon shows placeholder shape | ✅ `NSImage(named: NSImage.applicationIconName)` |
| BUG-0019 | Window height clips Isha row | ✅ `defaultSize(width: 620, height: 680)` |
| BUG-0020 | Ka'bah marker is black square | ✅ `KaabahMarker` with gold border + Kiswa stripe |
| BUG-0021 | Qiblah sheet too cramped | ✅ Sheet 440×560, compass 310pt, Done button |
| BUG-0022 | Ka'bah icon has white background | ✅ `.drawingGroup().clipShape(Circle())` with gold `.overlay` |
| BUG-0023 | Prayer mat white border on rotation | ✅ `.drawingGroup()` before `.rotationEffect` |
| BUG-0024 | Compass ring barely visible | ✅ `Color.primary.opacity(0.35)`, `lineWidth: 3` |
| BUG-0025 | Direction line too thin | ✅ `LinearGradient` fill, `width: 3`, `height: 155` |
| BUG-0026 | Dead whitespace on compass | ✅ Compass enlarged to 310pt, sheet to 440×560 |
| BUG-0027 | Done button wrong accent colour | ✅ `.tint(Color(red: 0.88, green: 0.69, blue: 0.06))` |
| BUG-0028 | Location Setup dead space | ✅ `Spacer(minLength: 16)` + centred content block |
| BUG-0029 | Header crowding at large text | ✅ `lineLimit(1)` + `minimumScaleFactor(0.8/0.75)` |
| BUG-0030 | Settings subtitle clips | ✅ `.fixedSize(horizontal: false, vertical: true)` |

### All Bugs Resolved ✅

All bugs BUG-0001 through BUG-0059 have been resolved. Verified 2026-05-11:

| Bug | Description | Resolution |
|-----|-------------|------------|
| BUG-0003 | fatalError in PrayerCalculator | ✅ PrayerCalculator uses `throw IqamahError.invalidDate` — no fatalError |
| BUG-0004 | No coordinate validation | ✅ `City.init` throws; QiblahView uses `isValidCoordinate` guard |
| BUG-0006 | AppDelegate timer | ✅ Acceptable — invalidated on `applicationWillTerminate` (menu bar pattern) |
| BUG-0007 | No urgency indicator | ✅ Deferred as enhancement; status bar turns red < 10 min |
| BUG-0009 | Accessibility labels | ✅ +/- buttons labeled; QiblahView compass has accessibilityElement |

---

## New Bugs — 2026-04-30 App Store Readiness Audit

**Total Active Bugs (updated):** 33  
**Critical:** 9  
**High:** 12 (+2)  
**Medium:** 6  
**Low:** 6 (+2)

---

**BUG-0031: Developer documentation (.md files) bundled as app resources** — ✅ Already resolved

**Severity:** High  
**Related Story:** US-0018 (App Store release identity)  
**Discovered:** 2026-04-30 App Store readiness audit  
**Status:** Open

**Description:**  
Eight developer documentation files are registered in the Xcode project as Copy Resources and are being bundled inside the shipping app:  
- `DocsFINAL_SESSION_SUMMARY.md`  
- `DocsMANUAL_TEST_CHECKLIST.md`  
- `DocsXCODE_SETUP_GUIDE.md`  
- `DocsACCESSIBILITY_AUDIT_GUIDE.md`  
- `DocsCODE_REVIEW_SECURITY.md`  
- `DocsBUILD_ERROR_FIX.md`  
- `PROJECT_STRUCTURE.md`  
- `PATH_VERIFICATION.md`

These files add unnecessary bundle weight, expose internal development notes to anyone who inspects the app bundle, and could raise questions during App Store review.

**Code Location:** `iqamah.xcodeproj/project.pbxproj` — PBXBuildFile section (lines 25–32) and Copy Resources build phase (lines 348–371)

**Fix:** Remove all 8 entries from the Copy Resources build phase in `project.pbxproj`. The files can remain in the Xcode project navigator (for reference) but must not be in the target's Copy Resources phase.

**Priority:** High — shipping dev docs in a production app bundle is unprofessional and a potential App Store review concern

---

**BUG-0032: PrivacyInfo.xcprivacy manifest missing** — ✅ Already resolved (PrivacyInfo.xcprivacy in Resources build phase)

**Severity:** High  
**Related Story:** US-0018 (App Store release identity)  
**Discovered:** 2026-04-30 App Store readiness audit  
**Status:** Open

**Description:**  
Apple requires a `PrivacyInfo.xcprivacy` file in apps submitted to the App Store that use certain "required reason" APIs. This app calls:  
- `UserDefaults` (NSPrivacyAccessedAPIType: `CA92.1` — User defaults)
- `FileTimestamp` may also apply

Without this file, App Store Connect will reject the binary at upload with: *"ITMS-91053: Missing API declaration."*

**Fix:** Add a `PrivacyInfo.xcprivacy` file to the target declaring:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "..." "...">
<plist version="1.0">
<dict>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>CA92.1</string>
      </array>
    </dict>
  </array>
  <key>NSPrivacyCollectedDataTypes</key>
  <array/>
  <key>NSPrivacyTracking</key>
  <false/>
</dict>
</plist>
```

**Priority:** High — binary will be rejected at App Store Connect upload without this

---

**BUG-0033: Privacy Policy not publicly hosted**

**Severity:** Low  
**Related Story:** US-0021 (Privacy Policy)  
**Discovered:** Carried forward from AC-0089  
**Status:** ✅ Resolved — 2026-05-07

**Resolution:**  
Published at `https://www.fablesoft.biz/products/iqamah/privacy`. Support page also live at `https://www.fablesoft.biz/products/iqamah/support`. Both URLs updated in `AppDelegate.swift` and `AboutView.swift`. AC-0089, AC-0090, AC-0091 closed.

---

**BUG-0034: App bundle ID not registered in App Store Connect**

**Severity:** Low  
**Related Story:** US-0018 (AC-0075)  
**Discovered:** Carried forward  
**Status:** Open

**Description:**  
`com.iqamah.app` is set as the bundle ID in the project but has not been registered in App Store Connect. This registration must happen before a build can be uploaded.

**Fix:** Log into App Store Connect → Certificates, Identifiers & Profiles → register `com.iqamah.app` as a macOS App ID, then create a new app record in App Store Connect.

**Priority:** Low — blocks submission step, not a code issue

---

## New Feature — 2026-04-30 Adhaan Sound Selection

*Not a bug — documented here for completeness.*

**Feature:** Per-prayer Adhaan sound selection with preview (US-0032)  
**Added:** 2026-04-30 current session  
**Status:** ✅ Implemented and verified (Release build succeeds, all 8 MP3s bundled)

**Summary of changes:**
- **8 MP3 files** added to `iqamah/Resources/` and registered in `project.pbxproj`
  - `adhaan_1.mp3` through `adhaan_5.mp3` (general, all prayers)
  - `adhaan_fajr_1.mp3` through `adhaan_fajr_3.mp3` (Fajr-specific, include "As-salatu khayrun minan nawm")
- **`Adhaan.swift`** — added `adhaanFajrRecordings` and `availableForFajr`; Fajr prayer shows fajr-specific options, other prayers show standard list
- **`AdhaaanPlayer.swift`** — added `AVAudioPlayerDelegate` conformance + `@Published var isPlaying` for reactive play/stop UI; new `preview()` method plays audio even when globally muted
- **`PrayerTimesView.swift`** — preview button is now a play/stop toggle; stops current playback before starting new; Fajr row shows extended dropdown

---

## Current Active Bug Count (2026-04-30)

**Total Active (Open) Bugs:** 9  
- BUG-0003 (needs verification)  
- BUG-0004 (partial)  
- BUG-0006 (deferred)  
- BUG-0007 (enhancement, deferred)  
- BUG-0009 (partial)  
- BUG-0031 (dev docs in bundle — High)  
- BUG-0032 (PrivacyInfo.xcprivacy — High)  
- BUG-0033 (privacy policy URL — Low)  
- BUG-0034 (App Store Connect registration — Low)

**App Store Blockers (must fix before submission):**  
1. **BUG-0031** — Remove dev docs from app bundle  
2. **BUG-0032** — Add PrivacyInfo.xcprivacy  
3. **BUG-0033** — Host privacy policy publicly  
4. **BUG-0034** — Register bundle ID in App Store Connect

---

**Last Updated:** 2026-04-30 (Previous UI review session + Adhaan sound feature session)

---

## Bug Fixes — 2026-05-01 to 2026-05-03 (Post-MVP Session)

### Fixed

**BUG-0035: Right-click status bar menu items had no effect**

**Severity:** High  
**Status:** ✅ Fixed — PR #35 merged  
**Root cause:** `NSMenuItem` without an explicit `.target` in a status bar menu silently discards its action. The `NSStatusItem` menu has no responder chain context, unlike normal app menus which walk from the key window up to `NSApp` and `AppDelegate`. Both "Show Prayer Times" and "Quit Iqamah" were firing into void.  
**Fix:** `showItem.target = self` and `quitItem.target = self` in `AppDelegate.showMenu()`.

---

**BUG-0036: App did not appear in Cmd+Tab switcher when main window was open**

**Severity:** High  
**Status:** ✅ Fixed — PR #35 merged  
**Root cause:** `INFOPLIST_KEY_LSUIElement = YES` in the Xcode build settings is a process-level OS flag set before the app launches. It permanently marks the process as an agent, meaning `NSApp.setActivationPolicy(.regular)` calls at runtime are silently ignored for Cmd+Tab registration.  
**Fix:** Removed `INFOPLIST_KEY_LSUIElement` from both Debug and Release build configs. Added `NSApplication.shared.setActivationPolicy(.accessory)` in `applicationDidFinishLaunching` for identical startup behaviour. The OS now fully honours `.regular` / `.accessory` transitions: window opens → `.regular` (Cmd+Tab visible, dock icon); window closes → `.accessory` (hidden).

---

**BUG-0037: UI design — header too dense, 7 competing elements**

**Severity:** Low (UX)  
**Status:** ✅ Fixed — PR open (`feat/option-b-secondary-toolbar-light-mode`)  
**Root cause:** Primary header contained icon + wordmark + city + full method name + mute + Qiblah + settings + about — 7 interactive/informational elements with no visual hierarchy.  
**Fix:** Option B design — header reduced to icon + wordmark + city + abbreviated method + mute. Secondary toolbar (Qiblah / Settings / About) below, Hijri date right-aligned in toolbar, Gregorian date standalone.

---

## New Bugs — 2026-05-03 Design Review (All Views)

**Total Active Bugs (updated):** 19  
**Critical:** 0  
**High:** 2 (+2)  
**Medium:** 4 (+4)  
**Low:** 4 (+4)

---

**BUG-0038 — `Color+App.swift` with `Color.appGold` centralises**

> ✅ Fixed — `Color+App.swift` with `Color.appGold` centralises the brand colour

**BUG-0038: Gold brand color hardcoded as local `let gold` in 6+ files**

**Severity:** Medium  
**Related Story:** US-0004 (Prayer Times Display), brand consistency  
**Discovered:** 2026-05-03 design review  
**Status:** Open

**Description:**  
`Color(red: 0.88, green: 0.69, blue: 0.06)` (and a slight variant `0.95, 0.76, 0.06`) is defined as `private let gold` in `PrayerTimeRow`, `AdhaanBannerView`, `AboutView`, `SunArcView`, `WaveBar`, and `QiblahView`, plus inline literals in `PrayerTimesView`. Any brand color tweak requires editing 6+ files.

**Code Locations:**  
- `iqamah/Views/PrayerTimesView.swift:39` — inline literal  
- `iqamah/Views/PrayerTimesView.swift:356` — `private let gold`  
- `iqamah/Views/AdhaanBannerView.swift:16` — `private let gold`  
- `iqamah/Views/AboutView.swift:6` — `private let gold`  
- `iqamah/Views/QiblahView.swift:64` — inline literal  

**Fix:** Add `Color+App.swift` extension with `static let appGold = Color(red: 0.88, green: 0.69, blue: 0.06)` and replace all local definitions.

**Priority:** Medium — maintainability / brand consistency risk

---

**BUG-0039 — adhaan column always visible in prayer row (not ho**

> ✅ Fixed — adhaan column always visible in prayer row (not hover-gated)

**BUG-0039: Adhaan picker hidden until hover — key feature invisible on first use**

**Severity:** High  
**Related Story:** US-0032 (Per-prayer adhaan selection)  
**Discovered:** 2026-05-03 design review  
**Status:** Open

**Description:**  
`PrayerTimeRow` shows the adhaan picker only when `isHovering || selectedAdhaan.id != "silent"`. A user who has never hovered over a prayer row will never discover they can assign an adhaan sound. The feature is completely invisible in its default state.

**Code Location:** `iqamah/Views/PrayerTimesView.swift:479`

**Fix:** Show a persistent but minimal hint ("No adhaan" / music note) below each row by default, or keep the picker always visible at minimum size and expand on hover.

**Priority:** High — core feature (US-0032) is undiscoverable

---

**BUG-0040 — `min/maxHeight` instead of fixed 660pt frame**

> ✅ Fixed — `min/maxHeight` instead of fixed 660pt frame

**BUG-0040: Settings sheet fixed height (660pt) exceeds main window minHeight (640pt)**

**Severity:** Medium  
**Related Story:** US-0022 (Settings UX)  
**Discovered:** 2026-05-03 design review  
**Status:** Open

**Description:**  
`SettingsSheetView` declares `.frame(width: 480, height: 660)`. The main `PrayerTimesView` has `minHeight: 640`. On a display where the window opened at or near its minimum height, the sheet can be taller than the window presenting it, causing layout overflow.

**Code Location:** `iqamah/Views/SettingsSheetView.swift:291`

**Fix:** Change to `.frame(width: 480, minHeight: 540, maxHeight: 660)` and let the existing `ScrollView` accommodate variable content height.

**Priority:** Medium — layout overflow on constrained displays

---

**BUG-0041 — stale PIL comment removed from SplashScreenView**

> ✅ Fixed — stale PIL comment removed from SplashScreenView

**BUG-0041: Stale PIL comment in SplashScreenView references a Python library**

**Severity:** Low  
**Related Story:** None  
**Discovered:** 2026-05-03 design review  
**Status:** Open

**Description:**  
`SplashScreenView.swift:23` contains `// (CoreText handles Arabic shaping correctly; PIL cannot)`. PIL (Python Imaging Library) has no relevance to a Swift codebase. This is a leftover comment from an image-generation script used during asset creation.

**Code Location:** `iqamah/Views/SplashScreenView.swift:23`

**Fix:** Remove the comment entirely.

**Priority:** Low — cosmetic / misleading comment

---

**BUG-0042 — `ForEach(prayerTimes.prayers, id: \.name)` in Pray**

> ✅ Fixed — `ForEach(prayerTimes.prayers, id: \.name)` in PrayerTimesComponents

**BUG-0042: ForEach in PrayerTimesTable uses array offset as identity — breaks animations**

**Severity:** Medium  
**Related Story:** US-0004 (Prayer Times Display)  
**Discovered:** 2026-05-03 design review  
**Status:** Open

**Description:**  
`ForEach(Array(prayerTimes.prayers.enumerated()), id: \.offset)` uses the integer index as the item identity. SwiftUI cannot track which row corresponds to which prayer across updates, so any state change that reorders or replaces the list will produce incorrect animations and potential state bleed between rows.

**Code Location:** `iqamah/Views/PrayerTimesView.swift:210`

**Fix:** `ForEach(prayerTimes.prayers, id: \.name)` — prayer names are stable and unique.

**Priority:** Medium — incorrect SwiftUI diffing can cause visual glitches

---

**BUG-0043 — no extra `clipShape` on app icon in header**

> ✅ Fixed — no extra `clipShape` on app icon in header

**BUG-0043: App icon in PrayerTimesView header is double-rounded**

**Severity:** Low  
**Related Story:** US-0004 (Prayer Times Display)  
**Discovered:** 2026-05-03 design review  
**Status:** Open

**Description:**  
`NSImage(named: NSImage.applicationIconName)` already returns a pre-rounded square icon (Apple renders all macOS app icons with a rounded rect mask). Applying an additional `.clipShape(RoundedRectangle(cornerRadius: 7))` creates a tighter inner clip that produces a slightly misshapen corner on the displayed icon.

**Code Location:** `iqamah/Views/PrayerTimesView.swift:31`

**Fix:** Remove the `.clipShape(RoundedRectangle(...))` modifier. The icon renders correctly without it.

**Priority:** Low — subtle visual artifact

---

**BUG-0044 — `.tint(.appGold)` on Continue buttons in both onbo**

> ✅ Fixed — `.tint(.appGold)` on Continue buttons in both onboarding views

**BUG-0044: Onboarding "Continue" button uses default blue accent — inconsistent with gold brand**

**Severity:** Low  
**Related Story:** US-0018 (Onboarding & First Launch)  
**Discovered:** 2026-05-03 design review  
**Status:** Open

**Description:**  
`LocationSetupView` and `CalculationMethodView` both use `.buttonStyle(.borderedProminent)` without a `.tint()`, defaulting to the system accent color (blue/teal). The `AboutView` and `QiblahView` done/close buttons use `.tint(gold)`. This creates an inconsistency: the first-run funnel uses blue, the rest of the app uses gold.

**Code Locations:**  
- `iqamah/Views/LocationSetupView.swift:132`  
- `iqamah/Views/CalculationMethodView.swift:131`

**Fix:** Add `.tint(.appGold)` (or equivalent) to the `.borderedProminent` buttons in both onboarding views.

**Priority:** Low — brand inconsistency in first-run funnel

---

**BUG-0045 — Display Size stepper removed from CalculationMetho**

> ✅ Fixed — Display Size stepper removed from CalculationMethodView

**BUG-0045: Display Size stepper embedded in step 2 of onboarding breaks focus**

**Severity:** Medium  
**Related Story:** US-0018 (Onboarding & First Launch)  
**Discovered:** 2026-05-03 design review  
**Status:** Open

**Description:**  
`CalculationMethodView` contains a "Display Size" stepper (±10% scale) after the calculation method section, with the label `"(you can change this later in Settings)"`. Embedding an unrelated display preference inside a focused onboarding step dilutes the task and the apologetic label acknowledges it doesn't belong there. New users should complete onboarding before tuning display preferences.

**Code Location:** `iqamah/Views/CalculationMethodView.swift:68-115`

**Fix:** Remove the Display Size block from `CalculationMethodView`. It remains accessible via Settings → Display Size.

**Priority:** Medium — breaks onboarding focus; setting is duplicated in Settings

---

**BUG-0046 — `Form { }.formStyle(.grouped)` in SettingsSheetVie**

> ✅ Fixed — `Form { }.formStyle(.grouped)` in SettingsSheetView

**BUG-0046: Settings sheet uses custom section/divider pattern instead of native `Form`**

**Severity:** High  
**Related Story:** US-0022 (Settings UX)  
**Discovered:** 2026-05-03 design review  
**Status:** Open

**Description:**  
`SettingsSheetView` reimplements macOS settings layout manually: custom `SectionHeader` view, manual `Divider()` placement, hand-rolled `SettingsRow`, explicit `padding(.horizontal, 28)` on every section, and a hardcoded `height: 660`. This diverges from `Form { Section { ... } }.formStyle(.grouped)`, which provides the correct macOS-native grouped appearance, automatic insets, focus ring behavior, and content-size adaptation for free.

**Code Location:** `iqamah/Views/SettingsSheetView.swift:66-305`

**Fix:** Wrap the settings content in `Form { }.formStyle(.grouped)`. Replace `SectionHeader` with `Section("Location") { }` headers. Remove manual `Divider()` calls and padding. Remove the fixed `height: 660` frame.

**Priority:** High — deviates from macOS platform conventions; hardcoded height causes layout issues

---

**BUG-0047 — `.buttonStyle(.bordered)` on AboutView Close butto**

> ✅ Fixed — `.buttonStyle(.bordered)` on AboutView Close button

**BUG-0047: AboutView "Close" button uses `.borderedProminent` — wrong prominence for dismiss**

**Severity:** Low  
**Related Story:** US-0021 (About screen)  
**Discovered:** 2026-05-03 design review  
**Status:** Open

**Description:**  
`AboutView` uses `.buttonStyle(.borderedProminent).tint(gold)` for the "Close" button. Per Apple HIG, `.borderedProminent` is reserved for the primary forward action in a flow (e.g., Save, Continue, Submit). A dismiss button should use `.bordered` or `.plain`. Using `.borderedProminent` for "Close" inverts the visual hierarchy and suggests the action is more significant than it is.

**Code Location:** `iqamah/Views/AboutView.swift:149`

**Fix:** Change to `.buttonStyle(.bordered)` and remove `.tint(gold)`.

**Priority:** Low — HIG violation, subtle but incorrect

---

**Last Updated:** 2026-05-03 (Design review — BUG-0038 through BUG-0047 added)

---

## New Bugs — 2026-05-05

**BUG-0048 — `_ = try City(...)` suppresses unused-result warni**

> ✅ Fixed — `_ = try City(...)` suppresses unused-result warning; #require() used in tests

**BUG-0048: "Result of 'City' initializer is unused" warning in test**

**Severity:** Low (test warning only — no production impact)  
**Discovered:** 2026-05-05 Xcode Issue Navigator  
**Status:** Open

**Description:**  
`IntegrationAndEdgeCaseTests.swift:173` calls `try City(...)` inside a `do { } catch` block to verify it throws an error, but the constructed value is never assigned. Swift warns "Result of 'City' initializer is unused".

**Code Location:** `Tests/IntegrationAndEdgeCaseTests.swift:173`

```swift
// Before (warns):
try City(name: "Test", countryCode: "XX", latitude: 91, longitude: 0, timezone: "UTC")

// Fix:
_ = try City(name: "Test", countryCode: "XX", latitude: 91, longitude: 0, timezone: "UTC")
```

**Priority:** Low — test-only, zero runtime impact

---

**Last Updated:** 2026-05-05

---

## Milestone — 2026-05-05: App Store Submission

Iqamah v1.0 submitted to App Store Connect for review.
- Screenshots uploaded
- Archive built from `develop` @ `747a5b2`
- Bundle ID: `com.fablesoft.iqamah`, Team: `96Y29SP9JR`
- BUG-0034 (App Store Connect registration) → **Resolved**

---

## New Bugs — 2026-05-05 (Xcode console log review)

**BUG-0049: layoutSubtreeIfNeeded called during active layout pass in AdhaanBannerController**

**Severity:** Low  
**Discovered:** 2026-05-05 Xcode console  
**Status:** Open

**Description:**  
`AdhaanBannerController.show()` calls `hosting.layoutSubtreeIfNeeded()` to measure the banner's fitting height, but this fires during an active layout cycle causing the warning "It's not legal to call -layoutSubtreeIfNeeded on a view which is already being laid out."

**Code Location:** `iqamah/Services/AdhaanBannerController.swift` — size measurement block

```swift
// Problematic:
hosting.frame = CGRect(x: 0, y: 0, width: bannerWidth, height: 1)
hosting.layoutSubtreeIfNeeded()
let fittingHeight = hosting.fittingSize.height

// Fix: use fittingSize directly — it triggers layout internally without recursion
let fittingHeight = hosting.fittingSize.height
```

**Priority:** Low — cosmetic console warning; adhaan banner still displays correctly

---

**BUG-0050: Audio queue timeout causes silent adhaan failure**

**Severity:** Medium  
**Discovered:** 2026-05-05 Xcode console  
**Status:** Open

**Description:**  
Console logs show `AQMEIO timed out after 15s` followed by `MEDeviceStreamClient: client stopping after failed start: AudioQueueObject`. An audio queue was unable to start (audio subsystem busy or hardware unavailable). If this occurs at prayer time the adhaan plays silently with no user feedback.

**Code Location:** `iqamah/Services/AdhaaanPlayer.swift` — `play()` / `preview()` methods

**Recommended Fix:**  
Check `AVAudioPlayer.play()` return value and handle `false` (failure to start). Show a visual fallback (e.g., banner still appears, mute icon pulses) so the user knows prayer time arrived even if audio failed.

**Priority:** Medium — silent failure at prayer time is user-facing

---

**Last Updated:** 2026-05-05 (App Store submission complete; BUG-0049, BUG-0050 logged)

---

## App Store Rejection — 2026-05-05

**BUG-0051: Invalid entitlement value causes App Store rejection (Guideline 2.4.5(i))**

**Severity:** Critical (blocks App Store distribution)  
**Discovered:** 2026-05-05 — App Store review rejection  
**Status:** ✅ Fixed

**Rejection message:**  
> Guideline 2.4.5(i) - Performance  
> The app incorrectly implements sandboxing, or it contains one or more entitlements with invalid values.  
> `com.apple.security.network.client	False`

**Root Cause:**  
`iqamah.entitlements` contained `com.apple.security.network.client` set to `<false/>`. Entitlements are capability grants — a key's *presence* means "grant this capability". Setting a key to `<false/>` is contradictory and invalid. Apple's codesigning validator rejects it under Guideline 2.4.5(i).

**Fix:**  
Removed `com.apple.security.network.client` entirely. Iqamah makes no network requests and does not need this entitlement. The entitlements file now contains only two valid keys:
- `com.apple.security.app-sandbox = true`
- `com.apple.security.personal-information.location = true`

**Next steps:**  
Archive a new build and resubmit to App Store Connect.

---

**Last Updated:** 2026-05-05 (App Store rejection resolved — resubmit required)

---

## Fixed — 2026-05-05/06 Session (PR #47, PR #48)

**BUG-0049: layoutSubtreeIfNeeded called during active layout pass** — ✅ Fixed  
Removed redundant `hosting.layoutSubtreeIfNeeded()` call in `AdhaanBannerController.show()`. `fittingSize.height` triggers layout internally.

**BUG-0050: Audio queue timeout causes silent adhaan failure** — ✅ Fixed  
`AdhaaanPlayer.startPlayback()` now checks `AVAudioPlayer.play()` return value. `isPlaying` only set `true` when audio actually starts; failed plays log a diagnostic and leave the banner visible.

**BUG-0051: Invalid entitlement causes App Store rejection** — ✅ Fixed (PR #47)  
Removed `com.apple.security.network.client = false` from `iqamah.entitlements`.

**BUG-0052: Header icon and text too small** — ✅ Fixed  
Icon 32→64pt; title font 20→28pt; city `.subheadline`→`.title3`; method `.caption2`→`.caption`; Hijri date `.caption`→`.subheadline`.

**BUG-0053: Sunrise row text smaller than prayer rows** — ✅ Fixed  
SunriseRow icon and label `.callout`→`.body`; time `.callout`→`.title3.weight(.medium)`.

**BUG-0054: Top gap above header** — ✅ Fixed  
`.padding(.top, 46)` → `.padding(.top, 16)` in `PrayerTimesView`.

**BUG-0055: adhaan_4.mp3 has 8s silent lead-in** — ✅ Fixed  
Trimmed 8 seconds via ffmpeg (`-ss 4` applied twice); 213s→205s.

---

---

## Session — 2026-05-10 to 2026-05-11 (EPIC-0010/0011/0012 implementation)

No new production bugs found during EPIC-0010 (iOS conversion), EPIC-0011 (Hilal Watch), or EPIC-0012 (Apple Watch) implementation. All three EPICs shipped without regressions.

### Resolved during implementation

**BUG-0056 (iOS build): `CLAuthorizationStatus.authorized` unavailable on watchOS**

**Severity:** Low (watchOS-only)  
**Discovered:** 2026-05-11 during EPIC-0012 Branch 1 (IqamahCore watchOS target)  
**Status:** ✅ Fixed — PR feat/compass-ios-style-ticks (commit 35b3348)

**Description:** `LocationService.swift` used `.authorized` (deprecated alias for `.authorizedAlways`) which is absent on watchOS, breaking the `IqamahWatch` target build.

**Fix:** Wrapped the `case .authorized:` branch in `#if os(iOS)` so it compiles conditionally. `case .authorizedWhenInUse, .authorizedAlways:` handles both platforms without the deprecated alias.

---

**BUG-0057 (CI): macOS `iqamahTests` crashed silently with exit code 65 on CI**

**Severity:** Low (intermittent CI flake)  
**Discovered:** 2026-05-11 during PR #67 CI run  
**Status:** ✅ Resolved — re-trigger caused clean pass; confirmed as transient runner crash

**Description:** The `Test & Coverage` job failed with exit code 65 (`TEST FAILED`) but printed no individual test failure — the xcodebuild test runner itself crashed after 12s. All 174 tests pass locally and on re-run.

**Root cause:** Transient GitHub Actions macOS runner instability (no reproducibility on second run). No code change required.

---

**BUG-0058 (iOS): `IqamahWatchWidget` test target needed `TEST_HOST` removed**

**Severity:** Low (CI test configuration)  
**Discovered:** 2026-05-11 during PR #67 CI run  
**Status:** ✅ Fixed — `TEST_HOST` removed from `IqamahWatchTests` build config

**Description:** `IqamahWatchTests` was configured as a *hosted* test bundle (`TEST_HOST = .../IqamahWatch.app/IqamahWatch`). This requires the watch app binary to be pre-built for the exact same simulator destination. CI used `generic/platform=watchOS` for the build step but a specific simulator for tests, causing a linker error: `library 'IqamahWatch' not found`.

**Fix:** Removed `TEST_HOST` — unit tests (`TimelineTests`, `QiblaTests`) are standalone and don't need to be hosted inside the watch app.

---

**BUG-0059 (Compass): iOS-style compass improvements identified during mockup review**

**Severity:** Low (visual polish)  
**Discovered:** 2026-05-11 during interactive mockup session  
**Status:** ✅ Fixed — PR #69

**Description:** The macOS Qiblah compass had coarse 15°-interval tick marks (24 total), no degree labels, a green gradient direction line, and no N-triangle marker — diverging from iOS compass conventions.

**Fix:** PR #69 (`feat/compass-ios-style-ticks`) updated `QiblahView.swift`:
- 72 tick marks every 5° with 4-level sizing (cardinal/semi-cardinal/medium/minor)
- Degree labels at 45/135/225/315 in 9pt monospaced
- N red triangle marker on ring
- Dashed gold Canvas line with arrowhead replacing green gradient
- Prayer mat enlarged to 72×108pt

---

**Last Updated:** 2026-05-11 (All bugs BUG-0001–BUG-0059 verified resolved. BUG-0039–0048 confirmed fixed in prior EPIC-0010/0011 implementation work. BUG-0031/0032 confirmed already resolved in bundle. No open production bugs.)
