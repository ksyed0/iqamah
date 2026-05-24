# ENH-0026 — Push-Driven Notifications & Background-Reliable Live Activity (Design)

**Date:** 2026-05-24
**Status:** Design captured → implementation deferred (parked)
**Tracking:** ENH-0026 (docs/ENHANCEMENTS.md)
**Effort estimate (if promoted):** Large (~4–6 weeks first-cut: backend bring-up + Worker port + APNs auth + client registration + privacy review)

---

## 1. Problem statement

PR #133 (commit `405256a`) shipped a foreground-Timer + `staleDate` fix that keeps the Live Activity / Dynamic Island honest while the iOS app is foregrounded or recently backgrounded — the Timer re-evaluates `ContentState` at the next prayer boundary and `staleDate` lets iOS dim the activity once the time has passed. That fix does not cover the fully-suspended case: if iOS suspends Iqamah for several hours (memory pressure, device restart, prolonged background), no Timer fires, no local update is scheduled, and the Live Activity drifts on a passed prayer until the user reopens the app. ENH-0026 designs the path to push-driven updates that work regardless of app suspension state.

## 2. Scope

This design treats **all time-sensitive notifications** — prayer reminders, Fasting Mode Suhoor / Iftar / day-before reminders, and Live Activity content updates — as push-driven from a backend that talks APNs HTTP/2. Local `UNUserNotificationCenter` scheduling and local `Activity.update(...)` calls are retired for these flows, removing a meaningful chunk of per-platform scheduling code and the brittleness that comes with it.

Two ruled-out alternatives are explicitly noted so we don't relitigate them: **CloudKit Functions** (does not exist as a shipped Apple product), and **Synology / home NAS in production** (single home internet pipe cannot reliably reach 100k+ App Store users; fine for staging only). The chosen split is Cloudflare Workers in production and a local-Mac Swift container for staging.

## 3. Final architecture: Cloudflare Workers + local Mac for staging

### Production — Cloudflare Workers

- Workers + Workers KV + Cron Triggers. Free tier covers ~10k MAU; ~$5–$10/month at 100k MAU.
- Worker code is **TypeScript** (one-time port of `FastingNotificationPlanner` + `PrayerCalculator` from Swift). Both are pure functions over inputs already well-tested in `IqamahCoreTests` — the port has a high-confidence test oracle.
- Three logical handlers (one Worker or three, both viable):
  - **Scheduler** (cron) — recomputes notification queue per device.
  - **Sender** (cron) — drains the queue against APNs.
  - **LA Pusher** (cron) — recomputes Live Activity `ContentState` and pushes deltas.
- **Workers KV** holds: `DeviceRegistration` cache, `NotificationPlan` queue, `LiveActivityRegistration` cache, error log.
- APNs HTTP/2 from the Worker via `fetch()` with JWT bearer auth from the `.p8` signing key (stored as a Worker secret).

### Staging — local Mac, no NAS required

- Same architecture in a Swift-on-Linux container running on the developer's Mac via Docker Desktop.
- Reuses `IqamahCore` directly as a vendored SPM dependency — staging and the app share a single source of truth for prayer math, with Workers TS as the production port we periodically diff-check against the Swift oracle.
- Validates the end-to-end push flow against a dev CloudKit container before flipping production.
- Stack: **Hummingbird 2** (HTTP server for admin UI), **APNSwift** (APNs HTTP/2 client), **AsyncHTTPClient** (CloudKit REST), **SQLiteNIO** (queue persistence).
- No auth on the admin UI — LAN-trust is fine for the developer's home network. Retrofit hook is present so a single bearer-token check can be added later without refactoring routes.

## 4. Data model

### 4a. CloudKit records (private DB, per-user)

**`DeviceRegistration`** — one record per device install.

