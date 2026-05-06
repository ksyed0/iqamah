# Release Plan

Detailed release plan defining MVP and subsequent milestones. Contains Epics, User Stories, Tasks, and Acceptance Criteria.

---

## Project Overview

**Project:** Iqamah — macOS Prayer Times Application  
**Current Version:** 0.1.0 (In Development)  
**Target MVP Release:** TBD (Q2 2026)

---

## Release Status

**Status:** 🟢 **PLANNING COMPLETE** — Ready to begin development

---

## Planned Releases

### **MVP v1.0.0 (Minimum Viable Product)**

**Target Date:** Q2 2026 (TBD)  
**Status:** 🟡 Ready to Start  
**Description:** Core prayer times functionality with location services, Qibla direction, and Hijri date display.

**Epics in MVP:**
- EPIC-0001: Location & City Selection
- EPIC-0002: Prayer Time Calculation & Display
- EPIC-0003: Qibla Direction Finder
- EPIC-0004: Testing & Quality Assurance

---

### **Release 1.1 (Future Enhancements)**

**Target Date:** Q3 2026  
**Status:** 🔴 Not Started  
**Description:** Adhan alerts, notifications, menu bar quick view

---

### **Release 1.2 (Future Enhancements)**

**Target Date:** Q4 2026  
**Status:** 🔴 Not Started  
**Description:** Internationalization (i18n), UI language selection, widgets

---

##EPIC-0001: Location & City Selection

**Description:** Enable users to determine their location either automatically via GPS or manually by selecting from a cities database.

**Release Target:** MVP v1.0.0  
**Status:** 🟡 Planned  
**Dependencies:** None

### User Stories in EPIC-0001

---

#### US-0001 (EPIC-0001): As a user, I want to grant location permission, so that the app can automatically detect my location for prayer times.

**Description:** Request CoreLocation permission and handle all authorization states gracefully.

**Priority:** High  
**Estimate:** 3 Story Points  
**Status:** 🟡 Planned  
**Dependencies:** None

**Acceptance Criteria:**
- [x] AC-0001: App requests location permission with clear explanation on first launch
- [x] AC-0002: Permission prompt uses standard iOS/macOS authorization dialog
- [x] AC-0003: Permission state persists between sessions
- [x] AC-0004: If denied, app shows actionable message directing user to System Settings
- [x] AC-0005: App handles authorization state changes (user enables/disables later)

**Definition of Ready (DOR):**
- [x] Story is understood and estimated
- [x] Acceptance criteria are defined and agreed
- [x] Dependencies are identified (none)
- [x] Design assets not required (system permission dialog)
- [x] No blockers exist to begin work

**Definition of Done (DOD):**
- [ ] All acceptance criteria are met
- [ ] Unit tests written and passing with ≥80% coverage
- [ ] Test cases created in TEST_CASES.md
- [ ] Code reviewed and approved
- [ ] No regressions introduced
- [ ] Accessibility audit passed (VoiceOver labels)
- [ ] Error handling implemented per ERROR_TAXONOMY.md
- [ ] No secrets or PII in code
- [ ] Documentation updated
- [ ] Session Close Protocol completed

---

#### US-0002 (EPIC-0001): As a user, I want to select my city from a database, so that I can use the app even if I deny location permission.

**Description:** Provide searchable cities database with countries, cities, coordinates, and timezones.

**Priority:** High  
**Estimate:** 5 Story Points  
**Status:** 🟢 Already Implemented  
**Dependencies:** None

**Acceptance Criteria:**
- [x] AC-0006: Cities database loaded from bundled cities.json
- [x] AC-0007: User can browse cities by country
- [x] AC-0008: User can search cities by name
- [x] AC-0009: Selected city persists between sessions via UserDefaults
- [x] AC-0010: Selected city syncs via iCloud to other devices

**Notes:** City selection functionality already exists in `Location.swift` and `CitiesLoader`. Needs testing and validation.

---

#### US-0003 (EPIC-0001): As a user, I want the app to suggest the closest city to my GPS location, so that I don't have to search manually.

**Description:** Auto-select nearest city from database when GPS location is available.

**Priority:** Medium  
**Estimate:** 3 Story Points  
**Status:** 🟢 Already Implemented  
**Dependencies:** US-0001, US-0002

**Acceptance Criteria:**
- [x] AC-0011: App calculates distance from GPS to all cities in database
- [x] AC-0012: Closest city is auto-selected on first launch with location permission
- [x] AC-0013: User can override auto-selected city with manual selection
- [x] AC-0014: Manual selection preference persists

**Notes:** `CitiesDatabase.closestCity(to:)` method already exists.

---

## EPIC-0002: Prayer Time Calculation & Display

**Description:** Calculate and display accurate Islamic prayer times based on user location and selected calculation methodology.

**Release Target:** MVP v1.0.0  
**Status:** 🟡 Planned  
**Dependencies:** EPIC-0001

### User Stories in EPIC-0002

---

#### US-0004 (EPIC-0002): As a user, I want to see accurate prayer times for my location, so that I know when to pray.
**Description:** Display 5 daily prayers + sunrise using astronomical calculations.

**Priority:** High (Critical)  
**Estimate:** 8 Story Points  
**Status:** 🟢 Already Implemented  
**Dependencies:** US-0001 or US-0002

**Acceptance Criteria:**
- [x] AC-0015: Display Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha times
- [x] AC-0016: Times calculated using PrayerCalculator with astronomical algorithms
- [x] AC-0017: Times display in user's local timezone
- [x] AC-0018: Times formatted in 12-hour format with AM/PM
- [x] AC-0019: Prayer times recalculate at midnight (day change)
- [x] AC-0020: Next prayer is highlighted with visual indicator

**Notes:** Core functionality already implemented in `PrayerCalculator.swift` and `PrayerTimesView.swift`.

---

#### US-0005 (EPIC-0002): As a user, I want to select my preferred calculation method, so that prayer times match my local mosque or school of thought.

**Description:** Support 6 recognized Islamic calculation methods with different Fajr/Isha angles.

