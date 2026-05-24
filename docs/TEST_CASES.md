# Test Cases

Human-readable test cases (TC-XXXX) linked to user stories and acceptance criteria. Distinct from unit tests — used for verification and QA.

---

## Test Case Registry

**Total Test Cases:** 0  
**Status:** 🔴 No test cases defined yet (awaiting User Stories and Acceptance Criteria)

---

## Test Case Format

```
TC-[XXXX]: [Short descriptive title]
Related Story: US-[XXXX]
Related Task: TASK-[XXXX]
Related AC: AC-[XXXX]
Type: [Functional | Regression | Edge Case | Negative | Accessibility | Performance]
Preconditions: [System state required before the test is run]
Steps:
  1. [Action]
  2. [Action]
  3. [Action]
Expected Result: [What should happen if the system is working correctly]
Actual Result: [Filled in during test execution — leave blank until executed]
Status: [ ] Not Run / [ ] Pass / [ ] Fail
Defect Raised: [BUG-XXXX or "None"]
Notes: [Any observations, edge cases, or defects found]
```

---

# Test Cases

Human-readable test cases (TC-XXXX) linked to user stories and acceptance criteria. Distinct from unit tests — used for verification and QA.

---

## Test Case Registry

**Total Test Cases:** 73
**Status:** 🟡 EPIC-0010, EPIC-0016, and EPIC-0017 covered (TC-0001 through TC-0073); EPIC-0001 through EPIC-0009 and EPIC-0011 through EPIC-0015 still pending TC backfill

---

## Test Case Format

```
TC-[XXXX]: [Short descriptive title]
Related Story: US-[XXXX]
Related Task: TASK-[XXXX]
Related AC: AC-[XXXX]
Type: [Functional | Regression | Edge Case | Negative | Accessibility | Performance]
Preconditions: [System state required before the test is run]
Steps:
  1. [Action]
  2. [Action]
  3. [Action]
Expected Result: [What should happen if the system is working correctly]
Actual Result: [Filled in during test execution — leave blank until executed]
Status: [ ] Not Run / [ ] Pass / [ ] Fail
Defect Raised: [BUG-XXXX or "None"]
Notes: [Any observations, edge cases, or defects found]
```

---

## Test Cases by Epic

### EPIC-0010 — iOS Universal App Conversion

#### US-0040 — Extract IqamahCore Swift Package

**TC-0001 (AC-0169) — IqamahCore declares both platforms**
Type: Functional · Preconditions: Branch 1 applied
Steps:
  1. Open `Packages/IqamahCore/Package.swift`
  2. Inspect `platforms` array
Expected: Contains `.macOS(.v14)` and `.iOS(.v17)`
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0002 (AC-0170) — macOS app builds clean after extraction**
Type: Regression · Preconditions: Branch 1 applied
Steps:
  1. `xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build` (macOS; for iOS use `-scheme iqamah-iOS -destination 'generic/platform=iOS'`)
  2. Compare warning count to pre-extraction baseline
Expected: BUILD SUCCEEDED, no new warnings introduced by the move
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0003 (AC-0171) — IqamahCore tests pass**
Type: Regression
Steps:
  1. `cd Packages/IqamahCore && swift test`
  2. Verify count matches pre-extraction count (or +N for newly added tests)
Expected: All tests pass; no regressions
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0004 (AC-0172) — No AppKit imports in IqamahCore**
Type: Functional
Steps:
  1. `grep -r "import AppKit" Packages/IqamahCore/Sources/`
Expected: Zero matches
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0005 (AC-0173) — macOS app behavior identical to pre-extraction**
Type: Regression · Preconditions: Identical settings on pre- and post-extraction installs (city, method, Asr method, adjustments)
Steps:
  1. Note all six prayer times on the pre-extraction baseline build
  2. Install the post-extraction build
  3. Compare all six times for the same date
