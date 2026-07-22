# ENH-0021 — Apple Vision Pro App (visionOS Design)

**Date:** 2026-07-20
**Status:** Brainstorm complete → ready for plan
**Tracking:** ENH-0021 (docs/ENHANCEMENTS.md)
**Effort estimate:** Path 1: ~1 day (done). Path 2: ~6–8 weeks.
**Promotion target:** EPIC-0018 / US-0076–US-0080

---

## Background

ENH-0021 was logged as a placeholder ("ENH-0017 — Apple Vision Pro App") and later expanded. visionOS is the only Apple platform on which no prayer app has a native spatial experience. The "designed for iPad" compatibility path (Path 1) ships Iqamah on Vision Pro at near-zero cost; a native path (Path 2) adds ornaments, a spatial Qibla volume, and an immersive adhan space — experiences only possible on Vision Pro.

The iOS app (EPIC-0010) is the foundation for both paths. IqamahCore, SettingsManager, PrayerCalculator, FastingModeEngine, and all shared views compile on visionOS unchanged.

## Path 1 status

**✅ Complete (2026-07-20).** `UIRequiresFullScreen = NO` added to `iqamah/iOS/Info.plist`. The iOS binary now advertises that it does not require full-screen display, which is the flag visionOS checks to allow the app to run in a resizable floating window. Next step: test on visionOS 26.5 simulator (SDK must be installed), then submit to App Store Connect under the existing Universal Purchase record.

---

## Goals (Path 2)

1. **Persistent glanceable presence** — a bottom ornament showing next prayer + Hijri date survives window minimisation and stays visible while the user is in other apps.
2. **Uniquely spatial Qibla** — a 3D volumetric compass that ARKit-tracks head orientation and points toward Makkah after a one-time North calibration; not achievable on any other platform.
3. **Immersive adhan moment** — an opt-in `ImmersiveSpace(.mixed)` that plays the adhan from a spatial audio point source above the user, pairing the call to prayer with a light ambient visual.
4. **Fasting Mode parity** — ornament relabels to Suhoor/Iftar countdowns during fasting days, reusing the existing `FastingLabelFormatter` without new logic.
5. **Liquid Glass chrome** — ornament and volume surfaces use `.glassBackgroundEffect()`, the visionOS-native material; `.glassEffect()` applied via `@available(visionOS 26, *)` when running on visionOS 26+.

## Out of scope (Path 2 v1)

- **Persistent ImmersiveSpace**: visionOS policy requires user interaction to open an ImmersiveSpace. Auto-opening at prayer time is not possible and will not be attempted.
- **watchOS / macOS / tvOS changes**: this work is visionOS-only; no other platform is touched.
- **Backend push (ENH-0026)**: adhan in the immersive space is foreground-only; background spatial audio requires the ENH-0026 push infrastructure.
- **Full Arabic text overlay in the immersive space**: v1 shows the prayer name only; a full adhan text display is a v2 enhancement.
- **Shared `IqamahVisionOS` App Store record**: visionOS ships as part of the Universal Purchase (same iTunes ID, "Designed for iPad" compatibility for Path 1, native when Path 2 is promoted); no new App Store record is needed.

---

## Decisions captured during brainstorming (2026-07-20)

1. **Qibla on Vision Pro uses ARKit face-North calibration** — Vision Pro has no magnetometer; `CLLocationManager.headingAvailable` returns false. Path 2 solves this via a one-time calibration gesture: user taps a button when facing North; `WorldTrackingProvider.DeviceAnchor` captures the forward vector in world space as the North reference; subsequent rotation updates orient the 3D Qibla arrow accordingly. Path 1 falls back to a bearing-only text card (great-circle degrees + "face North" instruction).

2. **Full scope for v1 native**: Window + Ornament + Qibla Volume + ImmersiveSpace Adhan. No scope reduction.

3. **Extend iOS target, not a new target** — the iOS target already deploys to visionOS in compat mode. Path 2 adds `#if os(visionOS)` conditionals to `iqamahApp_iOS.swift` (additional scenes) and new `IqamahVisionOS/` source group for the visionOS-only views. Bundle ID and Universal Purchase record remain `com.fablesoft.iqamah`.

