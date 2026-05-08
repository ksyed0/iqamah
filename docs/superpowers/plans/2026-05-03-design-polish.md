# Design Polish — Glassmorphic Redesign + Bug Fixes

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a two-tier glassmorphic visual layer (SwiftUI materials on macOS 14–25, Liquid Glass on macOS 26+), add a three-way appearance switcher, make the adhaan picker permanently visible via a dedicated column, and close ten design-quality bugs.

**Architecture:** A new `Color+App.swift` extension centralises the brand tokens. A new `IqamahBackground` view provides the ambient gradient that gives glass surfaces something to blur against. Every glass surface in the app uses a single `#available(macOS 26, *)` conditional — `.glassEffect()` above, `.ultraThinMaterial` below. `SettingsManager` gains an `AppAppearance` property wired to `.preferredColorScheme` at the `ContentView` level. `PrayerTimeRow` gains a persistent adhaan column replacing the hover-gated picker.

**Tech Stack:** SwiftUI, AppKit (macOS 14+), Liquid Glass `.glassEffect()` (macOS 26+), `GlassEffectContainer` (macOS 26+), `UserDefaults` via `SettingsManager`

> **No test targets exist in this project.** Verification steps use `xcodebuild` build checks and manual runtime inspection. Each task ends with a clean build as the passing criterion.

---

## File Map

| File | Status | Responsibility |
|------|--------|---------------|
| `iqamah/Extensions/Color+App.swift` | **Create** | Brand color tokens: `appGold`, `appGoldDim`, `appGoldDark` |
| `iqamah/Views/IqamahBackground.swift` | **Create** | Ambient gradient view — dark night-sky / light dawn, adapts to `colorScheme` |
| `iqamah/Services/SettingsManager.swift` | Modify | Add `AppAppearance` enum + `@Published var appearance` |
| `iqamah/ContentView.swift` | Modify | Wire `IqamahBackground` as root background; add `.preferredColorScheme` |
| `iqamah/Views/PrayerTimesView.swift` | Modify | Adhaan column, ForEach identity fix, icon clip removal, glass surfaces |
| `iqamah/Views/SplashScreenView.swift` | Modify | Remove stale PIL comment |
| `iqamah/Views/LocationSetupView.swift` | Modify | Gold tint on Continue button |
| `iqamah/Views/CalculationMethodView.swift` | Modify | Remove Display Size block; gold tint on Continue |
| `iqamah/Views/SettingsSheetView.swift` | Modify | Form/.formStyle(.grouped) refactor; appearance picker; height fix |
| `iqamah/Views/AboutView.swift` | Modify | Close button prominence fix; use `Color.appGold` |
| `iqamah/Views/QiblahView.swift` | Modify | Use `Color.appGold`; glass background on sheets |
| `iqamah/Views/AdhaanBannerView.swift` | Modify | Use `Color.appGold`; upgrade to `.glassEffect()` on macOS 26+ |

---

## Task 1: Brand Color Tokens (BUG-0038)

**Files:**
- Create: `iqamah/Extensions/Color+App.swift`

This task is the prerequisite for every other task. Do this first.

- [ ] **Step 1: Create the Extensions directory and Color+App.swift**

```swift
// iqamah/Extensions/Color+App.swift
import SwiftUI

extension Color {
    /// Primary gold brand accent — use on dark surfaces (dark mode, glass dark rows).
    static let appGold = Color(red: 0.88, green: 0.69, blue: 0.06)

    /// Lighter gold variant used in the wordmark gradient top stop.
    static let appGoldDim = Color(red: 0.95, green: 0.76, blue: 0.06)

    /// Darker amber for gold text on light surfaces (light mode glass).
    /// #8a5e00 — meets 4.5:1 contrast on white/cream backgrounds.
    static let appGoldDark = Color(red: 0.54, green: 0.37, blue: 0.0)
}
```

- [ ] **Step 2: Add Color+App.swift to the Xcode target**

In Xcode: File → Add Files to "iqamah" → select `iqamah/Extensions/Color+App.swift`. Ensure the "iqamah" target checkbox is ticked.

Alternatively, add to `project.pbxproj` by opening the project in Xcode and dragging the file into the navigator under the `iqamah` group.

- [ ] **Step 3: Replace all local gold definitions across every view**

In each file below, delete the `private let gold = Color(...)` line (or inline literal) and replace every reference to `gold` with `Color.appGold`. Use the gradient top stop `Color.appGoldDim` where the current code uses `Color(red: 0.95, green: 0.76, blue: 0.06)`.

