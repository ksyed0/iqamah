# US-0045 Design Spec — Live Activity 1-Hour-Before Auto-Start

**Date:** 2026-07-23 (revised 2026-07-24)
**Story:** US-0045 (EPIC-0010) — iOS Live Activity / Dynamic Island
**Status:** 🟡 Design — ready for implementation

---

## Problem Statement

`PrayerActivityManager.startOrUpdateActivity()` is called only on app-active events (foreground opens). The Live Activity therefore only appears if the user manually opens the app before a prayer. AC-0198 requires it to appear "within one minute of the one-hour-before mark" automatically — no user interaction required.

---

## Existing Architecture (What We Have)

```
App opens → iqamahApp_iOS.swift → startOrUpdateActivity(settings:)
                                         │
                              PrayerActivityManager
                              ├── builds ContentState (next prayer + fasting)
                              ├── Activity.request() or Activity.update()
                              └── scheduleRollover(at: nextPrayerTime + 1s)
                                        │
                                   Timer fires after prayer passes
                                        │
                                   startOrUpdateActivity() again (next prayer)
```

**Gap:** The rollover timer advances the LA *after* a prayer passes. Nothing *proactively starts* it 1h before a prayer. If the user last opened the app at 8:00 AM before Dhuhr at 1:15 PM, the LA is silent from 8:01 AM until they open the app again — or until Dhuhr passes and nothing fires.

---

## Constraints

| Constraint | Detail |
|---|---|
| ActivityKit start requires foregrounded or active context | `Activity.request()` cannot be called while fully suspended. It CAN be called during a BGTask execution window. |
| BGAppRefreshTask is opportunistic | iOS schedules it "around" the earliest begin date; not sub-minute precise. |
| 64 pending UNNotifications limit | Already using ≤35 for prayers. Budget available for T-1h markers. |
| ENH-0026 (push-driven LA) deferred | Server-side push updates are the gold-standard fix but require backend ops commitment. This spec is the client-only path. |
| Per-prayer toggles (US-0043) | `settings.isPrayerEnabled(name)` must gate LA start. |

---

## Approach Options

### Option 1 — Foreground Preemptive Timer (fast, low-risk)

Extend the existing `scheduleRollover` pattern. After `startOrUpdateActivity()` succeeds, schedule a second timer at `followingPrayer.time - 3600s`. When that timer fires (app still in foreground or recently backgrounded), call `startOrUpdateActivity()` which will now show the following-prayer countdown.

```
Prayer A at 13:15 → LA starts when app opens (say 12:00)
                  → schedulePreLaunch(for: Prayer B at 15:45)
                  → At 14:45, timer fires → startOrUpdateActivity() → LA updates to Prayer B
```

**Pro:** Zero new entitlements; pure Timer + existing machinery.
**Con:** App must remain in memory from "last open" to "T-1h mark". Fully suspended apps miss it.

---

### Option 2 — BGAppRefreshTask (background, best-effort)

Register a BGTask that iOS wakes the app to execute around T-1h before each prayer. iOS 13+ permits `Activity.request()` inside a BGTask handler.

**Steps:**
1. Add `BGTaskSchedulerPermittedIdentifiers` to Info.plist: `["com.fablesoft.iqamah.prayerLARefresh"]`
2. Add `fetch` to `UIBackgroundModes`
3. Register task in `IqamahiOSApp.init()` using `BGTaskScheduler.shared.register(...)` — **must happen before first scene body render; there is no AppDelegate lifecycle in this app**
4. Schedule via `BGTaskScheduler.shared.submit(...)` with `earliestBeginDate` = T-55min before next prayer (5-minute buffer so the task runs before T-1h rather than after)
5. In the handler: call `PrayerActivityManager.startOrUpdateActivity(settings: .shared)`

