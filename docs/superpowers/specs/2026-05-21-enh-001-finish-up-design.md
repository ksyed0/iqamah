# ENH-0001 Finish-Up — Design

**Date:** 2026-05-21
**Status:** Draft → ready for plan
**Tracking:** ENH-0001 (docs/ENHANCEMENTS.md)
**Effort:** ~½ day
**ACs:** AC-0349 – AC-0356

---

## Background

ENH-0001 ("Exact GPS Prayer Times via CLGeocoder, Option A+B") was largely shipped during the v1.5.0 cycle. An audit on 2026-05-21 found:

| Surface | ENH-0001 state | Location |
|---|---|---|
| macOS first-launch setup | ✅ A+B | `iqamah/Views/LocationSetupView.swift:142-260` |
| iOS first-launch setup | ✅ A+B (shares macOS view via `iOSRootView.swift:103`) | same |
| macOS/iOS Settings → "Detect my location" | ✅ A+B | `iqamah/Views/SettingsSheetView.swift:132-190` |
| watchOS first-launch GPS | ⚠️ Option A only | `IqamahWatch/IqamahWatchApp.swift:122-125` |
| watchOS Settings → "Update via GPS" | ⚠️ Option A only | `IqamahWatch/SettingsTab.swift` |
| `SettingsManager` schema + iCloud KVS sync | ✅ Done | `Packages/IqamahCore/.../SettingsManager.swift` |
| Tests for A+B math | ✅ Done | `Packages/IqamahCore/Tests/IqamahCoreTests/ENH001GPSTests.swift` |
| Legacy-user migration prompt for v1.6 | ❌ Missing | — |
| ENH-0001 status in `docs/ENHANCEMENTS.md` | ❌ Still marked as planned | — |

This spec covers the finish-up work plus two related structural cleanups discovered during the audit (dead duplicate files, ambiguous filenames across targets).

## Decisions captured during brainstorming (2026-05-21)

- **GPS label persistence:** Use reverse-geocoded locality from CLGeocoder (Option B). Already implemented on macOS/iOS — extend to watchOS.
- **Geocoder failure fallback:** Use TimeZone.current + nearest-city label (Option A values stay). Already implemented.
- **Activation scope:** All GPS flows use the new path. Existing v1.5.0 users get a one-time prompt on v1.6 launch.
- **Migration prompt audience:** All legacy users whose `locationSource` is unset (cannot reliably distinguish pre-ENH-0001 GPS users from manual pickers; let the user decide via the prompt).

## Scope (six items)

### 1. watchOS Option B parity

Add CLGeocoder reverse-geocode to the two watch GPS entry points so the watch matches macOS/iOS.

**`IqamahWatch/IqamahWatchApp.swift`** — in `locationManager(_:didUpdateLocations:)`, after the existing Option A writes (`saveGPSCoordinates`, `locationSource = "gps"`, `gpsTimezone = TimeZone.current.identifier`), dispatch a `CLGeocoder().reverseGeocodeLocation(...)` callback that writes `placemark.locality` to `settings.gpsLocality` and `placemark.timeZone?.identifier` to `settings.gpsTimezone`. Reuse the 5-km cache short-circuit from `iqamah/Views/LocationSetupView.swift:230-235`.

**`IqamahWatch/SettingsTab.swift`** — the "Update via GPS" button currently re-runs the same location-manager path; once `IqamahWatchApp` is fixed it inherits the refinement automatically. Verify no separate code path here; add a watchOS-targeted unit test that exercises the refinement.

**Behaviour on failure:** Option A values remain in place (raw coords + TimeZone.current). Log `[ENH-0001]` and exit. Matches macOS pattern at `LocationSetupView.swift:240-242`.

### 2. One-time v1.6 re-detect prompt

Prompt legacy users (whose `locationSource` is unset because they completed setup before ENH-0001 schema landed) once on first launch of v1.6.

**New `SettingsManager` key:**
```swift
static let didShowGPSReDetectPromptV16 = "didShowGPSReDetectPromptV16"
```
Bool, UserDefaults only — **not** KVS-synced. The prompt should fire once per device, not once per Apple ID. (A user upgrading two devices should see the prompt on both.)