4. **Ornament: compact, bottom-anchored** — single ornament below the main window: `🕌 Dhuhr  1:42:30  •  5 Dhul-Hijjah`. When Fasting Mode is active within 2 h of Fajr/Maghrib: `🌙 Suhoor  0:27:14  •  5 Dhul-Hijjah`. Reads from `FastingLabelFormatter` — zero new logic.

5. **Hilal Watch opens in a wider window on visionOS** — `.defaultSize(CGSize(width: 900, height: 700))` applied via `#if os(visionOS)`. The S-curve arcs are legible without pinch-zoom at this size.

6. **ImmersiveSpace is opt-in foreground only** — at prayer time, if the app is foregrounded, `AdhaanBannerView` gains a visionOS-conditional "Open in Space" button that calls `openImmersiveSpace(id: "adhan-space")`. The ImmersiveSpace auto-closes after the adhan ends + 30 s.

---

## Scene Architecture

```
iqamahApp_iOS.swift @main
  │
  ├── WindowGroup (main)
  │     iOSRootView
  │       .ornament(attachmentAnchor: .scene(.bottom))   [visionOS only]
  │         NextPrayerOrnament
  │
  ├── WindowGroup(id: "qibla-volume")                    [visionOS only]
  │     .windowStyle(.volumetric)
  │     .defaultSize(0.5 m × 0.5 m × 0.5 m)
  │     QiblaVolumeView
  │       RealityView → QiblaArrowEntity + CrescentEntity
  │
  └── ImmersiveSpace(id: "adhan-space")                  [visionOS only]
        .immersionStyle(.mixed)
        AdhanImmersiveView
          RealityView → AmbientParticleSystem
          SpatialAdhanPlayer (AVAudioEnvironmentNode)
```

`#if os(visionOS)` guards all three additions. The iOS `WindowGroup` body is shared verbatim.

---

## Ornament

### Placement

`.ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .center)` — floats below the main window. Standard visionOS convention for persistent status information.

### Content

```
┌──────────────────────────────────────────────────────┐
│  🕌  Asr   •   2h 14m 30s   •   5 Dhul-Hijjah 1448  │
└──────────────────────────────────────────────────────┘
```

- Prayer icon: `systemImage` per prayer (fajr → `moon.stars`, sunrise → `sunrise`, dhuhr → `sun.max`, asr → `sun.min`, maghrib → `sunset`, isha → `moon`)
- Countdown: `monospacedDigit()` font, updates every second via `Timer.publish(every: 1, on: .main, in: .common)`
- Hijri date: same string as the main window header
- Fasting active (within 2 h of Fajr/Maghrib): relabel via `FastingLabelFormatter.prayerLabel(state:prayerName:within2hWindow:isShiaMethod:)` — no new logic

### Styling

```swift
.padding(.horizontal, 24)
.padding(.vertical, 12)
.glassBackgroundEffect()              // visionOS 1.0 glass material
// If visionOS 26:
// .glassEffect()                     // @available(visionOS 26, *)
```

### Implementation file

`iqamah/iOS/visionOS/NextPrayerOrnament.swift` — new, visionOS only.

---

## Qibla Volume

### Overview

A `.volumetric` `WindowGroup` containing a 3D Qibla compass: a crescent pointer that rotates in world space to always point toward Makkah, after the user completes a one-time North calibration.

### Why a volume (not a flat window)

The Qibla direction is a bearing in 3D space — the user's body faces a physical direction. A flat 2D compass rendered in a window is no better than iPhone. A volumetric arrow that rotates in the actual room is the spatial affordance that justifies the Vision Pro experience.

### Qibla Volume Views

**`QiblaVolumeView`** — the root visionOS scene content:

```
┌─────────────────────────────────────┐
│                                     │
│        [3D crescent arrow]          │  ← RealityView
│         ↑ rotates toward Makkah     │
│                                     │
│  Calibration state overlay:         │
│  ● "Face North → Tap to Calibrate"  │  ← shown until calibrated
│  ● Bearing: 312°  (after calib.)    │
│  ● Distance: 11,492 km              │
└─────────────────────────────────────┘
```

### ARKit Calibration Flow

**Step 1 — Open volume.** User taps "Open Qibla in Space" button in the main window's Qibla tab. `openWindow(id: "qibla-volume")` is called.

**Step 2 — Calibration prompt.** The volume shows the 3D arrow in a neutral orientation + a prominent button: `"Face North and tap to calibrate"`. A secondary label shows the bearing in degrees from the user's GPS location to Makkah (computed from `QiblaCalculator.bearing(from:to:)` — already available).

