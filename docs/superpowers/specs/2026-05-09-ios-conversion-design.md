# Iqamah — iOS Universal App Conversion Design Spec

**Date:** 2026-05-09
**Status:** Draft — pending approval before implementation planning is acted on
**Scope:** EPIC-0010 (US-0040 through US-0045)
**Release Target:** v2.0 (iOS expansion)
**Branch:** `claude/explore-ios-conversion-Su3MF` (planning only); implementation will use staged feature branches per US

---

## 1. Goal

Expand Iqamah from a macOS-only app into a **universal app** that runs natively on macOS 14+ and iOS 17+, sharing a single bundle ID (`com.fablesoft.iqamah`) and the maximum amount of code.

**Non-goals:**
- iPadOS-specific layouts beyond what universal SwiftUI provides for free
- watchOS or visionOS targets
- Mac Catalyst (separate iOS-on-Mac binary) — we're keeping the native AppKit macOS app
- Rewriting any existing macOS feature
- Changing the calculation engine, cities database, or settings model

---

## 2. Why now

The macOS app is shipping (EPIC-0009). The calculation engine, models, location service, settings persistence, and audio playback are platform-agnostic and stable. The only macOS-specific surfaces are the menu-bar shell (`AppDelegate`, `MenuBarPopoverView`, `AdhaanBannerController`) and a handful of `NS*` references scattered across views — roughly 70% of the codebase is portable as-is. iOS users have repeatedly been the largest gap in the competitive analysis (`docs/competitive-analysis.md`).

---

## 3. Architectural decisions (locked)

| Decision | Choice | Why |
|----------|--------|-----|
| Shared code packaging | Local Swift Package `Packages/IqamahCore/` | Compiler-enforced boundary; reusable from app + widget + Live Activity targets without manual file membership |
| Bundle ID strategy | Universal — single `com.fablesoft.iqamah` across both targets | One App Store record, universal purchase, simplest user mental model |
| iOS deployment target | iOS 17.0 | Modern WidgetKit, interactive widgets, Observable, StandBy; ~90%+ device coverage |
| macOS deployment target | Unchanged: macOS 14.0 | No reason to bump |
| Cross-device sync | `NSUbiquitousKeyValueStore` (iCloud KVS) | Settings are <1 KB total, last-writer-wins is acceptable, no CloudKit container needed |
| Menu-bar replacement on iOS | Local notifications + Home/Lock Screen widget + Live Activity | Three complementary surfaces — none alone is sufficient |
| PR strategy | Six staged PRs, one per US (US-0040 through US-0045) | Each lands without breaking macOS; reviewable independently |

---

## 4. File-level mapping

### 4.1 Files moving into `Packages/IqamahCore/Sources/IqamahCore/`

| File | Notes |
|------|-------|
| `Models/Location.swift` | `Country`, `City`, `CitiesDatabase`, `CitiesLoader`. Pure Foundation + CoreLocation. |
| `Models/PrayerTimes.swift` | Pure struct. |
| `Models/CalculationMethod.swift` | Pure enum. |
| `Models/Adhaan.swift` | Pure model. |
| `Services/PrayerCalculator.swift` | Pure Foundation + CoreLocation math. |
| `Services/LocationService.swift` | CoreLocation wrapper; both platforms support `requestWhenInUseAuthorization`. |
| `Services/SettingsManager.swift` | Singleton, `UserDefaults`-backed. Cross-platform unchanged. |
| `Services/AdhaaanPlayer.swift` | `AVAudioPlayer`. iOS needs `AVAudioSession` configuration (see §6.1). |
| `Services/ModelsIqamahError.swift` | Pure Swift. |
| `Resources/cities.json` | Loaded via `Bundle.module`. |
| `Resources/adhaan_*.mp3` | All eight adhaan files. |
| `Resources/tone_*.aiff` | All five tone files. |

### 4.2 Files staying in the macOS app target (unchanged)

`AppDelegate.swift`, `MenuBarPopoverView.swift`, `AdhaanBannerController.swift`, `ContentView.swift` (icon-export utility lives here), `AppIconView.swift`, `AppIconGenerator.swift`, all of `Views/`.

### 4.3 New iOS app target files

| File | Purpose |
|------|---------|
| `iqamahApp_iOS.swift` | SwiftUI `App` entry point — pure SwiftUI lifecycle, no `NSApplicationDelegateAdaptor` |
| `iOSRootView.swift` | `TabView` shell: Times / Qiblah / Settings |
| `Info.plist` | iOS-specific keys (see §6.5) |
| `iqamah-iOS.entitlements` | iCloud KVS, optional Background Modes |
| `NotificationScheduler.swift` | iOS-only; schedules `UNNotificationRequest` per prayer |

