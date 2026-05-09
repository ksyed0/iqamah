# Iqamah iOS Universal App Conversion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** [`docs/superpowers/specs/2026-05-09-ios-conversion-design.md`](../specs/2026-05-09-ios-conversion-design.md)
**Backlog:** EPIC-0010 in `docs/RELEASE_PLAN.md` (US-0040 through US-0045)
**Goal:** Ship Iqamah as a universal app (macOS 14+ / iOS 17+) sharing all calculation, model, and service code via a local Swift Package, with iCloud settings sync, local notifications, a Home/Lock Screen widget, and Live Activity / Dynamic Island support.

**Architecture:** Six independent feature branches merged sequentially to `develop`. Each branch is self-contained and shippable. The macOS app must continue working unchanged after every branch lands.

**Tech Stack:** Swift 5.10, SwiftUI, AppKit (existing macOS only), UIKit (iOS shims only), CoreLocation, AVFoundation, UserNotifications, WidgetKit, ActivityKit, NSUbiquitousKeyValueStore.

---

## Pre-flight: verify current state

Before starting, confirm:
- [ ] Repo on `develop` (or fresh feature branch off `develop`), not `claude/explore-ios-conversion-Su3MF` (that branch is for planning only)
- [ ] macOS app builds clean: `xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build` → BUILD SUCCEEDED
- [ ] All existing tests pass
- [ ] No uncommitted changes
- [ ] Read the spec end-to-end before starting any branch

**Tools required:**
- Xcode 15.4+ (for iOS 17 SDK)
- macOS host capable of running iOS Simulator
- Apple Developer account access for entitlement updates (iCloud, App Groups)

---

## Branch 1 — US-0040: Extract IqamahCore Swift Package

**Branch:** `feat/US-0040-iqamah-core-package`
**Risk:** Low — pure refactor, no behavior change
**Estimated effort:** 0.5–1 day

### Task 1.1 — Create the package skeleton

- [ ] **Step 1:** Create the package directory tree
```bash
mkdir -p Packages/IqamahCore/Sources/IqamahCore/{Models,Services,Resources}
mkdir -p Packages/IqamahCore/Tests/IqamahCoreTests
```

- [ ] **Step 2:** Write `Packages/IqamahCore/Package.swift`
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

- [ ] **Step 3:** Verify package resolves standalone
```bash
cd Packages/IqamahCore && swift build 2>&1 | tail -20
```
Expected: empty package builds cleanly (or "no targets to build" warning).

- [ ] **Step 4:** Commit
```bash
git add Packages/IqamahCore/Package.swift
git commit -m "feat(US-0040): scaffold empty IqamahCore Swift Package"
```

### Task 1.2 — Move Models into the package

- [ ] **Step 1:** Move model files
```bash
git mv iqamah/Models/Location.swift          Packages/IqamahCore/Sources/IqamahCore/Models/
git mv iqamah/Models/PrayerTimes.swift       Packages/IqamahCore/Sources/IqamahCore/Models/
git mv iqamah/Models/CalculationMethod.swift Packages/IqamahCore/Sources/IqamahCore/Models/
git mv iqamah/Models/Adhaan.swift            Packages/IqamahCore/Sources/IqamahCore/Models/
```

- [ ] **Step 2:** Add `public` modifiers where needed
For each moved file, ensure types/properties/methods used outside the package are marked `public`. Common pattern:
```swift
public struct City: Codable, Identifiable, Hashable {
    public let name: String
    public let country: String
    public let latitude: Double
    public let longitude: Double
    public let timezone: String

    public var coordinate: CLLocationCoordinate2D { ... }
    // ...
}
```

- [ ] **Step 3:** Remove the moved files from the macOS app target in `iqamah.xcodeproj/project.pbxproj`
This requires editing `project.pbxproj` directly: find the `PBXBuildFile` and `PBXFileReference` entries for each moved file and delete them, plus their entries in the `PBXSourcesBuildPhase` for the iqamah target.

⚠️ **Better:** open `iqamah.xcodeproj` in Xcode, right-click each moved file in the navigator, choose "Delete → Remove Reference", then re-add the IqamahCore package as a dependency of the iqamah target via Project → iqamah target → Frameworks, Libraries, and Embedded Content → + → Add Other → Add Package Dependency → Add Local → select `Packages/IqamahCore`.

- [ ] **Step 4:** Add `import IqamahCore` to every macOS app file that references the moved types
```bash
grep -l "PrayerTimes\|CalculationMethod\|City\|Country\|CitiesDatabase" iqamah/**/*.swift
```
Add `import IqamahCore` near the top of each.