**Pro:** Works even if app was fully suspended overnight.
**Con:** BGAppRefresh is opportunistic — iOS may fire it late (up to several hours) during Low Power Mode or if the device hasn't been used recently. Not sub-minute precise. "Within one minute" (AC-0198) is best-effort, not guaranteed, on the client-only path.

---

### Option 3 — UNCalendarNotification as a Wake Trigger

iOS does NOT allow starting a Live Activity from a local notification delivery (no background execution). Silent push requires APNs (server). **This path is not viable for local notifications.**

---

### Recommended: Option 1 + Option 2 Combined

| Scenario | Coverage |
|---|---|
| User opened app within the last hour | Option 1 foreground timer fires at T-1h → LA starts instantly |
| App backgrounded but not suspended (≤30 min since last open) | Option 1 timer still fires in background (RunLoop.main runs for ~10 min after background) |
| App fully suspended, device used regularly | Option 2 BGTask wakes app around T-1h |
| App fully suspended, Low Power Mode / overnight | Best-effort; may fire late. ENH-0026 push path is the complete fix. |

In practice, most users check the app within an hour before prayers. Option 1 covers that majority. Option 2 covers the overnight case.

---

## Implementation Plan

### Task 0 — Extract shared prayer-finding helper

**Why:** `buildContentState` already finds `followingPrayer` internally but only surfaces `followingPrayerName` (a `String`) in the `ContentState` struct — `followingPrayer.time` is not accessible from the return value. The pre-launch timer and the BGTask scheduling both need the time. Additionally, `scheduleBGRefreshTask()` would otherwise duplicate the same prayer-finding loop a third time.

**Fix:** Extract into a private helper that both callers share.

**File:** `iqamah/iOS/PrayerActivityManager.swift`

```swift
private func findUpcomingPrayers(settings: SettingsManager)
    -> (next: (name: String, time: Date)?, following: (name: String, time: Date)?)
{
    guard let coord = settings.activeCoordinate,
          let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier) else {
        return (nil, nil)
    }
    let calc = PrayerCalculator(coordinate: coord, timezone: timezone,
                                method: settings.calculationMethod,
                                asrMethod: settings.asrMethod)
    let now = Date()
    var next: (name: String, time: Date)?
    var following: (name: String, time: Date)?

    for dayOffset in 0...1 {
        guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now),
              let times = try? calc.calculate(for: day) else { continue }
        let upcoming = times.prayers.filter { $0.time > now && $0.name != "Sunrise" }
        for prayer in upcoming {
            if next == nil { next = (prayer.name, prayer.time) }
            else if following == nil { following = (prayer.name, prayer.time); break }
        }
        if following != nil { break }
    }
    return (next, following)
}
```

Update `buildContentState` to call `findUpcomingPrayers(settings:)` instead of its inline loop.
Update `startOrUpdateActivity` to call `findUpcomingPrayers(settings:)` and pass `following` to both `schedulePreLaunch` and `scheduleBGRefreshTask`.

---

### Task 1 — Add pre-launch timer to `PrayerActivityManager`

**File:** `iqamah/iOS/PrayerActivityManager.swift`

```swift
private var preLaunchTimer: Timer?

// In startOrUpdateActivity, after scheduleRollover(at: state.nextPrayerTime):
let (_, following) = findUpcomingPrayers(settings: settings)
if let following {
    schedulePreLaunch(for: following, settings: settings)
}

private func schedulePreLaunch(
    for prayer: (name: String, time: Date),
    settings: SettingsManager
) {
    preLaunchTimer?.invalidate()
    guard settings.isPrayerEnabled(prayer.name) else { return }
    let fireDate = prayer.time.addingTimeInterval(-3600)
    guard fireDate > Date() else { return }  // already inside the 1h window
    let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
        Task { @MainActor in
            await self?.startOrUpdateActivity(settings: SettingsManager.shared)
        }
    }
    preLaunchTimer = timer
    RunLoop.main.add(timer, forMode: .common)
}
```