Expected: Times match to the second; UI behavior unchanged
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0006 (AC-0174) — IqamahCore builds for iOS Simulator**
Type: Functional
Steps:
  1. In Xcode, select an iOS 17 simulator destination for the IqamahCore scheme
  2. Product → Build
Expected: BUILD SUCCEEDED
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### US-0041 — Add iOS App Target & Core Flow

**TC-0007 (AC-0175) — iOS app installs and launches**
Type: Functional
Steps:
  1. Build & run `iqamah-iOS` scheme on an iOS 17 simulator
  2. Build & run on a physical iOS device
Expected: App launches without crashes on both targets
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0008 (AC-0176) — Universal bundle ID across both targets**
Type: Functional
Steps:
  1. Inspect Bundle Identifier for both `iqamah` and `iqamah-iOS` build settings
  2. Verify App Store Connect app record lists both macOS and iOS
Expected: Both targets are `com.fablesoft.iqamah`; App Store Connect lists a single universal app
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0009 (AC-0177) — First-launch flow completes end-to-end**
Type: Functional · Preconditions: Fresh install (no prior settings)
Steps:
  1. Launch the iOS app
  2. Observe launch screen → animated splash
  3. Select Toronto, Canada in Location Setup; Continue
  4. Select ISNA in Calculation Method; Continue
Expected: App lands on Prayer Times tab; no crashes; settings persisted
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0010 (AC-0178) — iOS prayer times match macOS to the second**
Type: Functional · Preconditions: Same city, method, Asr method, date on both apps
Steps:
  1. Note all six times on macOS
  2. Note all six times on iOS
Expected: Identical to the second
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0011 (AC-0179) — Qiblah updates with device heading on physical device**
Type: Functional · Preconditions: Physical iOS device with magnetometer
Steps:
  1. Open Qiblah tab
  2. Rotate device 90° clockwise
Expected: Compass needle rotates correspondingly; points toward Mecca direction relative to current location
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0012 (AC-0180) — No AppKit references in iOS target**
Type: Functional
Steps:
  1. `grep -rn "import AppKit\|NSImage\|NSColor\|NSScreen\|NSApp" iqamah-iOS/`
Expected: Zero matches
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### US-0042 — iCloud Settings Sync via KVS

**TC-0013 (AC-0181) — KVS entitlement present in both targets**
Type: Functional
Steps:
  1. Inspect `iqamah.entitlements` and `iqamah-iOS.entitlements`
  2. `codesign -d --entitlements - <path-to-built-binary>`
Expected: Both contain `com.apple.developer.ubiquity-kvstore-identifier`
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0014 (AC-0182) — Calculation method syncs macOS → iOS within 30s**
Type: Functional · Preconditions: Same iCloud account signed in on both devices; both apps launched
Steps:
  1. On macOS, change calculation method from MWL to ISNA
  2. Wait 30 seconds
  3. Foreground iOS app
Expected: iOS shows ISNA
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0015 (AC-0183) — All synced settings propagate bidirectionally**
Type: Functional
Steps:
  1. Repeat the TC-0014 pattern for: selected city, Asr method, per-prayer adjustment, adhaan selection per prayer
  2. Test in both directions (macOS→iOS and iOS→macOS)
Expected: Each change propagates within 30s in both directions
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0016 (AC-0184) — App functions when iCloud unavailable**
Type: Negative · Preconditions: Signed out of iCloud on test device
Steps:
  1. Launch app
  2. Change calculation method
  3. Force-quit and relaunch
Expected: App launches, setting persisted locally, no error UI surfaced
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0017 (AC-0185) — Second device populates from iCloud on first launch**
Type: Functional · Preconditions: macOS app already configured (city + method); fresh iOS install signed into same iCloud
Steps:
  1. Install and launch iOS app
  2. Wait up to 30 seconds
