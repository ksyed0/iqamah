# EPIC-0011 — Hilal Watch Implementation Plan
**Date:** 2026-05-10
**Status:** Draft — under review
**Spec:** `docs/superpowers/specs/2026-05-10-hilal-watch-design.md`
**Scope:** EPIC-0011 (US-0046 – US-0052, AC-0204 – AC-0251)
**Dependency:** EPIC-0010 (iOS conversion) must land first; Branch 1 may begin earlier if `IqamahCore` exists.

---

## Decisions (from 2026-05-10 brainstorm + spec review + product-owner answers)

| Question | Decision |
|---|---|
| Map renderer | MapKit `MKPolygon` overlays per cell, fallback `MKTileOverlay` if perf spike fails |
| Position engine | Direct Swift port of astronomy-engine v2 subset, no SwiftAA dependency |
| UI chrome | SwiftUI `Material` with `.glassEffect()` Liquid Glass via `@available(iOS 26, macOS 26, *)` |
| Hijri offset crossing month | No special-casing; offset is purely a label shift |
| macOS window | Separate panel window (SwiftUI `Window` scene + `WindowResizability.contentSize`) |
| First-launch About card | Peek-through (map renders behind) |
| Share dialog UX (macOS) | Pre-share resolution toggle dialog → `NSSharingServicePicker` |
| Perf benchmark | XCTest performance test, p50/p95 over 100 runs of `computeGrid` |
| Cell a11y density | VoiceOver labels exposed only at zoom level ≥ 4 |
| Multilingual | i18n-ready only in v1 (`String(localized:)` everywhere); translations in ENH-019 |
| **Visibility criteria scope (v1)** | **All three: Odeh (2004), Yallop (1997), HMNAO Enhanced. Coefficient verification is a Branch 1 prerequisite (Task 1.0).** |
| **EPIC-0010 merge ETA** | **~1 week from 2026-05-10 (target: 2026-05-17). Branch 1 may start in parallel; Branches 2-5 unblock at merge.** |
| **MapKit polygon spike hardware** | **Primary: iPhone XR (oldest accessible, sets conservative gate). Verification: Mobitru iPhone 12 (matches AC-0217 reference hardware).** |

---

## Branch overview

```
                          (depends on EPIC-0010)
                                   │
   Branch 1                Branch 2                Branch 3
  ┌─────────┐            ┌─────────┐             ┌─────────┐
  │ Astro   │ ────────►  │ Hilal   │ ─────────►  │ macOS   │
  │ port +  │            │ Calc    │             │ View +  │
  │ tests   │            │ + cache │             │ Map +   │
  │         │            │         │             │ Local   │
  └─────────┘            └─────────┘             └─────────┘
       │                       │                      │
       │                       │                      ▼
       │                       │                ┌─────────┐
       │                       │                │ Perf    │
       │                       │                │ spike   │ (gate before
       │                       │                └─────────┘  Branch 4)
       │                       │                      │
       │                       │                      ▼
       │                       │                ┌─────────┐
       │                       │                │ Branch  │
       │                       │                │   4     │
       │                       │                │ entry + │
       │                       │                │ share   │
       │                       │                └─────────┘
       │                       │                      │
       │                       │                      ▼
       │                       │                ┌─────────┐
       │                       │                │ Branch  │
       │                       │                │   5     │
       │                       │                │ iOS +   │
       │                       │                │ notif   │
       │                       │                └─────────┘
```

---

## Branch 1 — Astronomy port + 3 criteria + tests

**Goal:** Land a precision-validated astronomy module in `IqamahCore` plus all three visibility criteria (Odeh / Yallop / HMNAO). UI-free, internal-only.

**Branch name:** `feat/EPIC-0011-1-astronomy-port`
**Base:** `develop` (or whichever branch contains `IqamahCore` once EPIC-0010 lands)
**Estimated effort:** 2 weeks (mechanical port + extensive validation + multi-source coefficient sourcing for Yallop/HMNAO)
**Risk:** Medium-High — astronomy port precision is non-negotiable (ICOP regression suite is merge gate); coefficient sourcing for Yallop and HMNAO requires reconciling at least two authoritative sources per criterion (Task 1.0).