Files to update:
- `iqamah/Views/PrayerTimesView.swift` — header gradient uses both `appGold` and `appGoldDim`; `PrayerTimeRow` local `gold` constant
- `iqamah/Views/AdhaanBannerView.swift` — `private let gold`
- `iqamah/Views/AboutView.swift` — `private let gold`
- `iqamah/Views/QiblahView.swift` — inline `Color(red: 0.88, ...)` literals  
- `iqamah/Views/AdhaanBannerView.swift` — `SunArcView` and `WaveBar` nested structs each have their own `private let gold`

After editing, search the entire `iqamah/` directory for `Color(red: 0.88, green: 0.69` and `Color(red: 0.95, green: 0.76` — both should return zero results.

- [ ] **Step 4: Build and verify**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED` with zero errors.

- [ ] **Step 5: Commit**

```bash
git add iqamah/Extensions/Color+App.swift iqamah/Views/PrayerTimesView.swift \
  iqamah/Views/AdhaanBannerView.swift iqamah/Views/AboutView.swift \
  iqamah/Views/QiblahView.swift
git commit -m "refactor: centralise brand gold into Color+App.swift (BUG-0038)"
```

---

## Task 2: Trivial One-Line Bug Fixes (BUG-0041, 0043, 0047, 0040)

**Files:**
- Modify: `iqamah/Views/SplashScreenView.swift`
- Modify: `iqamah/Views/PrayerTimesView.swift`
- Modify: `iqamah/Views/AboutView.swift`
- Modify: `iqamah/Views/SettingsSheetView.swift`

- [ ] **Step 1: Remove stale PIL comment (BUG-0041)**

In `iqamah/Views/SplashScreenView.swift`, find and delete the line:
```swift
// (CoreText handles Arabic shaping correctly; PIL cannot)
```
PIL is a Python library. This comment predates the Swift implementation and is meaningless here.

- [ ] **Step 2: Remove double-rounded app icon clip (BUG-0043)**

In `iqamah/Views/PrayerTimesView.swift`, find the app icon `Image` in the primary header (around line 28–32) and remove the `.clipShape(...)` modifier:

Before:
```swift
Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
    .resizable()
    .frame(width: 32, height: 32)
    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    .shadow(color: Color.primary.opacity(0.10), radius: 3, x: 0, y: 1)
```

After:
```swift
Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
    .resizable()
    .frame(width: 32, height: 32)
    .shadow(color: Color.primary.opacity(0.10), radius: 3, x: 0, y: 1)
```

- [ ] **Step 3: Fix About Close button prominence (BUG-0047)**

In `iqamah/Views/AboutView.swift`, find the Close button (around line 149) and change its style:

Before:
```swift
Button("Close") { dismiss() }
    .buttonStyle(.borderedProminent)
    .tint(gold)
    .controlSize(.regular)
    .keyboardShortcut(.escape, modifiers: [])
    .padding(.bottom, 24)
```

After:
```swift
Button("Close") { dismiss() }
    .buttonStyle(.bordered)
    .controlSize(.regular)
    .keyboardShortcut(.escape, modifiers: [])
    .padding(.bottom, 24)
```

- [ ] **Step 4: Fix Settings sheet fixed height (BUG-0040)**

In `iqamah/Views/SettingsSheetView.swift`, find the `.frame(width: 480, height: 660)` modifier on the outermost `VStack` body and change it:

Before:
```swift
.frame(width: 480, height: 660)
```

After:
```swift
.frame(width: 480, minHeight: 540, maxHeight: 700)
```

- [ ] **Step 5: Build and verify**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add iqamah/Views/SplashScreenView.swift iqamah/Views/PrayerTimesView.swift \
  iqamah/Views/AboutView.swift iqamah/Views/SettingsSheetView.swift
git commit -m "fix: PIL comment, double-clip icon, About button prominence, Settings height (BUG-0040/41/43/47)"
```

---

## Task 3: Onboarding Cleanup (BUG-0044, 0045)

**Files:**
- Modify: `iqamah/Views/LocationSetupView.swift`
- Modify: `iqamah/Views/CalculationMethodView.swift`

- [ ] **Step 1: Gold tint on LocationSetupView Continue button (BUG-0044)**

In `iqamah/Views/LocationSetupView.swift`, find the Continue button (around line 126–134):

Before:
```swift
Button(action: {
    if let city = selectedCity { onLocationConfirmed(city) }
}) {
    Text("Continue")
        .frame(minWidth: 100)
}
.buttonStyle(.borderedProminent)
.controlSize(.large)
.disabled(selectedCity == nil)
```