- [ ] **Step 5:** Build
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```
Expected: BUILD SUCCEEDED. Fix any access-level errors by widening visibility in the package.

- [ ] **Step 6:** Commit
```bash
git add -A
git commit -m "feat(US-0040): move Models into IqamahCore package"
```

### Task 1.3 — Move Services into the package

- [ ] **Step 1:** Move service files
```bash
git mv iqamah/Services/PrayerCalculator.swift  Packages/IqamahCore/Sources/IqamahCore/Services/
git mv iqamah/Services/LocationService.swift   Packages/IqamahCore/Sources/IqamahCore/Services/
git mv iqamah/Services/SettingsManager.swift   Packages/IqamahCore/Sources/IqamahCore/Services/
git mv iqamah/Services/AdhaaanPlayer.swift     Packages/IqamahCore/Sources/IqamahCore/Services/
git mv iqamah/Services/ModelsIqamahError.swift Packages/IqamahCore/Sources/IqamahCore/Services/
```

- [ ] **Step 2:** Add `public` to types and APIs as in Task 1.2

- [ ] **Step 3:** Update Xcode project file references (same approach as Task 1.2)

- [ ] **Step 4:** Add `import IqamahCore` to consumers
```bash
grep -l "SettingsManager\|PrayerCalculator\|LocationService\|AdhaaanPlayer" iqamah/**/*.swift
```

- [ ] **Step 5:** Build & fix access errors. The most likely issues:
  - `SettingsManager.shared` needs `public`
  - `@Published` properties need `public`
  - `init()` needs `public` (private init is fine if singleton)

- [ ] **Step 6:** Commit
```bash
git add -A
git commit -m "feat(US-0040): move Services into IqamahCore package"
```

### Task 1.4 — Move resources and switch to Bundle.module

- [ ] **Step 1:** Move resources
```bash
git mv iqamah/Resources/cities.json     Packages/IqamahCore/Sources/IqamahCore/Resources/
git mv iqamah/Resources/adhaan_*.mp3    Packages/IqamahCore/Sources/IqamahCore/Resources/
git mv iqamah/Resources/tone_*.aiff     Packages/IqamahCore/Sources/IqamahCore/Resources/
```
Leave `splash.jpg`, `PrivacyInfo.xcprivacy`, and `Media/` in the app target — these are macOS-app-specific.

- [ ] **Step 2:** Remove the moved resource references from the macOS app target's Copy Bundle Resources phase (Xcode UI or `project.pbxproj` edit).

- [ ] **Step 3:** Find every `Bundle.main` reference for resources that were moved
```bash
grep -rn "Bundle.main" Packages/IqamahCore/Sources/IqamahCore/
```

- [ ] **Step 4:** Replace with `Bundle.module`. Common pattern:
```swift
// Before:
guard let url = Bundle.main.url(forResource: "cities", withExtension: "json") else { ... }
// After:
guard let url = Bundle.module.url(forResource: "cities", withExtension: "json") else { ... }
```

- [ ] **Step 5:** Build and run the macOS app. Verify:
  - Cities database loads
  - Adhaan audio plays
  - Tone audio plays
  - No console errors about missing resources

- [ ] **Step 6:** Commit
```bash
git add -A
git commit -m "feat(US-0040): move bundled resources into IqamahCore, switch to Bundle.module"
```

### Task 1.5 — Add iOS-only AVAudioSession setup to AdhaaanPlayer

- [ ] **Step 1:** Edit `Packages/IqamahCore/Sources/IqamahCore/Services/AdhaaanPlayer.swift`. Add at top:
```swift
#if os(iOS)
import AVFoundation
#endif
```

- [ ] **Step 2:** Add the configuration helper inside the class:
```swift
#if os(iOS)
private func configureAudioSessionIfNeeded() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default, options: [])
    try? session.setActive(true)
}
#endif
```

- [ ] **Step 3:** Call it before the first playback attempt. Find the existing `play(...)` method and add at the top:
```swift
#if os(iOS)
configureAudioSessionIfNeeded()
#endif
```

- [ ] **Step 4:** Build (still macOS only — verifies the `#if os(iOS)` blocks don't break anything)
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 5:** Commit
```bash
git add Packages/IqamahCore/Sources/IqamahCore/Services/AdhaaanPlayer.swift
git commit -m "feat(US-0040): add iOS AVAudioSession setup to AdhaaanPlayer (dormant on macOS)"
```

### Task 1.6 — Audit Color+App.swift for AppKit leaks

- [ ] **Step 1:** Read `iqamah/Extensions/Color+App.swift`. If it contains `NSColor`, gate with `#if canImport(AppKit)` and provide a `UIColor` mirror under `#elseif canImport(UIKit)`.

- [ ] **Step 2:** If the file is fully cross-platform (`Color`-only), move it into the package:
```bash
git mv iqamah/Extensions/Color+App.swift Packages/IqamahCore/Sources/IqamahCore/Extensions/
```
Otherwise leave it in the macOS app target and copy a cross-platform version into the package.

- [ ] **Step 3:** Build. Commit.
```bash
git commit -m "feat(US-0040): audit Color+App for cross-platform compatibility"
```

### Task 1.7 — Move tests into the package