### 4.4 Views needing `#if os(iOS)` branches

These are Views that mostly work cross-platform but have small `NS*` leaks or macOS-only sizing:

| File | Required change |
|------|----------------|
| `Views/SplashScreenView.swift` | `NSImage(contentsOf:)` → `#if os(iOS)` `UIImage(contentsOfFile:)` branch |
| `Views/AboutView.swift` | Same `NSImage`/`UIImage` split |
| `Views/PrayerTimesView.swift` | `NSImage(named: NSImage.applicationIconName)` → `Image("AppIcon")` from asset catalog |
| `Views/SettingsSheetView.swift` | Drop `NSScreen.main.visibleFrame` frame sizing on iOS; let SwiftUI size naturally |
| `Views/LocationSetupView.swift` | Verify; likely no changes needed |
| `Views/CalculationMethodView.swift` | Verify; likely no changes needed |
| `Views/QiblahView.swift` | iOS path can use `CLLocationManager.heading` (better than macOS) — verify no `NS*` leaks |
| `Views/PrayerTimesComponents.swift` | Verify no `NSColor` |
| `Views/IqamahBackground.swift` | Verify no `NSColor` |
| `Views/StepIndicatorView.swift` | Verify no `NSColor` |
| `Extensions/Color+App.swift` | Audit for `NSColor`; gate with `#if canImport(AppKit)` if present |

### 4.5 New iOS Widget Extension target

`IqamahWidget/` containing `IqamahWidget.swift` (timeline provider + view), `IqamahWidgetBundle.swift`, depends on `IqamahCore`.

### 4.6 New iOS Live Activity target

Either a separate `IqamahLiveActivity/` extension or merged into the widget bundle. `ActivityAttributes` defines prayer name + scheduled time; layouts for compact / expanded / minimal Dynamic Island and Lock Screen.

---

## 5. Project structure after all PRs land

```
iqamah/
├── iqamah.xcodeproj
├── Packages/
│   └── IqamahCore/
│       ├── Package.swift
│       ├── Sources/IqamahCore/
│       │   ├── Models/
│       │   ├── Services/
│       │   └── Resources/
│       └── Tests/IqamahCoreTests/
├── iqamah/                           (macOS app target — existing)
│   ├── AppDelegate.swift
│   ├── iqamahApp.swift
│   ├── ContentView.swift
│   ├── Views/
│   ├── Extensions/
│   └── iqamah.entitlements
├── iqamah-iOS/                       (NEW)
│   ├── iqamahApp_iOS.swift
│   ├── iOSRootView.swift
│   ├── NotificationScheduler.swift
│   ├── Info.plist
│   ├── Assets.xcassets
│   └── iqamah-iOS.entitlements
├── IqamahWidget/                     (NEW)
│   ├── IqamahWidget.swift
│   ├── IqamahWidgetBundle.swift
│   └── Info.plist
└── IqamahLiveActivity/               (NEW — may be in IqamahWidget bundle)
    ├── IqamahLiveActivity.swift
    └── PrayerActivityAttributes.swift  (lives in IqamahCore so app + activity share)
```

---

## 6. Per-feature design

### 6.1 US-0040 — IqamahCore extraction

**Problem:** Sharing code between macOS and iOS targets requires either a Swift Package (compiler-enforced) or manual multi-target file membership (fragile, no boundary).

**Solution:** Local Swift Package, two-platform manifest.

`Packages/IqamahCore/Package.swift`:
```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "IqamahCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "IqamahCore", targets: ["IqamahCore"]),
    ],
    targets: [
        .target(
            name: "IqamahCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "IqamahCoreTests",
            dependencies: ["IqamahCore"]
        ),
    ]
)
```

**Resource loading change:** every `Bundle.main.url(forResource:withExtension:)` call inside files that move into the package becomes `Bundle.module.url(forResource:withExtension:)`. Likely call sites (verify during implementation):
- `CitiesLoader` — loads `cities.json`
- `AdhaaanPlayer` — loads `adhaan_*.mp3` files
- Any tone-loading code

**Audio session prep:** `AdhaaanPlayer` gains a `#if os(iOS)` block that configures the audio session. Stays dormant on macOS.
```swift
#if os(iOS)
import AVFoundation
private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default, options: [])
    try? session.setActive(true)
}
#endif
```
Called once on first playback attempt.

