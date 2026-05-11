# EPIC-0012 — Apple Watch App Design Spec
**Date:** 2026-05-10
**Status:** Draft — pending implementation plan
**Scope:** EPIC-0012 (US-0053 – US-0057, AC-0252 – AC-0275)
**Promoted from:** ENH-016

---

## 1. Goal

Add a native watchOS app that displays today's prayer times, a live Qibla compass, and per-prayer haptic notifications. The watch runs fully independently — no iPhone required at runtime. Settings sync silently from iPhone via Watch Connectivity when available.

---

## 2. Architecture

### New Xcode targets

| Target | Type | Deployment Target | Purpose |
|--------|------|------------------|---------|
| `IqamahWatch` | watchOS App | watchOS 10.0+ | Prayer list, Qibla, Settings |
| `IqamahWatchWidget` | watchOS Widget Extension | watchOS 10.0+ | 4 WidgetKit complication families |

Both targets link against `IqamahCore` (local Swift Package). No new package dependencies.

### Data flow

```
IqamahCore (PrayerCalculator, SettingsManager, HilalCalculator)
    ↓ shared via local Swift Package
IqamahWatch ←── WCSession ──→ iqamah-iOS (iPhone companion)
    ↓ writes to App Group
IqamahWatchWidget (reads App Group UserDefaults)
```

### Storage

`SettingsManager` already uses App Group `group.com.fablesoft.iqamah` (established in EPIC-0010). The watch reads and writes the same keys with zero changes to the package. No new UserDefaults keys are introduced in this EPIC.

### Watch Connectivity

- **iPhone → Watch:** `WCSession.transferUserInfo(_:)` fires on every `settingsDidChange` notification in the iOS app. Payload is a dict of all synced SettingsManager keys.
- **Watch → iPhone:** None in v1. The watch is a consumer of settings, not a source of truth. Exception: GPS-detected location is written directly to the App Group and read by the widget — no WCSession round-trip needed.

---

## 3. Watch App UI

### Navigation

`TabView` with horizontal swipe + page indicator dots (3 tabs):

```
[Prayer Times] ←swipe→ [Qibla] ←swipe→ [Settings]
```

Standard Apple Watch `TabView` pattern. Digital Crown scrolls within each tab where content overflows.

---

### Tab 1 — Prayer Times

**Header:** Hijri date in small-caps, respecting `hijriDayOffset` from `SettingsManager`.
Example: `9 DHU AL-HIJJAH · MON`

**Prayer list:** `List` with `.plain` style. 6 rows (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha).

Two-column grid per row:
- Left: prayer name
- Right: absolute time (12h or 24h per `use24HourTime` setting)

**Visual treatment:**
- Past prayers: 28% opacity
- Next prayer: text colour `#FFD60A` (gold), bold weight, 12% gold pill background (`.background(Color(hex:"FFD60A").opacity(0.12), in: RoundedRectangle(cornerRadius: 5))`)
- Sunrise: same size as other rows but style is secondary (not a prayer, reference only)
- Future prayers: full opacity, normal weight

**Overflow:** All 6 rows fit on Series 9 (198×242pt). Digital Crown scroll is available for smaller devices (Series 4/5/SE) where rows may clip.

---

### Tab 2 — Qibla

**Arc ring:** Full-width ring showing Qibla bearing as a gold arc segment. Ka'bah icon centred inside the ring.

**Live heading:** Uses `CLLocationHeading` via `CLLocationManager`. Updates the arc orientation in real time as the watch rotates. Heading permission is requested on first visit to this tab (separate from location permission).

**Text below arc:**
- Line 1: `"Face 147° SE"` (absolute bearing, cardinal direction)
- Line 2: `"Turn 23° right"` (delta from current heading to Qibla bearing, positive = clockwise)
- Line 3: `"Makkah · 1,204 km"` (dimmed, 40% opacity)

**Edge cases:**
- Heading unavailable (no magnetometer data): hide arc animation, show `"Heading unavailable"` in place of turn instruction
- Location unknown: show `"Location needed for Qibla"` with a button to Settings tab

