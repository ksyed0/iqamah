# Fasting Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Fasting Mode (ENH-002 / EPIC-0017) — a generalized fasting-day engine with 9 triggers, prohibition filtering, cross-surface display (Option D hybrid), configurable Suhoor/Iftar/day-before notifications, and new Ja'fari calculation method with tradition-aware UI gating.

**Architecture:** Pure-functional `FastingModeEngine` + value types in `IqamahCore` provide a single source of truth (`FastingDayState`) consumed by every surface. JSON-blob settings, shared `FastingBanner` SwiftUI view, debounced 7-day notification window, Live Activity backward-compatible via optional ContentState fields.

**Tech Stack:** Swift 5.10+, SwiftUI, Foundation (`Calendar(identifier: .islamicUmmAlQura)`, `Codable`, `JSONEncoder`), `UNUserNotificationCenter` (per-platform), Swift Testing framework, `xcodebuild` for scheme builds.

**Spec:** [docs/superpowers/specs/2026-05-21-fasting-mode-design.md](../specs/2026-05-21-fasting-mode-design.md)

---

## File Structure

### New files (IqamahCore)

| Path | Responsibility |
|---|---|
| `Packages/IqamahCore/Sources/IqamahCore/Services/FastingMode.swift` | Value types: `FastingDayState`, `FastingTriggerKind`, `ProhibitedDay`, `FastingModeSettings` |
| `Packages/IqamahCore/Sources/IqamahCore/Services/FastingModeEngine.swift` | Pure engine — `evaluate(for:settings:hijriCalendar:timezone:)` |
| `Packages/IqamahCore/Sources/IqamahCore/Services/FastingLabelFormatter.swift` | Pure relabel helpers (Fajr→Suhoor / Maghrib→Iftar with glyphs) |
| `Packages/IqamahCore/Sources/IqamahCore/Services/FastingNotificationPlanner.swift` | Pure scheduling helpers (suhoor/iftar/dayBefore fire-date calculators) |
| `Packages/IqamahCore/Tests/IqamahCoreTests/CalculationMethodJafariTests.swift` | Ja'fari method + isShiaMethod tests |
| `Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeSettingsCodecTests.swift` | Codec round-trip + forward-compat |
| `Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeEngineTests.swift` | Trigger + prohibition + priority tests |
| `Packages/IqamahCore/Tests/IqamahCoreTests/FastingLabelFormatterTests.swift` | Relabel + glyph tests |
| `Packages/IqamahCore/Tests/IqamahCoreTests/FastingNotificationPlannerTests.swift` | Planner arithmetic + skip-logic tests |

### New files (app targets)

| Path | Responsibility |
|---|---|
| `iqamah/Views/Shared/FastingBanner.swift` | Cross-target SwiftUI banner view (macOS + iOS membership) |
| `iqamah/Views/Shared/FastingModeSection.swift` | Settings section view (macOS + iOS membership) |
| `iqamah/FastingNotificationScheduler.swift` | macOS `UNUserNotificationCenter` wrapper with 500ms debounce |

### Modified files

| Path | Change |
|---|---|
| `Packages/IqamahCore/Sources/IqamahCore/Models/CalculationMethod.swift` | Add `.jafari` case + `isShiaMethod` |
| `Packages/IqamahCore/Sources/IqamahCore/Services/SettingsManager.swift` | Add `fastingModeSettings` (JSON blob) + `didShowFastingModePromo` |
| `iqamah/Views/CalculationMethodView.swift` | Add Ja'fari picker row |
| `iqamah/AppDelegate.swift` | Menu bar relabel via FastingLabelFormatter |
| `iqamah/Views/MenuBarPopoverView.swift` | Render FastingBanner |
| `iqamah/Views/SettingsSheetView.swift` | Include FastingModeSection |
| `iqamah/iOS/PrayerHeroCard.swift` | Render FastingBanner |
| `iqamah/iOS/PrayerRowMobileView.swift` | Apply relabel within 2h window |
| `iqamah/iOS/NotificationScheduler.swift` | Schedule fasting reminders, debounced |
| `IqamahWatch/PrayerTimesTab.swift` | Apply relabel |
| `IqamahWatch/SettingsTab.swift` | Minimal "Fasting Mode" entry + navigation link |
| `IqamahWatch/WatchNotificationScheduler.swift` | Schedule fasting reminders, debounced |
| `IqamahWidget/IqamahWidget.swift` | Apply relabel in entries |
| `IqamahLiveActivity/PrayerActivityAttributes.swift` | Add optional fastingActive + fastingTriggerRaw to ContentState |
| `IqamahLiveActivity/PrayerLiveActivityView.swift` | Apply relabel |
| `iqamah/iOS/PrayerActivityManager.swift` | Pass FastingDayState into ContentState |
| `iqamah.xcodeproj/project.pbxproj` | Add file refs + multi-target memberships for shared views + macOS notification scheduler |
| `docs/ENHANCEMENTS.md` | Mark ENH-002 ✅; add ENH-022 stub |
| `docs/RELEASE_PLAN.md` | Add EPIC-0017 + US-0071–US-0075 + AC-0357–AC-0382 |
| `docs/TEST_CASES.md` | Add TC-0044 – TC-0073 |
| `docs/ID_REGISTRY.md` | Bump EPIC→0018, US→0076, AC→0383, TC→0074, ENH→0023 |

---

## Task Index

| # | Task | Surface | Effort |
|---|---|---|---|
| 1 | Add `.jafari` case + `isShiaMethod` + picker entry | IqamahCore + UI | S |
| 2 | Create `FastingMode.swift` value types | IqamahCore | S |
| 3 | `FastingModeSettings` JSON codec + SettingsManager integration | IqamahCore | M |
| 4 | `FastingModeEngine` — autoRamadan + weeklySchedule | IqamahCore | M |
| 5 | `FastingModeEngine` — Hijri-date triggers (4) | IqamahCore | M |
| 6 | `FastingModeEngine` — muharramFast tradition-adaptive | IqamahCore | M |
| 7 | `FastingModeEngine` — Shia-gated triggers + prohibition filter | IqamahCore | M |
| 8 | `FastingLabelFormatter` | IqamahCore | S |
| 9 | `FastingNotificationPlanner` | IqamahCore | M |
| 10 | `FastingBanner` shared SwiftUI view | iOS+macOS | M |
| 11 | macOS menu bar + popover wiring | macOS | M |
| 12 | iOS hero card + row relabel | iOS | M |
| 13 | watchOS prayer tab relabel | watchOS | S |
| 14 | Widgets + Live Activity wiring | iOS widgets + LA | M |
| 15 | `FastingModeSection` settings UI | iOS+macOS | M |
| 16 | watchOS SettingsTab entry | watchOS | S |
| 17 | macOS `FastingNotificationScheduler` + debounce | macOS | M |
| 18 | iOS notification scheduler extension | iOS | M |
| 19 | watchOS notification scheduler extension | watchOS | M |
| 20 | Doc updates: ENHANCEMENTS + RELEASE_PLAN + TEST_CASES + ID_REGISTRY | docs | M |
| 21 | Final verification — multi-platform build + tests + PR | all | M |

Continued in task sections below.

---

## Task 1: Add `.jafari` calculation method + `isShiaMethod` helper + picker entry

**Files:**
- Modify: `Packages/IqamahCore/Sources/IqamahCore/Models/CalculationMethod.swift`
- Test: `Packages/IqamahCore/Tests/IqamahCoreTests/CalculationMethodJafariTests.swift` (new)
- Modify: `iqamah/Views/CalculationMethodView.swift` (picker entry)

**Why:** AC-0381, AC-0382. The Ja'fari method (Fajr 16°, Isha 14°, Maghrib 4° below horizon) serves Shia communities outside Iran. The `isShiaMethod` helper drives Fasting Mode UI gating (Muharram label adaptation + visibility of 15 Sha'ban / 27 Rajab triggers).

- [ ] **Step 1: Write the failing tests**

Create `Packages/IqamahCore/Tests/IqamahCoreTests/CalculationMethodJafariTests.swift`:

```swift
import Testing
import Foundation
@testable import IqamahCore

@Suite("CalculationMethod Ja'fari + isShiaMethod")
struct CalculationMethodJafariTests {
    @Test("jafari case has expected angles")
    func jafariAngles() {
        #expect(CalculationMethod.jafari.fajrAngle == 16.0)
        #expect(CalculationMethod.jafari.ishaAngle == 14.0)
        #expect(CalculationMethod.jafari.maghribAngle == 4.0)
    }

    @Test("jafari case identifies as Shia")
    func jafariIsShia() {
        #expect(CalculationMethod.jafari.isShiaMethod == true)
    }

    @Test("tehran case identifies as Shia")
    func tehranIsShia() {
        #expect(CalculationMethod.tehran.isShiaMethod == true)
    }

    @Test("sunni methods are not Shia")
    func sunniMethodsNotShia() {
        for method in [CalculationMethod.muslimWorldLeague, .isna, .egypt, .ummAlQura, .karachi] {
            #expect(method.isShiaMethod == false, "\(method) should not be Shia")
        }
    }

    @Test("jafari has displayName and shortName")
    func jafariNaming() {
        #expect(!CalculationMethod.jafari.displayName.isEmpty)
        #expect(!CalculationMethod.jafari.shortName.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Packages/IqamahCore && swift test --filter CalculationMethodJafariTests 2>&1 | tail -20
```

Expected: failures referencing `value of type 'CalculationMethod' has no member 'jafari'` and `'isShiaMethod'`.

- [ ] **Step 3: Add the `.jafari` case to `CalculationMethod`**

In `Packages/IqamahCore/Sources/IqamahCore/Models/CalculationMethod.swift`, add the new case to the enum and switch statements. Insert after `case tehran` (line 9):

```swift
    case jafari
```

Then add the displayName/shortName/angles to each switch:

```swift
        case .jafari:
            "Ja'fari (Shia outside Iran)"
```

In `shortName`:
```swift
        case .jafari: "Ja'fari"
```

In `fajrAngle`:
```swift
        case .jafari:
            16.0
```

In `ishaAngle`:
```swift
        case .jafari:
            14.0
```

In `maghribAngle`:
```swift
        case .jafari:
            4.0
        case .tehran:
            4.5
        default:
            nil
```

- [ ] **Step 4: Add `isShiaMethod` extension**

At the end of the existing `extension CalculationMethod` (after `recommendationLabel`), add:

```swift
    /// True for methods rooted in Ja'fari (Shia) jurisprudence.
    /// Drives tradition-aware UI gating in Fasting Mode.
    public var isShiaMethod: Bool {
        self == .tehran || self == .jafari
    }
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd Packages/IqamahCore && swift test --filter CalculationMethodJafariTests 2>&1 | tail -10
```

Expected: all five tests pass.

- [ ] **Step 6: Add Ja'fari to the picker UI**

In `iqamah/Views/CalculationMethodView.swift`, locate the `ForEach(CalculationMethod.allCases)` block. Because `.jafari` was added to a `CaseIterable` enum, it appears automatically — no code change needed unless the file uses an explicit list. Verify by searching:

```bash
grep -n "CalculationMethod\." iqamah/Views/CalculationMethodView.swift | head -10
```

If you see hand-written cases (e.g. `[.muslimWorldLeague, .isna, .egypt, .ummAlQura, .karachi, .tehran]`), add `.jafari` to that array. Otherwise no edit needed.

- [ ] **Step 7: Verify CalculationMethodView builds and the picker shows Ja'fari**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | tail -5
xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

Expected: both `BUILD SUCCEEDED`.

- [ ] **Step 8: Commit**

```bash
git add Packages/IqamahCore/Sources/IqamahCore/Models/CalculationMethod.swift \
        Packages/IqamahCore/Tests/IqamahCoreTests/CalculationMethodJafariTests.swift \
        iqamah/Views/CalculationMethodView.swift
git commit -m "feat(core): add Ja'fari calculation method + isShiaMethod helper

AC-0381, AC-0382. Adds .jafari (Fajr 16°, Isha 14°, Maghrib 4° below
horizon) alongside .tehran. isShiaMethod helper drives tradition-aware
UI gating in Fasting Mode.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Create `FastingMode.swift` value types

**Files:**
- Create: `Packages/IqamahCore/Sources/IqamahCore/Services/FastingMode.swift`

**Why:** Foundation types consumed by every later task. Pure value types (Codable, Equatable, Hashable) — no behavior.

- [ ] **Step 1: Create the value types file**

Create `Packages/IqamahCore/Sources/IqamahCore/Services/FastingMode.swift`:

```swift
import Foundation

/// Result of evaluating today against the user's Fasting Mode settings.
/// Pure-data; computed by FastingModeEngine; consumed by every surface.
public struct FastingDayState: Equatable, Codable, Hashable {
    /// Is today a fasting day (after prohibition filter)?
    public let isActive: Bool
    /// Why today is active. Nil when isActive == false.
    public let trigger: FastingTriggerKind?
    /// Hard-prohibited override. When non-nil, isActive is false regardless of triggers.
    public let prohibition: ProhibitedDay?
    /// The day this state describes (midnight in the evaluation timezone).
    public let date: Date

    public init(
        isActive: Bool,
        trigger: FastingTriggerKind?,
        prohibition: ProhibitedDay?,
        date: Date
    ) {
        self.isActive = isActive
        self.trigger = trigger
        self.prohibition = prohibition
        self.date = date
    }

    /// Convenience constructor for the inactive case.
    public static func inactive(date: Date) -> FastingDayState {
        FastingDayState(isActive: false, trigger: nil, prohibition: nil, date: date)
    }
}

public enum FastingTriggerKind: String, Codable, Hashable, CaseIterable {
    case autoRamadan
    case weeklySchedule
    case ayyamAlBeed
    case sixDaysShawwal
    case dayOfArafah
    case firstNineDhulHijjah
    case muharramFast
    case midShaban
    case mabath
}

public enum ProhibitedDay: String, Codable, Hashable, CaseIterable {
    case eidAlFitr      // 1 Shawwal
    case eidAlAdha      // 10 Dhul-Hijjah
    case tashriq11      // 11 Dhul-Hijjah
    case tashriq12      // 12 Dhul-Hijjah
    case tashriq13      // 13 Dhul-Hijjah

    public var displayName: String {
        switch self {
        case .eidAlFitr: "Eid al-Fitr"
        case .eidAlAdha: "Eid al-Adha"
        case .tashriq11: "11 Dhul-Hijjah (Tashriq)"
        case .tashriq12: "12 Dhul-Hijjah (Tashriq)"
        case .tashriq13: "13 Dhul-Hijjah (Tashriq)"
        }
    }
}

/// User-configurable Fasting Mode settings, persisted as a single JSON blob
/// in UserDefaults under Keys.fastingModeSettings and KVS-synced.
public struct FastingModeSettings: Codable, Equatable {
    public var enabled: Bool
    public var autoRamadan: Bool
    /// Calendar weekday integers (1=Sun, 2=Mon, …, 7=Sat) per Calendar.component(.weekday).
    public var weeklyDays: Set<Int>
    public var ayyamAlBeed: Bool
    public var sixDaysShawwal: Bool
    public var dayOfArafah: Bool
    public var firstNineDhulHijjah: Bool
    public var muharramFast: Bool
    /// 15 Sha'ban — engine suppresses when !calculationMethod.isShiaMethod.
    public var midShaban: Bool
    /// 27 Rajab (Mab'ath) — engine suppresses when !calculationMethod.isShiaMethod.
    public var mabath: Bool
    /// Lead time before Fajr for Suhoor notification, in minutes (5–120, step 5).
    public var suhoorLeadMinutes: Int
    /// Lead time before Maghrib for Iftar notification, in minutes (5–120, step 5).
    public var iftarLeadMinutes: Int
    /// When true, day-before reminder is scheduled.
    public var dayBeforeEnabled: Bool
    /// Time of day for day-before reminder. Default 20:00 (8 PM).
    public var dayBeforeHour: Int
    public var dayBeforeMinute: Int
    /// Master switch for all three reminder kinds (Suhoor, Iftar, day-before).
    public var notificationsEnabled: Bool

    public init(
        enabled: Bool = false,
        autoRamadan: Bool = true,
        weeklyDays: Set<Int> = [],
        ayyamAlBeed: Bool = false,
        sixDaysShawwal: Bool = false,
        dayOfArafah: Bool = false,
        firstNineDhulHijjah: Bool = false,
        muharramFast: Bool = false,
        midShaban: Bool = false,
        mabath: Bool = false,
        suhoorLeadMinutes: Int = 30,
        iftarLeadMinutes: Int = 15,
        dayBeforeEnabled: Bool = true,
        dayBeforeHour: Int = 20,
        dayBeforeMinute: Int = 0,
        notificationsEnabled: Bool = true
    ) {
        self.enabled = enabled
        self.autoRamadan = autoRamadan
        self.weeklyDays = weeklyDays
        self.ayyamAlBeed = ayyamAlBeed
        self.sixDaysShawwal = sixDaysShawwal
        self.dayOfArafah = dayOfArafah
        self.firstNineDhulHijjah = firstNineDhulHijjah
        self.muharramFast = muharramFast
        self.midShaban = midShaban
        self.mabath = mabath
        self.suhoorLeadMinutes = suhoorLeadMinutes
        self.iftarLeadMinutes = iftarLeadMinutes
        self.dayBeforeEnabled = dayBeforeEnabled
        self.dayBeforeHour = dayBeforeHour
        self.dayBeforeMinute = dayBeforeMinute
        self.notificationsEnabled = notificationsEnabled
    }

