# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Iqamah** is a macOS (14.0+) SwiftUI app that calculates Islamic prayer times using astronomical algorithms. It features a menu bar status item showing the next prayer countdown and a main window with prayer times, location selection, and calculation method configuration.

## Build & Run

Open `iqamah.xcodeproj` in Xcode and build/run (Cmd+R). Alternatively:

```bash
# macOS:
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build
# iOS:
xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS -configuration Debug -destination 'generic/platform=iOS' build
```

There are no external dependencies, package managers, or test targets.

## Project Structure Conventions

Filenames recur across platform targets (e.g. `LocationSetupView.swift` lives
in `iqamah/Views/` for macOS+iOS and `WatchLocationSetupView.swift` in
`IqamahWatch/` — historically the watch file shared the base name, leading to
grep ambiguity). When you need to know which file a given target compiles,
search `iqamah.xcodeproj/project.pbxproj` for the file reference and trace its
target membership rather than relying on `grep` over the working tree. Xcode
resolves `sourceTree = "<group>"` paths relative to the parent group's on-disk
location, not the repo root.

`PrayerActivityAttributes.swift` previously existed as two drifted copies in
`IqamahLiveActivity/` and `iqamah/iOS/`; it has been consolidated into a single
file at `IqamahLiveActivity/PrayerActivityAttributes.swift` with multi-target
membership in pbxproj (build file refs `LA000000000000000000010` for the
extension and `AM00000000000000000000A` for the iqamah-iOS app target, both
pointing at file ref `LA000000000000000000010R`). When extending the type,
edit that single file — never re-introduce a duplicate.

## Architecture

### App Lifecycle
- `iqamahApp.swift` — SwiftUI @main entry point with NSApplicationDelegateAdaptor
- `AppDelegate.swift` — Manages menu bar status item (next prayer countdown, updates every 60s, turns red < 10 min), prevents app quit on window close
- `ContentView.swift` — Navigation controller using `AppScreen` enum: `.splash → .locationSetup → .calculationMethod → .prayerTimes`

### Models (`iqamah/Models/`)
- `Location.swift` — `Country`, `City`, `CitiesDatabase` (Codable), `CitiesLoader` singleton loading from `cities.json`
- `PrayerTimes.swift` — Struct holding 6 prayer times (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha)
- `CalculationMethod.swift` — 6 methods (MWL, ISNA, Egypt, Umm Al-Qura, Karachi, Tehran) with Fajr/Isha angles; Asr jurisprudence (Standard vs Hanafi)

### Services (`iqamah/Services/`)
- `PrayerCalculator.swift` — Core astronomical engine: Julian day conversion, solar declination, equation of time, hour angle calculations. Takes coordinates, timezone, method, and Asr jurisprudence as inputs.
- `LocationService.swift` — CoreLocation wrapper using async/await (CheckedContinuation pattern), @MainActor
- `SettingsManager.swift` — Singleton (`SettingsManager.shared`) persisting to UserDefaults. ObservableObject with @Published properties. Posts NotificationCenter updates for AppDelegate.

### Views (`iqamah/Views/`)
- `PrayerTimesView.swift` — Main UI: prayer table with real-time next-prayer highlighting, per-prayer +/- minute adjustments, Gregorian + Hijri dates
- `LocationSetupView.swift` — Country/city cascading dropdowns with auto-detect via CoreLocation
- `CalculationMethodView.swift` — Method picker and Asr jurisprudence selection
- `SplashScreenView.swift` — 10-second intro splash

### Data Flow
Singletons (`SettingsManager.shared`, `CitiesLoader.shared`) → SwiftUI @StateObject/@Published → Views. AppDelegate observes `NotificationCenter` for settings changes to update the status bar item.

### Resources
- `cities.json` — Global cities database with coordinates and timezones
- `splash.jpg` — Splash screen background
- `Assets.xcassets` — App icons (generated via `AppIconView.swift`/`AppIconGenerator.swift` at project root)

## Project Documentation

Key docs in `docs/`:
- `RELEASE_PLAN.md` — Epics (EPIC-XXXX), User Stories (US-XXXX), Acceptance Criteria (AC-XXXX); canonical feature backlog
- `BUGS.md` — Bug register (BUG-XXXX)
- `ENHANCEMENTS.md` — Lightweight future enhancement backlog (ENH-XXXX); competitive gap items and ideas not yet ready for a formal Epic. When an enhancement is approved for development, promote it to an EPIC + US in RELEASE_PLAN.md and cross-reference the ENH ID.
- `ID_REGISTRY.md` — Single source of truth for next available ID in every sequence (EPIC, US, AC, BUG, TASK, TC, ENH). Always consult before creating a new artefact.
- `competitive-analysis.md` — Feature comparison against top 10 App Store competitors; basis for ENH items

## Key Implementation Details

- Window size: 450x500 default, max 620x680, hidden title bar
- Prayer times recalculate on day change and every 60 seconds
- UserDefaults keys: `hasCompletedSetup`, `selectedCity*`, `calculationMethod`, `asrMethod`, `prayerAdjustments`
- Bundle ID: `com.fablesoft.iqamah`, Team: `96Y29SP9JR`
- Entitlements: App Sandbox enabled, location access via Info.plist keys

## UI Conventions

- **Chrome materials:** Use SwiftUI `Material` (`.regular`, `.thin`, `.ultraThin`, `.ultraThick`) for cards, panels, popovers, sheets, and floating headers. Materials auto-adapt to dark and light modes — do not write per-mode background colour logic.
- **Liquid Glass (iOS 26 / macOS 26+):** Where available, layer `.glassEffect()` on top of the Material via an `@available(iOS 26.0, macOS 26.0, *)` branch. The Material is the fallback on older OS versions; we do **not** bump the project's iOS 17 / macOS 14 minimum target to require Liquid Glass.
- **Light / dark parity:** Every new view must be tested in both modes. Tap targets, contrast, shadows, and overlay legibility must look correct in both. Prefer semantic colours (`Color.primary`, `Color.secondary`, `.quaternaryLabelColor`) over hardcoded hex.