Expected: Settings reflect macOS state (city, method); main view shown without re-running setup flow
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0018 (AC-0186) — Round-trip preserves settings**
Type: Regression
Steps:
  1. macOS: set method to MWL → wait → verify iOS shows MWL
  2. iOS: change to ISNA → wait → verify macOS shows ISNA
  3. macOS: change back to MWL → wait → verify iOS shows MWL
Expected: No setting lost or reverted across the round trip
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### US-0043 — iOS Local Prayer Notifications

**TC-0019 (AC-0187) — Authorization prompt appears with clear rationale; denial does not block app**
Type: Functional · Preconditions: Fresh install
Steps:
  1. Complete onboarding
  2. Reach Prayer Times view
  3. Tap "Don't Allow" on the system permission prompt
Expected: System prompt appears; denial does not crash; app remains usable
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0020 (AC-0188) — Notification fires at correct time on locked device**
Type: Functional · Preconditions: Notifications authorized; device locked; next enabled prayer within 5 minutes
Steps:
  1. Lock device
  2. Wait for prayer time
Expected: Notification appears within ±5 seconds of scheduled time
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0021 (AC-0189) — Per-prayer enable toggle controls scheduling**
Type: Functional
Steps:
  1. Open Settings tab
  2. Disable Fajr; enable Asr
  3. Inspect pending notification requests (debug build with logging, or iOS Settings → Notifications)
Expected: No pending Fajr requests; Asr requests scheduled for next 7 days
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0022 (AC-0190) — Notification sound matches user's per-prayer adhaan selection**
Type: Functional · Preconditions: User has selected `adhaan_2` for Maghrib
Steps:
  1. Lock device
  2. Trigger Maghrib notification (clock change or actual prayer time)
Expected: Notification plays `adhaan_2_notif.caf` (≤30s clip), not the system default
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0023 (AC-0191) — Notification tap launches Prayer Times tab**
Type: Functional · Preconditions: App backgrounded; notification delivered
Steps:
  1. Tap delivered notification on Lock Screen
Expected: App opens directly to the Prayer Times tab (not Settings or Qiblah)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0024 (AC-0192) — Notifications survive day boundaries and settings changes**
Type: Regression
Steps:
  1. Authorize notifications on day N
  2. Leave device locked for 24+ hours
  3. Verify notifications fire on day N+1
  4. Change calculation method
  5. Verify newly scheduled notifications use the new method
Expected: All boundaries handled; method change propagates to schedule
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### US-0044 — iOS Widget Extension

**TC-0025 (AC-0193) — Widget appears in gallery**
Type: Functional
Steps:
  1. Long-press Home Screen → + → search "Iqamah"
Expected: Widget listed as "Iqamah — Next Prayer"
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0026 (AC-0194) — Small/medium families render correctly**
Type: Functional
Steps:
  1. Add small widget to Home Screen; observe
  2. Add medium widget; observe
Expected: Both show next prayer name and accurate countdown; no truncation or visual glitches
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0027 (AC-0195) — Lock Screen rectangular widget renders in light/dark modes**
Type: Functional
Steps:
  1. Customize Lock Screen → add Iqamah accessory rectangular widget
  2. Switch to a light wallpaper; verify legibility
  3. Switch to a dark wallpaper; verify legibility
Expected: Widget legible and correctly themed in both wallpaper variants
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0028 (AC-0196) — Widget transitions to next prayer within 1 minute of elapse**
Type: Functional · Preconditions: Widget installed; next prayer within 2 minutes
Steps:
  1. Wait until prayer time elapses
  2. Observe widget within 60 seconds after the elapse
Expected: Widget shows the *next* prayer (e.g. switches from Dhuhr to Asr)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0029 (AC-0197) — Widget reflects settings changes within 1 minute**
Type: Functional
Steps:
  1. Change calculation method in iOS app
  2. Wait up to 60 seconds
  3. Observe widget
Expected: Widget displays times derived from the new method
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### US-0045 — iOS Live Activity / Dynamic Island