    /// Friday in weeklyDays without Thursday or Saturday — discouraged in many traditions.
    public var hasFridayAloneWarning: Bool {
        weeklyDays.contains(6) && !weeklyDays.contains(5) && !weeklyDays.contains(7)
    }

    /// Saturday in weeklyDays without Friday — canonical Sunnah pairing is Fri+Sat.
    public var hasSaturdayAloneWarning: Bool {
        weeklyDays.contains(7) && !weeklyDays.contains(6)
    }
}
```

Note: `dayBeforeTime` was originally specced as `DateComponents`. Switched to two `Int` fields (`dayBeforeHour`, `dayBeforeMinute`) because `DateComponents` doesn't have a stable `Codable` representation across Swift versions — two ints serialize cleanly and avoid migration surprises.

- [ ] **Step 2: Verify the file compiles**

```bash
cd Packages/IqamahCore && swift build 2>&1 | tail -5
```

Expected: `Build complete!` with no errors. Existing tests still pass:

```bash
cd Packages/IqamahCore && swift test 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add Packages/IqamahCore/Sources/IqamahCore/Services/FastingMode.swift
git commit -m "feat(core): add Fasting Mode value types

Adds FastingDayState, FastingTriggerKind (9 cases), ProhibitedDay
(5 cases), and FastingModeSettings (16 fields, all default-valued for
forward-compat decode). Pure value types — no behavior.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: `FastingModeSettings` JSON codec + SettingsManager integration

**Files:**
- Test: `Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeSettingsCodecTests.swift` (new)
- Modify: `Packages/IqamahCore/Sources/IqamahCore/Services/SettingsManager.swift`

**Why:** AC-0357. Single JSON blob in UserDefaults under `fastingModeSettings`, KVS-synced. Forward-compat decode handles future field additions via Codable defaults.

- [ ] **Step 1: Write the failing codec tests**

Create `Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeSettingsCodecTests.swift`:

```swift
import Testing
import Foundation
@testable import IqamahCore

@Suite("FastingModeSettings Codec")
struct FastingModeSettingsCodecTests {
    @Test("default settings round-trip preserves all fields")
    func defaultRoundTrip() throws {
        let original = FastingModeSettings()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FastingModeSettings.self, from: data)
        #expect(decoded == original)
    }

    @Test("populated settings round-trip preserves all fields")
    func populatedRoundTrip() throws {
        var original = FastingModeSettings()
        original.enabled = true
        original.weeklyDays = [2, 5]    // Mon, Thu
        original.midShaban = true
        original.suhoorLeadMinutes = 60
        original.iftarLeadMinutes = 20
        original.dayBeforeHour = 21
        original.dayBeforeMinute = 30
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FastingModeSettings.self, from: data)
        #expect(decoded == original)
    }

    @Test("legacy JSON missing new fields decodes with defaults")
    func forwardCompatDecode() throws {
        // Simulate a v1.6 install that only had the original 5 fields,
        // before later additions like midShaban/mabath/dayBeforeMinute were added.
        let legacyJSON = """
        {
            "enabled": true,
            "autoRamadan": true,
            "weeklyDays": [2, 5],
            "ayyamAlBeed": false,
            "sixDaysShawwal": false,
            "dayOfArafah": false,
            "firstNineDhulHijjah": false,
            "muharramFast": false,
            "midShaban": false,
            "mabath": false,
            "suhoorLeadMinutes": 30,
            "iftarLeadMinutes": 15,
            "dayBeforeEnabled": true,
            "dayBeforeHour": 20,
            "dayBeforeMinute": 0,
            "notificationsEnabled": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(FastingModeSettings.self, from: legacyJSON)
        #expect(decoded.enabled == true)
        #expect(decoded.weeklyDays == [2, 5])
        #expect(decoded.midShaban == false)
    }

    @Test("Friday-alone warning triggers when only Fri")
    func fridayAloneAlone() {
        var s = FastingModeSettings()
        s.weeklyDays = [6]
        #expect(s.hasFridayAloneWarning == true)
    }

    @Test("Friday-alone warning clears when paired with Thursday")
    func fridayWithThursdayClears() {
        var s = FastingModeSettings()
        s.weeklyDays = [5, 6]
        #expect(s.hasFridayAloneWarning == false)
    }

    @Test("Friday-alone warning clears when paired with Saturday")
    func fridayWithSaturdayClears() {
        var s = FastingModeSettings()
        s.weeklyDays = [6, 7]
        #expect(s.hasFridayAloneWarning == false)
    }

    @Test("Saturday-alone warning triggers when only Sat")
    func saturdayAlone() {
        var s = FastingModeSettings()
        s.weeklyDays = [7]
        #expect(s.hasSaturdayAloneWarning == true)
    }

    @Test("Saturday-alone warning clears when paired with Friday")
    func saturdayWithFridayClears() {
        var s = FastingModeSettings()
        s.weeklyDays = [6, 7]
        #expect(s.hasSaturdayAloneWarning == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
cd Packages/IqamahCore && swift test --filter FastingModeSettingsCodecTests 2>&1 | tail -10
```

Expected: all 8 tests pass (the struct already exists from Task 2 with the required behavior).

- [ ] **Step 3: Add `fastingModeSettings` to `SettingsManager`**

In `Packages/IqamahCore/Sources/IqamahCore/Services/SettingsManager.swift`:

Locate the `Keys` enum (around line 49) and add after `liveActivityEnabled`:

```swift
        static let fastingModeSettings = "fastingModeSettings"
        static let didShowFastingModePromo = "didShowFastingModePromo"
```