- `recordName`: UUID generated on first launch, persisted in Keychain (survives reinstall iff Keychain entry isn't wiped).
- `pushToken` (String, APNs hex), `platform` (String — `"ios" | "macos" | "watchos"`), `bundleID` (String).
- City fields: `cityName`, `countryCode`, `latitude`, `longitude`, `timezoneIdentifier`.
- `calculationMethod` (String, raw enum value), `asrMethod` (String).
- `prayerAdjustmentsJSON` (String, encoded `[Prayer: Int]`).
- `fastingSettingsJSON` (String, `FastingModeSettings` blob).
- `locale` (String, e.g. `"en-CA"`).
- `lastSeenAt` (Date), `schemaVersion` (Int64, start at `1`).

**`LiveActivityRegistration`** — one record per active Live Activity.

- `recordName`: `Activity.id` UUID.
- `deviceRef` (Reference to `DeviceRegistration`, cascade delete).
- `pushToken` (String, LA-specific token — different from the device token).
- `attributesJSON` (String, `PrayerActivityAttributes` blob).
- `expiresAt` (Date), `registeredAt` (Date).

### 4b. Workers KV / SQLite queue schema (server-side persistent storage)

The SQLite schema below is the staging container's source of truth. In Workers KV each table becomes a namespace; queries degrade to namespace scans + in-memory filters (acceptable at the volumes we expect because the hot query is "due in the next 30s" and the queue is sharded per-device).

```sql
CREATE TABLE notification_plan (
  id TEXT PRIMARY KEY,             -- deterministic: "{deviceID}.{kind}.{yyyy-MM-dd}"
  device_id TEXT NOT NULL,
  push_token TEXT NOT NULL,        -- snapshot at compute time
  bundle_id TEXT NOT NULL,
  fire_time INTEGER NOT NULL,      -- Unix epoch ms UTC
  kind TEXT NOT NULL,              -- 'fasting_suhoor' | 'fasting_iftar' | 'fasting_daybefore' | 'prayer_fajr' | ...
  payload_json TEXT NOT NULL,      -- full APNs aps payload as JSON
  sent_at INTEGER,                 -- NULL until sent
  last_error TEXT,
  attempts INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  computed_from TEXT NOT NULL      -- 'daily_cron' | 'settings_change' | 'manual_recompute'
);
CREATE INDEX idx_due ON notification_plan (fire_time) WHERE sent_at IS NULL;

CREATE TABLE device_cache (
  device_id TEXT PRIMARY KEY,
  fetched_at INTEGER NOT NULL,
  registration_json TEXT NOT NULL
);

CREATE TABLE error_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  occurred_at INTEGER NOT NULL,
  device_id TEXT,
  kind TEXT NOT NULL,
  message TEXT NOT NULL,
  context_json TEXT
);
CREATE INDEX idx_error_recent ON error_log (occurred_at DESC);

CREATE TABLE service_state (
  key TEXT PRIMARY KEY,
  value_json TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### 4c. APNs payload format

**Notification push (Suhoor, Iftar, etc.):**

```json
{
  "aps": {
    "alert": {
      "title": "🌙 Suhoor reminder",
      "title-loc-key": "fasting.suhoor.title",
      "body": "Suhoor ends in 30 min",
      "loc-key": "fasting.suhoor.body",
      "loc-args": ["30"]
    },
    "sound": "adhaan_fajr_1_notif.mp3",
    "category": "FASTING_SUHOOR",
    "thread-id": "fasting-mode",
    "interruption-level": "time-sensitive",
    "relevance-score": 1.0
  },
  "iqamah": {
    "kind": "fasting_suhoor",
    "fire_time_utc": 1764556800,
    "scheduler_version": 1,
    "for_local_date": "2026-03-15"
  }
}
```

APNs HTTP/2 headers per request:

- `apns-topic: com.fablesoft.iqamah`
- `apns-push-type: alert`
- `apns-priority: 10` (immediate for prayer alerts)
- `apns-expiration: fire_time + 60` (don't deliver stale pushes)
- `apns-collapse-id: notification_plan.id` (idempotency — re-sends replace)
- `authorization: bearer <JWT from .p8 key>`

**Live Activity update push:**

```json
{
  "aps": {
    "timestamp": 1764556800,
    "event": "update",
    "content-state": {
      "nextPrayerName": "Isha",
      "nextPrayerTime": 1764568800,
      "followingPrayerName": "Fajr",
      "moonPhase": 0.42,
      "hijriDateString": "23 Sha'ban 1447"
    },
    "stale-date": 1764568860,
    "alert": { "title": "Prayer time", "body": "Isha at 8:45 PM" }
  }
}
```

LA push headers: `apns-topic: com.fablesoft.iqamah.push-type.liveactivity`, `apns-push-type: liveactivity`, `apns-priority: 5`, `apns-expiration: 0`.

## 5. Per-flow detail

### Scheduler

- **Triggers:** daily cron at 04:00 UTC, 15-min CloudKit change-poll, on-demand `POST /api/recompute`.
- For each device, compute the next **30 days** of plans, atomic SQLite transaction:

```sql
BEGIN;
  DELETE FROM notification_plan WHERE device_id=? AND sent_at IS NULL AND fire_time > now();
  INSERT new plans (deterministic IDs, INSERT OR REPLACE);
COMMIT;
```

- Deterministic IDs (`{deviceID}.{kind}.{yyyy-MM-dd}`) make the operation idempotent: re-running produces the same queue state.

### Sender (notifications)

- 30-second tick. Query `WHERE sent_at IS NULL AND fire_time <= now() LIMIT 100`.
- Send via APNs with `TaskGroup` concurrency 8.
- Success → `UPDATE sent_at`. Failure → `UPDATE attempts++`, log error. 5 attempts max.
- APNs `410 Gone` → mark device's token invalid, stop sending until the app re-registers.

### LA Pusher

- 60-second tick. Query active `LiveActivityRegistration` records.
- For each, compute current `ContentState`. If it differs from the last push, send an LA update.
- No retries — the next tick recomputes anyway.

### Settings-change propagation (Mumbai → Delhi trace)

1. App writes new `DeviceRegistration` to CloudKit.
2. App opportunistically `POST`s to backend (~200ms on home Wi-Fi, fails silently on cellular — that's fine, see step 3).
3. Backend Scheduler picks up the change via the opportunistic POST **or** the 15-minute CloudKit change-poll.
4. Atomic transaction: DELETE old future plans + INSERT new ones.
5. Sender's next 30-second tick fires the new times.
6. LA Pusher's next 60-second tick updates the LA `ContentState`.

## 6. Why deferred

- Requires committing to **backend operations** — cost, SLA, monitoring, on-call. That's a meaningful identity shift from today's "client-only, no servers" posture.
- ~$5–$10/mo at 100k MAU is the minimum credible cost; not free.
- **Privacy / GDPR implications** when settings + location flow through developer infrastructure (vs staying device-local today). User-facing privacy policy and the Apple privacy manifest both need rework.
- **ENH-0027** (cross-ecosystem expansion to Windows / Linux / Android) may change infrastructure decisions; worth waiting until that direction settles before sinking time into an Apple-only push backend.

## 7. Promotion criteria

Promote to EPIC + US when **all three** of these are true:

1. Product decision made to commit to backend ops.
2. Privacy review covers what user data leaves the device.
3. Funding model (or developer's personal cost tolerance) agreed for hosting.

## 8. References

- PR #133 commit `405256a` — current foreground LA fix.
- `iqamah/iOS/PrayerActivityManager.swift` — current Timer-based implementation.
- `IqamahLiveActivity/PrayerActivityAttributes.swift` — `ContentState` shape (single source post-consolidation).
- Apple ActivityKit push-token documentation.
- Cloudflare Workers docs — Workers KV, Cron Triggers, scheduled handlers.
- APNSwift, Hummingbird 2, SQLiteNIO — for the Swift staging container.