**TC-0030 (AC-0198) — Live Activity starts at the 60-minute-before mark**
Type: Functional · Preconditions: Physical device with Dynamic Island; next enabled prayer 50–60 minutes away
Steps:
  1. Wait until 60 minutes before prayer time
  2. Observe Dynamic Island
Expected: Live Activity appears within 1 minute of the 60-min mark
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0031 (AC-0199) — Compact, expanded, and minimal Dynamic Island layouts render**
Type: Functional · Preconditions: Live Activity active
Steps:
  1. View compact (default) state
  2. Long-press the island to expand
  3. Open another app to put activity in minimal state
Expected: All three layouts show prayer name and live countdown without truncation
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0032 (AC-0200) — Lock Screen Live Activity card renders correctly**
Type: Functional · Preconditions: Live Activity active; device locked
Steps:
  1. Wake screen by tapping power button
Expected: Lock Screen card shows prayer name + accurate live countdown
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0033 (AC-0201) — Live Activity ends at prayer time without stale state**
Type: Functional · Preconditions: Live Activity active and within minutes of prayer time
Steps:
  1. Wait for prayer time to elapse
  2. Foreground the app
Expected: Live Activity dimmed at scheduled time (staleDate); removed entirely on next foreground sweep
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0034 (AC-0202) — Disabled prayer does not start a Live Activity**
Type: Negative · Preconditions: Asr disabled in Settings tab
Steps:
  1. Wait until 60 minutes before Asr
Expected: No Live Activity appears for Asr
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0035 (AC-0203) — No duplicate Live Activities for the same prayer**
Type: Edge Case
Steps:
  1. Foreground the app within 60 min of prayer
  2. Background the app
  3. Foreground again
  4. Repeat several cycles
Expected: At most one Live Activity active for the upcoming prayer at any time
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

### EPIC-0016 — ENH-0001 GPS Accuracy Finish-Up

#### US-0070 — Finish ENH-0001 across watchOS + Legacy Migration + Structural Cleanup

**TC-0036 (AC-0349) — Watch CLGeocoder refines locality and timezone**
Type: Functional · Preconditions: Apple Watch Series 11 simulator; Custom location set to Brampton (43.685, -79.759); fresh watch app install
Steps:
  1. Launch IqamahWatch app
  2. Allow location permission
  3. Wait ~3 seconds for CLGeocoder to resolve
  4. Inspect `SettingsManager.shared.gpsLocality` and `.gpsTimezone`
Expected: `gpsLocality` is "Brampton" (or nearest reverse-geocoded locality name); `gpsTimezone` is "America/Toronto"
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0037 (AC-0349) — Watch 5 km cache short-circuit suppresses redundant geocoding**
Type: Edge Case · Preconditions: Watch app already has `gpsLocality` populated; new GPS fix within 5 km of cached coordinate
Steps:
  1. Trigger a new location fix (e.g. tap "Update via GPS" in Settings)
  2. Inspect debug logs for `[ENH-0001]` CLGeocoder invocations
Expected: No new CLGeocoder request is made; existing `gpsLocality`/`gpsTimezone` values remain unchanged
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0038 (AC-0350) — Watch CLGeocoder failure retains Option-A values**
Type: Negative · Preconditions: Watch simulator with airplane mode (no network)
Steps:
  1. Launch IqamahWatch app
  2. Allow location permission
  3. Wait 5 seconds
  4. Inspect `gpsTimezone` and confirm no error UI displayed
Expected: `gpsTimezone` equals `TimeZone.current.identifier` (Option A fallback); no alert/banner shown to user; failure logged with `[ENH-0001]` tag
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0039 (AC-0351, AC-0352) — Legacy v1.5 user sees prompt once on macOS v1.6**
Type: Functional · Preconditions: macOS app UserDefaults with `hasCompletedSetup=true` but `locationSource` key absent; `didShowGPSReDetectPromptV16=false`
Steps:
  1. Reset state via `defaults delete com.fablesoft.iqamah locationSource && defaults delete com.fablesoft.iqamah didShowGPSReDetectPromptV16 && defaults write com.fablesoft.iqamah hasCompletedSetup -bool YES`
  2. Launch macOS app
  3. Observe alert
  4. Click "Keep current"
  5. Close and relaunch app
