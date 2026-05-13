# Adaptive Layout Design Spec
**Date:** 2026-05-13
**Status:** Draft — approved for implementation planning
**Scope:** EPIC-0014 — Adaptive Layout (iPhone · iPad · macOS Qibla scaling)
**IDs used:** EPIC-0014, US-0061–US-0063, AC-0276–AC-0295

---

## 1. Goal

Replace all hardcoded macOS-sized frames with adaptive layouts driven by `GeometryReader` and `horizontalSizeClass`. Three user stories:

- **US-0061** — Adaptive prayer times view (iPhone single-column hero · iPad portrait hero · iPad landscape today/tomorrow split)
- **US-0062** — Adaptive prayer row on iOS (adhaan pill always visible · tap-to-expand chip picker · Sunrise alert-only · no ±controls on mobile)
- **US-0063** — Adaptive Qibla compass (GeometryReader scaling on all platforms · centered prayer mat · iPad landscape info panel)

---

## 2. Current Problems

| File | Symptom |
|------|---------|
| `PrayerTimesView.swift` | `.frame(minWidth: 580, idealWidth: 620, minHeight: 640)` clips iPhone; iPad wastes horizontal space |
| `QiblahView.swift` | Fixed `320pt` compass, fixed `.frame(width: 440, height: 560)` outer container |
| `PrayerTimesView` prayer row | All controls (±, adhaan pill 100pt, mute) always inline — overflows iPhone width (~450pt total) |
| `Adhaan.swift` | No `availableForSunrise` — Sunrise row has no audio controls at all |

---

## 3. Architecture

No new targets. All changes are in existing files:

| File | Change |
|------|--------|
| `iqamah/Views/PrayerTimesView.swift` | Adaptive layout via `horizontalSizeClass` + `GeometryReader` |
| `iqamah/Views/PrayerTimesComponents.swift` | Adaptive prayer row; `expandedPrayerName` state |
| `iqamah/Views/QiblahView.swift` | GeometryReader compass; proportional mat |
| `iqamah/iOS/iOSRootView.swift` | No structural change needed |
| `Packages/IqamahCore/Sources/IqamahCore/Models/Adhaan.swift` | Add `availableForSunrise` |

---

## 4. US-0061 — Adaptive Prayer Times View

### 4.1 Layout rules

```
horizontalSizeClass == .regular AND orientation == landscape
    → iPad landscape layout (Section 4.3)

horizontalSizeClass == .regular AND orientation == portrait
    → iPad portrait layout (Section 4.2)

horizontalSizeClass == .compact   (iPhone any orientation)
    → iPhone layout (Section 4.2, same single-column with smaller hero)

os(macOS)
    → Existing layout unchanged
```

Detection in SwiftUI:
```swift
@Environment(\.horizontalSizeClass) private var hSizeClass
// orientation via GeometryReader: width > height → landscape
```

### 4.2 iPhone + iPad portrait layout

```
┌─────────────────────────────┐
│  [App icon] Iqamah  City    │  ← existing header, unchanged
│             Method     🔊   │
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ 🌒  25 Dhu al-Qi'dah   │ │  ← Hero card (new on iOS)
│ │     1447 AH             │ │
│ │     Waning Crescent     2:14│
│ │                  [Hilal Watch ›] │
│ └─────────────────────────┘ │
│  Tuesday, May 12, 2026      │
│  Fajr          ··· 4:20 AM  │
│  Sunrise       ··· 5:56 AM  │
│  ▶ Dhuhr NEXT  ··· 1:14 PM  │  ← highlighted
│  Asr           ··· 5:13 PM  │
│  Maghrib       ··· 8:31 PM  │
│  Isha          ··· 10:07 PM │
├─────────────────────────────┤
│  Times    Qiblah   Settings │  ← tab bar
└─────────────────────────────┘
```