**Step 3 — Capture North reference.** On button tap:
```swift
let session = ARKitSession()
let worldTracking = WorldTrackingProvider()
await session.run([worldTracking])
let anchor = await worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
northTransform = anchor?.originFromAnchorTransform  // simd_float4x4
```
The device's forward vector (column 2, negated, in world space) at tap time becomes `worldNorthForward`. Stored in `QiblaCalibrationState`.

**Step 4 — Live tracking.** On each frame update from `worldTracking.anchorUpdates`:
```swift
let currentTransform = anchor.originFromAnchorTransform
let currentForward = -normalize(SIMD3<Float>(currentTransform.columns.2.x,
                                             currentTransform.columns.2.y,
                                             currentTransform.columns.2.z))
let angleFromNorth = atan2(
    dot(cross(worldNorthForward.xz, currentForward.xz), SIMD2<Float>(0, 1)),
    dot(worldNorthForward.xz, currentForward.xz)
)
let qiblaAngle = -Float(qiblaBearing.radians) + angleFromNorth
qiblaArrow.transform.rotation = simd_quatf(angle: qiblaAngle, axis: [0, 1, 0])
```
The arrow rotates to point toward Makkah in the real room.

**Calibration persistence.** `northTransform` is stored in `UserDefaults` as `Data` (encoded `simd_float4x4`). On next volume open, the stored transform is used immediately. A "Recalibrate" button resets it. Invalidated when the user physically moves to a new room (detected via WorldAnchor drift > 1 m — trigger recalibration prompt).

### 3D Arrow Model

`QiblaArrowEntity` — composed from `ModelEntity` primitives:

- **Shaft**: `MeshResource.generateCylinder(height: 0.25, radius: 0.015)`, rotated 90° to lie horizontal
- **Head**: `MeshResource.generateCone(height: 0.08, radius: 0.035)`, attached at the positive end of the shaft
- **Crescent**: A `MeshResource` generated from a parametric crescent shape (subtract smaller circle from larger arc), positioned above the arrowhead — the Islamic visual cue

Material: `SimpleMaterial(color: UIColor(Color.gold), roughness: 0.2, isMetallic: true)` — the app's gold accent color. Slight emission so it's readable in bright rooms.

Volume chrome: `.glassBackgroundEffect()` — the volume floats with visionOS's glass look, matching the ornament.

### Fallback (pre-calibration / calibration lost)

- 3D arrow is displayed in a neutral "North" orientation with a pulsing opacity
- Bearing card text: `"Makkah is 312° — face North, then turn right 42°"`
- This is also the fallback for Path 1 (compat mode), displayed in a regular 2D window

### Implementation files

- `iqamah/iOS/visionOS/QiblaVolumeView.swift` — new
- `iqamah/iOS/visionOS/QiblaCalibrationState.swift` — new; `@Observable` class holding `northTransform`, calibrated Bool, bearing, distance
- `iqamah/iOS/visionOS/QiblaArrowEntity.swift` — new; RealityKit `Entity` subclass

---

## Immersive Adhan Space

### Concept

At prayer time, if Iqamah is foregrounded, the `AdhaanBannerView` gains a visionOS-conditional "Open in Space" button. Tapping it opens an `ImmersiveSpace` in `.mixed` immersion — the user's real room is still visible, but a subtle ambient effect plays and the adhan audio comes from a spatial point source above them. The experience lasts for the adhan duration + a 30-second fade.

This is the closest a software app can come to the experience of hearing a muezzin's call from a minaret.

### ImmersiveSpace content (`AdhanImmersiveView`)

**Audio:** `SpatialAdhanPlayer` — wraps `AVAudioEngine` + `AVAudioEnvironmentNode`:
```swift
let engine = AVAudioEngine()
let environment = AVAudioEnvironmentNode()
engine.attach(environment)
engine.connect(environment, to: engine.mainMixerNode, format: nil)
environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)  // user's head
environment.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)

let player = AVAudioPlayerNode()
engine.attach(player)
engine.connect(player, to: environment, format: adhaan.processingFormat)
player.position = AVAudio3DPoint(x: 0, y: 2.5, z: -1)  // 2.5m above, slightly forward (minaret metaphor)
player.reverbBlend = 0.3  // slight reverb — open-air space
```

