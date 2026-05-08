# Iqamah P1/P2/P3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement GPS prayer time accuracy, always-visible adhaan picker layout, audio failure feedback, settings sheet completion, and the menu bar left-click popover with right-click menu redesign.

**Architecture:** Five independent feature branches merged sequentially to `develop`. Each branch is self-contained and shippable. The popover (Branch 5) and right-click menu share `AppDelegate.swift` and ship together.

**Tech Stack:** Swift 5.10, SwiftUI, AppKit (`NSPopover`, `NSMenu`), CoreLocation (`CLGeocoder`), AVFoundation, UserDefaults, Combine

---

## Pre-flight: Already Done (do not re-implement)

Code inspection confirmed these spec items are already in the codebase:
- **BUG-0031/32/38/42/45** (housekeeping) — `Color+App.swift` ✅, `PrivacyInfo.xcprivacy` ✅, `ForEach id: \.name` ✅, `.md` files absent from Copy Resources ✅, Display Size stepper removed ✅
- **Per-prayer mute toggle** — speaker icon already in `PrayerTimeRow` ✅
- **Master mute** — `AdhaaanPlayer.isMuted` with UserDefaults persistence ✅
- **Settings Form.grouped** — already used for Location/Calculation/Display sections ✅
- **±adjustment accessibility labels** — already on both buttons ✅

---

## Branch 1 — ENH-001: GPS Exact Prayer Times
**Branch:** `feat/ENH-001-gps-accuracy`

**Files:**
- Modify: `iqamah/Views/LocationSetupView.swift`
- Modify: `iqamah/Services/SettingsManager.swift`
- Modify: `iqamah/AppDelegate.swift`
- Test: `Tests/LocationServiceTests.swift` (add cases)

**What exists today:** `LocationSetupView` calls `LocationService` to get `CLLocation`, finds the nearest city via `CitiesDatabase.closestCity(to:)`, then saves that city's stored timezone string via `SettingsManager.completeSetup(city:...)`. Prayer calculations use the stored city's coordinates and timezone — not the raw GPS fix.

**What changes:** For GPS auto-detect only, use raw GPS coordinates for calculation and `TimeZone.current` immediately (Option A), then fire CLGeocoder to get the authoritative timezone and locality name (Option B). Manual city selection is unchanged.

---

### Task 1.1: Add GPS cache keys to SettingsManager

**Files:**
- Modify: `iqamah/Services/SettingsManager.swift`

- [ ] **Step 1: Add new Keys and published properties**

In `SettingsManager`, inside the `Keys` enum, add:
```swift
static let gpsLatitude    = "gpsLatitude"
static let gpsLongitude   = "gpsLongitude"
static let gpsLocality    = "gpsLocality"
static let gpsTimezone    = "gpsTimezone"
static let locationSource = "locationSource"  // "gps" or "manual"
```

Add to the class body after existing `@Published` properties:
```swift
@Published var locationSource: String {
    didSet { defaults.set(locationSource, forKey: Keys.locationSource) }
}
@Published var gpsLocality: String {
    didSet { defaults.set(gpsLocality, forKey: Keys.gpsLocality) }
}
@Published var gpsTimezone: String {
    didSet { defaults.set(gpsTimezone, forKey: Keys.gpsTimezone) }
}
```

In `init()`, load them:
```swift
locationSource = defaults.string(forKey: Keys.locationSource) ?? "manual"
gpsLocality    = defaults.string(forKey: Keys.gpsLocality) ?? ""
gpsTimezone    = defaults.string(forKey: Keys.gpsTimezone) ?? TimeZone.current.identifier
```

Add a helper for GPS coordinate cache:
```swift
func saveGPSCoordinates(_ coordinate: CLLocationCoordinate2D) {
    defaults.set(coordinate.latitude,  forKey: Keys.gpsLatitude)
    defaults.set(coordinate.longitude, forKey: Keys.gpsLongitude)
}

func cachedGPSCoordinate() -> CLLocationCoordinate2D? {
    let lat = defaults.double(forKey: Keys.gpsLatitude)
    let lon = defaults.double(forKey: Keys.gpsLongitude)
    guard lat != 0 || lon != 0 else { return nil }
    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
}
```

- [ ] **Step 2: Build to confirm no errors**
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**
```bash
git add iqamah/Services/SettingsManager.swift
git commit -m "feat(ENH-001): add GPS cache keys and coordinate helpers to SettingsManager"
```

---

### Task 1.2: Use raw GPS coordinates and TimeZone.current (Option A)

**Files:**
- Modify: `iqamah/Views/LocationSetupView.swift`

- [ ] **Step 1: Find the GPS auto-detect success path**

In `LocationSetupView`, find where `LocationService` returns a location and `closestCity` is called. It looks like:
```swift
let location = try await locationService.requestLocation()
if let city = database.closestCity(to: location.coordinate) {
    // saves city ...
}
```

- [ ] **Step 2: Apply Option A — use raw GPS coords and TimeZone.current**

Replace the GPS success handler with:
```swift
let location = try await locationService.requestLocation()
let coordinate = location.coordinate

// Option A: immediate fix — use raw GPS coord + device timezone
SettingsManager.shared.locationSource = "gps"
SettingsManager.shared.saveGPSCoordinates(coordinate)
SettingsManager.shared.gpsTimezone = TimeZone.current.identifier

// Still find nearest city for display name (Option B will refine this)
if let city = database.closestCity(to: coordinate) {
    SettingsManager.shared.gpsLocality = city.name
    SettingsManager.shared.completeSetup(
        city: City(
            name: city.name,
            countryCode: city.countryCode,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timezone: TimeZone.current.identifier
        ),
        calculationMethod: selectedMethod,
        asrMethod: selectedAsrMethod
    )
}

// Fire Option B geocoder asynchronously
reverseGeocodeAndUpdate(coordinate: coordinate)
```

