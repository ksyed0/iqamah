# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Iqamah** is a macOS (14.0+) SwiftUI app that calculates Islamic prayer times using astronomical algorithms. It features a menu bar status item showing the next prayer countdown and a main window with prayer times, location selection, and calculation method configuration.

## Build & Run

Open `iqamah.xcodeproj` in Xcode and build/run (Cmd+R). Alternatively:

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build
```

There are no external dependencies, package managers, or test targets.

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

## Key Implementation Details

- Window size: 450x500 default, max 620x680, hidden title bar
- Prayer times recalculate on day change and every 60 seconds
- UserDefaults keys: `hasCompletedSetup`, `selectedCity*`, `calculationMethod`, `asrMethod`, `prayerAdjustments`
- Bundle ID: `com.fablesoft.iqamah`, Team: `96Y29SP9JR`
- Entitlements: App Sandbox enabled, location access via Info.plist keys