Update `endActivity()` to also invalidate `preLaunchTimer`:
```swift
func endActivity() async {
    rolloverTimer?.invalidate()
    rolloverTimer = nil
    preLaunchTimer?.invalidate()     // ← add this
    preLaunchTimer = nil             // ← add this
    // ... rest unchanged
}
```

**Edge cases:**
- *Already inside the 1h window:* `fireDate > Date()` guard returns early; `startOrUpdateActivity` is already running the LA for the current prayer.
- *Following prayer disabled:* `isPrayerEnabled` guard returns early; timer is not scheduled.
- *Following prayer > 24h away (post-Isha):* Timer is valid but sleeps in the RunLoop. Invalidated on next `startOrUpdateActivity` call. No issue.

---

### Task 2 — BGAppRefreshTask registration

**Critical:** The identifier string `"com.fablesoft.iqamah.prayerLARefresh"` must match exactly between Info.plist and the `register(...)` call. A mismatch fails silently — the task never fires.

**File:** `iqamah/iOS/Info.plist`

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.fablesoft.iqamah.prayerLARefresh</string>
</array>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
</array>
```

**File:** `iqamah/iOS/iqamahApp_iOS.swift`

`import BackgroundTasks` goes inside `#if os(iOS)` at the top of the file — the visionOS build path compiles this same file and `BackgroundTasks` is not available there.

Register the task in `IqamahiOSApp.init()`, after the existing `--uitesting` guard:

```swift
#if os(iOS)
import BackgroundTasks
#endif

// In IqamahiOSApp.init():
#if os(iOS)
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.fablesoft.iqamah.prayerLARefresh",
    using: nil
) { task in
    task.expirationHandler = {
        task.setTaskCompleted(success: false)
    }
    Task { @MainActor in
        await PrayerActivityManager.shared.startOrUpdateActivity(
            settings: SettingsManager.shared
        )
        PrayerActivityManager.shared.scheduleBGRefreshTask(settings: SettingsManager.shared)
        task.setTaskCompleted(success: true)
    }
}
#endif
```

`expirationHandler` is required: if iOS cancels the task before the async work completes (system pressure, ~30s time limit), calling `setTaskCompleted(success: false)` preserves iOS's willingness to reschedule.

Both `startOrUpdateActivity` and `scheduleBGRefreshTask` are `@MainActor`-isolated, so they must be called inside `Task { @MainActor in }`. `setTaskCompleted` and `scheduleBGRefreshTask` both go inside that block so they run after the await.

**File:** `iqamah/iOS/PrayerActivityManager.swift`

```swift
func scheduleBGRefreshTask(settings: SettingsManager) {
    let (_, following) = findUpcomingPrayers(settings: settings)
    // If already inside the 1h window, target the prayer after following
    // (findUpcomingPrayers already skips passed prayers, so `following` is
    // the next unapproached prayer after `next`).
    guard let target = following,
          settings.isPrayerEnabled(target.name) else { return }
    let fireDate = target.time.addingTimeInterval(-3600 + 300)  // T-55min
    guard fireDate > Date() else { return }  // inside window, nothing to schedule

    let request = BGAppRefreshTaskRequest(identifier: "com.fablesoft.iqamah.prayerLARefresh")
    request.earliestBeginDate = fireDate
    try? BGTaskScheduler.shared.submit(request)
}
```

Note: `BGTaskScheduler.shared.submit` replaces any previously pending request with the same identifier — no need to cancel before re-submitting.

Call `scheduleBGRefreshTask(settings:)` at the end of `startOrUpdateActivity`:
```swift
scheduleBGRefreshTask(settings: settings)
```

---

### Task 3 — Hook into settings changes via existing `reschedule()`

The existing `reschedule()` function in `iqamahApp_iOS.swift` is already called from every settings-change `.onChange` (calculationMethod, asrMethod, enabledPrayers) and on `scenePhase == .active`. Adding one line there covers all call sites automatically:

```swift
private func reschedule() {
    Task { await NotificationScheduler.shared.rescheduleAll() }
    PrayerActivityManager.shared.scheduleBGRefreshTask(settings: settings)  // ← add
}
```

No changes needed to the `settingsDidChange` receiver or individual `.onChange` closures.

---

### Task 4 — AC-0202: Per-prayer toggle gate (already covered)

- `schedulePreLaunch(for:settings:)` checks `isPrayerEnabled` before scheduling the timer (Task 1).
- `scheduleBGRefreshTask(settings:)` checks `isPrayerEnabled` before submitting the BGTask (Task 2).
- `buildContentState` already skips disabled prayers when computing `nextPrayer`, so the LA content never shows a disabled prayer.

No additional work required.

---

### Task 5 — AC-0198 best-effort caveat in RELEASE_PLAN.md

Update AC-0198 to reflect the client-only limitation:

> **AC-0198:** Activity appears in the Dynamic Island within one minute of the one-hour-before mark for prayers **when the app has been used within the preceding hour** (foreground timer path, exact). Best-effort via BGAppRefreshTask when the app is fully suspended; guaranteed sub-minute timing for suspended devices requires ENH-0026 (push-driven Live Activity updates).

---

## Acceptance Criteria Mapping

| AC | Coverage | Path |
|---|---|---|
| AC-0198: Appears within 1 min of T-1h | Foreground: timer fires exactly at T-1h. Suspended: BGTask fires ~T-1h (best effort). | Task 1 + Task 2 |
| AC-0199: Compact/expanded/minimal DI render correctly | Already implemented | Existing |
| AC-0200: Lock Screen countdown accurate | Already implemented | Existing |
| AC-0201: Activity ends at prayer time | `scheduleRollover` already handles this | Existing |
| AC-0202: Disabled prayer → no LA | `isPrayerEnabled` guard in timer + BGTask | Task 1 + Task 2 |
| AC-0203: No duplicate activities | `Activity.activities` dedup in `startOrUpdateActivity` already present | Existing |

---

## Files Touched

| File | Change |
|---|---|
| `iqamah/iOS/PrayerActivityManager.swift` | Add `findUpcomingPrayers()`, `preLaunchTimer`, `schedulePreLaunch()`, `scheduleBGRefreshTask()`; update `endActivity()` |
| `iqamah/iOS/iqamahApp_iOS.swift` | `import BackgroundTasks` (inside `#if os(iOS)`), register BGTask in `init()`, add `scheduleBGRefreshTask` call to `reschedule()` |
| `iqamah/iOS/Info.plist` | `BGTaskSchedulerPermittedIdentifiers`, `UIBackgroundModes = [fetch]` |
| `docs/RELEASE_PLAN.md` | Update AC-0198 with client-only precision caveat |

---

## What This Does NOT Solve

- **Full background reliability** when app is suspended for >1h with Low Power Mode: still requires ENH-0026 push infrastructure.
- **Sub-minute BGTask precision**: iOS schedules BGAppRefreshTask opportunistically. In adverse conditions (Low Power Mode, infrequent app use), it may fire 30+ minutes late.
- **Simulator testing of BGTask**: Use the LLDB command `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.fablesoft.iqamah.prayerLARefresh"]` to trigger the task in-session. Cannot be reliably automated in XCUITest.

---

## Effort Estimate

| Task | Points |
|---|---|
| Task 0 (extract `findUpcomingPrayers` helper) | 0.5 |
| Task 1 (pre-launch timer) | 1 |
| Task 2 (BGTask registration + handler) | 2 |
| Task 3 (settings change hook via `reschedule()`) | 0.5 |
| Task 4 (per-prayer toggle — already covered) | 0 |
| Task 5 (AC caveat doc update) | 0.5 |
| **Total** | **~4.5 SP** |

Aligns with the 5 SP estimate in the story. One session of work.