- [ ] **Step 3: Add the CLGeocoder helper (Option B)**

Add this method to `LocationSetupView`:
```swift
private func reverseGeocodeAndUpdate(coordinate: CLLocationCoordinate2D) {
    // Skip if coords haven't moved more than 5 km from cache
    if let cached = SettingsManager.shared.cachedGPSCoordinate() {
        let cachedLocation = CLLocation(latitude: cached.latitude, longitude: cached.longitude)
        let newLocation    = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if cachedLocation.distance(from: newLocation) < 5000 &&
           !SettingsManager.shared.gpsLocality.isEmpty { return }
    }

    CLGeocoder().reverseGeocodeLocation(
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    ) { placemarks, error in
        guard error == nil,
              let placemark = placemarks?.first else {
            // Fallback already applied via Option A — nothing more to do
            print("[ENH-001] CLGeocoder failed: \(error?.localizedDescription ?? "unknown")")
            return
        }

        let locality = placemark.locality ?? placemark.name ?? SettingsManager.shared.gpsLocality
        let timezone = placemark.timeZone?.identifier ?? TimeZone.current.identifier

        DispatchQueue.main.async {
            SettingsManager.shared.gpsLocality  = locality
            SettingsManager.shared.gpsTimezone  = timezone

            // Update the stored city with authoritative values
            if var city = SettingsManager.shared.savedCity() {
                let refined = try? City(
                    name: locality,
                    countryCode: city.countryCode,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    timezone: timezone
                )
                if let refined { SettingsManager.shared.saveCity(refined) }
            }
        }
    }
}
```

- [ ] **Step 4: Build**
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Update AppDelegate status bar display name**

In `AppDelegate.updateStatusBarDisplay()`, find where the city name is read for the status bar label. Change it to prefer `gpsLocality` when `locationSource == "gps"`:
```swift
let displayCity: String
if SettingsManager.shared.locationSource == "gps" && !SettingsManager.shared.gpsLocality.isEmpty {
    displayCity = SettingsManager.shared.gpsLocality
} else {
    displayCity = SettingsManager.shared.savedCity()?.name ?? "—"
}
```

- [ ] **Step 6: Build and commit**
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
git add iqamah/Views/LocationSetupView.swift iqamah/AppDelegate.swift
git commit -m "feat(ENH-001): use raw GPS coords + TimeZone.current, CLGeocoder for locality and timezone"
```

---

### Task 1.3: Write tests for GPS coordinate cache helpers

**Files:**
- Modify: `Tests/LocationServiceTests.swift` (or create `Tests/ENH001GPSTests.swift`)

- [ ] **Step 1: Write tests**
```swift
import XCTest
@testable import iqamah

final class ENH001GPSTests: XCTestCase {
    var settings: SettingsManager!

    override func setUp() {
        super.setUp()
        settings = SettingsManager(userDefaults: UserDefaults(suiteName: "test.gps")!)
    }

    override func tearDown() {
        UserDefaults(suiteName: "test.gps")?.removePersistentDomain(forName: "test.gps")
        super.tearDown()
    }

    func testSaveAndRecallGPSCoordinates() {
        let coord = CLLocationCoordinate2D(latitude: 43.685, longitude: -79.759)
        settings.saveGPSCoordinates(coord)
        let recalled = settings.cachedGPSCoordinate()
        XCTAssertNotNil(recalled)
        XCTAssertEqual(recalled!.latitude,  coord.latitude,  accuracy: 0.0001)
        XCTAssertEqual(recalled!.longitude, coord.longitude, accuracy: 0.0001)
    }

    func testCachedCoordinateNilWhenEmpty() {
        XCTAssertNil(settings.cachedGPSCoordinate())
    }

