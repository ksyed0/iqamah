# EPIC-0011 — Hilal Watch Design Spec
**Date:** 2026-05-10
**Status:** Draft — under review
**Scope:** EPIC-0011 (US-0046 – US-0052, AC-0204 – AC-0251)
**Promoted from:** ENH-0018
**Preview standard:** All new UI reviewed in 4 variants — Materials Glass Light/Dark + Liquid Glass Light/Dark (per `CLAUDE.md` § UI Conventions)

---

## 1. Goal

Add a **Hilal Watch** screen that computes and visualises global crescent-moon visibility for the two evenings (29th and 30th of each Hijri month) on which the new Islamic month is determined globally. Users should be able to:

1. See, at a glance from the prayer-times screen, whether tonight is a watch evening
2. Open the global visibility map for the current month and navigate ±N synodic months
3. Read precise, peer-reviewed Odeh values (ARCL, ARCV, W, V) for their own location
4. Receive an opt-in notification ~30 min before sunset on the 29th
5. Switch between three published visibility criteria (Odeh 2004, Yallop 1997, HMNAO Enhanced)
6. Manually offset the displayed Hijri date to align with their local sighting committee
7. Share a snapshot of the global map for community/family chats during Ramadan & Eid season

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  IqamahCore (Swift Package, shared macOS / iOS)             │
│                                                             │
│  Astronomy/                                                 │
│   ├── MoonPosition.swift   ← Meeus port of astronomy-engine │
│   ├── SunPosition.swift    ← solar coords + sunset          │
│   ├── NewMoon.swift        ← new-moon JD by Meeus           │
│   ├── VisibilityCriterion  ← protocol: f(arcv, w, arcl) → cat │
│   │     ├── OdehCriterion          (default, 2004)          │
│   │     ├── YallopCriterion        (1997)                   │
│   │     └── HMNAOCriterion         (enhanced)               │
│   ├── HilalCalculator      ← grid + local card computation  │
│   └── HijriCalendar        ← identifier + day offset        │
│                                                             │
│  + existing PrayerCalculator, LocationService, …            │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
┌──────────────────┐    ┌──────────────────┐
│ iqamah (macOS)   │    │ iqamah-iOS       │
│  HilalWatchView  │    │  HilalWatchView  │  ← largely shared,
│  HilalMapView    │    │  HilalMapView    │     branched only
│  LocalSightingC… │    │  LocalSightingC… │     where AppKit /
│  MoonPhaseView   │    │  MoonPhaseView   │     UIKit differs
│  AboutCardView   │    │  AboutCardView   │
└──────────────────┘    └──────────────────┘
```

**Key principle:** All astronomy and visibility logic lives in `IqamahCore` and is platform-neutral. View code lives in the platform targets and shares as much SwiftUI as possible.

---

## 3. Dependencies on EPIC-0010

This epic **must** land after EPIC-0010 (iOS conversion). It depends on:

| EPIC-0010 deliverable | Used here for |
|---|---|
| `IqamahCore` Swift package | All `Astronomy/` code lives here |
| App Group + iCloud KVS sync | Per-device Hilal Watch settings (criterion, day offset, notification flag) sync between Mac and iPhone |
| `UNUserNotificationCenter` scheduling pipeline | The d29 watch reminder reuses the same scheduling, deep-linking, and re-schedule machinery introduced for prayer notifications |
| `SettingsManager` extensions for `activeCoordinate` / `activeTimezoneIdentifier` | Local sighting card sources the user's location from these |
| iOS-side notification deep-link routing | Tapping the Hilal Watch notification opens the app on the d29 tab |

If EPIC-0010 is not yet on `develop` when this epic begins implementation, the work cannot start beyond Branch 1 (the astronomy port can begin in `IqamahCore` once that package exists).

---

## 4. Astronomy port (Branch 1 of implementation plan)

### 4.1 Source

[astronomy-engine v2](https://github.com/cosinekitty/astronomy) — MIT-licensed, ~3000 LOC of pure JS math. We port **only the subset needed**, not the whole library. Required functions:

- `Equator(body, date, observer, ofdate, aberration)` → topocentric RA/Dec/distance for Sun and Moon
- `Horizon(date, observer, ra, dec, refraction)` → altitude (used for ARCV at sunset)
- `SearchMoonPhase(targetLon, startDate, days)` → new-moon Julian Day (used for d29 / d30 anchoring)
- The 60+ Meeus lunar longitude / latitude / distance series (Astronomical Algorithms, Ch. IIIb)
- Aberration + nutation tables (small fixed-size arrays)

Total estimated port: 500–700 LOC of pure Swift, no external dependencies. Lives in `IqamahCore/Sources/IqamahCore/Astronomy/`.

### 4.2 Validation strategy

Three layers of automated tests in `IqamahCore/Tests/IqamahCoreTests/AstronomyTests.swift`:

1. **Unit tests** — fixed (date, location) pairs with expected RA/Dec values from astronomy-engine's own JS test suite. ±0.001° tolerance.
2. **Critical-period tests** — the months where moonsighting.com publishes maps (rolling, last 24 months). Compute our V values for ~20 sample locations and assert ±0.5° vs the published reference table.
3. **ICOP set** — Odeh (2004) was validated against 737 historical observations. We replay them: compute our category prediction for each and assert the same true-positive / true-negative rates Odeh reports. 100% A-zone hit rate, 0% D-zone hit rate.

### 4.3 Why not SwiftAA?

SwiftAA wraps the AA+ C++ library — pulls in C++ bridging (~2 MB binary cost) and a much larger API surface than we need. Direct port is simpler to audit, simpler to test, and keeps `IqamahCore` dependency-free.

---

## 5. Visibility criteria (`VisibilityCriterion` protocol)

### 5.1 Protocol

```swift
public protocol VisibilityCriterion {
    /// Returns 0 (not visible) … 4 (easily visible naked eye)
    func category(arcv: Double, arcl: Double, distanceKm: Double) -> Int
    /// Returns the V-score (or equivalent) for display in the local card
    func score(arcv: Double, arcl: Double, distanceKm: Double) -> Double
    /// Display name for the picker
    var displayName: String { get }
    /// Short description for the About card
    var explanation: String { get }
}
```

### 5.2 Implementations

| Type | Threshold function | Notes |
|---|---|---|
| `OdehCriterion` | `V = ARCV − f(W)` where `f(W) = -0.1018·W³ + 0.7319·W² − 6.3226·W + 7.1651`; A ≥ 5.65, B ≥ 2.0, C ≥ −0.96, D ≥ −8 | Default. Validated against 737 ICOP observations. |
| `YallopCriterion` | Yallop's q-test from 1997 NAO Technical Note | Slightly more conservative; used by ISNA committees and many UK communities |
| `HMNAOCriterion` | HMNAO Enhanced extension of Yallop with refined coefficients | Used by some European committees |

All three operate on the same upstream Meeus astronomy outputs. **Switching criterion only changes the threshold function**, not the position computation.

### 5.3 Open question — exact coefficients

The Yallop and HMNAO coefficient tables need authoritative-source verification before implementation. Pre-implementation task: cross-check against:
- Yallop, B.D. (1997) NAO Technical Note No. 69
- HMNAO Astronomical Information Sheet (current edition)

Two sources at minimum, ideally a published paper that reproduces the values.

---

## 6. Grid computation & caching (`HilalCalculator`)

### 6.1 Inputs

```swift
public struct HilalGridRequest {
    let newMoonJD: Double           // canonical anchor for cache key
    let evening: Evening            // .d29 or .d30
    let criterion: any VisibilityCriterion
}
```

### 6.2 Output

`ContiguousArray<Int8>` of 16,200 categories (90 latitudes × 180 longitudes, 2° × 2° cells). `0` means not visible / polar day / polar night; `1`–`4` are the A/B/C/D categories. `ContiguousArray` (not `Array`) so the inner `withTaskGroup` writes are guaranteed contiguous and avoid CoW costs.

### 6.3 Algorithm

```swift
func computeGrid(_ req: HilalGridRequest) async -> ContiguousArray<Int8> {
    let cores = ProcessInfo.processInfo.activeProcessorCount
    let stride = (90 + cores - 1) / cores
    return await withTaskGroup(of: (Int, [Int8]).self) { group in
        for c in 0..<cores {
            let band = (c * stride)..<min((c + 1) * stride, 90)
            group.addTask {
                (band.lowerBound, computeBand(band, req))
            }
        }
        // collect into a 16,200-cell ContiguousArray, splice each band by index
    }
}
```

Each cell:
1. Approximate sunset JD at (lat, lon) for the d29/d30 evening (±15 min via fast solar algorithm)
2. Compute topocentric Moon + Sun positions at that moment via ported `Equator()`
3. Compute ARCL (angular separation), ARCV (Moon altitude via `Horizon()`), W (crescent width from topocentric distance)
4. Pass to the active criterion's `category(...)`

### 6.4 Caching

Cache key: a stable identifier per criterion combined with `newMoonJD` rounded to 3 decimal places. Both d29 and d30 grids computed together in one TaskGroup invocation and stored in the same cache entry. Cache lives in memory for the app session (`Dictionary<HilalCacheKey, HilalGridPair>` where `HilalGridPair` holds two `ContiguousArray<Int8>` values), bounded to last 6 entries (LRU). No disk cache — recomputing on cold launch is ≤ 30 ms on supported hardware.

### 6.5 Performance budget (per AC-0217)

| Hardware | First grid (cold) | Switch tab (cached) |
|---|---:|---:|
| iPhone 12+ | ≤ 300 ms | < 1 ms |
| Apple Silicon Mac | ≤ 100 ms | < 1 ms |

Below these we pulse-animate the crescent placeholder. Above, we trigger a `Logger.warning(...)` with the elapsed time to detect regressions.

---

## 7. MapKit overlay design

### 7.1 Why MapKit, not SwiftUI Canvas

Decided during 2026-05-10 brainstorm: MapKit's native pan / zoom / pinch / country borders / ocean labels outweigh the equirectangular parity loss with moonsighting.com. Mercator high-latitude stretching is documented in the in-app About card (AC-0242) so users aren't misled.

### 7.2 Overlay strategy — `MKPolygon` per cell

For each non-zero cell in the grid:
- Build an `MKPolygon` with four corners at the cell's lat/lon bounds, using `MKMapPoint` constructed from `CLLocationCoordinate2D`
- Tag the overlay with the category (1–4) via a subclass: `class HilalCellOverlay: MKPolygon { let category: Int8 }`
- Add all overlays to the `MKMapView` via `addOverlays(_:level: .aboveRoads)` so country borders remain crisp on top

### 7.3 Renderer

```swift
func mapView(_ mv: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    guard let cell = overlay as? HilalCellOverlay else { return MKOverlayRenderer() }
    let r = MKPolygonRenderer(polygon: cell)
    r.fillColor = HilalPalette.fill(for: cell.category)
    r.strokeColor = .clear
    r.alpha = HilalPalette.alpha(for: cell.category)
    return r
}
```

### 7.4 Map style

`MKMapType.mutedStandard` in light mode; the dark variant (system-decided on iOS 26 / macOS 26 Liquid Glass) uses `.mutedStandard` with the system's dark colour scheme. Country borders, ocean labels, city labels — all native, no bundled assets.

### 7.5 Performance budget for 16,200 polygons

**Needs empirical validation before Branch 3 starts.** Apple's MapKit documentation does not publish a polygon-overlay frame-budget figure, and 16,200 small polygons is at the higher end of what apps typically render. Pre-implementation spike: add a debug command that loads a synthesised 16,200-cell grid, scroll/zoom interactively on iPhone 12, profile with Instruments. Acceptance gate: ≥ 50 fps during pan and pinch.

If the spike fails on iPhone 12, fall back to `MKTileOverlay` rendering a per-tile CGContext drawn from the underlying `[Int8]` grid. This trades some interactivity (tile redraw on zoom level change) for vastly lower overlay count. Defer that path unless the spike actually fails.

---

## 8. Moon phase preview (PrayerTimesView entry point)

### 8.1 Component

`MoonPhaseView` — a 56×56 SwiftUI Canvas-rendered crescent reflecting the current synodic phase. Renders pixel-by-pixel for accurate terminator curve on any phase. Same renderer is used inside Hilal Watch (consistency, AC-0205).

### 8.2 Integration in PrayerTimesView header row

Replaces the existing single-line Hijri row:

```swift
HStack(alignment: .center, spacing: 12) {
    MoonPhaseView(phase: SettingsManager.shared.currentMoonPhase, size: 56)
    VStack(alignment: .leading) {
        Text(hijriDateFormatted)            // "Sha'ban 28, 1447 AH"
        Text(phaseSubtitle)                  // "Waxing Gibbous · 4d 8h old"
                                             // OR "Hilal Watch tonight" on d29/d30
    }
    Spacer()
    Button("Details") { showHilalWatch = true }
}
.padding(.vertical, 4)
```

### 8.3 macOS NSStatusItem — "Moon Sighting…"

Add a permanent menu item below the existing prayer-times entries:

```swift
let moonItem = NSMenuItem(title: "Moon Sighting…", action: #selector(showHilalWatch), keyEquivalent: "")
moonItem.target = self
menu.addItem(NSMenuItem.separator())
menu.addItem(moonItem)
```

Always visible (not just on watch evenings) — discoverability matters more than minimal UI. Opens the same Hilal Watch panel as the in-app `Details` button.

---

## 9. Hijri month navigation + day offset

### 9.1 Month navigation

`hilalDates(monthOffset: Int) -> (d29: Date, d30: Date)`:

```swift
let referenceJD = NewMoon.searchMoonPhase(
    target: 0,                      // new-moon longitude
    startDate: Date(),
    daysAhead: monthOffset >= 0 ? 60 : -60
)
let monthlyJD = referenceJD + monthOffset * SYNODIC
```

Uses the **real** new-moon JD via Meeus, not arithmetic extrapolation. AC-0226.

### 9.2 Hijri calendar identifier (Settings)

Picker in Settings sheet → "Hijri Calendar":
- Umm Al-Qura (default — current behaviour)
- Islamic Civil
- Islamic Tabular

Stored in `SettingsManager.hijriCalendarIdentifier: String`. Affects which Foundation `Calendar(identifier:)` is used app-wide for Hijri date display.

### 9.3 Day offset (Settings)

Stepper in Settings sheet → "Hijri day offset" (range −2 … +2). Stored as `SettingsManager.hijriDayOffset: Int`.

**Critical separation** (AC-0231):
- The offset shifts displayed labels (PrayerTimesView header, Hilal Watch month label, Hilal Watch tab labels)
- The offset does **NOT** shift the Hilal Watch astronomy. Maps and local-card values are computed from real new-moon JD. The user's offset is purely a label shift to align with what their committee announced.

### 9.4 iCloud KVS sync

Both keys (`hijriCalendarIdentifier`, `hijriDayOffset`) sync via the EPIC-0010 KVS infrastructure. Adds two keys to the existing whitelist.

---

## 10. d29 evening notification

### 10.1 Trigger condition

On each Hijri month rollover, schedule a single notification for the d29 evening — ~30 min before local sunset at the user's `activeCoordinate`.

### 10.2 Computation

```swift
let nextNewMoonJD = NewMoon.searchMoonPhase(target: 0, ...)
let d29SunsetJD = SunPosition.sunsetJD(jd: nextNewMoonJD, lat: ..., lon: ...)
let triggerDate = Date.fromJulianDay(d29SunsetJD - 30.0/(24*60))   // 30 min lead
let request = UNNotificationRequest(identifier: "hilal-watch-\(monthAH)", ...)
center.add(request)
```

`Date.fromJulianDay(_:)` is a small helper added in `IqamahCore/Calendar/JulianDay.swift` (Foundation has no built-in initialiser).

### 10.3 Body content

> "Hilal Watch — B-zone tonight at your location"

The zone letter is computed at schedule time using the user's location and the active criterion. AC-0235.

### 10.4 Re-scheduling

When a notification fires (or on month rollover, whichever comes first), schedule the next month's notification. Reuses the same EPIC-0010 monthly-rollover hook used for prayer notifications.

### 10.5 Deep-link

The notification's `userInfo` contains `["destination": "hilal-watch", "tab": "d29", "monthAH": 1448]`. The app's notification handler (introduced in EPIC-0010) routes this to `ContentView.presentedScreen = .hilalWatch(month: 1448, tab: .d29)`.

---

## 11. Share / export (`MKMapSnapshotter`)

### 11.1 Approach

```swift
let options = MKMapSnapshotter.Options()
options.region = mapView.region
options.size = isHiRes ? CGSize(width: 3072, height: 2304)
                       : CGSize(width: 1024, height: 768)
options.scale = 3.0
let snapshot = try await MKMapSnapshotter(options: options).start()
let composed = compositeOverlays(on: snapshot.image)
let footered = addFooter(composed,
                         text: "Iqamah · Hilal Watch · \(month) \(year) · \(criterion)")
share(footered)
```

`compositeOverlays(on:)` re-projects each cell from grid coordinates to MapKit's snapshot coordinate space and draws the polygon using `CGContext`. Reuses the same colour palette as the live map.

### 11.2 Performance budget (AC-0248)

Hi-res snapshot + composite ≤ 2.5 s on iPhone 12+ / Apple Silicon Mac. Standard ≤ 1.0 s.

---

## 12. UI conventions — Materials + Liquid Glass

Per `CLAUDE.md` § UI Conventions and AC-0249/0250/0251.

### 12.1 Chrome material

```swift
extension View {
    func hilalChrome() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            return self
                .background(.regularMaterial)
                .glassEffect()
        } else {
            return self.background(.regularMaterial)
        }
    }
}
```

Used on: criterion picker, About card, local sighting card, share dialog, info pill (with `.thin` instead of `.regular`).

### 12.2 Light/Dark parity

All views built and screenshotted in **4 variants** before merging — Materials Light, Materials Dark, Liquid Glass Light, Liquid Glass Dark. Map cell fill alpha is tuned per-mode if needed via SwiftUI's platform-neutral `@Environment(\.colorScheme)`:

```swift
struct HilalCellRenderer {
    @Environment(\.colorScheme) private var scheme
    func alpha(for category: Int8) -> CGFloat {
        // Cells are slightly more opaque in dark mode to maintain contrast against
        // MapKit's dark map style; lighter in light mode where the cream land
        // background is busier.
        scheme == .light ? 0.62 : 0.78
    }
}
```

### 12.3 Semantic colours only

`Color.primary`, `Color.secondary`, `.quaternaryLabelColor`. No hardcoded hex values for chrome — only the four cell-category colours (which match the published OmegaHilalSighting palette and are deliberately stable across modes).

---

## 12.4 Accessibility (US-0012 alignment)

- **Map cells** — each `HilalCellOverlay` exposes `accessibilityLabel` of the form "B-zone visibility at 43°N 80°W". Map view as a whole responds to VoiceOver gestures; tapping a cell speaks its label.
- **Local sighting card** — every numeric value (ARCL, ARCV, W, V, category) has a spoken label that includes the unit. Example: "Elongation 12.4 degrees, easily visible naked eye."
- **Moon phase preview** — `accessibilityLabel = "\(phaseName), \(ageDescription)"` — e.g. "Waxing crescent, 22 hours old".
- **Cell colour palette** — A/B/C/D categories are visually distinguished by hue **and** by being labelled with the letter (A, B, C, D) when VoiceOver focus lands on a cell. Never colour-only.
- **Dynamic Type** — local sighting card and About card use `.font(.body)` / `.font(.callout)` — semantic sizes that scale. Map cells are fixed-size by definition.
- **Contrast** — chrome contrast verified per AC-0250 against WCAG 2.1 AA in all four variants. Cell colour palette is identical in light and dark; the alpha per-mode (Section 12.2) is tuned so contrast against the underlying MapKit style stays ≥ 3:1 for the smallest visible text overlay.

---

## 12.5 Internationalisation readiness

Full app-wide multilingual support is tracked separately as **ENH-0019** (see `docs/ENHANCEMENTS.md`). EPIC-0011 does **not** include translations, but it must be **i18n-ready** so ENH-0019 only needs to add translations, not refactor:

- Every user-visible string in Hilal Watch goes through `String(localized:)` (Swift 5.7+) — no hardcoded English `Text("…")` literals in any view.
- Hijri month names are sourced from Foundation's `Calendar(identifier:)` localisation — no hardcoded English month names.
- Numbers (degrees, arcminutes, V-score) are formatted via `Measurement.FormatStyle` / `Number.FormatStyle` so locale formatting is automatic when ENH-0019 lands.
- The notification body uses a parametric format string with the zone letter as `%@` — when ENH-0019 lands, only the format string needs translating, not the formatting logic.
- All horizontal layouts use SwiftUI `HStack` (which respects `Locale.LanguageDirection`) — RTL works out of the box once translations are added.
- `MoonPhaseView` does **not** flip in RTL (astronomy is direction-neutral); the Hilal map does **not** flip (geography is fixed). Both are documented as RTL-exempt in the renderer comments.

**Net effect:** when ENH-0019 ships, Hilal Watch becomes multilingual with no view-layer rework — only `Localizable.xcstrings` additions and review.

---

## 12.6 Error handling

| Failure | Behaviour |
|---|---|
| `NewMoon.searchMoonPhase` returns nil (search beyond range) | Hilal Watch shows a "No new moon found within ±60 days" empty state. Should never happen for sensible month offsets. Logged to `Logger.error`. |
| `Equator()` returns NaN at extreme latitudes | Cell category set to `0` (not visible). Logged once per session per coordinate via a deduping logger. |
| `MKMapSnapshotter.start()` throws | Share dialog shows a retry button with the underlying error. No crash. |
| MapKit overlay renderer fails to draw | The renderer returns a plain `MKOverlayRenderer()` (transparent). User sees missing cells; a single `Logger.error` records the failure. Never crash. |
| `UNUserNotificationCenter` permission denied | The "Notify me on Hilal Watch evening" toggle in settings shows "Notifications disabled — open Settings" with a button that links to the system settings. Toggle is otherwise inert. |
| iCloud KVS sync rejects a key | Per EPIC-0010 — local writes still succeed; the next push retries. No user-visible error. |
| Astronomy port precision regression detected by ICOP regression tests | CI fails. Branch cannot merge. No user-visible failure mode (caught before ship). |

Recovery principle: Hilal Watch should always show **something** even when astronomy or rendering fails. Never block the prayer-times screen. Never crash the app.

---

## 13. File layout

### Added in `IqamahCore`

```
IqamahCore/Sources/IqamahCore/
  Astronomy/
    MoonPosition.swift          — Meeus longitude/latitude/distance series + Equator()
    SunPosition.swift           — solar position + sunsetJD()
    NewMoon.swift               — searchMoonPhase()
    Coordinates.swift           — Horizon(), separation()
    VisibilityCriterion.swift   — protocol + Odeh / Yallop / HMNAO conformances
                                  (single file — total < 300 LOC)
    HilalCalculator.swift       — grid + local card
  Calendar/
    HijriCalendar.swift         — identifier + offset wrapper
    JulianDay.swift             — Date ↔ JD helpers (Date.fromJulianDay etc.)
  Resources/
    (no new files — all logic, no assets)
