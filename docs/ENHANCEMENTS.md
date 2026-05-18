# Iqamah — Future Enhancements

Logged from competitive analysis (May 2026) and product research. Items are grouped by theme, not priority. See competitive-analysis.md for the feature gap matrix these derive from.

**Implementation status as of 2026-05-11:**
- ENH-015 (iPhone/iPad) → ✅ Implemented as EPIC-0010 (PRs #56–60)
- ENH-016 (Apple Watch) → ✅ Implemented as EPIC-0012 (PR #67)
- ENH-018 (Hilal Watch) → ✅ Implemented as EPIC-0011 (PRs #61–66)
- ENH-019 (i18n) → 🔵 Planned — not yet started
- ENH-020 (Apple TV) → 🔵 Backlog — see Platform Expansion section
- ENH-021 (visionOS) → 🔵 Backlog — see Platform Expansion section

---

## Location Accuracy

### ENH-001 — Exact GPS Prayer Times via CLGeocoder (Option A + B)
**Source:** Internal — Brampton vs. Toronto discrepancy (~2–3 min offset)

**Problem:** The current flow maps GPS coordinates to the nearest city in `cities.json`, then uses that city's coordinates and timezone for calculation. The mismatch between actual location (e.g. Brampton: 43.685°N, 79.759°W) and the proxy city (Toronto: 43.653°N, 79.383°W) introduces a systematic error in transit time and every derived prayer time.

**Solution (Option A):** For the auto-detect path, replace `TimeZone(identifier: city.timezone)` with `TimeZone.current`. The device's system timezone is always accurate. Combined with the raw GPS coordinate (not the proxy city's coordinate), this eliminates the offset with a one-line change.

**Solution (Option B):** Use `CLGeocoder.reverseGeocodeLocation()` to resolve the exact timezone from raw GPS coordinates. `CLPlacemark.timeZone` returns the authoritative timezone for any point on Earth. Results can be cached to UserDefaults alongside the display name. This is more robust than `.current` for edge cases (timezone boundaries, users calculating for a different location).

**Recommended approach:** A + B together. Use `.current` as an immediate fast path; use CLGeocoder to confirm and persist the resolved timezone. Fall back to the city database only for manual city selection.

**Effort:** Small (Option A: ~5 lines; Option B: ~30 lines + caching logic)  
**Files:** `LocationSetupView.swift`, `SettingsManager.swift`, `AppDelegate.swift`

---

## Ramadan / Seasonal Features

### ENH-002 — Ramadan Mode (Suhoor & Iftar Countdowns)
**Source:** Competitor gap — 8 of 10 top apps have this; users expect it  
**Priority:** High — seasonal but high-visibility

Replace or augment the standard prayer countdown in the menu bar with Suhoor (Fajr) and Iftar (Maghrib) countdowns during Ramadan. Auto-detect Ramadan dates via Hijri calendar. Could show "Suhoor in 2h 14m" or "Iftar in 45m" during the month.

**Effort:** Medium — Hijri calendar logic already present; needs menu bar display logic + Ramadan date range detection

---

### ENH-003 — Hijri Calendar Events (Islamic Holidays)
**Source:** Competitor gap — 8 of 10 top apps surface Islamic calendar events  

Display upcoming Islamic dates (Eid al-Fitr, Eid al-Adha, Mawlid, etc.) in the prayer times view or a dedicated calendar panel. Use `Calendar(identifier: .islamicUmmAlQura)` which is already imported.

**Effort:** Small-Medium — data is a static list of Hijri dates mapped to display names

---

## Localisation & Internationalisation

### ENH-019 — App-wide Multilingual Support (i18n + l10n)
**Source:** Internal — project has been English-only since inception; see also deferred US-0016 in `RELEASE_PLAN.md`.
**Priority:** Medium — large global Muslim audience speaks Arabic, Urdu, Indonesian, Turkish, French, Bengali, Bahasa Melayu, Persian, etc. as a first language. English-only excludes most users from a fluent UX.

**Problem:** Iqamah ships with hardcoded English strings throughout views, status bar, settings, adhaan picker labels, and notifications. Foundation gives us a free Hijri calendar localisation, but everything else is fixed. The forthcoming Hilal Watch (EPIC-0011) and iOS conversion (EPIC-0010) screens will inherit the same monolingual constraint unless this is resolved.

**Solution:** Two phases.

**Phase 1 — i18n plumbing (the engineering):**
- Convert every user-visible string to `String(localized:)` (Swift 5.7+) or `NSLocalizedString` where required. Audit: `iqamah/`, `iqamah-iOS/` (post EPIC-0010), `IqamahCore/`. Estimated ~150–200 string keys app-wide.
- Add a `Localizable.strings` (or `.xcstrings` Xcode 15+ string catalogue) with the English keys as the source of truth.
- Replace all hardcoded number formatting with `Measurement.FormatStyle` / `Number.FormatStyle` so locale formatting is automatic (1 234,56 vs 1,234.56).
- Replace any locale-sensitive comparison with `localizedCaseInsensitiveCompare(_:)` etc.
- Audit RTL bugs: every horizontal layout must respect `Locale.LanguageDirection`. SwiftUI `HStack` already does this; AppKit views may need leading/trailing constraints.

**Phase 2 — l10n (the translations):**
Initial languages, in priority order:
1. **Arabic (`ar`)** — RTL; needs native review for both UI strings and Hijri month names.
2. **Urdu (`ur`)** — RTL; large diaspora user base.
3. **Indonesian (`id`)** — largest Muslim country by population.
4. **Turkish (`tr`)** — modern Latin script, high digital adoption.
5. **French (`fr`)** — Maghreb + diaspora.
6. **Bengali (`bn`)** — LTR; Bangladesh + Indian diaspora.
7. **Bahasa Melayu (`ms`)** — Malaysia / Indonesia regional alternative.
8. **Persian / Farsi (`fa`)** — RTL; Iran + diaspora.

Per-language acceptance criterion: **a native speaker has reviewed every string in context**, not just translated keys in isolation. Use translation memory (XLIFF) so updates between releases reuse prior reviews.

**RTL-specific work:**
- All chevrons in pickers / month navigators reverse direction.
- Times of day in 12-hour format put AM/PM in locale-appropriate position.
- Status bar countdown text alignment.
- `MoonPhaseView` does **not** flip — astronomy is direction-neutral.
- Hilal Watch S-curve map does **not** flip — geography is fixed.

**Acceptance criteria (when promoted to an Epic):**
- [ ] All user-visible strings in iqamah, iqamah-iOS, and IqamahCore go through `String(localized:)` — no hardcoded English in any view, view model, or service
- [ ] `Localizable.xcstrings` exists with English source-of-truth and at least Arabic populated end-to-end (50%+ string coverage minimum for v1)
- [ ] App's user-facing language follows system locale by default; manual override available via Settings sheet → "Language" picker
- [ ] RTL layouts pass a visual review on Arabic and Urdu — no clipped text, no mis-aligned icons, no chevrons pointing the wrong way
- [ ] Number formatting respects locale (e.g. `1 234,56` in fr-FR; `1,234.56` in en-US)
- [ ] Hijri month names use Foundation's localised name on every supported locale (no English fallback)
- [ ] Notifications fire in the user's selected language, including the d29 Hilal Watch notification body
- [ ] Voice-Over speaks in the active language for all Hilal Watch / prayer times labels

**Cross-references:**
- **US-0016** in RELEASE_PLAN.md (Future — Release 1.2) is the user-story shell for this work; promotion to an Epic supersedes US-0016.
- **EPIC-0011 (Hilal Watch)** strings are written through `String(localized:)` from day 1 so this enhancement only adds translations, not engineering rework.
- **EPIC-0010 (iOS conversion)** likewise.
- **competitive-analysis.md** notes 4/10 surveyed apps offer 5+ language support; none of the macOS-native peers do.

**Effort:** Medium-Large
- Phase 1 plumbing audit + conversion: 2–3 weeks for an experienced developer (mostly mechanical but requires careful review of every view).
- Phase 2 first language (Arabic): 1 week for translation + 1 week for native review + RTL fixes.
- Each subsequent language: ~3–5 days assuming TM reuse.

**Files (when implemented):**
- `iqamah/Localizable.xcstrings` (and equivalent for `iqamah-iOS/`, `IqamahCore/`)
- `iqamah/Views/Settings/LanguagePicker.swift` (new)
- Audit + edit every `.swift` view file in `iqamah/Views/` and `iqamah-iOS/Views/`
- New CI lint: `swift-format` rule or custom script that fails the build if a `Text(...)` literal contains anything other than `String(localized:)` / `LocalizedStringKey` / a referenced variable.

---

## Astronomy & Calendar

### ENH-018 — Hilal Watch: Global Crescent Sighting Map ✅ Implemented (2026-05-11)
**Status:** ✅ Fully implemented — EPIC-0011 shipped in PRs #61–66. All 5 branches landed: astronomy port (Meeus/Odeh/Yallop/HMNAO), 16,200-cell grid calculator, macOS MapKit UI, iOS sheet, d29 notification. 174/174 tests passing.
**Source:** Internal product exploration via Claude conversation (May 2026); cross-checked against moonsighting.com / OmegaHilalSighting
**Priority:** Medium — distinctive feature; 0/10 surveyed competitors offer this

**Problem:** The Islamic lunar calendar depends on physically sighting the new crescent moon at the start of each month. Iqamah's current Hijri date display uses arithmetic tabular conversion (via Foundation `Calendar(identifier: .islamicUmmAlQura)`) which is accurate to ±1 day but provides no insight into *where on Earth* the crescent will actually be visible on the 29th and 30th of the current Hijri month — the two evenings on which the new month is determined globally.

**Solution:** Add a Hilal Watch screen that computes and displays global crescent visibility for both watch evenings, plus precise local visibility from the user's prayer-times location.

**Algorithm:**
- **Visibility criterion:** Odeh (2004), peer-reviewed against 737 ICOP observations. `V = ARCV − f(W)` where `ARCV` is moon altitude at sunset and `W` is topocentric crescent width in arcminutes. Four zones: A (easily visible naked eye), B (visible under good conditions), C (optical aid to locate), D (optical aid only).
- **Position engine:** Full Meeus lunar ephemeris (60+ longitude terms, ±0.01°). Simplified 10-term approaches produce false positives near the 6.4° Danjon limit; full Meeus eliminates these. Reference implementation: [astronomy-engine v2](https://github.com/cosinekitty/astronomy) (MIT, ~3000 LOC of pure math — portable to Swift). Alternatives for Swift: [SwiftAA](https://github.com/onekiloparsec/SwiftAA), or port astronomy-engine directly.
- **Sunset timing:** Fast ±15 min approximation is sufficient — sunset timing error contributes only ~0.15° to ARCV, well below the noise floor.
- **Grid:** 2° × 2° equirectangular, 90 × 180 = 16,200 points per evening. Both evenings (d29 and d30) computed once on screen mount and cached. Tab switching is instant. Estimated compute: 100–250 ms on iPhone 12 or newer.
- **Hijri month navigation:** Reuse the existing arithmetic tabular conversion. Month arrows step ±1 synodic period (29.530588853 days). Each month is labelled with the confirmation context (e.g. "Confirms start of Sha'ban 1447").
- **Date locking:** Maps lock to the next new-moon conjunction. d29 = evening of conjunction day; d30 = evening after. Each longitude's local sunset falls at a different UTC offset from conjunction, producing different crescent ages and the characteristic S-curve visibility arcs.

**Local sighting card:** When the user's prayer-times location is known, compute local Odeh values and display the raw inputs (ARCL elongation, ARCV moon altitude, W crescent width in arcmin) plus the V-score and zone, allowing cross-check against moonsighting.com tables.

**Colour scheme:** Match moonsighting.com / OmegaHilalSighting convention so users familiar with the global standard orient immediately:
- A — forest green (easily visible naked eye)
- B — teal/cyan (good conditions)
- C — grey (optical aid to locate)
- D — red (optical aid only)

**Acceptance criteria (when promoted to an Epic):**
- [ ] 29th watch map produces S-curve arcs consistent with moonsighting.com for the same date
- [ ] 30th watch map shows substantially wider visibility zones than the 29th
- [ ] Local sighting card shows ARCL, ARCV, W, V values matchable against moonsighting.com tables to within ±0.5°
- [ ] Grid computes in under 300 ms on iPhone 12 or newer
- [ ] Both grids cached; switching between 29th/30th tabs produces no visible recompute delay
- [ ] Colour scheme matches the OmegaHilalSighting A/B/C/D convention

**Open design questions:**
- Is this a feature on the existing Hijri date row, or a dedicated tab/screen? (Mockup assumes dedicated screen)
- macOS-only, iOS-only, or both? (Recommend both — fits naturally inside the planned EPIC-0010 universal app structure once that lands)
- Calculation can be done in `IqamahCore` so both platforms share it

**Mockup:** Original React/web prototype iterated during the brainstorm has been retired now that the algorithm and UI design are fully captured in the EPIC-0011 spec. The Odeh criterion implementation reference lives in [astronomy-engine v2](https://github.com/cosinekitty/astronomy); the colour scheme and visibility thresholds are codified in AC-0213.

**Effort:** Medium-Large — the algorithm is mechanical (mockup contains the full implementation) but porting an astronomical position engine to Swift, building the map UI, and validating against moonsighting.com is a multi-week effort. Should be a standalone Epic.

**Files (when implemented):**
- `IqamahCore/Sources/IqamahCore/Astronomy/HilalCalculator.swift` (new)
- `IqamahCore/Sources/IqamahCore/Astronomy/OdehCriterion.swift` (new)
- `IqamahCore/Sources/IqamahCore/Astronomy/MoonPosition.swift` (new — full Meeus port or SwiftAA wrapper)
- `iqamah/Views/HilalWatchView.swift` (macOS) and `iqamah-iOS/HilalWatchView.swift` (iOS) — most likely shareable
- New `IqamahCore/Tests/` cases validating against ICOP observation set

**External references:**
- Odeh (2004) criterion: [astronomycenter.net/pdf/2006_cri.pdf](https://astronomycenter.net/pdf/2006_cri.pdf)
- astronomy-engine: [github.com/cosinekitty/astronomy](https://github.com/cosinekitty/astronomy)
- crescent-moon-visibility (MIT): [github.com/crescent-moon-visibility/crescent-moon-visibility](https://github.com/crescent-moon-visibility/crescent-moon-visibility)
- moonsighting.com (visual cross-check baseline)

---

## macOS-Native Enhancements

### ENH-004 — macOS Menu Bar Widget / Notification Center Widget
**Source:** Competitor gap — 7 of 10 apps have home/lock screen widgets  

Add a macOS Notification Center widget (WidgetKit) showing today's prayer times and next prayer countdown. The menu bar already computes this data every 60 seconds — the widget would consume the same output.

**Effort:** Medium — requires a new WidgetKit extension target; data sharing via App Groups / UserDefaults suite

---

### ENH-005 — Silent / Do Not Disturb Mode
**Source:** Competitor gap — Guidance had this; users loved it; no current macOS competitor offers it  

Allow the adhan sound to be suppressed globally (visual indicator only) without per-prayer muting. Distinct from the existing per-prayer mute — this is a global "I'm in a meeting" toggle accessible from the menu bar right-click menu.

**Effort:** Small — one bool in SettingsManager, one menu item in the right-click NSMenu

---

### ENH-006 — Adhan Banner Dismiss Timeout Configuration
**Source:** Internal UX  

Let users set how long the adhan banner stays on screen before auto-dismissing. Currently hardcoded.

**Effort:** Small

---

## Prayer Tracking

### ENH-007 — Prayer Check-in / Habit Tracker
**Source:** Competitor gap — Just Pray (4.9★) built an entire app around this  

Allow users to mark each prayer as prayed on time, prayed late, or missed. Show a simple streak counter in the main view. Store history in UserDefaults or a local SQLite database.

**Effort:** Medium-Large — requires persistent storage schema, streak logic, UI additions

---

### ENH-008 — Sunnah Prayer Times (Tahajjud, Duha)
**Source:** Competitor gap — IslamApp surfaces these  

Display optional Sunnah prayer windows (Tahajjud: last third of night; Duha: 15–45 min after sunrise). These are calculated from existing Fajr/Sunrise/Dhuhr times already computed.

**Effort:** Small — calculation is trivial; UI is a toggle to show/hide extra rows

---

## Qibla

### ENH-009 — Augmented Reality Qibla
**Source:** Competitor gap — Athan Pro offers AR Qibla  

Overlay the Qibla direction on a live camera view using ARKit/RealityKit. The compass bearing is already calculated; AR adds a visual layer.

**Effort:** Large — requires ARKit integration, camera entitlement, separate UI flow

---

## Audio & Adhan

### ENH-010 — Additional Adhan Voices
**Source:** Competitor feature — Namaz offers "multiple maqams from famous mosques"  

Expand the adhan library beyond the current 5 regular + 3 Fajr. Potential additions: Makkah (Sheikh Sudais), Madinah, Al-Aqsa.

**Effort:** Small (content acquisition) + Small (code — the player infrastructure already supports it)

---

### ENH-011 — Per-Prayer Adhan Preview in Settings
**Source:** UX gap — users cannot audition an adhan before committing to it  

Add a play/preview button next to each adhan option in the settings sheet so users can hear a short clip before selecting.

**Effort:** Small

---

## Content & Information

### ENH-012 — Hadith of the Day
**Source:** Competitor gap — 4 of 10 apps surface a daily Hadith  

Show a rotating Hadith in the main view or as a menu bar tooltip. Could be a static bundled JSON of curated Hadith to avoid network dependency.

**Effort:** Small — static data + UI card

---

### ENH-013 — Tasbih / Dhikr Counter
**Source:** Competitor gap — Muslim Pro and Athan have this  

A simple tap counter for post-prayer dhikr. Could live as a popover from the main view.

**Effort:** Small

---

### ENH-014 — Zakat Calculator
**Source:** Competitor feature — Muslim Pro, Athan  

A one-time calculator for annual Zakat based on nisab. Could be a modal or separate screen.

**Effort:** Small — math is straightforward; primarily a UI task

---

## Platform Expansion

### ENH-015 — iPhone & iPad App ✅ Implemented via EPIC-0010 (2026-05-10)
See the multi-platform migration assessment in this file (below).
**Status:** Implemented → EPIC-0010 (US-0040–US-0044 shipped in PRs #56–60). IqamahCore extracted, iOS target live, iCloud KVS sync, notifications, widget. US-0045 (Live Activity) deferred to v2.1.

### ENH-016 — Apple Watch App ✅ Implemented via EPIC-0012 (2026-05-11)
See the multi-platform migration assessment in this file (below).
**Status:** Implemented → EPIC-0012 (US-0053–US-0057, AC-0252–AC-0275, PR #67). Prayer times list, Qibla, settings on-watch, 4 WidgetKit complications, haptic notifications, WCSession sync.

### ENH-017 — Apple Vision Pro App
See ENH-021 below (expanded from this placeholder).


### ENH-020 — Apple TV App (tvOS)
**Source:** Product exploration — prayer times on a shared family screen; strong use case during Ramadan (Suhoor/Iftar countdowns on living-room TV)
**Priority:** Low-Medium — niche but zero competitors offer it on tvOS
**Release Target:** Post EPIC-0012 (Watch app must ship first; Watch Connectivity pattern established)

**Problem:** No prayer times app exists on Apple TV. The family living-room screen is underused for Islamic content; a beautiful 4K prayer times display during Ramadan is a compelling differentiator.

**Platform constraints:**
- No GPS on Apple TV — location must come from iCloud KVS (already synced from iPhone/Mac via EPIC-0010) or manual selection via on-screen keyboard
- No `UNUserNotificationCenter` for local notifications — the TV cannot alert at prayer time; adhan playback is not possible
- Siri Remote input model — focus engine only (Up/Down/Left/Right/Select); no touch, no swipe
- All SwiftUI focus-driven navigation must be tested against the remote
- Qibla compass is meaningless (no magnetometer) — omit from tvOS

**What ships in v1:**
- Prayer times list for today, next prayer highlighted in gold
- City displayed prominently (pulled from App Group / iCloud KVS)
- Countdown to next prayer in large type
- Hijri date header
- Minimal settings: city selection via search (Siri Remote keyboard), calculation method
- Designed for ambient display (no interaction required — auto-refreshes at midnight)

**IqamahCore changes required:** None — `PrayerCalculator` already runs on tvOS. `SettingsManager` App Group already works across all Apple platforms.

**New target:** `IqamahTV` (tvOS 17+, bundle ID `com.fablesoft.iqamah.tv`, separate App Store record)

**Acceptance criteria (when promoted to an Epic):**
- [ ] `IqamahTV` target builds and runs on Apple TV simulator
- [ ] Prayer times display correctly using location pulled from iCloud KVS
- [ ] All UI elements navigable with Siri Remote (focus engine, no crashes)
- [ ] Qibla tab is absent from tvOS build
- [ ] App updates prayer times at midnight without user interaction
- [ ] First launch (no KVS data): shows city picker via on-screen keyboard

**Effort:** Medium (2–3 weeks) — new target + focus-engine UI adaptation + city selection without touch

---

### ENH-021 — Apple Vision Pro App (visionOS)
**Source:** ENH-017 placeholder expanded
**Priority:** Medium — "designed for iPad" path is nearly free; native path is a strong press story
**Release Target:** Path 1 immediately after EPIC-0010 (iOS app) ships; Path 2 as optional EPIC

**Problem:** visionOS is growing and no Islamic prayer app has a native spatial experience. The "designed for iPad" compatibility path gets Iqamah on Vision Pro at near-zero cost.

**Path 1 — iPad Compatibility (~1 week, recommended for v1):**
- visionOS automatically runs the iOS app in a floating window; users resize it freely in their space
- Qibla compass uses Vision Pro's IMU/sensors — works without changes
- Submit with `UIRequiresFullScreen = NO`; Apple review typically approves
- Adhan plays from the device speaker (not spatial, but functional)
- Zero extra code beyond the iOS app (EPIC-0010)
- **This should be the first visionOS release** — validates demand before investing in native

**Path 2 — Native visionOS (~3–4 weeks on top of Path 1):**

*Ornaments (floating UI beside the main window):*
- Prayer countdown ornament — always-visible next prayer + time, floating beside any open app
- Hijri date ornament — small date strip

*Volumes (3D content):*
- Spatial Qibla indicator: a 3D RealityKit arrow volume floating in the room, pointing toward Makkah using device heading. Updates live as the user turns.

*Spatial audio:*
- Adhan placed at a fixed spatial point in the room (e.g. slightly above eye level, centred) — `AVAudioEnvironmentNode` with distance attenuation. Unique to Vision Pro; not available on any other platform.

*Window chrome:*
- `.glassEffect()` already planned for iOS 26 / macOS 26 (AC-0251) — visionOS uses the same API; the Liquid Glass chrome applies automatically.

**IqamahCore changes required:** None for Path 1. Path 2 adds RealityKit and `AVAudioEnvironmentNode` code only to the `IqamahVisionOS` target — IqamahCore is unchanged.

**Acceptance criteria (when promoted to an Epic):**

Path 1:
- [ ] Iqamah iOS app runs in visionOS simulator in compatibility mode without crashes
- [ ] All 5 prayer times display correctly
- [ ] Qibla compass responds to device heading in visionOS
- [ ] App Store Connect submission accepted as compatible with visionOS

Path 2 (additional):
- [ ] Prayer countdown ornament persists beside other windows
- [ ] Spatial Qibla volume renders in the correct direction from the user's position
- [ ] Adhan plays from a fixed spatial point; headphone users experience directional audio
- [ ] `.glassEffect()` window chrome applied via `@available(visionOS 1.0, *)`

**Effort:** Path 1: ~1 week testing + submission. Path 2: ~3–4 weeks on top.


---

## Multi-Platform Migration Assessment

### Overview

Iqamah is currently a macOS-only app. Expanding to iPhone, iPad, Apple Watch, and Vision Pro requires understanding which parts of the codebase are already cross-platform and which are macOS-specific.

---

### What Is Already Cross-Platform (Zero Changes Needed)

| Component | Why portable |
|---|---|
| `PrayerCalculator.swift` | Pure math — Foundation + CoreLocation only |
| `Models/Location.swift` | Codable structs, no platform APIs |
| `Models/PrayerTimes.swift` | Pure structs |
| `Models/CalculationMethod.swift` | Enums + pure Swift |
| `LocationService.swift` | CoreLocation is cross-platform |
| `cities.json` | Data resource |

These five form a clean, portable core. Extracting them into a local Swift Package would make sharing across targets explicit and compile-time verified.

---

### What Is macOS-Specific (Needs Replacement or Conditional Compilation)

| Component | macOS APIs Used | Notes |
|---|---|---|
| `AppDelegate.swift` | `NSApplication`, `NSStatusItem`, `NSStatusBar`, `NSWindow`, `NSMenu`, `NSMenuItem`, `NSWindowDelegate`, `AppKit` throughout | The entire file is macOS-only. On iOS there is no menu bar or status item concept. |
| `iqamahApp.swift` | `@NSApplicationDelegateAdaptor`, `.windowStyle(.hiddenTitleBar)` | Entry point needs `#if os(macOS)` branching |
| `PrayerTimesView.swift` | `NSImage(named:)`, `NSImage.applicationIconName` | Needs `Image(...)` / `#if` conditionals |
| `AdhaanBannerController.swift` | Likely uses `NSWindow` overlay | Needs a UIKit/SwiftUI equivalent on iOS |
| `AdhaaanPlayer.swift` | `AVFoundation` (cross-platform), but background audio session differs | iOS requires `AVAudioSession` category setup; background playback rules differ |
| Adhan trigger mechanism (`Timer` in AppDelegate) | macOS keeps background timers alive indefinitely | On iOS, background timers are killed after ~30s. Must use `UNUserNotificationCenter` scheduled local notifications with custom sounds instead. |

---

### Platform-by-Platform Effort

#### iPhone + iPad — Effort: **Medium (4–6 weeks)**

The views and core logic port well. The primary engineering work is:

1. **Adhan scheduling re-architecture** — the biggest change. On iOS, a 60-second background Timer does not survive. Replace with `UNUserNotificationCenter` local notifications: schedule all 5 daily prayers as notifications with `.sound = UNNotificationSound(named:)` at setup time and re-schedule when settings change. The adhan files must be packaged as `.caf` or `.aiff` (iOS notification sound format, max 30s per system limit — full adhans that exceed this need a different approach, e.g. playing via an iOS background audio mode on app launch).

2. **Replace AppDelegate** — iOS uses `UIApplicationDelegate` or pure SwiftUI `App` lifecycle. The status bar concept becomes a home screen widget + push/local notifications.

3. **View adaptations** — Replace `NSImage` with `Image`. Add `NavigationStack` or tab-based navigation appropriate for iPhone's smaller screen. The current single-window layout will need responsive adaptation (`adaptiveModalPresentation`, size class branching).

4. **iPad** — iPad gets the iPhone app for free. A dedicated iPad layout (split view, sidebar navigation) would be a polish pass on top.

5. **Entitlements** — `Background Modes` (audio, background fetch) required for iOS adhan delivery.

**iCloud sync** (UserDefaults → NSUbiquitousKeyValueStore) is optional but strongly recommended so settings sync between Mac and iPhone.

---

#### Apple Watch — Effort: **High (6–10 weeks)**

Watch is a genuinely separate platform with its own constraints:

1. **Separate watchOS target** in Xcode — cannot share the macOS/iOS app target directly.

2. **PrayerCalculator is fully portable** — pure Swift, no AppKit/UIKit. Copy or package-share it; it runs fine on watchOS.

3. **Data sync** — use `WCSession` (Watch Connectivity) to push today's prayer times from the iPhone to the watch. Alternatively, run the calculator on-watch (it's lightweight enough).

4. **No adhan audio on watch** — watchOS does not support custom notification sounds beyond system haptics. The watch experience is: complication showing next prayer + countdown, and a haptic tap at prayer time.

5. **Complications** — the main value-add on watch. Implement `WidgetKit` complications (used for watchOS 7+ complications) showing next prayer name + time, or a countdown. Requires the complication family matrix (corner, circular, rectangular, etc.).

6. **UI** — `WKInterfaceController` / SwiftUI for watchOS. A simple list of today's prayers with the next one highlighted. Very limited screen real estate.

---

#### Apple Vision Pro (visionOS) — Effort: **Low–Medium**

Two paths:

**Path 1 — "Designed for iPad" compatibility (Low, ~1 week of testing)**
visionOS automatically runs iPad apps in a floating window. If the iPhone/iPad app is built first, it runs on Vision Pro in compatibility mode with zero additional code. Users can resize the window in their space. This gets Iqamah on Vision Pro at no extra cost once the iOS app exists.

**Path 2 — Native visionOS experience (Medium, 3–4 weeks on top of iOS)**
A native visionOS app uses ornaments (toolbars floating beside a window), volumes (3D content), and the spatial audio system. For a prayer times app the native additions would be:
- A 3D Qibla direction indicator as a RealityKit volume
- An ornament showing the next prayer countdown beside the main window
- Spatial adhan audio (plays from a fixed point in the room)

For a v1 visionOS release, Path 1 is the right call.

---

### Recommended Sequencing

| Phase | Platforms | Rationale |
|---|---|---|
| 1 | iPhone + iPad | Largest user base; proves the multi-platform architecture; required before Watch |
| 2 | Apple Watch | Depends on iPhone for Watch Connectivity; complications are high-value for this app |
| 3 | Vision Pro | Free via iPad compatibility; native experience is a polish pass after Watch |

---

### Architectural Recommendation

Extract the portable core into a local Swift Package (`IqamahCore`) before starting phase 1:

```
IqamahCore/
  Sources/
    PrayerCalculator.swift
    PrayerTimes.swift
    CalculationMethod.swift
    Location.swift
    LocationService.swift
```

All four app targets (macOS, iOS, watchOS, visionOS) import `IqamahCore`. Platform-specific code (AppDelegate, status bar, notification scheduling, complications) lives in each target separately. This prevents the codebase from becoming a sea of `#if os(macOS)` conditionals and makes the boundaries explicit.

**Estimated total effort across all platforms:** 12–18 weeks of focused development, assuming one developer.