---

### Tab 3 — Settings

`Form`-based SwiftUI view, Digital Crown scrollable. Writes directly to `SettingsManager.shared` (App Group UserDefaults). Changes propagate to complications via `WidgetCenter.shared.reloadAllTimelines()`.

**Sections:**

**Location**
- Row: city name (if set) or GPS coordinates
- Button: "Update Location" — re-runs `CLLocationManager` on-watch, writes new lat/lon to App Group

**Prayer Times**
- Calculation Method picker (6 options: MWL, ISNA, Egypt, Umm Al-Qura, Karachi, Tehran)
- Asr Method picker (Standard / Hanafi)

**Adjustments**
- Per-prayer stepper for each of the 5 prayers: −15 to +15 minutes
- Matches the adjustment range in the iOS and macOS apps

**Notifications**
- Toggle: "Prayer notifications" — schedules/cancels haptic `UNNotificationRequest` for each enabled prayer

**Display**
- Toggle: "24-hour time"

---

## 4. Complications

**Target:** `IqamahWatchWidget` — a watchOS Widget Extension using WidgetKit (watchOS 9+).

**Single `WidgetBundle` → single `Widget` → four supported families.**

### PrayerEntry

```swift
struct PrayerEntry: TimelineEntry {
    let date: Date
    let nextPrayerName: String
    let nextPrayerTime: Date
    let cityName: String
    let methodName: String   // short form: "ISNA", "MWL", etc.
}
```

### Timeline provider

- Generates one entry per prayer time, today + tomorrow (~12 entries total)
- `.policy: .after(nextPrayerTime)` — WidgetKit re-requests the timeline the moment each prayer passes
- Reads from `SettingsManager.shared` (App Group) — no WCSession needed in the widget extension

### Complication families

| Family | Layout |
|--------|--------|
| `.accessoryRectangular` | `"IQAMAH"` label (small, dimmed) · `"Asr  2h 14m"` (bold, gold) · `"Riyadh · ISNA"` (small, dimmed) |
| `.accessoryCircular` | Progress arc (time-of-day progress toward next prayer) · prayer name · countdown inside ring |
| `.accessoryCorner` | Prayer initial letter in gold ring · countdown `"2:14"` below |
| `.accessoryInline` | `"Asr at 3:42 PM"` — plain text |

### Accent colour

`#FFD60A` registered as `widgetAccentColor` in Assets.xcassets of `IqamahWatchWidget`. watchOS applies it correctly on both full-colour and tinted (monochrome) watch faces.

---

## 5. First Launch Flow

```
1. Watch app opens — App Group UserDefaults is empty
2. Show "Detecting your location…" spinner
3. CLLocationManager requests "When In Use" permission on-watch
   ├── Granted → get fix → write lat/lon + timezone to App Group
   │             → compute prayer times → show Tab 1 (prayer list)
   └── Denied  → show "Enable location in Watch Settings"
                 with Settings deep-link button
4. If GPS fix takes > 10s:
   → show "Location unavailable — tap to retry" row in prayer list
5. When iPhone app next opens:
   → WCSession.transferUserInfo pushes settings dict → watch updates silently
```

---

## 6. Offline Resilience

| Condition | Behaviour |
|-----------|-----------|
| iPhone unreachable | Use last-synced App Group values. Prayer times continue to work. |
| App Group empty + location granted | Run on-watch GPS flow (first launch path) |
| App Group empty + location denied | Show "Enable location" prompt |
| Qibla heading unavailable | Hide arc animation, show static bearing text + "Heading unavailable" note |
| Prayer times calculation error | Show error row with city name + "Check Settings" |

---

## 7. Notifications

- `UNUserNotificationRequest` scheduled for each prayer where `isPrayerEnabled(_:)` returns true
- Sound: `.default` (system haptic — watchOS does not support custom notification sounds)
- Body: `"Time for Asr"` · Subtitle: city name
- Tap action: opens watch app, returns to Tab 1
- Reschedule: on every app-active, same 7-day rolling window pattern as iOS (EPIC-0010 US-0043)
- Permission: requested when "Prayer notifications" toggle is first enabled in Tab 3 Settings