IqamahCore/Tests/IqamahCoreTests/
  AstronomyTests.swift
  HilalCalculatorTests.swift
  ICOPRegressionTests.swift
```

### Added in macOS / iOS targets

```
iqamah/Views/HilalWatch/
  HilalWatchView.swift
  HilalMapView.swift             — wraps MKMapView via NSViewRepresentable / UIViewRepresentable
  HilalCellOverlay.swift         — MKPolygon subclass
  LocalSightingCardView.swift
  MoonPhaseView.swift             — shared with PrayerTimesView header
  AboutHilalWatchCard.swift
  HilalCriterionPicker.swift
  HilalSettings.swift             — additions to Settings sheet
  HilalShareSheet.swift           — MKMapSnapshotter + composite
```

The two platform targets ideally share these files via Xcode group membership. Where AppKit/UIKit differs (e.g. share sheet, status bar menu), `#if os(macOS)` branches inside the same file rather than separate files.

### Modified existing files

- `iqamah/Views/PrayerTimesView.swift` — Hijri row replaced with moon phase preview + Details button (Section 8.2)
- `iqamah/AppDelegate.swift` (macOS) — "Moon Sighting…" menu item (Section 8.3)
- `iqamah/Services/SettingsManager.swift` — new keys: `hijriCalendarIdentifier`, `hijriDayOffset`, `selectedCriterion`, `hilalNotificationEnabled`. Add to iCloud KVS whitelist (Section 9.4).
- `iqamah-iOS/NotificationDeepLink.swift` (added in EPIC-0010) — handle `destination: hilal-watch`.