With AirPods Pro / AirPods Max: head-tracked spatial audio. The minaret stays "above" even as the user turns.
Without headphones: falls back to mono + reverb from the device speaker.

**Visual:** `RealityView` with a particle system:
- 200–400 small luminous particles in a cylinder above the user (r: 3 m, h: 4 m), slowly drifting upward
- Particle color: soft gold/amber, very low opacity (0.05–0.15)
- Effect: like soft light or dust motes in a courtyard, not cartoonish
- Two text labels float at `y = 1.8` (eye level): prayer name (e.g., "Dhuhr") and "Allāhu Akbar" in Arabic — fade in 2 s after adhan starts

**Lifecycle:**
1. `openImmersiveSpace(id: "adhan-space")` called from `AdhaanBannerView`
2. Space opens → `SpatialAdhanPlayer.play()` starts
3. After adhan audio ends + 30 s → `dismissImmersiveSpace()` called automatically
4. User can also dismiss by pressing the Digital Crown

### Trigger from AdhaanBannerView

```swift
#if os(visionOS)
Button("Open in Space") {
    Task { await openImmersiveSpace(id: "adhan-space") }
}
.buttonStyle(.bordered)
#endif
```

The `openImmersiveSpace` environment action is available from SwiftUI on visionOS. No separate entry point needed.

### What does NOT change

- The standard `UNUserNotificationCenter` adhan notifications fire as usual — lock screen banner + notification sound. Spatial audio is foreground-only.
- The regular `AdhaanBannerView` still shows on visionOS. The "Open in Space" button is additive.

### Implementation files

- `iqamah/iOS/visionOS/AdhanImmersiveView.swift` — new
- `iqamah/iOS/visionOS/SpatialAdhanPlayer.swift` — new; wraps `AVAudioEngine` setup
- `iqamah/iOS/visionOS/AmbientParticleSystem.swift` — new; `RealityView` particle emitter configuration

---

## Hilal Watch on visionOS

No new logic. One conditional size override in `HilalWatchView.swift` (or the sheet/navigation wrapper that presents it):

```swift
// In the WindowGroup or NavigationStack that hosts HilalMapView:
#if os(visionOS)
.defaultSize(CGSize(width: 900, height: 700))
#endif
```

The S-curve visibility arcs, the colour-coded cells, and the local sighting card are all fully readable at 900 × 700 without pinch-zoom. MapKit on visionOS renders identically to iPadOS.

---

## Fasting Mode Integration

Zero new logic required. The ornament reads from `SettingsManager.shared.fastingModeSettings` and calls `FastingModeEngine.evaluate(for:settings:hijriCalendar:timezone:)` on every render tick. `FastingLabelFormatter.prayerLabel(state:prayerName:within2hWindow:isShiaMethod:)` returns the relabeled prayer name + glyph. The ornament substitutes `Suhoor`/`Iftar` exactly as the macOS menu bar does.

---

## Liquid Glass

| Surface | visionOS 1.0–25 | visionOS 26+ |
|---|---|---|
| Ornament background | `.glassBackgroundEffect()` | `.glassEffect()` via `@available(visionOS 26, *)` |
| Volume chrome | `.glassBackgroundEffect()` on RealityView overlay | Same |
| Main window | System default visionOS window chrome | System chrome (already glass) |
| Immersive space | No chrome (immersive) | No chrome |

`.glassBackgroundEffect()` is the visionOS 1.0 API. `.glassEffect()` was introduced with iOS 26 / macOS 26 / visionOS 26 simultaneously, so the `@available(visionOS 26, *)` guard is the right syntax.

---

## Architecture

### Where code lives

```
iqamah/iOS/visionOS/              (new source group, visionOS target membership only)
  NextPrayerOrnament.swift        — SwiftUI ornament view
  QiblaVolumeView.swift           — root volumetric scene content
  QiblaCalibrationState.swift     — @Observable calibration state
  QiblaArrowEntity.swift          — RealityKit entity
  AdhanImmersiveView.swift        — ImmersiveSpace content
  SpatialAdhanPlayer.swift        — AVAudioEngine spatial wrapper
  AmbientParticleSystem.swift     — particle emitter for adhan space
```

All existing shared files (`iOSRootView`, `PrayerTimesView`, `HilalWatchView`, etc.) are unchanged. visionOS-specific additions are `#if os(visionOS)` guarded at call sites.