**Priority:** High  
**Estimate:** 3 Story Points  
**Status:** 🟢 Already Implemented  
**Dependencies:** US-0004

**Acceptance Criteria:**
- [x] AC-0021: User can select from 6 calculation methods: MWL, ISNA, Egyptian, Umm Al-Qura, Karachi, Tehran
- [x] AC-0022: Each method uses correct Fajr and Isha angles
- [x] AC-0023: Umm Al-Qura uses 90-minute interval for Isha (not angle)
- [x] AC-0024: Tehran method uses Maghrib angle (4.5°)
- [x] AC-0025: Selected method persists between sessions
- [x] AC-0026: Prayer times update immediately when method changes

**Notes:** `CalculationMethod.swift` already implements all 6 methods.

---

#### US-0006 (EPIC-0002): As a user, I want to select my Asr calculation method (Standard or Hanafi), so that Asr time matches my juristic preference.

**Description:** Support two Asr calculation methods with different shadow factors.

**Priority:** Medium  
**Estimate:** 2 Story Points  
**Status:** 🟢 Already Implemented  
**Dependencies:** US-0004

**Acceptance Criteria:**
- [x] AC-0027: User can select Standard (Shafi'i/Maliki/Hanbali) or Hanafi method
- [x] AC-0028: Standard method uses shadow factor of 1.0
- [x] AC-0029: Hanafi method uses shadow factor of 2.0
- [x] AC-0030: Selected method persists between sessions
- [x] AC-0031: Asr time updates immediately when method changes

**Notes:** `AsrJuristicMethod.swift` already implements both methods.

---

#### US-0007 (EPIC-0002): As a user, I want to adjust individual prayer times by minutes, so that I can match my local mosque's iqamah times.

**Description:** Allow ±minute adjustments per prayer that persist between sessions.

**Priority:** High  
**Estimate:** 5 Story Points  
**Status:** 🟢 Already Implemented  
**Dependencies:** US-0004

**Acceptance Criteria:**
- [x] AC-0032: User can adjust each prayer time in 1-minute increments (+ or -)
- [x] AC-0033: Adjustment controls appear on hover over prayer row
- [x] AC-0034: Current adjustment value displayed in red next to prayer time
- [x] AC-0035: Adjustments persist via UserDefaults with iCloud sync
- [x] AC-0036: Adjustments apply to displayed time without changing calculation base
- [x] AC-0037: Reset option available to clear all adjustments

**Notes:** Adjustment functionality exists in `SettingsManager.swift` and `PrayerTimesView.swift`.

---

#### US-0008 (EPIC-0002): As a user, I want to see both Gregorian and Hijri dates, so that I know the Islamic date for today.

**Description:** Display current date in both Gregorian and Islamic Hijri calendars.

**Priority:** Medium  
**Estimate:** 3 Story Points  
**Status:** 🟢 Already Implemented  
**Dependencies:** None

**Acceptance Criteria:**
- [x] AC-0038: Gregorian date displayed in format "Weekday, Month Day, Year"
- [x] AC-0039: Hijri date displayed in format "Day MonthName Year AH"
- [x] AC-0040: Hijri month names displayed in English (or user's locale)
- [x] AC-0041: Dates update at midnight
- [x] AC-0042: Hijri calendar uses Umm Al-Qura calculation

**Notes:** Date formatting implemented in `PrayerCalculator.swift` extensions.

---

## EPIC-0003: Qibla Direction Finder

**Description:** Help users determine the Qibla direction (toward Ka'bah in Makkah) from their location using compass visualization.

**Release Target:** MVP v1.0.0  
**Status:** 🟡 Planned  
**Dependencies:** EPIC-0001

### User Stories in EPIC-0003

---

#### US-0009 (EPIC-0003): As a user, I want to see the Qibla direction from my location, so that I can pray in the correct direction.

**Description:** Calculate and display bearing from user location to Ka'bah coordinates.

**Priority:** High  
**Estimate:** 5 Story Points  
**Status:** 🟢 Already Implemented  
**Dependencies:** US-0001 or US-0002

**Acceptance Criteria:**
- [x] AC-0043: Qibla bearing calculated from user coordinates to Ka'bah (21.4225°N, 39.8262°E)
- [x] AC-0044: Bearing displayed in degrees (0-360°)
- [x] AC-0045: Cardinal direction displayed (N, NE, E, SE, S, SW, W, NW)
- [x] AC-0046: Compass visualization shows Qibla direction with green line
- [x] AC-0047: Prayer mat icon rotated to face Qibla
- [x] AC-0048: Ka'bah icon positioned at Qibla bearing on compass ring

**Notes:** Qibla calculation and visualization implemented in `QiblahView.swift`.

---

#### US-0010 (EPIC-0003): As a user, I want an intuitive compass interface for Qibla, so that I can easily understand the direction.

**Description:** Clean compass UI with visual indicators and labels.

**Priority:** Medium  
**Estimate:** 5 Story Points  
**Status:** 🟢 Already Implemented  
**Dependencies:** US-0009

**Acceptance Criteria:**
- [x] AC-0049: Compass displays cardinal directions (N, E, S, W)
- [x] AC-0050: Tick marks every 10 degrees (major every 90 degrees)
- [x] AC-0051: North marked in red for emphasis
- [x] AC-0052: Modal sheet presentation (380×480pt window)
- [x] AC-0053: Close button (X) in top-right corner

**Notes:** Compass design implemented with custom SwiftUI shapes.

---

## EPIC-0004: Testing & Quality Assurance

**Description:** Ensure all features meet quality standards with comprehensive testing, accessibility compliance, and performance validation.

**Release Target:** MVP v1.0.0  
**Status:** 🟡 In Progress  
**Dependencies:** EPIC-0001, EPIC-0002, EPIC-0003

**CI/QA completed 2026-05-03:**
- Issue #5 — cities.json schema validation CI job with `paths:` filter (PR #37)
- Issue #6 — Release .app bundle size budget check (50 MB limit) in CI (PR #38)
- Issue #4 — Prayer time accuracy regression test suite: 5 cities × 5 prayers, ±3 min tolerance (PR #39)

### User Stories in EPIC-0004

---

#### US-0011 (EPIC-0004): As a developer, I want comprehensive unit tests, so that code changes don't introduce regressions.

**Priority:** High (Critical)  
**Estimate:** 13 Story Points  
**Status:** ✅ Implemented  
**Dependencies:** US-0001 through US-0010

**Acceptance Criteria:**
- [x] AC-0052: Test suite achieves ≥80% code coverage
- [x] AC-0053: All prayer calculation methods tested against known values
- [x] AC-0054: Location service authorization flow tested
- [x] AC-0055: Settings persistence tested (save/load)
- [x] AC-0056: Qibla bearing calculation tested for accuracy
- [x] AC-0057: Date boundary transitions tested (midnight rollover)
- [x] AC-0058: Timezone handling tested
- [x] AC-0059: Edge cases tested (high latitudes, antipodal points)

---

#### US-0012 (EPIC-0004): As a user with disabilities, I want full accessibility support, so that I can use the app with VoiceOver and other assistive technologies.

**Priority:** High  
**Estimate:** 5 Story Points  
**Status:** 🔴 Not Started  
**Dependencies:** US-0001 through US-0010

**Acceptance Criteria:**
- [ ] AC-0060: All interactive elements have VoiceOver labels
- [ ] AC-0061: Tab order is logical and complete
- [ ] AC-0062: Keyboard shortcuts available for primary actions
- [x] AC-0063: Color contrast meets WCAG 2.1 AA (4.5:1 minimum)
- [x] AC-0064: Dynamic Type supported (text scales with system settings)
- [x] AC-0065: No information conveyed by color alone

---

#### US-0013 (EPIC-0004): As a developer, I want performance benchmarks, so that the app remains fast and responsive.

**Priority:** Medium  
**Estimate:** 3 Story Points  
**Status:** 🔴 Not Started  
**Dependencies:** US-0001 through US-0010

**Acceptance Criteria:**
- [x] AC-0066: Prayer time calculation completes in <100ms
- [x] AC-0067: City database loads in <500ms
- [x] AC-0068: UI updates complete in <50ms
- [x] AC-0069: Memory usage stays below 100MB
- [x] AC-0070: App launches in <2 seconds on macOS 12.0

---

## User Stories NOT in MVP (Future Releases)

---

#### US-0014: As a user, I want adhan (call to prayer) audio alerts, so that I'm reminded when it's time to pray.

**Priority:** Medium  
**Status:** ✅ Implemented in v1.0  
**Notes:** Implemented in EPIC-0007. `AppDelegate` polls every 60s and fires `AdhaaanPlayer.shared.play()` + `AdhaanBannerController.shared.show()` within a 90s window after each prayer time. Per-prayer adhaan selection (including Fajr-specific recordings) persists via UserDefaults. Was incorrectly marked as deferred.

---

#### US-0015: As a user, I want a menu bar quick view, so that I can see next prayer time without opening the full app.

**Priority:** Medium  
**Status:** 🟡 Partially implemented in v1.0 — countdown only  
**Notes:** Menu bar status item shows countdown to next prayer (turns red < 10 min) and right-click menu with "Show Prayer Times" / Help / Privacy / Quit. A full popover showing all 6 prayer times inline from the status bar is **not** implemented — deferred to v1.1 if desired (P3).

---

#### US-0016 (Future — Release 1.2): As a user, I want to switch the app language (i18n), so that I can use the app in my preferred language.

**Priority:** Low  
**Status:** 🔴 Deferred to v1.2

---

#### US-0017 (Future — Release 1.2): As a user, I want macOS widgets, so that I can glance at prayer times from my desktop or Notification Center.

**Priority:** Low  
**Status:** 🔴 Deferred to v1.2

---

## Summary Statistics

**Total Epics:** 4 (MVP) + future enhancements  
**Total User Stories:** 13 (MVP) + 4 (future)  
**Total Acceptance Criteria:** 70 (AC-0001 through AC-0070)

**MVP User Stories by Status:**
- 🟢 Already Implemented: 8 (US-0002, US-0003, US-0004, US-0005, US-0006, US-0007, US-0008, US-0009, US-0010)
- 🟡 Planned: 2 (US-0001, US-0011)
- 🔴 Not Started: 3 (US-0011, US-0012, US-0013)

**Next Immediate Actions:**
1. Create test suite for US-0011 (Testing & QA)
2. Conduct accessibility audit for US-0012
3. Establish performance baselines for US-0013
4. Verify all implemented features meet their acceptance criteria
5. Create test cases in TEST_CASES.md for all user stories

---

---

## EPIC-0005: App Store Submission Readiness

**Description:** All work required to prepare Iqamah for a successful first submission to the Mac App Store as a free app. Covers compilation blockers, legal requirements, UX polish, and metadata.

**Release Target:** v1.0.0  
**Status:** 🔴 In Progress  
**Dependencies:** EPIC-0001, EPIC-0002, EPIC-0003

---

### US-0018 (EPIC-0005): As a developer, I want the app to have a v1.0 release identity, so that it presents professionally on the Mac App Store.

**Priority:** Critical  
**Estimate:** 1 Story Point  
**Status:** ✅ Implemented  
**Related Bugs:** BUG-0012, BUG-0013

**Acceptance Criteria:**
- [x] AC-0071: `MARKETING_VERSION` is set to `1.0` in project build settings
- [x] AC-0072: `CURRENT_PROJECT_VERSION` (build number) is set to `1`
- [x] AC-0073: `iqamah.entitlements` contains `com.apple.security.personal-information.location = true`
- [x] AC-0074: `Info.plist` contains `NSLocationWhenInUseUsageDescription` with a user-friendly explanation string
- [ ] AC-0075: App bundle ID `com.iqamah.app` is registered in App Store Connect
- [x] AC-0076: App compiles without warnings in Release configuration targeting macOS 14.0

---

### US-0019 (EPIC-0005): As a returning user, I want the splash screen to be brief and skippable, so that I can access my prayer times quickly.

**Priority:** High  
**Estimate:** 2 Story Points  
**Status:** ✅ Implemented  
**Related Bugs:** BUG-0003 (10-second splash)

**Acceptance Criteria:**
- [x] AC-0077: Splash screen displays for no longer than 2 seconds for all users
- [x] AC-0078: Returning users (hasCompletedSetup == true) are shown splash for ≤1 second, then jump directly to PrayerTimesView
- [x] AC-0079: Splash screen is skippable by clicking anywhere on it
- [x] AC-0080: Splash-to-content transition uses a smooth cross-dissolve animation ≤300ms

---

### US-0020 (EPIC-0005): As a user, I want a Settings sheet accessible from the prayer times view, so that I can change my city or calculation method without losing my saved data.

**Priority:** High  
**Estimate:** 5 Story Points  
**Status:** ✅ Implemented  
**Note:** Previously the gear icon triggered `resetSettings()` + full re-onboarding, destroying all saved adjustments.

**Acceptance Criteria:**
- [x] AC-0081: Tapping the gear icon opens a modal Settings sheet (does not navigate away or reset data)
- [x] AC-0082: Settings sheet allows changing country/city without affecting calculation method or prayer adjustments
- [x] AC-0083: Settings sheet allows changing calculation method and Asr jurisprudence without affecting city or adjustments
- [x] AC-0084: "Save" in Settings sheet persists all changes and dismisses the sheet
- [x] AC-0085: "Cancel" in Settings sheet discards all changes
- [x] AC-0086: After saving, prayer times recalculate immediately with new settings
- [x] AC-0087: All per-prayer minute adjustments are preserved when city or method is changed

---

### US-0021 (EPIC-0005): As a developer, I want a Privacy Policy URL available, so that the App Store submission can be completed.

**Priority:** Critical  
**Estimate:** 1 Story Point  
**Status:** ✅ Draft Created (`Privacy_Policy.md` in repo root)

**Acceptance Criteria:**
- [ ] AC-0088: `Privacy_Policy.md` exists in the repository with complete policy text
- [ ] AC-0089: Policy is hosted at a publicly accessible URL (e.g., GitHub Pages or similar)
- [ ] AC-0090: Privacy policy URL is entered in App Store Connect before submission
- [ ] AC-0091: Policy accurately states that no personal data is collected or transmitted

---

### US-0022 (EPIC-0005): As a user in a 24-hour time region, I want to choose between 12-hour and 24-hour time display, so that prayer times are shown in my preferred format.

**Priority:** Medium  
**Estimate:** 3 Story Points  
**Status:** ✅ Implemented

**Acceptance Criteria:**
- [x] AC-0092: A 12h/24h toggle is available in the Settings sheet (US-0020)
- [x] AC-0093: Selecting 24-hour mode changes all prayer time displays in PrayerTimesView to `HH:mm` format
- [x] AC-0094: Selecting 24-hour mode changes the status bar display to `HH:mm` format
- [x] AC-0095: The time format preference persists across app restarts via UserDefaults
- [x] AC-0096: Default format is 12-hour (`h:mm a`)

---

### US-0023 (EPIC-0005): As a developer, I want window sizing to be consistent, so that the app opens at the correct size and does not jump when transitioning from splash to prayer times.

**Priority:** Medium  
**Estimate:** 1 Story Point  
**Status:** ✅ Implemented  
**Note:** `iqamahApp.swift` declares `defaultSize(width: 450, height: 500)` but `PrayerTimesView` requires `minWidth: 580, minHeight: 640`.

**Acceptance Criteria:**
- [x] AC-0097: `iqamahApp.swift` `defaultSize` matches the `PrayerTimesView` minimum size
- [x] AC-0098: The window does not resize abruptly when `PrayerTimesView` first appears
- [x] AC-0099: Window respects the declared `maxSize` of 620×680 and cannot be enlarged beyond it

---

### US-0024 (EPIC-0005): As a developer, I want all compilation bugs fixed, so that the app builds without errors in both Debug and Release configurations.

**Priority:** Critical  
**Estimate:** 2 Story Points  
**Status:** ✅ Implemented  
**Related Bugs:** BUG-0010, BUG-0011, BUG-0014, BUG-0015, BUG-0016

**Acceptance Criteria:**
- [x] AC-0100: BUG-0010 fixed — `LocationSetupView.loadDatabase()` handles `Result<CitiesDatabase, IqamahError>` correctly
- [x] AC-0101: BUG-0011 fixed — `PrayerTimesView.timerSubscription` declared as `Cancellable?` and stores `timer.connect()` without casting
- [x] AC-0102: BUG-0014 fixed — `AppDelegate.statusBarButtonClicked` uses `guard let event = NSApp.currentEvent` 
- [x] AC-0103: BUG-0015 fixed — `isNextPrayer()` applies per-prayer adjustments before comparing against current time
- [x] AC-0104: BUG-0016 fixed — `PrayerTimeRow` uses a timezone-correct `DateFormatter` (timezone passed from parent)
- [x] AC-0105: App builds with zero errors and zero warnings in Release configuration

---

## Updated Summary Statistics

**Total Epics:** 5  
**Total User Stories:** 24  
**Total Acceptance Criteria:** 105 (AC-0001 through AC-0105)

**EPIC-0005 Stories:** 7 (US-0018 through US-0024)  
**EPIC-0005 Acceptance Criteria:** 35 (AC-0071 through AC-0105)

---

---

## EPIC-0006: Live UI Design Review Fixes

**Description:** Improvements identified during live screen-by-screen review of the running app on 2026-04-30. Covers splash text collision, window sizing, header icon, onboarding UX, and Qiblah improvements.

**Release Target:** v1.0.0  
**Status:** 🟡 In Progress (BUG-0017, BUG-0020, BUG-0021 already fixed in code)  
**Dependencies:** EPIC-0005

---

### US-0025 (EPIC-0006): As a first-time user, I want the splash screen to look polished and readable, so that my first impression of the app is positive.

**Priority:** Critical  
**Estimate:** 2 Story Points  
**Status:** ✅ Implemented  
**Related Bugs:** BUG-0017 (fixed)

**Acceptance Criteria:**
- [x] AC-0106: `splash.jpg` is generated from the high-resolution mosque photo (`splash_full.png`) — no generic placeholder
- [x] AC-0107: "Iqamah" title rendered in gold SFNS 68pt with shadow, centred in the dark top gradient zone
- [x] AC-0108: Arabic "إقامة" rendered by SwiftUI `Text()` using CoreText — correct Arabic shaping, no placeholder boxes
- [x] AC-0109: Dark translucent panel in the lower 44% of the image contains the charity message with a gold rule border
- [x] AC-0110: No text-on-text collision — image and SwiftUI overlay text occupy distinct zones
- [ ] AC-0111: Splash duration reduced to ≤2 seconds (still 10s in ContentView — see BUG-0003 / US-0019)

---

### US-0026 (EPIC-0006): As a user on Location Setup, I want clear feedback that GPS detected my city, so that I trust the auto-selected values.

**Priority:** High  
**Estimate:** 2 Story Points  
**Status:** ✅ Implemented

**Acceptance Criteria:
- [x] AC-0112: When GPS auto-detects and sets a city, a "📍 Location detected" badge appears near the Country/City pickers within 500ms of detection
- [x] AC-0113: Badge disappears if the user manually changes the Country selection
- [x] AC-0114: If GPS fails or is denied, the pickers show empty with an explanatory message (not silent empty dropdowns)
- [x] AC-0115: Country and City pickers are the same width (300pt max, full-width within their container)
- [x] AC-0116: Dead space between pickers and Continue button is filled — content block is vertically centred in the window

---

### US-0027 (EPIC-0006): As a user in onboarding, I want step indicators and a Back button, so that I can navigate the setup flow without feeling trapped.

**Priority:** High  
**Estimate:** 3 Story Points  
**Status:** ✅ Implemented

**Acceptance Criteria:
- [x] AC-0117: Both Location Setup and Calculation Settings screens show a step indicator ("Step 1 of 2", "Step 2 of 2")
- [x] AC-0118: Calculation Settings screen has a Back button that returns to Location Setup without losing the selected city
- [x] AC-0119: Calculation Settings dropdown includes a region hint for each method (e.g., "North America", "Middle East", "South Asia")
- [x] AC-0120: Asr options include a one-line description: "Earlier Asr" (Standard) and "Later Asr" (Hanafi)

---

### US-0028 (EPIC-0006): As a user, I want the Sunrise row to be visually distinct from the five prayers, so that I don't try to set an iqamah for it.

**Priority:** Medium  
**Estimate:** 1 Story Point  
**Status:** ✅ Implemented

**Acceptance Criteria:
- [x] AC-0121: The Sunrise row renders at smaller font size (14pt vs 17pt for prayers) and secondary text colour
- [x] AC-0122: The Sunrise row has no ± adjustment controls (sunrise is an astronomical event, not a prayer)
- [x] AC-0123: The Sunrise row icon uses `.sunrise.fill` at reduced opacity to further de-emphasise it

---

### US-0029 (EPIC-0006): As a user, I want the prayer times header to show the real app icon, so that the branding is consistent.

**Priority:** High  
**Estimate:** 1 Story Point  
**Status:** ✅ Implemented  
**Related Bugs:** BUG-0018

**Acceptance Criteria:**
- [x] AC-0124: The header icon uses `NSImage(named: NSImage.applicationIconName)` — the compiled asset — not the rendered `AppIconView`
- [x] AC-0125: Icon renders clearly at 36×36pt with a rounded-rect clip
- [x] AC-0126: App icon asset (`AppIcon.appiconset`) is fully populated from `app_icon_full.png` at all required sizes (✅ done)

---

### US-0030 (EPIC-0006): As a user, I want the Qiblah compass to be clear and usable with the real prayer mat and Ka'bah images, so that the direction is immediately understood.

**Priority:** High  
**Estimate:** 3 Story Points  
**Status:** ✅ Mostly Implemented  
**Related Bugs:** BUG-0020 (fixed), BUG-0021 (fixed)

**Acceptance Criteria:**
- [x] AC-0127: Prayer mat uses the real asset from `PrayerMat.imageset` (1x/2x from `prayer_mat_full.png`), not the custom `PrayerMatShape`
- [x] AC-0128: Prayer mat is 40×60pt — small enough that the compass ring is clearly readable
- [x] AC-0129: Ka'bah marker uses `KaabahIcon.imageset` (1x/2x resized from `Kaaba_full.png` at 28×28pt), replacing the programmatic `KaabahMarker` SwiftUI view
- [x] AC-0130: Compass sheet is 420×520pt (enlarged from 380×480)
- [x] AC-0131: Compass ring is 280pt diameter (enlarged from 260pt)
- [x] AC-0132: Tick marks reduced to every 30° (12 total) from every 10° (36 total) — less visual noise
- [x] AC-0133: Sheet dismissed via "Done" button at bottom, not floating X in corner
- [x] AC-0134: "From [City name]" subtitle shown below the bearing text (e.g., "From Toronto")
- [x] AC-0135: Header button in PrayerTimesView uses `Image("PrayerMat")` from asset catalogue — clearly recognisable

---

---

### US-0031 (EPIC-0006): As a user selecting my location, I want the app to pre-select the calculation method most commonly used in my country, so that I don't have to know which method applies to my region.

**Priority:** High  
**Estimate:** 2 Story Points  
**Status:** ✅ Implemented

**Background:**  
Different countries and regions use established calculation methods endorsed by local Islamic authorities. Requiring a user to pick "Umm Al-Qura University, Makkah" from a list when they simply live in Saudi Arabia creates unnecessary friction. When the user selects their country on Location Setup, the Calculation Settings screen should open with the correct method already selected.

**Country → Method Mapping (exhaustive):**

| Region / Countries | Recommended Method |
|---|---|
| USA, Canada | ISNA (Islamic Society of North America) |
| UK, Ireland, most of Western Europe | Muslim World League (MWL) |
| Egypt, Sudan, Libya, Algeria, Tunisia, Morocco, Jordan, Palestine | Egyptian General Authority of Survey |
| Saudi Arabia, UAE, Qatar, Bahrain, Kuwait, Yemen, Oman | Umm Al-Qura (Makkah) |
| Pakistan, Afghanistan, Bangladesh, India | University of Islamic Sciences, Karachi |
| Iran | Institute of Geophysics, Tehran |
| Turkey, Central Asia, most other countries | Muslim World League (MWL) — safe default |

**Acceptance Criteria:**
- [x] AC-0136: `CalculationMethod` gains a `static func suggested(forCountryCode: String) -> CalculationMethod` that returns the regionally appropriate method
- [x] AC-0137: Mapping covers at minimum: US/CA → ISNA; GB/EU → MWL; EG/MA/DZ/TN/LY/JO/PS → Egypt; SA/AE/QA/BH/KW/YE/OM → UmmAlQura; PK/AF/BD/IN → Karachi; IR → Tehran; all others → MWL
- [x] AC-0138: When the user confirms their country on Location Setup, the `calculationMethod` binding is pre-populated with the result of `suggested(forCountryCode:)` before navigating to Calculation Settings
- [x] AC-0139: The Calculation Settings screen clearly labels the pre-selected method as "Recommended for [Country Name]" in a caption below the picker
- [x] AC-0140: The user can override the pre-selected method by choosing any other option — the label disappears once they change it
- [x] AC-0141: Pre-selection only fires on first setup; changing city later (via Settings sheet) does not silently override a method the user has previously customised

---

## Updated Summary Statistics

**Total Epics:** 6  
**Total User Stories:** 31  
**Total Acceptance Criteria:** 141 (AC-0001 through AC-0141)

**EPIC-0006 Stories:** 7 (US-0025 through US-0031)  
**EPIC-0006 Acceptance Criteria:** 36 (AC-0106 through AC-0141)

---

**Last Updated:** 2026-04-30 (US-0031 added — calculation method country auto-mapping)


---

---

## EPIC-0007: Adhaan Sound Selection & Preview

**Description:** Allow users to assign a specific Adhaan recording or alert tone to each prayer, with Fajr getting its own Fajr-specific Adhaan category (which includes "As-salatu khayrun minan nawm"). Each selection can be previewed in-place before saving.

**Release Target:** v1.0.0  
**Status:** ✅ Implemented — 2026-04-30  
**Dependencies:** EPIC-0002 (Prayer Times Display)

---

### US-0032 (EPIC-0007): As a user, I want to choose an Adhaan or alert tone for each prayer and preview it before saving, so that I hear the correct call at the right time.

**Priority:** High  
**Estimate:** 5 Story Points  
**Status:** ✅ Implemented

**Background:**  
The Fajr Adhaan is liturgically distinct from the Adhaan for other prayers — it includes the additional phrase "As-salatu khayrun minan nawm" (Prayer is better than sleep), which is not said in any other Adhaan. The app therefore separates standard Adhaan recordings (valid for all 5 prayers) from Fajr-specific recordings (valid for Fajr only). Users can also choose from gentle alert tones (Glass Bell, Soft Ping, etc.) or select Silent.

**Acceptance Criteria:**
- [x] AC-0142: Each prayer row (Fajr, Dhuhr, Asr, Maghrib, Isha) shows an Adhaan picker on hover or when a non-silent Adhaan is selected
- [x] AC-0143: Picker options include: Silent → Alert Tones (5) → Adhaan 1–5 for standard prayers
- [x] AC-0144: Fajr prayer picker additionally includes "Fajr Adhaan 1–3" at the end (these include "As-salatu khayrun minan nawm")
- [x] AC-0145: A preview play/stop button appears next to the picker when a non-silent Adhaan is selected
- [x] AC-0146: Preview plays audio even when the global mute toggle is on (preview is explicitly user-initiated)
- [x] AC-0147: Tapping the preview button while audio is playing stops it (toggle behaviour)
- [x] AC-0148: Starting a new preview automatically stops any currently playing preview
- [x] AC-0149: When audio finishes naturally, the play button returns to its default state without user interaction
- [x] AC-0150: Adhaan selection persists between app launches via UserDefaults (existing `prayerAdhaanIds` key)
- [x] AC-0151: Audio files are bundled in the app: `adhaan_1–5.mp3` (standard) and `adhaan_fajr_1–3.mp3` (Fajr-specific)
- [x] AC-0152: `AdhaaanPlayer.play(_:)` respects the global mute state; `preview(_:)` ignores it

**Implementation Notes:**
- `Adhaan.swift` — `adhaanFajrRecordings` scans bundle for `adhaan_fajr_1…5`; `availableForFajr` combines all categories
- `AdhaaanPlayer.swift` — conforms to `AVAudioPlayerDelegate`; `@Published var isPlaying` updates UI reactively; `nonisolated audioPlayerDidFinishPlaying` hops back to `@MainActor` via `Task`
- `PrayerTimesView.swift` (`PrayerTimeRow`) — `adhaanOptions` computed from `name == "Fajr"` check; preview button observes `player.isPlaying`

---

## Updated Summary Statistics (as of 2026-04-30)

**Total Epics:** 7  
**Total User Stories:** 32  
**Total Acceptance Criteria:** 152 (AC-0001 through AC-0152)

**EPIC-0007 Stories:** 1 (US-0032)  
**EPIC-0007 Acceptance Criteria:** 11 (AC-0142 through AC-0152)

---

## App Store Submission Checklist (2026-04-30)

### Code Complete ✅
All features implemented and Release build succeeds with zero errors.

### Must-Do Before Submission

| Item | Status | Notes |
|------|--------|-------|
| Remove dev `.md` docs from app bundle (BUG-0031) | ❌ Open | 8 files in Copy Resources phase must be removed |
| Add `PrivacyInfo.xcprivacy` (BUG-0032) | ❌ Open | Required for UserDefaults API; ITMS-91053 rejection without it |
| Host Privacy Policy publicly (BUG-0033) | ❌ Open | Need public URL for App Store Connect |
| Register `com.iqamah.app` in App Store Connect (BUG-0034) | ❌ Open | Create app record before uploading build |
| Full VoiceOver accessibility audit (BUG-0009) | ⚠️ Partial | Many labels added; full sweep still needed |

### Already Done ✅
- Release build succeeds with zero errors and zero warnings
- App Sandbox entitlements correct (location + no network)
- Info.plist auto-generated with location usage description
- Bundle ID `com.iqamah.app` set; Team `96Y29SP9JR` set
- All prayer calculation, display, and adjustment features working
- Adhaan sound selection with 8 bundled MP3s + 5 alert tones
- Settings sheet (non-destructive), 24-hour time, Hijri date, Qiblah compass
- Status bar menu with countdown and red urgency highlight

---

**Last Updated:** 2026-04-30 (EPIC-0007 Adhaan sounds added; App Store submission checklist added)


---

## EPIC-0008: Post-MVP Bug Fixes & UX Improvements (2026-05-01 – 2026-05-03)

**Status:** 🟡 In Progress

---

### US-0033 — Menu bar agent stability

**Status:** ✅ Implemented (merged PR #35)

- **BUG:** Right-click → "Show Prayer Times" and "Quit Iqamah" had no effect — `NSMenuItem` without `.target` in a status bar menu silently discards its action selector (no responder chain in status bar context).  
- **FIX:** Set `showItem.target = self` and `quitItem.target = self` explicitly.

- **BUG:** App did not appear in Cmd+Tab switcher when main window was open — `LSUIElement = YES` in Info.plist is a process-level OS flag that prevents `setActivationPolicy(.regular)` from fully registering the app in the Cmd+Tab switcher at runtime.  
- **FIX:** Removed `INFOPLIST_KEY_LSUIElement` from both build configs; call `setActivationPolicy(.accessory)` in `applicationDidFinishLaunching` instead. App now toggles `.regular` (window open) / `.accessory` (window closed) seamlessly.

---

### US-0034 — UI Design Refresh: Option B secondary toolbar + light mode

**Status:** 🟡 In Progress (PR open, CI running)

**Acceptance Criteria:**
- [x] Primary header trimmed to: app icon + "Iqamah" wordmark + city name + abbreviated method + mute button (4 elements vs. 7)
- [x] Secondary toolbar below header contains: Qiblah / Settings / About as flat hover-highlight buttons (macOS toolbar convention)
- [x] Hijri date moved into secondary toolbar right-aligned
- [x] Gregorian date stands alone as single-line `subheadline.bold()`
- [x] `CalculationMethod.shortName` computed property for abbreviated display (ISNA, MWL, Egyptian, etc.)
- [x] `SecondaryToolbarButton` component: SF symbol + label, no border, hover background via semantic `quaternaryLabelColor`
- [x] Shadow uses `Color.primary.opacity()` — adapts light/dark automatically
- [ ] Full light mode pass on remaining hardcoded dark values (future follow-up)

---

**Last Updated:** 2026-05-03


---

## EPIC-0009: App Store Resubmission — v1.0 (2026-05-05)

**Description:** Work required following the first App Store rejection. Two separate rejection reasons must be resolved before resubmitting: a technical entitlement error (Guideline 2.4.5i) and an information request (Guideline 2.1). Additionally, UI issues identified during review must be fixed before the next archive.

**Release Target:** v1.0 (resubmission)
**Status:** 🟡 In Progress
**Dependencies:** EPIC-0005

---

### US-0035 — Fix invalid entitlement (BUG-0051) ✅

**Status:** ✅ Fixed — merged PR #47 to `develop` @ `7bb12fa`

**Rejection:** Guideline 2.4.5(i) — `com.apple.security.network.client = false` is invalid.

**What was wrong:** `iqamah.entitlements` contained `com.apple.security.network.client` set to `<false/>`. Apple's sandbox treats entitlement keys as grants — a key set to `false` is a malformed declaration. Iqamah makes no network requests so the key should not exist at all.

**Fix applied:** Removed `com.apple.security.network.client` entirely. Entitlements file now contains only:
- `com.apple.security.app-sandbox = true`
- `com.apple.security.personal-information.location = true`

**Acceptance Criteria:**
- [x] AC-0153: `iqamah.entitlements` has exactly two keys, both set to `<true/>`
- [x] AC-0154: No entitlement key is set to `<false/>`
- [x] AC-0155: Release build succeeds with updated entitlements

---

### US-0036 — Provide App Review information (Guideline 2.1) ⚠️

**Status:** ❌ Pending — manual action required in App Store Connect

**Rejection:** Guideline 2.1 — Apple requested a screen recording and app details.

**Action required — fill in App Store Connect → App Review Information → Notes:**

```
APP OVERVIEW
Iqamah is a macOS menu bar prayer times app for Muslims. It calculates
the five daily Islamic prayer times using classical astronomical algorithms,
displays a countdown to the next prayer in the menu bar, and optionally
plays an adhaan sound at prayer time. No account required. Fully offline.

TESTED DEVICES & OS
- MacBook Pro 14-inch (M3, Nov 2024), macOS 26.3

SETUP INSTRUCTIONS
1. Launch the app — a brief splash screen appears
2. Select your country and city (or allow location detection)
3. Select your calculation method (MWL is the default)
4. The main window shows all six daily prayer times
5. A countdown to the next prayer appears in the menu bar
No login credentials required. No account of any kind.

CORE FEATURES
- Menu bar countdown to next prayer
- Six calculation methods (MWL, ISNA, Egypt, Umm Al-Qura, Karachi, Tehran)
- Per-prayer adhaan sound selection from bundled MP3 library
- Qiblah compass showing direction of Mecca
- Hijri (Islamic) calendar date display
- ±1 minute per-prayer adjustment
- Appearance switcher (Light/Dark/System)
- Launch at login

EXTERNAL SERVICES
None. The app is 100% offline. Prayer times are calculated on-device
using astronomical algorithms. No APIs, no data providers, no analytics,
no payment processors, no AI services.

LOCATION PERMISSION
The app requests location access only to auto-detect the nearest city.
The permission prompt appears on the Location Setup screen. Location is
optional — users may manually select their city instead.

REGIONAL DIFFERENCES
None. The app functions identically in all regions.

REGULATED CONTENT
The app is a utility for Islamic religious practice. It does not provide
religious rulings, legal advice, financial advice, or medical advice.
```

**Screen recording required (upload to App Review Information):**
Record on Mac using QuickTime Player → New Screen Recording. Show:
1. App launch → splash screen
2. Location Setup → select city
3. Calculation method selection → Continue
4. Main prayer times view — click adhaan column on a prayer
5. Open Settings sheet
6. Open Qiblah compass
7. Menu bar icon showing countdown
Keep under 3 minutes.

**Acceptance Criteria:**
- [ ] AC-0156: Notes field in App Review Information is filled with the text above
- [ ] AC-0157: Screen recording (≤3 min) uploaded to App Review Information showing full first-launch flow
- [ ] AC-0158: Notes saved in App Store Connect before resubmitting build

---

### US-0037 — Fix UI issues before resubmission (BUG-0052, 0053, 0054) ❌

**Status:** ❌ Open — code fixes needed

**Issues to fix before archiving next build:**

#### Task 1 — Remove top gap above header (BUG-0054)
**File:** `iqamah/Views/PrayerTimesView.swift:72`
```swift
// Change:
.padding(.top, 46)
// To:
.padding(.top, 16)
```

#### Task 2 — Increase header icon and text sizes (BUG-0052)
**File:** `iqamah/Views/PrayerTimesView.swift`
- Icon: `.frame(width: 32, height: 32)` → `.frame(width: 64, height: 64)` (line 30)
- App name font base: `titleFontSize: CGFloat = 20` → `28` (line 20)
- City name: `.font(.subheadline.weight(.semibold))` → `.font(.title3.weight(.semibold))` (line 48)
- Method: `.font(.caption2.weight(.medium))` → `.font(.caption.weight(.medium))` (line 52)
- Hijri date: `.font(.caption)` → `.font(.subheadline)` (line 104)

#### Task 3 — Match Sunrise text size to prayer rows (BUG-0053)
**File:** `iqamah/Views/PrayerTimesComponents.swift`
```swift
// SunriseRow — change all three .callout instances:
Image → .font(.body)           // icon (line 14)
Text("Sunrise") → .font(.body) // label (line 18)
Text(time) → .font(.title3.weight(.medium)) // time (line 23)
```

**Acceptance Criteria:**
- [ ] AC-0159: No visible gap between window top edge and app icon
- [ ] AC-0160: App icon renders at 64×64pt in header
- [ ] AC-0161: App name, city, method, and Hijri date are noticeably larger than before
- [ ] AC-0162: Sunrise row text is the same size as inactive prayer row text

---

### US-0038 — Trim adhaan_4.mp3 silent lead-in (BUG-0055) ❌

**Status:** ❌ Open — audio edit needed

**Issue:** `adhaan_4.mp3` has ~5 seconds of silence before the adhaan begins, making it sound broken.

**Task — trim using ffmpeg (requires ffmpeg installed via Homebrew):**
```bash
# Install if needed:
brew install ffmpeg

# Trim first 4 seconds (leaves ~1s natural lead-in):
cd iqamah/Resources
ffmpeg -i adhaan_4.mp3 -ss 4 -acodec copy adhaan_4_trimmed.mp3

# Listen to verify the result sounds correct, then replace:
mv adhaan_4.mp3 adhaan_4_original_backup.mp3
mv adhaan_4_trimmed.mp3 adhaan_4.mp3

# Remove backup once verified:
rm adhaan_4_original_backup.mp3
```

**Acceptance Criteria:**
- [ ] AC-0163: `adhaan_4.mp3` begins with ≤1 second of silence before audio
- [ ] AC-0164: Adhaan audio is not clipped or distorted after trimming
- [ ] AC-0165: File size reduced proportionally (≈ 4/213 × 2.8 MB smaller)

---

### US-0039 — Archive and resubmit to App Store ❌

**Status:** ❌ Blocked — requires US-0035 ✅, US-0036, US-0037, US-0038 complete first

**Steps:**
1. Ensure `develop` is at `7bb12fa` or later (entitlement fix merged)
2. Complete US-0037 code fixes → commit → push → verify CI green
3. Complete US-0038 audio trim → commit → push
4. In Xcode: **Product → Archive**
5. Organizer → **Distribute App → App Store Connect → Upload**
   - Use **Automatically manage signing**
   - Team: KAMAL M SYED (96Y29SP9JR)
6. Wait 5–15 min for Apple to process the build
7. In App Store Connect: select new build, verify all fields, click **Submit for Review**

**Acceptance Criteria:**
- [ ] AC-0166: New build uploaded successfully (no ITMS errors)
- [ ] AC-0167: App Review Information Notes and screen recording present before submitting
- [ ] AC-0168: Submission accepted (not immediately rejected at upload)

---

## Updated Summary Statistics (2026-05-05)

**Total Epics:** 9
**Total User Stories:** 39 (US-0001 through US-0039)
**Total Acceptance Criteria:** 168 (AC-0001 through AC-0168)

**Open for resubmission:**
- ✅ US-0035 — Entitlement fix (done, merged PR #47)
- ❌ US-0036 — App Review Notes + screen recording (manual, App Store Connect)
- ❌ US-0037 — UI sizing fixes (BUG-0052/053/054)
- ❌ US-0038 — adhaan_4.mp3 trim (BUG-0055)
- ❌ US-0039 — Archive & resubmit (blocked on above)

---

**Last Updated:** 2026-05-05 (EPIC-0009 added — App Store resubmission tasks)
