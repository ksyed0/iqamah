# Widgets + Live Activity Design Spec
**Date:** 2026-05-11
**Status:** Draft — approved for implementation planning
**Scope:** US-0045 (Live Activity / Dynamic Island) + iOS widget expansion + macOS Notification Center widget (ENH-004)
**Promotions from:** US-0045 (deferred from EPIC-0010), ENH-004 (macOS widget backlog)

---

## 1. Goal

Three related deliverables sharing a common infrastructure:

1. **Dynamic Island / Live Activity** — persistent all-day prayer countdown in the Dynamic Island, lock screen, and StandBy, with moon phase + Hijri date context
2. **iOS Widget Expansion** — four new widget families (Large, StandBy, Lock Screen Circular, Lock Screen Inline) added to the existing `IqamahWidget` target
3. **macOS Notification Center Widget** — Small, Medium (free — reuse iOS views), and Large (full prayer schedule) in macOS Notification Center

---

## 2. Architecture

### Targets

| Target | Type | Change |
|--------|------|--------|
| `IqamahLiveActivity` | ActivityKit Extension (iOS) | **New target** |
| `IqamahWidget` | WidgetKit Extension | **Extend** — add macOS platform + new families |
| `IqamahCore` | Local Swift Package | Add `moonPhase(for:)` and `hijriDateString(for:)` helpers |

### Shared data

`PrayerEntry` (existing `TimelineEntry`) is **not modified**. Moon phase and Hijri date are only needed by the Live Activity, so they live in `PrayerActivityAttributes.ContentState` — not the widget timeline entry.

New `IqamahCore` helpers (pure functions, no new types):
```swift
/// Synodic phase fraction [0 = new moon, 0.5 = full, 1 = new again]
public func moonPhase(for date: Date) -> Double

/// "9 Dhu al-Hijjah 1447" — respects SettingsManager.hijriDayOffset
public func hijriDateString(for date: Date, offset: Int) -> String
```

Both are computed from `NewMoon` (already in `IqamahCore`) and `Calendar(identifier: .islamicUmmAlQura)`.

---

## 3. Live Activity (Dynamic Island)

### ActivityAttributes

```swift
public struct PrayerActivityAttributes: ActivityAttributes {
    // Static — set once when activity starts, never changes
    public let cityName: String
    public let methodName: String

    public struct ContentState: Codable, Hashable {
        public let nextPrayerName: String
        public let nextPrayerTime: Date
        public let followingPrayerName: String  // shown in compact trailing hint
        public let moonPhase: Double             // 0–1 synodic fraction
        public let hijriDateString: String       // "9 Dhu al-Hijjah 1447"
    }
}
```

### Lifecycle

| Event | Action |
|-------|--------|
| App enters foreground | If no live activity exists → start for current prayer period |
| 60 min before each prayer | `NotificationScheduler` also calls `Activity.request(...)` as safety net |
| Each prayer time elapses | `Activity.update(using: newContentState)` |
| Stale policy | `.stale(after: nextPrayerTime)` — system requests fresh update |
| End condition | Next day's Fajr start (activity auto-renews, maintaining 24h cycle) |
| User toggle | `SettingsManager.liveActivityEnabled: Bool` (new key, independent of `hilalNotificationEnabled`) |

### Presentations

**Compact (pill closed — shown alongside other content):**
- Leading: gold dot `●` + prayer name in `Color.appGold`
- Trailing: countdown `HH:mm` in white, tabular digits

