# Fasting Mode (ENH-002) — Design

**Date:** 2026-05-21
**Status:** Draft → ready for plan
**Tracking:** ENH-002 (docs/ENHANCEMENTS.md) — expanded from "Ramadan Mode" to generalized "Fasting Mode"
**Effort:** Medium (~2–3 weeks development + 1 week QA across all surfaces)
**Promotion target:** EPIC-0017 / US-0071–US-0075 / AC-0357–AC-0382 / TC-0044–TC-0069

---

## Background

ENH-002 was originally specced as "Ramadan Mode (Suhoor & Iftar Countdowns)" — auto-detect Ramadan via Hijri calendar and show Suhoor/Iftar countdowns in the macOS menu bar and iOS header. During brainstorming on 2026-05-21 the scope generalized significantly:

- Renamed to **Fasting Mode** to cover both Ramadan and year-round Nawafil (supererogatory) fasts
- Activation expanded from "auto-Ramadan" to a set of nine independently-toggleable triggers covering the canonical Sunnah fasting days from authentic hadith
- Surfaces expanded from menu bar + iOS header to **all** glanceable surfaces (menu bar, popover, iOS hero, watch, widgets, Live Activity)
- Added **Ja'fari calculation method** (alongside the existing Tehran method) and tradition-aware UI gating for Muharram/Sha'ban/Rajab fasts
- Added user-configurable Suhoor and Iftar reminder lead times (5–120 minutes, separate) plus night-before reminders with Ramadan-aware skip logic

## Goals

1. **Single source of truth** — one pure-functional `FastingModeEngine` in `IqamahCore` decides "is today a fasting day" and feeds every surface
2. **Tradition-neutral data model** — the engine knows about Hijri dates and weekdays, not about sect; sect-aware framing is a UI concern derived from the user's calculation method
3. **Respect the user's existing prayer-time configuration** — the calculation method drives both prayer timings and tradition framing; users never declare their sect explicitly
4. **Notifications scale with practice** — separate Suhoor/Iftar lead times because the practical needs differ (cooking Suhoor vs setting the table for Iftar)
5. **No surprise behavior** — toggles default off; auto-Ramadan defaults on but only fires when the user has Fasting Mode itself enabled

## Out of scope (deferred to future ENHs)

- **Celebration reminders for Islamic holidays** (Eid al-Fitr, Eid al-Adha, Mawlid, Laylat al-Qadr, Hijri new year, Ashura commemorations) — distinct concept from fasting; tracked as a new ENH-022 stub in `docs/ENHANCEMENTS.md`
- **Customizable 6-of-Shawwal day selection** — v1 picks 2–7 Shawwal automatically (Eid is day 1, always excluded). A future enhancement could let users pick any 6 days in Shawwal
- **"Most of Sha'ban" trigger** — the hadith says "most of" without a specific date range. Users can use the weekly schedule to cover Sha'ban Mondays/Thursdays; auto-triggering an arbitrary date range overreaches
- **Per-prayer Maghrib delay tuning for Ja'fari users** — the Ja'fari calculation method's encoded Maghrib delay is sufficient; manual offsets are already available via the existing `prayerAdjustments` system

---

## Decisions captured during brainstorming