### `iqamahApp_iOS.swift` additions

```swift
var body: some Scene {
    WindowGroup {
        iOSRootView()
        #if os(visionOS)
            .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .center) {
                NextPrayerOrnament()
            }
        #endif
    }

    #if os(visionOS)
    WindowGroup(id: "qibla-volume") {
        QiblaVolumeView()
    }
    .windowStyle(.volumetric)
    .defaultSize(width: 0.5, height: 0.5, depth: 0.5, in: .meters)

    ImmersiveSpace(id: "adhan-space") {
        AdhanImmersiveView()
    }
    .immersionStyle(selection: .constant(.mixed), in: .mixed)
    #endif
}
```

### IqamahCore

No changes. `PrayerCalculator`, `FastingModeEngine`, `FastingLabelFormatter`, `QiblaCalculator` all compile on visionOS unchanged.

### SettingsManager

One addition: `northCalibrationTransform: Data?` — stores the ARKit world transform at calibration time, serialized as a flat `[Float]` (16 values, row-major). Not KVS-synced (device-local; another Vision Pro would need its own calibration).

---

## Open Questions

| # | Question | Stakes |
|---|---|---|
| OQ-1 | Does `CLLocationManager` provide GPS location on Vision Pro without a paired iPhone nearby? | If not, Qibla bearing requires iPhone in proximity. Verify in simulator. |
| OQ-2 | Does `WorldTrackingProvider.queryDeviceAnchor(atTimestamp:)` work in the visionOS 26.5 simulator? | If not, calibration flow needs stub data for simulator testing. |
| OQ-3 | Does `AVAudioEnvironmentNode` head-tracking work with visionOS + AirPods Pro spatial audio? | Spatial audio API changed in visionOS 2.0 with `AVAudioSession.Mode.spatialPlayback`. Verify. |
| OQ-4 | `ImmersiveSpace` particle system performance — do 400 `ParticleEmitterComponent` instances maintain frame rate on Vision Pro hardware? | Reduce to 100 if frame rate drops below 90 fps. |
| OQ-5 | Can the Hilal Watch MapKit view load properly in the visionOS simulator without a real network location? | May need a fallback to a hardcoded lat/lng for simulator testing. |

---

## Acceptance Criteria (when promoted to EPIC-0018)

### Path 1 — iPad Compat

- [x] AC-0383: `UIRequiresFullScreen = NO` added to `iqamah/iOS/Info.plist`
- [ ] AC-0384: Iqamah iOS binary runs in visionOS 26.5 simulator without crashing on launch
- [ ] AC-0385: All 5 prayer times display correctly in the compat window
- [ ] AC-0386: Settings, Hilal Watch, and Qibla tabs load without error (Qibla shows bearing-only text, not crash)
- [ ] AC-0387: App Store Connect visionOS platform toggle enabled under the existing Universal Purchase record

### Path 2 — Native visionOS

**Ornament:**
- [ ] AC-0388: Bottom ornament appears when the main window is open
- [ ] AC-0389: Ornament shows correct prayer name, live countdown, and Hijri date
- [ ] AC-0390: During Fasting Mode (within 2 h of Fajr/Maghrib), ornament relabels to Suhoor/Iftar per `FastingLabelFormatter`
- [ ] AC-0391: Ornament updates every second without visible lag

**Qibla Volume:**
- [ ] AC-0392: Tapping "Open Qibla in Space" from the Qibla tab opens the volumetric window
- [ ] AC-0393: Volume shows the 3D crescent arrow + calibration prompt on first open
- [ ] AC-0394: After user taps "Face North → Calibrate", the arrow rotates to the correct Qibla bearing and holds heading as the user turns their head
- [ ] AC-0395: Bearing label shows the correct great-circle degrees from user's GPS location to Makkah
- [ ] AC-0396: Calibration state persists across volume close/reopen; Recalibrate button resets it
- [ ] AC-0397: If GPS is unavailable, volume shows "Location required for Qibla" and disables calibration button