**Expanded (tap to open — shown briefly on state change):**
- Header: `"IQAMAH"` label (10pt, #aaa) + `MoonPhaseView(size: 20, phase: moonPhase)` + Hijri date string
- Body: prayer name (28pt bold, `Color.appGold`) left + countdown (36pt bold, white) right
- Subheader: `"at 3:42 PM · Riyadh"` (13pt, `Color.secondary`)
- Footer: `"Open Iqamah ›"` Liquid Glass pill — taps open app to prayer times tab
- Chrome: `.regularMaterial` with `.glassEffect()` on iOS 26+

**Lock Screen:**
- Layout B: prayer info (icon + name + absolute time + natural language countdown) on the left; moon crescent + Hijri date in their own right column separated by a hairline divider
- Icon: clock emoji in gold-tinted circle
- "in 2 hours 14 minutes" — natural language via `RelativeDateTimeFormatter`
- Moon: `MoonPhaseView(size: 26, phase: moonPhase)` — dark disc always, gold crescent
- Chrome: `.regularMaterial` with Liquid Glass on iOS 26+

**Minimal (second app's activity visible):**
- Prayer initial only (e.g. "A" for Asr) in `Color.appGold`

---

## 4. iOS Widget Expansion

All new families added to the existing `IqamahWidget` target via new cases in `IqamahWidgetView`'s `@Environment(\.widgetFamily)` switch.

`PrayerTimelineProvider` and `PrayerEntry` are **unchanged**.

### New families

| Family | View | Content |
|--------|------|---------|
| `.systemLarge` | `LargeWidgetView` | All 5 prayers listed. Past: 30% opacity. Next: gold pill highlight. Hijri date footer. |
| `.systemExtraLarge` | `ExtraLargeWidgetView` | iPad only. Same as Large but two-column: today left, tomorrow right. |
| `.accessoryCircular` | `CircularWidgetView` | Progress arc (time elapsed since last prayer). Prayer initial + countdown inside. Same arc pattern as Watch circular complication. |
| `.accessoryInline` | `InlineWidgetView` | `"🕐 Asr at 3:42 PM"` — plain text above clock. |
| StandBy (`.systemLarge`) | Reuses `LargeWidgetView` | `.containerBackground(.black)` — system handles rotation. Zero extra code. |

### Color tokens

- Dark mode: `Color.appGold` (#FFD60A), body white, secondary #aaa
- Light mode: `Color.appGoldDim` (#A07010), body #111, secondary #555
- Background: `.regularMaterial` → `.glassEffect()` on iOS 26+

---

## 5. macOS Notification Center Widget

The `IqamahWidget` target gains `.macOS(.v14)` in `Package.swift`.

### Families

| Family | Code | Effort |
|--------|------|--------|
| `.systemSmall` | Reuses `SmallWidgetView` unchanged | **Free** |
| `.systemMedium` | Reuses `MediumWidgetView` unchanged | **Free** |
| `.systemLarge` | New `macOSLargeWidgetView` | ~60 lines |

### `macOSLargeWidgetView`

- Header: `"IQAMAH · MON · 9 DHU AL-HIJJAH"` small caps + countdown in `Color.appGold` (right-aligned)
- Hairline divider
- Prayer list: all 5 prayers. Past: 30% opacity. Next: gold pill highlight with `●` dot. Future: full opacity.
- Footer divider + `"Riyadh · ISNA · Standard Asr"` in 9pt secondary

Dark/light adapts via `@Environment(\.colorScheme)` — same pattern as existing iOS views.

---

## 6. Data Flow Diagram

```
IqamahCore
  ├── PrayerCalculator          → prayer times for today + tomorrow
  ├── NewMoon.previous(before:) → moonPhase(for:)
  ├── Calendar(.islamicUmmAlQura) → hijriDateString(for:offset:)
  └── PrayerTimelineProvider    → PrayerEntry[] (widget timeline, unchanged)

iqamah-iOS app
  ├── PrayerActivityManager     → NEW: manages ActivityKit lifecycle
  │     startOrUpdateActivity() called on: app active, prayer crossing, 60min before
  │     endActivity()           called on: next Fajr
  └── SettingsManager           → liveActivityEnabled: Bool (new key, KVS-synced)

IqamahLiveActivity (new target)
  └── PrayerActivityAttributes  → Compact / Expanded / Lock Screen / Minimal views

IqamahWidget (existing target, extended)
  └── IqamahWidgetView          → switch on widgetFamily → all families including new ones
```

---

## 7. Testing

### Unit tests — `IqamahCoreTests`

| Test | Assertion |
|------|-----------|
| `testMoonPhaseRange` | `moonPhase(for: Date())` ∈ [0, 1] |
| `testMoonPhaseFullMoon` | Known full moon date → value ~0.5 ± 0.02 |
| `testHijriDateString` | Known Gregorian date → correct Hijri string |
| `testActivityContentStateCodable` | `ContentState` round-trips through `Codable` |

### Unit tests — `IqamahWidgetTests`

| Test | Assertion |
|------|-----------|
| `testCircularViewNoCrash` | `CircularWidgetView(entry: stub)` instantiates without crash |
| `testInlineViewFormat` | `InlineWidgetView` text matches `"🕐 \(prayerName) at \(time)"` |

### Manual QA gates

- Live Activity appears in Dynamic Island within 5s of app launch
- Activity updates at each prayer crossing (use simulator clock fast-forward)
- Lock screen presentation visible in dark and light wallpaper contexts
- StandBy renders correctly in landscape charging position
- Expanded "Open Iqamah ›" tap opens app to prayer times tab
- macOS Large widget renders in Notification Center (dark + light system theme)
- All new iOS widget families visible in widget picker
- `liveActivityEnabled` toggle in Settings independently controls Live Activity (separate from notification toggle)

---

## 8. Scope Boundaries

**In scope:**
- `PrayerActivityAttributes` + all 4 Dynamic Island presentations
- `PrayerActivityManager` (new service in `iqamah-iOS`)
- `liveActivityEnabled` SettingsManager key (KVS-synced)
- iOS: Large, ExtraLarge, Circular, Inline, StandBy widget families
- macOS: Small, Medium (free), Large (new view)
- `moonPhase(for:)` and `hijriDateString(for:offset:)` in IqamahCore

**Out of scope (future):**
- Push token-based remote Live Activity updates (requires server)
- watchOS Live Activity surface (separate Epic)
- Interactive widget buttons (requires iOS 17 target already met, but scope deferred)

---

## 9. New IDs Required

Consult `docs/ID_REGISTRY.md` before assigning. Next available: **EPIC-0013**, **US-0058**, **AC-0276**.

This feature should be promoted as **EPIC-0013 — Widget Platform** with user stories:
- **US-0058** — Live Activity / Dynamic Island (replaces deferred US-0045)
- **US-0059** — iOS widget expansion (Large, StandBy, Circular, Inline)
- **US-0060** — macOS Notification Center widget

---

**Last Updated:** 2026-05-11 (Brainstorming session — all design decisions approved)
