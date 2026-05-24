# Iqamah — Future Enhancements

Logged from competitive analysis (May 2026) and product research. Items are grouped by theme, not priority. See competitive-analysis.md for the feature gap matrix these derive from.

**Implementation status as of 2026-05-20:**
- ENH-0015 (iPhone/iPad) → ✅ Implemented as EPIC-0010 (PRs #56–60). Submitted to App Store 2026-05-20.
- ENH-0016 (Apple Watch) → ✅ Implemented as EPIC-0012 (PR #67). Submitted to App Store 2026-05-20.
- ENH-0018 (Hilal Watch) → ✅ Implemented as EPIC-0011 (PRs #61–66). Submitted to App Store 2026-05-20.
- ENH-0019 (i18n) → 🔵 Planned — not yet started
- ENH-0020 (Apple TV) → 🔵 Backlog — see Platform Expansion section
- ENH-0021 (visionOS) → 🔵 Backlog — see Platform Expansion section

---

## Location Accuracy

### ENH-0001 — Exact GPS Prayer Times via CLGeocoder (Option A + B) ✅ Implemented (2026-05-21)
**Status:** ✅ Fully implemented across all platforms. A+B shipped during v1.5.0 (macOS/iOS first-launch and Settings re-detect); watchOS Option B parity, a one-time v1.6 re-detect prompt for legacy users, and structural cleanups landed in the v1.6 cycle (see docs/superpowers/specs/2026-05-21-enh-001-finish-up-design.md).

| Surface | Option | Location |
|---|---|---|
| macOS first-launch | A+B | `iqamah/Views/LocationSetupView.swift` |
| iOS first-launch | A+B | same (shared via `iOSRootView`) |
| macOS/iOS Settings re-detect | A+B | `iqamah/Views/SettingsSheetView.swift` |
| watchOS first-launch + Settings | A+B | `IqamahWatch/IqamahWatchApp.swift` |

**Source:** Internal — Brampton vs. Toronto discrepancy (~2–3 min offset)

**Problem:** The current flow maps GPS coordinates to the nearest city in `cities.json`, then uses that city's coordinates and timezone for calculation. The mismatch between actual location (e.g. Brampton: 43.685°N, 79.759°W) and the proxy city (Toronto: 43.653°N, 79.383°W) introduces a systematic error in transit time and every derived prayer time.

**Solution (Option A):** For the auto-detect path, replace `TimeZone(identifier: city.timezone)` with `TimeZone.current`. The device's system timezone is always accurate. Combined with the raw GPS coordinate (not the proxy city's coordinate), this eliminates the offset with a one-line change.

**Solution (Option B):** Use `CLGeocoder.reverseGeocodeLocation()` to resolve the exact timezone from raw GPS coordinates. `CLPlacemark.timeZone` returns the authoritative timezone for any point on Earth. Results can be cached to UserDefaults alongside the display name. This is more robust than `.current` for edge cases (timezone boundaries, users calculating for a different location).

**Recommended approach:** A + B together. Use `.current` as an immediate fast path; use CLGeocoder to confirm and persist the resolved timezone. Fall back to the city database only for manual city selection.

**Effort:** Small (Option A: ~5 lines; Option B: ~30 lines + caching logic)  
**Files:** `LocationSetupView.swift`, `SettingsManager.swift`, `AppDelegate.swift`

---

## Ramadan / Seasonal Features

### ENH-0002 — Fasting Mode (Suhoor & Iftar Countdowns + Nawafil Triggers) ✅ Implemented (2026-05-21)
**Status:** ✅ Implemented as EPIC-0017 (US-0071–US-0075 shipped in v1.6). Generalized from Ramadan-only mode to a Fasting Mode covering 9 activation triggers (auto-Ramadan, weekly schedule, Ayyam al-Beed, 6 of Shawwal, Day of Arafah, first 9 of Dhul-Hijjah, Muharram fast, 15 Sha'ban, 27 Rajab). Tradition-aware UI gating driven by `isShiaMethod` helper; Ja'fari calculation method added alongside Tehran. Spec at `docs/superpowers/specs/2026-05-21-fasting-mode-design.md`.

| Surface | Treatment |
|---|---|
| macOS menu bar | Relabel Fajr→Suhoor / Maghrib→Iftar (🌙 Ramadan, 🕗 Nawafil) within 2h window |
| macOS popover | Banner + relabel |
| iOS hero card | Banner + relabel |
| iOS prayer row | Relabel |
| watchOS prayer tab | Relabel |
| Widgets | Relabel in entries |
| Live Activity | Relabel via ContentState fastingActive/fastingTriggerRaw fields |

---

### ENH-0003 — Hijri Calendar Events (Islamic Holidays)
**Source:** Competitor gap — 8 of 10 top apps surface Islamic calendar events  

Display upcoming Islamic dates (Eid al-Fitr, Eid al-Adha, Mawlid, etc.) in the prayer times view or a dedicated calendar panel. Use `Calendar(identifier: .islamicUmmAlQura)` which is already imported.

**Effort:** Small-Medium — data is a static list of Hijri dates mapped to display names

---

## Localisation & Internationalisation

### ENH-0019 — App-wide Multilingual Support (i18n + l10n)
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

### ENH-0018 — Hilal Watch: Global Crescent Sighting Map ✅ Implemented (2026-05-11)
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

### ENH-0004 — macOS Menu Bar Widget / Notification Center Widget
**Source:** Competitor gap — 7 of 10 apps have home/lock screen widgets  

Add a macOS Notification Center widget (WidgetKit) showing today's prayer times and next prayer countdown. The menu bar already computes this data every 60 seconds — the widget would consume the same output.

**Effort:** Medium — requires a new WidgetKit extension target; data sharing via App Groups / UserDefaults suite

---

### ENH-0005 — Silent / Do Not Disturb Mode
**Source:** Competitor gap — Guidance had this; users loved it; no current macOS competitor offers it  

Allow the adhan sound to be suppressed globally (visual indicator only) without per-prayer muting. Distinct from the existing per-prayer mute — this is a global "I'm in a meeting" toggle accessible from the menu bar right-click menu.

**Effort:** Small — one bool in SettingsManager, one menu item in the right-click NSMenu

---

### ENH-0006 — Adhan Banner Dismiss Timeout Configuration
**Source:** Internal UX  

Let users set how long the adhan banner stays on screen before auto-dismissing. Currently hardcoded.

**Effort:** Small

---

## Prayer Tracking

### ENH-0007 — Prayer Check-in / Habit Tracker
**Source:** Competitor gap — Just Pray (4.9★) built an entire app around this  

Allow users to mark each prayer as prayed on time, prayed late, or missed. Show a simple streak counter in the main view. Store history in UserDefaults or a local SQLite database.

**Effort:** Medium-Large — requires persistent storage schema, streak logic, UI additions

---

### ENH-0008 — Sunnah Prayer Times (Tahajjud, Duha)
**Source:** Competitor gap — IslamApp surfaces these  

Display optional Sunnah prayer windows (Tahajjud: last third of night; Duha: 15–45 min after sunrise). These are calculated from existing Fajr/Sunrise/Dhuhr times already computed.

**Effort:** Small — calculation is trivial; UI is a toggle to show/hide extra rows

---

## Qibla

### ENH-0009 — Augmented Reality Qibla
**Source:** Competitor gap — Athan Pro offers AR Qibla  

Overlay the Qibla direction on a live camera view using ARKit/RealityKit. The compass bearing is already calculated; AR adds a visual layer.

**Effort:** Large — requires ARKit integration, camera entitlement, separate UI flow

---

## Audio & Adhan

### ENH-0010 — Additional Adhan Voices
**Source:** Competitor feature — Namaz offers "multiple maqams from famous mosques"  

Expand the adhan library beyond the current 5 regular + 3 Fajr. Potential additions: Makkah (Sheikh Sudais), Madinah, Al-Aqsa.

**Effort:** Small (content acquisition) + Small (code — the player infrastructure already supports it)

---

### ENH-0011 — Per-Prayer Adhan Preview in Settings
**Source:** UX gap — users cannot audition an adhan before committing to it  

Add a play/preview button next to each adhan option in the settings sheet so users can hear a short clip before selecting.

**Effort:** Small

---

### ENH-0023 — Adhaan Surround Mode (Spatial Multi-Muezzin)
**Source:** User suggestion (2026-05-21)
**Priority:** Medium — distinctive feature; emotionally meaningful for users from Muslim-majority countries

**Problem:** Iqamah plays a single adhaan at prayer time. Users who grew up in Muslim-majority countries — Egypt, Saudi Arabia, Pakistan, Indonesia, Malaysia, Turkey, the Levant — describe the experience of hearing multiple mosques start the adhaan within a 5–15 second window, each from a different direction, as one of the most emotionally evocative aspects of daily prayer life. The single-source adhaan in apps misses this sensory dimension entirely.

**Solution:** "Surround Mode" that:
1. Lets the user select 2–5 different adhaan recordings simultaneously (existing 5 regular + 3 Fajr library plus any added via ENH-0010)
2. Plays them with staggered start times — small natural jitter (e.g. 0s / +3s / +8s / +12s) to mimic real-world multi-mosque overlap
3. Positions each in 3D space using `AVAudioEnvironmentNode` — different azimuth/distance per source so the listener perceives mosques in different directions and at different perceived distances
4. Master volume + per-source mix balance so overlapping playback doesn't clip

**Platforms:**
- iOS / iPadOS — full support; spatial audio works via head-tracking with AirPods Pro/Max
- macOS — full support; positional audio through any output device
- visionOS — best fit; spatial audio is native and the experience would be remarkable
- watchOS — likely unavailable; watchOS audio APIs don't expose `AVAudioEnvironmentNode`
- tvOS — would work but unusual use case (living-room ambient)

**Technical sketch:**
```swift
let engine = AVAudioEngine()
let environment = AVAudioEnvironmentNode()
engine.attach(environment)
engine.connect(environment, to: engine.mainMixerNode, format: nil)

// For each adhaan source:
let player = AVAudioPlayerNode()
engine.attach(player)
engine.connect(player, to: environment, format: file.processingFormat)
player.position = AVAudio3DPoint(x: 10, y: 0, z: 5)  // azimuth + distance
player.scheduleFile(file, at: AVAudioTime(sampleTime: offset, atRate: rate))
```

**Settings UI:**
- New section: "Surround Mode" with master toggle (off by default — opt-in)
- Per-prayer enable (Fajr / Dhuhr / Asr / Maghrib / Isha — Sunrise excluded)
- Multi-select picker for 2–5 source adhaans
- Spread slider: tight (3–5 s window) → wide (10–15 s window)
- Spatial layout preset: Cairo (5 mosques typical), Istanbul (3), Lahore (4), or "Custom" with manual 3D positions
- Master volume

**Acceptance criteria (when promoted to an Epic):**
- [ ] User can select 2–5 adhaans for simultaneous playback
- [ ] Each source has a configurable start offset (0–15 s)
- [ ] `AVAudioEnvironmentNode` positions each source in 3D space
- [ ] Mix is balanced — no clipping at default master volume
- [ ] Preset layouts ship with sensible defaults
- [ ] Feature gracefully degrades on devices without spatial audio support (falls back to stereo)
- [ ] watchOS and tvOS gracefully ignore the setting (Surround Mode unavailable badge in settings)

**Cross-references:**
- ENH-0010 (Additional Adhaan Voices) — synergistic; more voices = more variety
- ENH-0021 (Vision Pro Path 2) — spatial Qibla mentioned; Surround Mode is a natural pair

**Effort:** Medium (1–2 weeks). Audio engine code is the main lift; `AVAudioEnvironmentNode` has a learning curve but standard Apple sample code covers it.

**Open questions:**
- Headphones-required or speaker-OK? Likely speaker for the at-home use case (most users won't be wearing AirPods at prayer time)
- Per-prayer config or single global setting?
- Should licensed recordings from iconic mosques (Masjid al-Haram, Al-Aqsa, Prophet's Mosque in Madinah) ship as optional preset packs?

---

### ENH-0024 — Adhaan Bypasses iPhone Silent Switch (Critical Alerts Entitlement)
**Source:** User request (2026-05-21); audit completed same day
**Priority:** Medium-High — religiously significant; affects a substantial fraction of daily-use scenarios

**Audit summary (2026-05-21):**

| Path | Status | Reason |
|---|---|---|
| **Foreground playback** (`AdhaaanPlayer.swift:60-61`) | ✅ Bypasses silent switch correctly | Uses `AVAudioSession.Category.playback` + `setActive(true)` before each playback |
| **Background / locked playback** (`NotificationScheduler.swift:90` via `UNNotificationSound(named:)`) | ⚠️ Silenced by switch | iOS notification sounds always respect the silent switch unless using `criticalSound` (requires Critical Alerts entitlement) |
| **Focus / DND bypass** (`interruptionLevel = .timeSensitive`) | ✅ Already working | Per BUG-0066. Independent of silent-switch concern. |

**User-facing behavior right now:**
- App foregrounded at prayer time → adhaan plays at full volume regardless of silent switch
- App backgrounded or device locked → lock-screen banner appears (Focus/DND bypassed), but the adhaan sound is muted by the silent switch ❌

**Problem:** A substantial fraction of prayer-time events happen with the app backgrounded — that's the normal case. Users with silent switch enabled (which many keep on by default outside of phone calls) will miss the audible adhaan despite expecting it. This isn't a code bug — Apple deliberately prevents apps from bypassing the silent switch via plain local notifications. The only sanctioned route is the **Critical Alerts entitlement** (`com.apple.developer.usernotifications.critical-alerts`).

**Solution — three parts:**

1. **Apply to Apple for the Critical Alerts entitlement.** Apply via Apple Developer support. Justification: prayer times are time-bound religious obligations; missed prayers due to silenced alerts is a real harm to observant users. Apple has historically granted this for prayer apps in some cases (worth a competitor check — Athan Pro and Muslim Pro behavior on silent suggests they may have it; verify before applying).

2. **Once entitlement is granted, switch notification sound construction:**
   ```swift
   // Was: UNNotificationSound(named: UNNotificationSoundName(notifFilename))
   content.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
   // — or, for the specific adhaan file —
   content.sound = UNNotificationSound.criticalSoundNamed(
       UNNotificationSoundName(notifFilename),
       withAudioVolume: 1.0
   )
   content.interruptionLevel = .critical  // upgrade from .timeSensitive
   ```

3. **Settings UX:**
   - Add a "Play through silent mode" toggle (default ON) — gives users opt-out for moments when they truly want silence (cinema, meetings)
   - Show a one-time explanation banner when the user first enables notifications: *"Iqamah uses the Critical Alerts permission to play the adhaan even when your phone is on silent. You can disable this in Settings if you prefer."*
   - Document the behavior in the App Store description so it's not a surprise

**Acceptance criteria (when promoted to an Epic):**
- [ ] Critical Alerts entitlement granted by Apple
- [ ] `UNNotificationSound.criticalSoundNamed(_:withAudioVolume:)` used for prayer notifications when entitled
- [ ] `interruptionLevel = .critical` for the Critical-Alerts path
- [ ] Fallback: if entitlement is not granted (provisional builds, side-loaded), code gracefully falls back to current `.timeSensitive` + non-critical sound (no user-visible error)
- [ ] Settings exposes "Play through silent mode" toggle (default ON)
- [ ] First-launch onboarding mentions the behavior + how to opt out
- [ ] On a real iPhone with silent switch ON and the app backgrounded, adhaan plays at audible volume at prayer time
- [ ] App Store description and What's New mention the behavior

**Cross-references:**
- BUG-0066 (resolved) — `.timeSensitive` interruption level for Focus / DND bypass. Silent-switch bypass is a separate (lower) layer.
- ENH-0023 (Surround Mode) — Critical Alerts grant would let Surround Mode also play through silent.

**Effort:** Small-Medium for the code (~30 lines + Settings toggle). Large for the entitlement application — Apple's response time is days-to-weeks, may require iteration, and there's a non-zero chance of denial. Ship the code path behind a runtime entitlement check so it's ready to flip when approval arrives.

**Watch behavior:** watchOS adhaan uses haptics only (no audio sound file); iPhone's silent switch doesn't affect the watch haptic. Verified during the audit.

**Why we should pursue this:**
The audit showed Iqamah is doing everything correctly within Apple's default constraints. The remaining gap requires Apple's explicit permission and is the single biggest quality-of-experience opportunity for a prayer-times app. Worth applying for.

---

### ENH-0026 — Background-reliable Live Activity updates

**Status:** Backlog
**Source:** Follow-up from v1.6.0 LA rollover fix (PR #133, commit 405256a)

**Problem:** v1.6.0 ships a foreground/recent-background fix for the Live Activity "stuck on passed prayer" bug — `staleDate` + a `Timer` that re-evaluates the activity state at the next prayer time. If the app is suspended (long-backgrounded, terminated, or memory-pressured), the Timer doesn't fire and the Live Activity / Dynamic Island can drift again until the user reopens the app.

**Proposed solution:** Move from local Activity updates to push-token Live Activities. Each scheduled prayer time becomes a server-pushed `ActivityContent` update via APNs (or a silent local APNs via `Activity<...>.pushToken` if Apple's documentation allows it without a server). Pair with `BGAppRefreshTask` registration so the app can re-arm the next push window on launch / background refresh.

**Why backlog (not Epic yet):**
- Requires a backend (or commitment to a server-light solution like a cheap Cloudflare Worker / Lambda) — design + cost decision.
- Push payload format + retry strategy needs design.
- Existing code already produces a `FastingDayState` per evaluation — pure-data side already done.

**Promotion criteria:** Promote to EPIC + US when the team commits to a notification backend (a separate decision the indie/solo dev cycle will gate on).

**References:**
- `iqamah/iOS/PrayerActivityManager.swift` — current foreground Timer
- `IqamahLiveActivity/PrayerActivityAttributes.swift` — ContentState struct
- Apple docs: ActivityKit push-token updates

---

### ENH-0025 — Per-day Alert Scheduling
**Source:** User request (2026-05-23)
**Priority:** Medium — quality-of-life refinement on top of existing notification system

**Problem:** Notifications are currently global — when prayer notifications are enabled, they fire for every selected prayer every day. Some users want different behaviour on different days (e.g., mute Fajr on weekends; silence everything on Friday during travel).

**Proposed solution:** Add a settings UI that lets the user enable/disable each prayer's notification independently per day-of-week (7 × N-prayers matrix, or a simpler "per-day master toggle" if matrix is too dense).

**Why backlog (not Epic yet):**
- Requires schema decision: matrix vs per-day master vs per-prayer-per-day
- Storage cost in `SettingsManager` (likely a new `[Int: Set<String>]` keyed by Calendar weekday)
- Notification scheduler (per-platform) needs to consult the day-of-week before scheduling each fire
- UI is non-trivial — Settings sheet on macOS/iOS will need a new section

**Promotion criteria:** Promote to EPIC + US in `RELEASE_PLAN.md` when (a) at least one more user requests this OR (b) a v1.7 planning cycle scopes it.

**References:**
- `iqamah/iOS/PrayerNotificationScheduler.swift` (or equivalent — the per-platform scheduler that would need to consult day-of-week)
- `Packages/IqamahCore/Sources/IqamahCore/Services/SettingsManager.swift` (storage)

---

## Content & Information

### ENH-0012 — Hadith of the Day
**Source:** Competitor gap — 4 of 10 apps surface a daily Hadith  

Show a rotating Hadith in the main view or as a menu bar tooltip. Could be a static bundled JSON of curated Hadith to avoid network dependency.

**Effort:** Small — static data + UI card

---

### ENH-0013 — Tasbih / Dhikr Counter
**Source:** Competitor gap — Muslim Pro and Athan have this  

A simple tap counter for post-prayer dhikr. Could live as a popover from the main view.

**Effort:** Small

---

### ENH-0014 — Zakat Calculator
**Source:** Competitor feature — Muslim Pro, Athan  

A one-time calculator for annual Zakat based on nisab. Could be a modal or separate screen.

**Effort:** Small — math is straightforward; primarily a UI task

---

## Platform Expansion

### ENH-0015 — iPhone & iPad App ✅ Implemented via EPIC-0010 (2026-05-10)
See the multi-platform migration assessment in this file (below).
**Status:** Implemented → EPIC-0010 (US-0040–US-0044 shipped in PRs #56–60). IqamahCore extracted, iOS target live, iCloud KVS sync, notifications, widget. US-0045 (Live Activity) deferred to v2.1.

### ENH-0016 — Apple Watch App ✅ Implemented via EPIC-0012 (2026-05-11)
See the multi-platform migration assessment in this file (below).
**Status:** Implemented → EPIC-0012 (US-0053–US-0057, AC-0252–AC-0275, PR #67). Prayer times list, Qibla, settings on-watch, 4 WidgetKit complications, haptic notifications, WCSession sync.

### ENH-0017 — Apple Vision Pro App
See ENH-0021 below (expanded from this placeholder).


### ENH-0020 — Apple TV App (tvOS)
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

### ENH-0021 — Apple Vision Pro App (visionOS)
**Source:** ENH-0017 placeholder expanded
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

### ENH-0022 — Islamic Holiday Celebration Reminders
**Source:** Spawned from Fasting Mode brainstorming (2026-05-21) as a sibling concept

**Problem:** Iqamah surfaces fasting practice via Fasting Mode (ENH-0002) but does not commemorate non-fasting Islamic holidays. Users miss notifications for Eid al-Fitr, Eid al-Adha, Mawlid an-Nabi, Laylat al-Qadr, Hijri New Year, Ashura commemorations (Shia tradition), Isra wal-Mi'raj, Laylat al-Bara'ah, and Eid al-Ghadir (Shia).

**Solution:** Reuse the FastingModeEngine's Hijri-date evaluation infrastructure to expose celebration notifications. Per-holiday opt-in toggles in Settings. Tradition-aware visibility (some holidays observed primarily in Shia or Sunni tradition).

**Effort:** Medium — engine pattern is established; mainly date data + UI toggles + per-platform notification scheduling.

**Files (when implemented):**
- `Packages/IqamahCore/Sources/IqamahCore/Services/CelebrationCalendar.swift` (new)
- `Packages/IqamahCore/Sources/IqamahCore/Services/SettingsManager.swift` (new celebration toggles)
- Settings UI section (parallel to FastingModeSection)
- Per-platform notification scheduler extensions

---

### ENH-0027 — Cross-Ecosystem Expansion: Windows, Linux, Android
**Source:** Internal product exploration via Claude conversation (2026-05-24); follow-up to the Apple-only Multi-Platform Migration Assessment below.
**Priority:** Low-Medium — large addressable audience outside the Apple ecosystem (Android is the largest mobile OS globally; Windows dominates desktop in many Muslim-majority countries), but a non-trivial architectural commitment. Defer until after EPIC-0010, EPIC-0011, EPIC-0012, EPIC-0017, ENH-0019 (i18n), and ENH-0020/0021 (tvOS/visionOS) have stabilised.
**Release Target:** Post v2.0. Not before the Apple platform matrix is fully shipped, instrumented, and the Hijri/astronomy + FastingModeEngine code in `IqamahCore` is settled.

**Problem:** Iqamah is intentionally Apple-native today. Every UI uses SwiftUI + Material/`.glassEffect()`; every persistence layer uses `UserDefaults` + iCloud KVS; every background mechanism (menu bar, notifications, complications, Live Activities) is Apple-specific. The portable surface (calculation engine, cities database, Hijri/Hilal astronomy, FastingModeEngine) is small, deterministic, and well-tested — but it is currently expressible only as a Swift Package (`IqamahCore`). Reaching Android, Windows, and Linux users requires either (a) a full per-platform rewrite that will inevitably drift in subtle ways (DST handling, "next prayer" selection at midnight, adjustment ordering, Hilal Odeh thresholds, fasting trigger evaluation), or (b) a deliberate, contract-driven architecture in which one shared core enforces correctness and each platform owns only its native UI.

This enhancement scopes option (b): a shared portable core with N native UIs, designed specifically for **solo agentic development via Claude Code**, where the bottleneck is verification and parity enforcement rather than per-platform expertise.

**Why the solo + Claude Code model changes the calculus:**
The traditional "N codebases to maintain forever" objection assumes human engineering hours. With agentic development, the cost shifts: agents can read 6 codebases simultaneously and apply a contract change consistently in a single session, but humans still pay the *triage and verification* cost per bug, per release, per app store. The existing EPIC/US/AC/BUG/ENH discipline in this repo (see `RELEASE_PLAN.md`, `BUGS.md`, `ID_REGISTRY.md`) is the substrate that makes agentic multi-platform tractable — without it, parity drift would be inevitable inside 3 sprints.

**Solution — five-pillar architecture:**

**Pillar 1: Promote `IqamahCore` to a language-portable core.**
Two viable paths; pick before any non-Apple platform begins.
- **1a. Rust + UniFFI (recommended)** — port `IqamahCore` to Rust (~500–1500 LOC of pure math, plus the FastingModeEngine state machine from EPIC-0017), expose via UniFFI to generate Swift, Kotlin, C#, Python, and (via WASM) TypeScript bindings automatically. Same crate consumed by every platform. UniFFI is what Firefox and 1Password use for this exact pattern. Apple targets continue calling the same API shape they call today via the auto-generated Swift wrapper; the existing `IqamahCore` Swift Package becomes a thin shim during transition, then is retired.
- **1b. Kotlin Multiplatform** — port to Kotlin/Native for iOS/macOS, JVM for Android/desktop. Better ergonomics if the team is mobile-first, less mature on Apple than option 1a. Avoid unless Android is the dominant strategic target.
- **Out of scope:** TypeScript core (forces a JS runtime everywhere), Flutter (UI framework not a portability layer), Electron (regresses Mac quality).

**Pillar 2: Golden test vector contract.**
A single `tests/vectors.json` (or `.toml`) committed to the core, containing at minimum:
- 500+ `(lat, lng, date, timezone, method, asr, adjustments) → expected_prayer_times` cases covering DST transitions, IDL crossings, polar latitudes (with appropriate fallback expectations), edge-of-day boundaries.
- 50+ Hilal Odeh vector cases (ARCL, ARCV, W → V, zone) cross-checked against the ICOP observation set already used in EPIC-0011.
- 20+ "next prayer" selection cases covering midnight rollover, day-change behaviour, and per-prayer adjustment ordering.
- 30+ FastingModeEngine cases covering each of the 9 trigger types (auto-Ramadan, weekly schedule, Ayyam al-Beed, 6 of Shawwal, Day of Arafah, first 9 of Dhul-Hijjah, Muharram fast, 15 Sha'ban, 27 Rajab) with tradition-aware gating.
Every platform's CI consumes this file. A platform that cannot pass the vectors cannot ship. This is the single most important anti-drift mechanism — it makes correctness mechanically verifiable.

**Pillar 3: Per-platform native UIs.**
Each platform target owns its UI fully; no shared UI framework is mandated.

| Platform | Recommended UI | Native conventions to honour |
|---|---|---|
| macOS | SwiftUI + Material + Liquid Glass (current) | Apple HIG, mac menu bar idioms |
| iOS / iPadOS / watchOS / tvOS / visionOS | SwiftUI (current + planned) | Apple HIG per platform |
| Android | Jetpack Compose + Material 3 | Material You dynamic colour, tile API for quick settings, Wear OS tiles if expanded later |
| Windows | WinUI 3 (preferred) or Avalonia (if cross-desktop UI sharing is desired with Linux) | Fluent Design, system tray via `NotifyIcon`, Windows notification platform |
| Linux | GTK4 (GNOME-native) or Qt6 (KDE-native) | StatusNotifierItem/AppIndicator for tray; respect XDG conventions; ship Flatpak + native packages |

Each platform's UI converts `core::PrayerTimes` / `core::FastingState` (or platform-binding equivalent) into native widgets. No `#if` matrix; no shared rendering layer.

**Pillar 4: Shared persistence schema, native persistence mechanism.**
Define `settings.v1.json` schema in the core (extending the existing `SettingsManager` schema including Fasting Mode triggers and tradition gating). Each platform reads/writes its native store (`UserDefaults` on Apple, `SharedPreferences`/DataStore on Android, Registry/`%APPDATA%` on Windows, `~/.config/iqamah/` on Linux per XDG) but the *payload shape* is identical across all of them. Sync is per-ecosystem (iCloud KVS on Apple; Google account sync on Android; no automatic cross-ecosystem sync in v1 — explicit "export settings" / "import settings" is the v1 bridge between ecosystems).

**Pillar 5: Anti-drift governance.**
- **Tagged ACs in RELEASE_PLAN.md.** Every AC gets a `platforms: [...]` tag and a `deferred: [...]` tag. PRs touching shared behaviour must update all relevant platforms or explicitly defer with justification. Add a `/parity-check` slash command that audits the AC × platform matrix weekly.
- **Semver on the core.** `IqamahCore 1.x → 2.x` triggers a release-train obligation; all platforms must adopt within N weeks of a minor bump or it becomes a release blocker.
- **Cross-platform release train.** Releases are gated on *all* shipping platforms reaching the milestone, not the fastest one. Reduces "Mac is on 2.1, Linux is on 1.4" rot.
- **Per-platform Claude Code subagents.** Define `android-dev`, `windows-dev`, `linux-dev`, `rust-core-dev` in `.claude/agents/`. Each subagent's system prompt holds that platform's conventions (Material 3, Fluent, GNOME HIG, Rust idioms). The main agent dispatches in parallel: "implement [AC-XXXX] on all targets" → N concurrent subagent invocations, each loading only its slice of the monorepo to conserve context.
- **Screenshot snapshot tests in CI per platform.** Paparazzi (Android), `swift-snapshot-testing` (Apple, already in use — see EPIC-0017's FastingBanner/FastingModeSection snapshot suite), WinAppDriver (Windows), GTK headless rendering (Linux). Claude reads diffs; humans review the visual deltas the agent flags.

**Recommended sequencing — staged validation, not big-bang:**
| Stage | Scope | Cumulative effort | Decision gate |
|---|---|---|---|
| 0 | Extract `IqamahCore` (including FastingModeEngine) → Rust + UniFFI; prove parity in existing Swift apps; existing test suite passes | ~2–3 weeks | Apple builds bit-identical outputs to today |
| 1 | Add Android (Kotlin + Jetpack Compose); first non-Apple consumer of the core | ~4–6 weeks on top of stage 0 | Contract holds with two ecosystems; vector tests green on both |
| 2 | Add Linux (GTK4, Flatpak distribution) | ~3–4 weeks on top of stage 1 | Cheapest desktop expansion; Linux users tolerant of rough edges |
| 3 | Add Windows (WinUI 3, MSIX, Microsoft Store) | ~3–4 weeks on top of stage 2 | Highest polish bar; do last when the contract is battle-tested |

Total scope across all stages: **3–4 months of focused agentic development**, assuming the existing Claude Code workflow continues to drive each platform.

**What is explicitly NOT in scope for ENH-0027:**
- Web app (separate ENH if pursued — different sync, different distribution, different UI ecosystem)
- Cross-ecosystem settings sync (rely on per-ecosystem cloud + manual export/import in v1)
- Adhan audio parity with Apple (each platform's notification system has different limits; document the divergence rather than fight it — ENH-0024's Critical Alerts pattern is Apple-only)
- Live Activity parity (Apple-only platform feature; Android has its own foreground service notifications that need a separate native implementation)
- Wear OS, Tizen, KaiOS, or any non-flagship platform

**Risks and mitigations:**
- **Risk: Rust core becomes a bottleneck for solo iteration.** Mitigation: invest heavily in `cargo` ergonomics, snapshot tests, and `IqamahCore`-side documentation so agents can navigate the Rust crate as fluently as Swift.
- **Risk: Code signing / store submission overhead multiplies (Apple + Google + Microsoft).** Mitigation: automate via `fastlane`, `bundletool`, `msstore` CLIs; capture the credential ceremony in `docs/RELEASE_RUNBOOK.md`.
- **Risk: Visual verification can't be fully agentic on platforms you don't own.** Mitigation: snapshot tests in CI per platform; budget for at least one physical device per major ecosystem (used Pixel for Android, used Surface for Windows, any laptop for Linux).
- **Risk: Bug reports require 6 fixes.** Mitigation: triage stays human; fix application is agentic. The `BUGS.md` register scales linearly; ad-hoc bug handling does not.
- **Risk: Context window cost balloons holding 6 codebases.** Mitigation: per-platform subagents with per-platform `CLAUDE.md` files; main agent never loads all 6 simultaneously.

**Acceptance criteria (when promoted to an Epic — likely multiple Epics, one per stage):**
- [ ] `IqamahCore` exists as a Rust crate, exposed via UniFFI, consumed bit-identically by all existing Apple targets (macOS, iOS, watchOS); existing test suite (including the EPIC-0017 FastingModeEngine tests) passes unchanged
- [ ] `tests/vectors.json` exists with ≥500 prayer-time cases, ≥50 Hilal cases, ≥20 next-prayer cases, ≥30 FastingModeEngine cases; CI on every platform consumes it; failure is a merge-blocker
- [ ] `RELEASE_PLAN.md` ACs carry `platforms:` and `deferred:` tags; `/parity-check` slash command exists and runs in CI weekly
- [ ] Android app reaches feature parity with iOS for prayer times, Qibla, settings, notifications, Fasting Mode, and at least one home-screen widget
- [ ] Linux app reaches feature parity with macOS for prayer times, system tray, notifications, settings, Fasting Mode; ships as Flatpak
- [ ] Windows app reaches feature parity with macOS for prayer times, system tray, notifications, settings, Fasting Mode; ships via Microsoft Store
- [ ] Per-platform Claude Code subagents are defined in `.claude/agents/` and used in the standard development workflow
- [ ] `docs/RELEASE_RUNBOOK.md` documents the cross-platform release-train process and per-store credentialing
- [ ] No `IqamahCore` minor version goes more than N weeks without adoption by all shipping platforms

**Cross-references:**
- The existing **Multi-Platform Migration Assessment** (below in this file) covers the *intra-Apple* extraction that is the prerequisite for ENH-0027; ENH-0027 extends rather than replaces it.
- **EPIC-0010 (iOS)**, **EPIC-0012 (Watch)**, and **EPIC-0017 (Fasting Mode)** validated the `IqamahCore` Swift Package boundary that ENH-0027 promotes to a language-portable contract.
- **ENH-0019 (i18n)** should ship first; adding a translation per platform is cheaper than adding a platform per language.
- **ENH-0020 (tvOS)** and **ENH-0021 (visionOS)** complete the Apple matrix and should ship before ENH-0027 begins — they exercise the core contract on platforms with no notifications / no touch input, which surfaces edge cases that would otherwise appear first on Android/Linux.
- **ENH-0022 (Islamic Holiday Reminders)** should also ship Apple-side first; the celebration calendar then ports cleanly as part of the shared core.
- **ENH-0024 (Critical Alerts)** and **ENH-0026 (Live Activity)** are explicitly Apple-only and are NOT part of the parity contract.
- **CLAUDE.md** UI Conventions (Material, Liquid Glass, light/dark parity) apply *only* to Apple targets; each new ecosystem defines its own equivalent conventions in its own `CLAUDE.md` under its target subfolder.

**Effort:** Large — 3–4 months across all stages for solo agentic development. Stage 0 alone (Rust extraction) is 2–3 weeks and unlocks every subsequent stage. Recommend treating each stage as a standalone Epic with explicit go/no-go gates.

**Files (when implemented — illustrative monorepo layout):**
```
core/                         # Rust crate, UniFFI-exposed
  src/
    prayer_calculator.rs
    hilal.rs
    cities.rs
    fasting_mode.rs           # ported from EPIC-0017
    settings_schema.rs
  tests/
    vectors.json              # the contract
apps/
  apple/                      # existing iqamah.xcodeproj, consumes core via auto-generated Swift bindings
  android/                    # new — Kotlin + Compose
  windows/                    # new — WinUI 3 or Avalonia
  linux/                      # new — GTK4 + Flatpak
.claude/
  agents/
    rust-core-dev.md
    android-dev.md
    windows-dev.md
    linux-dev.md
  commands/
    parity-check.md
docs/
  RELEASE_RUNBOOK.md          # new — per-store credentialing + release-train
  PARITY_MATRIX.md            # generated by /parity-check
```

**External references:**
- UniFFI (Mozilla): [github.com/mozilla/uniffi-rs](https://github.com/mozilla/uniffi-rs)
- Kotlin Multiplatform: [kotlinlang.org/docs/multiplatform.html](https://kotlinlang.org/docs/multiplatform.html)
- Signal's shared-core architecture (industry reference for this pattern): [signal.org/blog/](https://signal.org/blog/)
- WinUI 3: [learn.microsoft.com/en-us/windows/apps/winui/winui3/](https://learn.microsoft.com/en-us/windows/apps/winui/winui3/)
- Avalonia (cross-desktop alternative): [avaloniaui.net](https://avaloniaui.net)

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