Expected: Alert appears exactly once on first launch; "Keep current" sets `locationSource="manual"` and `didShowGPSReDetectPromptV16=true`; second launch shows no alert
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0040 (AC-0351, AC-0352) — Legacy v1.5 user sees prompt once on iOS v1.6**
Type: Functional · Preconditions: Same legacy state as TC-0039, on iOS simulator
Steps:
  1. Reset state via `xcrun simctl spawn booted defaults ...` (equivalent to macOS reset)
  2. Launch iOS app
  3. Tap "Re-detect"
  4. Observe iOS Settings tab is opened (selectedTab=2)
  5. Force-quit and relaunch
Expected: Alert appears once; tapping "Re-detect" switches to Settings tab where re-detect controls live; second launch shows no alert
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0041 (AC-0354) — Dead Views/ deletion does not break any build**
Type: Regression · Preconditions: ENH-0001 finish-up branch checked out
Steps:
  1. `xcodebuild -project iqamah.xcodeproj -scheme iqamah build`
  2. `xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`
  3. `xcodebuild -project iqamah.xcodeproj -scheme IqamahWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build`
  4. `ls Views/ 2>&1`
Expected: All three schemes report BUILD SUCCEEDED; `ls Views/` returns "No such file or directory"
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0042 (AC-0355) — Watch view rename compiles and is reachable**
Type: Functional · Preconditions: ENH-0001 finish-up branch checked out
Steps:
  1. `grep -rn "WatchLocationSetupView" IqamahWatch/`
  2. `grep -rn "struct LocationSetupView" IqamahWatch/` (should return nothing)
  3. Build IqamahWatch scheme
  4. Launch watch app and verify location setup screen still renders correctly
Expected: WatchLocationSetupView is referenced in IqamahWatchApp.swift line 30; no legacy struct LocationSetupView remains in IqamahWatch/; build succeeds; screen renders identically to pre-rename behavior
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0043 (AC-0353, AC-0356) — Documentation updated**
Type: Functional · Preconditions: Final commit of ENH-0001 finish-up branch
Steps:
  1. `grep "✅ Implemented (2026-05-21)" docs/ENHANCEMENTS.md`
  2. `grep "Project Structure Conventions" CLAUDE.md`
  3. `grep "AC-0356" docs/ID_REGISTRY.md`
Expected: All three greps return at least one match; ENHANCEMENTS.md ENH-0001 section includes the surface-by-surface implementation table; CLAUDE.md section explains the duplicate-filename + PrayerActivityAttributes patterns
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

---

### EPIC-0017 — Fasting Mode (ENH-0002)

#### US-0071 — FastingModeEngine + settings schema

**TC-0044 (AC-0357) — FastingModeSettings round-trip preserves all fields**
Type: Functional · Preconditions: IqamahCore tests building
Steps:
  1. `cd Packages/IqamahCore && swift test --filter FastingModeSettingsCodecTests`
Expected: All 8 codec tests pass (default round-trip, populated round-trip, forward-compat decode, both warning helpers)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0045 (AC-0357) — Forward-compat decode applies defaults for missing fields**
Type: Edge Case
Steps:
  1. Decode legacy JSON that omits midShaban/mabath/dayBeforeMinute
  2. Verify decoded struct has expected default values
Expected: Decoded struct.midShaban == false; struct.mabath == false; struct.dayBeforeMinute == 0
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0046 (AC-0358) — FastingModeEngine.evaluate is pure**
Type: Functional
Steps:
  1. Call evaluate twice with identical input
