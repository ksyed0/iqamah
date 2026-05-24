# Iqamah v1.6.0 Release Notes

**Release date:** 2026-XX-XX (TBD when submitted)
**Build:** 15
**Platforms:** macOS 14+, iOS 17+, watchOS 26+

## 🌟 New in this release

### Fasting Mode (EPIC-0017)

Comprehensive support for Islamic fasting traditions — automatic Ramadan, weekly Sunnah days, Hijri-anchored special days, and Shia-specific observances. All Sunni and Shia methods supported. A single pure-functional `FastingModeEngine` in `IqamahCore` decides "is today a fasting day" and feeds every glanceable surface (menu bar, popover, iOS hero card, watch, widgets, Live Activity).

**Triggers (9, independently toggleable):**

- `autoRamadan` — automatic Ramadan detection from the Hijri calendar
- `weeklySchedule` — Monday and/or Thursday weekly Sunnah
- `ayyamAlBeed` — 13/14/15 of every Hijri month ("white days")
- `sixDaysShawwal` — 2–7 Shawwal (six days following Eid al-Fitr)
- `dayOfArafah` — 9 Dhul-Hijjah
- `firstNineDhulHijjah` — 1–9 Dhul-Hijjah
- `muharramFast` — Tasu'a (Shia) / Ashura 9+10 Muharram (Sunni)
- `midShaban` — 15 Sha'ban (method-gated to Shia)
- `mabath` — 27 Rajab (method-gated to Shia)

**Prohibitions (5, hard-suppress mode at runtime):**

- `eidAlFitr` (1 Shawwal)
- `eidAlAdha` (10 Dhul-Hijjah)
- `tashriq11`, `tashriq12`, `tashriq13` (11/12/13 Dhul-Hijjah)

**Notifications:** Suhoor reminder (configurable 5–120 min lead), Iftar reminder (configurable 5–120 min lead, separate setting), optional day-before reminder at a user-picked time. Day-before is suppressed for Ramadan days 2–30 to avoid noise.

**UI:** Live banner on the macOS popover, iOS hero card with 🌙 + purple gradient (Ramadan) or 🕗 + teal gradient (Nawafil), watchOS prayer-tab indicator, widget labelling, Live Activity treatment.

**Settings:** Full configuration UI on macOS and iOS (master toggle, per-trigger toggles, lead-time pickers, calculation-method-gated visibility for Shia-emphasis triggers). Simpler master toggle on watchOS.

Shipped across PRs #132 (foundation), #136 (UI wiring), #137 (settings UI), #138 (schedulers + close-out), #139 (snapshot coverage).

### Better location detection (BUG-0069 fix)

- **"Current Location" row** at the top of city pickers showing your actual geocoded locality.
- **Pre-resolved geocoder** so the picker shows e.g. "Airdrie" instead of snapping to "Calgary" purely by nearest-city distance.
- **Opt-in 25 km auto-detect** — prompts to switch cities when you've moved more than 25 km from your saved city. Off by default; new `autoDetectOnMove` setting.

Shipped in PR #140.

### Live Activity / Dynamic Island fixes