**Immersive Adhan:**
- [ ] AC-0398: `AdhaanBannerView` shows "Open in Space" button on visionOS when the banner is visible
- [ ] AC-0399: Tapping the button opens the ImmersiveSpace in `.mixed` mode (real room visible)
- [ ] AC-0400: Adhan audio plays from a spatial point source above the user; perceived as coming from above when wearing AirPods Pro
- [ ] AC-0401: Ambient particle system renders without frame drop (≥ 90 fps on Vision Pro hardware; acceptable in simulator)
- [ ] AC-0402: ImmersiveSpace auto-dismisses 30 s after adhan audio ends
- [ ] AC-0403: Digital Crown press dismisses the ImmersiveSpace

**Hilal Watch:**
- [ ] AC-0404: Hilal Watch window opens at 900 × 700 pts on visionOS
- [ ] AC-0405: S-curve visibility arcs and zone colours are legible without pinch-zoom at default size

**Liquid Glass:**
- [ ] AC-0406: Ornament uses `.glassBackgroundEffect()` on visionOS 1.0–25; `.glassEffect()` on visionOS 26+
- [ ] AC-0407: Qibla volume chrome uses `.glassBackgroundEffect()` on the RealityView overlay

---

## User Stories (when promoted to EPIC-0018)

### US-0076 (EPIC-0018) — Path 1 visionOS submission
As a Vision Pro user, I can run Iqamah in iPad compatibility mode, so I can see prayer times in a floating window without leaving my spatial environment.
**Priority:** High | **Estimate:** XS (done minus App Store Connect step)
**Dependencies:** `UIRequiresFullScreen = NO` (AC-0383 done), visionOS SDK installed

### US-0077 (EPIC-0018) — Ornament + Fasting Mode parity
As a native visionOS user, I can see the next prayer and Hijri date in a persistent bottom ornament (with Suhoor/Iftar relabelling during fasting days), so I get a glanceable prayer indicator without opening the main window.
**Priority:** High | **Estimate:** S

### US-0078 (EPIC-0018) — Spatial Qibla volume
As a native visionOS user, I can open a 3D Qibla compass volume that points toward Makkah after a one-time North calibration, so I can find the prayer direction while immersed in Vision Pro.
**Priority:** High | **Estimate:** L (ARKit calibration is the main engineering effort)

### US-0079 (EPIC-0018) — Immersive Adhan space
As a native visionOS user, I can open an immersive space at prayer time where the adhan plays from a spatial audio source above me, so I experience the call to prayer in a way that no other platform can offer.
**Priority:** Medium | **Estimate:** M

### US-0080 (EPIC-0018) — Hilal Watch window sizing + Liquid Glass polish
As a native visionOS user, I see the Hilal Watch map in a larger, legible window, and the ornament and Qibla volume surfaces use Liquid Glass chrome.
**Priority:** Low | **Estimate:** XS

---

## Testing

### What can be tested in the simulator

- Path 1: full smoke test (launch, prayer times, Hilal Watch, settings)
- Ornament: renders, updates, fasting relabel
- Volumetric window: opens, 3D arrow renders
- Qibla calibration flow: UI works; ARKit world tracking in simulator returns synthetic anchors — heading tracking will not match real-world North, but the flow and state machine can be verified
- ImmersiveSpace: opens in simulator's grey environment; audio and particle system run but without spatial head tracking
- Hilal Watch window size

### What requires Vision Pro hardware

- ARKit Qibla arrow accuracy — real-world North calibration and arrow bearing
- `AVAudioEnvironmentNode` spatial audio with head tracking + AirPods Pro
- ImmersiveSpace passthrough quality
- Ornament positioning in real space
- Particle system frame rate at 90 fps

### Test files (new)

- `IqamahTests/visionOS/QiblaCalibrationStateTests.swift` — unit tests for bearing math, transform persistence, drift detection
- `IqamahTests/visionOS/NextPrayerOrnamentTests.swift` — snapshot test for ornament label in standard, fasting-active, and fasting-prohibited states
- Manual test checklist (to be added to `docs/MANUAL_TEST_CHECKLIST.md`) for visionOS simulator smoke and hardware acceptance

---

## What this adds to the App Store story

- Path 1 (immediate): "Now available on Apple Vision Pro" — adds visionOS to the Universal Purchase listing at no code cost
- Path 2: "The first native Islamic prayer experience for Vision Pro — a 3D Qibla compass in your space, a persistent glanceable ornament, and an immersive adhan that sounds like the call is coming from a minaret in your room"

No competitor ships a native prayer app on visionOS. This is a meaningful press story and a meaningful differentiation.