**Behaviour rules:**
- macOS app behavior must be byte-for-byte identical after extraction (this is a refactor, not a feature change)
- All existing tests move to the package's test target
- No `import AppKit` may appear under `Packages/IqamahCore/Sources/`
- A throwaway iOS scheme (or test target) must compile against the package to prove iOS readiness

**Files modified:**
- New: `Packages/IqamahCore/Package.swift`, package source tree
- Modified: `iqamah.xcodeproj/project.pbxproj` (add package dependency, remove moved files from app target)
- Modified: source files only at `Bundle.main` → `Bundle.module` call sites

### 6.2 US-0041 — iOS app target

**Problem:** Need an iOS app shell, navigation, asset catalog, Info.plist, and view ports.

**Solution:**

**Target config:**
- Name: `iqamah-iOS`
- Bundle ID: `com.fablesoft.iqamah` (universal — same as macOS)
- Deployment: iOS 17.0
- Team: 96Y29SP9JR
- Capabilities: Location (when in use)

**Navigation shell** (`iOSRootView.swift`):
```
TabView {
    PrayerTimesView()     .tabItem { Label("Times",   systemImage: "clock") }
    QiblahView()          .tabItem { Label("Qiblah",  systemImage: "location.north.line") }
    SettingsSheetView()   .tabItem { Label("Settings", systemImage: "gear") }
}
```

**Setup flow on iOS:** Same `AppScreen` enum as macOS. First launch: `splash → locationSetup → calculationMethod → main TabView`. After completion, splash is skipped (existing logic).

**Splash:** iOS launch screen (Info.plist `UILaunchScreen` with brand colour) shows immediately. The animated `SplashScreenView` runs as the first SwiftUI view post-launch, identical to macOS.

**View ports** — apply `#if os(iOS)` branches per §4.4. Strategy: do NOT duplicate views; make them work on both platforms with conditional compilation. If a single view becomes too cluttered with conditionals (>3 `#if` blocks), split into platform-specific subviews via extension files.

**iOS app icons:** Generate a full iOS icon set (20pt @ 2x/3x through 1024pt marketing) from the existing `AppIconView`/`AppIconGenerator` design, add to a new `iqamah-iOS/Assets.xcassets/AppIcon.appiconset`.

**Settings tab:** Same `SettingsSheetView` content but presented as a tab, not a sheet. Drop modal sheet chrome on iOS via `#if os(iOS)`.

**Behaviour rules:**
- All prayer time calculations must produce identical output to macOS for the same city/method/date
- Location auto-detect must work on physical device (simulator location is unreliable)
- Qiblah view should use `CLLocationManager.startUpdatingHeading()` on iOS (already free)

### 6.3 US-0042 — iCloud settings sync

**Problem:** Universal-purchase users will install on multiple devices and expect their city/method/preferences to sync.

**Solution:** Bridge `SettingsManager` to `NSUbiquitousKeyValueStore` (KVS) — the simplest cross-device store, no CloudKit container required.

**Architecture:**

```
View ──► @Published property ──► SettingsManager setter ──► UserDefaults (local cache)
                                                       └─► NSUbiquitousKeyValueStore (iCloud)

NSUbiquitousKeyValueStore.didChangeExternallyNotification ──► SettingsManager applyRemote()
   ──► UserDefaults updated ──► @Published property updated ──► View re-renders
```

**Synced keys (all existing UserDefaults keys):**
- `selectedCity*` (city name, country, lat, lon, timezone)
- `calculationMethod`
- `asrMethod`
- `prayerAdjustments` (encoded `[String: Int]`)
- `selectedAdhaanFile` per prayer
- `prayerMuteStates`
- `appearanceMode` (Light/Dark/System)
- `gpsLocality`, `gpsTimezone`, `locationSource` (added in EPIC-0008)

**Not synced:**
- `hasCompletedSetup` — device-local; new device should still see the setup flow if KVS has no data
- Notification scheduling state (iOS-only)
- Window position/size (macOS-only)

**Conflict resolution:** KVS native last-writer-wins. No custom merge needed because settings are user-driven point-in-time choices, not collaborative state.

**Failure modes:**
- iCloud signed out → KVS calls become no-ops; local UserDefaults continues to work; no error UI surfaced
- Initial sync delay on second device → first launch shows setup flow; KVS arrives later via `didChangeExternallyNotification` and overwrites local state if newer