- [ ] **Step 1:** Move tests
```bash
git mv Tests/PrayerCalculatorTests.swift           Packages/IqamahCore/Tests/IqamahCoreTests/
git mv Tests/PrayerAccuracyRegressionTests.swift   Packages/IqamahCore/Tests/IqamahCoreTests/
git mv Tests/IqamahModelTests.swift                Packages/IqamahCore/Tests/IqamahCoreTests/
git mv Tests/ENH001GPSTests.swift                  Packages/IqamahCore/Tests/IqamahCoreTests/
git mv Tests/IntegrationAndEdgeCaseTests.swift     Packages/IqamahCore/Tests/IqamahCoreTests/
```
Leave any UI/AppKit-dependent tests in the app target.

- [ ] **Step 2:** Add `@testable import IqamahCore` to each moved test file (replacing `@testable import iqamah` if present).

- [ ] **Step 3:** Run package tests
```bash
cd Packages/IqamahCore && swift test 2>&1 | tail -30
```
Expected: all tests pass.

- [ ] **Step 4:** Run app-target tests via Xcode to confirm UI tests still work.

- [ ] **Step 5:** Commit
```bash
git add -A
git commit -m "feat(US-0040): move calculation and model tests into IqamahCore package"
```

### Task 1.8 — Verify iOS compilation (without building an iOS target yet)

- [ ] **Step 1:** Build the package for iOS Simulator
```bash
cd Packages/IqamahCore
swift build -Xswiftc -sdk -Xswiftc "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -Xswiftc -target -Xswiftc arm64-apple-ios17.0-simulator
```
(Alternatively, in Xcode: Product → Build For → set destination to an iOS Simulator and build the IqamahCore scheme.)

Expected: BUILD SUCCEEDED. If it fails with `import AppKit` errors, find and remove/gate those imports.

- [ ] **Step 2:** Final verification
- [ ] AC-0169: `Package.swift` declares both platforms ✓
- [ ] AC-0170: macOS app builds clean ✓
- [ ] AC-0171: Tests pass in package ✓
- [ ] AC-0172: `grep -r "import AppKit" Packages/IqamahCore/Sources/` returns nothing ✓
- [ ] AC-0173: Manual smoke test of macOS app — prayer times unchanged ✓
- [ ] AC-0174: Package builds for iOS Simulator ✓

- [ ] **Step 3:** Push branch and open PR
```bash
git push -u origin feat/US-0040-iqamah-core-package
```
PR title: `feat(US-0040): extract IqamahCore Swift Package`
PR body: link to spec § 6.1.

---

## Branch 2 — US-0041: Add iOS App Target & Core Flow

**Branch:** `feat/US-0041-ios-app-target`
**Risk:** Medium — new target, view ports, asset generation
**Estimated effort:** 1–2 days
**Depends on:** US-0040 merged

### Task 2.1 — Create the iOS app target

- [ ] **Step 1:** In Xcode: File → New → Target → iOS → App
  - Product Name: `iqamah-iOS`
  - Team: `KAMAL M SYED (96Y29SP9JR)`
  - Organization Identifier: `com.fablesoft`
  - Bundle Identifier: `com.fablesoft.iqamah` (overwrite the suggested value to match macOS)
  - Interface: SwiftUI
  - Language: Swift
  - Deployment Target: iOS 17.0

- [ ] **Step 2:** Add `IqamahCore` package dependency to the new target.

- [ ] **Step 3:** Build the empty iOS target on the iOS Simulator. Expected: blank Hello-World runs.

- [ ] **Step 4:** Commit
```bash
git add -A
git commit -m "feat(US-0041): add iqamah-iOS app target with shared bundle ID"
```

### Task 2.2 — Implement the iOS app entry point and root navigation

- [ ] **Step 1:** Replace the auto-generated `iqamahApp.swift` (the iOS one — Xcode may name-collide with the macOS one; use `iqamahApp_iOS.swift`):
```swift
import SwiftUI
import IqamahCore

@main
struct IqamahiOSApp: App {
    @StateObject private var settings = SettingsManager.shared

    var body: some Scene {
        WindowGroup {
            iOSRootView()
                .environmentObject(settings)
        }
    }
}
```

- [ ] **Step 2:** Create `iOSRootView.swift`:
```swift
import SwiftUI
import IqamahCore

struct iOSRootView: View {
    @EnvironmentObject private var settings: SettingsManager

    var body: some View {
        if settings.hasCompletedSetup {
            MainTabView()
        } else {
            OnboardingFlow()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { PrayerTimesView() }
                .tabItem { Label("Times", systemImage: "clock") }
            NavigationStack { QiblahView() }
                .tabItem { Label("Qiblah", systemImage: "location.north.line") }
            NavigationStack { SettingsSheetView() }
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

struct OnboardingFlow: View {
    @State private var step: Step = .splash
    enum Step { case splash, location, method }

    var body: some View {
        switch step {
        case .splash:
            SplashScreenView()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        step = .location
                    }
                }
        case .location:
            LocationSetupView(onContinue: { step = .method })
        case .method:
            CalculationMethodView(onContinue: { /* setup completes via SettingsManager */ })
        }
    }
}
```