- Live Activity now advances past a passed prayer when the app is foregrounded or recently backgrounded (PR #133 — foreground `Timer` re-evaluates `ContentState` at the next prayer boundary).
- `staleDate` set so iOS dims the Live Activity after a prayer passes rather than showing a "live" stale time.

### macOS polish

- **Start on Login** toggle now surfaces actual error messages from `SMAppService` (PR #133) instead of failing silently.
- Top-bar buttons (Qiblah, Settings, About, Mute) now have labels and better spacing.
- iOS CFBundleVersion uses the `CURRENT_PROJECT_VERSION` build-setting substitution so the App Store version-validation gate works correctly across all targets (PR #134).

### Developer-facing improvements

- **272 IqamahCore tests** (up from 251 at v1.5.0) — Fasting Mode adds `FastingModeEngineTests`, `FastingModeTypesTests`, `FastingLabelFormatterTests`, `FastingNotificationPlannerTests`, and `FastingModeSettingsCodecTests`.
- **23 snapshot tests** (up from 9) — now covering `FastingBanner`, `FastingModeSection` settings UI, and the prior macOS / iOS / widget surfaces.
- **ENH IDs renumbered to ENH-XXXX** four-digit format (matches `BUG-XXXX`, `EPIC-XXXX`, etc.) — closed in PR #141.
- **BUG-0068** (App Store rejection of v1.5 (13) watch icon) and **BUG-0069** (location detect / city picker) closed.

## ⚠️ Known limitations

### Live Activity may drift if app is fully suspended

Iqamah's Live Activity / Dynamic Island (iOS) shows your next prayer and updates automatically when the app is open or recently backgrounded. If iOS suspends the app for an extended period (memory pressure, device restart, or several hours of background time), the Live Activity may briefly show a passed prayer until you reopen the app, at which point it refreshes within ~2 seconds.

This is a known limitation of client-only Live Activity updates. A full fix requires push-driven updates via backend infrastructure — tracked as [ENH-0026](ENHANCEMENTS.md#enh-0026) (design spec at [2026-05-24-enh-0026-push-driven-notifications-design.md](superpowers/specs/2026-05-24-enh-0026-push-driven-notifications-design.md)) and planned for a future release.

**Workaround:** open Iqamah briefly to refresh the Live Activity. The prayer-time notifications themselves (Adhan, Suhoor reminder, Iftar reminder) are unaffected and continue to fire reliably from local scheduling.

## 🛠 Changes by area

### Core (`IqamahCore`)

- `feat(core): Fasting Mode foundation (Tasks 1–9 of EPIC-0017)` — PR #132
- `refactor(activitykit): consolidate PrayerActivityAttributes into single source`

### iOS

- `feat(ui): Fasting Mode UI wiring (Tasks 10–14 of EPIC-0017)` — PR #136
- `feat(ui): Fasting Mode settings UI (Tasks 15–16 of EPIC-0017)` — PR #137
- `feat(ios): v1.6 re-detect prompt for legacy users (AC-0351, AC-0352)`
- `fix(BUG-0069): show detected city in picker + opt-in 25km auto-detect` — PR #140
- `fix(ios): use CURRENT_PROJECT_VERSION substitution for CFBundleVersion` — PR #134
- `fix(ios): migrate Activity.end to iOS 16.2+ signature`
- `chore(ios): drop redundant openSettingsForReDetect notification post`

### macOS

- `fix(v1.6.0): LA rollover, Start-on-Login errors, macOS toolbar polish, ENH-025` — PR #133
- `feat(macos): v1.6 re-detect prompt for legacy users (AC-0351, AC-0352)`
- `refactor(macos): use applyGeocodingRefinement helper in LocationSetupView`

### watchOS

- `feat(watch): add CLGeocoder refinement after GPS detect (ENH-001 Option B parity)`
- `refactor(watch): rename LocationSetupView to WatchLocationSetupView`
- `fix(watch): drop non-Sendable settings capture in CLGeocoder Task closure`
- `fix(watch-icon): WatchAppIconView with 3 design variants for BUG-0068`
- `fix(watch-icon): replace asset with variant B (lighter navy) — BUG-0068`
- `fix(watch-icon): reset PNG DPI to 72 (BUG-0068 follow-up)`
- `fix(icon-export): emit PNGs at 72 DPI via ImageRenderer instead of NSHostingView`

### Notifications / Live Activity / Widgets

- `feat(notifications): Fasting Mode schedulers + EPIC-0017 close-out (Tasks 17–21)` — PR #138

### Settings

- `feat(settings): add v1.6 re-detect prompt flag + legacy-user detection`
- `feat(ux): highlight Detect-location button after v1.6 legacy GPS prompt`

### Tooling / CI / cleanup

- `tooling: CLI watch-icon exporter + IconExporterView UI for BUG-0068`
- `chore: gate icon-export dev tooling behind #if DEBUG`
- `chore: bump build number to 14 across all targets`
- `chore: delete dead repo-root Views/ directory`
- `style: fix SwiftFormat indentation + remove force-unwrap (CI unblocker)`

### Tests

- `test(snapshots): add FastingBanner + FastingModeSection visual regression` — PR #139

### Docs

- `docs: design spec for Fasting Mode (ENH-002 expanded)`
- `docs: implementation plan for Fasting Mode (ENH-002 / EPIC-0017)`
- `docs(plan): expand Tasks 10-21 to full TDD detail for Fasting Mode`
- `docs(fasting-mode): finalize Sunni Muharram label as 'Ashura (9+10 Muharram)'`
- `docs: design spec for ENH-001 finish-up (watch parity + v1.6 prompt + cleanup)`
- `docs: implementation plan for ENH-001 finish-up`
- `docs: ENH-001 closeout + CLAUDE.md project structure note`
- `docs: promote ENH-001 finish-up to EPIC-0016 + add TC-0036-0043`
- `docs(bugs): log BUG-0068 — App Store rejection of v1.5 (13) watch icon`
- `docs(enhancements): add ENH-023 Adhaan Surround Mode + ENH-024 silent-switch bypass check`
- `docs(enhancements): expand ENH-024 with audit findings`
- `docs: log ENH-026 background LA + clarify iOS xcodebuild scheme` — PR #135
- `docs: log ENH-0027 — Cross-Ecosystem Expansion (Windows/Linux/Android)` — PR #144
- `docs: close BUG-0068/BUG-0069 + renumber ENH IDs to 4-digit format` — PR #141

## Migration notes

- `FastingModeSettings` is forward-compatible via a custom `Codable init(from:)` — no migration required from v1.5.x.
- iCloud KVS keys unchanged for existing settings; new `fastingModeSettings` and `autoDetectOnMove` keys added.
- App Store version is **15**; any TestFlight build below 15 will be replaced on upload.