Expected: Two calls return equal FastingDayState
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0047 (AC-0359) — autoRamadan + weeklySchedule fire correctly**
Type: Functional
Steps:
  1. With autoRamadan=true, evaluate a Ramadan date → trigger should be .autoRamadan
  2. With weeklyDays=[2] (Mon), evaluate a Monday → trigger should be .weeklySchedule
Expected: Both behaviors per spec
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0048 (AC-0360) — Ayyam al-Beed + 6 Shawwal fire correctly**
Type: Functional
Steps:
  1. With ayyamAlBeed=true, evaluate 13/14/15 of a non-Ramadan Hijri month → active
  2. With sixDaysShawwal=true, evaluate 2-7 Shawwal → active; day 8 → inactive
Expected: Both behaviors per spec
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0049 (AC-0361) — Arafah priority over firstNineDhulHijjah on day 9**
Type: Edge Case
Steps:
  1. Set dayOfArafah=true and firstNineDhulHijjah=true
  2. Evaluate 9 Dhul-Hijjah
Expected: state.trigger == .dayOfArafah (Arafah wins)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0050 (AC-0362) — muharramFast Sunni fires on 9+10 Muharram**
Type: Functional
Steps:
  1. With method=.muslimWorldLeague and muharramFast=true, evaluate 9 Muharram → active
  2. Same setup, evaluate 10 Muharram → active
  3. Same setup, evaluate 11 Muharram → inactive
Expected: 9 and 10 active; 11 inactive
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0051 (AC-0362) — muharramFast Shia fires on 9 Muharram only**
Type: Functional
Steps:
  1. With method=.tehran and muharramFast=true, evaluate 9 Muharram → active
  2. Same setup, evaluate 10 Muharram → inactive
Expected: 9 active, 10 inactive
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0052 (AC-0363) — midShaban visible+active for Shia methods**
Type: Functional
Steps:
  1. With method=.tehran and midShaban=true, evaluate 15 Sha'ban
Expected: state.trigger == .midShaban
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0053 (AC-0363) — midShaban suppressed for Sunni methods even when toggle is true**
Type: Functional
Steps:
  1. With method=.muslimWorldLeague and midShaban=true (stored), evaluate 15 Sha'ban
Expected: state.isActive == false (suppressed even though toggle is true)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0054 (AC-0364) — Eid al-Fitr suppresses sixDaysShawwal**
Type: Edge Case
Steps:
  1. With sixDaysShawwal=true, evaluate 1 Shawwal
Expected: state.isActive == false; state.prohibition == .eidAlFitr
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0055 (AC-0364) — Tashriq days 11-13 suppress ayyamAlBeed**
Type: Edge Case
Steps:
  1. With ayyamAlBeed=true, evaluate 11, 12, and 13 Dhul-Hijjah
Expected: All three return prohibition matching the day; isActive=false
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### US-0072 — UI Surfaces

**TC-0056 (AC-0365) — FastingLabelFormatter relabels within 2h, passes through outside**
Type: Functional
Steps:
  1. Active Ramadan state, Fajr 42 min away → "🌙 Suhoor"
  2. Active Ramadan state, Fajr 3 hours away → "Fajr" (passthrough)
  3. Active Nawafil state, Fajr 42 min away → "🕗 Suhoor"
Expected: All three behaviors per spec
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0057 (AC-0366) — FastingBanner renders active state with correct tinting**
Type: Functional · Preconditions: iOS or macOS app with Fasting Mode enabled
Steps:
  1. Trigger an active autoRamadan day; view PrayerHeroCard
  2. Trigger an active weeklySchedule day; view PrayerHeroCard
Expected: Ramadan day shows 🌙 + purple gradient; Nawafil day shows 🕗 + teal gradient
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0058 (AC-0367) — FastingBanner renders prohibition state in grey**
Type: Functional
Steps:
  1. Trigger a prohibition-day evaluation (Eid)