In the `kvsKeys` set (around line 82), add `Keys.fastingModeSettings` to the list. Do NOT add `didShowFastingModePromo` — that flag is device-local (each device's first-Ramadan banner fires once independently).

Locate the existing `@Published var gpsDetectedCity` (around line 273). Add immediately after its closing brace:

```swift
    /// Fasting Mode user-configurable settings. Persisted as JSON blob; KVS-synced.
    @Published public var fastingModeSettings: FastingModeSettings {
        didSet {
            guard let data = try? JSONEncoder().encode(fastingModeSettings) else { return }
            defaults.set(data, forKey: Keys.fastingModeSettings)
            guard !isApplyingRemote else { return }
            kvs.set(data, forKey: Keys.fastingModeSettings)
        }
    }

    /// True once the first-Ramadan Fasting Mode promo banner has been shown.
    /// NOT KVS-synced — per-device flag.
    @Published public var didShowFastingModePromo: Bool {
        didSet {
            defaults.set(didShowFastingModePromo, forKey: Keys.didShowFastingModePromo)
        }
    }
```

In `init(userDefaults:)` (around line 289), add to the load block before `migrateFromStandardDefaultsIfNeeded()`:

```swift
        if let data = userDefaults.data(forKey: Keys.fastingModeSettings),
           let decoded = try? JSONDecoder().decode(FastingModeSettings.self, from: data) {
            fastingModeSettings = decoded
        } else {
            fastingModeSettings = FastingModeSettings()
        }
        didShowFastingModePromo = userDefaults.bool(forKey: Keys.didShowFastingModePromo)
```

- [ ] **Step 4: Extend the KVS remote-apply handler**

Locate `handleRemoteKVSChange` / `applyRemote(...)` in SettingsManager (search for `case Keys.gpsLocality:` to find the switch). Add a new case:

```swift
        case Keys.fastingModeSettings:
            if let data = kvs.data(forKey: key),
               let decoded = try? JSONDecoder().decode(FastingModeSettings.self, from: data) {
                fastingModeSettings = decoded
            }
```

- [ ] **Step 5: Run all IqamahCore tests**

```bash
cd Packages/IqamahCore && swift test 2>&1 | tail -10
```

Expected: all tests pass (including the existing 185+ plus the 8 new codec tests).

- [ ] **Step 6: Commit**

```bash
git add Packages/IqamahCore/Sources/IqamahCore/Services/SettingsManager.swift \
        Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeSettingsCodecTests.swift
git commit -m "feat(core): wire FastingModeSettings into SettingsManager

AC-0357. JSON blob under Keys.fastingModeSettings, KVS-synced.
didShowFastingModePromo is device-local. Tests cover round-trip,
forward-compat decode of legacy JSON, and Friday-alone/Saturday-alone
warning logic.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: `FastingModeEngine` — autoRamadan + weeklySchedule triggers

**Files:**
- Create: `Packages/IqamahCore/Sources/IqamahCore/Services/FastingModeEngine.swift`
- Test: `Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeEngineTests.swift` (new)

**Why:** AC-0358, AC-0359. Foundation of the engine — the two simplest triggers. Subsequent tasks layer additional triggers and the prohibition filter on top.

- [ ] **Step 1: Write the failing engine tests**

Create `Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeEngineTests.swift`:

```swift
import Testing
import Foundation
@testable import IqamahCore

@Suite("FastingModeEngine — base triggers")
struct FastingModeEngineBaseTests {
    /// Convenience: build a Date at given Gregorian Y/M/D in a known timezone.
    static func date(_ y: Int, _ m: Int, _ d: Int, tz: TimeZone = TimeZone(identifier: "America/Toronto")!) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    static let hijri = Calendar(identifier: .islamicUmmAlQura)
    static let tz = TimeZone(identifier: "America/Toronto")!

    @Test("engine is inactive when settings.enabled is false")
    func disabledReturnsInactive() {
        var s = FastingModeSettings()
        s.enabled = false
        s.autoRamadan = true
        // 2026-02-17 is 1 Ramadan 1447 (approx, depends on Umm al-Qura)
        let result = FastingModeEngine.evaluate(
            for: Self.date(2026, 2, 17),
            settings: s,
            calculationMethod: .mwl,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(result.isActive == false)
        #expect(result.trigger == nil)
    }

    @Test("autoRamadan fires on a Ramadan day")
    func autoRamadanFires() {
        var s = FastingModeSettings()
        s.enabled = true
        s.autoRamadan = true
        // Pick a date deep in Ramadan to avoid boundary uncertainty. 2026-03-01 is mid-Ramadan 1447.
        let result = FastingModeEngine.evaluate(
            for: Self.date(2026, 3, 1),
            settings: s,
            calculationMethod: .mwl,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        let hijriMonth = Self.hijri.component(.month, from: Self.date(2026, 3, 1))
        if hijriMonth == 9 {
            #expect(result.isActive == true)
            #expect(result.trigger == .autoRamadan)
        }
    }

    @Test("autoRamadan does not fire when toggle is off")
    func autoRamadanOff() {
        var s = FastingModeSettings()
        s.enabled = true
        s.autoRamadan = false
        let result = FastingModeEngine.evaluate(
            for: Self.date(2026, 3, 1),
            settings: s,
            calculationMethod: .mwl,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(result.trigger != .autoRamadan)
    }

    @Test("weeklySchedule fires on a Monday")
    func weeklyMondayFires() {
        var s = FastingModeSettings()
        s.enabled = true
        s.weeklyDays = [2]  // Mon
        // 2026-09-14 is a Monday.
        let result = FastingModeEngine.evaluate(
            for: Self.date(2026, 9, 14),
            settings: s,
            calculationMethod: .mwl,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(result.isActive == true)
        #expect(result.trigger == .weeklySchedule)
    }

    @Test("weeklySchedule does not fire on a Wednesday when only Mon/Thu set")
    func weeklyWednesdayInactive() {
        var s = FastingModeSettings()
        s.enabled = true
        s.weeklyDays = [2, 5]  // Mon, Thu
        // 2026-09-16 is a Wednesday.
        let result = FastingModeEngine.evaluate(
            for: Self.date(2026, 9, 16),
            settings: s,
            calculationMethod: .mwl,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(result.isActive == false)
    }

    @Test("engine is pure — same input yields same output")
    func enginePurity() {
        var s = FastingModeSettings()
        s.enabled = true
        s.weeklyDays = [2]
        let input = Self.date(2026, 9, 14)
        let a = FastingModeEngine.evaluate(for: input, settings: s, calculationMethod: .mwl, hijriCalendar: Self.hijri, timezone: Self.tz)
        let b = FastingModeEngine.evaluate(for: input, settings: s, calculationMethod: .mwl, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(a == b)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Packages/IqamahCore && swift test --filter FastingModeEngineBaseTests 2>&1 | tail -15
```

Expected: failures referencing `value of type 'FastingModeEngine' has no member 'evaluate'` (because the engine doesn't exist yet).

- [ ] **Step 3: Create the engine skeleton + Task 4 triggers**

Create `Packages/IqamahCore/Sources/IqamahCore/Services/FastingModeEngine.swift`:

```swift
import Foundation

/// Pure-functional engine that decides "is today a fasting day?".
/// Called at every render site; no caching, no I/O.
public enum FastingModeEngine {

    /// Evaluate today's Fasting Mode state against the user's settings.
    /// - Parameters:
    ///   - date: The day to evaluate (typically `Date()`).
    ///   - settings: User Fasting Mode preferences.
    ///   - calculationMethod: Affects muharramFast date set and Shia-gated trigger suppression.
    ///   - hijriCalendar: Calendar(identifier: .islamicUmmAlQura) or similar.
    ///   - timezone: User's active timezone (settings.activeTimezoneIdentifier).
    /// - Returns: FastingDayState describing today.
    public static func evaluate(
        for date: Date,
        settings: FastingModeSettings,
        calculationMethod: CalculationMethod,
        hijriCalendar: Calendar,
        timezone: TimeZone
    ) -> FastingDayState {
        // Master switch — short-circuit
        guard settings.enabled else {
            return .inactive(date: date)
        }

        // Build a calendar configured to the user's timezone for accurate weekday/Hijri queries
        var gregCal = Calendar(identifier: .gregorian)
        gregCal.timeZone = timezone
        var hCal = hijriCalendar
        hCal.timeZone = timezone

        // (Future tasks: prohibition filter runs here before triggers.)

        // Walk triggers in priority order; first match wins.
        if settings.autoRamadan {
            let hijriMonth = hCal.component(.month, from: date)
            if hijriMonth == 9 {
                return FastingDayState(
                    isActive: true,
                    trigger: .autoRamadan,
                    prohibition: nil,
                    date: date
                )
            }
        }

        // weeklySchedule (runs last among Task 4 scope)
        if !settings.weeklyDays.isEmpty {
            let weekday = gregCal.component(.weekday, from: date)
            if settings.weeklyDays.contains(weekday) {
                return FastingDayState(
                    isActive: true,
                    trigger: .weeklySchedule,
                    prohibition: nil,
                    date: date
                )
            }
        }

        return .inactive(date: date)
    }
}
```

Note: `weeklySchedule` is documented in the spec as the LEAST specific trigger and runs LAST. In this Task 4 scope we only have two triggers, so the order is `autoRamadan` → `weeklySchedule`. Tasks 5–7 insert intermediate triggers between them at the spec's documented priority positions.

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Packages/IqamahCore && swift test --filter FastingModeEngineBaseTests 2>&1 | tail -10
```

Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/IqamahCore/Sources/IqamahCore/Services/FastingModeEngine.swift \
        Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeEngineTests.swift
git commit -m "feat(core): FastingModeEngine — autoRamadan + weeklySchedule triggers

AC-0358, AC-0359. Pure-functional engine; takes date + settings + method
+ hijriCalendar + timezone, returns FastingDayState. autoRamadan fires
on Hijri month 9; weeklySchedule fires on user-selected Calendar weekday
ints. Subsequent tasks layer additional triggers and the prohibition
filter at documented priority positions.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: `FastingModeEngine` — Hijri-date triggers (Ayyam al-Beed, 6 Shawwal, Arafah, first 9 Dhul-Hijjah)

**Files:**
- Modify: `Packages/IqamahCore/Sources/IqamahCore/Services/FastingModeEngine.swift`
- Modify: `Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeEngineTests.swift`

**Why:** AC-0360, AC-0361. Hijri-date-driven triggers. On 9 Dhul-Hijjah, both `dayOfArafah` and `firstNineDhulHijjah` could match — Arafah takes priority.

- [ ] **Step 1: Add the failing tests**

Append to `FastingModeEngineTests.swift`:

```swift
@Suite("FastingModeEngine — Hijri-date triggers")
struct FastingModeEngineHijriTests {
    static let hijri = Calendar(identifier: .islamicUmmAlQura)
    static let tz = TimeZone(identifier: "America/Toronto")!

    /// Build a Date for the given Hijri Y/M/D in the test timezone, at noon.
    static func hijriDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test("ayyamAlBeed fires on day 13 of any Hijri month")
    func ayyamAlBeed13() {
        var s = FastingModeSettings()
        s.enabled = true
        s.ayyamAlBeed = true
        // Use Sha'ban (month 8) to avoid Ramadan/prohibition overlap.
        let date = Self.hijriDate(1448, 8, 13)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .mwl, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.isActive == true)
        #expect(result.trigger == .ayyamAlBeed)
    }

    @Test("ayyamAlBeed fires on day 14")
    func ayyamAlBeed14() {
        var s = FastingModeSettings()
        s.enabled = true
        s.ayyamAlBeed = true
        let date = Self.hijriDate(1448, 8, 14)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .mwl, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.trigger == .ayyamAlBeed)
    }

    @Test("ayyamAlBeed does not fire on day 16")
    func ayyamAlBeedDay16() {
        var s = FastingModeSettings()
        s.enabled = true
        s.ayyamAlBeed = true
        let date = Self.hijriDate(1448, 8, 16)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .mwl, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.isActive == false)
    }

    @Test("sixDaysShawwal fires on day 2 Shawwal")
    func sixShawwalDay2() {
        var s = FastingModeSettings()
        s.enabled = true
        s.sixDaysShawwal = true
        let date = Self.hijriDate(1448, 10, 2)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .mwl, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.trigger == .sixDaysShawwal)
    }

    @Test("sixDaysShawwal fires on day 7 Shawwal")
    func sixShawwalDay7() {
        var s = FastingModeSettings()
        s.enabled = true
        s.sixDaysShawwal = true
        let date = Self.hijriDate(1448, 10, 7)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .mwl, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.trigger == .sixDaysShawwal)
    }

    @Test("sixDaysShawwal does not fire on day 8 Shawwal")
    func sixShawwalDay8Inactive() {
        var s = FastingModeSettings()
        s.enabled = true
        s.sixDaysShawwal = true
        let date = Self.hijriDate(1448, 10, 8)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .mwl, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.isActive == false)
    }

    @Test("dayOfArafah fires on 9 Dhul-Hijjah")
    func arafahFires() {
        var s = FastingModeSettings()
        s.enabled = true
        s.dayOfArafah = true
        let date = Self.hijriDate(1448, 12, 9)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .mwl, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.trigger == .dayOfArafah)
    }

    @Test("firstNineDhulHijjah fires on day 5")
    func firstNineDay5() {
        var s = FastingModeSettings()
        s.enabled = true
        s.firstNineDhulHijjah = true
        let date = Self.hijriDate(1448, 12, 5)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .mwl, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.trigger == .firstNineDhulHijjah)
    }

    @Test("on 9 Dhul-Hijjah, dayOfArafah wins over firstNineDhulHijjah")
    func arafahPriorityOverFirstNine() {
        var s = FastingModeSettings()
        s.enabled = true
        s.dayOfArafah = true
        s.firstNineDhulHijjah = true
        let date = Self.hijriDate(1448, 12, 9)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .mwl, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.trigger == .dayOfArafah)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Packages/IqamahCore && swift test --filter FastingModeEngineHijriTests 2>&1 | tail -15
```

Expected: 9 failures — the engine returns `.inactive` for all of them because the new triggers aren't implemented yet.

- [ ] **Step 3: Add the triggers to `FastingModeEngine.evaluate`**

In `FastingModeEngine.swift`, modify the trigger walk inside `evaluate` to insert these triggers at the spec's documented priority positions. Replace the body **between `autoRamadan` and `weeklySchedule`** (where the "Future tasks" comment was) with:

```swift
        let hijriMonth = hCal.component(.month, from: date)
        let hijriDay = hCal.component(.day, from: date)

        // autoRamadan (already present from Task 4)
        if settings.autoRamadan, hijriMonth == 9 {
            return FastingDayState(isActive: true, trigger: .autoRamadan, prohibition: nil, date: date)
        }

        // dayOfArafah — priority over firstNineDhulHijjah on day 9
        if settings.dayOfArafah, hijriMonth == 12, hijriDay == 9 {
            return FastingDayState(isActive: true, trigger: .dayOfArafah, prohibition: nil, date: date)
        }

        // firstNineDhulHijjah
        if settings.firstNineDhulHijjah, hijriMonth == 12, (1...9).contains(hijriDay) {
            return FastingDayState(isActive: true, trigger: .firstNineDhulHijjah, prohibition: nil, date: date)
        }

        // (muharramFast — added in Task 6)

        // ayyamAlBeed
        if settings.ayyamAlBeed, (13...15).contains(hijriDay) {
            return FastingDayState(isActive: true, trigger: .ayyamAlBeed, prohibition: nil, date: date)
        }

        // sixDaysShawwal — 2 through 7 Shawwal (day 1 is Eid, excluded by prohibition filter in Task 7)
        if settings.sixDaysShawwal, hijriMonth == 10, (2...7).contains(hijriDay) {
            return FastingDayState(isActive: true, trigger: .sixDaysShawwal, prohibition: nil, date: date)
        }

        // (midShaban + mabath — added in Task 7)

        // weeklySchedule (least specific, runs last — already present from Task 4)
        if !settings.weeklyDays.isEmpty {
            let weekday = gregCal.component(.weekday, from: date)
            if settings.weeklyDays.contains(weekday) {
                return FastingDayState(isActive: true, trigger: .weeklySchedule, prohibition: nil, date: date)
            }
        }
```

Remove the now-duplicated `autoRamadan` block from earlier in the method — there should be exactly one of each trigger check, in the order above.

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Packages/IqamahCore && swift test --filter FastingModeEngine 2>&1 | tail -10
```

Expected: all base tests (Task 4) plus all 9 new Hijri tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/IqamahCore/Sources/IqamahCore/Services/FastingModeEngine.swift \
        Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeEngineTests.swift
git commit -m "feat(core): FastingModeEngine — Hijri-date triggers + priority

AC-0360, AC-0361. Adds ayyamAlBeed (13-15), sixDaysShawwal (2-7),
dayOfArafah (9 Dhul-Hijjah), firstNineDhulHijjah (1-9 Dhul-Hijjah).
Trigger walk respects documented priority: Arafah > firstNine on day 9.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: `FastingModeEngine` — muharramFast tradition-adaptive

**Files:**
- Modify: `Packages/IqamahCore/Sources/IqamahCore/Services/FastingModeEngine.swift`
- Modify: `Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeEngineTests.swift`

**Why:** AC-0362. `muharramFast` is the only trigger whose **date set** depends on calculation method:
- Sunni methods → fires on 9 + 10 Muharram (label: "Ashura (9+10 Muharram)")
- Shia methods → fires on 9 Muharram only (label: "Tasu'a (9 Muharram)")

- [ ] **Step 1: Add the failing tests**

Append to `FastingModeEngineTests.swift`:

```swift
@Suite("FastingModeEngine — muharramFast tradition-adaptive")
struct FastingModeEngineMuharramTests {
    static let hijri = Calendar(identifier: .islamicUmmAlQura)
    static let tz = TimeZone(identifier: "America/Toronto")!

    static func hijriDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test("Sunni method: muharramFast fires on 10 Muharram (Ashura)")
    func sunniDay10() {
        var s = FastingModeSettings()
        s.enabled = true
        s.muharramFast = true
        let date = Self.hijriDate(1448, 1, 10)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .mwl,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == true)
        #expect(result.trigger == .muharramFast)
    }

    @Test("Sunni method: muharramFast fires on 9 Muharram (Tasu'a)")
    func sunniDay9() {
        var s = FastingModeSettings()
        s.enabled = true
        s.muharramFast = true
        let date = Self.hijriDate(1448, 1, 9)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .isna,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == true)
        #expect(result.trigger == .muharramFast)
    }

    @Test("Sunni method: muharramFast does NOT fire on 11 Muharram")
    func sunniDay11Inactive() {
        var s = FastingModeSettings()
        s.enabled = true
        s.muharramFast = true
        let date = Self.hijriDate(1448, 1, 11)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .mwl,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
    }

    @Test("Shia (tehran): muharramFast fires on 9 Muharram only")
    func shiaTehranDay9() {
        var s = FastingModeSettings()
        s.enabled = true
        s.muharramFast = true
        let date = Self.hijriDate(1448, 1, 9)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .tehran,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.trigger == .muharramFast)
    }

    @Test("Shia (tehran): muharramFast does NOT fire on 10 Muharram")
    func shiaTehranDay10Inactive() {
        var s = FastingModeSettings()
        s.enabled = true
        s.muharramFast = true
        let date = Self.hijriDate(1448, 1, 10)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .tehran,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
    }

    @Test("Shia (jafari): muharramFast fires on 9 Muharram")
    func shiaJafariDay9() {
        var s = FastingModeSettings()
        s.enabled = true
        s.muharramFast = true
        let date = Self.hijriDate(1448, 1, 9)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .jafari,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.trigger == .muharramFast)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Packages/IqamahCore && swift test --filter FastingModeEngineMuharramTests 2>&1 | tail -10
```

Expected: 4 of 6 fail (Sunni day-10 and day-9 cases may pass by coincidence if no other trigger matches, but most will fail because muharramFast isn't implemented yet).

- [ ] **Step 3: Insert muharramFast into the trigger walk**

In `FastingModeEngine.swift`, locate the `// (muharramFast — added in Task 6)` comment and replace with:

```swift
        // muharramFast — date set adapts to calculation method
        if settings.muharramFast, hijriMonth == 1 {
            let firesToday: Bool = if calculationMethod.isShiaMethod {
                hijriDay == 9  // Shia: Tasu'a only
            } else {
                hijriDay == 9 || hijriDay == 10  // Sunni: Tasu'a + Ashura
            }
            if firesToday {
                return FastingDayState(isActive: true, trigger: .muharramFast, prohibition: nil, date: date)
            }
        }
```

Place this between `firstNineDhulHijjah` and `ayyamAlBeed` per the spec's priority order.

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Packages/IqamahCore && swift test --filter FastingModeEngine 2>&1 | tail -10
```

Expected: all existing engine tests still pass plus the 6 new Muharram tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/IqamahCore/Sources/IqamahCore/Services/FastingModeEngine.swift \
        Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeEngineTests.swift
git commit -m "feat(core): FastingModeEngine — muharramFast tradition-adaptive trigger

AC-0362. Sunni methods fire on 9+10 Muharram; Shia methods (Tehran,
Ja'fari via isShiaMethod) fire on 9 Muharram only. Single trigger
enum value; date set adapts at evaluation time.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: `FastingModeEngine` — Shia-gated triggers + prohibition filter

**Files:**
- Modify: `Packages/IqamahCore/Sources/IqamahCore/Services/FastingModeEngine.swift`
- Modify: `Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeEngineTests.swift`

**Why:** AC-0363, AC-0364. Two remaining concerns:
1. `midShaban` (15 Sha'ban) and `mabath` (27 Rajab) triggers — fire only when `calculationMethod.isShiaMethod`; the engine silently suppresses them otherwise even if the toggle is stored as `true`
2. The prohibition filter — Eid al-Fitr (1 Shawwal), Eid al-Adha (10 Dhul-Hijjah), Tashriq 11–13 Dhul-Hijjah — runs **before** trigger evaluation and always wins

- [ ] **Step 1: Add the failing tests**

Append to `FastingModeEngineTests.swift`:

```swift
@Suite("FastingModeEngine — Shia-gated triggers")
struct FastingModeEngineShiaGatedTests {
    static let hijri = Calendar(identifier: .islamicUmmAlQura)
    static let tz = TimeZone(identifier: "America/Toronto")!

    static func hijriDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test("midShaban fires for Shia method on 15 Sha'ban")
    func midShabanShiaFires() {
        var s = FastingModeSettings()
        s.enabled = true
        s.midShaban = true
        let date = Self.hijriDate(1448, 8, 15)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .tehran,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.trigger == .midShaban)
    }

    @Test("midShaban suppressed for Sunni method even when toggle is true")
    func midShabanSunniSuppressed() {
        var s = FastingModeSettings()
        s.enabled = true
        s.midShaban = true
        let date = Self.hijriDate(1448, 8, 15)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .mwl,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
    }

    @Test("mabath fires for Shia method on 27 Rajab")
    func mabathShiaFires() {
        var s = FastingModeSettings()
        s.enabled = true
        s.mabath = true
        let date = Self.hijriDate(1448, 7, 27)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .jafari,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.trigger == .mabath)
    }

    @Test("mabath suppressed for Sunni method")
    func mabathSunniSuppressed() {
        var s = FastingModeSettings()
        s.enabled = true
        s.mabath = true
        let date = Self.hijriDate(1448, 7, 27)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .karachi,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
    }
}

@Suite("FastingModeEngine — prohibition filter")
struct FastingModeEngineProhibitionTests {
    static let hijri = Calendar(identifier: .islamicUmmAlQura)
    static let tz = TimeZone(identifier: "America/Toronto")!

    static func hijriDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test("Eid al-Fitr suppresses sixDaysShawwal trigger")
    func eidAlFitrSuppressesShawwal() {
        var s = FastingModeSettings()
        s.enabled = true
        s.sixDaysShawwal = true
        let date = Self.hijriDate(1448, 10, 1)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .mwl,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
        #expect(result.prohibition == .eidAlFitr)
    }

    @Test("Eid al-Adha suppresses any trigger")
    func eidAlAdhaSuppresses() {
        var s = FastingModeSettings()
        s.enabled = true
        s.dayOfArafah = true  // sneaky — Arafah is 9 Dhul-Hijjah, Eid al-Adha is 10
        s.firstNineDhulHijjah = true
        s.weeklyDays = [1, 2, 3, 4, 5, 6, 7] // every day
        let date = Self.hijriDate(1448, 12, 10)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .mwl,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
        #expect(result.prohibition == .eidAlAdha)
    }

    @Test("Tashriq 11 suppresses ayyamAlBeed")
    func tashriq11SuppressesAyyamAlBeed() {
        var s = FastingModeSettings()
        s.enabled = true
        s.ayyamAlBeed = true  // would normally fire on 13 Dhul-Hijjah
        let date = Self.hijriDate(1448, 12, 11)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .mwl,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.prohibition == .tashriq11)
    }

    @Test("Tashriq 12 suppresses any trigger")
    func tashriq12Suppresses() {
        var s = FastingModeSettings()
        s.enabled = true
        s.weeklyDays = [1, 2, 3, 4, 5, 6, 7]
        let date = Self.hijriDate(1448, 12, 12)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .mwl,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.prohibition == .tashriq12)
    }

    @Test("Tashriq 13 suppresses ayyamAlBeed")
    func tashriq13SuppressesAyyamAlBeed() {
        var s = FastingModeSettings()
        s.enabled = true
        s.ayyamAlBeed = true
        let date = Self.hijriDate(1448, 12, 13)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .mwl,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.prohibition == .tashriq13)
    }

    @Test("ordinary day with no triggers stays inactive (no prohibition)")
    func ordinaryDayInactive() {
        var s = FastingModeSettings()
        s.enabled = true
        // No toggles enabled, ordinary day.
        let date = Self.hijriDate(1448, 6, 20)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .mwl,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
        #expect(result.prohibition == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Packages/IqamahCore && swift test --filter "FastingModeEngineShiaGatedTests|FastingModeEngineProhibitionTests" 2>&1 | tail -15
```

Expected: most tests fail — midShaban/mabath triggers and prohibition filter not implemented.

- [ ] **Step 3: Add the prohibition filter to the top of `evaluate`**

In `FastingModeEngine.swift`, immediately after the `guard settings.enabled else { return .inactive(date: date) }` line and after computing `hijriMonth` and `hijriDay`, insert the prohibition check **before** any trigger evaluation:

```swift
        // Prohibition filter — always wins over any trigger.
        if hijriMonth == 10, hijriDay == 1 {
            return FastingDayState(isActive: false, trigger: nil, prohibition: .eidAlFitr, date: date)
        }
        if hijriMonth == 12, hijriDay == 10 {
            return FastingDayState(isActive: false, trigger: nil, prohibition: .eidAlAdha, date: date)
        }
        if hijriMonth == 12, hijriDay == 11 {
            return FastingDayState(isActive: false, trigger: nil, prohibition: .tashriq11, date: date)
        }
        if hijriMonth == 12, hijriDay == 12 {
            return FastingDayState(isActive: false, trigger: nil, prohibition: .tashriq12, date: date)
        }
        if hijriMonth == 12, hijriDay == 13 {
            return FastingDayState(isActive: false, trigger: nil, prohibition: .tashriq13, date: date)
        }
```

Note: `hijriMonth` and `hijriDay` must be computed before the filter (move their declarations up if they were declared later in Task 5's diff).

- [ ] **Step 4: Insert midShaban + mabath triggers into the walk**

In `FastingModeEngine.swift`, at the `// (midShaban + mabath — added in Task 7)` placeholder (between `sixDaysShawwal` and `weeklySchedule`), insert:

```swift
        // midShaban — Shia-gated, suppressed when method is not Shia
        if settings.midShaban, calculationMethod.isShiaMethod, hijriMonth == 8, hijriDay == 15 {
            return FastingDayState(isActive: true, trigger: .midShaban, prohibition: nil, date: date)
        }

        // mabath (27 Rajab) — Shia-gated
        if settings.mabath, calculationMethod.isShiaMethod, hijriMonth == 7, hijriDay == 27 {
            return FastingDayState(isActive: true, trigger: .mabath, prohibition: nil, date: date)
        }
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd Packages/IqamahCore && swift test --filter FastingModeEngine 2>&1 | tail -15
```

Expected: all engine tests pass.

- [ ] **Step 6: Commit**

```bash
git add Packages/IqamahCore/Sources/IqamahCore/Services/FastingModeEngine.swift \
        Packages/IqamahCore/Tests/IqamahCoreTests/FastingModeEngineTests.swift
git commit -m "feat(core): FastingModeEngine — Shia-gated triggers + prohibition filter

AC-0363, AC-0364. Engine fully implements all 9 triggers + 5 prohibited
days. midShaban/mabath suppressed when method is not Shia, even when
stored toggle is true. Prohibition filter always wins over any trigger.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: `FastingLabelFormatter`

**Files:**
- Create: `Packages/IqamahCore/Sources/IqamahCore/Services/FastingLabelFormatter.swift`
- Create: `Packages/IqamahCore/Tests/IqamahCoreTests/FastingLabelFormatterTests.swift`

**Why:** AC-0365. Pure helpers that relabel "Fajr" → "Suhoor" and "Maghrib" → "Iftar" within a 2-hour window when Fasting Mode is active. Used by every narrow surface (menu bar, watch, widgets, Live Activity). Selects 🌙 for Ramadan (autoRamadan trigger) and 🕗 for Nawafil.

- [ ] **Step 1: Write the failing tests**

Create `Packages/IqamahCore/Tests/IqamahCoreTests/FastingLabelFormatterTests.swift`:

```swift
import Testing
import Foundation
@testable import IqamahCore

@Suite("FastingLabelFormatter")
struct FastingLabelFormatterTests {
    static let tz = TimeZone(identifier: "America/Toronto")!
    static let now = Date(timeIntervalSince1970: 1_745_000_000) // arbitrary fixed time

    @Test("inactive state returns original prayer name")
    func inactivePassthrough() {
        let state = FastingDayState.inactive(date: Self.now)
        let result = FastingLabelFormatter.relabel(
            prayerName: "Fajr",
            prayerTime: Self.now.addingTimeInterval(60 * 60),  // 1h away
            currentTime: Self.now,
            state: state
        )
        #expect(result == "Fajr")
    }

    @Test("active Ramadan within 2h relabels Fajr to Suhoor with moon glyph")
    func ramadanRelabelFajr() {
        let state = FastingDayState(
            isActive: true, trigger: .autoRamadan, prohibition: nil, date: Self.now
        )
        let result = FastingLabelFormatter.relabel(
            prayerName: "Fajr",
            prayerTime: Self.now.addingTimeInterval(42 * 60),  // 42 min away
            currentTime: Self.now,
            state: state
        )
        #expect(result == "🌙 Suhoor")
    }

    @Test("active Ramadan within 2h relabels Maghrib to Iftar")
    func ramadanRelabelMaghrib() {
        let state = FastingDayState(
            isActive: true, trigger: .autoRamadan, prohibition: nil, date: Self.now
        )
        let result = FastingLabelFormatter.relabel(
            prayerName: "Maghrib",
            prayerTime: Self.now.addingTimeInterval(60 * 60),
            currentTime: Self.now,
            state: state
        )
        #expect(result == "🌙 Iftar")
    }

    @Test("active Nawafil uses clock glyph instead of moon")
    func nawafilUsesClockGlyph() {
        let state = FastingDayState(
            isActive: true, trigger: .weeklySchedule, prohibition: nil, date: Self.now
        )
        let result = FastingLabelFormatter.relabel(
            prayerName: "Fajr",
            prayerTime: Self.now.addingTimeInterval(60 * 60),
            currentTime: Self.now,
            state: state
        )
        #expect(result == "🕗 Suhoor")
    }

    @Test("outside 2h window returns original prayer name even when active")
    func outsideWindowPassthrough() {
        let state = FastingDayState(
            isActive: true, trigger: .autoRamadan, prohibition: nil, date: Self.now
        )
        let result = FastingLabelFormatter.relabel(
            prayerName: "Fajr",
            prayerTime: Self.now.addingTimeInterval(3 * 60 * 60),  // 3h away
            currentTime: Self.now,
            state: state
        )
        #expect(result == "Fajr")
    }

    @Test("only Fajr and Maghrib are relabeled — other prayers untouched")
    func otherPrayersUntouched() {
        let state = FastingDayState(
            isActive: true, trigger: .autoRamadan, prohibition: nil, date: Self.now
        )
        for prayer in ["Sunrise", "Dhuhr", "Asr", "Isha"] {
            let result = FastingLabelFormatter.relabel(
                prayerName: prayer,
                prayerTime: Self.now.addingTimeInterval(60 * 60),
                currentTime: Self.now,
                state: state
            )
            #expect(result == prayer, "\(prayer) should not be relabeled")
        }
    }

    @Test("prohibition state does not relabel")
    func prohibitionNoRelabel() {
        let state = FastingDayState(
            isActive: false, trigger: nil, prohibition: .eidAlFitr, date: Self.now
        )
        let result = FastingLabelFormatter.relabel(
            prayerName: "Fajr",
            prayerTime: Self.now.addingTimeInterval(60 * 60),
            currentTime: Self.now,
            state: state
        )
        #expect(result == "Fajr")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Packages/IqamahCore && swift test --filter FastingLabelFormatterTests 2>&1 | tail -10
```

Expected: failures — `FastingLabelFormatter` doesn't exist.

- [ ] **Step 3: Implement the formatter**

Create `Packages/IqamahCore/Sources/IqamahCore/Services/FastingLabelFormatter.swift`:

```swift
import Foundation

/// Pure helpers for relabeling prayer-name strings when Fasting Mode is active.
/// Consumed by every narrow surface (menu bar, watch, widgets, Live Activity).
public enum FastingLabelFormatter {

    /// Window (in seconds) before a prayer time during which the Suhoor/Iftar
    /// relabel applies. 2 hours per spec.
    private static let relabelWindow: TimeInterval = 2 * 60 * 60

    /// Relabel a prayer name when Fasting Mode is active and the prayer is within 2h.
    /// Returns the original name if any precondition fails (inactive, prohibition,
    /// outside window, or non-Fajr/non-Maghrib prayer).
    public static func relabel(
        prayerName: String,
        prayerTime: Date,
        currentTime: Date,
        state: FastingDayState
    ) -> String {
        // Only relabel when actively fasting (not for prohibition state)
        guard state.isActive, state.trigger != nil else { return prayerName }

        // Only Fajr (→ Suhoor) and Maghrib (→ Iftar) are relabeled
        let suhoorLabel: String?
        switch prayerName {
        case "Fajr": suhoorLabel = "Suhoor"
        case "Maghrib": suhoorLabel = "Iftar"
        default: return prayerName
        }
        guard let newLabel = suhoorLabel else { return prayerName }

        // Within 2h window?
        let secondsUntil = prayerTime.timeIntervalSince(currentTime)
        guard (0...Self.relabelWindow).contains(secondsUntil) else { return prayerName }

        // Glyph picker
        let glyph: String = state.trigger == .autoRamadan ? "🌙" : "🕗"

        return "\(glyph) \(newLabel)"
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Packages/IqamahCore && swift test --filter FastingLabelFormatterTests 2>&1 | tail -10
```

Expected: all 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/IqamahCore/Sources/IqamahCore/Services/FastingLabelFormatter.swift \
        Packages/IqamahCore/Tests/IqamahCoreTests/FastingLabelFormatterTests.swift
git commit -m "feat(core): FastingLabelFormatter for prayer-name relabeling

AC-0365. Relabels Fajr → Suhoor and Maghrib → Iftar within 2h window
when state.isActive == true. 🌙 glyph for autoRamadan; 🕗 for any other
trigger. Passes through for inactive states, prohibition states,
outside-window cases, and non-Fajr/Maghrib prayers.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: `FastingNotificationPlanner` — pure scheduling helpers

**Files:**
- Create: `Packages/IqamahCore/Sources/IqamahCore/Services/FastingNotificationPlanner.swift`
- Create: `Packages/IqamahCore/Tests/IqamahCoreTests/FastingNotificationPlannerTests.swift`

**Why:** AC-0376, AC-0377 (logic portion). Pure helpers that produce notification fire-dates given prayer times + settings + Hijri context. Per-platform schedulers (Tasks 17–19) wrap these with `UNUserNotificationCenter` calls.

- [ ] **Step 1: Write the failing tests**

Create `Packages/IqamahCore/Tests/IqamahCoreTests/FastingNotificationPlannerTests.swift`:

```swift
import Testing
import Foundation
@testable import IqamahCore

@Suite("FastingNotificationPlanner")
struct FastingNotificationPlannerTests {
    static let tz = TimeZone(identifier: "America/Toronto")!
    static let hijri = Calendar(identifier: .islamicUmmAlQura)

    static func fajrTime(hour: Int = 5, minute: Int = 12) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: hour, minute: minute))!
    }

    static func maghribTime(hour: Int = 20, minute: Int = 32) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: hour, minute: minute))!
    }

    @Test("Suhoor 30-min lead fires 30 minutes before Fajr")
    func suhoorThirtyMinLead() {
        var s = FastingModeSettings()
        s.suhoorLeadMinutes = 30
        let fajr = Self.fajrTime()
        let fire = FastingNotificationPlanner.suhoorFireDate(fajr: fajr, settings: s)
        #expect(fire == fajr.addingTimeInterval(-30 * 60))
    }

    @Test("Suhoor 120-min lead fires 2 hours before Fajr")
    func suhoorOneTwentyMinLead() {
        var s = FastingModeSettings()
        s.suhoorLeadMinutes = 120
        let fajr = Self.fajrTime()
        let fire = FastingNotificationPlanner.suhoorFireDate(fajr: fajr, settings: s)
        #expect(fire == fajr.addingTimeInterval(-120 * 60))
    }

    @Test("Iftar 15-min lead fires 15 minutes before Maghrib")
    func iftarFifteenMinLead() {
        var s = FastingModeSettings()
        s.iftarLeadMinutes = 15
        let maghrib = Self.maghribTime()
        let fire = FastingNotificationPlanner.iftarFireDate(maghrib: maghrib, settings: s)
        #expect(fire == maghrib.addingTimeInterval(-15 * 60))
    }

    @Test("Day-before fires for Ramadan day 1 — tomorrow is 1 Ramadan")
    func dayBeforeRamadanDay1Fires() {
        var s = FastingModeSettings()
        s.dayBeforeEnabled = true
        s.dayBeforeHour = 20
        s.dayBeforeMinute = 0
        s.autoRamadan = true
        // Build a "today" that is 30 Sha'ban so tomorrow is 1 Ramadan
        var hCal = Self.hijri
        hCal.timeZone = Self.tz
        let tomorrow = hCal.date(from: DateComponents(year: 1448, month: 9, day: 1, hour: 12))!
        let plan = FastingNotificationPlanner.dayBefore(
            tomorrow: tomorrow,
            tomorrowState: FastingDayState(isActive: true, trigger: .autoRamadan, prohibition: nil, date: tomorrow),
            settings: s,
            hijriCalendar: hCal,
            timezone: Self.tz
        )
        #expect(plan != nil)
    }

    @Test("Day-before skipped for Ramadan day 2")
    func dayBeforeRamadanDay2Skipped() {
        var s = FastingModeSettings()
        s.dayBeforeEnabled = true
        s.autoRamadan = true
        var hCal = Self.hijri
        hCal.timeZone = Self.tz
        let tomorrow = hCal.date(from: DateComponents(year: 1448, month: 9, day: 2, hour: 12))!
        let plan = FastingNotificationPlanner.dayBefore(
            tomorrow: tomorrow,
            tomorrowState: FastingDayState(isActive: true, trigger: .autoRamadan, prohibition: nil, date: tomorrow),
            settings: s,
            hijriCalendar: hCal,
            timezone: Self.tz
        )
        #expect(plan == nil)
    }

    @Test("Day-before fires for Nawafil Monday")
    func dayBeforeNawafilFires() {
        var s = FastingModeSettings()
        s.dayBeforeEnabled = true
        s.weeklyDays = [2]  // Mon
        var hCal = Self.hijri
        hCal.timeZone = Self.tz
        let tomorrow = hCal.date(from: DateComponents(year: 1448, month: 6, day: 15, hour: 12))!
        // Verify this Hijri date maps to a Monday in Gregorian
        let plan = FastingNotificationPlanner.dayBefore(
            tomorrow: tomorrow,
            tomorrowState: FastingDayState(isActive: true, trigger: .weeklySchedule, prohibition: nil, date: tomorrow),
            settings: s,
            hijriCalendar: hCal,
            timezone: Self.tz
        )
        #expect(plan != nil)
    }

    @Test("Day-before skipped when dayBeforeEnabled is false")
    func dayBeforeDisabledSkipped() {
        var s = FastingModeSettings()
        s.dayBeforeEnabled = false
        let tomorrow = Self.fajrTime()
        let plan = FastingNotificationPlanner.dayBefore(
            tomorrow: tomorrow,
            tomorrowState: FastingDayState(isActive: true, trigger: .weeklySchedule, prohibition: nil, date: tomorrow),
            settings: s,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(plan == nil)
    }

    @Test("Day-before skipped when tomorrow is hard-prohibited")
    func dayBeforeProhibitionSkipped() {
        var s = FastingModeSettings()
        s.dayBeforeEnabled = true
        let tomorrow = Self.fajrTime()
        let plan = FastingNotificationPlanner.dayBefore(
            tomorrow: tomorrow,
            tomorrowState: FastingDayState(isActive: false, trigger: nil, prohibition: .eidAlFitr, date: tomorrow),
            settings: s,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(plan == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Packages/IqamahCore && swift test --filter FastingNotificationPlannerTests 2>&1 | tail -10
```

Expected: failures — planner doesn't exist.

- [ ] **Step 3: Implement the planner**

Create `Packages/IqamahCore/Sources/IqamahCore/Services/FastingNotificationPlanner.swift`:

```swift
import Foundation

/// A planned notification — fire date plus the body text the scheduler should attach.
public struct FastingNotificationPlan: Equatable {
    public let fireDate: Date
    public let title: String
    public let body: String
    public let identifier: String
}

/// Pure helpers for computing notification fire dates for Fasting Mode reminders.
/// Per-platform schedulers wrap these with UNUserNotificationCenter calls.
public enum FastingNotificationPlanner {

    /// When should the Suhoor reminder fire for a given Fajr time?
    public static func suhoorFireDate(fajr: Date, settings: FastingModeSettings) -> Date {
        fajr.addingTimeInterval(-Double(settings.suhoorLeadMinutes) * 60)
    }

    /// When should the Iftar reminder fire for a given Maghrib time?
    public static func iftarFireDate(maghrib: Date, settings: FastingModeSettings) -> Date {
        maghrib.addingTimeInterval(-Double(settings.iftarLeadMinutes) * 60)
    }

    /// Plan the day-before reminder for `tomorrow`. Returns nil when the reminder should be skipped:
    /// - dayBeforeEnabled is false
    /// - notificationsEnabled is false
    /// - tomorrow has a prohibition
    /// - tomorrow is Ramadan day 2–30 (day 1 is included; days 2–30 are skipped)
    /// - tomorrow is inactive (no fasting day to remind about)
    public static func dayBefore(
        tomorrow: Date,
        tomorrowState: FastingDayState,
        settings: FastingModeSettings,
        hijriCalendar: Calendar,
        timezone: TimeZone
    ) -> FastingNotificationPlan? {
        guard settings.notificationsEnabled, settings.dayBeforeEnabled else { return nil }
        guard tomorrowState.prohibition == nil else { return nil }
        guard tomorrowState.isActive else { return nil }

        // Skip Ramadan days 2–30 (day 1 still fires)
        var hCal = hijriCalendar
        hCal.timeZone = timezone
        let hijriMonth = hCal.component(.month, from: tomorrow)
        let hijriDay = hCal.component(.day, from: tomorrow)
        if hijriMonth == 9, hijriDay >= 2, hijriDay <= 30 {
            return nil
        }

        // Compute fire date — at user-picked hour:minute on the day *before* tomorrow
        var gregCal = Calendar(identifier: .gregorian)
        gregCal.timeZone = timezone
        guard let dayBefore = gregCal.date(byAdding: .day, value: -1, to: tomorrow) else { return nil }
        var components = gregCal.dateComponents([.year, .month, .day], from: dayBefore)
        components.hour = settings.dayBeforeHour
        components.minute = settings.dayBeforeMinute
        guard let fireDate = gregCal.date(from: components) else { return nil }

        // Compose body text based on tomorrow's trigger
        let isRamadanDayOne = (hijriMonth == 9 && hijriDay == 1)
        let title: String
        let body: String
        if isRamadanDayOne {
            title = "🌙 Ramadan begins tomorrow"
            body = "First Suhoor begins tonight"
        } else {
            title = "🕗 Fasting tomorrow"
            body = "Suhoor preparations begin tonight"
        }

        let identifier = identifier(for: tomorrow, kind: "daybefore", timezone: timezone)
        return FastingNotificationPlan(
            fireDate: fireDate, title: title, body: body, identifier: identifier
        )
    }

    /// Produces a stable per-day identifier for cancellation/replacement.
    /// Format: `fastingmode.<kind>.yyyy-MM-dd`
    public static func identifier(for date: Date, kind: String, timezone: TimeZone) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = timezone
        return "fastingmode.\(kind).\(fmt.string(from: date))"
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Packages/IqamahCore && swift test --filter FastingNotificationPlannerTests 2>&1 | tail -10
```

Expected: all 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/IqamahCore/Sources/IqamahCore/Services/FastingNotificationPlanner.swift \
        Packages/IqamahCore/Tests/IqamahCoreTests/FastingNotificationPlannerTests.swift
git commit -m "feat(core): FastingNotificationPlanner — pure fire-date helpers

AC-0376 (logic), AC-0377 (logic). Computes Suhoor/Iftar fire dates from
prayer times + lead minutes. dayBefore returns nil when reminder should
be skipped: disabled toggle, prohibition, Ramadan days 2-30, or inactive
tomorrow. Identifier format 'fastingmode.<kind>.yyyy-MM-dd' for stable
cancellation/replacement across reschedules.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 10: `FastingBanner` shared SwiftUI view

**Files:**
- Create: `iqamah/Views/Shared/FastingBanner.swift`
- Modify: `iqamah.xcodeproj/project.pbxproj` (add file ref + memberships for `iqamah` and `iqamah-iOS` targets)

**Why:** AC-0366, AC-0367. Renders the dual-countdown banner (Suhoor ends + Iftar at) when state is active, or the prohibition message when `state.prohibition != nil`. Purple gradient + 🌙 for Ramadan; teal + 🕗 for Nawafil; grey + ⚠️ for prohibition. Used by macOS popover (Task 11) and iOS hero card (Task 12).

- [ ] **Step 1: Create the SwiftUI view**

Create `iqamah/Views/Shared/` directory if it doesn't exist. Then create `iqamah/Views/Shared/FastingBanner.swift`:

```swift
import SwiftUI
import IqamahCore

/// Shared dual-countdown banner for Fasting Mode.
/// Renders either: active state (Suhoor ends + Iftar at), or prohibition message.
/// Callers must gate on `state.isActive || state.prohibition != nil` before rendering.
public struct FastingBanner: View {
    let state: FastingDayState
    let fajrTime: Date?
    let maghribTime: Date?
    let isShiaMethod: Bool

    public init(state: FastingDayState, fajrTime: Date?, maghribTime: Date?, isShiaMethod: Bool) {
        self.state = state
        self.fajrTime = fajrTime
        self.maghribTime = maghribTime
        self.isShiaMethod = isShiaMethod
    }

    public var body: some View {
        Group {
            if let prohibition = state.prohibition {
                prohibitionBanner(prohibition)
            } else if state.isActive {
                activeBanner
            } else {
                EmptyView()  // caller should not have rendered us
            }
        }
    }

    private var activeBanner: some View {
        let isRamadan = state.trigger == .autoRamadan
        let gradient: LinearGradient = isRamadan
            ? LinearGradient(colors: [Color(red: 0.16, green: 0.10, blue: 0.23),
                                       Color(red: 0.10, green: 0.16, blue: 0.23)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color(red: 0.10, green: 0.23, blue: 0.23),
                                       Color(red: 0.10, green: 0.16, blue: 0.23)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
        let glyph = isRamadan ? "🌙" : "🕗"

        return HStack(alignment: .center, spacing: 12) {
            Text(glyph).font(.system(size: 28))
            VStack(alignment: .leading, spacing: 4) {
                if let fajr = fajrTime {
                    HStack {
                        Text("Suhoor ends")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(Color(red: 0.79, green: 0.63, blue: 0.23))
                        Spacer()
                        Text(formatted(fajr))
                            .font(.caption).fontWeight(.medium).monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
                if let maghrib = maghribTime {
                    HStack {
                        Text("Iftar at")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(Color(red: 0.79, green: 0.63, blue: 0.23))
                        Spacer()
                        Text(formatted(maghrib))
                            .font(.caption).fontWeight(.medium).monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(red: 0.79, green: 0.63, blue: 0.23).opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func prohibitionBanner(_ prohibition: ProhibitedDay) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("⚠️").font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text(prohibition.displayName)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text("Fasting is forbidden today")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.10)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    private func formatted(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}
```

- [ ] **Step 2: Add file refs to pbxproj for both targets**

Open `iqamah.xcodeproj/project.pbxproj`. The file needs:
1. One PBXFileReference (e.g., `FB000000000000000000001R`)
2. Two PBXBuildFile entries (one per target) referencing the same file ref
3. Membership in the iqamah Sources phase AND iqamah-iOS Sources phase
4. A group entry under a new `Shared` group inside the `Views` group (or under iqamah/Views/ directly)

Use the pattern already established by `PrayerActivityAttributes.swift` (consolidated in commit `c5215bd`) for multi-target membership. Run:

```bash
grep -A1 "LA000000000000000000010R" iqamah.xcodeproj/project.pbxproj | head -10
```

Then mirror that structure for `FastingBanner.swift` with new GUIDs `FB000000000000000000001` (build file iqamah), `FB000000000000000000002` (build file iqamah-iOS), and `FB000000000000000000001R` (file ref).

- [ ] **Step 3: Build both targets to verify the view compiles into both**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | tail -5
xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

Expected: both `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add iqamah/Views/Shared/FastingBanner.swift iqamah.xcodeproj/project.pbxproj
git commit -m "feat(ui): shared FastingBanner view for macOS + iOS

AC-0366, AC-0367. Renders dual Suhoor/Iftar countdown for active state
(purple+🌙 for Ramadan, teal+🕗 for Nawafil) or prohibition message
(grey+⚠️). Multi-target membership via pbxproj — single file compiled
into both iqamah and iqamah-iOS schemes.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 11: macOS menu bar + popover wiring

**Files:**
- Modify: `iqamah/AppDelegate.swift:136-211` (`updateStatusBarDisplay`)
- Modify: `iqamah/Views/MenuBarPopoverView.swift`

**Why:** AC-0368. Apply `FastingLabelFormatter.relabel` to the next-prayer name in the menu bar display. Render `FastingBanner` above the prayer list in the popover.

- [ ] **Step 1: Modify menu bar to use FastingLabelFormatter**

In `iqamah/AppDelegate.swift`, locate the `displayText` line in `updateStatusBarDisplay` (around line 200):

```swift
        let displayText = "\(next.name) \(formatter.string(from: next.time))"
```

Replace with:

```swift
        let fastingState = FastingModeEngine.evaluate(
            for: now,
            settings: settings.fastingModeSettings,
            calculationMethod: settings.calculationMethod,
            hijriCalendar: Calendar(identifier: .islamicUmmAlQura),
            timezone: timezone
        )
        let labeledName = FastingLabelFormatter.relabel(
            prayerName: next.name,
            prayerTime: next.time,
            currentTime: now,
            state: fastingState
        )
        let displayText = "\(labeledName) \(formatter.string(from: next.time))"
```

- [ ] **Step 2: Render FastingBanner in the popover**

Find the body of `iqamah/Views/MenuBarPopoverView.swift`:

```bash
grep -n "var body" iqamah/Views/MenuBarPopoverView.swift | head -3
```

Inside the body, locate where the prayer list begins (likely a `ForEach` or `VStack { ... prayerRows ... }`). Immediately above it, insert:

```swift
            let fastingState = FastingModeEngine.evaluate(
                for: Date(),
                settings: settings.fastingModeSettings,
                calculationMethod: settings.calculationMethod,
                hijriCalendar: Calendar(identifier: .islamicUmmAlQura),
                timezone: TimeZone(identifier: settings.activeTimezoneIdentifier) ?? .current
            )
            if fastingState.isActive || fastingState.prohibition != nil {
                FastingBanner(
                    state: fastingState,
                    fajrTime: prayerTimes?.fajr,
                    maghribTime: prayerTimes?.maghrib,
                    isShiaMethod: settings.calculationMethod.isShiaMethod
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
```

(Adjust `prayerTimes?.fajr` / `.maghrib` to whatever variable holds today's `PrayerTimes` in the popover view.)

- [ ] **Step 3: Build the macOS scheme**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Manual smoke**

Run the macOS app. With Fasting Mode disabled, menu bar should show standard countdown. Enable Fasting Mode in Settings, toggle `weeklyDays` to include today's weekday, and reopen the popover. Banner should appear above the prayer list within ~60 s.

- [ ] **Step 5: Commit**

```bash
git add iqamah/AppDelegate.swift iqamah/Views/MenuBarPopoverView.swift
git commit -m "feat(macos): Fasting Mode in menu bar countdown + popover banner

AC-0368. Menu bar countdown applies FastingLabelFormatter relabel within
2h window. Popover renders FastingBanner above the prayer list when
fasting today (or when today is hard-prohibited).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 12: iOS hero card + prayer row relabel

**Files:**
- Modify: `iqamah/iOS/PrayerHeroCard.swift` (render FastingBanner above the next-prayer block)
- Modify: `iqamah/iOS/PrayerRowMobileView.swift` (apply relabel within 2h window)

**Why:** AC-0369 (iOS portion). The hero card is the most prominent iOS surface for Fasting Mode messaging; the per-row relabel keeps the next-prayer name consistent with the menu bar treatment.

- [ ] **Step 1: Add FastingBanner to PrayerHeroCard**

Locate the body of `iqamah/iOS/PrayerHeroCard.swift`. Find the outer `VStack` that contains the next-prayer label + countdown. Insert immediately ABOVE the existing content (so the banner appears above the hero):

```swift
            let fastingState = FastingModeEngine.evaluate(
                for: Date(),
                settings: settings.fastingModeSettings,
                calculationMethod: settings.calculationMethod,
                hijriCalendar: Calendar(identifier: .islamicUmmAlQura),
                timezone: TimeZone(identifier: settings.activeTimezoneIdentifier) ?? .current
            )
            if fastingState.isActive || fastingState.prohibition != nil {
                FastingBanner(
                    state: fastingState,
                    fajrTime: prayerTimes.fajr,
                    maghribTime: prayerTimes.maghrib,
                    isShiaMethod: settings.calculationMethod.isShiaMethod
                )
                .padding(.bottom, 12)
            }
```

Use the existing `prayerTimes` variable (the same struct the hero card consumes for the next-prayer countdown). If the hero card receives a `PrayerTimes` parameter under a different name (e.g. `times`), substitute accordingly.

- [ ] **Step 2: Apply relabel in PrayerRowMobileView**

In `iqamah/iOS/PrayerRowMobileView.swift`, find where the prayer name `Text(...)` is rendered. Replace:

```swift
Text(prayer.name)
```

with:

```swift
Text(FastingLabelFormatter.relabel(
    prayerName: prayer.name,
    prayerTime: prayer.time,
    currentTime: Date(),
    state: FastingModeEngine.evaluate(
        for: Date(),
        settings: settings.fastingModeSettings,
        calculationMethod: settings.calculationMethod,
        hijriCalendar: Calendar(identifier: .islamicUmmAlQura),
        timezone: TimeZone(identifier: settings.activeTimezoneIdentifier) ?? .current
    )
))
```

`settings` must be accessible via `@EnvironmentObject` or passed in. If the row doesn't currently observe settings, add:

```swift
@EnvironmentObject private var settings: SettingsManager
```

Find the actual binding by searching:

```bash
grep -n "@EnvironmentObject\|settings:" iqamah/iOS/PrayerRowMobileView.swift | head -5
```

- [ ] **Step 3: Build iOS scheme**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add iqamah/iOS/PrayerHeroCard.swift iqamah/iOS/PrayerRowMobileView.swift
git commit -m "feat(ios): Fasting Mode hero banner + row relabel

AC-0369 (iOS). PrayerHeroCard renders FastingBanner above next-prayer
block when active or prohibited. PrayerRowMobileView applies relabel
within 2h window so the row name flips from Fajr/Maghrib to
Suhoor/Iftar with the appropriate glyph.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 13: watchOS prayer tab relabel

**Files:**
- Modify: `IqamahWatch/PrayerTimesTab.swift:48` (and the row rendering loop)

**Why:** AC-0369 (watchOS portion). Watch gets the relabel but NOT the banner (limited screen real estate).

- [ ] **Step 1: Apply relabel in the watch row**

In `IqamahWatch/PrayerTimesTab.swift`, find the row rendering loop (search for `ForEach` or `prayer.name`):

```bash
grep -n "prayer.name\|ForEach" IqamahWatch/PrayerTimesTab.swift | head -5
```

Replace the prayer-name `Text(prayer.name)` (likely line 48 or nearby) with:

```swift
Text(FastingLabelFormatter.relabel(
    prayerName: prayer.name,
    prayerTime: prayer.time,
    currentTime: Date(),
    state: FastingModeEngine.evaluate(
        for: Date(),
        settings: settings.fastingModeSettings,
        calculationMethod: settings.calculationMethod,
        hijriCalendar: Calendar(identifier: .islamicUmmAlQura),
        timezone: TimeZone(identifier: settings.activeTimezoneIdentifier) ?? .current
    )
))
```

- [ ] **Step 2: Build watch scheme**

```bash
xcodebuild -project iqamah.xcodeproj -scheme "IqamahWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add IqamahWatch/PrayerTimesTab.swift
git commit -m "feat(watch): Fasting Mode relabel in prayer rows

AC-0369 (watchOS). Watch shares the relabel logic with iOS/macOS but
skips the banner due to limited screen real estate.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 14: Widgets + Live Activity wiring

**Files:**
- Modify: `IqamahLiveActivity/PrayerActivityAttributes.swift` (add optional ContentState fields)
- Modify: `IqamahLiveActivity/PrayerLiveActivityView.swift` (apply relabel)
- Modify: `iqamah/iOS/PrayerActivityManager.swift` (pass FastingDayState into ContentState)
- Modify: `IqamahWidget/IqamahWidget.swift` (provider includes fasting state; views relabel)

**Why:** AC-0370. Adds backward-compatible optional fields to `ContentState`; widget timeline entries carry today's fasting state; LA and widget views apply the relabel.

- [ ] **Step 1: Add optional fields to ContentState**

In `IqamahLiveActivity/PrayerActivityAttributes.swift`, modify the `ContentState` struct:

```swift
struct ContentState: Codable, Hashable {
    let nextPrayerName: String
    let nextPrayerTime: Date
    let followingPrayerName: String
    let moonPhase: Double
    let hijriDateString: String
    // v1.6 additions — optional with default-nil so v1.5 in-flight activities decode cleanly
    var fastingActive: Bool? = nil
    var fastingTriggerRaw: String? = nil

    init(
        nextPrayerName: String, nextPrayerTime: Date,
        followingPrayerName: String, moonPhase: Double, hijriDateString: String,
        fastingActive: Bool? = nil, fastingTriggerRaw: String? = nil
    ) {
        self.nextPrayerName = nextPrayerName
        self.nextPrayerTime = nextPrayerTime
        self.followingPrayerName = followingPrayerName
        self.moonPhase = moonPhase
        self.hijriDateString = hijriDateString
        self.fastingActive = fastingActive
        self.fastingTriggerRaw = fastingTriggerRaw
    }
}
```

- [ ] **Step 2: Apply relabel in the Live Activity view**

In `IqamahLiveActivity/PrayerLiveActivityView.swift`, find each place that renders `context.state.nextPrayerName`. Wrap with:

```swift
private func displayedNextPrayerName(_ context: ActivityViewContext<PrayerActivityAttributes>) -> String {
    guard context.state.fastingActive == true,
          let triggerRaw = context.state.fastingTriggerRaw,
          let trigger = FastingTriggerKind(rawValue: triggerRaw) else {
        return context.state.nextPrayerName
    }
    let stubState = FastingDayState(isActive: true, trigger: trigger, prohibition: nil, date: Date())
    return FastingLabelFormatter.relabel(
        prayerName: context.state.nextPrayerName,
        prayerTime: context.state.nextPrayerTime,
        currentTime: Date(),
        state: stubState
    )
}
```

Replace each `Text(context.state.nextPrayerName)` with `Text(displayedNextPrayerName(context))`.

- [ ] **Step 3: Populate fasting state in PrayerActivityManager**

In `iqamah/iOS/PrayerActivityManager.swift`, find the `buildContentState` method (around line 65). Add to the local computations:

```swift
let fastingState = FastingModeEngine.evaluate(
    for: Date(),
    settings: settings.fastingModeSettings,
    calculationMethod: settings.calculationMethod,
    hijriCalendar: Calendar(identifier: .islamicUmmAlQura),
    timezone: TimeZone(identifier: settings.activeTimezoneIdentifier) ?? .current
)
```

Then add to the `return PrayerActivityAttributes.ContentState(...)` constructor:

```swift
return PrayerActivityAttributes.ContentState(
    nextPrayerName: nextPrayer.name,
    nextPrayerTime: nextPrayer.time,
    followingPrayerName: followingPrayer.name,
    moonPhase: moonPhase,
    hijriDateString: hijriDateString,
    fastingActive: fastingState.isActive,
    fastingTriggerRaw: fastingState.trigger?.rawValue
)
```

- [ ] **Step 4: Apply relabel in widgets**

In `IqamahWidget/IqamahWidget.swift`, find each `Text(entry.nextPrayerName)` or similar (around line 188-201). Wrap with a helper function that mirrors `displayedNextPrayerName` above but reads from the `TimelineEntry` instead of `ActivityViewContext`.

If the widget's `TimelineEntry` does not currently carry Fasting Mode state, add two optional fields to its struct definition (search for `struct PrayerEntry: TimelineEntry`):

```swift
let fastingActive: Bool?
let fastingTriggerRaw: String?
```

Populate them in the provider's `getTimeline(...)` by calling `FastingModeEngine.evaluate(...)` once per entry date.

- [ ] **Step 5: Build extension schemes**

```bash
xcodebuild -project iqamah.xcodeproj -scheme IqamahLiveActivity -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
xcodebuild -project iqamah.xcodeproj -scheme IqamahWidget -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

Expected: all three `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add IqamahLiveActivity/PrayerActivityAttributes.swift \
        IqamahLiveActivity/PrayerLiveActivityView.swift \
        iqamah/iOS/PrayerActivityManager.swift \
        IqamahWidget/IqamahWidget.swift
git commit -m "feat(widgets+live-activity): Fasting Mode state through ContentState

AC-0370. ContentState gains two optional fields (fastingActive,
fastingTriggerRaw) with default-nil — v1.5 in-flight activities decode
cleanly under v1.6. Widget TimelineEntry mirrors the same fields.
Views apply FastingLabelFormatter relabel when fastingActive == true.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 15: `FastingModeSection` settings UI

**Files:**
- Create: `iqamah/Views/Shared/FastingModeSection.swift`
- Modify: `iqamah/Views/SettingsSheetView.swift` (include the new section)
- Modify: `iqamah.xcodeproj/project.pbxproj` (multi-target membership for new file)

**Why:** AC-0371, AC-0372, AC-0373, AC-0374. The configuration UI — master toggle, all 9 trigger toggles with tradition-aware visibility/labels, weekday picker, Friday-alone/Saturday-alone warnings, and reminder controls.

- [ ] **Step 1: Create FastingModeSection**

Create `iqamah/Views/Shared/FastingModeSection.swift`:

```swift
import SwiftUI
import IqamahCore

/// Settings section for Fasting Mode. Renders the master toggle and, when on,
/// all sub-controls. Adapts visibility/labels based on calculationMethod.isShiaMethod.
public struct FastingModeSection: View {
    @ObservedObject var settings: SettingsManager

    public init(settings: SettingsManager) {
        self.settings = settings
    }

    public var body: some View {
        Section("Fasting Mode") {
            Toggle("Enable Fasting Mode", isOn: $settings.fastingModeSettings.enabled)

            if settings.fastingModeSettings.enabled {
                Group {
                    activationSection
                    remindersSection
                }
            }
        }
    }

    private var activationSection: some View {
        Group {
            Toggle("Auto-enable during Ramadan", isOn: $settings.fastingModeSettings.autoRamadan)

            weeklyPicker
            if settings.fastingModeSettings.hasFridayAloneWarning {
                Label("Friday alone is discouraged. Consider adding Thursday or Saturday.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            if settings.fastingModeSettings.hasSaturdayAloneWarning {
                Label("Saturday alone is discouraged. Consider adding Friday.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }

            Toggle("Monthly: Ayyam al-Beed (13–15)", isOn: $settings.fastingModeSettings.ayyamAlBeed)
            Toggle("Annual: 6 days of Shawwal", isOn: $settings.fastingModeSettings.sixDaysShawwal)
            Toggle("Annual: Day of Arafah (9 Dhul-Hijjah)", isOn: $settings.fastingModeSettings.dayOfArafah)
            Toggle("Annual: First 9 of Dhul-Hijjah", isOn: $settings.fastingModeSettings.firstNineDhulHijjah)

            muharramFastRow

            if settings.calculationMethod.isShiaMethod {
                Toggle("Annual: 15 Sha'ban — Laylat al-Bara'ah", isOn: $settings.fastingModeSettings.midShaban)
                Toggle("Annual: 27 Rajab — Mab'ath an-Nabi", isOn: $settings.fastingModeSettings.mabath)
            }
        }
    }

    private var muharramFastRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: $settings.fastingModeSettings.muharramFast) {
                Text(settings.calculationMethod.isShiaMethod
                     ? "Annual: Tasu'a (9 Muharram)"
                     : "Annual: Ashura (9+10 Muharram)")
            }
            Text(settings.calculationMethod.isShiaMethod
                 ? "Shia tradition: commemoration day"
                 : "Sunni Sunnah fast")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var weeklyPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weekly schedule").font(.subheadline)
            HStack(spacing: 6) {
                ForEach(weekdayShortNames, id: \.day) { wd in
                    Button {
                        toggleWeekday(wd.day)
                    } label: {
                        Text(wd.short)
                            .frame(minWidth: 32, minHeight: 32)
                            .background(
                                Circle().fill(settings.fastingModeSettings.weeklyDays.contains(wd.day)
                                               ? Color(red: 0.79, green: 0.63, blue: 0.23)
                                               : Color.gray.opacity(0.2))
                            )
                            .foregroundStyle(settings.fastingModeSettings.weeklyDays.contains(wd.day) ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var weekdayShortNames: [(day: Int, short: String)] {
        // 1=Sun, 2=Mon, ..., 7=Sat per Calendar.component(.weekday)
        [(2, "M"), (3, "T"), (4, "W"), (5, "Th"), (6, "F"), (7, "S"), (1, "Su")]
    }

    private func toggleWeekday(_ day: Int) {
        if settings.fastingModeSettings.weeklyDays.contains(day) {
            settings.fastingModeSettings.weeklyDays.remove(day)
        } else {
            settings.fastingModeSettings.weeklyDays.insert(day)
        }
    }

    private var remindersSection: some View {
        Group {
            Toggle("Send system notifications", isOn: $settings.fastingModeSettings.notificationsEnabled)

            if settings.fastingModeSettings.notificationsEnabled {
                Stepper(value: $settings.fastingModeSettings.suhoorLeadMinutes, in: 5...120, step: 5) {
                    Text("Suhoor lead time: \(settings.fastingModeSettings.suhoorLeadMinutes) min")
                }
                Stepper(value: $settings.fastingModeSettings.iftarLeadMinutes, in: 5...120, step: 5) {
                    Text("Iftar lead time: \(settings.fastingModeSettings.iftarLeadMinutes) min")
                }
                Toggle("Notify night before fasting day", isOn: $settings.fastingModeSettings.dayBeforeEnabled)
                if settings.fastingModeSettings.dayBeforeEnabled {
                    HStack {
                        Text("Day-before time")
                        Spacer()
                        Stepper(value: $settings.fastingModeSettings.dayBeforeHour, in: 0...23) {
                            Text("\(settings.fastingModeSettings.dayBeforeHour):\(String(format: "%02d", settings.fastingModeSettings.dayBeforeMinute))")
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Add to SettingsSheetView**

In `iqamah/Views/SettingsSheetView.swift`, find the main `Form` or `ScrollView` body. Insert `FastingModeSection(settings: SettingsManager.shared)` at an appropriate point (typically after the notifications/adhaan section, before the appearance/UI scale section). Search for an existing section header to find the right spot:

```bash
grep -n "Section(\|Text(\"Notifications\|Text(\"Appearance" iqamah/Views/SettingsSheetView.swift | head -10
```

- [ ] **Step 3: Add pbxproj entry for FastingModeSection.swift**

Mirror the multi-target membership pattern from Task 10 (FastingBanner). Use new GUIDs `FB000000000000000000003` (build file iqamah), `FB000000000000000000004` (build file iqamah-iOS), `FB000000000000000000003R` (file ref).

- [ ] **Step 4: Build both schemes**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | tail -5
xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

Expected: both `BUILD SUCCEEDED`.

- [ ] **Step 5: Manual smoke**

Open Settings on iOS simulator. Verify:
1. Master toggle off → no sub-controls visible
2. Master toggle on → autoRamadan ON by default, all other triggers OFF, weekly empty
3. Tap Friday pill alone → Friday-alone warning appears
4. Switch calculation method to Ja'fari → Muharram row relabels to "Tasu'a (9 Muharram)"; 15 Sha'ban + 27 Rajab toggles appear
5. Switch back to MWL → Muharram row relabels to "Ashura (9+10 Muharram)"; 15 Sha'ban + 27 Rajab toggles disappear

- [ ] **Step 6: Commit**

```bash
git add iqamah/Views/Shared/FastingModeSection.swift iqamah/Views/SettingsSheetView.swift iqamah.xcodeproj/project.pbxproj
git commit -m "feat(settings): FastingModeSection with tradition-aware UI gating

AC-0371, AC-0372, AC-0373, AC-0374. Master toggle hides sub-controls
when off. Weekday picker pills with Friday/Saturday-alone warnings.
Muharram label adapts to isShiaMethod. 15 Sha'ban + 27 Rajab toggles
visible only for Shia methods. Toggle state persists via the underlying
FastingModeSettings struct across method changes (hidden toggles retain
stored values).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 16: watchOS SettingsTab entry

**Files:**
- Modify: `IqamahWatch/SettingsTab.swift`

**Why:** AC-0375. Watch shows only a minimal Fasting Mode master toggle + "Configure on iPhone/Mac" hint.

- [ ] **Step 1: Add the section**

In `IqamahWatch/SettingsTab.swift`, find the `Form` or `List` body. Add a new section:

```swift
Section("Fasting Mode") {
    Toggle("Enable", isOn: $settings.fastingModeSettings.enabled)
    Text("Configure triggers + reminders on iPhone or Mac")
        .font(.caption2).foregroundStyle(.secondary)
}
```

- [ ] **Step 2: Build watch scheme**

```bash
xcodebuild -project iqamah.xcodeproj -scheme "IqamahWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add IqamahWatch/SettingsTab.swift
git commit -m "feat(watch): minimal Fasting Mode entry in SettingsTab

AC-0375. Master toggle only — full configuration deferred to iPhone/Mac.
Watch syncs the settings struct via KVS.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 17: macOS `FastingNotificationScheduler` + debounce

**Files:**
- Create: `iqamah/FastingNotificationScheduler.swift`
- Modify: `iqamah/AppDelegate.swift` (call `requestReschedule()` at app launch + on settings change + at midnight)
- Modify: `iqamah.xcodeproj/project.pbxproj` (add file to iqamah target only)

**Why:** AC-0376, AC-0377, AC-0378, AC-0379. macOS wrapper around `UNUserNotificationCenter`. 7-day rolling window via `FastingNotificationPlanner`. 500ms debounce coalesces rapid settings changes.

- [ ] **Step 1: Create the scheduler**

Create `iqamah/FastingNotificationScheduler.swift`:

```swift
import Foundation
import IqamahCore
import UserNotifications

/// macOS scheduler for Fasting Mode reminders. Wraps UNUserNotificationCenter
/// with a 500ms debounce so rapid settings changes coalesce into one reschedule.
@MainActor
final class FastingNotificationScheduler {
    static let shared = FastingNotificationScheduler()
    private init() {}

    private var debounceWorkItem: DispatchWorkItem?

    /// Debounced entry point — call from any settings observer.
    func requestReschedule() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.rescheduleNow()
            }
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Immediate reschedule — clears existing fastingmode.* notifications + posts new 7-day window.
    func rescheduleNow() async {
        let center = UNUserNotificationCenter.current()

        // Remove all existing fastingmode.* requests
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("fastingmode.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let settings = SettingsManager.shared
        guard settings.fastingModeSettings.enabled,
              settings.fastingModeSettings.notificationsEnabled else { return }

        guard let city = settings.loadCity() else { return }
        let tz = TimeZone(identifier: settings.activeTimezoneIdentifier) ?? .current
        let hCal = Calendar(identifier: .islamicUmmAlQura)
        let calculator = PrayerCalculator(
            coordinate: city.coordinate,
            timezone: tz,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )

        // Walk 7 days starting today
        var gregCal = Calendar(identifier: .gregorian)
        gregCal.timeZone = tz
        let now = Date()

        for dayOffset in 0..<7 {
            guard let day = gregCal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let dayState = FastingModeEngine.evaluate(
                for: day,
                settings: settings.fastingModeSettings,
                calculationMethod: settings.calculationMethod,
                hijriCalendar: hCal,
                timezone: tz
            )

            // Suhoor + Iftar for active fasting days
            if dayState.isActive, let prayerTimes = try? calculator.calculate(for: day) {
                let suhoorFire = FastingNotificationPlanner.suhoorFireDate(fajr: prayerTimes.fajr, settings: settings.fastingModeSettings)
                let iftarFire = FastingNotificationPlanner.iftarFireDate(maghrib: prayerTimes.maghrib, settings: settings.fastingModeSettings)
                if suhoorFire > now {
                    await schedule(at: suhoorFire,
                                   title: dayState.trigger == .autoRamadan ? "🌙 Suhoor reminder" : "🕗 Suhoor reminder",
                                   body: "Suhoor ends in \(settings.fastingModeSettings.suhoorLeadMinutes) min — Fajr at \(format(prayerTimes.fajr, tz: tz))",
                                   identifier: FastingNotificationPlanner.identifier(for: day, kind: "suhoor", timezone: tz))
                }
                if iftarFire > now {
                    await schedule(at: iftarFire,
                                   title: dayState.trigger == .autoRamadan ? "🌙 Iftar approaches" : "🕗 Iftar approaches",
                                   body: "Iftar in \(settings.fastingModeSettings.iftarLeadMinutes) min — Maghrib at \(format(prayerTimes.maghrib, tz: tz))",
                                   identifier: FastingNotificationPlanner.identifier(for: day, kind: "iftar", timezone: tz))
                }
            }

            // Day-before reminder: today's state used for "tomorrow" (offset+1)
            if dayOffset < 6 {
                guard let tomorrow = gregCal.date(byAdding: .day, value: dayOffset + 1, to: now) else { continue }
                let tomorrowState = FastingModeEngine.evaluate(
                    for: tomorrow,
                    settings: settings.fastingModeSettings,
                    calculationMethod: settings.calculationMethod,
                    hijriCalendar: hCal,
                    timezone: tz
                )
                if let plan = FastingNotificationPlanner.dayBefore(
                    tomorrow: tomorrow,
                    tomorrowState: tomorrowState,
                    settings: settings.fastingModeSettings,
                    hijriCalendar: hCal,
                    timezone: tz
                ), plan.fireDate > now {
                    await schedule(at: plan.fireDate, title: plan.title, body: plan.body, identifier: plan.identifier)
                }
            }
        }
    }

    private func schedule(at date: Date, title: String, body: String, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func format(_ date: Date, tz: TimeZone) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.timeZone = tz
        return fmt.string(from: date)
    }
}
```

- [ ] **Step 2: Wire AppDelegate to call requestReschedule**

In `iqamah/AppDelegate.swift`, at the end of `applicationDidFinishLaunching` (or wherever app setup completes), add:

```swift
FastingNotificationScheduler.shared.requestReschedule()

// Re-schedule on settings change
NotificationCenter.default.addObserver(
    forName: .settingsDidChange,
    object: nil, queue: .main
) { _ in
    FastingNotificationScheduler.shared.requestReschedule()
}

// Re-schedule at midnight (uses the existing midnight check in updateStatusBarDisplay)
```

In the existing 60-second timer callback (or at the midnight detection point in `updateStatusBarDisplay`), add a `Calendar.current.isDate(now, inSameDayAs: announcedDate)` guard — when the day changes, call `FastingNotificationScheduler.shared.requestReschedule()`.

- [ ] **Step 3: Add pbxproj entry for FastingNotificationScheduler.swift**

Add to the `iqamah` target only (not iqamah-iOS — iOS has its own scheduler in Task 18). Use new GUIDs `FN000000000000000000001` (build file) and `FN000000000000000000001R` (file ref).

- [ ] **Step 4: Build macOS scheme**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Manual smoke**

Run the macOS app. Enable Fasting Mode + weekly Mon. Open Console.app and filter for `UNUserNotificationCenter`. Within ~600 ms after toggling, verify Suhoor + Iftar + day-before reminders are added for the upcoming Monday.

- [ ] **Step 6: Commit**

```bash
git add iqamah/FastingNotificationScheduler.swift iqamah/AppDelegate.swift iqamah.xcodeproj/project.pbxproj
git commit -m "feat(macos): FastingNotificationScheduler with 500ms debounce

AC-0376, AC-0377, AC-0378, AC-0379. macOS wrapper around
UNUserNotificationCenter. 7-day rolling window. Consumes
FastingNotificationPlanner for fire-date arithmetic. Debounces
rapid settings changes via DispatchWorkItem cancellation pattern.
Wired to AppDelegate launch + settings observers + midnight rollover.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 18: iOS notification scheduler extension

**Files:**
- Modify: `iqamah/iOS/NotificationScheduler.swift`

**Why:** AC-0376, AC-0377, AC-0378, AC-0379 (iOS portion). Extend the existing iOS scheduler to schedule Fasting Mode reminders alongside prayer notifications. Same 500ms debounce pattern.

- [ ] **Step 1: Add fasting reminder logic**

In `iqamah/iOS/NotificationScheduler.swift`, locate the existing scheduling method (search for `func schedule` or `UNUserNotificationCenter`). At the bottom of the class, add:

```swift
    private var fastingDebounce: DispatchWorkItem?

    /// Debounced entry point for fasting reminder rescheduling.
    func requestFastingReschedule() {
        fastingDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.rescheduleFastingNow()
            }
        }
        fastingDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    @MainActor
    func rescheduleFastingNow() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("fastingmode.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let settings = SettingsManager.shared
        guard settings.fastingModeSettings.enabled,
              settings.fastingModeSettings.notificationsEnabled,
              let city = settings.loadCity() else { return }
        let tz = TimeZone(identifier: settings.activeTimezoneIdentifier) ?? .current
        let hCal = Calendar(identifier: .islamicUmmAlQura)
        let calculator = PrayerCalculator(coordinate: city.coordinate, timezone: tz,
                                          method: settings.calculationMethod,
                                          asrMethod: settings.asrMethod)
        var gregCal = Calendar(identifier: .gregorian); gregCal.timeZone = tz
        let now = Date()

        for dayOffset in 0..<7 {
            guard let day = gregCal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let state = FastingModeEngine.evaluate(for: day, settings: settings.fastingModeSettings,
                                                    calculationMethod: settings.calculationMethod,
                                                    hijriCalendar: hCal, timezone: tz)
            if state.isActive, let times = try? calculator.calculate(for: day) {
                let suhoor = FastingNotificationPlanner.suhoorFireDate(fajr: times.fajr, settings: settings.fastingModeSettings)
                let iftar = FastingNotificationPlanner.iftarFireDate(maghrib: times.maghrib, settings: settings.fastingModeSettings)
                let glyph = state.trigger == .autoRamadan ? "🌙" : "🕗"
                if suhoor > now {
                    await schedule(at: suhoor,
                                   title: "\(glyph) Suhoor reminder",
                                   body: "Suhoor ends in \(settings.fastingModeSettings.suhoorLeadMinutes) min",
                                   identifier: FastingNotificationPlanner.identifier(for: day, kind: "suhoor", timezone: tz))
                }
                if iftar > now {
                    await schedule(at: iftar,
                                   title: "\(glyph) Iftar approaches",
                                   body: "Iftar in \(settings.fastingModeSettings.iftarLeadMinutes) min",
                                   identifier: FastingNotificationPlanner.identifier(for: day, kind: "iftar", timezone: tz))
                }
            }
            if dayOffset < 6, let tomorrow = gregCal.date(byAdding: .day, value: dayOffset + 1, to: now) {
                let tState = FastingModeEngine.evaluate(for: tomorrow, settings: settings.fastingModeSettings,
                                                        calculationMethod: settings.calculationMethod,
                                                        hijriCalendar: hCal, timezone: tz)
                if let plan = FastingNotificationPlanner.dayBefore(tomorrow: tomorrow, tomorrowState: tState,
                                                                    settings: settings.fastingModeSettings,
                                                                    hijriCalendar: hCal, timezone: tz),
                   plan.fireDate > now {
                    await schedule(at: plan.fireDate, title: plan.title, body: plan.body, identifier: plan.identifier)
                }
            }
        }
    }

    private func schedule(at date: Date, title: String, body: String, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
```

- [ ] **Step 2: Wire to settings observers in the iOS app**

In `iqamah/iOS/iqamahApp_iOS.swift` (or wherever the iOS app initializes), add at app launch:

```swift
NotificationScheduler.shared.requestFastingReschedule()
NotificationCenter.default.addObserver(forName: .settingsDidChange, object: nil, queue: .main) { _ in
    NotificationScheduler.shared.requestFastingReschedule()
}
```

- [ ] **Step 3: Build iOS scheme**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add iqamah/iOS/NotificationScheduler.swift iqamah/iOS/iqamahApp_iOS.swift
git commit -m "feat(ios): extend NotificationScheduler with Fasting Mode reminders

AC-0376, AC-0377, AC-0378, AC-0379 (iOS). 7-day rolling window with
500ms debounce. Mirrors the macOS scheduler structure but runs in the
existing NotificationScheduler singleton.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 19: watchOS notification scheduler extension

**Files:**
- Modify: `IqamahWatch/WatchNotificationScheduler.swift`

**Why:** AC-0376, AC-0377, AC-0378, AC-0379 (watchOS). Extend the existing watch scheduler. Logic identical to iOS — call `FastingNotificationPlanner` over a 7-day window with 500ms debounce.

- [ ] **Step 1: Add watch fasting scheduler methods**

In `IqamahWatch/WatchNotificationScheduler.swift`, locate the existing scheduling section. At the bottom of the class, add:

```swift
    private var fastingDebounce: DispatchWorkItem?

    func requestFastingReschedule() {
        fastingDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.rescheduleFastingNow()
            }
        }
        fastingDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    @MainActor
    func rescheduleFastingNow() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("fastingmode.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let settings = SettingsManager.shared
        guard settings.fastingModeSettings.enabled,
              settings.fastingModeSettings.notificationsEnabled,
              let city = settings.loadCity() else { return }
        let tz = TimeZone(identifier: settings.activeTimezoneIdentifier) ?? .current
        let hCal = Calendar(identifier: .islamicUmmAlQura)
        let calculator = PrayerCalculator(coordinate: city.coordinate, timezone: tz,
                                          method: settings.calculationMethod,
                                          asrMethod: settings.asrMethod)
        var gregCal = Calendar(identifier: .gregorian); gregCal.timeZone = tz
        let now = Date()

        for dayOffset in 0..<7 {
            guard let day = gregCal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let state = FastingModeEngine.evaluate(for: day, settings: settings.fastingModeSettings,
                                                    calculationMethod: settings.calculationMethod,
                                                    hijriCalendar: hCal, timezone: tz)
            if state.isActive, let times = try? calculator.calculate(for: day) {
                let suhoor = FastingNotificationPlanner.suhoorFireDate(fajr: times.fajr, settings: settings.fastingModeSettings)
                let iftar = FastingNotificationPlanner.iftarFireDate(maghrib: times.maghrib, settings: settings.fastingModeSettings)
                let glyph = state.trigger == .autoRamadan ? "🌙" : "🕗"
                if suhoor > now {
                    await scheduleFasting(at: suhoor,
                                          title: "\(glyph) Suhoor reminder",
                                          body: "Suhoor ends in \(settings.fastingModeSettings.suhoorLeadMinutes) min",
                                          identifier: FastingNotificationPlanner.identifier(for: day, kind: "suhoor", timezone: tz))
                }
                if iftar > now {
                    await scheduleFasting(at: iftar,
                                          title: "\(glyph) Iftar approaches",
                                          body: "Iftar in \(settings.fastingModeSettings.iftarLeadMinutes) min",
                                          identifier: FastingNotificationPlanner.identifier(for: day, kind: "iftar", timezone: tz))
                }
            }
            if dayOffset < 6, let tomorrow = gregCal.date(byAdding: .day, value: dayOffset + 1, to: now) {
                let tState = FastingModeEngine.evaluate(for: tomorrow, settings: settings.fastingModeSettings,
                                                        calculationMethod: settings.calculationMethod,
                                                        hijriCalendar: hCal, timezone: tz)
                if let plan = FastingNotificationPlanner.dayBefore(tomorrow: tomorrow, tomorrowState: tState,
                                                                    settings: settings.fastingModeSettings,
                                                                    hijriCalendar: hCal, timezone: tz),
                   plan.fireDate > now {
                    await scheduleFasting(at: plan.fireDate, title: plan.title, body: plan.body, identifier: plan.identifier)
                }
            }
        }
    }

    private func scheduleFasting(at date: Date, title: String, body: String, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
```

Use `scheduleFasting` as a private helper name to avoid conflict if the class already has a `schedule(...)` method for prayer notifications. If the existing class already exposes a compatible helper that takes title/body/identifier/fireDate, reuse it instead.

- [ ] **Step 2: Wire to settings observers**

In `IqamahWatch/IqamahWatchApp.swift`, in the `.onAppear` block (around line 33), add:

```swift
WatchNotificationScheduler.shared.requestFastingReschedule()
NotificationCenter.default.addObserver(forName: .settingsDidChange, object: nil, queue: .main) { _ in
    WatchNotificationScheduler.shared.requestFastingReschedule()
}
```

- [ ] **Step 3: Build watch scheme**

```bash
xcodebuild -project iqamah.xcodeproj -scheme "IqamahWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add IqamahWatch/WatchNotificationScheduler.swift IqamahWatch/IqamahWatchApp.swift
git commit -m "feat(watch): extend WatchNotificationScheduler with Fasting Mode reminders

AC-0376, AC-0377, AC-0378, AC-0379 (watchOS). Same 7-day debounced
window as iOS/macOS. Watch displays haptic + banner per existing
notification UX; no custom adhaan-style sounds (watchOS limitation).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 20: Doc registry updates (ENHANCEMENTS + RELEASE_PLAN + TEST_CASES + ID_REGISTRY)

**Files:**
- Modify: `docs/ENHANCEMENTS.md`
- Modify: `docs/RELEASE_PLAN.md`
- Modify: `docs/TEST_CASES.md`
- Modify: `docs/ID_REGISTRY.md`

**Why:** Per CLAUDE.md convention — approved enhancements promote to EPIC + US + AC in `RELEASE_PLAN.md` with 1:1 TC mapping in `TEST_CASES.md`. Also add ENH-022 stub for celebration reminders.

- [ ] **Step 1: Mark ENH-002 ✅ and add ENH-022 stub in ENHANCEMENTS.md**

In `docs/ENHANCEMENTS.md`, replace the existing ENH-002 section (lines around 35-43) with:

```markdown
### ENH-002 — Fasting Mode (Suhoor & Iftar Countdowns + Nawafil Triggers) ✅ Implemented (2026-05-21)
**Status:** ✅ Implemented as EPIC-0017 (US-0071–US-0075 shipped in v1.6). Generalized from Ramadan-only mode to a Fasting Mode covering 9 activation triggers (auto-Ramadan, weekly schedule, Ayyam al-Beed, 6 of Shawwal, Day of Arafah, first 9 of Dhul-Hijjah, Muharram fast, 15 Sha'ban, 27 Rajab). Tradition-aware UI gating driven by isShiaMethod helper; Ja'fari calculation method added alongside Tehran. Spec at `docs/superpowers/specs/2026-05-21-fasting-mode-design.md`.

| Surface | Treatment |
|---|---|
| macOS menu bar | Relabel Fajr→Suhoor / Maghrib→Iftar (🌙 Ramadan, 🕗 Nawafil) within 2h window |
| macOS popover | Banner + relabel |
| iOS hero card | Banner + relabel |
| iOS prayer row | Relabel |
| watchOS prayer tab | Relabel |
| Widgets | Relabel in entries |
| Live Activity | Relabel via ContentState fastingActive/fastingTriggerRaw fields |
```

Locate the celebration-reminder placeholder section (or at the end of the file before the "## Multi-Platform Migration Assessment" header). Insert:

```markdown
### ENH-022 — Islamic Holiday Celebration Reminders
**Source:** Spawned from Fasting Mode brainstorming (2026-05-21) as a sibling concept

**Problem:** Iqamah surfaces fasting practice via Fasting Mode (ENH-002) but does not commemorate non-fasting Islamic holidays. Users miss notifications for Eid al-Fitr, Eid al-Adha, Mawlid an-Nabi, Laylat al-Qadr, Hijri New Year, Ashura commemorations (Shia tradition), Isra wal-Mi'raj, Laylat al-Bara'ah, and Eid al-Ghadir (Shia).

**Solution:** Reuse the FastingModeEngine's Hijri-date evaluation infrastructure to expose celebration notifications. Per-holiday opt-in toggles in Settings. Tradition-aware visibility (some holidays observed primarily in Shia or Sunni tradition).

**Effort:** Medium — engine pattern is established; mainly date data + UI toggles + per-platform notification scheduling.

**Files (when implemented):**
- `Packages/IqamahCore/Sources/IqamahCore/Services/CelebrationCalendar.swift` (new)
- `Packages/IqamahCore/Sources/IqamahCore/Services/SettingsManager.swift` (new celebration toggles)
- Settings UI section (parallel to FastingModeSection)
- Per-platform notification scheduler extensions
```

- [ ] **Step 2: Add EPIC-0017 to RELEASE_PLAN.md**

Locate the end of EPIC-0016 (the ENH-001 finish-up section added in earlier work) in `docs/RELEASE_PLAN.md`. Insert before the existing `**Last Updated:**` footer:

```markdown
## EPIC-0017 — Fasting Mode (ENH-002)

**Status:** 🟡 Planned
**Version Target:** v1.6
**Cross-references:** ENH-002 in `docs/ENHANCEMENTS.md`; spec at `docs/superpowers/specs/2026-05-21-fasting-mode-design.md`; plan at `docs/superpowers/plans/2026-05-21-fasting-mode.md`

**Goal:** Generalize Ramadan Mode into a year-round Fasting Mode covering auto-Ramadan + 7 Nawafil triggers with method-gated visibility, dedicated banner + relabel display across all surfaces, configurable Suhoor/Iftar/day-before notifications, and a new Ja'fari calculation method.

---

### US-0071 — FastingModeEngine + settings schema (IqamahCore foundation)

**Acceptance Criteria:**
- AC-0357: FastingModeSettings struct with 16 default-valued fields; Codable round-trip preserves all; legacy JSON missing fields decodes with defaults
- AC-0358: FastingModeEngine.evaluate is pure-functional and returns FastingDayState
- AC-0359: autoRamadan + weeklySchedule triggers fire correctly
- AC-0360: ayyamAlBeed + sixDaysShawwal triggers
- AC-0361: dayOfArafah + firstNineDhulHijjah with Arafah priority on day 9
- AC-0362: muharramFast tradition-adaptive (Sunni 9+10, Shia 9 only)
- AC-0363: midShaban + mabath suppressed in engine when !isShiaMethod
- AC-0364: Prohibition filter (Eid×2 + Tashriq×3) always wins over triggers

### US-0072 — UI Surfaces (banner + relabel)

**Acceptance Criteria:**
- AC-0365: FastingLabelFormatter relabels Fajr↔Suhoor + Maghrib↔Iftar within 2h window with appropriate glyph
- AC-0366: FastingBanner active-state rendering (Ramadan vs Nawafil tinting)
- AC-0367: FastingBanner prohibition rendering
- AC-0368: macOS menu bar + popover wiring
- AC-0369: iOS hero card + row relabel + watchOS prayer tab relabel
- AC-0370: Live Activity ContentState backward-compatible with v1.5

### US-0073 — Settings UI + tradition-aware gating

**Acceptance Criteria:**
- AC-0371: Master toggle hides sub-controls when off
- AC-0372: Muharram label adaptation + midShaban/mabath visibility driven by isShiaMethod
- AC-0373: Friday-alone + Saturday-alone warnings
- AC-0374: Toggle state persists across method changes
- AC-0375: watchOS Settings shows master toggle + "Configure on iPhone/Mac" hint only

### US-0074 — Notifications + scheduling

**Acceptance Criteria:**
- AC-0376: Suhoor + Iftar reminders with independent lead times (5–120 min)
- AC-0377: Day-before reminder fires for Ramadan day 1 and Nawafil days, skipped for Ramadan days 2–30
- AC-0378: 7-day rolling window with 500ms debounce
- AC-0379: All reminders suppressed for hard-prohibited days
- AC-0380: Permission-denied state shows deep link (iOS + macOS)

### US-0075 — Ja'fari calculation method

**Acceptance Criteria:**
- AC-0381: .jafari case with Fajr 16°, Isha 14°, Maghrib 4° below horizon
- AC-0382: isShiaMethod returns true for .tehran/.jafari, false otherwise; picker includes Ja'fari row

---

**EPIC-0017 Summary:**

| Story | Surfaces | Effort | AC count |
|---|---|---|---|
| US-0071 — Engine + settings | IqamahCore | M | 8 |
| US-0072 — UI surfaces | All | M | 6 |
| US-0073 — Settings UI | iOS+macOS+watchOS | M | 5 |
| US-0074 — Notifications | All | M | 5 |
| US-0075 — Ja'fari method | IqamahCore + UI | S | 2 |

**Total:** 26 acceptance criteria (AC-0357 – AC-0382), mapped 1:1 to TC-0044 – TC-0072 (plus TC-0073 for multi-platform smoke).
**Estimated effort:** 2–3 developer-weeks.
```

Update the `**Last Updated:**` footer:

```markdown
**Last Updated:** 2026-05-21 (EPIC-0017 created — 5 user stories, 26 ACs, generalized Fasting Mode with Ja'fari method)
```

- [ ] **Step 3: Add TC-0044 through TC-0073 to TEST_CASES.md**

In `docs/TEST_CASES.md`, append after the EPIC-0016 test cases (added in earlier work):

```markdown
### EPIC-0017 — Fasting Mode (ENH-002)

#### US-0071 — FastingModeEngine + settings schema

**TC-0044 (AC-0357) — FastingModeSettings round-trip preserves all fields**
Type: Functional · Preconditions: IqamahCore tests building
Steps:
  1. `cd Packages/IqamahCore && swift test --filter FastingModeSettingsCodecTests`
Expected: All 8 codec tests pass (default round-trip, populated round-trip, forward-compat decode, both warning helpers)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0045 (AC-0357) — Forward-compat decode applies defaults for missing fields**
Type: Edge Case
Steps:
  1. Decode legacy JSON that omits midShaban/mabath/dayBeforeMinute
  2. Verify decoded struct has expected default values
Expected: Decoded struct.midShaban == false; struct.mabath == false; struct.dayBeforeMinute == 0
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0046 (AC-0358) — FastingModeEngine.evaluate is pure**
Type: Functional
Steps:
  1. Call evaluate twice with identical input
Expected: Two calls return equal FastingDayState
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0047 (AC-0359) — autoRamadan + weeklySchedule fire correctly**
Type: Functional
Steps:
  1. With autoRamadan=true, evaluate a Ramadan date → trigger should be .autoRamadan
  2. With weeklyDays=[2] (Mon), evaluate a Monday → trigger should be .weeklySchedule
Expected: Both behaviors per spec
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0048 (AC-0360) — Ayyam al-Beed + 6 Shawwal fire correctly**
Type: Functional
Steps:
  1. With ayyamAlBeed=true, evaluate 13/14/15 of a non-Ramadan Hijri month → active
  2. With sixDaysShawwal=true, evaluate 2-7 Shawwal → active; day 8 → inactive
Expected: Both behaviors per spec
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0049 (AC-0361) — Arafah priority over firstNineDhulHijjah on day 9**
Type: Edge Case
Steps:
  1. Set dayOfArafah=true and firstNineDhulHijjah=true
  2. Evaluate 9 Dhul-Hijjah
Expected: state.trigger == .dayOfArafah (Arafah wins)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0050 (AC-0362) — muharramFast Sunni fires on 9+10 Muharram**
Type: Functional
Steps:
  1. With method=.mwl and muharramFast=true, evaluate 9 Muharram → active
  2. Same setup, evaluate 10 Muharram → active
  3. Same setup, evaluate 11 Muharram → inactive
Expected: 9 and 10 active; 11 inactive
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0051 (AC-0362) — muharramFast Shia fires on 9 Muharram only**
Type: Functional
Steps:
  1. With method=.tehran and muharramFast=true, evaluate 9 Muharram → active
  2. Same setup, evaluate 10 Muharram → inactive
Expected: 9 active, 10 inactive
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0052 (AC-0363) — midShaban visible+active for Shia methods**
Type: Functional
Steps:
  1. With method=.tehran and midShaban=true, evaluate 15 Sha'ban
Expected: state.trigger == .midShaban
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0053 (AC-0363) — midShaban suppressed for Sunni methods even when toggle is true**
Type: Functional
Steps:
  1. With method=.mwl and midShaban=true (stored), evaluate 15 Sha'ban
Expected: state.isActive == false (suppressed even though toggle is true)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0054 (AC-0364) — Eid al-Fitr suppresses sixDaysShawwal**
Type: Edge Case
Steps:
  1. With sixDaysShawwal=true, evaluate 1 Shawwal
Expected: state.isActive == false; state.prohibition == .eidAlFitr
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0055 (AC-0364) — Tashriq days 11-13 suppress ayyamAlBeed**
Type: Edge Case
Steps:
  1. With ayyamAlBeed=true, evaluate 11, 12, and 13 Dhul-Hijjah
Expected: All three return prohibition matching the day; isActive=false
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### US-0072 — UI Surfaces

**TC-0056 (AC-0365) — FastingLabelFormatter relabels within 2h, passes through outside**
Type: Functional
Steps:
  1. Active Ramadan state, Fajr 42 min away → "🌙 Suhoor"
  2. Active Ramadan state, Fajr 3 hours away → "Fajr" (passthrough)
  3. Active Nawafil state, Fajr 42 min away → "🕗 Suhoor"
Expected: All three behaviors per spec
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0057 (AC-0366) — FastingBanner renders active state with correct tinting**
Type: Functional · Preconditions: iOS or macOS app with Fasting Mode enabled
Steps:
  1. Trigger an active autoRamadan day; view PrayerHeroCard
  2. Trigger an active weeklySchedule day; view PrayerHeroCard
Expected: Ramadan day shows 🌙 + purple gradient; Nawafil day shows 🕗 + teal gradient
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0058 (AC-0367) — FastingBanner renders prohibition state in grey**
Type: Functional
Steps:
  1. Trigger a prohibition-day evaluation (Eid)
Expected: Banner shows ⚠️ + grey gradient + "Fasting is forbidden today" text
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0059 (AC-0368) — macOS menu bar relabel + popover banner**
Type: Functional · Preconditions: macOS app with Fasting Mode enabled, today is a fasting day
Steps:
  1. Verify menu bar shows "🌙 Suhoor" or "🕗 Suhoor" relabel when within 2h of Fajr
  2. Open popover; verify FastingBanner renders above prayer list
Expected: Relabel visible in menu bar; banner visible in popover
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0060 (AC-0369) — iOS hero banner + iOS row relabel + watch row relabel**
Type: Functional
Steps:
  1. iOS: verify FastingBanner above PrayerHeroCard on a fasting day
  2. iOS: verify PrayerRowMobileView shows relabel within 2h window
  3. watchOS: verify PrayerTimesTab row shows relabel within 2h window
Expected: All three surfaces behave correctly
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0061 (AC-0370) — Live Activity ContentState backward decode**
Type: Regression
Steps:
  1. Start a Live Activity on v1.5 ContentState (no fasting fields)
  2. Upgrade to v1.6
  3. Verify the in-flight activity does not crash; new fastingActive == nil
Expected: No crash; relabel does not apply (defaults to standard countdown)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### US-0073 — Settings UI

**TC-0062 (AC-0371) — Master toggle hides sub-controls when off**
Type: Functional
Steps:
  1. Open Settings → Fasting Mode section
  2. Toggle master OFF
Expected: All sub-controls disappear; only the master toggle remains visible
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0063 (AC-0372) — Tradition gating + Muharram label adaptation**
Type: Functional
Steps:
  1. Switch to Tehran method → Settings shows "Tasu'a (9 Muharram)" + Shia subtitle; 15 Sha'ban + 27 Rajab toggles appear
  2. Switch to MWL → label changes to "Ashura (9+10 Muharram)" + Sunni subtitle; Shia toggles disappear
Expected: Both adaptations per spec
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0064 (AC-0373) — Friday-alone + Saturday-alone warnings**
Type: Functional
Steps:
  1. Select only Friday in weekly picker → warning appears
  2. Add Thursday → warning clears
  3. Remove Thursday, add Saturday → warning clears
  4. Select only Saturday → Saturday-alone warning appears
  5. Add Friday → warning clears
Expected: All warning transitions per spec
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0065 (AC-0374) — Toggle persistence across method changes**
Type: Regression
Steps:
  1. With Tehran method, enable midShaban
  2. Switch to MWL → midShaban toggle hidden
  3. Inspect SettingsManager.fastingModeSettings.midShaban → still true
  4. Switch back to Tehran → midShaban toggle reappears, still on
Expected: Stored value preserved through method swap
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0066 (AC-0375) — watch Settings minimal UI**
Type: Functional
Steps:
  1. Open IqamahWatch Settings tab
Expected: Fasting Mode section shows master toggle + "Configure on iPhone/Mac" hint only; no sub-controls
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### US-0074 — Notifications

**TC-0067 (AC-0376) — Suhoor + Iftar lead-time arithmetic + range**
Type: Functional
Steps:
  1. Set suhoorLeadMinutes=30, schedule for Fajr=05:12 → notification fires at 04:42
  2. Set suhoorLeadMinutes=120 → notification fires at 03:12
  3. Set iftarLeadMinutes=15, Maghrib=20:32 → notification fires at 20:17
Expected: Fire dates match arithmetic
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0068 (AC-0377) — Day-before logic per Ramadan/Nawafil/prohibition**
Type: Functional
Steps:
  1. Tomorrow is 1 Ramadan → plan != nil
  2. Tomorrow is 2 Ramadan → plan == nil (skipped)
  3. Tomorrow is a scheduled Nawafil Monday → plan != nil
  4. Tomorrow is Eid → plan == nil
Expected: All four cases per spec
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0069 (AC-0378) — 7-day rolling window + 500ms debounce**
Type: Functional
Steps:
  1. Enable Fasting Mode + weekly = [2,5]
  2. Rapidly toggle additional weekdays (5 changes in 1 second)
  3. Wait 1 second
  4. Inspect pending notifications
Expected: Notifications reflect final state only (one reschedule occurred, not 5)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0070 (AC-0380) — Permission-denied deep link UI**
Type: Negative · Preconditions: Notifications denied in System Settings
Steps:
  1. Open Settings → Fasting Mode → Send system notifications row
  2. Tap "Enable in System Settings" link
Expected: Deep link opens Notifications preferences on the appropriate platform (iOS: Iqamah notification settings; macOS: System Settings Notifications pane)
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### US-0075 — Ja'fari calculation method

**TC-0071 (AC-0381) — Ja'fari Maghrib timing matches reference**
Type: Functional
Steps:
  1. With method=.jafari, compute prayer times for Toronto on 2026-06-21 (summer solstice)
  2. Compare Maghrib to PrayTimes.org Ja'fari reference output for same coordinates/date
Expected: Maghrib time within ±1 minute of reference
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

**TC-0072 (AC-0382) — isShiaMethod returns expected for all 7 methods**
Type: Functional
Steps:
  1. `cd Packages/IqamahCore && swift test --filter CalculationMethodJafariTests`
Expected: All Jafari tests pass — only .tehran and .jafari return true; all other methods return false
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:

#### Multi-platform smoke

**TC-0073 — All schemes build clean after Fasting Mode merge**
Type: Regression
Steps:
  1. `cd Packages/IqamahCore && swift test`
  2. `xcodebuild -project iqamah.xcodeproj -scheme iqamah build`
  3. `xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`
  4. `xcodebuild -project iqamah.xcodeproj -scheme "IqamahWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build`
  5. `xcodebuild -project iqamah.xcodeproj -scheme IqamahLiveActivity -destination 'platform=iOS Simulator,name=iPhone 17' build`
  6. `xcodebuild -project iqamah.xcodeproj -scheme IqamahWidget -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: All commands succeed with BUILD SUCCEEDED / Test Suite passed
Status: [ ] Not Run / [ ] Pass / [ ] Fail · Defect: None · Notes:
```

Update the registry header:

```markdown
**Total Test Cases:** 73
**Status:** 🟡 EPIC-0010, EPIC-0016, and EPIC-0017 covered (TC-0001 through TC-0073); EPIC-0001 through EPIC-0009 and EPIC-0011 through EPIC-0015 still pending TC backfill
```

Add to the "Test Cases by Type" lists:
- Functional Tests: append `, 0044, 0046, 0047, 0048, 0050, 0051, 0052, 0053, 0056, 0057, 0058, 0059, 0060, 0062, 0063, 0064, 0066, 0067, 0068, 0069, 0071, 0072`
- Regression Tests: append `, 0061, 0065, 0073`
- Edge Case Tests: append `, 0045, 0049, 0054, 0055`
- Negative Tests: append `, 0070`

Update the footer:
```markdown
**Last Updated:** 2026-05-21 (TC-0044 through TC-0073 added covering EPIC-0017 / US-0071–US-0075 acceptance criteria)
```

- [ ] **Step 4: Bump ID_REGISTRY counters**

In `docs/ID_REGISTRY.md`, update the table rows:

```markdown
| EPIC         | EPIC-0018             | EPIC-0017         |
| US           | US-0076               | US-0075           |
| AC           | AC-0383               | AC-0382           |
| TC           | TC-0074               | TC-0073           |
| ENH          | ENH-023               | ENH-022           |
```

Update the footer:
```markdown
**Last Updated:** 2026-05-21 (EPIC-0017 created — Fasting Mode; US-0071–US-0075, AC-0357–AC-0382, TC-0044–TC-0073 consumed; ENH-022 stub for celebration reminders added.)
```

- [ ] **Step 5: Commit**

```bash
git add docs/ENHANCEMENTS.md docs/RELEASE_PLAN.md docs/TEST_CASES.md docs/ID_REGISTRY.md
git commit -m "docs: promote ENH-002 Fasting Mode to EPIC-0017 + TC-0044-0073

Per CLAUDE.md convention. ENH-002 marked ✅ Implemented with surface
table. ENH-022 stub added for sibling celebration reminders feature.
EPIC-0017 with 5 user stories + 26 ACs in RELEASE_PLAN.md. 30 TCs
in TEST_CASES.md (one per AC plus multi-platform smoke). ID_REGISTRY
counters bumped.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 21: Final verification — multi-platform build + tests + PR

**Files:** None directly — verification + PR creation only.

- [ ] **Step 1: Run all IqamahCore tests**

```bash
cd Packages/IqamahCore && swift test 2>&1 | tail -15
```

Expected: all existing tests (185+) plus all new Fasting Mode tests (~40) pass.

- [ ] **Step 2: Build every scheme**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug build 2>&1 | tail -3
xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -3
xcodebuild -project iqamah.xcodeproj -scheme "IqamahWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -3
xcodebuild -project iqamah.xcodeproj -scheme IqamahLiveActivity -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -3
xcodebuild -project iqamah.xcodeproj -scheme IqamahWidget -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -3
```

Expected: five `BUILD SUCCEEDED` lines.

- [ ] **Step 3: Manual smoke — macOS**

Launch macOS app. Open Settings → Fasting Mode. Toggle master on. Toggle weekly Monday on. Verify:
1. Menu bar relabels when within 2 hours of Fajr or Maghrib on a Monday
2. Popover shows banner above the prayer list on a Monday
3. Switching to Tehran method shows Tasu'a label + 15 Sha'ban + 27 Rajab toggles

- [ ] **Step 4: Manual smoke — iOS**

Launch iOS app on iPhone 17 simulator. Same checks as macOS plus:
1. Hero card shows banner on a fasting day
2. Prayer row shows relabel within 2-hour window
3. Live Activity (if started near a prayer time) shows relabel

- [ ] **Step 5: Manual smoke — watch**

Launch IqamahWatch on Apple Watch Series 11 simulator:
1. Prayer Times tab shows row relabel within window
2. Settings tab shows minimal Fasting Mode section

- [ ] **Step 6: Push branch + open PR**

```bash
git push -u origin claude/vigilant-mccarthy-5435c6
gh pr create --title "Fasting Mode (EPIC-0017): engine + UI + notifications + Ja'fari method" --body "$(cat <<'EOF'
## Summary

- Generalized ENH-002 from Ramadan Mode to Fasting Mode
- 9 activation triggers: auto-Ramadan, weekly schedule, Ayyam al-Beed, 6 of Shawwal, Day of Arafah, first 9 of Dhul-Hijjah, Muharram fast, 15 Sha'ban, 27 Rajab
- 5 hard-prohibited days (Eid×2 + Tashriq×3) with runtime suppression
- Cross-surface display per Option D hybrid: relabel on narrow (menu bar, watch, widgets, Live Activity), banner on wide (iOS hero, macOS popover)
- Configurable Suhoor + Iftar lead times (5–120 min independent) + day-before reminders with Ramadan-day-2-30 skip
- New Ja'fari calculation method (Fajr 16°, Isha 14°, Maghrib 4° below horizon) + isShiaMethod helper drives tradition-aware UI gating
- Pure-functional FastingModeEngine in IqamahCore with full test coverage

Spec: `docs/superpowers/specs/2026-05-21-fasting-mode-design.md`
Plan: `docs/superpowers/plans/2026-05-21-fasting-mode.md`
ACs: AC-0357 — AC-0382 (26 ACs)
TCs: TC-0044 — TC-0073 (30 TCs)

## Test plan

- [ ] `swift test` in `Packages/IqamahCore` — all tests pass (~225 total)
- [ ] `xcodebuild` clean for all 5 schemes (iqamah, iqamah-iOS, IqamahWatch Watch App, IqamahLiveActivity, IqamahWidget)
- [ ] macOS smoke: menu bar relabel + popover banner + Settings tradition gating
- [ ] iOS smoke: hero banner + row relabel + Live Activity backward compat
- [ ] watch smoke: row relabel + minimal Settings entry
- [ ] Notification smoke: enable Fasting Mode + weekly Monday; verify Suhoor + Iftar + day-before reminders schedule within 1s of settings change

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL returned. Share it back to the user.

---


|---|---|---|
| AC-0357 (settings codec) | Task 3 | TC-0044, TC-0045 |
| AC-0358 (engine purity) | Task 4 | TC-0046 |
| AC-0359 (autoRamadan + weekly) | Task 4 | TC-0047 |
| AC-0360 (Ayyam + 6 Shawwal) | Task 5 | TC-0048 |
| AC-0361 (Arafah priority) | Task 5 | TC-0049 |
| AC-0362 (muharramFast adaptive) | Task 6 | TC-0050, TC-0051 |
| AC-0363 (Shia-gated triggers) | Task 7 | TC-0052, TC-0053 |
| AC-0364 (prohibition filter) | Task 7 | TC-0054, TC-0055 |
| AC-0365 (label formatter) | Task 8 | TC-0056 |
| AC-0366 (banner active) | Task 10 | TC-0057 |
| AC-0367 (banner prohibition) | Task 10 | TC-0058 |
| AC-0368 (macOS surfaces) | Task 11 | TC-0059 |
| AC-0369 (iOS + watch surfaces) | Tasks 12, 13 | TC-0060 |
| AC-0370 (Live Activity migration) | Task 14 | TC-0061 |
| AC-0371 (Settings master) | Task 15 | TC-0062 |
| AC-0372 (tradition gating + label) | Task 15 | TC-0063 |
| AC-0373 (warnings) | Task 15 | TC-0064 |
| AC-0374 (toggle persistence) | Tasks 3, 15 | TC-0065 |
| AC-0375 (watch Settings minimal) | Task 16 | TC-0066 |
| AC-0376 (Suhoor/Iftar reminders) | Tasks 9, 17, 18, 19 | TC-0067 |
| AC-0377 (day-before logic) | Task 9 | TC-0068 |
| AC-0378 (rolling window + debounce) | Tasks 17, 18, 19 | TC-0069 |
| AC-0379 (prohibition suppression of notifs) | Task 9 (via planner returns nil) | TC-0054/TC-0055 |
| AC-0380 (permission deep links) | Tasks 17, 18 | TC-0070 |
| AC-0381 (Ja'fari method) | Task 1 | TC-0071 |
| AC-0382 (isShiaMethod helper + picker) | Task 1 | TC-0072 |
| Registry promotion | Task 20 | — |
| Final verification + smoke | Task 21 | TC-0073 |