### Tasks

- **1.0** **Pre-task: Coefficient sourcing.** Locate authoritative Yallop and HMNAO threshold coefficients before Task 1.7 begins. Sources to reconcile (need at least two):
  - Yallop, B.D. (1997) "A Method for Predicting the First Sighting of the New Crescent Moon", NAO Technical Note No. 69 (HMNAO)
  - HMNAO Astronomical Information Sheet — current edition crescent visibility section
  - Cross-check via [crescent-moon-visibility](https://github.com/crescent-moon-visibility/crescent-moon-visibility) (MIT) source code
  - Cross-check via Odeh (2004) Appendix A which restates Yallop's coefficients for comparison purposes
  - Commit a JSON fixture `IqamahCore/Tests/IqamahCoreTests/Fixtures/criterion-coefficients-references.json` recording each source's values + citation. **Branch 1 cannot close until this fixture exists and the values reconcile.**
- **1.1** Create `IqamahCore/Sources/IqamahCore/Astronomy/` module structure
- **1.2** Add `Calendar/JulianDay.swift` with `Date.fromJulianDay(_:)` / `julianDay()` helpers
- **1.3** Port `MoonPosition.swift` — Meeus longitude/latitude/distance series + `Equator()`. Direct translation of astronomy-engine v2 `astronomy.js` lines covering `Body.Moon`. ~250 LOC.
- **1.4** Port `SunPosition.swift` — solar coordinates + `sunsetJD()` (fast, ±15 min approximation per spec §6.3)
- **1.5** Port `NewMoon.swift` — `searchMoonPhase(target:startDate:daysAhead:)`. ~80 LOC.
- **1.6** Add `Coordinates.swift` — `Horizon()`, `separation()`, `crescentWidthArcmin(arcl:distanceKm:)`. ~50 LOC.
- **1.7** Add `VisibilityCriterion.swift` — protocol + **all three conformances** (`OdehCriterion`, `YallopCriterion`, `HMNAOCriterion`). Coefficients sourced via Task 1.0. ~300 LOC total.
- **1.8** Add `IqamahCore/Tests/IqamahCoreTests/AstronomyTests.swift` — unit tests against astronomy-engine JS test fixtures. ±0.001° tolerance on RA/Dec for Sun + Moon over 50 sample (date, location) pairs.
- **1.9** Add `ICOPRegressionTests.swift` — replay 737 ICOP observations through `OdehCriterion`; assert published true-positive / true-negative rates. **Merge-blocking.**
- **1.10** Add `CriticalPeriodTests.swift` — for the most recent 24 months published by moonsighting.com, compute V values for ~20 sample locations and assert ±0.5° vs reference table. (Reference data committed as JSON fixture.)
- **1.11** Add `CriterionConsistencyTests.swift` — for ~50 (date, location) pairs spanning the visibility spectrum, assert that Odeh / Yallop / HMNAO produce expected ordering of categories (Yallop is conservatively at-or-below Odeh; HMNAO is at-or-above Yallop).

### Files added
```
IqamahCore/Sources/IqamahCore/Astronomy/
  MoonPosition.swift
  SunPosition.swift
  NewMoon.swift
  Coordinates.swift
  VisibilityCriterion.swift             — protocol + Odeh + Yallop + HMNAO
IqamahCore/Sources/IqamahCore/Calendar/
  JulianDay.swift
IqamahCore/Tests/IqamahCoreTests/
  AstronomyTests.swift
  ICOPRegressionTests.swift
  CriticalPeriodTests.swift
  CriterionConsistencyTests.swift
  Fixtures/icop-observations.json
  Fixtures/moonsighting-2024-2025.json
  Fixtures/criterion-coefficients-references.json
```

### Test gates
- ✅ Task 1.0 coefficient-references fixture exists with ≥ 2 reconciled sources per criterion
- ✅ All `AstronomyTests` pass with ±0.001° tolerance
- ✅ All `ICOPRegressionTests` pass (100% A-zone hit, 0% D-zone hit per Odeh 2004)
- ✅ All `CriticalPeriodTests` pass (±0.5° vs moonsighting.com reference)
- ✅ All `CriterionConsistencyTests` pass (Yallop ≤ Odeh; HMNAO ≥ Yallop)
- ✅ `swift test` runs in < 30 s for the full IqamahCore suite
- ✅ Code coverage ≥ 90% on the new files

### ACs covered
- (validation underlies AC-0222 — local card values match moonsighting.com to ±0.5°)
- AC-0218 (TaskGroup parallelism — protocol established, used in Branch 2)
- AC-0238 (criteria available — Odeh / Yallop / HMNAO all conform to protocol)
- AC-0240 (criterion swap reuses upstream astronomy)

---

## Branch 2 — HilalCalculator + grid + caching

**Goal:** Land the grid-computation engine on top of Branch 1's astronomy, with parallel TaskGroup execution and an LRU memory cache. Still UI-free.

**Branch name:** `feat/EPIC-0011-2-hilal-calculator`
**Base:** Branch 1 merged into `develop` (and EPIC-0010 must be on `develop` since this branch needs `IqamahCore` extensions Branch 1 cannot mock)
**Estimated effort:** 1 week
**Risk:** Low — pure compute layer, well-defined inputs/outputs. Yallop/HMNAO criterion implementations already landed in Branch 1.

### Tasks

- **2.1** Add `HilalCalculator.swift` with the public API:
  - `func computeGrid(_ req: HilalGridRequest) async -> ContiguousArray<Int8>`
  - `func computeLocalCard(date: Date, lat: Double, lon: Double, criterion: any VisibilityCriterion) -> LocalSightingValues`
- **2.2** Implement parallel TaskGroup over latitude bands per spec §6.3
- **2.3** Implement `HilalCacheKey` + LRU cache (max 6 entries; in-memory only)
- **2.4** Add `Evening` enum (`.d29`, `.d30`) and `HilalGridRequest` struct
- **2.5** Add `HilalCalculatorTests.swift` — performance test asserting ≤ 30 ms on Apple Silicon Mac, ≤ 300 ms on iPhone 12 (skipped on CI hardware that doesn't match)
- **2.6** Add `HilalCalculatorTests.testGridContent` — for a known new-moon date, sample 50 cells across the grid and assert their categories match a hand-computed reference fixture
- **2.7** Add per-criterion grid fixtures: same date / different criterion → different grids. Asserts the criterion-swap pathway is correctly wired through to `HilalCalculator` (cells differ where expected, identical where the criterion thresholds don't disagree).
- **2.8** Performance benchmark XCTest (per decision in §Decisions): p50/p95 over 100 runs

### Files added
```
IqamahCore/Sources/IqamahCore/Astronomy/
  HilalCalculator.swift
  HilalCacheKey.swift
IqamahCore/Tests/IqamahCoreTests/
  HilalCalculatorTests.swift
  Fixtures/grid-reference-1448-ramadan-odeh.json
  Fixtures/grid-reference-1448-ramadan-yallop.json
  Fixtures/grid-reference-1448-ramadan-hmnao.json
```

### Test gates
- ✅ Performance test asserts compute budget per spec §6.5
- ✅ Cache hit rate test: switch evenings 100 times, assert no recomputation after first
- ✅ Grid content test passes (50/50 cells match reference)

### ACs covered
- AC-0211 (cache + tab switching is instant)
- AC-0212 (16,200-cell grid)
- AC-0217 (compute budget)
- AC-0218 (parallel TaskGroup)
- AC-0240 (criterion swap reuses astronomy)
- AC-0221 (local card values)
- AC-0222 (within ±0.5° of moonsighting.com — final validation)

---

## Branch 3 — macOS Hilal Watch view + map + local card + criterion picker + About

**Goal:** Land the macOS Hilal Watch UI on top of `HilalCalculator`. Standalone panel window. No PrayerTimesView integration, no notifications, no share — those come in later branches.

**Branch name:** `feat/EPIC-0011-3-macos-view`
**Base:** Branch 2 merged into `develop` (and EPIC-0010 must be on `develop`)
**Estimated effort:** 2 weeks
**Risk:** Medium — depends on MapKit polygon-overlay performance spike (gate item 3.0).

### Tasks

- **3.0** **Pre-task: MapKit polygon spike.** Add a debug menu command "Hilal Spike" that loads a synthesised 16,200-cell grid and renders it as `MKPolygon` overlays on a `MKMapView`. Profile pan/zoom on **iPhone XR** (oldest accessible hardware — sets a conservative gate) plus a **Mobitru iPhone 12** session to verify against AC-0217's reference hardware. **Acceptance gate:** ≥ 50 fps on iPhone 12 (Mobitru), ≥ 30 fps on iPhone XR (acceptable for the 4-year-older device). If failed on either, pivot to `MKTileOverlay` strategy in 3.7. Document spike results (instrument traces + frame-rate measurements) in branch description.
- **3.1** Create `iqamah/Views/HilalWatch/` directory and group it in Xcode
- **3.2** `HilalCellOverlay.swift` — `MKPolygon` subclass with `category: Int8`
- **3.3** `HilalMapView.swift` — `NSViewRepresentable` wrapping `MKMapView`. Renderer applies `HilalPalette.fill / alpha`. Mercator projection accepted; mutedStandard map type.
- **3.4** `HilalPalette.swift` — colour values for A/B/C/D categories per spec §6 + alpha computation per `@Environment(\.colorScheme)`
- **3.5** `LocalSightingCardView.swift` — displays ARCL/ARCV/W/V + category badge + scale bar per spec §local card
- **3.6** `MoonPhaseView.swift` — SwiftUI Canvas crescent renderer (used here, integrated into PrayerTimesView in Branch 4)
- **3.7** Conditional: if 3.0 spike failed, replace 3.2/3.3 with `HilalTileOverlay.swift` rendering per-tile CGContext from `[Int8]` grid
- **3.8** `HilalCriterionPicker.swift` — segmented picker (Odeh / Yallop / HMNAO — all three from Branch 1)
- **3.9** `AboutHilalWatchCard.swift` — peek-through modal with S-curve explanation + criterion explanations per spec §6
- **3.10** `HilalWatchView.swift` — top-level layout: header (title + criterion picker + (i) info pill + share button), tab selector (29th / 30th), map, local card. Wires up state.
- **3.11** Add `HilalWatchWindow.swift` — SwiftUI `Window` scene declaration in `iqamahApp.swift` for separate panel window, default size 720×640.
- **3.12** Add accessibility labels per spec §12.4: cells via `accessibilityLabel`, scale bar with screen-reader friendly text, MoonPhaseView with phase name + age.
- **3.13** Verify in 4 variants: Materials Light, Materials Dark, Liquid Glass Light, Liquid Glass Dark. Screenshot each. Attach to PR.
- **3.14** XCUITest covering: open Hilal Watch, switch tabs, change criterion, open About, close.

### Files added
```
iqamah/Views/HilalWatch/
  HilalWatchView.swift
  HilalMapView.swift
  HilalCellOverlay.swift
  HilalPalette.swift
  HilalCriterionPicker.swift
  LocalSightingCardView.swift
  MoonPhaseView.swift
  AboutHilalWatchCard.swift
iqamah/HilalWatchWindow.swift
iqamahUITests/HilalWatchUITests.swift
```

### Files modified
```
iqamah/iqamahApp.swift              — add Window scene
```

### Test gates
- ✅ MapKit polygon spike (3.0) resolved with documented result
- ✅ XCUITest passes
- ✅ All 4 chrome variants reviewed and screenshotted
- ✅ VoiceOver navigation through Hilal Watch produces sensible labels (manual QA)
- ✅ No new SwiftLint warnings

### ACs covered
- AC-0210, AC-0211, AC-0213, AC-0214, AC-0215, AC-0216, AC-0219, AC-0220 (map)
- AC-0212 (cells; via 3.2 or 3.7 depending on spike)
- AC-0221, AC-0223, AC-0224, AC-0225 (local card)
- AC-0238, AC-0239 (criterion picker — all three options)
- AC-0242, AC-0243 (About card)
- AC-0249, AC-0250, AC-0251 (Materials + Liquid Glass + dark/light)

---

## Branch 4 — Entry-point integration + Hijri offset settings + share

**Goal:** Surface Hilal Watch from PrayerTimesView and the macOS status menu. Add Hijri calendar identifier picker and day offset stepper to Settings. Add share dialog with hi-res export.

**Branch name:** `feat/EPIC-0011-4-entry-and-share`
**Base:** Branch 3 merged into `develop`
**Estimated effort:** 1 week
**Risk:** Low — wiring + share flow.

### Tasks

- **4.1** Modify `PrayerTimesView.swift` — replace single-line Hijri row with `MoonPhaseView` (56×56) + phase subtitle + `[ Details ]` button per spec §8.2
- **4.2** Add "Hilal Watch tonight" detection — d29/d30 of current Hijri month determined by comparing `Date()` against most recent / next new-moon JD
- **4.3** Modify `AppDelegate.swift` (macOS) — add `NSMenuItem("Moon Sighting…")` to status menu. Action opens HilalWatch window via app delegate notification.
- **4.4** Modify `SettingsManager.swift`:
  - Add `hijriCalendarIdentifier: String` (default: `umm-al-qura`)
  - Add `hijriDayOffset: Int` (default: `0`, range −2…+2)
  - Add `selectedCriterion: String` (default: `odeh`)
  - Add `hilalNotificationEnabled: Bool` (default: `false`)
  - Add all four to iCloud KVS whitelist
- **4.5** Modify Settings sheet view (existing) to add:
  - "Hijri Calendar" picker (Umm Al-Qura / Civil / Tabular)
  - "Hijri day offset" stepper
  - "Notify me on Hilal Watch evening" toggle (no behaviour wired yet — that's Branch 5)
- **4.6** Verify offset shifts displayed Hijri labels app-wide (PrayerTimesView header, Hilal Watch month label) but NOT astronomy
- **4.7** Add `HilalShareSheet.swift` — pre-share resolution toggle dialog → `NSSharingServicePicker` (macOS). iOS uses `UIActivityViewController` — wired in Branch 5.
- **4.8** Implement `MKMapSnapshotter` + composite + footer per spec §11
- **4.9** XCUITest: open Settings, change calendar identifier, verify Hijri date display updates; open share, select hi-res, verify resulting image dimensions.

### Files added
```
iqamah/Views/HilalWatch/HilalShareSheet.swift
```

### Files modified
```
iqamah/Views/PrayerTimesView.swift           — moon phase preview + Details button
iqamah/AppDelegate.swift                     — Moon Sighting menu item
iqamah/Services/SettingsManager.swift        — new keys + KVS whitelist
iqamah/Views/SettingsSheetView.swift         — new picker / stepper / toggle (file path TBD)
iqamah/iqamahApp.swift                       — Hilal Watch window opens via menu action
```

### Test gates
- ✅ Hijri offset XCTest: change offset to +1, assert displayed date shifts, assert grid astronomy unchanged
- ✅ Share XCUITest: hi-res export produces 3072×2304 PNG
- ✅ KVS sync XCTest: write a key, simulate remote update, assert local merge

### ACs covered
- AC-0204, AC-0205, AC-0206, AC-0207, AC-0208 (PrayerTimesView entry)
- AC-0209 (NSStatusItem menu item)
- AC-0226, AC-0227, AC-0228 (existing month nav from Branch 3, now data-bound)
- AC-0229, AC-0230, AC-0231, AC-0232 (Hijri identifier + offset + sync)
- AC-0241 (criterion persisted)
- AC-0244, AC-0245, AC-0246, AC-0247, AC-0248 (share)

---

## Branch 5 — iOS-side wiring + d29 notification + KVS sync

**Goal:** Make Hilal Watch work on iOS. Wire up the d29 evening notification and deep-link routing. Wire share sheet through `UIActivityViewController`.

**Branch name:** `feat/EPIC-0011-5-ios-and-notification`
**Base:** Branch 4 merged into `develop`
**Estimated effort:** 1 week
**Risk:** Medium — depends on EPIC-0010's notification scheduling and deep-link infrastructure being correctly in place.

### Tasks

- **5.1** Verify the views from Branch 3 compile and run on iOS. Branch 3 was developed against the macOS target; some `NSViewRepresentable` references need to become `UIViewRepresentable` via `#if os(iOS)`. SwiftUI views should be cross-platform unchanged.
- **5.2** Add `iqamah-iOS/Views/HilalWatch/HilalWatchSheet.swift` (or similar) — the iOS presentation is a sheet on `PrayerTimesView`, not a separate window
- **5.3** Modify `iqamah-iOS/NotificationDeepLink.swift` (added in EPIC-0010) — handle `destination: hilal-watch` per spec §10.5
- **5.4** Add `HilalNotificationScheduler.swift` to `IqamahCore/Sources/IqamahCore/`:
  - `func scheduleNextWatchEvening(criterion:location:) async`
  - On d29 sunset −30 min, schedule a `UNNotificationRequest` per spec §10.2
  - On notification fire OR Hijri month rollover hook (from EPIC-0010), call self again
- **5.5** Wire `hilalNotificationEnabled` toggle (from Branch 4) to enable/disable scheduling
- **5.6** Permission flow: if `UNUserNotificationCenter.authorizationStatus == .notDetermined` when toggle is enabled, prompt; if `.denied`, show "Notifications disabled — open Settings" link per spec §12.6
- **5.7** Re-share via `UIActivityViewController` on iOS
- **5.8** XCUITest: enable toggle, simulate notification fire, assert deep-link opens Hilal Watch on d29 tab
- **5.9** Final cross-device sync test: change criterion on Mac, observe iOS settings update via iCloud KVS

### Files added
```
IqamahCore/Sources/IqamahCore/HilalNotificationScheduler.swift
iqamah-iOS/Views/HilalWatch/HilalWatchSheet.swift   (if not shared with macOS)
iqamah-iOS/HilalWatchUITests/HilalNotificationUITests.swift
```

### Files modified
```
iqamah-iOS/NotificationDeepLink.swift    — handle hilal-watch destination
iqamah-iOS/AppDelegate.swift              — wire HilalNotificationScheduler
iqamah-iOS/Views/HilalWatch/HilalShareSheet.swift  — UIActivityViewController branch
```

### Test gates
- ✅ Notification scheduling XCUITest passes
- ✅ Deep-link XCUITest passes
- ✅ KVS sync XCUITest passes (Mac → iOS)
- ✅ All views render correctly on iPhone (5 device variants: iPhone SE 3 / iPhone 13 / iPhone 14 Pro / iPhone 16 Pro Max / iPad Pro 13)
- ✅ All Branch 3 a11y gates re-verified on iOS

### ACs covered
- AC-0233, AC-0234, AC-0235, AC-0236, AC-0237 (notification)
- AC-0240 (criterion swap on iOS — already in Branch 2/3 but verified end-to-end here)
- All Branch 3-4 ACs re-verified on iOS
- AC-0244, AC-0245, AC-0246, AC-0247, AC-0248 (iOS share branch)

---

## Cross-branch concerns

### Performance regression CI
Branch 1 introduces `IqamahCorePerformanceTests.testAstronomyEquatorPerformance`. Branch 2 introduces `HilalCalculatorTests.testGridComputePerformance`. These run on every PR via the existing CI (which currently runs unit tests). Branch threshold:
- `testAstronomyEquatorPerformance`: median ≤ 50 µs per `Equator()` call (CI hardware: GitHub Actions macOS-14 runner)
- `testGridComputePerformance`: median ≤ 60 ms for full grid compute on CI hardware (slower than iPhone 12 because GitHub runners aren't dedicated)

Crossing thresholds fails the PR. Tighten thresholds across branches if measurements show consistent headroom.

### App-bundle size budget
Each branch must keep the macOS Release `.app` bundle under the existing 50 MB CI gate. Astronomy port adds ~10 KB. MapKit overlay rendering adds nothing. Hi-res share rendering uses runtime memory only.

### Documentation per branch
Every branch's PR must update:
- `RELEASE_PLAN.md` — mark relevant ACs `[x]` as they ship
- `TEST_CASES.md` — add TC entries (TC-0036 onwards) for new ACs once promoted

### Rollback plan
If Branch 3's MapKit polygon spike fails and the `MKTileOverlay` fallback also performs poorly, defer Branch 3 entirely and fall back to a non-interactive bundled-PNG map (rejected option from §7.1). This is a v1.5 path, not preferred. Pre-emptively mitigated by the spike in 3.0 happening before Branch 3 view code commits.

### What NOT to do
- Do not bundle astronomy-engine v2 as a Swift package dependency. Direct port only. (Per spec §4.3.)
- Do not bump iOS / macOS deployment target above 17 / 14. Liquid Glass features must be `@available(iOS 26, macOS 26, *)` branches.
- Do not change `cities.json` schema or contents. Hilal Watch uses the user's existing `activeCoordinate`, no city-database changes.
- Do not add disk persistence to the grid cache. Memory-only LRU; cold launch recomputes.

---

## Estimated total

| Branch | Effort |
|---|---:|
| 1. Astronomy port + 3 criteria + tests | 2 weeks (was 1.5 — added Yallop/HMNAO + coefficient sourcing) |
| 2. HilalCalculator + grid | 1 week |
| 3. macOS view + map | 2 weeks |
| 4. Entry + share | 1 week |
| 5. iOS + notification | 1 week |
| **Total** | **7 weeks** |

Adds ~1 week of buffer for the MapKit polygon spike resolution and any criterion-coefficient ambiguity discovered during Task 1.0.

---

## Sequencing with EPIC-0010

```
[ EPIC-0010 in flight ] (lands ~2026-05-17, 1 week from now)
        │
        ├── Branch 1 (Astronomy port + 3 criteria) starts in parallel ────┐
        │                                                                 │
        ▼                                                                 ▼
[ EPIC-0010 lands on develop ~2026-05-17 ]               [ Branch 1 ready ~2026-05-24 ]
        │                                                                 │
        └────────────────────────────┬────────────────────────────────────┘
                                     ▼
                           [ Branches 2-5 sequential, ~5 weeks ]
                                     │
                                     ▼
                          [ EPIC-0011 v1 ready ~2026-06-28 ]
```

Calendar projection assuming EPIC-0010 lands on schedule: EPIC-0011 v1 ready in ~7 weeks (2026-06-28). Branch 1 is the only parallel work; everything else is strictly sequential after EPIC-0010 merges.

---

## Open implementation-time decisions

1. **MapKit spike result determines Branch 3 path** — `MKPolygon` (Task 3.2/3.3) vs `MKTileOverlay` (Task 3.7). Resolved during Task 3.0; both iPhone XR (≥30 fps) and Mobitru iPhone 12 (≥50 fps) gates must pass for the `MKPolygon` path.

---

**Last Updated:** 2026-05-10 (Draft — incorporating product-owner answers: all three criteria in v1, EPIC-0010 ~2026-05-17, hardware iPhone XR + Mobitru iPhone 12)