Expected: Banner shows ⚠️ + grey gradient + "Fasting is forbidden today" text
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0059 (AC-0368) — macOS menu bar relabel + popover banner**
Type: Functional · Preconditions: macOS app with Fasting Mode enabled, today is a fasting day
Steps:
  1. Verify menu bar shows "🌙 Suhoor" or "🕗 Suhoor" relabel when within 2h of Fajr
  2. Open popover; verify FastingBanner renders above prayer list
Expected: Relabel visible in menu bar; banner visible in popover
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0060 (AC-0369) — iOS hero banner + iOS row relabel + watch row relabel**
Type: Functional
Steps:
  1. iOS: verify FastingBanner above PrayerHeroCard on a fasting day
  2. iOS: verify PrayerRowMobileView shows relabel within 2h window
  3. watchOS: verify PrayerTimesTab row shows relabel within 2h window
Expected: All three surfaces behave correctly
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0061 (AC-0370) — Live Activity ContentState backward decode**
Type: Regression
Steps:
  1. Start a Live Activity on v1.5 ContentState (no fasting fields)
  2. Upgrade to v1.6
  3. Verify the in-flight activity does not crash; new fastingActive == nil
Expected: No crash; relabel does not apply (defaults to standard countdown)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### US-0073 — Settings UI

**TC-0062 (AC-0371) — Master toggle hides sub-controls when off**
Type: Functional
Steps:
  1. Open Settings → Fasting Mode section
  2. Toggle master OFF
Expected: All sub-controls disappear; only the master toggle remains visible
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0063 (AC-0372) — Tradition gating + Muharram label adaptation**
Type: Functional
Steps:
  1. Switch to Tehran method → Settings shows "Tasu'a (9 Muharram)" + Shia subtitle; 15 Sha'ban + 27 Rajab toggles appear
  2. Switch to MWL → label changes to "Ashura (9+10 Muharram)" + Sunni subtitle; Shia toggles disappear
Expected: Both adaptations per spec
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0064 (AC-0373) — Friday-alone + Saturday-alone warnings**
Type: Functional
Steps:
  1. Select only Friday in weekly picker → warning appears
  2. Add Thursday → warning clears
  3. Remove Thursday, add Saturday → warning clears
  4. Select only Saturday → Saturday-alone warning appears
  5. Add Friday → warning clears
Expected: All warning transitions per spec
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0065 (AC-0374) — Toggle persistence across method changes**
Type: Regression
Steps:
  1. With Tehran method, enable midShaban
  2. Switch to MWL → midShaban toggle hidden
  3. Inspect SettingsManager.fastingModeSettings.midShaban → still true
  4. Switch back to Tehran → midShaban toggle reappears, still on
Expected: Stored value preserved through method swap
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0066 (AC-0375) — watch Settings minimal UI**
Type: Functional
Steps:
  1. Open IqamahWatch Settings tab
Expected: Fasting Mode section shows master toggle + "Configure on iPhone/Mac" hint only; no sub-controls
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### US-0074 — Notifications

**TC-0067 (AC-0376) — Suhoor + Iftar lead-time arithmetic + range**
Type: Functional
Steps:
  1. Set suhoorLeadMinutes=30, schedule for Fajr=05:12 → notification fires at 04:42
  2. Set suhoorLeadMinutes=120 → notification fires at 03:12
  3. Set iftarLeadMinutes=15, Maghrib=20:32 → notification fires at 20:17
Expected: Fire dates match arithmetic
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0068 (AC-0377) — Day-before logic per Ramadan/Nawafil/prohibition**
Type: Functional
Steps:
  1. Tomorrow is 1 Ramadan → plan != nil
  2. Tomorrow is 2 Ramadan → plan == nil (skipped)
  3. Tomorrow is a scheduled Nawafil Monday → plan != nil
  4. Tomorrow is Eid → plan == nil
Expected: All four cases per spec
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0069 (AC-0378) — 7-day rolling window + 500ms debounce**
Type: Functional
Steps:
  1. Enable Fasting Mode + weekly = [2,5]
  2. Rapidly toggle additional weekdays (5 changes in 1 second)
  3. Wait 1 second
  4. Inspect pending notifications