---

## 8. Testing

### Unit tests — `IqamahWatchTests` target

| Test | Assertion |
|------|-----------|
| `testTimelineEntriesCount` | Provider generates ≥ 10 entries for today + tomorrow |
| `testTimelineRefreshPolicy` | `.policy` date equals `nextPrayerTime` of the last entry |
| `testPrayerEntryFieldsNonEmpty` | `cityName` and `methodName` are never empty strings |
| `testNextPrayerIsAlwaysInFuture` | No entry has `nextPrayerTime < entry.date` |
| `testEmptyAppGroupShowsPlaceholder` | `placeholder(in:)` returns stub without crashing when App Group is empty |
| `testQiblaAngleRiyadh` | Qibla bearing from Riyadh (24.7°N, 46.7°E) ≈ 247° ± 2° |
| `testQiblaAngleLondon` | Qibla bearing from London (51.5°N, −0.1°E) ≈ 119° ± 2° |

### Manual QA gates

- All 4 complication families render correctly in Xcode Watch simulator (Series 9)
- Gold accent applies on both full-colour and tinted watch faces
- Qibla arc rotates live with device heading (simulator simulated heading)
- Haptic fires at prayer time (physical Apple Watch)
- First-launch GPS flow completes without iPhone paired
- Settings changes on watch appear in iPhone app within 30s (WCSession round-trip)

### CI

New scheme `IqamahWatch` added to the CI matrix. watchOS build + unit tests run on `macos-latest` runner (same as existing schemes). No additional infrastructure.

---

## 9. Scope boundaries

**In v1:**
- Prayer times list (Tab 1)
- Qibla compass (Tab 2)
- Full settings on-watch (Tab 3)
- 4 complication families
- Haptic prayer notifications
- Independent GPS (no iPhone required)
- WCSession sync from iPhone

**Explicitly out of v1:**
- Custom adhaan audio (watchOS limitation — system haptic only)
- Hilal Watch crescent map on watch (screen too small; complication crescent icon is a future enhancement)
- visionOS / iPad complications (separate EPIC)
- Watch-to-iPhone settings sync (watch is read-mostly in v1)

---

## 10. ACs covered

- AC-0252: `IqamahWatch` target exists, watchOS 10.0+
- AC-0253: `IqamahCore` dependency, clean build
- AC-0254: Universal purchase, installs automatically on paired watch
- AC-0255: Prayer times list on launch
- AC-0256: `IqamahWatchWidget` WidgetKit timeline provider
- AC-0257: `.accessoryCorner` — prayer initial + countdown
- AC-0258: `.accessoryCircular` — progress arc + name + countdown
- AC-0259: `.accessoryRectangular` — name + relative time + city/method
- AC-0260: `.accessoryInline` — plain text
- AC-0261: Timeline `.policy: .after(nextPrayerDate)`
- AC-0262: Complication reads calculation method from App Group
- AC-0263: `UNNotificationRequest` per enabled prayer
- AC-0264: System haptic sound only
- AC-0265: Notification body "Time for [Prayer]" + city subtitle
- AC-0266: Notification tap → prayer list
- AC-0267: 7-day rolling reschedule
- AC-0268: On-watch `PrayerCalculator` — no network required
- AC-0269: `WCSession.transferUserInfo` from iPhone on settings change
- AC-0270: First-launch placeholder if no settings yet
- AC-0271: App Group fallback when iPhone unreachable
- AC-0272: SwiftUI `List` with Digital Crown scrolling
- AC-0273: Next prayer gold highlight; past prayers dimmed
- AC-0274: 12h/24h follows `use24HourTime` setting
- AC-0275: App icon in all required watchOS sizes

---

**Last Updated:** 2026-05-10 (Initial spec — brainstorming session)