After:
```swift
Button(action: {
    if let city = selectedCity { onLocationConfirmed(city) }
}) {
    Text("Continue")
        .frame(minWidth: 100)
}
.buttonStyle(.borderedProminent)
.tint(.appGold)
.controlSize(.large)
.disabled(selectedCity == nil)
```

- [ ] **Step 2: Remove Display Size block and add gold tint in CalculationMethodView (BUG-0044, 0045)**

In `iqamah/Views/CalculationMethodView.swift`, delete the entire "Display Size" `HStack` block — approximately lines 68–115. It begins with:
```swift
// ── Display size (quick pick before first use) ──────────
HStack(spacing: 10) {
```
and ends before the `Spacer()` that precedes the navigation buttons.

Then add `.tint(.appGold)` to the Continue button:

Before:
```swift
Button(action: onConfirm) {
    Text("Continue")
        .frame(minWidth: 100)
}
.buttonStyle(.borderedProminent)
.controlSize(.large)
```

After:
```swift
Button(action: onConfirm) {
    Text("Continue")
        .frame(minWidth: 100)
}
.buttonStyle(.borderedProminent)
.tint(.appGold)
.controlSize(.large)
```

- [ ] **Step 3: Build and verify**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add iqamah/Views/LocationSetupView.swift iqamah/Views/CalculationMethodView.swift
git commit -m "fix: gold tint on onboarding Continue, remove Display Size from onboarding (BUG-0044/45)"
```

---

## Task 4: AppAppearance in SettingsManager

**Files:**
- Modify: `iqamah/Services/SettingsManager.swift`

- [ ] **Step 1: Add AppAppearance enum and Keys entry**

At the top of `iqamah/Services/SettingsManager.swift`, just before the `class SettingsManager` declaration, add:

```swift
enum AppAppearance: String, CaseIterable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}
```

Add `import SwiftUI` at the top of the file (it currently only imports `Foundation`).

- [ ] **Step 2: Add the Keys entry**

Inside the `private enum Keys` block, add:
```swift
static let appearance = "appAppearance"
```

- [ ] **Step 3: Add the @Published property**

After the `uiScale` property block, add:

```swift
@Published var appearance: AppAppearance {
    didSet {
        defaults.set(appearance.rawValue, forKey: Keys.appearance)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
}
```

- [ ] **Step 4: Load from UserDefaults in init**

After the `uiScale` initialization line in `init`, add:

```swift
if let raw = userDefaults.string(forKey: Keys.appearance),
   let saved = AppAppearance(rawValue: raw) {
    appearance = saved
} else {
    appearance = .system
}
```

- [ ] **Step 5: Build and verify**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add iqamah/Services/SettingsManager.swift
git commit -m "feat: add AppAppearance enum and @Published appearance to SettingsManager"
```

---

## Task 5: IqamahBackground + ContentView Wiring

**Files:**
- Create: `iqamah/Views/IqamahBackground.swift`
- Modify: `iqamah/ContentView.swift`

- [ ] **Step 1: Create IqamahBackground.swift**

```swift
// iqamah/Views/IqamahBackground.swift
import SwiftUI

/// Full-bleed ambient gradient that sits behind all app content.
/// Provides the rich color field that glass surfaces blur against.
/// Dark: night-sky — amber/fire top-left, deep indigo bottom-right, dusk purple midpoint.
/// Light: dawn — golden warmth top-left, cool afternoon blue bottom-right.
struct IqamahBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(colorScheme == .dark ? darkGradient : lightGradient)
            .ignoresSafeArea()
    }

    private var darkGradient: some ShapeStyle {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.098, green: 0.031, blue: 0.012), location: 0.0),
                .init(color: Color(red: 0.047, green: 0.047, blue: 0.102), location: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var lightGradient: some ShapeStyle {
        LinearGradient(
            stops: [
                .init(color: Color(red: 1.0, green: 0.973, blue: 0.925), location: 0.0),
                .init(color: Color(red: 0.910, green: 0.941, blue: 1.0), location: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
```

- [ ] **Step 2: Add IqamahBackground.swift to the Xcode target**

In Xcode, drag `IqamahBackground.swift` into the `Views` group in the navigator and confirm the iqamah target is checked.

- [ ] **Step 3: Wire background and preferredColorScheme in ContentView**

In `iqamah/ContentView.swift`, the `body` currently returns a `Group { ... }` with `.frame`, `.scaleEffect`, and `.padding` modifiers. Add two modifiers after the final `.padding(10)`:

```swift
.background(IqamahBackground())
.preferredColorScheme(settings.appearance.colorScheme)
```

Also remove any `.background(Color(nsColor: .windowBackgroundColor))` modifier on `PrayerTimesView` — search `PrayerTimesView.swift` for this string and delete the modifier. The `IqamahBackground` in `ContentView` replaces it.

- [ ] **Step 4: Build and verify**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`. Launch the app — the window should show a dark gradient background instead of the plain system background.

- [ ] **Step 5: Commit**

```bash
git add iqamah/Views/IqamahBackground.swift iqamah/ContentView.swift iqamah/Views/PrayerTimesView.swift
git commit -m "feat: add IqamahBackground ambient gradient + wire preferredColorScheme"
```

---

## Task 6: Settings Form Refactor + Appearance Picker (BUG-0046)

**Files:**
- Modify: `iqamah/Views/SettingsSheetView.swift`

The existing `SettingsSheetView` uses custom `SectionHeader`/`SettingsRow` sub-views, manual `Divider()` calls, and `padding(.horizontal, 28)` everywhere. Replace the scroll content entirely with `Form { }.formStyle(.grouped)`. Keep the header `HStack` ("Settings" title) and the Cancel/Save footer `HStack` unchanged.

- [ ] **Step 1: Replace the ScrollView content with a Form**

Find the `ScrollView { VStack(alignment: .leading, spacing: 24) { ... } }` block inside `SettingsSheetView.body` and replace it with:

```swift
Form {
    // ── Location ─────────────────────────────────────
    Section("Location") {
        if let db = database {
            Picker("Country", selection: $selectedCountry) {
                Text("Select a country").tag(nil as Country?)
                ForEach(db.countries.sorted { $0.name < $1.name }) { c in
                    Text(c.name).tag(c as Country?)
                }
            }

            if selectedCountry != nil {
                Picker("City", selection: $selectedCity) {
                    Text("Select a city").tag(nil as City?)
                    ForEach(cities) { city in
                        Text(city.name).tag(city as City?)
                    }
                }
            }
        } else {
            ProgressView("Loading cities…")
        }
    }

    // ── Calculation ───────────────────────────────────
    Section("Calculation") {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Method", selection: $selectedMethod) {
                ForEach(CalculationMethod.allCases) { method in
                    Text(method.displayName).tag(method)
                }
            }
            .onChange(of: selectedMethod) { _, _ in userOverrodeMethod = true }
            if let label = recommendationLabel, !userOverrodeMethod {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }

        Picker("Asr Calculation", selection: $selectedAsrMethod) {
            ForEach(AsrJuristicMethod.allCases) { method in
                Text(method.displayName).tag(method)
            }
        }
        .pickerStyle(.radioGroup)
    }

    // ── Display ───────────────────────────────────────
    Section("Display") {
        Toggle(isOn: $use24Hour) {
            VStack(alignment: .leading, spacing: 2) {
                Text("24-Hour Time")
                Text(use24Hour ? "e.g. 13:30" : "e.g. 1:30 PM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)

        Toggle(isOn: $launchAtLogin) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Launch at Login")
                Text("Start Iqamah automatically when you log in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .onChange(of: launchAtLogin) { _, enabled in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = !enabled
            }
        }

        Picker("Appearance", selection: $selectedAppearance) {
            ForEach(AppAppearance.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)

        // Display Size
        HStack {
            Text("Display Size")
            Spacer()
            Button {
                if settings.uiScale > SettingsManager.uiScaleMin {
                    settings.uiScale = (settings.uiScale - SettingsManager.uiScaleStep).rounded(toPlaces: 1)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(settings.uiScale > SettingsManager.uiScaleMin ? Color.accentColor : .secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .disabled(settings.uiScale <= SettingsManager.uiScaleMin)

            Text("\(Int(settings.uiScale * 100))%")
                .font(.body.monospacedDigit())
                .frame(minWidth: 42, alignment: .center)

            Button {
                if settings.uiScale < SettingsManager.uiScaleMax {
                    settings.uiScale = (settings.uiScale + SettingsManager.uiScaleStep).rounded(toPlaces: 1)
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(settings.uiScale < SettingsManager.uiScaleMax ? Color.accentColor : .secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .disabled(settings.uiScale >= SettingsManager.uiScaleMax)

            if settings.uiScale != 1.0 {
                Button("Reset") { settings.uiScale = 1.0 }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
.formStyle(.grouped)
```

- [ ] **Step 2: Add draft state for selectedAppearance**

Add to the `// MARK: - Draft state` block:
```swift
@State private var selectedAppearance: AppAppearance
```

Initialize it in `init`:
```swift
_selectedAppearance = State(initialValue: SettingsManager.shared.appearance)
```

Add to the `save()` method alongside the other saves:
```swift
SettingsManager.shared.appearance = selectedAppearance
```

- [ ] **Step 3: Remove SectionHeader and SettingsRow**

Delete the `private struct SectionHeader` and `private struct SettingsRow` definitions at the bottom of `SettingsSheetView.swift` — they are no longer used.

- [ ] **Step 4: Build and verify**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`. Launch the app, open Settings — the sheet should show native grouped form sections with Location, Calculation, and Display. Test the Appearance segmented picker; the window should switch color schemes on Save.

- [ ] **Step 5: Commit**

```bash
git add iqamah/Views/SettingsSheetView.swift iqamah/Services/SettingsManager.swift
git commit -m "feat: Settings Form refactor + appearance switcher (BUG-0046, appearance feature)"
```

---

## Task 7: Adhaan Column in PrayerTimeRow (BUG-0039, 0042)

**Files:**
- Modify: `iqamah/Views/PrayerTimesView.swift`

This is the largest single-view change. The hover-gated adhaan picker sub-row is replaced by a persistent adhaan column in the row grid. Clicking the column expands an inline chip picker below that row.

- [ ] **Step 1: Fix ForEach identity (BUG-0042)**

In `PrayerTimesTable.body`, find:
```swift
ForEach(Array(prayerTimes.prayers.enumerated()), id: \.offset) { _, prayer in
```
Replace with:
```swift
ForEach(prayerTimes.prayers, id: \.name) { prayer in
```

- [ ] **Step 2: Add expandedPrayerName state to PrayerTimesTable**

In `PrayerTimesTable`, add a state variable to track which prayer's chip picker is currently open:

```swift
@State private var expandedPrayerName: String? = nil
```

- [ ] **Step 3: Thread expandedPrayerName into PrayerTimeRow**

Update the `PrayerTimeRow` call inside the `ForEach` to pass a binding:

```swift
PrayerTimeRow(
    name: prayer.name,
    time: adjusted,
    formatter: timeFormatter,
    adjustment: adjustments[prayer.name] ?? 0,
    selectedAdhaan: Binding(
        get: { adhaanSelections[prayer.name] ?? .silent },
        set: { newAdhaan in
            adhaanSelections[prayer.name] = newAdhaan
            settingsManager.setAdhaan(newAdhaan, for: prayer.name)
        }
    ),
    isPrayerMuted: Binding(
        get: { prayerMuted[prayer.name] ?? false },
        set: { muted in
            prayerMuted[prayer.name] = muted
            settingsManager.setPrayerMuted(muted, for: prayer.name)
        }
    ),
    isHighlighted: isNextPrayer(adjustedTime: adjusted),
    isPickerExpanded: expandedPrayerName == prayer.name,
    onTogglePicker: {
        withAnimation(.easeInOut(duration: 0.18)) {
            expandedPrayerName = expandedPrayerName == prayer.name ? nil : prayer.name
        }
    },
    onAdjust: { delta in adjustPrayerTime(for: prayer.name, delta: delta) }
)
```

- [ ] **Step 4: Rewrite PrayerTimeRow signature and body**

Replace the full `struct PrayerTimeRow: View` with the following. Key changes:
- Remove `@State private var isHovering`
- Add `isPickerExpanded: Bool` and `onTogglePicker: () -> Void` parameters
- Remove `isHovering` guard on the picker expansion
- Replace the hover-gated sub-row with an adhaan column in the main HStack and a conditional chip row below

```swift
struct PrayerTimeRow: View {
    let name: String
    let time: Date
    let formatter: DateFormatter
    let adjustment: Int
    @Binding var selectedAdhaan: Adhaan
    @Binding var isPrayerMuted: Bool
    let isHighlighted: Bool
    let isPickerExpanded: Bool
    let onTogglePicker: () -> Void
    let onAdjust: (Int) -> Void

    @ObservedObject private var player = AdhaaanPlayer.shared
    @Environment(\.colorScheme) private var colorScheme

    private var adhaanOptions: [Adhaan] {
        name == "Fajr" ? Adhaan.availableForFajr : Adhaan.available
    }

    private var effectiveGold: Color {
        colorScheme == .dark ? .appGold : .appGoldDark
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Main row ──────────────────────────────────────────
            HStack(spacing: 0) {
                // Left accent stripe (highlighted only)
                Rectangle()
                    .fill(isHighlighted ? effectiveGold : Color.clear)
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .padding(.vertical, 8)

                HStack(spacing: 16) {
                    // Prayer icon + name
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

                    Spacer()

                    // ── Adhaan column ──────────────────────────────
                    Button(action: onTogglePicker) {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note")
                                .font(.caption2)
                                .foregroundStyle(selectedAdhaan.id == "silent"
                                    ? Color.secondary.opacity(0.4)
                                    : effectiveGold.opacity(0.75))
                            if selectedAdhaan.id == "silent" {
                                Text("—")
                                    .font(.caption.italic())
                                    .foregroundStyle(.secondary.opacity(0.5))
                            } else {
                                Text(selectedAdhaan.shortName)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(effectiveGold.opacity(0.85))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(selectedAdhaan.id == "silent"
                                    ? Color.clear
                                    : effectiveGold.opacity(colorScheme == .dark ? 0.10 : 0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(selectedAdhaan.id == "silent"
                                    ? Color.clear
                                    : effectiveGold.opacity(0.22), lineWidth: 0.5)
                        )
                        .frame(minWidth: 72, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .help(selectedAdhaan.id == "silent" ? "Tap to set adhaan for \(name)" : "Adhaan: \(selectedAdhaan.displayName) — tap to change")
                    .accessibilityLabel(selectedAdhaan.id == "silent" ? "No adhaan set for \(name). Tap to set." : "Adhaan for \(name): \(selectedAdhaan.displayName). Tap to change.")

                    // Time + optional adjustment badge overlay
                    ZStack(alignment: .topTrailing) {
                        Text(formatter.string(from: time))
                            .font(isHighlighted ? .title2.weight(.semibold) : .title3.weight(.medium))
                            .foregroundStyle(isHighlighted ? effectiveGold : .primary)
                            .monospacedDigit()
                            .frame(minWidth: 72, alignment: .trailing)

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

                    // Adjustment controls
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

                        Button(action: { onAdjust(1) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .help("Increase \(name) by 1 minute")
                        .accessibilityLabel("Increase \(name) time by 1 minute")
                    }

                    // Per-prayer mute
                    Button(action: { isPrayerMuted = !isPrayerMuted }) {
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, isHighlighted ? 18 : 14)
            }

            // ── Inline chip picker — visible when this row's picker is expanded ──
            if isPickerExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: (player.isMuted || isPrayerMuted) ? "speaker.slash" : "music.note")
                            .font(.caption)
                            .foregroundStyle((player.isMuted || isPrayerMuted) ? Color.orange.opacity(0.7) : .secondary)

                        Text("Select adhaan for \(name)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        if selectedAdhaan.id != "silent", player.isPlaying {
                            Button(action: { AdhaaanPlayer.shared.stop() }) {
                                Label("Stop", systemImage: "stop.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(adhaanOptions) { option in
                                Button(action: {
                                    selectedAdhaan = option
                                    if option.id != "silent" {
                                        AdhaaanPlayer.shared.preview(option)
                                    }
                                    if option.id == "silent" {
                                        onTogglePicker()
                                    }
                                }) {
                                    Text(option.displayName)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(selectedAdhaan.id == option.id
                                                    ? effectiveGold.opacity(colorScheme == .dark ? 0.18 : 0.15)
                                                    : Color.secondary.opacity(0.08))
                                        )
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(selectedAdhaan.id == option.id
                                                    ? effectiveGold.opacity(0.35)
                                                    : Color.clear, lineWidth: 1)
                                        )
                                        .foregroundStyle(selectedAdhaan.id == option.id
                                            ? effectiveGold
                                            : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                .padding(.leading, 20)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHighlighted ? effectiveGold.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isHighlighted ? effectiveGold.opacity(0.25) : Color.clear, lineWidth: 1)
        )
        .shadow(color: isHighlighted ? effectiveGold.opacity(0.12) : .clear, radius: 6, x: 0, y: 2)
        .contentShape(Rectangle())
        .onKeyPress(.escape) {
            if isPickerExpanded { onTogglePicker() }
            return isPickerExpanded ? .handled : .ignored
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(name) at \(formatter.string(from: time))"
            + (adjustment != 0 ? ", adjusted \(adjustment) min" : "")
            + (isPrayerMuted ? ", muted" : "")
            + (isHighlighted ? ", next prayer" : "")
        )
    }

    private var iconName: String {
        switch name {
        case "Fajr":    "sun.horizon.fill"
        case "Sunrise": "sunrise.fill"
        case "Dhuhr":   "sun.max.fill"
        case "Asr":     "sun.min.fill"
        case "Maghrib": "sunset.fill"
        case "Isha":    "moon.stars.fill"
        default:        "clock.fill"
        }
    }
}
```

- [ ] **Step 5: Add shortName to Adhaan**

`Adhaan.shortName` is referenced in the column chip. Open `iqamah/Models/Adhaan.swift` and add a computed property to the `Adhaan` struct:

```swift
var shortName: String {
    // Trim "Adhaan " prefix for compact display
    if displayName.hasPrefix("Adhaan ") {
        return String(displayName.dropFirst("Adhaan ".count))
    }
    return displayName
}
```

- [ ] **Step 6: Build and verify**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`. Launch the app — each prayer row should show a music note + "—" (or adhaan name if set) in the column. Clicking it should expand the chip row below with a smooth animation.

- [ ] **Step 7: Commit**

```bash
git add iqamah/Views/PrayerTimesView.swift iqamah/Models/Adhaan.swift
git commit -m "feat: adhaan column in prayer table replaces hover picker (BUG-0039/42)"
```

---

## Task 8: Glass Surfaces — Main Window

**Files:**
- Modify: `iqamah/Views/PrayerTimesView.swift`

Apply the two-tier glass pattern to the primary header, secondary toolbar, date bar, and prayer rows. The `IqamahBackground` from Task 5 is already behind everything; now the layers on top become glass.

- [ ] **Step 1: Glass the primary header HStack**

In `PrayerTimesView.body`, the primary header `HStack` currently has no background. Add:

```swift
.background {
    if #available(macOS 26, *) {
        Rectangle().glassEffect()
    } else {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Divider().opacity(0.4)
            }
    }
}
```

- [ ] **Step 2: Glass the secondary toolbar HStack**

The secondary toolbar `HStack` currently has `.background(Color(nsColor: .windowBackgroundColor))`. Replace that modifier with:

```swift
.background {
    if #available(macOS 26, *) {
        Rectangle().glassEffect()
    } else {
        Rectangle().fill(.ultraThinMaterial)
    }
}
```

- [ ] **Step 3: Glass the date bar Text**

The `Text(currentDate.formattedGregorianDate())` currently has no background. Wrap it and add:

```swift
Text(currentDate.formattedGregorianDate())
    .font(.subheadline.bold())
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity)
    .background {
        if #available(macOS 26, *) {
            Rectangle().glassEffect()
        } else {
            Rectangle().fill(.ultraThinMaterial.opacity(0.6))
        }
    }
```

- [ ] **Step 4: Glass normal prayer rows in PrayerTimesTable**

In `PrayerTimesTable.body`, the `VStack(spacing: 1)` container currently has `.background(Color(nsColor: .controlBackgroundColor))`. Replace that with the glass pattern and, on macOS 26+, wrap the VStack in a `GlassEffectContainer`:

```swift
// macOS 14–25: glass rows in a plain VStack
// macOS 26+:   GlassEffectContainer enables row morphing on expand/collapse

Group {
    if #available(macOS 26, *) {
        GlassEffectContainer {
            rowsContent
        }
    } else {
        rowsContent
    }
}
```

Extract the `VStack { ForEach... }` into a `@ViewBuilder var rowsContent: some View` computed property on `PrayerTimesTable`. Then update `PrayerTimeRow`'s background modifier to use the glass pattern:

In `PrayerTimeRow.body`, replace the existing `.background(RoundedRectangle...)` with:

```swift
.background {
    if #available(macOS 26, *) {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .glassEffect(isHighlighted
                ? .regular.tint(effectiveGold.opacity(0.15))
                : .regular)
    } else {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isHighlighted
                ? effectiveGold.opacity(0.10)
                : .ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isHighlighted
                        ? effectiveGold.opacity(0.25)
                        : Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}
```

Remove the existing `.background(RoundedRectangle...)`, `.overlay(RoundedRectangle...)`, and `.shadow(...)` modifiers from `PrayerTimeRow` that implemented the highlighted styling — they are now handled in the single `.background` block above.

Also remove the `.shadow(color: .black.opacity(0.05)...)` from the outer table container — glass doesn't need the extra shadow.

- [ ] **Step 5: Build and verify**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`. On macOS 14–25: frosted material rows over the gradient. On macOS 26+: Liquid Glass rows.

- [ ] **Step 6: Commit**

```bash
git add iqamah/Views/PrayerTimesView.swift
git commit -m "feat: glass surfaces on header, toolbar, date bar, prayer rows (macOS 14-25 material / macOS 26+ Liquid Glass)"
```

---

## Task 9: Glass Surfaces — Sheets and Banner

**Files:**
- Modify: `iqamah/Views/AboutView.swift`
- Modify: `iqamah/Views/QiblahView.swift`
- Modify: `iqamah/Views/SettingsSheetView.swift`
- Modify: `iqamah/Views/AdhaanBannerView.swift`

Sheets presented over the glass main window should inherit the visual language. On macOS 26+ sheets automatically pick up the window's material; on macOS 14–25 we add `.background(.regularMaterial)`.

- [ ] **Step 1: AboutView glass background**

In `iqamah/Views/AboutView.swift`, replace `.background(Color(nsColor: .windowBackgroundColor))` at the bottom of the view with:

```swift
.background {
    if #available(macOS 26, *) {
        Rectangle().glassEffect()
    } else {
        Rectangle().fill(.regularMaterial)
    }
}
```

- [ ] **Step 2: QiblahView glass background**

In `iqamah/Views/QiblahView.swift`, the outermost `VStack` has no explicit background. Add:

```swift
.background {
    if #available(macOS 26, *) {
        Rectangle().glassEffect()
    } else {
        Rectangle().fill(.regularMaterial)
    }
}
```

- [ ] **Step 3: SettingsSheetView glass background**

In `iqamah/Views/SettingsSheetView.swift`, the outer `VStack` body has no explicit background. Add the same pattern as above.

- [ ] **Step 4: AdhaanBannerView upgrade**

`AdhaanBannerView` already uses `.ultraThinMaterial`. Upgrade it conditionally:

Find the `.background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))` modifier and replace with:

```swift
.background {
    if #available(macOS 26, *) {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .glassEffect(.regular.tint(Color.appGold.opacity(0.08)))
    } else {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
    }
}
```

Keep the existing `.overlay(RoundedRectangle(...).strokeBorder(Color.appGold.opacity(0.28), lineWidth: 1))` — the gold border stays on both tiers.

- [ ] **Step 5: Build and verify**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`. Open each sheet (About, Qiblah, Settings) and the adhaan banner — all should show material/glass backgrounds rather than opaque system white.

- [ ] **Step 6: Commit**

```bash
git add iqamah/Views/AboutView.swift iqamah/Views/QiblahView.swift \
  iqamah/Views/SettingsSheetView.swift iqamah/Views/AdhaanBannerView.swift
git commit -m "feat: glass backgrounds on About, Qiblah, Settings sheets and AdhaanBanner"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|-----------------|------|
| BUG-0038 Color centralization | Task 1 |
| BUG-0039 Adhaan column | Task 7 |
| BUG-0040 Settings height | Task 2 |
| BUG-0041 PIL comment | Task 2 |
| BUG-0042 ForEach identity | Task 7 |
| BUG-0043 Double-rounded icon | Task 2 |
| BUG-0044 Onboarding gold tint | Task 3 |
| BUG-0045 Display Size removal | Task 3 |
| BUG-0046 Settings Form style | Task 6 |
| BUG-0047 About Close button | Task 2 |
| AppAppearance enum + UserDefaults | Task 4 |
| IqamahBackground gradient | Task 5 |
| `.preferredColorScheme` wiring | Task 5 |
| Glass header/toolbar/datebar | Task 8 |
| Glass prayer rows + GlassEffectContainer | Task 8 |
| Glass sheets + banner | Task 9 |
| `appGoldDark` light-mode contrast | Task 1 (token) + Task 7 (`effectiveGold`) |
| `.buttonStyle(.glass)` toolbar macOS 26+ | ⚠️ Not covered — see note below |

**Note on `.buttonStyle(.glass)`:** The spec mentions glass toolbar buttons on macOS 26+. This is a minor polish item — add `.buttonStyle(.glass)` conditionally to the `SecondaryToolbarButton` view if the implementation worker has time, but it does not block success criteria.

**Placeholder scan:** No TBD, TODO, or "implement later" strings found.

**Type consistency check:**
- `AppAppearance` defined in Task 4, used in Tasks 6 and 5 ✓
- `Color.appGold` / `Color.appGoldDark` defined in Task 1, used throughout ✓
- `effectiveGold` computed property defined in Task 7 `PrayerTimeRow`, used within that struct only ✓
- `expandedPrayerName: String?` defined in Task 7 `PrayerTimesTable`, threaded as `isPickerExpanded: Bool` + `onTogglePicker` to `PrayerTimeRow` ✓
- `Adhaan.shortName` defined in Task 7 Step 5, used in Task 7 Step 4 ✓
- `IqamahBackground` defined in Task 5 Step 1, used in Task 5 Step 3 ✓