Expected: Notifications reflect final state only (one reschedule occurred, not 5)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0070 (AC-0380) — Permission-denied deep link UI**
Type: Negative · Preconditions: Notifications denied in System Settings
Steps:
  1. Open Settings → Fasting Mode → Send system notifications row
  2. Tap "Enable in System Settings" link
Expected: Deep link opens Notifications preferences on the appropriate platform (iOS: Iqamah notification settings; macOS: System Settings Notifications pane)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### US-0075 — Ja'fari calculation method

**TC-0071 (AC-0381) — Ja'fari Maghrib timing matches reference**
Type: Functional
Steps:
  1. With method=.jafari, compute prayer times for Toronto on 2026-06-21 (summer solstice)
  2. Compare Maghrib to PrayTimes.org Ja'fari reference output for same coordinates/date
Expected: Maghrib time within ±1 minute of reference
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0072 (AC-0382) — isShiaMethod returns expected for all 7 methods**
Type: Functional
Steps:
  1. `cd Packages/IqamahCore && swift test --filter CalculationMethodJafariTests`
Expected: All Jafari tests pass — only .tehran and .jafari return true; all other methods return false
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### Multi-platform smoke

**TC-0073 — All schemes build clean after Fasting Mode merge**
Type: Regression
Steps:
  1. `cd Packages/IqamahCore && swift test`
  2. `xcodebuild -project iqamah.xcodeproj -scheme iqamah build`
  3. `xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS -destination 'generic/platform=iOS' build`
  4. `xcodebuild -project iqamah.xcodeproj -scheme IqamahWatch -destination 'generic/platform=watchOS' build`
  5. `xcodebuild -project iqamah.xcodeproj -scheme IqamahLiveActivity -destination 'generic/platform=iOS' build`
  6. `xcodebuild -project iqamah.xcodeproj -scheme IqamahWidget -destination 'generic/platform=iOS' build`
Expected: All commands succeed with BUILD SUCCEEDED / Test Suite passed
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

---

## Test Cases by Type

### Functional Tests
TC-0001, 0006, 0007, 0008, 0009, 0010, 0011, 0012, 0013, 0014, 0015, 0017, 0019, 0020, 0021, 0022, 0023, 0025, 0026, 0027, 0028, 0029, 0030, 0031, 0032, 0033, 0036, 0039, 0040, 0042, 0043, 0044, 0046, 0047, 0048, 0050, 0051, 0052, 0053, 0056, 0057, 0058, 0059, 0060, 0062, 0063, 0064, 0066, 0067, 0068, 0069, 0071, 0072

### Regression Tests
TC-0002, 0003, 0005, 0018, 0024, 0041, 0061, 0065, 0073

### Edge Case Tests
TC-0035, 0037, 0045, 0049, 0054, 0055

### Negative Tests
TC-0016, 0034, 0038, 0070

### Accessibility Tests
*[To be created — recommend covering VoiceOver labels for new iOS surfaces in a follow-up]*

### Performance Tests
*[To be created — recommend covering widget timeline build time and Live Activity request latency in a follow-up]*

---

## Rules (AGENTS.md §10)

- Every user story must have at least one test case covering its primary acceptance criterion
- Every acceptance criterion (AC-XXXX) must have a corresponding test case (TC-XXXX)
- Edge cases and negative paths must have their own uniquely identified test cases
- Test cases must be reviewed and updated whenever acceptance criteria change
- Failed test cases must raise a BUG-XXXX entry and be logged in `progress.md`
- Test case IDs are permanent — never reuse or renumber a TC-XXXX, even if deleted
- Mark deleted cases as `Status: Retired`

---

**Last Updated:** 2026-05-23 (TC-0044 through TC-0073 added covering EPIC-0017 / US-0071–US-0075 acceptance criteria)
