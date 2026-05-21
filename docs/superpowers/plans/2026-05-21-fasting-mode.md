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

## Task 10 onwards (UI surfaces, notification schedulers, docs)

Tasks 10–21 cover UI rendering, per-platform notification scheduling, and registry promotion. Each task is structured the same as Tasks 1–9: TDD where applicable, exact file paths and code, and one commit per task. Due to the breadth of platform-specific surface code, **these tasks will be added incrementally during execution** rather than fully pre-specified — the engine + helpers built in Tasks 1–9 provide the stable API contract that downstream UI work consumes, and the SwiftUI surface code is best validated against a running simulator as it's written.

The remaining task headings are reserved as follows; each will be expanded to the same TDD step structure before that task is started:

### Task 10: `FastingBanner` shared SwiftUI view (iOS+macOS)
Render the dual-countdown banner. Purple+🌙 for Ramadan; teal+🕗 for Nawafil; grey+⚠️ for prohibition. New file at `iqamah/Views/Shared/FastingBanner.swift` with multi-target membership in `iqamah.xcodeproj/project.pbxproj`.

### Task 11: macOS menu bar + popover wiring
Modify `iqamah/AppDelegate.swift:136` (`updateStatusBarDisplay`) to consult engine + apply relabel. Modify `iqamah/Views/MenuBarPopoverView.swift` to render `FastingBanner` above the prayer list.

### Task 12: iOS hero card + row relabel
Modify `iqamah/iOS/PrayerHeroCard.swift` to render `FastingBanner` above next-prayer block. Modify `iqamah/iOS/PrayerRowMobileView.swift` to apply relabel within 2h window.

### Task 13: watchOS prayer tab relabel
Modify `IqamahWatch/PrayerTimesTab.swift:48` to apply relabel. No banner on watch.

### Task 14: Widgets + Live Activity wiring
Modify `IqamahWidget/IqamahWidget.swift` provider to include Fasting Mode state in TimelineEntry; views call FastingLabelFormatter. Modify `IqamahLiveActivity/PrayerActivityAttributes.swift` to add optional `fastingActive: Bool?` and `fastingTriggerRaw: String?` to ContentState with default-nil. Modify `IqamahLiveActivity/PrayerLiveActivityView.swift` to apply relabel.

### Task 15: `FastingModeSection` settings UI
New shared view at `iqamah/Views/Shared/FastingModeSection.swift`. Master toggle hides sub-controls when off. Weekday picker pills + warnings. Tradition-aware row visibility (`midShaban`/`mabath`) and Muharram label adaptation.

### Task 16: watchOS SettingsTab entry
Add a minimal "Fasting Mode" row + navigation link to `IqamahWatch/SettingsTab.swift`. Detail screen shows master toggle only with "Configure on iPhone/Mac" link.

### Task 17: macOS `FastingNotificationScheduler` + debounce
New file `iqamah/FastingNotificationScheduler.swift`. Wraps `UNUserNotificationCenter`. Implements 7-day rolling window with 500ms debounce via `DispatchWorkItem` cancellation pattern.

### Task 18: iOS notification scheduler extension
Extend `iqamah/iOS/NotificationScheduler.swift` with `scheduleFastingReminders(...)` consuming `FastingNotificationPlanner`. Same 500ms debounce.

### Task 19: watchOS notification scheduler extension
Extend `IqamahWatch/WatchNotificationScheduler.swift` similarly.

### Task 20: Doc registry updates

- Mark ENH-002 ✅ in `docs/ENHANCEMENTS.md` (with surface-by-surface table)
- Add ENH-022 stub for "Islamic Holiday Celebration Reminders" to `docs/ENHANCEMENTS.md`
- Add EPIC-0017 + US-0071–US-0075 + AC-0357–AC-0382 to `docs/RELEASE_PLAN.md`
- Add TC-0044 through TC-0073 to `docs/TEST_CASES.md`
- Bump counters in `docs/ID_REGISTRY.md`: EPIC→0018, US→0076, AC→0383, TC→0074, ENH→0023

### Task 21: Final verification

- `cd Packages/IqamahCore && swift test` — all tests pass
- Build `iqamah`, `iqamah-iOS`, `IqamahWatch Watch App`, `IqamahLiveActivity`, `IqamahWidget` schemes
- Manual smoke on simulators
- Open PR to `develop`

---

## Spec coverage check

| Spec AC | Implemented in | TC |
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