**Hero card contents (new `PrayerHeroCard` view):**
- Moon phase view (existing `MoonPhaseView`, size 44pt)
- Hijri date string + moon phase subtitle
- Countdown to next prayer (`.timer` style, right-aligned)
- "Hilal Watch ›" button → posts `.openHilalWatch` notification

**What is removed from iOS:**
- "About Iqamah" link (accessible via Settings tab)
- Secondary toolbar Qiblah + Settings buttons (already done in PR #78; About button also removed)
- ±adjustment controls on prayer rows (see US-0062)
- The macOS `.frame(minWidth: 580...)` constraint (replace with `.frame(maxWidth: .infinity)`)

### 4.3 iPad landscape layout

```
┌──────────────────────────────────────────────────────┐
│ [I] Iqamah  Toronto · ISNA   🌒 25 Dhu al-Qi'dah   2:14 🔊│  ← full-width header row
├─────────────────────────┬────────────────────────────┤
│  Today                  │  Tomorrow (55% opacity)    │
│  Fajr     ··· 4:20 AM   │  Fajr     ··· 4:19 AM     │
│  Sunrise  ··· 5:56 AM   │  Sunrise  ··· 5:55 AM     │
│ ▶Dhuhr    ··· 1:14 PM   │  Dhuhr    ··· 1:14 PM     │
│  Asr      ··· 5:13 PM   │  Asr      ··· 5:14 PM     │
│  Maghrib  ··· 8:31 PM   │  Maghrib  ··· 8:32 PM     │
│  Isha     ··· 10:07 PM  │  Isha     ··· 10:08 PM    │
│  [Hilal Watch ›]        │                            │
├─────────────────────────┴────────────────────────────┤
│  Times              Qiblah              Settings     │
└──────────────────────────────────────────────────────┘
```

**Full-width header (landscape-only):** single `HStack` containing brand, city/method, moon circle, Hijri date string, countdown, mute button. Replaces the stacked header + hero card.

**Columns:** 50/50 split via `HStack`. A hairline divider separates the columns.

**Tomorrow column** renders the same `PrayerRowView` as Today, including:
- Adhaan pill (always visible between name and time)
- Expand-on-tap chip tray (full adhaan + alert options, same as Today)
- No "NEXT" highlight (no prayer is highlighted in Tomorrow)
- 55% opacity on rows whose time has not yet passed; past rows at 28% (same dimming rule as Today, evaluated against tomorrow's dates)

`expandedPrayerName` is shared across both columns so only one row across both columns is open at a time. The expand state identifies a row by `(date, name)` tuple, not just `name`, to distinguish today's Fajr from tomorrow's Fajr.

**"Hilal Watch ›"** button lives at the bottom of the Today column.

### 4.4 Acceptance criteria (US-0061)

- AC-0276: iPhone prayer times screen shows all 6 rows without clipping or horizontal scroll
- AC-0277: Hero card visible on iPhone and iPad portrait above the prayer list
- AC-0278: Countdown in hero card updates every minute
- AC-0279: "Hilal Watch ›" in hero card opens HilalWatchSheet on iOS
- AC-0280: iPad landscape shows today + tomorrow columns side by side
- AC-0281: Tomorrow column rows have adhaan pills and expand-on-tap chip trays
- AC-0282: Only one row across both columns is expanded at a time
- AC-0283: iPad landscape header spans full width with moon + countdown inline
- AC-0284: macOS layout unchanged

---

## 5. US-0062 — Adaptive Prayer Row on iOS

### 5.1 Row default state

```
[icon]  Prayer name       [adhaan pill]   time
```

- Icon: existing 44pt circle (kept)
- Name: `.body.bold()` for next, `.body` otherwise
- Adhaan pill: always visible, positioned between name and time via `Spacer()`
  - Prayer rows: grey pill "No adhaan" or gold pill with adhaan name
  - Sunrise row: amber pill "No alert" or amber pill with alert tone name
- Time: right-aligned, tabular digits
- **No ±stepper buttons** on iOS — adjustments remain in Settings only
- **No per-row mute toggle** — replaced by Mute chip inside the expanded picker

### 5.2 Expand on tap

One row expanded at a time. Tapping an already-expanded row collapses it. Tapping a different row collapses the current and expands the new one.

State in `PrayerTimesComponents`:
```swift
@State private var expandedPrayerName: String? = nil
```

Expanded row: pill changes to blue-tinted "··· ›" style. Below the row a chip tray slides in with `withAnimation(.spring(duration: 0.25))`.

### 5.3 Chip tray — standard prayers

```
🔔 Alert tones
[Chime]  [Bell]  [Soft]  [Ping]

🕌 Adhaan
[No adhaan★]  [Makkah]  [Madinah]  [Al-Aqsa]  [Short]  […]
[🔇 Mute]
```

- Selected chip has gold (adhaan) or amber (alert) fill
- Tapping a chip: saves selection via `SettingsManager.setAdhaan(_:for:)`, collapses tray
- 🔇 Mute chip: calls `SettingsManager.setPrayerMuted(true, for:)`, collapses
- Fajr: shows `availableForFajr` (Fajr-specific adhaan recordings) instead of `available`

### 5.4 Chip tray — Sunrise

```
🔔 Alert tones
[No alert★]  [Chime]  [Bell]  [Soft]  [Ping]
```

- No adhaan recordings section
- No Mute chip (alert tones are already optional; "No alert" = silence)
- Uses `Adhaan.availableForSunrise` (new computed property: `[.silent] + alertTones`)
- Pill label: "No alert" when silent, alert tone name when set

### 5.5 IqamahCore change — `Adhaan.availableForSunrise`

```swift
/// Alert tones only — suitable for Sunrise which is not a prayer.
public static var availableForSunrise: [Adhaan] {
    var options: [Adhaan] = [.silent]
    options += alertTones
    return options
}
```

### 5.6 macOS unchanged

On macOS, prayer rows keep the existing inline layout: ±buttons, 100pt adhaan pill, per-row mute toggle. The `PrayerRowView` uses `#if os(iOS)` for the compact/expand path and `#else` for the existing macOS path.

### 5.7 Acceptance criteria (US-0062)

- AC-0285: Prayer row shows `icon · name · pill · time` on iPhone without overflow
- AC-0286: Tapping a row expands adhaan chip tray inline below it
- AC-0287: Only one row expanded at a time; tapping another row collapses the previous
- AC-0288: Tapping a chip saves the selection and collapses the tray
- AC-0289: Gold pill shows selected adhaan name; grey "No adhaan" when silent
- AC-0290: Sunrise row shows amber "No alert" pill
- AC-0291: Sunrise chip tray shows only alert tones (no adhaan recordings, no Mute chip)
- AC-0292: Amber pill shows selected alert tone name when set
- AC-0293: Fajr chip tray shows Fajr-specific adhaan recordings
- AC-0294: macOS prayer row layout unchanged

---

## 6. US-0063 — Adaptive Qibla Compass

### 6.1 Scaling formula

```swift
GeometryReader { geo in
    let diameter = min(geo.size.width, geo.size.height) * 0.85
    QiblahCompassView(diameter: diameter, bearing: qiblahBearing)
}
```

Applies on **all platforms** (iOS, iPadOS, macOS). Removes all fixed `.frame(width: 320)` and `.frame(width: 440, height: 560)` from `QiblahView`.

### 6.2 Prayer mat — centered and proportional

The existing mat is positioned at the needle tip. Replace with a **centered mat** whose size scales with `radius`:

```
matWidth  = radius * 0.24   // ~44pt at 320pt radius → readable at all sizes
matHeight = radius * 0.32
archHeight = matHeight * 0.30
```

Drawing order (all within `transform: translate(cx,cy) rotate(bearing)`):
1. Mat body rect, centered at (0, 0), pointing "up" (toward the arch)
2. Arch path at the top edge of the mat
3. Inner arch decorative line
4. Center dot on top of mat (z-order last, always visible)

The dashed gold needle starts at (0, 0) (center / center dot) and extends to (0, −radius + tick_inset).

### 6.3 iPad landscape — info panel

When `horizontalSizeClass == .regular` and orientation is landscape, `QiblahView` uses an `HStack`:

```
┌──────────────────────┬─────────────────┐
│   [compass, fills]   │  Bearing: 58.3° │
│                      │  NE             │
│                      │                 │
│                      │  From: Toronto  │
│                      │  43.65°N 79.38°W│
│                      │                 │
│                      │  To: Makkah     │
│                      │  21.42°N 39.83°E│
└──────────────────────┴─────────────────┘
```

Info panel width: `min(200, geo.size.width * 0.28)`. Compass gets the remaining width.

### 6.4 Acceptance criteria (US-0063)

- AC-0295: Compass diameter = `min(available.width, available.height) × 0.85` on all platforms
- AC-0296: Prayer mat is centered in the compass and rotated to qibla bearing
- AC-0297: Mat arch points toward Makkah; needle radiates from center to ring
- AC-0298: Mat proportions scale with radius (no fixed pixel sizes)
- AC-0299: iPad landscape shows info panel alongside compass
- AC-0300: macOS compass scales with window resize

---

## 7. Data Flow

No new data sources. Existing `SettingsManager`, `PrayerCalculator`, and `AdhaaanPlayer` are unchanged. `PrayerTimesView` fetches tomorrow's times using `PrayerCalculator.calculate(for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)` only when in iPad landscape layout.

---

## 8. Testing

### Unit tests

| Test | Assertion |
|------|-----------|
| `testAvailableForSunrise` | `Adhaan.availableForSunrise` contains `.silent` and all `alertTones`, no adhaan recordings |
| `testAvailableForSunriseNoRecordings` | No element in `availableForSunrise` has `id` starting with "adhaan_" or "fajr_" |

### Manual QA gates

- iPhone 17 sim: prayer times fully visible, no horizontal clipping; hero card visible; Hilal Watch button works
- iPhone 17 sim: tap each prayer row → chip tray expands; tap again → collapses
- iPhone 17 sim: tap Sunrise → amber tray with only alert tones visible
- iPhone 17 sim: select adhaan chip → pill updates, tray closes
- iPad Pro 11" sim portrait: hero card + single column layout
- iPad Pro 11" sim landscape: today/tomorrow split; header inline; adhaan chips work in both columns; tapping tomorrow's Fajr while today's Fajr is open collapses today's
- iPad Pro 11" sim: Qibla compass fills available space; mat centered
- macOS: prayer times layout unchanged; Qibla compass scales with window resize

---

## 9. Scope Boundaries

**In scope:**
- All layouts described above
- `Adhaan.availableForSunrise`
- GeometryReader compass on all platforms
- Centered proportional prayer mat

**Out of scope:**
- watchOS layout changes (separate concern)
- Font size scaling beyond what SwiftUI's Dynamic Type already provides
- Interactive compass with device rotation / CoreMotion (future epic)
- Tomorrow column in Settings adjustments view

---

## 10. IDs

| ID | Item |
|----|------|
| EPIC-0014 | Adaptive Layout |
| US-0061 | Adaptive prayer times view |
| US-0062 | Adaptive prayer row on iOS |
| US-0063 | Adaptive Qibla compass |
| AC-0276–AC-0284 | US-0061 acceptance criteria (9 ACs) |
| AC-0285–AC-0294 | US-0062 acceptance criteria (10 ACs) |
| AC-0295–AC-0300 | US-0063 acceptance criteria (6 ACs) |

**Last Updated:** 2026-05-13 (rev 2: tomorrow column gets full adhaan controls; expand state keyed on date+name tuple; implementation snag confirmed non-issue — prayer list is VStack not List)
