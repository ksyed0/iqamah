# Design Polish — Glassmorphic Redesign + Bug Fixes

**Date:** 2026-05-03  
**Status:** Approved — ready for implementation planning  
**Bugs addressed:** BUG-0038 through BUG-0047  
**New features:** Glassmorphic visual layer, Appearance switcher

---

## 1. Goals

1. Fix ten design-quality issues identified in the 2026-05-03 design review (BUG-0038–0047).
2. Introduce a glassmorphic visual layer using SwiftUI materials on macOS 14–25 and Apple Liquid Glass on macOS 26+.
3. Add a three-way appearance switcher (Light / Dark / System) with System as the default.
4. Make the adhaan sound feature discoverable without requiring hover.

---

## 2. Bug Fixes (no design decisions needed)

These are straightforward code changes with no ambiguity.

### BUG-0041 — Remove stale PIL comment
**File:** `iqamah/Views/SplashScreenView.swift:23`  
Delete the line `// (CoreText handles Arabic shaping correctly; PIL cannot)`. PIL is a Python library with no relevance to this codebase.

### BUG-0042 — Fix ForEach identity in PrayerTimesTable
**File:** `iqamah/Views/PrayerTimesView.swift:210`  
Change `ForEach(Array(prayerTimes.prayers.enumerated()), id: \.offset)` to `ForEach(prayerTimes.prayers, id: \.name)`. Prayer names are stable unique identifiers; using the array index loses SwiftUI's ability to animate row changes correctly.

### BUG-0043 — Remove double-rounded app icon clip
**File:** `iqamah/Views/PrayerTimesView.swift:31`  
Remove `.clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))`. `NSImage(named: NSImage.applicationIconName)` is already pre-rounded by the OS; the second clip creates a tighter inner corner that looks subtly wrong.

### BUG-0047 — Fix About Close button prominence
**File:** `iqamah/Views/AboutView.swift:149`  
Change `.buttonStyle(.borderedProminent).tint(gold)` to `.buttonStyle(.bordered)`. Per Apple HIG, `.borderedProminent` is for primary forward actions (Save, Continue). A dismiss action uses `.bordered` or `.plain`.

### BUG-0040 — Fix Settings sheet fixed height
**File:** `iqamah/Views/SettingsSheetView.swift:291`  
Change `.frame(width: 480, height: 660)` to `.frame(width: 480, minHeight: 540, maxHeight: 700)`. The existing `ScrollView` handles content that exceeds `maxHeight`. This prevents overflow on displays where the main window is at its minimum height.

---

## 3. Brand Color Centralization (BUG-0038)

### Problem
`Color(red: 0.88, green: 0.69, blue: 0.06)` is defined as `private let gold` in six view files and as inline literals in two more. Any brand color change requires editing eight files.

### Solution
Create `iqamah/Extensions/Color+App.swift`:

```swift
extension Color {
    static let appGold = Color(red: 0.88, green: 0.69, blue: 0.06)
    static let appGoldDim = Color(red: 0.95, green: 0.76, blue: 0.06) // header gradient variant
}
```

Replace all `private let gold = Color(...)` local definitions and inline literals across:
- `PrayerTimesView.swift` (gradient and inline)
- `PrayerTimeRow` (local `gold` constant)
- `AdhaanBannerView.swift`
- `AboutView.swift`
- `QiblahView.swift`
- `SunArcView` / `WaveBar`

### BUG-0044 — Onboarding button tint (depends on BUG-0038)
**Files:** `LocationSetupView.swift:132`, `CalculationMethodView.swift:131`  
Add `.tint(.appGold)` to the `.borderedProminent` Continue buttons in both onboarding views. This makes the first-run funnel consistent with the gold accent used on action buttons throughout the rest of the app.

---

## 4. Adhaan Column — Discoverable Design (BUG-0039)

### Problem
The adhaan picker is gated behind hover (`isHovering || selectedAdhaan.id != "silent"`). Users who never hover a row never know the feature exists.

### Solution — Option C: Dedicated Adhaan Column

Add a persistent adhaan column to the `PrayerTimeRow` grid between the prayer name and the time. No hover required. Clicking the column expands an inline chip picker directly below the row.

**Grid layout change:**  
Current: `4px | 44px icon | 1fr name | 100px time | 35px badge | adj controls | mute`  
New: `4px | 44px icon | 1fr name | 90px adhaan | 72px time | adj controls | mute`

The adjustment badge (±N) is shown only when non-zero, as a small capsule superimposed on the time value (top-right corner of the time cell). When zero it is hidden entirely — no placeholder space needed.

**Adhaan column states:**
- **Silent (default):** muted `♪` icon + italic `—` in `Color.secondary.opacity(0.4)`. Tappable — click opens picker.
- **Set:** gold `♪` icon + adhaan short name (e.g. "Fajr 1", "Adhaan 2") in `Color.appGold.opacity(0.8)`. Tappable — click opens picker.