    func testLocationSourceDefaultsToManual() {
        XCTAssertEqual(settings.locationSource, "manual")
    }
}
```

- [ ] **Step 2: Run tests**
```bash
xcodebuild test -project iqamah.xcodeproj -scheme iqamah -destination 'platform=macOS' 2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```
Expected: all new tests pass

- [ ] **Step 3: Commit and open PR**
```bash
git add Tests/ENH001GPSTests.swift
git commit -m "test(ENH-001): GPS coordinate cache round-trip tests"
git push -u origin feat/ENH-001-gps-accuracy
# Open PR to develop, merge after CI green
```

---

## Branch 2 — BUG-0039: Adhaan Picker Always-Visible Layout
**Branch:** `fix/BUG-0039-adhaan-picker`

**Files:**
- Modify: `iqamah/Views/PrayerTimesView.swift`

**What exists today:** `adhaanColumnButton` is a `Button(action: onTogglePicker)` that shows the current selection name but only opens the chip picker when tapped. The per-prayer mute (speaker icon) already exists in `mainRowContent`. The layout order is `[icon+name] [spacer] [adhaan button] [time] [±controls] [mute]`.

**What changes:** 
1. The adhaan pill moves to a fixed always-visible column position, clearly centred between a divider and the mute toggle.
2. The time and ±controls stay grouped together, right-aligned.
3. Layout becomes: `[icon+name] [Spacer] [time] [±] | [adhaan pill centred] [mute]`

---

### Task 2.1: Restructure mainRowContent layout

**Files:**
- Modify: `iqamah/Views/PrayerTimesView.swift` — `mainRowContent` computed property (around line 412)

- [ ] **Step 1: Replace the mainRowContent HStack**

The current layout (simplified):
```swift
HStack(spacing: 16) {
    // icon + name
    Spacer()
    adhaanColumnButton   // ← moves
    Text(time)           // time
    HStack { minus; plus } // ±
    // mute speaker (already exists)
}
```

Replace with:
```swift
private var mainRowContent: some View {
    HStack(spacing: 0) {
        // Left accent stripe
        Rectangle()
            .fill(isHighlighted ? effectiveGold : Color.clear)
            .frame(width: 4)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .padding(.vertical, 8)

        HStack(spacing: 0) {
            // Icon circle + name
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isHighlighted
                            ? effectiveGold.opacity(0.20)
                            : Color.secondary.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: iconName)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(isHighlighted ? effectiveGold : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body.bold())
                        .foregroundStyle(isHighlighted ? effectiveGold : .primary)
                    if isHighlighted {
                        Text("NEXT")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(effectiveGold.opacity(0.85))
                            .tracking(1.2)
                    }
                }
            }
            .padding(.leading, 16)

            Spacer()

            // Time + ± grouped together, right-aligned
            HStack(spacing: 8) {
                Text(formatter.string(from: time))
                    .font(isHighlighted ? .title2.weight(.semibold) : .title3.weight(.medium))
                    .foregroundStyle(isHighlighted ? effectiveGold : .primary)
                    .monospacedDigit()
                    .frame(minWidth: 72, alignment: .trailing)
                    .overlay(alignment: .topTrailing) {
                        if adjustment != 0 {
                            Text(adjustment > 0 ? "+\(adjustment)" : "\(adjustment)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.red.opacity(0.8)))
                                .offset(x: 4, y: -4)
                                .accessibilityLabel("\(abs(adjustment)) minute adjustment")
                        }
                    }

                HStack(spacing: 6) {
                    Button(action: { onAdjust(-1) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .help("Decrease \(name) by 1 minute")
                    .accessibilityLabel("Decrease \(name) time by 1 minute")
                    .accessibilityHint("Current adjustment: \(adjustment) minutes")

                    Button(action: { onAdjust(1) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .help("Increase \(name) by 1 minute")
                    .accessibilityLabel("Increase \(name) time by 1 minute")
                    .accessibilityHint("Current adjustment: \(adjustment) minutes")
                }
            }
            .padding(.trailing, 8)

            // Divider between time/± and adhaan column
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1, height: 28)
                .padding(.horizontal, 10)

            // Adhaan pill — always visible, centred in fixed column
            adhaanColumnButton
                .frame(width: 100)

            // Per-prayer mute (already exists — keep as-is)
            Button(action: { isPrayerMuted.toggle() }) {
                Image(systemName: isPrayerMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.callout)
                    .foregroundStyle(isPrayerMuted ? .orange : .secondary)
                    .symbolRenderingMode(.hierarchical)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isPrayerMuted ? "Unmute \(name) adhaan" : "Mute \(name) adhaan")
            .accessibilityLabel(isPrayerMuted ? "Unmute \(name) adhaan" : "Mute \(name) adhaan")
            .opacity(player.isMuted ? 0.4 : 1.0)
            .frame(width: 36)
            .padding(.trailing, 16)
        }
    }
}
```

- [ ] **Step 2: Update adhaanColumnButton to use pill style**

The existing `adhaanColumnButton` already shows `selectedAdhaan.shortName`. Update its appearance so it always looks like a labelled pill with chevron, not a borderless icon button. Replace the button label content:

```swift
private var adhaanColumnButton: some View {
    Button(action: onTogglePicker) {
        HStack(spacing: 3) {
            Text(selectedAdhaan.id == "silent" ? "No adhaan" : selectedAdhaan.shortName)
                .font(.caption.weight(.medium))
                .foregroundStyle(selectedAdhaan.id == "silent"
                    ? Color.secondary.opacity(0.6)
                    : (isPrayerMuted ? Color.secondary.opacity(0.4) : effectiveGold.opacity(0.85)))
                .lineLimit(1)
                .strikethrough(isPrayerMuted && selectedAdhaan.id != "silent",
                               color: Color.secondary.opacity(0.5))
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(selectedAdhaan.id == "silent"
                    ? Color.secondary.opacity(0.07)
                    : (isPrayerMuted
                        ? Color.secondary.opacity(0.05)
                        : effectiveGold.opacity(colorScheme == .dark ? 0.10 : 0.12)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(selectedAdhaan.id == "silent"
                    ? Color.secondary.opacity(0.15)
                    : (isPrayerMuted
                        ? Color.secondary.opacity(0.10)
                        : effectiveGold.opacity(0.22)), lineWidth: 0.5)
        )
    }
    .buttonStyle(.plain)
    .help(selectedAdhaan.id == "silent"
        ? "Tap to set adhaan for \(name)"
        : "Adhaan: \(selectedAdhaan.displayName) — tap to change")
    .accessibilityLabel(selectedAdhaan.id == "silent"
        ? "No adhaan set for \(name). Tap to set."
        : "Adhaan for \(name): \(selectedAdhaan.displayName). Tap to change.")
}
```

- [ ] **Step 3: Build**
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Launch app and visually verify**
Run the app. Confirm:
- All prayer rows show the adhaan pill immediately (no hover required)
- Pill shows "No adhaan" (grey, no strikethrough) when silent
- Pill shows adhaan name in gold when a sound is selected
- Pill shows strikethrough when prayer-muted with a sound selected
- Time and ±controls are grouped together on the right
- Tapping the pill still opens/closes the chip picker section below

- [ ] **Step 5: Commit and push**
```bash
git add iqamah/Views/PrayerTimesView.swift
git commit -m "fix(BUG-0039): adhaan pill always visible, time+controls grouped, strikethrough muted state"
git push -u origin fix/BUG-0039-adhaan-picker
# Open PR to develop, merge after CI green
```

---

## Branch 3 — BUG-0050: Adhaan Failure Feedback
**Branch:** `fix/BUG-0050-adhaan-failure`

**Files:**
- Modify: `iqamah/Services/AdhaaanPlayer.swift`
- Modify: `iqamah/Views/AdhaanBannerView.swift`

**What exists today:** `AdhaaanPlayer.play()` prints to console when `play()` returns false but does not surface this to the UI. `AdhaanBannerView` shows the banner regardless.

**What changes:** Publish `audioFailed: Bool` from `AdhaaanPlayer`. `AdhaanBannerView` observes it and shows a warning row when true.

---

### Task 3.1: Publish audioFailed from AdhaaanPlayer

**Files:**
- Modify: `iqamah/Services/AdhaaanPlayer.swift`

- [ ] **Step 1: Add @Published var audioFailed**

In `AdhaaanPlayer`, add after `@Published var isPlaying`:
```swift
@Published var audioFailed = false
```

- [ ] **Step 2: Set it on play failure, reset on success and stop**

In the `play(_:)` method, find:
```swift
if newPlayer.play() {
    player = newPlayer
    isPlaying = true
    print("AdhaaanPlayer: play() returned false — audio subsystem busy or unavailable")
}
```

Replace with:
```swift
if newPlayer.play() {
    player = newPlayer
    isPlaying = true
    audioFailed = false
} else {
    print("[AdhaaanPlayer] play() returned false — audio subsystem busy or unavailable")
    audioFailed = true
}
```

In `stop()`, add:
```swift
audioFailed = false
```

In `audioPlayerDidFinishPlaying`, the existing hop back to MainActor already sets `isPlaying = false`. Add:
```swift
Task { @MainActor in
    self.isPlaying = false
    self.audioFailed = false  // ← add this
}
```

- [ ] **Step 3: Build**
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**
```bash
git add iqamah/Services/AdhaaanPlayer.swift
git commit -m "fix(BUG-0050): publish audioFailed on play() failure, reset on stop/finish"
```

---

### Task 3.2: Show warning in AdhaanBannerView when audio fails

**Files:**
- Modify: `iqamah/Views/AdhaanBannerView.swift`

- [ ] **Step 1: Read current banner structure**
```bash
cat -n iqamah/Views/AdhaanBannerView.swift
```

- [ ] **Step 2: Add audio failure warning row**

In `AdhaanBannerView`, add `@ObservedObject var player = AdhaaanPlayer.shared` if not already present.

Inside the banner's `VStack` (after the prayer name / time row), add:
```swift
if player.audioFailed {
    HStack(spacing: 4) {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.caption2)
            .foregroundStyle(Color.yellow.opacity(0.85))
        Text("Audio unavailable")
            .font(.caption2)
            .foregroundStyle(Color.yellow.opacity(0.85))
    }
    .transition(.opacity)
}
```

Wrap the insertion in `withAnimation(.easeIn(duration: 0.2))` if the banner uses animation blocks.

- [ ] **Step 3: Build and test**
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

To test without real audio failure, temporarily add `AdhaaanPlayer.shared.audioFailed = true` to `applicationDidFinishLaunching` in `AppDelegate`, run the app, trigger an adhaan, verify the warning appears. Remove the test line before committing.

- [ ] **Step 4: Commit and push**
```bash
git add iqamah/Views/AdhaanBannerView.swift
git commit -m "fix(BUG-0050): show audio unavailable warning in adhaan banner when play() fails"
git push -u origin fix/BUG-0050-adhaan-failure
# Open PR to develop, merge after CI green
```

---

## Branch 4 — BUG-0046: Settings Sheet Completion
**Branch:** `fix/BUG-0046-settings-form`

**Files:**
- Modify: `iqamah/Views/SettingsSheetView.swift`
- Modify: `iqamah/iqamahApp.swift`

**What exists today:** `SettingsSheetView` uses `Form { }.formStyle(.grouped)` for Location, Calculation, and Display sections. Missing: (1) Adjustments section not in the Form, (2) section headers are plain strings not `Label(icon:)`, (3) `AppAppearance` is stored in `SettingsManager` but `.preferredColorScheme()` is not applied at the app root.

---

### Task 4.1: Apply preferredColorScheme at app root

**Files:**
- Modify: `iqamah/iqamahApp.swift`

- [ ] **Step 1: Read iqamahApp.swift**
```bash
cat -n iqamah/iqamahApp.swift
```

- [ ] **Step 2: Inject preferredColorScheme on WindowGroup content**

`SettingsManager.shared.appearance` is an `AppAppearance` enum with `.colorScheme: ColorScheme?`. Apply it on the root content view:

```swift
@main
struct iqamahApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var settings = SettingsManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 620, height: 680)
        .windowResizability(.contentSize)
    }
}
```

- [ ] **Step 3: Build**
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Verify theme switching works**
Run app → open Settings → switch theme → confirm the window changes appearance immediately on Save.

- [ ] **Step 5: Commit**
```bash
git add iqamah/iqamahApp.swift
git commit -m "fix(BUG-0046): apply preferredColorScheme from SettingsManager at WindowGroup root"
```

---

### Task 4.2: Add section icons and Adjustments section to Form

**Files:**
- Modify: `iqamah/Views/SettingsSheetView.swift`

- [ ] **Step 1: Read the current settingsForm and section properties**
```bash
sed -n '180,300p' iqamah/Views/SettingsSheetView.swift
```

- [ ] **Step 2: Replace Form section headers with Label(icon:)**

Update `settingsForm`:
```swift
private var settingsForm: AnyView {
    AnyView(
        Form {
            Section {
                locationSection
            } header: {
                Label("Location", systemImage: "location.fill")
            }

            Section {
                calculationSection
            } header: {
                Label("Calculation", systemImage: "function")
            }

            Section {
                displaySection
            } header: {
                Label("Display", systemImage: "display")
            }

            Section {
                adjustmentsSection
            } header: {
                Label("Adjustments", systemImage: "timer")
            } footer: {
                Button("Reset all adjustments", role: .destructive) {
                    SettingsManager.shared.resetAllAdjustments()
                    selectedAdjustments = Dictionary(
                        uniqueKeysWithValues: PrayerName.allCases.map { ($0.rawValue, 0) }
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .padding(.top, 4)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, minHeight: 480)
    )
}
```

- [ ] **Step 3: Implement adjustmentsSection**

Add or update the `adjustmentsSection` computed property. It should mirror what currently exists for adjustments (±1 minute steppers per prayer). If `adjustmentsSection` doesn't exist yet, add:

```swift
private var adjustmentsSection: some View {
    ForEach(["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"], id: \.self) { name in
        let binding = Binding<Int>(
            get: { selectedAdjustments[name] ?? 0 },
            set: { selectedAdjustments[name] = $0 }
        )
        Stepper(value: binding, in: -60...60) {
            HStack {
                Text(name)
                Spacer()
                let val = selectedAdjustments[name] ?? 0
                Text(val == 0 ? "±0 min" : (val > 0 ? "+\(val) min" : "\(val) min"))
                    .foregroundStyle(val == 0 ? .secondary : .orange)
                    .font(.caption.monospacedDigit())
            }
        }
    }
}
```

(Adjust to match existing state variables — `selectedAdjustments` is already a `[String: Int]` `@State` in the view from the current implementation.)

- [ ] **Step 4: Build and verify**
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```
Run app → open Settings → confirm: all 4 sections present with icons, Adjustments section shows stepper rows, Reset button in footer, sheet height adapts to content.

- [ ] **Step 5: Commit and push**
```bash
git add iqamah/Views/SettingsSheetView.swift
git commit -m "fix(BUG-0046): add section icons and Adjustments section to Form; adaptive height"
git push -u origin fix/BUG-0046-settings-form
# Open PR to develop, merge after CI green
```

---

## Branch 5 — US-0015: Menu Bar Popover + Right-Click Menu Redesign
**Branch:** `feat/US-0015-popover`

**Files:**
- Create: `iqamah/Views/MenuBarPopoverView.swift`
- Modify: `iqamah/AppDelegate.swift`

**What exists today:** Left-click calls `toggleWindow()` (shows/hides the main window). Right-click calls `showMenu()` with: Show Prayer Times / Help & Support / Privacy Policy / Quit.

**What changes:** Left-click → `NSPopover` with compact prayer times view. Right-click → redesigned menu: identity header / Open Main Window / Settings (⌘,) / Quit (⌘Q).

---

### Task 5.1: Create MenuBarPopoverView

**Files:**
- Create: `iqamah/Views/MenuBarPopoverView.swift`

- [ ] **Step 1: Create the file**
```bash
touch iqamah/Views/MenuBarPopoverView.swift
```

Add to Xcode project via `project.pbxproj` (add a Sources entry) or open Xcode and add the file to the target manually.

- [ ] **Step 2: Implement the popover view**

```swift
import SwiftUI
import Combine

struct MenuBarPopoverView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var player   = AdhaaanPlayer.shared
    @StateObject private var timerState  = PopoverTimerState()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            popoverHeader
            dateBar
            columnHeaders
            prayerList
            popoverFooter
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear  { timerState.start() }
        .onDisappear { timerState.stop() }
    }

    // MARK: - Header

    private var popoverHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("📍 \(displayCity) · \(settings.calculationMethod.shortName)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(timerState.countdownString)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appGold)
                    .monospacedDigit()

                if let next = timerState.nextPrayer {
                    Text("until \(next.name) at \(next.timeString(use24Hour: settings.use24HourTime))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 4) {
                Button(action: { AdhaaanPlayer.shared.toggleMute() }) {
                    Image(systemName: player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(player.isMuted ? .secondary : Color.appGold)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(player.isMuted
                                    ? Color.secondary.opacity(0.08)
                                    : Color.appGold.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .help(player.isMuted ? "Unmute all adhaan" : "Mute all adhaan")
                .accessibilityLabel(player.isMuted ? "Unmute all adhaan sounds" : "Mute all adhaan sounds")

                Text("All sounds")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Date bar

    private var dateBar: some View {
        Text(dateBarString)
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.03))
            .overlay(alignment: .bottom) {
                Divider().opacity(0.5)
            }
    }

    // MARK: - Column headers

    private var columnHeaders: some View {
        HStack {
            Spacer().frame(width: 28 + 8 + 8) // icon + gaps
            Text("Prayer")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Time")
                .frame(width: 72, alignment: .trailing)
            Spacer().frame(width: 10)
            Text("Sound")
                .frame(width: 28, alignment: .center)
        }
        .font(.system(size: 9, weight: .bold))
        .textCase(.uppercase)
        .tracking(0.6)
        .foregroundStyle(.quaternary)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) { Divider().opacity(0.4) }
    }

    // MARK: - Prayer list

    private var prayerList: some View {
        VStack(spacing: 0) {
            ForEach(timerState.prayers) { row in
                PopoverPrayerRow(
                    row: row,
                    isNext: row.name == timerState.nextPrayer?.name,
                    use24Hour: settings.use24HourTime,
                    isMasterMuted: player.isMuted
                )
                if row.name == "Fajr" {
                    // Sunrise de-emphasised row
                    PopoverSunriseRow(
                        time: timerState.sunriseTime,
                        use24Hour: settings.use24HourTime
                    )
                }
            }
        }
    }

    // MARK: - Footer

    private var popoverFooter: some View {
        HStack {
            Spacer()
            Button("Open main window →") {
                NSApp.sendAction(#selector(AppDelegate.showWindow), to: nil, from: nil)
                // Dismiss popover by removing it from AppDelegate
                NSApp.sendAction(#selector(AppDelegate.closePopover), to: nil, from: nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Divider().opacity(0.4) }
    }

    // MARK: - Helpers

    private var displayCity: String {
        settings.locationSource == "gps" && !settings.gpsLocality.isEmpty
            ? settings.gpsLocality
            : settings.savedCity()?.name ?? "—"
    }

    private var dateBarString: String {
        let greg = Date().formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        let hijri = Date().formatted(.dateTime.calendar(.islamicUmmAlQura).day().month(.wide).year())
        return "\(greg) · \(hijri)"
    }
}

// MARK: - PopoverPrayerRow

struct PopoverPrayerRow: View {
    let row: PopoverPrayerData
    let isNext: Bool
    let use24Hour: Bool
    let isMasterMuted: Bool

    @State private var isPrayerMuted = false

    var body: some View {
        HStack(spacing: 0) {
            // Icon
            ZStack {
                Circle()
                    .fill(isNext ? Color.appGold.opacity(0.15) : Color.secondary.opacity(0.06))
                    .frame(width: 28, height: 28)
                Image(systemName: row.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isNext ? Color.appGold : .secondary)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)

            // Name
            Text(row.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isNext ? Color.appGold : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Time — right-aligned fixed width
            Text(row.timeString(use24Hour: use24Hour))
                .font(.system(size: 14, weight: isNext ? .semibold : .medium))
                .foregroundStyle(isNext ? Color.appGold : .secondary)
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)

            // Column divider
            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(width: 1, height: 20)
                .padding(.horizontal, 10)

            // Per-prayer mute
            Button(action: { isPrayerMuted.toggle() }) {
                Image(systemName: isPrayerMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(isPrayerMuted ? .orange : (isMasterMuted ? .quaternary : .secondary))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isPrayerMuted ? Color.orange.opacity(0.10) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help(isPrayerMuted ? "Unmute \(row.name) adhaan" : "Mute \(row.name) adhaan")
            .accessibilityLabel(isPrayerMuted ? "Unmute \(row.name) adhaan" : "Mute \(row.name) adhaan")
            .padding(.trailing, 12)
        }
        .frame(height: 40)
        .background(isNext ? Color.appGold.opacity(0.06) : Color.clear)
        .overlay(alignment: .bottom) { Divider().opacity(0.3) }
        .onAppear {
            isPrayerMuted = UserDefaults.standard.bool(forKey: "mute_\(row.name)")
        }
        .onChange(of: isPrayerMuted) { _, val in
            UserDefaults.standard.set(val, forKey: "mute_\(row.name)")
        }
    }
}

// MARK: - PopoverSunriseRow

struct PopoverSunriseRow: View {
    let time: Date?
    let use24Hour: Bool

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 16 + 28 + 8)
            Text("Sunrise")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if let t = time {
                    Text(t.formatted(use24Hour
                        ? .dateTime.hour(.twoDigits(amPM: .omitted)).minute()
                        : .dateTime.hour().minute()))
                } else {
                    Text("—")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.quaternary)
            .monospacedDigit()
            .frame(width: 72 + 1 + 20 + 28 + 12, alignment: .trailing)
            .padding(.trailing, 12)
        }
        .frame(height: 28)
        .overlay(alignment: .bottom) { Divider().opacity(0.2) }
    }
}

// MARK: - Supporting types

struct PopoverPrayerData: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let time: Date

    func timeString(use24Hour: Bool) -> String {
        let f = DateFormatter()
        f.dateFormat = use24Hour ? "HH:mm" : "h:mm a"
        return f.string(from: time)
    }
}

// MARK: - Timer state

@MainActor
final class PopoverTimerState: ObservableObject {
    @Published var countdownString = "—"
    @Published var nextPrayer: PopoverPrayerData?
    @Published var prayers: [PopoverPrayerData] = []
    @Published var sunriseTime: Date?

    private var cancellable: Cancellable?

    private let prayerIcons = [
        "Fajr": "moon.stars.fill",
        "Dhuhr": "sun.max.fill",
        "Asr": "cloud.sun.fill",
        "Maghrib": "sunset.fill",
        "Isha": "moon.fill"
    ]

    func start() {
        recalculate()
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.recalculate() }
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }

    private func recalculate() {
        guard let city = SettingsManager.shared.savedCity() else { return }
        let settings = SettingsManager.shared
        guard let tz = TimeZone(identifier: city.timezone) else { return }
        let coord = CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude)
        guard let times = try? PrayerCalculator.calculate(
            for: Date(), coordinate: coord,
            timezone: tz,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        ) else { return }

        let prayerList: [(String, Date)] = [
            ("Fajr", times.fajr), ("Dhuhr", times.dhuhr),
            ("Asr", times.asr), ("Maghrib", times.maghrib), ("Isha", times.isha)
        ]
        sunriseTime = times.sunrise
        prayers = prayerList.map { name, time in
            PopoverPrayerData(name: name, icon: prayerIcons[name] ?? "clock.fill", time: time)
        }

        let now = Date()
        let adjusted = prayerList.map { name, time -> (String, Date) in
            let adj = settings.getAdjustment(for: name)
            return (name, time.addingTimeInterval(Double(adj) * 60))
        }
        nextPrayer = adjusted
            .first(where: { $0.1 > now })
            .flatMap { name, t in prayers.first(where: { $0.name == name }) }

        if let next = adjusted.first(where: { $0.1 > now })?.1 {
            let diff = next.timeIntervalSince(now)
            let h = Int(diff) / 3600
            let m = (Int(diff) % 3600) / 60
            let s = Int(diff) % 60
            countdownString = h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%d:%02d", m, s)
        } else {
            countdownString = "—"
        }
    }
}
```

- [ ] **Step 3: Build**
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 4: Commit**
```bash
git add iqamah/Views/MenuBarPopoverView.swift
git commit -m "feat(US-0015): add MenuBarPopoverView with countdown, prayer list, per-prayer mutes"
```

---

### Task 5.2: Wire popover and redesign right-click menu in AppDelegate

**Files:**
- Modify: `iqamah/AppDelegate.swift`

- [ ] **Step 1: Add NSPopover property and setup**

In `AppDelegate`, add:
```swift
private var popover: NSPopover?

private func makePopover() -> NSPopover {
    let pop = NSPopover()
    pop.contentSize    = NSSize(width: 320, height: 440)
    pop.behavior       = .transient
    pop.animates       = true
    pop.contentViewController = NSHostingController(
        rootView: MenuBarPopoverView()
    )
    return pop
}
```

- [ ] **Step 2: Add closePopover selector**
```swift
@objc func closePopover() {
    popover?.close()
}
```

- [ ] **Step 3: Replace left-click handler**

In `statusBarButtonClicked`, the current `else` branch calls `toggleWindow()`. Replace with:
```swift
@objc func statusBarButtonClicked(_: NSStatusBarButton) {
    guard let event = NSApp.currentEvent else { return }
    if event.type == .rightMouseUp {
        showMenu()
    } else {
        showPopover()
    }
}

private func showPopover() {
    guard let button = statusItem?.button else { return }
    if popover == nil { popover = makePopover() }
    if let pop = popover {
        if pop.isShown {
            pop.close()
        } else {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
```

- [ ] **Step 4: Redesign showMenu()**

Replace the existing `showMenu()` body:
```swift
private func showMenu() {
    let menu = NSMenu()

    // Non-interactive identity header
    let headerItem = NSMenuItem()
    let headerView = NSHostingView(rootView:
        HStack(spacing: 8) {
            Text("🕌").font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text("Iqamah").font(.system(size: 13, weight: .semibold))
                let city = SettingsManager.shared.locationSource == "gps"
                    ? SettingsManager.shared.gpsLocality
                    : SettingsManager.shared.savedCity()?.name ?? ""
                Text("📍 \(city) · \(SettingsManager.shared.calculationMethod.shortName)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(width: 220)
    )
    headerView.frame = NSRect(x: 0, y: 0, width: 220, height: 44)
    headerItem.view = headerView
    menu.addItem(headerItem)

    menu.addItem(NSMenuItem.separator())

    let windowItem = NSMenuItem(title: "Open Main Window", action: #selector(showWindow), keyEquivalent: "")
    windowItem.target = self
    windowItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
    menu.addItem(windowItem)

    let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
    settingsItem.keyEquivalentModifierMask = .command
    settingsItem.target = self
    settingsItem.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
    menu.addItem(settingsItem)

    menu.addItem(NSMenuItem.separator())

    let quitItem = NSMenuItem(title: "Quit Iqamah", action: #selector(quitApp), keyEquivalent: "q")
    quitItem.keyEquivalentModifierMask = .command
    quitItem.target = self
    quitItem.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
    menu.addItem(quitItem)

    statusItem?.menu = menu
    statusItem?.button?.performClick(nil)
    statusItem?.menu = nil
}

@objc func openSettingsFromMenu() {
    showWindow()
    // Post notification that ContentView / PrayerTimesView can observe to open the settings sheet
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}
```

Add to `Notification.Name` extension (in `SettingsManager.swift` or a new file):
```swift
extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
```

In `PrayerTimesView`, observe this notification to toggle `showSettings = true`:
```swift
.onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
    showSettings = true
}
```

- [ ] **Step 5: Build**
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Verify end-to-end**
Run app. Left-click status bar → popover appears with countdown, prayer list, mute controls. Click outside → dismisses. Right-click → menu shows identity header, Open Main Window, Settings (⌘,), Quit (⌘Q). Settings item opens main window then triggers settings sheet.

- [ ] **Step 7: Commit and push**
```bash
git add iqamah/AppDelegate.swift
git commit -m "feat(US-0015): left-click NSPopover, right-click menu redesign with identity header"
git push -u origin feat/US-0015-popover
# Open PR to develop, merge after CI green
```

---

## Branch 6 — BUG-0009: Accessibility Label Pass
**Branch:** `fix/BUG-0009-accessibility`

**Files:**
- Modify: `iqamah/Views/QiblahView.swift`
- Modify: `iqamah/Views/MenuBarPopoverView.swift`

**What exists today:** ±buttons, master mute, and adhaan pill already have accessibility labels (confirmed in code review). Missing: Qiblah compass bearing label, prayer mat image label.

---

### Task 6.1: Add accessibility labels to QiblahView

**Files:**
- Modify: `iqamah/Views/QiblahView.swift`

- [ ] **Step 1: Read current QiblahView**
```bash
cat -n iqamah/Views/QiblahView.swift
```

- [ ] **Step 2: Add compass bearing accessibility label**

Find the `ZStack` that renders the compass ring + bearing line. Add on the outermost ZStack or the compass container:
```swift
.accessibilityElement(children: .ignore)
.accessibilityLabel("Qiblah direction: \(Int(qiblahBearing)) degrees \(cardinalDirection(for: qiblahBearing))")
.accessibilityValue("Face \(cardinalDirection(for: qiblahBearing)) to face Mecca")
```

Add the helper (if not already present):
```swift
private func cardinalDirection(for bearing: Double) -> String {
    let directions = ["N","NE","E","SE","S","SW","W","NW"]
    let index = Int((bearing + 22.5) / 45) % 8
    return directions[index]
}
```

- [ ] **Step 3: Add prayer mat accessibility label**

Find `Image("PrayerMat")` in QiblahView:
```swift
Image("PrayerMat")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 40, height: 60)
    .accessibilityLabel("Prayer mat facing Qiblah direction")
    .accessibilityHidden(false)
```

- [ ] **Step 4: Build**
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 5: Commit**
```bash
git add iqamah/Views/QiblahView.swift
git commit -m "fix(BUG-0009): add Qiblah compass and prayer mat accessibility labels"
```

---

### Task 6.2: Verify master mute accessibility in popover

**Files:**
- Modify: `iqamah/Views/MenuBarPopoverView.swift` (if needed)

- [ ] **Step 1: Confirm master mute has label**

The master mute button in `MenuBarPopoverView` already has `.accessibilityLabel` in the implementation above. Verify it reads correctly with VoiceOver by enabling VoiceOver (Cmd+F5) and tabbing to the popover's mute button. Expected: "Mute all adhaan sounds" or "Unmute all adhaan sounds".

- [ ] **Step 2: Add accessibilityLabel to countdown text**

In `popoverHeader`, add on the countdown `Text`:
```swift
Text(timerState.countdownString)
    ...
    .accessibilityLabel(
        timerState.nextPrayer.map { "Time until \($0.name): \(timerState.countdownString)" }
        ?? "No upcoming prayer"
    )
```

- [ ] **Step 3: Build, commit, and push**
```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
git add iqamah/Views/QiblahView.swift iqamah/Views/MenuBarPopoverView.swift
git commit -m "fix(BUG-0009): accessibility label on popover countdown; VoiceOver sweep complete"
git push -u origin fix/BUG-0009-accessibility
# Open PR to develop, merge after CI green
```

---

## Self-Review Checklist

### Spec coverage
| Spec section | Covered by |
|---|---|
| ENH-001 Option A (TimeZone.current + raw coords) | Task 1.2 |
| ENH-001 Option B (CLGeocoder locality + timezone) | Task 1.2 |
| ENH-001 5 km re-trigger threshold | Task 1.2 |
| ENH-001 display name from CLGeocoder locality | Task 1.2 + Task 1.1 gpsLocality |
| BUG-0039 always-visible pill | Task 2.1 adhaanColumnButton |
| BUG-0039 pill states (set/muted/silent) | Task 2.1 |
| BUG-0039 time + ± grouped right | Task 2.1 mainRowContent |
| BUG-0039 fixed adhaan column (100pt) + mute column (36pt) | Task 2.1 |
| BUG-0050 audioFailed @Published | Task 3.1 |
| BUG-0050 banner warning row | Task 3.2 |
| BUG-0050 reset on stop/finish | Task 3.1 |
| BUG-0046 preferredColorScheme at root | Task 4.1 |
| BUG-0046 section icons | Task 4.2 |
| BUG-0046 Adjustments in Form | Task 4.2 |
| BUG-0046 adaptive height (.frame minHeight: 480) | Task 4.2 |
| US-0015 NSPopover left-click | Task 5.2 |
| US-0015 countdown timer (1s) start/stop on appear/disappear | Task 5.1 PopoverTimerState |
| US-0015 master mute button | Task 5.1 popoverHeader |
| US-0015 per-prayer mute column | Task 5.1 PopoverPrayerRow |
| US-0015 time right-aligned fixed width | Task 5.1 |
| US-0015 Sunrise de-emphasised, no mute | Task 5.1 PopoverSunriseRow |
| US-0015 Open main window footer | Task 5.1 popoverFooter |
| US-0015 right-click menu: identity header | Task 5.2 |
| US-0015 right-click menu: Settings ⌘, | Task 5.2 |
| US-0015 right-click menu: Quit ⌘Q | Task 5.2 |
| BUG-0009 Qiblah compass bearing label | Task 6.1 |
| BUG-0009 prayer mat label | Task 6.1 |
| BUG-0009 popover countdown label | Task 6.2 |
| Default mute state (absent = unmuted) | Task 5.1 PopoverPrayerRow.onAppear |
| Branching (one branch per item) | Each branch section |