---

## 14. Out of scope (v1)

- **Apple Watch complication** — defer to a separate epic alongside the larger watchOS port (ENH-0016)
- **macOS Notification Center widget** — defer to ENH-0004 (existing enhancement)
- **visionOS 3D moon volume** — premature; revisit after a v1 visionOS app exists
- **Automated cross-reference against moonsighting.com's published maps as a CI test** — manual QA only for v1; their HTML is unstable to scrape
- **Real-time crescent-age countdown** — the static "tonight" label is sufficient
- **Historical observation database** (recording where users actually sighted the crescent) — interesting for v2; cleanly out of scope for v1
- **Crescent visibility for Mars / Venus / etc.** — comedy

---

## 15. Open questions

1. **Yallop / HMNAO coefficient verification** — ✅ Resolved 2026-05-10: all three criteria ship in v1. Coefficient sourcing is the implementation plan's Task 1.0, blocking Branch 1 closure until ≥ 2 authoritative sources reconcile per criterion.
2. **Hijri offset display when crossing month boundaries** — ✅ Resolved 2026-05-10: no special-casing. If user offsets +1 and the underlying date is the last day of the month, the displayed label rolls over — that's exactly what offsetting means.
3. **macOS window mode for Hilal Watch** — ✅ Resolved 2026-05-10: separate panel window via SwiftUI `Window` scene + `WindowResizability.contentSize`, default 720×640. Doesn't fight the main 580×640 window.
4. **First-launch About card auto-display** — ✅ Resolved 2026-05-10: peek-through. The map computes in the background and the About card slides up over a partially-rendered map; users can dismiss any time.
5. **Notification permission already granted via EPIC-0010?** — ⏳ To verify at Branch 5 kickoff. EPIC-0010 introduces the permission flow for prayer notifications; Hilal Watch reuses the same `UNUserNotificationCenter` handle. We don't want a second permission prompt for Hilal Watch.
6. **AC-0245 share dialog UI on macOS** — ✅ Resolved 2026-05-10: small pre-share dialog with the resolution toggle, then invoke `NSSharingServicePicker` with the chosen resolution.
7. **Performance benchmark methodology** — ✅ Resolved 2026-05-10: XCTest performance test running `HilalCalculator.computeGrid` 100× on a known date in a representative criterion, measuring p50 / p95.
8. **MapKit polygon-overlay scaling spike** — ⏳ To execute at Branch 3 kickoff. Hardware: iPhone XR (oldest accessible) for a conservative gate of ≥ 30 fps; Mobitru iPhone 12 for the AC-0217 reference gate of ≥ 50 fps. If either fails, pivot to `MKTileOverlay` (Branch 3 Task 3.7).
9. **Arabic / multilingual rollout** — ✅ Resolved 2026-05-10: handled by ENH-0019 (App-wide Multilingual Support), not in EPIC-0011 scope. EPIC-0011 only commits to being i18n-ready (§12.5).
10. **Cell `accessibilityLabel` density** — ✅ Resolved 2026-05-10: VoiceOver labels exposed only at MapKit zoom level ≥ 4. At lower zoom levels the map view as a whole has a single summary label ("Hilal visibility map for [Month] [Year], [N] regions visible").