**Trigger:**
```
hasCompletedSetup == true
&& locationSource.isEmpty
&& didShowGPSReDetectPromptV16 == false
```

**Surface:** SwiftUI `.alert()` attached to the macOS main window's root `.onAppear` and the iOS `iOSRootView`'s `.onAppear`. Watch app skipped — watch users are a small fraction of the install base and inherit `gpsTimezone` via iCloud KVS from their phone.

**Copy:**
> **Location accuracy improved**
> Iqamah v1.6 uses your exact GPS position and authoritative timezone for prayer-time calculations. Re-detect your location now to apply the improvement?
>
> [Re-detect] [Keep current]

**Actions:**
- **Re-detect**: sets `didShowGPSReDetectPromptV16 = true`, opens the existing Settings re-detect flow (programmatically open Settings sheet on macOS/iOS).
- **Keep current**: sets `didShowGPSReDetectPromptV16 = true` AND `locationSource = "manual"` so subsequent launches behave as a manual selection.

### 3. Doc closeout

- `docs/ENHANCEMENTS.md` — update ENH-0001 heading to `✅ Implemented (2026-05-21)`, list which surfaces ship A vs A+B, link the v1.6 PR.
- `docs/ID_REGISTRY.md` — bump `AC` next-available to AC-0357 after the AC-0349 – AC-0356 in this spec are consumed.
- No new EPIC/US/ENH/BUG IDs needed.

### 4. Delete dead `Views/` directory