**Inline picker (expanded state):**  
When the adhaan column is clicked, a chip row expands below the prayer row with animation (`.transition(.opacity.combined(with: .move(edge: .top)))`). Chips are the available adhaan options for that prayer. A "▶ preview" button appears when an adhaan is selected. Selecting "Silent" or pressing Escape collapses the picker. Clicking another prayer row's adhaan column while one is expanded first collapses the open one, then opens the new one.

**Hover behavior:** The existing hover expansion for the full picker sub-row is removed. The column replaces it entirely.

**Sunrise row:** No adhaan column — Sunrise retains its existing simplified row with a `Color.clear` spacer in the adhaan column slot to maintain grid alignment.

---

## 5. Display Size Removed from Onboarding (BUG-0045)

**File:** `iqamah/Views/CalculationMethodView.swift:68–115`  
Remove the entire "Display Size" stepper block from step 2 of onboarding. The setting remains accessible via Settings → Display. The apologetic label `"(you can change this later in Settings)"` is self-evidence that this control does not belong in onboarding.

---

## 6. Settings Sheet — Form Style (BUG-0046)

### Problem
`SettingsSheetView` reimplements macOS settings layout manually: custom `SectionHeader`, manual `Divider()`, hand-rolled `SettingsRow`, explicit `padding(.horizontal, 28)` on every section, and a hardcoded `height: 660`.

### Solution
Refactor the content area to use `Form { }.formStyle(.grouped)`:

```swift
Form {
    Section("Location") {
        // Country picker
        // City picker (conditional)
    }
    Section("Calculation") {
        // Method picker + recommendation label
        // Asr radio group
    }
    Section("Display") {
        // 24-hour toggle
        // Launch at login toggle
        // Display size stepper
    }
}
.formStyle(.grouped)
```

**Remove:** `SectionHeader`, `SettingsRow`, all manual `Divider()` calls inside scroll content, and `padding(.horizontal, 28)` on section content. The `Form` provides correct insets, grouped backgrounds, and focus ring behavior automatically.

**Keep:** The custom header ("Settings" title), the Cancel/Save button footer, and the outer `VStack` wrapping both.

---

## 7. Appearance Switcher

### Feature
A three-way appearance preference stored in `SettingsManager` and applied at the root `WindowGroup`.

**Options:** System (default) · Light · Dark  
**Default:** System — respects macOS System Settings, no forced override.

### Storage
Add to `SettingsManager`:
```swift
enum AppAppearance: String, CaseIterable {
    case system, light, dark
}
@Published var appearance: AppAppearance = .system  // UserDefaults key: "appAppearance"
```

### Application
In `ContentView` or the root `WindowGroup` scene, apply:
```swift
.preferredColorScheme(settingsManager.appearance.colorScheme)
// where:
// .system → nil (system default)
// .light  → .light
// .dark   → .dark
```

### Settings UI placement
Add to Settings → Display section, below the 24-hour toggle:

```
Appearance
  ○ System   ● Dark   ○ Light       (segmented picker or radio group)
```

Use `.pickerStyle(.segmented)` for compact inline display.

### Default behavior note
Because the glassmorphic redesign (Section 8) works well in both dark and light mode via separate gradient backgrounds, the default of **System** is safe — neither mode is degraded.

---

## 8. Glassmorphic Visual Redesign

### Philosophy
Replace the flat opaque window background with an atmospheric gradient that glass surfaces can blur against. Each UI layer (header, toolbar, prayer rows) becomes a glass panel. The gradient is thematically tied to the Islamic prayer cycle — warm amber for dawn (Fajr) through deep indigo for night (Isha).

### Ambient Background

Add `IqamahBackground` as a SwiftUI `View` that fills the window behind all content:

**Dark mode gradient:**
```
radial top-left:  rgba(80,40,8,0.92)  — amber/fire (Fajr warmth)
radial bot-right: rgba(12,20,65,0.95) — deep indigo (Isha night)
radial mid:       rgba(100,20,80,0.5) — dusk purple (Maghrib)
base:             #190800 → #0c0c1a
```

**Light mode gradient:**
```
radial top-left:  rgba(255,235,180,0.55) — golden dawn
radial bot-right: rgba(200,220,255,0.4)  — cool afternoon blue
base:             #fff8ec → #e8f0ff
```

`IqamahBackground` is a plain `Rectangle()` with these gradients. It sits as the `.background` of the root `ZStack` in `ContentView`, behind `PrayerTimesView`.

### Glass Layer — Two-tier conditional

Every glass surface in the app uses this pattern:

```swift
// For panel backgrounds (header, toolbar, date bar):
.background {
    if #available(macOS 26, *) {
        Rectangle().glassEffect()
    } else {
        Rectangle().fill(.ultraThinMaterial)
    }
}

// For individual prayer rows:
.background {
    if #available(macOS 26, *) {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .glassEffect(.regular.tint(...))
    } else {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}
```