1. **Surface scope:** All five glanceable surfaces (menu bar, popover, iOS hero, watch, widgets, Live Activity)
2. **Behavior:** Additive — standard next-prayer countdown remains; Suhoor/Iftar treatment activates within 2 hours of Fajr/Maghrib on fasting days
3. **Display treatment:** Option D (hybrid) — narrow surfaces (menu bar, watch, widgets) use relabel; wide surfaces (iOS hero card, macOS popover) get a dedicated banner
4. **Override:** Auto + master Settings toggle to disable. Disabled state hides all sub-controls
5. **Visual differentiation:** Subtler outside Ramadan — 🌙 + purple gradient for Ramadan; 🕗 + teal gradient for Nawafil days
6. **Trigger scope:** All 9 triggers (auto-Ramadan, weekly schedule, Ayyam al-Beed, 6 of Shawwal, Day of Arafah, first 9 of Dhul-Hijjah, Muharram fast, 15 Sha'ban, 27 Rajab) with method-gated visibility for Shia-emphasis ones
7. **Exclusion handling:** Hard-prohibited absolute dates (Eid al-Fitr, Eid al-Adha, Tashriq 11/12/13) suppress mode at runtime + show informational banner. Soft-discouraged patterns (Friday-alone, Saturday-alone) get configuration-time warnings only
8. **Reminders:** Suhoor + Iftar lead times separate, both 5–120 min in 5-min steps. Day-before reminder at user-picked time; skipped for Ramadan days 2–30, included for Ramadan day 1 and Nawafil days
9. **Tradition gating:** Calculation method (`.tehran` or `.jafari` → `isShiaMethod`) implicitly drives Muharram label (Tasu'a vs Ashura) and visibility of 15 Sha'ban / 27 Rajab triggers
10. **New calculation method:** Add `.jafari` alongside `.tehran` to serve Shia communities outside Iran

---

## Recommended Fasting Days — Research Summary

Sources: Sahih al-Bukhari, Sahih Muslim, Sunan Abu Dawud, Sunan al-Tirmidhi, Sunan Ibn Majah.

| # | Fast | Hijri/Greg | Frequency | Strength | Note |
|---|---|---|---|---|---|
| 1 | Mondays & Thursdays | Greg weekday | Weekly year-round | Strongly recommended | Prophet's regular practice |
| 2 | Ayyam al-Beed (White Days) | 13/14/15 of every Hijri month | Monthly | Strongly recommended | Full-moon days |
| 3 | 6 days of Shawwal | 2–7 Shawwal (Eid is day 1) | Annual | Strongly recommended | "Ramadan + 6 of Shawwal = full year" — Muslim |
| 4 | Day of Arafah | 9 Dhul-Hijjah | Annual | Highly emphasized | Expiates two years of sins |
| 5 | First 9 days of Dhul-Hijjah | 1–9 Dhul-Hijjah | Annual | Recommended | Arafah is the strongest |
| 6 | Muharram fast | 9+10 Muharram (Sunni) or 9 only (Shia) | Annual | Strongly recommended (varies by tradition) | See Tradition-Aware section |
| 7 | 15 Sha'ban (Laylat al-Bara'ah) | 15 Sha'ban | Annual | Recommended (stronger emphasis in Shia tradition) | Method-gated UI |
| 8 | 27 Rajab (Mab'ath an-Nabi) | 27 Rajab | Annual | Recommended (stronger emphasis in Shia tradition) | Method-gated UI |

**Hard-prohibited days** (engine always suppresses, regardless of toggles):

| Day | Hijri | Why |
|---|---|---|
| Eid al-Fitr | 1 Shawwal | Forbidden — celebration |
| Eid al-Adha | 10 Dhul-Hijjah | Forbidden — celebration |
| Tashriq 11 | 11 Dhul-Hijjah | Forbidden — part of Hajj/Eid |
| Tashriq 12 | 12 Dhul-Hijjah | Forbidden |
| Tashriq 13 | 13 Dhul-Hijjah | Forbidden |

**Soft-discouraged patterns** (configuration-time warning only, no engine suppression):

- Friday in weekly schedule without Thursday or Saturday
- Saturday in weekly schedule without Friday (canonical Sunnah pairing is Fri+Sat)

---

## Activation Model

**`FastingDayState`** is the pure-data result of evaluating today against the user's `FastingModeSettings`:

```swift
public struct FastingDayState: Equatable {
    public let isActive: Bool                 // is today a fasting day?
    public let trigger: FastingTriggerKind?   // why active (nil if inactive)
    public let prohibition: ProhibitedDay?    // hard-prohibited override
    public let date: Date                     // the day (midnight in tz)
}

public enum FastingTriggerKind: String, Codable {
    case autoRamadan, weeklySchedule, ayyamAlBeed,
         sixDaysShawwal, dayOfArafah, firstNineDhulHijjah,
         muharramFast, midShaban, mabath
}

public enum ProhibitedDay: String, Codable {
    case eidAlFitr, eidAlAdha,
         tashriq11, tashriq12, tashriq13
}
```

**Engine evaluation order:**

1. If `settings.enabled == false` → return `isActive=false, trigger=nil, prohibition=nil`
2. Compute today's Hijri date (using `Calendar(identifier: settings.hijriCalendarIdentifier)` + `hijriDayOffset` from existing SettingsManager)
3. Check **prohibited days** first — if today matches any, return `isActive=false, prohibition=<matched>`
4. Walk triggers in priority order (so the returned `trigger` value is deterministic when multiple match):
   1. `autoRamadan` (most general — covers all 30 days of month 9)
   2. `dayOfArafah` (highest priority among Dhul-Hijjah triggers — wins over firstNineDhulHijjah on day 9)
   3. `firstNineDhulHijjah`
   4. `muharramFast` (date depends on calculation method — see Tradition-Aware section)
   5. `ayyamAlBeed`
   6. `sixDaysShawwal`
   7. `midShaban` (suppressed if `!calculationMethod.isShiaMethod`)
   8. `mabath` (suppressed if `!calculationMethod.isShiaMethod`)
   9. `weeklySchedule` (least specific — runs last)
5. Return `isActive=true, trigger=<first match>` or `isActive=false` if no match

**`midShaban` / `mabath` engine-level suppression** (when method is not Shia) means a user can never accidentally fast on a hidden trigger — even if their stored toggle is true from a previous Tehran/Ja'fari period.

---

## Tradition-Aware UI Gating

The user's `calculationMethod` implicitly signals tradition. `isShiaMethod` is true for `.tehran` and `.jafari`, false otherwise.

**Muharram fast (`.muharramFast` trigger):**

| Method | Date(s) fired | Label | Subtitle |
|---|---|---|---|
| Sunni (MWL, ISNA, Egypt, Umm al-Qura, Karachi) | 9 + 10 Muharram | "Ashura (9+10 Muharram)" | "Sunni Sunnah fast" |
| Shia (Tehran, Ja'fari) | 9 Muharram only | "Tasu'a (9 Muharram)" | "Shia tradition: commemoration day" |

The trigger enum value is the same (`.muharramFast`); the date set and label are method-dependent at evaluation time. The engine reads the method from the passed-in settings struct.

**Settings UI visibility:**

| Trigger | Visible when method is Shia | Visible when method is Sunni |
|---|---|---|
| autoRamadan, weeklySchedule, ayyamAlBeed, sixDaysShawwal, dayOfArafah, firstNineDhulHijjah, muharramFast | ✅ | ✅ |
| midShaban (15 Sha'ban) | ✅ | ❌ hidden |
| mabath (27 Rajab) | ✅ | ❌ hidden |

**Toggle persistence:** Stored toggle state survives method changes. If a user enables `midShaban` while on Tehran, then switches to MWL, the toggle is hidden in Settings AND suppressed in the engine — but the underlying `Bool` remains `true`. Switching back to Tehran restores visibility with the prior preference intact.

**Why this design:** The app never asks "are you Sunni or Shia?" — that's intrusive and reductive. The calculation method is a functional setting the user has already chosen; it's a reliable enough signal to drive tradition-aware UI without prescribing.

---

## Display Treatment (Option D — hybrid)

### Narrow surfaces — relabel only

When `state.isActive == true` AND now is within 2 hours of Fajr or Maghrib:

| Surface | Behavior |
|---|---|
| **macOS menu bar** | `Fajr 5:12 (42m)` → `🌙 Suhoor 5:12 (42m)` during Ramadan; `🕗 Suhoor 5:12 (42m)` during Nawafil. Same swap for Maghrib → Iftar |
| **watchOS prayer tab** | Same relabel applied to the row's prayer name |
| **WidgetKit widgets** (iOS home, macOS Notification Center, watchOS complications) | Same relabel on the next-prayer name field |
| **Live Activity** | ContentState carries `fastingActive` + `fastingTriggerRaw`; LA view applies same relabel |

### Wide surfaces — banner

When `state.isActive == true` OR `state.prohibition != nil`:

| Surface | Banner placement |
|---|---|
| **macOS popover** (`MenuBarPopoverView`) | Above the prayer list |
| **iOS hero card** (`PrayerHeroCard`) | Above the next-prayer block |

**Banner content (active state):**

- Ramadan: purple gradient (`#2a1a3a` → `#1a2a3a`), 🌙 icon, dual countdown:
  - `Suhoor ends 5:12 AM (42m)`
  - `Iftar at 8:32 PM`
- Nawafil: teal gradient (`#1a3a3a` → `#1a2a3a`), 🕗 icon, same dual countdown layout

**Banner content (prohibition state):**

Grey gradient (`#2a2a2a` → `#1a1a1a`), ⚠️ icon, e.g. *"Eid al-Adha (10 Dhul-Hijjah) — fasting is forbidden today"*

**Prayer times list itself:** Always shows Fajr/Sunrise/Dhuhr/Asr/Maghrib/Isha rows unchanged. Relabel is countdown-only.

---

## Settings UI

New section in `SettingsSheetView` (shared between macOS and iOS):

```
┌─ Fasting Mode ─────────────────────────────────┐
│ Enable Fasting Mode                  [○━━]    │  ← master (off hides all below)
└────────────────────────────────────────────────┘
```

**Expanded when master is on:**

```
┌─ Fasting Mode ─────────────────────────────────┐
│ Enable Fasting Mode                  [━━●]    │
│                                                │
│ ── When to activate ──                         │
│ Auto-enable during Ramadan           [━━●]    │
│                                                │
│ Weekly schedule                                │
│   [M] [T] [W] [Th] [F] [S] [Su]               │
│   ⚠ Friday alone is discouraged. Consider     │  ← inline warning (Fri-alone)
│     adding Thursday or Saturday.               │
│                                                │
│ Monthly: Ayyam al-Beed (13–15)        [○━━]   │
│ Annual: 6 days of Shawwal             [○━━]   │
│ Annual: Day of Arafah (9 Dhul-Hijjah) [○━━]   │
│ Annual: First 9 of Dhul-Hijjah        [○━━]   │
│ Annual: <method-adaptive label>       [○━━]   │  ← see below
│ Annual: 15 Sha'ban (Laylat al-Bara'ah)[○━━]   │  ← Shia methods only
│ Annual: 27 Rajab (Mab'ath an-Nabi)    [○━━]   │  ← Shia methods only
│                                                │
│ ── Reminders ──                                │
│ Send system notifications            [━━●]    │  ← master for all reminders
│ Suhoor reminder lead time            [30 min ▾]│  ← 5–120 min, step 5
│ Iftar reminder lead time             [15 min ▾]│  ← 5–120 min, step 5
│ Notify night before fasting day      [━━●]    │
│   Day-before reminder time          [8:00 PM ▾]│  ← time-of-day picker
└────────────────────────────────────────────────┘
```

**Muharram fast row label adapts** based on `settings.calculationMethod.isShiaMethod`:

| isShiaMethod | Label | Subtitle |
|---|---|---|
| false | "Ashura (9+10 Muharram)" | "Sunni Sunnah fast" |
| true | "Tasu'a (9 Muharram)" | "Shia tradition: commemoration day" |

**watchOS Settings:** shows only the master toggle + a "Configure on iPhone/Mac" navigation link. Full configuration done on phone/Mac and synced via iCloud KVS.

**First-launch prompt:** When Ramadan begins and Fasting Mode has never been enabled, show a one-time banner above the prayer list: *"Ramadan begins today — turn on Fasting Mode for Suhoor/Iftar countdowns?"* with **Enable** / **Not now** buttons. Sets `didShowFastingModePromo = true` either way.

---

## Notifications

Three reminder kinds, gated by the master "Send system notifications" toggle:

| Reminder | Fires at | Default | Range |
|---|---|---|---|
| Suhoor | `Fajr − suhoorLeadMinutes` on fasting day | 30 min | 5–120 min, step 5 |
| Iftar | `Maghrib − iftarLeadMinutes` on fasting day | 15 min | 5–120 min, step 5 |
| Day-before | User-picked time of day on evening before fasting day | 8:00 PM | Any hour:minute |

**Day-before logic:**

| Tomorrow is… | Day-before fires? |
|---|---|
| Ramadan day 1 (1 Ramadan) | ✅ Yes — "Ramadan begins tomorrow" |
| Ramadan days 2–30 | ❌ No — user is already in the rhythm |
| Any Nawafil fasting day (weekly schedule, Ayyam al-Beed, Arafah, Ashura, 6 Shawwal, first 9 Dhul-Hijjah, 15 Sha'ban, 27 Rajab) | ✅ Yes |
| Hard-prohibited day (Eid, Tashriq) | ❌ No — no reminder for impermissible fast |

**Notification bodies:**

| Kind | Ramadan | Nawafil |
|---|---|---|
| Suhoor | *"🌙 Suhoor ends in {N} min — Fajr at {time}"* | *"🕗 Suhoor ends in {N} min — Fajr at {time}"* |
| Iftar | *"🌙 Iftar in {N} min — Maghrib at {time}"* | *"🕗 Iftar in {N} min — Maghrib at {time}"* |
| Day-before (Ramadan day 1) | *"🌙 Ramadan begins tomorrow — first Suhoor at {Fajr}"* | n/a |
| Day-before (Nawafil) | n/a | *"🕗 Fasting tomorrow — Suhoor at {Fajr}"* |

**Identifiers (used for cancellation/replacement):**

- `fastingmode.suhoor.{yyyy-MM-dd}`
- `fastingmode.iftar.{yyyy-MM-dd}`
- `fastingmode.daybefore.{yyyy-MM-dd}` — date is the *upcoming* fasting day

**Scheduling strategy:**

- **Rolling 7-day window.** Re-schedule on: midnight rollover (existing timer), any Fasting Mode settings change (debounced 500 ms), city change, calculation method change.
- **iOS pending notification cap is 64.** 7 days × 3 notifications = 21 slots; existing 5 prayers × 10 days adhaan schedule = 50 slots. Total: 71. **Mitigation:** trim adhaan schedule to 7 days (parity with Fasting Mode window) — separate small adjustment in NotificationScheduler. Net: 21 + 35 = 56, safe under cap.

**Permission-denied UI:** Settings shows an "Enable in System Settings" row with deep link:

- iOS: `URL(string: UIApplication.openSettingsURLString)` → `UIApplication.shared.open`
- macOS: `URL(string: "x-apple.systempreferences:com.apple.preference.notifications")` → `NSWorkspace.shared.open`
- watchOS: static help text *"Enable in iPhone → Settings → Notifications → Iqamah"*

---

## Architecture

### Where logic lives

**`IqamahCore` (pure, cross-platform):**

- `FastingMode.swift` (new) — value types: `FastingDayState`, `FastingTriggerKind`, `ProhibitedDay`, `FastingModeSettings`, `FastingTriggerStyle`
- `FastingModeEngine.swift` (new) — pure static `evaluate(for:settings:hijriCalendar:timezone:) -> FastingDayState`
- `FastingLabelFormatter.swift` (new) — pure helpers: `prayerLabel(state:prayerName:within2hWindow:isShiaMethod:) -> String`, returns relabeled name + glyph
- `FastingNotificationPlanner.swift` (new) — pure helpers: `planSuhoor(for:fajr:settings:) -> NotificationPlan?`, `planIftar(...)`, `planDayBefore(for:settings:hijri:)`

**Shared iOS+macOS UI (in `iqamah/Views/Shared/`, referenced by both `iqamah` and `iqamah-iOS` targets in pbxproj):**

- `FastingBanner.swift` (new) — SwiftUI banner view using `Material` chrome + gradient tints

**Platform-specific:**

- `iqamah/AppDelegate.swift` — menu bar relabel
- `iqamah/Views/MenuBarPopoverView.swift` — popover banner
- `iqamah/iOS/PrayerHeroCard.swift` — iOS hero banner
- `iqamah/iOS/PrayerRowMobileView.swift` — iOS row relabel
- `IqamahWatch/PrayerTimesTab.swift` — watch row relabel
- `IqamahWidget/IqamahWidget.swift` — widget relabel
- `IqamahLiveActivity/PrayerLiveActivityView.swift` — LA view relabel
- `iqamah/FastingNotificationScheduler.swift` (new) — macOS UNUserNotificationCenter wrapper
- `iqamah/iOS/NotificationScheduler.swift` — extended for fasting reminders
- `IqamahWatch/WatchNotificationScheduler.swift` — extended for fasting reminders

### No caching

The engine is pure math (~5 Calendar component extractions, microsecond cost). No `@Published` cached value. Each render site calls `FastingModeEngine.evaluate(for: Date(), settings: ..., hijriCalendar: ..., timezone: ...)`. Settings changes propagate naturally because the underlying `@Published var fastingModeSettings: FastingModeSettings` is observed by SwiftUI.

### Single JSON-encoded settings blob

All 13 Fasting Mode settings live in one Codable struct, serialized to a single UserDefaults key (`fastingModeSettings`):

```swift
public struct FastingModeSettings: Codable, Equatable {
    public var enabled: Bool = false
    public var autoRamadan: Bool = true
    public var weeklyDays: Set<Int> = []                 // 1=Sun … 7=Sat
    public var ayyamAlBeed: Bool = false
    public var sixDaysShawwal: Bool = false
    public var dayOfArafah: Bool = false
    public var firstNineDhulHijjah: Bool = false
    public var muharramFast: Bool = false
    public var midShaban: Bool = false   // engine ignores when !isShiaMethod
    public var mabath: Bool = false      // engine ignores when !isShiaMethod
    public var suhoorLeadMinutes: Int = 30
    public var iftarLeadMinutes: Int = 15
    public var dayBeforeEnabled: Bool = true
    public var dayBeforeTime: DateComponents = .init(hour: 20, minute: 0)
    public var notificationsEnabled: Bool = true
}
```

**Schema evolution:** All fields default-valued. Future additions are decode-safe — `Codable`'s synthesized `init(from:)` handles missing keys via the default values.

**SettingsManager wiring:**

```swift
@Published public var fastingModeSettings: FastingModeSettings {
    didSet {
        if let data = try? JSONEncoder().encode(fastingModeSettings) {
            defaults.set(data, forKey: Keys.fastingModeSettings)
            guard !isApplyingRemote else { return }
            kvs.set(data, forKey: Keys.fastingModeSettings)
        }
    }
}
```

Plus one un-synced device-local key: `didShowFastingModePromo: Bool` (whether the first-Ramadan banner has been shown).

### Live Activity ContentState migration

Existing v1.5 `ContentState` ships without Fasting Mode fields. v1.6 adds two **optional** fields with default-nil:

```swift
struct ContentState: Codable, Hashable {
    let nextPrayerName: String
    let nextPrayerTime: Date
    let followingPrayerName: String
    let moonPhase: Double
    let hijriDateString: String
    // v1.6 additions — optional for backward decode of in-flight v1.5 activities
    var fastingActive: Bool? = nil
    var fastingTriggerRaw: String? = nil
}
```

In-flight v1.5 activities decode cleanly (missing fields → nil), and v1.6 LA views render `fastingActive ?? false` as the standard countdown. No forced re-start needed.

Single source of truth at `IqamahLiveActivity/PrayerActivityAttributes.swift` (consolidated 2026-05-21, commit `c5215bd`). Editing the file updates both the iqamah-iOS app target and the IqamahLiveActivity extension because the file ref has multi-target membership.

### Debounced notification re-scheduling

Settings changes can come in bursts (user toggling weekday pills). Each `FastingNotificationScheduler` wraps the re-schedule entry:

```swift
private var debounceWorkItem: DispatchWorkItem?

func requestReschedule() {
    debounceWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.rescheduleNow() }
    debounceWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
}
```

Observers call `requestReschedule()` on each change. Rapid taps coalesce into one `rescheduleNow()` call 500 ms after the last change. `rescheduleNow()` itself runs the actual scheduling off the main queue.

### Caller-side banner gating

`FastingBanner` always renders content when called. Callers gate visibility:

```swift
if state.isActive || state.prohibition != nil {
    FastingBanner(state: state, todayTimes: prayerTimes, isShiaMethod: settings.calculationMethod.isShiaMethod)
}
```

Clearer at the call site than the banner silently returning `EmptyView()`.

### Friday-alone / Saturday-alone warnings

```swift
extension FastingModeSettings {
    /// Friday in weeklyDays without Thursday or Saturday — discouraged in many traditions.
    var hasFridayAloneWarning: Bool {
        weeklyDays.contains(6) && !weeklyDays.contains(5) && !weeklyDays.contains(7)
    }

    /// Saturday in weeklyDays without Friday — canonical pairing is Fri+Sat.
    var hasSaturdayAloneWarning: Bool {
        weeklyDays.contains(7) && !weeklyDays.contains(6)
    }
}
```

Settings UI renders `Label("...", systemImage: "exclamationmark.triangle.fill")` inline beneath the weekday pills when either flag is true. Non-blocking — purely informational.

---

## Ja'fari Calculation Method

New case in `Packages/IqamahCore/Sources/IqamahCore/Models/CalculationMethod.swift`:

```swift
case jafari    // Ja'fari (Shia outside Iran) — Fajr 16°, Isha 14°, Maghrib 4° below horizon
```

Distinct from `.tehran` (Fajr 17.7°, Isha 14°, Maghrib 4.5°). Both are recognized Ja'fari conventions; users pick based on their community's practice.

**Picker entry** in `CalculationMethodView.swift`:

```swift
case .jafari:
    return ("Ja'fari", "Shia jurisprudence (used outside Iran)")
```

**`isShiaMethod` helper:**

```swift
public extension CalculationMethod {
    /// True for methods rooted in Ja'fari (Shia) jurisprudence.
    /// Drives tradition-aware UI gating in Fasting Mode and prayer-time framing.
    var isShiaMethod: Bool {
        self == .tehran || self == .jafari
    }
}
```

Single source of truth — consumed by `FastingModeEngine`, `FastingLabelFormatter`, and the Settings UI.

---

## SettingsManager schema additions

| Key | Type | KVS-synced | Default | Notes |
|---|---|---|---|---|
| `fastingModeSettings` | `Data` (JSON-encoded `FastingModeSettings`) | ✅ | `FastingModeSettings()` defaults | Single blob; field-level defaults handle decode of older data |
| `didShowFastingModePromo` | `Bool` | ❌ (per-device) | `false` | First-Ramadan banner shown flag |

Plus existing `calculationMethod` (already KVS-synced) gains `.jafari` as a valid value. The KVS data format is unchanged (raw string of the enum case).

**Cross-version sync note:** If a v1.6 device sets `calculationMethod = .jafari` and syncs to a v1.5 device via KVS, the v1.5 device's `CalculationMethod(rawValue: "jafari")` returns `nil` and the existing fallback at `SettingsManager.init` lines 293–298 silently defaults to `.muslimWorldLeague`. No crash. The user notices their method "changed" until they upgrade the older device. Acceptable degradation — Ja'fari users on multi-device setups are expected to upgrade all devices together.

---

## Edge Cases

### Hijri day offset
`settings.hijriDayOffset` (already in SettingsManager) is applied to date inputs before trigger evaluation. Tests cover offset = ±1 across Ramadan/Eid boundaries.

### Timezone changes
Engine takes `TimeZone` as a parameter; uses `settings.activeTimezoneIdentifier` (from ENH-001). A traveler crossing midnight in their original timezone sees the new day's fasting state at the moment of crossover.

### Midnight rollover
Each render call passes `Date()`, so the answer naturally updates after midnight. The menu bar / iOS hero are timer-driven (re-render every 60 s) — they'll pick up the new state within one tick. Notifications are re-scheduled at midnight by the existing AppDelegate / NotificationScheduler midnight handlers.

### System clock changes
Engine consults `Date()` at evaluation time. If a user backdates their system clock (rare), the next render reflects the new "now". No persistent cache to invalidate.

### Multi-trigger overlap
A Monday that's also 13 Dhul-Hijjah (Tashriq): the prohibition filter wins; `state.prohibition = .tashriq13`, `state.isActive = false`. The Monday weekly trigger and Ayyam al-Beed trigger are both moot.

### Multi-device + iCloud KVS
Settings sync via KVS. The blob format ensures atomic sync — a partially-applied settings change can't occur (the whole struct is one key).

### Notification cap pressure
If a user adds many trigger types AND the existing adhaan schedule fills slots, the rolling 7-day window may need to shrink. **Mitigation:** if `UNUserNotificationCenter.getPendingNotificationRequests` returns > 50 items at re-schedule time, shrink the Fasting Mode window to 3 days. Falls back gracefully.

### Watch sync
`fastingModeSettings` syncs via KVS (already established). The watch app evaluates locally — no extra WCSession messages required. Initial sync covered by the existing KVS pull on app launch.

---

## Testing

All trigger logic, exclusion filtering, label formatting, and notification planning is pure-functional in `IqamahCore` — testable with Swift Testing.

### Test files

**`Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeEngineTests.swift`** (new)
- 9 trigger suites (one per FastingTriggerKind)
- 1 prohibition suite (5 prohibited days × suppression check)
- 1 priority suite (Arafah > firstNineDhulHijjah on day 9; prohibition > any trigger; Shia gating)

**`Packages/IqamahCore/Tests/IqamahCoreTests/FastingLabelFormatterTests.swift`** (new)
- Ramadan vs Nawafil glyph selection
- Inside-2h-window relabel
- Outside-2h-window passthrough (returns original)
- Muharram-label tradition adaptation (Tasu'a vs Ashura)

**`Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeSettingsCodecTests.swift`** (new)
- Round-trip encode/decode
- Forward compatibility — old JSON missing new fields decodes with defaults
- All trigger toggles correctly serialize

**`Packages/IqamahCore/Tests/IqamahCoreTests/FastingNotificationPlannerTests.swift`** (new)
- Suhoor lead-time arithmetic for various leads (5, 30, 60, 120 min)
- Iftar lead-time arithmetic
- Day-before reminder fires for Ramadan day 1, skipped for days 2–30, fires for Nawafil
- Hard-prohibited day suppresses all three planners

**`Packages/IqamahCore/Tests/IqamahCoreTests/CalculationMethodJafariTests.swift`** (new)
- Ja'fari Fajr/Isha/Maghrib angles produce expected times at known coordinates
- `isShiaMethod` returns expected values for all 7 methods

### Coverage targets (~40 tests across the 5 new files)

| # | Test | Setup | Expected |
|---|---|---|---|
| 1 | autoRamadan ON, 5 Ramadan 1447 | autoRamadan=true | active, `.autoRamadan` |
| 2 | autoRamadan OFF, 5 Ramadan 1447 | autoRamadan=false | inactive |
| 3 | weekly={Mon, Thu}, Monday | weeklyDays=[2,5] | active, `.weeklySchedule` |
| 4 | weekly={Mon, Thu}, Wednesday | weeklyDays=[2,5] | inactive |
| 5 | ayyamAlBeed ON, 13 Rabi al-Thani | ayyamAlBeed=true | active, `.ayyamAlBeed` |
| 6 | ayyamAlBeed ON, 16 Rabi al-Thani | ayyamAlBeed=true | inactive |
| 7 | dayOfArafah ON, 9 Dhul-Hijjah | dayOfArafah=true | active, `.dayOfArafah` |
| 8 | firstNineDhulHijjah ON, 5 Dhul-Hijjah | firstNineDhulHijjah=true | active, `.firstNineDhulHijjah` |
| 9 | firstNineDhulHijjah + dayOfArafah, 9 Dhul-Hijjah | both true | active, `.dayOfArafah` (priority) |
| 10 | muharramFast Sunni, 10 Muharram | method=.mwl, muharramFast=true | active, `.muharramFast` (Ashura date) |
| 11 | muharramFast Sunni, 9 Muharram | method=.mwl, muharramFast=true | active, `.muharramFast` (Tasu'a date) |
| 12 | muharramFast Shia, 9 Muharram | method=.tehran, muharramFast=true | active, `.muharramFast` |
| 13 | muharramFast Shia, 10 Muharram | method=.tehran, muharramFast=true | inactive |
| 14 | sixDaysShawwal ON, 2 Shawwal | sixDaysShawwal=true | active, `.sixDaysShawwal` |
| 15 | sixDaysShawwal ON, 1 Shawwal (Eid) | sixDaysShawwal=true | inactive, `prohibition=.eidAlFitr` |
| 16 | midShaban Shia, 15 Sha'ban | method=.tehran, midShaban=true | active, `.midShaban` |
| 17 | midShaban Sunni, 15 Sha'ban | method=.mwl, midShaban=true | inactive (engine suppression) |
| 18 | mabath Shia, 27 Rajab | method=.tehran, mabath=true | active, `.mabath` |
| 19 | mabath Sunni, 27 Rajab | method=.mwl, mabath=true | inactive |
| 20 | Toggle persistence after method swap | midShaban=true, switch tehran→mwl→tehran | toggle still true |
| 21 | weekly={Sun}, 10 Dhul-Hijjah Sunday | weeklyDays=[1] | inactive, `prohibition=.eidAlAdha` |
| 22 | All triggers ON, ordinary Tuesday | every Bool true, every date | inactive (no match) |
| 23 | hijriDayOffset=+1, real 8 Dhul-Hijjah | dayOfArafah=true | active, `.dayOfArafah` |
| 24 | hijriDayOffset=-1, real 10 Muharram | muharramFast=true, method=.tehran | active (Tasu'a after offset) |
| 25 | hasFridayAloneWarning when only Fri | weeklyDays=[6] | true |
| 26 | hasFridayAloneWarning with Fri+Thu | weeklyDays=[5,6] | false |
| 27 | hasSaturdayAloneWarning when only Sat | weeklyDays=[7] | true |
| 28 | hasSaturdayAloneWarning with Fri+Sat | weeklyDays=[6,7] | false |
| 29 | Codec round-trip preserves all fields | encode → decode | equal |
| 30 | Codec decodes legacy JSON missing midShaban | JSON without that key | defaults to false |
| 31 | Suhoor 30-min lead arithmetic | suhoorLead=30, Fajr=05:12 | fire at 04:42 |
| 32 | Suhoor 120-min lead arithmetic | suhoorLead=120, Fajr=05:12 | fire at 03:12 |
| 33 | Iftar 15-min lead arithmetic | iftarLead=15, Maghrib=20:32 | fire at 20:17 |
| 34 | Day-before fires for Ramadan day 1 | tomorrow=1 Ramadan | non-nil plan |
| 35 | Day-before skipped for Ramadan day 2 | tomorrow=2 Ramadan | nil |
| 36 | Day-before fires for Nawafil Monday | tomorrow=Monday, weekly={Mon} | non-nil |
| 37 | Day-before skipped for prohibited day | tomorrow=Eid al-Fitr | nil |
| 38 | Label relabel Ramadan within 2h | active, trigger=.autoRamadan, Fajr<2h | "🌙 Suhoor" |
| 39 | Label relabel Nawafil within 2h | active, trigger=.weeklySchedule, Fajr<2h | "🕗 Suhoor" |
| 40 | Label passthrough outside 2h | active, Fajr>2h | "Fajr" |
| 41 | Ja'fari method Maghrib timing | method=.jafari, sunset 20:00 | Maghrib ~20:08–20:12 |
| 42 | isShiaMethod returns expected for all 7 | iterate every case | only .tehran and .jafari true |

### What we don't unit-test (manual on simulator)

- Banner rendering visuals (would be in EPIC-0015 US-0065 snapshot suite if/when that lands)
- iCloud KVS round-trip between phone and Mac
- WCSession watch sync of fastingModeSettings
- Live Activity actually displaying new ContentState fields on Dynamic Island
- Actual notification delivery on a locked device

---

## EPIC / US / AC / TC Promotion

### EPIC-0017 — Fasting Mode (ENH-002)

**Status:** 🟡 Planned
**Version Target:** v1.6
**Goal:** Generalize Ramadan Mode into a year-round Fasting Mode covering auto-Ramadan, 7 Nawafil triggers, banner+relabel display across all surfaces, and configurable Suhoor/Iftar/day-before notifications. Add Ja'fari calculation method and tradition-aware UI gating.

### User Stories

**US-0071 — FastingModeEngine + settings schema (IqamahCore foundation)**
Build the pure-functional engine, the JSON-blob settings struct, and the 9-trigger evaluation logic with prohibition filtering and Shia-gating.

- AC-0357: `FastingModeSettings` struct exists in `IqamahCore` with all 13 fields default-valued; Codable round-trip preserves all fields; decode of legacy JSON missing fields applies defaults
- AC-0358: `FastingModeEngine.evaluate(for:settings:hijriCalendar:timezone:)` is pure-functional (no I/O, no side effects); returns `FastingDayState` value
- AC-0359: `.autoRamadan` and `.weeklySchedule` triggers fire on Hijri month 9 and on user-selected weekdays respectively when their toggles are on
- AC-0360: `.ayyamAlBeed` (13/14/15 of any Hijri month) and `.sixDaysShawwal` (2–7 Shawwal) triggers fire when toggled on
- AC-0361: `.dayOfArafah` (9 Dhul-Hijjah) and `.firstNineDhulHijjah` (1–9 Dhul-Hijjah) triggers fire when toggled on; on day 9 `.dayOfArafah` takes priority
- AC-0362: `.muharramFast` trigger fires on 9+10 Muharram when `!isShiaMethod`, or 9 Muharram only when `isShiaMethod`
- AC-0363: `.midShaban` (15 Sha'ban) and `.mabath` (27 Rajab) triggers fire only when `isShiaMethod`; toggle value is preserved but suppressed in engine for non-Shia methods
- AC-0364: Prohibition filter detects Eid al-Fitr (1 Shawwal), Eid al-Adha (10 Dhul-Hijjah), Tashriq days 11/12/13 Dhul-Hijjah; suppresses any active trigger and returns `prohibition` value in state

**US-0072 — UI Surfaces (banner + relabel)**
Implement the visual treatment across every surface per Option D (relabel narrow + banner wide).

- AC-0365: `FastingLabelFormatter.prayerLabel(...)` relabels "Fajr" → "Suhoor" and "Maghrib" → "Iftar" only when state is active AND current time is within 2 hours of that prayer; uses 🌙 for Ramadan triggers, 🕗 for Nawafil triggers; returns the original prayer name otherwise
- AC-0366: `FastingBanner` view renders dual countdown (Suhoor ends + Iftar at) with Ramadan vs Nawafil tinting (purple+🌙 vs teal+🕗) when `state.isActive == true`
- AC-0367: `FastingBanner` renders grey prohibition message when `state.prohibition != nil` (e.g. "Eid al-Adha (10 Dhul-Hijjah) — fasting is forbidden today")
- AC-0368: macOS menu bar (`AppDelegate.updateStatusBarDisplay`) applies relabel; macOS popover (`MenuBarPopoverView`) renders `FastingBanner` above the prayer list
- AC-0369: iOS `PrayerHeroCard` renders `FastingBanner` above the next-prayer block; `PrayerRowMobileView` and watchOS `PrayerTimesTab` apply relabel
- AC-0370: Live Activity `ContentState` gains optional `fastingActive` and `fastingTriggerRaw` fields with default-nil; v1.5 in-flight activities decode cleanly; LA view applies relabel when fields are non-nil; widgets apply relabel

**US-0073 — Settings UI + tradition-aware gating**
Build the Settings section with master toggle, sub-controls, weekday picker, warnings, and method-driven UI adaptations.

- AC-0371: Settings master toggle hides all sub-controls when off; expanded state shows triggers in spec order
- AC-0372: Settings UI shows method-adaptive Muharram label/subtitle; shows `midShaban` and `mabath` rows only when `settings.calculationMethod.isShiaMethod`
- AC-0373: Friday-alone warning (Fri without Thu and without Sat) and Saturday-alone warning (Sat without Fri) render inline beneath the weekday picker when applicable; warnings are informational, non-blocking
- AC-0374: Toggle state for `midShaban` and `mabath` persists across calculation method changes; hidden in UI but stored Bool value is retained
- AC-0375: watchOS Settings shows master toggle + "Configure on iPhone/Mac" navigation link only — full configuration is on phone/Mac

**US-0074 — Notifications + scheduling**
Wire reminders into per-platform schedulers with debouncing, prohibition suppression, and permission UX.

- AC-0376: Suhoor and Iftar reminders fire at `Fajr − suhoorLeadMinutes` and `Maghrib − iftarLeadMinutes` on active fasting days; each lead time independently configurable 5–120 min in 5-min steps
- AC-0377: Day-before reminder fires at user-picked time on the evening before a fasting day; skipped for Ramadan days 2–30; fires for Ramadan day 1 and all Nawafil triggers
- AC-0378: 7-day rolling window re-schedules on midnight rollover, on Fasting Mode settings change (debounced 500 ms), on city change, and on calculation method change
- AC-0379: All three reminder kinds (Suhoor, Iftar, day-before) are suppressed for hard-prohibited days (Eids + Tashriq)
- AC-0380: Notifications-denied state shows a Settings row with platform-appropriate deep link (iOS: `openSettingsURLString`; macOS: `x-apple.systempreferences:com.apple.preference.notifications`; watchOS: static help text)

**US-0075 — Ja'fari calculation method**
Add the `.jafari` case and the `isShiaMethod` helper that drives tradition gating.

- AC-0381: `CalculationMethod.jafari` case exists with Fajr 16°, Isha 14°, Maghrib 4° below horizon; prayer times computed at known coordinates match published Ja'fari reference values within ±1 minute
- AC-0382: `CalculationMethod.isShiaMethod` returns `true` for `.tehran` and `.jafari`, `false` for all other methods; `CalculationMethodView` picker includes Ja'fari with descriptor "Shia jurisprudence (used outside Iran)"

### Acceptance criteria mapped to test cases

| AC | TC | Type |
|---|---|---|
| AC-0357 | TC-0044 (settings codec round-trip) + TC-0045 (legacy JSON decode) | Functional |
| AC-0358 | TC-0046 (engine purity) | Functional |
| AC-0359 | TC-0047 (autoRamadan + weekly) | Functional |
| AC-0360 | TC-0048 (Ayyam al-Beed + 6 Shawwal) | Functional |
| AC-0361 | TC-0049 (Arafah priority over firstNine) | Edge Case |
| AC-0362 | TC-0050 (muharramFast Sunni 9+10) + TC-0051 (muharramFast Shia 9 only) | Functional |
| AC-0363 | TC-0052 (midShaban Shia visible/active) + TC-0053 (midShaban Sunni suppressed) | Functional |
| AC-0364 | TC-0054 (Eid al-Fitr suppresses 6 Shawwal) + TC-0055 (Tashriq suppresses Ayyam al-Beed) | Edge Case |
| AC-0365 | TC-0056 (relabel within 2h, passthrough outside) | Functional |
| AC-0366 | TC-0057 (banner active state rendering) | Functional |
| AC-0367 | TC-0058 (banner prohibition state) | Functional |
| AC-0368 | TC-0059 (macOS menu bar relabel + popover banner) | Functional |
| AC-0369 | TC-0060 (iOS hero banner + row relabel + watch row relabel) | Functional |
| AC-0370 | TC-0061 (LA ContentState backward decode + new fields render) | Regression |
| AC-0371 | TC-0062 (master toggle hides/shows sub-controls) | Functional |
| AC-0372 | TC-0063 (Shia/Sunni Settings visibility + Muharram label adaptation) | Functional |
| AC-0373 | TC-0064 (Friday-alone + Saturday-alone warnings) | Functional |
| AC-0374 | TC-0065 (toggle persistence across method swap) | Regression |
| AC-0375 | TC-0066 (watch Settings minimal UI) | Functional |
| AC-0376 | TC-0067 (Suhoor + Iftar lead-time arithmetic + range) | Functional |
| AC-0377 | TC-0068 (day-before logic per Ramadan/Nawafil/prohibition) | Functional |
| AC-0378 | TC-0069 (7-day window re-schedule + 500ms debounce) | Functional |
| AC-0379 | (covered by TC-0054, TC-0055 — exclusion filter is shared) | — |
| AC-0380 | TC-0070 (permission-denied deep link UI) | Negative |
| AC-0381 | TC-0071 (Ja'fari Maghrib timing matches reference) | Functional |
| AC-0382 | TC-0072 (isShiaMethod returns expected for all 7 methods) | Functional |

30 TC entries reserved (TC-0044 — TC-0073). AC-0357, AC-0362, AC-0363, and AC-0364 each consume two TCs (covering distinct scenarios); AC-0379 reuses TC-0054/TC-0055 from AC-0364 (same prohibition filter); TC-0073 is the multi-platform smoke test covering "all schemes build clean after Fasting Mode merge".

### ID Registry consumption

After ENH-001 finish-up consumes through AC-0356 and TC-0043, ENH-002 will consume:

| Sequence | First | Last | Count |
|---|---|---|---|
| EPIC | EPIC-0017 | EPIC-0017 | 1 |
| US | US-0071 | US-0075 | 5 |
| AC | AC-0357 | AC-0382 | 26 |
| TC | TC-0044 | TC-0073 | 30 |

Post-implementation `ID_REGISTRY.md` next-available values:

| Sequence | Next Available |
|---|---|
| EPIC | EPIC-0018 |
| US | US-0076 |
| AC | AC-0383 |
| TC | TC-0074 |
| ENH | ENH-023 (ENH-022 stub for celebration reminders added to `docs/ENHANCEMENTS.md` during this work) |

---

## Files Touched

### New files

| File | Purpose |
|---|---|
| `Packages/IqamahCore/Sources/IqamahCore/Services/FastingMode.swift` | Value types |
| `Packages/IqamahCore/Sources/IqamahCore/Services/FastingModeEngine.swift` | Pure engine |
| `Packages/IqamahCore/Sources/IqamahCore/Services/FastingLabelFormatter.swift` | Relabel helpers |
| `Packages/IqamahCore/Sources/IqamahCore/Services/FastingNotificationPlanner.swift` | Pure scheduling helpers |
| `iqamah/Views/Shared/FastingBanner.swift` | Cross-target SwiftUI banner |
| `iqamah/Views/Shared/FastingModeSection.swift` | Settings UI section (shared macOS/iOS) |
| `iqamah/FastingNotificationScheduler.swift` | macOS UNUserNotificationCenter wrapper |
| `Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeEngineTests.swift` | Engine tests |
| `Packages/IqamahCore/Tests/IqamahCoreTests/FastingLabelFormatterTests.swift` | Formatter tests |
| `Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeSettingsCodecTests.swift` | Codec tests |
| `Packages/IqamahCore/Tests/IqamahCoreTests/FastingNotificationPlannerTests.swift` | Planner tests |
| `Packages/IqamahCore/Tests/IqamahCoreTests/CalculationMethodJafariTests.swift` | Ja'fari method tests |

### Modified files

| File | Change |
|---|---|
| `Packages/IqamahCore/Sources/IqamahCore/Models/CalculationMethod.swift` | Add `.jafari` case + `isShiaMethod` helper |
| `Packages/IqamahCore/Sources/IqamahCore/Services/SettingsManager.swift` | Add `fastingModeSettings` + `didShowFastingModePromo` keys + observers |
| `iqamah/Views/CalculationMethodView.swift` | Add Ja'fari picker entry |
| `iqamah/AppDelegate.swift` | Menu bar relabel via FastingLabelFormatter |
| `iqamah/Views/MenuBarPopoverView.swift` | Render FastingBanner |
| `iqamah/Views/SettingsSheetView.swift` | Include FastingModeSection |
| `iqamah/iOS/PrayerHeroCard.swift` | Render FastingBanner |
| `iqamah/iOS/PrayerRowMobileView.swift` | Apply relabel |
| `iqamah/iOS/NotificationScheduler.swift` | Extend for fasting reminders + debounce |
| `IqamahWatch/PrayerTimesTab.swift` | Apply relabel |
| `IqamahWatch/SettingsTab.swift` | Minimal Fasting Mode entry |
| `IqamahWatch/WatchNotificationScheduler.swift` | Extend for fasting reminders + debounce |
| `IqamahWidget/IqamahWidget.swift` | Apply relabel |
| `IqamahLiveActivity/PrayerActivityAttributes.swift` | Add optional `fastingActive` + `fastingTriggerRaw` fields |
| `IqamahLiveActivity/PrayerLiveActivityView.swift` | Apply relabel |
| `iqamah/iOS/PrayerActivityManager.swift` | Pass fasting state into ContentState |
| `iqamah.xcodeproj/project.pbxproj` | Add new file refs + multi-target memberships for FastingBanner + FastingModeSection |
| `docs/ENHANCEMENTS.md` | Mark ENH-002 ✅; add ENH-022 stub for celebration reminders |
| `docs/RELEASE_PLAN.md` | Add EPIC-0017 + US-0071–US-0075 + AC-0357–AC-0382 |
| `docs/TEST_CASES.md` | Add TC-0044 — TC-0073 |
| `docs/ID_REGISTRY.md` | Bump EPIC→0018, US→0076, AC→0383, TC→0074, ENH→0023 |

---

## Cross-References

- **ENH-002** (this work) supersedes the original Ramadan Mode stub in `docs/ENHANCEMENTS.md`
- **ENH-022** (Celebration reminders) — new stub to be added during this work
- **ENH-023** is next available after this spec lands
- **EPIC-0015** (Test Automation) — once US-0065 (snapshot tests) ships, the FastingBanner snapshot suite slots in naturally
- **ENH-001** (GPS Accuracy) — already-shipped + finish-up spec. ENH-001's `gpsTimezone` is consumed via `settings.activeTimezoneIdentifier` for engine evaluation
- **`IqamahLiveActivity/PrayerActivityAttributes.swift` consolidation** — completed 2026-05-21 (commit `c5215bd`); the optional Fasting Mode fields are added to the single canonical file with multi-target membership

---

## Spec self-review notes

- All sections have content; no TBD or placeholder
- Trigger priority order and prohibition precedence stated explicitly
- Schema-evolution strategy stated (JSON blob with default-valued fields)
- Migration story for Live Activity stated (optional fields, default-nil)
- Architecture sections cite the consolidated PrayerActivityAttributes commit and the existing `activeTimezoneIdentifier` helper
- 42 covered test scenarios mapped to ~26 AC entries (some ACs span multiple tests; AC-0379 reuses prohibition tests)
- ID consumption is explicit (EPIC-0017, US-0071–0075, AC-0357–0382, TC-0044–0073)
- Visual treatments specified with exact gradient hex values and glyphs
- Notification cap calculation done explicitly (21 + 35 = 56 < 64)
- Out-of-scope items called out (celebrations as ENH-022; "most of Sha'ban" deferred)
