# Iqamah — macOS Prayer Times

[![CI](https://github.com/ksyed0/iqamah/actions/workflows/ci.yml/badge.svg)](https://github.com/ksyed0/iqamah/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue.svg)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A free, open-source macOS menu bar app that calculates accurate Islamic prayer times using astronomical algorithms. No internet connection required — everything runs on-device.

---

## Features

- **Accurate prayer times** via 6 established calculation methods (MWL, ISNA, Egyptian, Umm Al-Qura, Karachi, Tehran)
- **Menu bar countdown** showing the next prayer name and time, turning red when under 10 minutes away
- **Per-prayer Adhaan** — assign a different sound to each prayer; Fajr has its own dedicated recordings (which include *"As-salatu khayrun minan nawm"*)
- **Individual mute** per prayer, plus a master mute toggle
- **Iqamah adjustments** — ± minute offsets per prayer to match your local mosque's iqamah time
- **Qiblah compass** with prayer-mat and Ka'bah imagery
- **Hijri date** displayed alongside the Gregorian date
- **24-hour time** toggle
- **Auto city detection** via CoreLocation, or manual country/city selection from a bundled database of thousands of cities
- **Calculation method auto-suggestion** based on your selected country
- Fully offline — zero external dependencies, no analytics, no tracking

---

## Requirements

| | Version |
|---|---|
| macOS | 14.0 (Sonoma) or later |
| Xcode | 15.0 or later |
| Swift | 5.9 or later |

---

## Build & Run

```bash
git clone https://github.com/ksyed0/iqamah.git
cd iqamah
open iqamah.xcodeproj
```

Press **Cmd+R** in Xcode. No package manager or external dependencies needed.

From the command line:

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build
```

---

## Adding Adhaan Recordings

Adhaan audio files are **not included** in this repository. To add your own:

1. Place MP3 or M4A files in `iqamah/Resources/` using these names:
   - `adhaan_1.mp3` … `adhaan_5.mp3` — standard Adhaan (all 5 prayers)
   - `adhaan_fajr_1.mp3` … `adhaan_fajr_3.mp3` — Fajr-specific (includes *"As-salatu khayrun minan nawm"*)
2. In Xcode, right-click the `Resources` group → **Add Files to "iqamah"** → ensure **Add to target: iqamah** is checked

Public-domain and permissively-licensed recordings are available at [mp3quran.net](https://mp3quran.net).

---

## Architecture

```
iqamah/
├── iqamahApp.swift               # @main entry point, WindowGroup
├── AppDelegate.swift             # Menu bar status item + 60s update timer
├── ContentView.swift             # Navigation: Splash → Setup → Prayer Times
├── Models/
│   ├── Adhaan.swift              # Audio option model; bundle-scanning for recordings
│   ├── CalculationMethod.swift   # 6 methods + country→method auto-mapping
│   ├── Location.swift            # City, Country, CitiesDatabase, CitiesLoader
│   └── PrayerTimes.swift         # Prayer times struct + date formatters
├── Services/
│   ├── AdhaaanPlayer.swift       # AVAudioPlayer; per-prayer + global mute, preview
│   ├── LocationService.swift     # CoreLocation async/await wrapper
│   ├── PrayerCalculator.swift    # Astronomical engine (Julian day, declination, etc.)
│   └── SettingsManager.swift     # UserDefaults singleton; all persistent state
├── Views/
│   ├── PrayerTimesView.swift     # Main UI: prayer table + next-prayer highlight
│   ├── SettingsSheetView.swift   # Non-destructive settings sheet
│   ├── LocationSetupView.swift   # Onboarding step 1 — city + GPS
│   ├── CalculationMethodView.swift  # Onboarding step 2 — method + Asr
│   ├── QiblahView.swift          # Compass with real prayer-mat + Ka'bah assets
│   ├── SplashScreenView.swift    # Splash screen
│   └── StepIndicatorView.swift   # Onboarding step dots
└── Resources/
    ├── cities.json               # Global cities database with coords + timezones
    ├── splash.jpg                # Splash background
    ├── PrivacyInfo.xcprivacy     # Apple privacy manifest (UserDefaults declaration)
    ├── tone_*.aiff               # Bundled alert tones
    └── adhaan_*.mp3              # User-supplied — not in repo (see above)
```

**Data flow:** `SettingsManager.shared` (`UserDefaults`) → SwiftUI `@StateObject`/`@Published` → Views. `AppDelegate` observes `NotificationCenter` for settings changes to update the status bar item.

---

## Testing

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug test \
  -destination 'platform=macOS'
```

The test suite covers prayer calculation accuracy, city model validation, Qiblah bearing, Hijri date conversion, settings persistence, Adhaan model, and calculation method country mapping. Target: ≥80% code coverage.

---

## Contributing

1. Fork the repo and create a branch from `develop`
2. Run `swiftformat .` before committing (style enforcement)
3. Run `swiftlint lint` and fix any warnings
4. Ensure all tests pass with ≥80% coverage
5. Open a pull request against `develop`

For major changes, open an issue first to discuss what you'd like to change.

---

## Privacy

Iqamah collects **no personal data**. CoreLocation is used only to detect your nearest city — the result is stored locally in `UserDefaults`. No analytics, no crash reporting, no network calls.

See [Privacy Policy](Privacy_Policy.md) for the full policy text.

---

## License

MIT © Kamal Syed — see [LICENSE](LICENSE) for details.