(Adjust `onContinue` parameter shape to match the actual `LocationSetupView`/`CalculationMethodView` API.)

- [ ] **Step 3:** Build for simulator. App launches to splash → location → method → tab view (or to tab view if setup is complete).

- [ ] **Step 4:** Commit
```bash
git commit -m "feat(US-0041): implement iOS root navigation with TabView"
```

### Task 2.3 — Port views with #if os(iOS) branches

For each view in `iqamah/Views/` that the iOS app needs, add cross-platform branches:

- [ ] **Step 1: SplashScreenView**
Replace `NSImage(contentsOf:)` with:
```swift
#if os(macOS)
import AppKit
private func loadSplashImage() -> NSImage? {
    guard let url = Bundle.main.url(forResource: "splash", withExtension: "jpg") else { return nil }
    return NSImage(contentsOf: url)
}
#else
import UIKit
private func loadSplashImage() -> UIImage? {
    guard let url = Bundle.main.url(forResource: "splash", withExtension: "jpg") else { return nil }
    return UIImage(contentsOfFile: url.path)
}
#endif
```
Also adjust the SwiftUI `Image` rendering site to consume the right type:
```swift
#if os(macOS)
if let img = loadSplashImage() { Image(nsImage: img).resizable() }
#else
if let img = loadSplashImage() { Image(uiImage: img).resizable() }
#endif
```

For the iOS target, add `splash.jpg` to its bundle resources (or move it to IqamahCore if you want a single source).

- [ ] **Step 2: AboutView** — same pattern as SplashScreenView.