**Entitlements (added to both targets):**
```xml
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
```

**Behaviour rules:**
- Every existing setter in `SettingsManager` must write to BOTH `UserDefaults` and `NSUbiquitousKeyValueStore` atomically
- `init()` reads from `UserDefaults` only; KVS subscription updates settings asynchronously after init
- A first-launch race where setup completes locally before KVS arrives is acceptable — the next external change notification reconciles it
- KVS sync is opportunistic; no "sync now" UI

### 6.4 US-0043 — iOS local prayer notifications

**Problem:** iOS has no menu bar. Users need a passive way to know a prayer time has arrived without opening the app.

**Solution:** `UNUserNotificationCenter` with one `UNNotificationRequest` scheduled per enabled prayer for the next 7 days.

**Authorization flow:**
1. After setup completes (first reach of main view), check `UNUserNotificationCenter.notificationSettings()`
2. If `.notDetermined`, request `[.alert, .sound]` (don't request `.criticalAlert` for v1 — avoids entitlement complexity)
3. On grant → schedule. On deny → silently disable; expose a re-enable banner in Settings

**Scheduling:**
- For each enabled prayer × 7 days = up to 35 requests, well under the iOS 64-pending limit
- Identifier: `prayer.<name>.<yyyy-MM-dd>` — deterministic, allows replacement
- Triggered on: app launch, app foreground, settings change, location change, midnight (background task)
- Cleared on: settings disabled, day rollover for past dates

**Notification content:**
```swift
content.title    = "Iqamah"
content.body     = "It is time for \(prayerName)"
content.sound    = userSelectedSoundForPrayer(prayerName)
content.userInfo = ["prayerName": prayerName, "scheduledFor": isoTimestamp]
```

**Sound resolution:**
- If user has selected a custom adhaan for this prayer AND the file is ≤30s (iOS limit) AND adhaan-as-notification-sound preference is enabled → use that file as `UNNotificationSound(named:)`
- Else fall back to `.default`
- Existing adhaan files exceed 30s and need a 30s "preview" version added to `IqamahCore/Resources/` for notification use, OR the full file plays only when the app is foregrounded

**v1 simplification:** Use `.default` sound for all notifications in PR 4. A follow-up PR can add the 30s preview clips and per-prayer custom sounds. This keeps the notification PR small and avoids audio editing in the main path.

**Tap handling:** `UNUserNotificationCenterDelegate.didReceive(_:withCompletionHandler:)` posts a `NotificationCenter` message that the iOS app's root view observes and switches to the Times tab.

**Background mode:** Not required for v1 (no audio playback while locked). If we later want adhaan to play while locked, add `UIBackgroundModes = ["audio"]` and configure `AVAudioSession` accordingly.

**Behaviour rules:**
- Authorization denial is silent — never block the app
- Settings tab shows per-prayer toggles (Fajr, Dhuhr, Asr, Maghrib, Isha; Sunrise excluded since it's not a prayer)
- Notifications must reschedule when user changes city, calculation method, Asr method, or per-prayer adjustments
- Test cases: locked device fires correctly, day rollover handled, denied permission doesn't crash, notification tap launches Times tab

### 6.5 US-0044 — iOS Widget Extension

**Problem:** Users want glanceable next-prayer info on Home/Lock Screen.

**Solution:** Single widget kind, three families, timeline driven by prayer time transitions.

**Target config:**
- New target: `IqamahWidget` (Widget Extension)
- Bundle ID: `com.fablesoft.iqamah.widget`
- Deployment: iOS 17.0
- Depends on: `IqamahCore`

**App Group:** Both iOS app and widget need access to the same `UserDefaults` snapshot. Add App Group `group.com.fablesoft.iqamah` to both targets; modify `SettingsManager` to use `UserDefaults(suiteName:)` when an app-group ID is configured. This is a small change to `SettingsManager`'s init.

**Families:**
| Family | Layout |
|--------|--------|
| `.systemSmall` | Prayer name (bold) + countdown timer (mono digits), gold accent background |
| `.systemMedium` | Above + next 2 prayers stacked on the right |
| `.accessoryRectangular` (Lock Screen) | Single line: "Maghrib in 1h 23m" with prayer icon |

**Timeline:**
```swift
struct PrayerTimelineProvider: TimelineProvider {
    func getTimeline(...) {
        let calc = PrayerCalculator(/* from shared settings */)
        let entries = nextPrayerEntries(from: now, lookahead: .hours(24))
        // entries every 60s up to next prayer; new timeline at next prayer
        completion(Timeline(entries: entries, policy: .after(nextPrayerTransition)))
    }
}
```

**Refresh triggers:**
- Native: `.policy = .after(nextPrayerTime)` — widget rebuilds at each prayer transition
- App-driven: `WidgetCenter.shared.reloadAllTimelines()` called from app on settings/location change

**Behaviour rules:**
- Widget must work when app has never been launched after install (graceful empty state: "Open Iqamah to set up")
- Widget must respect `prayerAdjustments` (per-prayer minute offsets)
- Light/Dark wallpaper variants for Lock Screen widget
- No location lookup from widget — read cached coordinates from app group

### 6.6 US-0045 — iOS Live Activity / Dynamic Island

**Problem:** Users want a live countdown in the hour before each prayer without opening the app.

**Solution:** `ActivityKit` Live Activity, started by the iOS app one hour before each enabled prayer, ended at the prayer's scheduled time.

**Target setup:** Live Activities require the iOS app target itself (no separate extension target needed for the widget bundle that hosts the activity views; the activity views go in the existing widget extension bundle).

`Info.plist`: `NSSupportsLiveActivities = true` on the iOS app target.

**Attributes** (lives in `IqamahCore` so app + widget extension share):
```swift
public struct PrayerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let scheduledTime: Date
    }
    public let prayerName: String
    public let methodName: String
}
```

**Lifecycle:**
- Triggered when app calculates next prayer is ≤60 minutes away
- App calls `Activity.request(attributes:contentState:pushType:)`
- Activity ends automatically at `scheduledTime` via `Activity.end(_:dismissalPolicy:)`
- Only one activity per prayer at a time (dedupe by prayer name)

**Layouts:**
- **Compact leading:** prayer icon
- **Compact trailing:** countdown (mono)
- **Minimal:** countdown only
- **Expanded:** prayer name (top), large countdown (centre), method name (bottom)
- **Lock Screen:** rectangular card with prayer name + countdown

**Behaviour rules:**
- Respects per-prayer enable toggle from US-0043 (disabled prayers do not start Live Activities)
- Activity must update countdown without push (use `Text(timerInterval:)` for self-updating UI)
- No more than one Live Activity simultaneously for the same prayer
- If user kills the app, Live Activities continue (system-managed); ending the activity at prayer time still works

---

## 7. Out of scope for EPIC-0010

| Item | Why deferred |
|------|--------------|
| Critical Alert notifications | Requires entitlement application to Apple; can be a follow-up |
| iPad-optimized layouts (sidebar, multi-column) | Universal SwiftUI handles iPad acceptably; native iPad UX is its own epic |
| Apple Watch app | Separate platform decision; would warrant its own EPIC |
| Background adhaan audio playback while locked | Adds `UIBackgroundModes = ["audio"]` complexity; defer to a sound-focused iOS PR |
| Per-prayer custom adhaan as notification sound | Needs ≤30s preview clips; defer until US-0043 ships with default sound |
| Push-driven Live Activity updates | Self-updating timer covers v1; remote push is a follow-up |
| Migration of existing macOS users' settings to iCloud | KVS write-through is forward-only; existing macOS users will sync on next setting change |

---

## 8. Open questions

| # | Question | Decision needed by |
|---|----------|--------------------|
| 1 | Will the iOS Settings tab include all macOS settings, or trim some (e.g. menu-bar specific items)? | US-0041 |
| 2 | Should the widget show the city name, or just the prayer? | US-0044 |
| 3 | Should Live Activity start time be configurable (currently fixed at 60 min before)? | US-0045 |
| 4 | Should KVS sync include `selectedAdhaanFile` per prayer, or is that device-local? | US-0042 |

Recommended defaults: (1) full parity minus menu-bar items; (2) prayer name + city in medium, prayer only in small/lock; (3) fixed at 60 min for v1; (4) sync — same adhaan preference cross-device is a coherent UX.

---

## 9. Acceptance criteria reference

Full ACs are tracked in `docs/RELEASE_PLAN.md` under EPIC-0010:
- US-0040 → AC-0169 to AC-0174
- US-0041 → AC-0175 to AC-0180
- US-0042 → AC-0181 to AC-0186
- US-0043 → AC-0187 to AC-0192
- US-0044 → AC-0193 to AC-0197
- US-0045 → AC-0198 to AC-0203