`Views/CalculationMethodView.swift`, `Views/LocationSetupView.swift`, `Views/SplashScreenView.swift` at the repo root are not referenced by any Xcode target (verified via `iqamah.xcodeproj/project.pbxproj` audit — only the `iqamah/Views/` and `IqamahWatch/` copies appear in any target's Sources phase).

`rm -r Views/` and confirm no diff in built products.

### 5. Rename watch `LocationSetupView` to disambiguate

`IqamahWatch/LocationSetupView.swift` shares its filename with `iqamah/Views/LocationSetupView.swift` (different implementations — watch UI vs cross-platform UI). Rename:

- File: `IqamahWatch/LocationSetupView.swift` → `IqamahWatch/WatchLocationSetupView.swift`
- Struct: `LocationSetupView` → `WatchLocationSetupView`
- Update pbxproj `path = LocationSetupView.swift;` entry for `WA000000000000000000011R` to `path = WatchLocationSetupView.swift;`
- Update the call site in `IqamahWatch/IqamahWatchApp.swift` (only one)

### 6. Add "Project structure" note to `CLAUDE.md`

Insert a short section after "Build & Run":

```markdown
## Project Structure Conventions

Filenames recur across platform targets (e.g. `LocationSetupView.swift` exists
in both `iqamah/Views/` for macOS+iOS and `IqamahWatch/` for watchOS — they
are different implementations sharing a base name where the file is repurposed
per-platform). When you need to know which file a given target compiles, search
`iqamah.xcodeproj/project.pbxproj` for the file reference and trace its target
membership rather than relying on `grep` over the working tree. Xcode resolves
`sourceTree = "<group>"` paths relative to the parent group's on-disk location,
not the repo root.
```

## Out of scope

- **PrayerActivityAttributes consolidation** — the two copies in `IqamahLiveActivity/` and `iqamah/iOS/` have already drifted. Tracked as a separate spawned task — needs pbxproj multi-target membership edits and validation on both targets. Latent ActivityKit hazard but not blocking.
- **Renaming `SplashScreenView` / `CalculationMethodView` collisions** — resolved by item 4 (dead directory deletion); no further renames needed.
- **Backfilling `locationSource = "gps"` for legacy GPS users** — impossible to distinguish reliably from manual pickers; the v1.6 prompt is the chosen migration path.

## Testing

- **Existing:** `ENH001GPSTests.swift` covers A+B math.
- **New unit test:** `testReDetectPromptFiresOnceForLegacyUsers` — given `locationSource == ""` and `didShowGPSReDetectPromptV16 == false`, trigger evaluates true; after either action, both flags are set and re-evaluation returns false.
- **New unit test:** `testWatchGeocodingRefinesLocalityAndTimezone` — given a stub geocoder that returns a placemark with `locality = "Brampton"` and timezone `America/Toronto`, after calling the watch refinement helper `settings.gpsLocality == "Brampton"` and `settings.gpsTimezone == "America/Toronto"`.
- **Manual:**
  - Apple Watch Series 11 simulator: tap "Update via GPS", verify `gpsLocality` populates within ~2 s.
  - macOS app on a v1.5.0 install fixture (legacy state): launch v1.6, verify alert appears once and not on second launch.
  - iOS: same as macOS.

## Acceptance criteria

- **AC-0349:** watchOS `IqamahWatchApp.locationManager(_:didUpdateLocations:)` invokes `CLGeocoder().reverseGeocodeLocation(...)` after saving raw GPS coordinates; on success, writes `placemark.locality` to `SettingsManager.gpsLocality` and `placemark.timeZone?.identifier` to `SettingsManager.gpsTimezone`. CLGeocoder is short-circuited when the cached coordinate is within 5 km of the new fix and `gpsLocality` is non-empty (mirrors macOS).
- **AC-0350:** On CLGeocoder failure or no network, watchOS retains the Option-A values (raw coords + `TimeZone.current`). No UI degradation or error surfaced to the user. Failure is logged with the `[ENH-0001]` tag.
- **AC-0351:** First launch of v1.6 on a device with `hasCompletedSetup && locationSource.isEmpty` presents the re-detect `.alert()` exactly once on macOS and on iOS. Watch app does not present a prompt.
- **AC-0352:** Either alert action sets `SettingsManager.didShowGPSReDetectPromptV16 = true`. "Keep current" also sets `locationSource = "manual"`. The alert never re-presents on subsequent launches.
- **AC-0353:** `docs/ENHANCEMENTS.md` ENH-0001 entry is updated to ✅ Implemented (2026-05-21) with PR references and a surface-by-surface table.
- **AC-0354:** Repo-root `Views/` directory no longer exists; `LocationSetupView`, `CalculationMethodView`, and `SplashScreenView` exist only in their target-specific locations. Both `iqamah` and `iqamah-iOS` schemes build clean.
- **AC-0355:** `IqamahWatch/WatchLocationSetupView.swift` exists; the struct is renamed to `WatchLocationSetupView`; the pbxproj path is updated; `IqamahWatchApp.swift` references the new type. `IqamahWatch` scheme builds clean.
- **AC-0356:** `CLAUDE.md` contains a "Project Structure Conventions" section explaining that filenames recur across targets and pbxproj is authoritative for target membership.

## Files touched

| File | Change |
|---|---|
| `IqamahWatch/IqamahWatchApp.swift` | Add CLGeocoder refinement after Option A writes |
| `IqamahWatch/SettingsTab.swift` | (verify no separate path; likely no change) |
| `IqamahWatch/LocationSetupView.swift` → `WatchLocationSetupView.swift` | Rename file + struct |
| `iqamah/iOS/iOSRootView.swift` | Add `.alert()` for re-detect prompt on first v1.6 launch |
| `iqamah/ContentView.swift` (or root macOS view) | Add `.alert()` for re-detect prompt on first v1.6 launch |
| `Packages/IqamahCore/Sources/IqamahCore/Services/SettingsManager.swift` | Add `didShowGPSReDetectPromptV16` key + published prop |
| `Packages/IqamahCore/Tests/IqamahCoreTests/ENH001GPSTests.swift` | Add two new tests |
| `iqamah.xcodeproj/project.pbxproj` | Update path for `WA000000000000000000011R` |
| `Views/` (repo root) | Delete entire directory (3 files) |
| `docs/ENHANCEMENTS.md` | Mark ENH-0001 ✅ |
| `docs/ID_REGISTRY.md` | Bump AC counter to AC-0357 |
| `CLAUDE.md` | Add Project Structure Conventions section |