- [ ] **Step 3: PrayerTimesView**
```swift
// Find:
Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
// Replace with:
Image("AppIcon")
    .resizable()
```
Add an `AppIcon` image set to both Assets.xcassets bundles (macOS already has the app icon set; iOS needs a sized non-AppIcon image since `AppIcon.appiconset` isn't directly addressable — use a separate `HeaderIcon` image set).

Cleaner refactor: introduce a single `HeaderIconView` in IqamahCore that does the platform branching internally.

- [ ] **Step 4: SettingsSheetView**
Find:
```swift
.frame(width: 480, height: min((NSScreen.main?.visibleFrame.height ?? 900) - 80, 820))
```
Wrap with `#if os(macOS)`:
```swift
#if os(macOS)
.frame(width: 480, height: min((NSScreen.main?.visibleFrame.height ?? 900) - 80, 820))
#endif
```

- [ ] **Step 5: LocationSetupView, CalculationMethodView, QiblahView, IqamahBackground, StepIndicatorView, PrayerTimesComponents**
Build the iOS target and fix compile errors as they appear. Most should be `Color`/`Font`/SwiftUI-only and just work.

- [ ] **Step 6: MenuBarPopoverView** — DO NOT include in iOS target (already macOS-only; ensure file membership excludes iOS target).

- [ ] **Step 7:** Build iOS target until clean
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS -destination 'platform=iOS Simulator,name=iPhone 15' build
```

- [ ] **Step 8:** Commit
```bash
git commit -m "feat(US-0041): port shared views to iOS with platform conditionals"
```

### Task 2.4 — Generate iOS app icons

- [ ] **Step 1:** Run the existing icon generator (macOS) to produce a 1024×1024 master:
```bash
# Use existing AppIconGenerator or AppIconView preview; export to PNG
```

- [ ] **Step 2:** Use a tool like `appicon` (npm) or Xcode's "Single Size" option to produce all required iOS sizes (20pt, 29pt, 40pt, 60pt, 76pt, 83.5pt, 1024pt at appropriate scales).

- [ ] **Step 3:** Drag into the iOS target's `Assets.xcassets/AppIcon.appiconset`.

- [ ] **Step 4:** Build, install on simulator, verify icon appears on home screen.

- [ ] **Step 5:** Commit
```bash
git commit -m "feat(US-0041): add iOS app icon set"
```

### Task 2.5 — iOS Info.plist and entitlements

- [ ] **Step 1:** Edit iOS target Info.plist:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Iqamah uses your location to calculate accurate prayer times for your area.</string>
<key>UILaunchScreen</key>
<dict>
    <key>UIColorName</key>
    <string>LaunchBackgroundColor</string>
</dict>
```

- [ ] **Step 2:** Add `LaunchBackgroundColor` to iOS Assets.xcassets matching the existing macOS splash background.

- [ ] **Step 3:** Create `iqamah-iOS.entitlements` (initially empty — KVS is added in Branch 3).

- [ ] **Step 4:** Build & launch — verify launch screen colour appears briefly.

- [ ] **Step 5:** Commit
```bash
git commit -m "feat(US-0041): configure iOS Info.plist and launch screen"
```

### Task 2.6 — End-to-end smoke test

- [ ] **Step 1:** Fresh install on iOS 17 simulator. Verify:
  - Launch screen → animated splash → location setup → method selection → tab view
  - Manual city selection works
  - GPS auto-detect works (set a simulated location in Simulator → Features → Location)
  - Prayer times displayed match macOS for the same city + method + date
  - Tab switching works (Times / Qiblah / Settings)
  - Settings changes persist across app relaunch

- [ ] **Step 2:** Install on a physical iPhone if available. Verify:
  - GPS works correctly
  - Qiblah view updates with device heading

- [ ] **Step 3:** Verify ACs
- [ ] AC-0175: Builds & installs ✓
- [ ] AC-0176: Universal bundle ID ✓
- [ ] AC-0177: First-launch flow completes ✓
- [ ] AC-0178: Times match macOS ✓
- [ ] AC-0179: Qiblah works on device ✓
- [ ] AC-0180: `grep -r "import AppKit" iqamah-iOS/` returns nothing ✓

- [ ] **Step 4:** Push and open PR
```bash
git push -u origin feat/US-0041-ios-app-target
```

---

## Branch 3 — US-0042: iCloud Settings Sync

**Branch:** `feat/US-0042-icloud-kvs-sync`
**Risk:** Medium — touches shared `SettingsManager`; multi-device test required
**Estimated effort:** 1 day
**Depends on:** US-0041 merged

### Task 3.1 — Add iCloud KVS entitlement to both targets

- [ ] **Step 1:** Open Xcode → iqamah target → Signing & Capabilities → + Capability → iCloud → check "Key-value storage"

- [ ] **Step 2:** Repeat for iqamah-iOS target.

- [ ] **Step 3:** Verify `iqamah.entitlements` and `iqamah-iOS.entitlements` both contain:
```xml
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
```

- [ ] **Step 4:** Build both targets to confirm provisioning profiles regenerate.

- [ ] **Step 5:** Commit
```bash
git commit -m "feat(US-0042): add iCloud KVS entitlement to both app targets"
```

### Task 3.2 — Bridge SettingsManager to NSUbiquitousKeyValueStore

- [ ] **Step 1:** Edit `Packages/IqamahCore/Sources/IqamahCore/Services/SettingsManager.swift`. Add KVS reference:
```swift
private let kvs = NSUbiquitousKeyValueStore.default
```

- [ ] **Step 2:** Update every setter to write through to KVS. Pattern for each `@Published`:
```swift
@Published public var calculationMethod: CalculationMethod {
    didSet {
        defaults.set(calculationMethod.rawValue, forKey: Keys.calculationMethod)
        kvs.set(calculationMethod.rawValue, forKey: Keys.calculationMethod)
        kvs.synchronize()
    }
}
```

Apply to: `selectedCity`, `calculationMethod`, `asrMethod`, `prayerAdjustments`, `selectedAdhaanFile`, `prayerMuteStates`, `appearanceMode`, `gpsLocality`, `gpsTimezone`, `locationSource`.
**Do NOT sync:** `hasCompletedSetup`.

- [ ] **Step 3:** Add the change subscriber in `init()`:
```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleRemoteKVSChange(_:)),
    name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
    object: kvs
)
kvs.synchronize()
```

- [ ] **Step 4:** Implement the handler:
```swift
@objc private func handleRemoteKVSChange(_ note: Notification) {
    guard let userInfo = note.userInfo,
          let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
    else { return }

    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        for key in changedKeys {
            self.applyRemoteValue(forKey: key)
        }
    }
}

private func applyRemoteValue(forKey key: String) {
    switch key {
    case Keys.calculationMethod:
        if let raw = kvs.string(forKey: key),
           let method = CalculationMethod(rawValue: raw),
           method != calculationMethod {
            // Avoid feedback loop: use a private setter that doesn't write back to KVS
            applyCalculationMethodFromRemote(method)
        }
    // ... repeat per key
    default: break
    }
}
```

- [ ] **Step 5:** Add private "from remote" setters that update UserDefaults + the @Published property without re-writing to KVS:
```swift
private func applyCalculationMethodFromRemote(_ method: CalculationMethod) {
    defaults.set(method.rawValue, forKey: Keys.calculationMethod)
    // Bypass didSet to avoid loop
    _calculationMethod = method
    objectWillChange.send()
}
```
(Requires the underlying storage to be a non-@Published `_property` with a custom getter/setter, OR use a flag to suppress the next `didSet` write-back.)

**Simpler alternative:** add a `private var isApplyingRemote = false` flag:
```swift
@Published public var calculationMethod: CalculationMethod {
    didSet {
        guard !isApplyingRemote else { return }
        defaults.set(calculationMethod.rawValue, forKey: Keys.calculationMethod)
        kvs.set(calculationMethod.rawValue, forKey: Keys.calculationMethod)
    }
}

// In handler:
isApplyingRemote = true
calculationMethod = newValue
isApplyingRemote = false
```

- [ ] **Step 6:** Build, test on macOS first.

- [ ] **Step 7:** Commit
```bash
git commit -m "feat(US-0042): bridge SettingsManager setters to NSUbiquitousKeyValueStore"
```

### Task 3.3 — Multi-device verification

- [ ] **Step 1:** Sign in to the same iCloud account on:
  - macOS host
  - iOS Simulator (Settings → Sign in to your iPhone)

- [ ] **Step 2:** Install macOS app + iOS app, complete setup on each independently.

- [ ] **Step 3:** Test cases:
  - Change calculation method on macOS → wait 30s → iOS reflects new method
  - Change selected city on iOS → wait 30s → macOS reflects new city
  - Change per-prayer adjustment on macOS → iOS reflects
  - Change adhaan selection per prayer → syncs both ways
  - Sign out of iCloud on iOS → app continues to work using local UserDefaults

- [ ] **Step 4:** Verify ACs (AC-0181 through AC-0186).

- [ ] **Step 5:** Commit any test fixes; push and open PR.

---

## Branch 4 — US-0043: iOS Local Prayer Notifications

**Branch:** `feat/US-0043-ios-notifications`
**Risk:** Low–medium — iOS-only, well-understood APIs
**Estimated effort:** 0.5–1 day
**Depends on:** US-0041 merged (US-0042 not strictly required)

### Task 4.1 — NotificationScheduler service

- [ ] **Step 1:** Create `iqamah-iOS/NotificationScheduler.swift`:
```swift
import Foundation
import UserNotifications
import IqamahCore

@MainActor
final class NotificationScheduler: ObservableObject {
    static let shared = NotificationScheduler()
    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            return granted
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func rescheduleAll() async {
        guard await requestAuthorizationIfNeeded() else { return }
        center.removeAllPendingNotificationRequests()

        let settings = SettingsManager.shared
        guard let coord = settings.activeCoordinate,
              let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier)
        else { return }

        let calc = PrayerCalculator(
            coordinate: coord,
            timezone: timezone,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )

        let calendar = Calendar(identifier: .gregorian)
        let today = Date()

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let times = calc.prayerTimes(for: day)

            for prayer in times.prayers where settings.isPrayerEnabled(prayer.name) {
                let request = makeRequest(prayer: prayer, date: day)
                try? await center.add(request)
            }
        }
    }

    private func makeRequest(prayer: PrayerTime, date: Date) -> UNNotificationRequest {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let id = "prayer.\(prayer.name).\(formatter.string(from: date))"

        let content = UNMutableNotificationContent()
        content.title = "Iqamah"
        content.body = "It is time for \(prayer.name)"
        content.sound = .default
        content.userInfo = ["prayerName": prayer.name]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: prayer.time
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }
}
```

- [ ] **Step 2:** Add `isPrayerEnabled(_:)` and per-prayer toggle storage to `SettingsManager` (in IqamahCore):
```swift
@Published public var enabledPrayers: Set<String> {
    didSet { /* persist + KVS */ }
}

public func isPrayerEnabled(_ name: String) -> Bool {
    enabledPrayers.contains(name)
}
```
Default value: all five prayers enabled (Fajr, Dhuhr, Asr, Maghrib, Isha — Sunrise excluded).

- [ ] **Step 3:** Wire up scheduling triggers in iOS app:
```swift
// In iqamahApp_iOS.swift
.onChange(of: settings.calculationMethod) { _, _ in Task { await NotificationScheduler.shared.rescheduleAll() } }
.onChange(of: settings.selectedCity)      { _, _ in Task { await NotificationScheduler.shared.rescheduleAll() } }
.onChange(of: settings.enabledPrayers)    { _, _ in Task { await NotificationScheduler.shared.rescheduleAll() } }

// On scenePhase becoming active:
@Environment(\.scenePhase) var scenePhase
.onChange(of: scenePhase) { _, new in
    if new == .active { Task { await NotificationScheduler.shared.rescheduleAll() } }
}
```

- [ ] **Step 4:** Add per-prayer toggles to the iOS Settings tab UI.

- [ ] **Step 5:** Implement notification tap handler — on `didReceive`, post a `NotificationCenter` message that `iOSRootView` observes to switch to the Times tab.

- [ ] **Step 6:** Test on simulator (Features → Trigger Notification at scheduled time, or set device clock).

- [ ] **Step 7:** Verify ACs (AC-0187 through AC-0192).

- [ ] **Step 8:** Push and open PR.

---

## Branch 5 — US-0044: iOS Widget Extension

**Branch:** `feat/US-0044-ios-widget`
**Risk:** Medium — new extension target, app group setup
**Estimated effort:** 1 day
**Depends on:** US-0041 merged

### Task 5.1 — Add Widget Extension target

- [ ] **Step 1:** Xcode → File → New → Target → iOS → Widget Extension
  - Product Name: `IqamahWidget`
  - Bundle Identifier: `com.fablesoft.iqamah.widget`
  - Include Configuration Intent: No (use static configuration for v1)

- [ ] **Step 2:** Add `IqamahCore` as a dependency.

- [ ] **Step 3:** Build to confirm template widget runs.

### Task 5.2 — App Group for shared UserDefaults

- [ ] **Step 1:** Both iOS app and widget targets → Signing & Capabilities → + App Groups → add `group.com.fablesoft.iqamah`.

- [ ] **Step 2:** Modify `SettingsManager` to optionally use a suite name:
```swift
public init(suiteName: String? = nil) {
    self.defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    // ...
}
public static let shared = SettingsManager(suiteName: "group.com.fablesoft.iqamah")
```
Caveat: this changes UserDefaults storage location — existing users will appear to lose their settings on first launch after upgrade. Mitigation: one-time migration that copies values from `.standard` to the group suite at init.

- [ ] **Step 3:** Add the migration:
```swift
private func migrateFromStandardDefaultsIfNeeded() {
    let migrationKey = "didMigrateToAppGroupV1"
    guard !defaults.bool(forKey: migrationKey) else { return }
    let std = UserDefaults.standard
    for key in Keys.allKeys {
        if let value = std.object(forKey: key) {
            defaults.set(value, forKey: key)
        }
    }
    defaults.set(true, forKey: migrationKey)
}
```

### Task 5.3 — Widget timeline + views

- [ ] **Step 1:** Implement `IqamahWidget.swift`:
```swift
import WidgetKit
import SwiftUI
import IqamahCore

struct PrayerEntry: TimelineEntry {
    let date: Date
    let nextPrayer: String
    let nextPrayerTime: Date
    let cityName: String
}

struct PrayerTimelineProvider: TimelineProvider {
    func placeholder(in: Context) -> PrayerEntry { /* stub */ }
    func getSnapshot(in: Context, completion: @escaping (PrayerEntry) -> Void) { /* stub */ }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let settings = SettingsManager.shared
        guard let coord = settings.activeCoordinate else {
            completion(Timeline(entries: [emptyEntry()], policy: .never))
            return
        }
        let calc = PrayerCalculator(
            coordinate: coord,
            timezone: TimeZone(identifier: settings.activeTimezoneIdentifier) ?? .current,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )
        let now = Date()
        let times = calc.prayerTimes(for: now).prayers
        let upcoming = times.first(where: { $0.time > now }) ?? calc.prayerTimes(for: now.addingTimeInterval(86400)).prayers.first!

        let entries = stride(from: 0, to: 60, by: 1).map { minute -> PrayerEntry in
            let date = now.addingTimeInterval(TimeInterval(minute * 60))
            return PrayerEntry(date: date, nextPrayer: upcoming.name, nextPrayerTime: upcoming.time, cityName: settings.activeCityName)
        }

        completion(Timeline(entries: entries, policy: .after(upcoming.time)))
    }
}

struct IqamahWidgetView: View {
    var entry: PrayerEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall: smallLayout
        case .systemMedium: mediumLayout
        case .accessoryRectangular: lockScreenLayout
        default: smallLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading) {
            Text(entry.nextPrayer).font(.headline)
            Text(entry.nextPrayerTime, style: .relative).font(.title2.monospacedDigit())
        }
        .padding()
    }
    // mediumLayout, lockScreenLayout similar
}

@main
struct IqamahWidgetBundle: WidgetBundle {
    var body: some Widget { IqamahWidget() }
}

struct IqamahWidget: Widget {
    let kind: String = "IqamahWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            IqamahWidgetView(entry: entry)
        }
        .configurationDisplayName("Iqamah Next Prayer")
        .description("Shows the time until your next prayer.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
```

- [ ] **Step 2:** Trigger widget refresh from the iOS app on settings/location change:
```swift
import WidgetKit
WidgetCenter.shared.reloadAllTimelines()
```

- [ ] **Step 3:** Test: install on simulator, add widget to Home Screen, verify countdown updates and transitions to next prayer correctly.

- [ ] **Step 4:** Verify ACs (AC-0193 through AC-0197). Push and open PR.

---

## Branch 6 — US-0045: Live Activity / Dynamic Island

**Branch:** `feat/US-0045-live-activity`
**Risk:** Medium — ActivityKit lifecycle, Dynamic Island layouts
**Estimated effort:** 1 day
**Depends on:** US-0044 merged (shares the widget extension bundle)

### Task 6.1 — ActivityAttributes in IqamahCore

- [ ] **Step 1:** Add `Packages/IqamahCore/Sources/IqamahCore/Models/PrayerActivityAttributes.swift`:
```swift
#if canImport(ActivityKit)
import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct PrayerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let scheduledTime: Date
        public init(scheduledTime: Date) { self.scheduledTime = scheduledTime }
    }
    public let prayerName: String
    public let methodName: String

    public init(prayerName: String, methodName: String) {
        self.prayerName = prayerName
        self.methodName = methodName
    }
}
#endif
```

### Task 6.2 — Live Activity views in widget extension

- [ ] **Step 1:** Add `IqamahWidget/IqamahLiveActivity.swift`:
```swift
import ActivityKit
import WidgetKit
import SwiftUI
import IqamahCore

@available(iOS 16.1, *)
struct IqamahLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            // Lock Screen layout
            VStack {
                Text(context.attributes.prayerName).font(.headline)
                Text(context.state.scheduledTime, style: .timer)
                    .font(.title.monospacedDigit())
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.prayerName).font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.scheduledTime, style: .timer)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.methodName).font(.caption)
                }
            } compactLeading: {
                Image(systemName: "moon.stars")
            } compactTrailing: {
                Text(context.state.scheduledTime, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 60)
            } minimal: {
                Image(systemName: "moon.stars")
            }
        }
    }
}
```

- [ ] **Step 2:** Add to widget bundle:
```swift
@main
struct IqamahWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        IqamahWidget()
        if #available(iOS 16.1, *) { IqamahLiveActivity() }
    }
}
```

### Task 6.3 — Triggering Live Activities from the iOS app

- [ ] **Step 1:** Add `LiveActivityManager.swift` to iOS target:
```swift
import ActivityKit
import IqamahCore

@available(iOS 16.1, *)
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var activities: [String: Activity<PrayerActivityAttributes>] = [:]

    func startIfDue(prayer: PrayerTime, methodName: String) {
        let secondsUntil = prayer.time.timeIntervalSinceNow
        guard secondsUntil > 0, secondsUntil <= 3600 else { return }
        guard activities[prayer.name] == nil else { return }

        let attributes = PrayerActivityAttributes(prayerName: prayer.name, methodName: methodName)
        let state = PrayerActivityAttributes.ContentState(scheduledTime: prayer.time)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: prayer.time.addingTimeInterval(60))
            )
            activities[prayer.name] = activity
            // Schedule end at prayer time
            Task {
                try? await Task.sleep(nanoseconds: UInt64(secondsUntil * 1_000_000_000))
                await activity.end(nil, dismissalPolicy: .immediate)
                activities.removeValue(forKey: prayer.name)
            }
        } catch {
            print("Live Activity failed: \(error)")
        }
    }
}
```

- [ ] **Step 2:** Add `NSSupportsLiveActivities = true` to iOS target Info.plist.

- [ ] **Step 3:** Drive `startIfDue` from the iOS app on timer (every minute) or on app foreground; respect `enabledPrayers`.

- [ ] **Step 4:** Test on a physical device (Live Activities don't render in simulator's Dynamic Island reliably).

- [ ] **Step 5:** Verify ACs (AC-0198 through AC-0203). Push and open PR.

---

## Final integration — after all 6 PRs merge

- [ ] **Step 1:** Update App Store Connect to add iOS as a platform on the existing app record.
- [ ] **Step 2:** Generate iOS App Store screenshots (per `docs/APP_STORE_LISTING.md` — extend with iOS sizes).
- [ ] **Step 3:** Submit iOS build for review alongside next macOS build.
- [ ] **Step 4:** Update `docs/RELEASE_PLAN.md`: mark EPIC-0010 stories ✅ as they ship.
- [ ] **Step 5:** Update `docs/competitive-analysis.md` to reflect iOS parity.
- [ ] **Step 6:** Tag release `v2.0.0`.

---

## Risk register

| Risk | Mitigation |
|------|------------|
| Xcode `project.pbxproj` corruption during file moves | Make moves in Xcode UI, not text edits; commit after each task |
| `Bundle.module` resource lookups fail at runtime | Smoke-test cities and audio loading after Branch 1 |
| App Group migration loses existing macOS user settings | One-time migration code in Branch 5 (Task 5.2 Step 3) |
| iCloud KVS sync feedback loop | `isApplyingRemote` flag in Branch 3 (Task 3.2 Step 5) |
| iOS notification sound files exceed 30s limit | Use `.default` sound for v1 (per spec §6.4); custom sounds = follow-up PR |
| Live Activity not appearing on simulator | Test on physical device; document in PR test plan |
| Universal bundle ID conflicts in App Store Connect | Validate bundle ID is configured for both macOS and iOS in App Store Connect before submitting |

---

## Cross-references

- Spec: `docs/superpowers/specs/2026-05-09-ios-conversion-design.md`
- Backlog: `docs/RELEASE_PLAN.md` § EPIC-0010
- ID Registry: `docs/ID_REGISTRY.md`
- Existing macOS conventions: `docs/superpowers/plans/2026-05-07-p1-p2-p3-implementation.md`