---

## 16. AC reference (cross to RELEASE_PLAN.md)

| Section | ACs |
|---|---|
| §4 Astronomy port | (validation: implicit in AC-0222) |
| §5 Visibility criteria | AC-0238, 0239, 0240, 0241, 0242, 0243 |
| §6 Grid + caching | AC-0210, 0211, 0212, 0217, 0218 |
| §7 MapKit overlay | AC-0210, 0212, 0213, 0214, 0215, 0216, 0219, 0220 |
| §8 Moon preview + entry points | AC-0204, 0205, 0206, 0207, 0208, 0209 |
| §9 Hijri navigation + offset | AC-0226, 0227, 0228, 0229, 0230, 0231, 0232 |
| §10 Notification | AC-0233, 0234, 0235, 0236, 0237 |
| §11 Share / export | AC-0244, 0245, 0246, 0247, 0248 |
| §12 UI conventions | AC-0249, 0250, 0251 |
| §12.4 Accessibility | AC-0060 – AC-0065 (existing US-0012 contract; Hilal Watch must comply) |
| §12.5 Internationalisation readiness | (translations themselves: ENH-0019) |
| §12.6 Error handling | implicit — no user-visible crashes or hangs |
| §local sighting card | AC-0221, 0222, 0223, 0224, 0225 |

---

## 17. Implementation plan

See `docs/superpowers/plans/2026-05-10-hilal-watch-implementation.md` for the full 5-branch staged plan.

1. **Astronomy port + 3 criteria + tests** (IqamahCore-only, no UI) — 2 weeks
2. **HilalCalculator + grid + caching** — 1 week
3. **macOS HilalWatchView + map + local card + criterion picker + About card** — 2 weeks
4. **Entry-point integration: PrayerTimesView moon preview, NSStatusItem menu, Hijri offset settings, share** — 1 week
5. **iOS-side wiring + d29 notification + KVS sync of new keys** — 1 week

**Total estimate:** 7 weeks, with Branch 1 starting in parallel to EPIC-0010 (~2026-05-17 merge target). Calendar projection: EPIC-0011 v1 ready ~2026-06-28.

---

**Last Updated:** 2026-05-10 (Draft — open questions 1, 2, 3, 4, 6, 7, 9, 10 resolved; questions 5 and 8 still pending — to verify at Branch 5 / Branch 3 kickoff respectively)