On macOS 26+, wrap the entire prayer table in a `GlassEffectContainer` so adjacent rows morph into each other on hover/expansion.

### Surfaces affected

| Surface | macOS 14–25 | macOS 26+ |
|---------|-------------|-----------|
| Window background | `IqamahBackground` gradient | Same |
| Primary header | `.ultraThinMaterial` + `strokeBorder` | `.glassEffect()` |
| Secondary toolbar | `.ultraThinMaterial` + `strokeBorder` | `.glassEffect()` |
| Date bar | `.ultraThinMaterial` | `.glassEffect()` |
| Normal prayer row | `.ultraThinMaterial` + `strokeBorder` | `.glassEffect(.regular)` |
| Next-prayer row | `.ultraThinMaterial` gold-tinted | `.glassEffect(.regular.tint(.appGold.opacity(0.15)))` |
| Sunrise row | `.fill(.ultraThinMaterial.opacity(0.5))` | `.glassEffect()` with reduced opacity |
| Settings sheet | `.ultraThinMaterial` chrome | `.glassEffect()` |
| Qiblah sheet | `.ultraThinMaterial` | `.glassEffect()` |
| About sheet | `.ultraThinMaterial` | `.glassEffect()` |
| AdhaanBannerView | Already uses `.ultraThinMaterial` ✓ | Upgrade to `.glassEffect()` |

### Toolbar buttons (macOS 26+ only)
The secondary toolbar buttons (Qiblah / Settings / About) get `.buttonStyle(.glass)` on macOS 26+, remaining as plain text buttons on macOS 14–25.

### Text contrast
On glass surfaces, `Color.primary` and `Color.secondary` remain unchanged — they adapt to dark/light mode automatically. The gold accent (`Color.appGold`) is unchanged. No manual contrast overrides are needed because SwiftUI materials handle vibrancy.

### `windowBackground` removal
Remove `.background(Color(nsColor: .windowBackgroundColor))` from `PrayerTimesView` and any other views that set it. The `IqamahBackground` gradient replaces it. `SettingsSheetView`, `QiblahView`, and `AboutView` (presented as sheets) inherit the window material automatically on macOS 26+; on 14–25 they get `.background(.regularMaterial)`.

---

## 9. Files to Create / Modify

| File | Change |
|------|--------|
| `iqamah/Extensions/Color+App.swift` | **Create** — `Color.appGold`, `Color.appGoldDim` |
| `iqamah/Views/IqamahBackground.swift` | **Create** — ambient gradient view, dark + light variants |
| `iqamah/Views/PrayerTimesView.swift` | Major — adhaan column, glass rows, ForEach identity fix, icon clip fix, background removal |
| `iqamah/Views/SplashScreenView.swift` | Minor — remove stale PIL comment |
| `iqamah/Views/LocationSetupView.swift` | Minor — gold tint on Continue button |
| `iqamah/Views/CalculationMethodView.swift` | Minor — remove Display Size block, gold tint on Continue |
| `iqamah/Views/SettingsSheetView.swift` | Major — Form style refactor, appearance picker, height fix |
| `iqamah/Views/AboutView.swift` | Minor — Close button prominence fix, gold color ref |
| `iqamah/Views/QiblahView.swift` | Minor — glass background, gold color ref |
| `iqamah/Views/AdhaanBannerView.swift` | Minor — glass upgrade on macOS 26+, gold color ref |
| `iqamah/Models/SettingsManager.swift` | Add `AppAppearance` enum + `@Published var appearance` |
| `iqamah/ContentView.swift` | Add `IqamahBackground` + `.preferredColorScheme` |

---

## 10. Out of Scope

- Liquid Glass morphing animations between non-adjacent elements
- Custom `NSWindowStyleMask` or vibrancy material on the NSWindow level (unnecessary — SwiftUI materials handle this)
- Any changes to prayer calculation, location, or adhaan audio logic
- watchOS or iOS ports

---

## 11. Success Criteria

- [ ] `Color.appGold` is the only definition of the brand gold — no local `let gold` anywhere
- [ ] Adhaan selection for each prayer is visible without hovering
- [ ] Clicking an adhaan column cell opens an inline chip picker with animation
- [ ] Main window shows atmospheric gradient background in both dark and light mode
- [ ] On macOS 14–25: prayer rows use `.ultraThinMaterial` with `strokeBorder`
- [ ] On macOS 26+: prayer rows use `.glassEffect()` wrapped in `GlassEffectContainer`
- [ ] Appearance switcher (System/Light/Dark) in Settings → Display works correctly
- [ ] Settings sheet uses `Form { }.formStyle(.grouped)` — no manual dividers or section headers
- [ ] Onboarding Continue buttons are gold-tinted
- [ ] Display Size stepper is absent from onboarding step 2
- [ ] About Close button uses `.bordered` not `.borderedProminent`
- [ ] App compiles and runs on macOS 14 (no macOS 26 API called without `#available` guard)
