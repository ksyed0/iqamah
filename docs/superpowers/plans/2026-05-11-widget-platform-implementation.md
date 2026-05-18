# Widget Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Live Activity / Dynamic Island (US-0058), four new iOS widget families (US-0059), and macOS Notification Center widget (US-0060) sharing IqamahCore infrastructure.

**Architecture:** New `IqamahLiveActivity` ActivityKit target for Dynamic Island; existing `IqamahWidget` target extended with new widget families and macOS platform; two new `moonPhase(for:)` and `hijriDateString(for:offset:)` helpers added to IqamahCore shared by both.

**Tech Stack:** Swift 5.10, SwiftUI, ActivityKit (iOS 16.2+), WidgetKit (iOS 17 / macOS 14), IqamahCore local Swift Package, Xcode project.pbxproj (Python editing).

---

## File Map

### New files — IqamahCore
| File | Purpose |
|------|---------|
| `Packages/IqamahCore/Sources/IqamahCore/Astronomy/MoonHijriHelpers.swift` | `moonPhase(for:)` + `hijriDateString(for:offset:)` public helpers |
| `Packages/IqamahCore/Tests/IqamahCoreTests/MoonHijriTests.swift` | Unit tests for the two helpers |

### New files — IqamahWidget (new widget views)
| File | Purpose |
|------|---------|
| `IqamahWidget/LargeWidgetView.swift` | `.systemLarge` — full prayer schedule, gold highlight |
| _ExtraLargeWidgetView_ | **Not a separate file** — `.systemExtraLarge` reuses `LargeWidgetView` unchanged; SwiftUI adapts geometry automatically |
| `IqamahWidget/CircularWidgetView.swift` | `.accessoryCircular` — arc + initial + countdown |
| `IqamahWidget/InlineWidgetView.swift` | `.accessoryInline` — `"🕐 Asr at 3:42 PM"` text |
| `IqamahWidget/macOSLargeWidgetView.swift` | macOS-specific full schedule view |

### New files — IqamahLiveActivity (new Xcode target)
| File | Purpose |
|------|---------|
| `IqamahLiveActivity/PrayerActivityAttributes.swift` | `ActivityAttributes` conforming type + `ContentState` |
| `IqamahLiveActivity/PrayerLiveActivityView.swift` | All four DI presentations (compact/expanded/lock screen/minimal) |
| `IqamahLiveActivity/Info.plist` | `NSSupportsLiveActivities = YES` |
| `IqamahLiveActivity/IqamahLiveActivity.entitlements` | App Group entitlement |

### New files — iOS app
| File | Purpose |
|------|---------|
| `iqamah/iOS/PrayerActivityManager.swift` | Manages `Activity<PrayerActivityAttributes>` lifecycle |

### Modified files
| File | Change |
|------|--------|
| `IqamahWidget/IqamahWidget.swift` | Add new family cases; add macOS platform guard; add `.macOS` to `supportedFamilies` |
| `Packages/IqamahCore/Sources/IqamahCore/Services/SettingsManager.swift` | Add `liveActivityEnabled: Bool` @Published property + Keys entry + KVS sync |
| `iqamah/iOS/iqamahApp_iOS.swift` | Wire `PrayerActivityManager` on active + `liveActivityEnabled` onChange |
| `iqamah.xcodeproj/project.pbxproj` | Add `IqamahLiveActivity` target; register new widget + activity files |
| `iqamah.xcodeproj/xcshareddata/xcschemes/IqamahLiveActivity.xcscheme` | New scheme |

---

## Task 1 — IqamahCore helpers (TDD)

**Files:**
- Create: `Packages/IqamahCore/Sources/IqamahCore/Astronomy/MoonHijriHelpers.swift`
- Create: `Packages/IqamahCore/Tests/IqamahCoreTests/MoonHijriTests.swift`

- [ ] **Step 1: Write failing tests first**

Create `Packages/IqamahCore/Tests/IqamahCoreTests/MoonHijriTests.swift`:

```swift
import Foundation
import IqamahCore
import Testing

@Suite("Moon + Hijri helpers")
struct MoonHijriTests {

    @Test("moonPhase returns value in [0, 1]")
    func moonPhaseRange() {
        let phase = moonPhase(for: Date())
        #expect(phase >= 0.0 && phase <= 1.0)
    }

    @Test("moonPhase near known full moon is approximately 0.5")
    func moonPhaseFull() {
        // 2024-Feb-24 was a full moon (JD 2460365.1)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let fullMoonDate = formatter.date(from: "2024-02-24")!
        let phase = moonPhase(for: fullMoonDate)
        // Full moon ≈ 0.5; allow ±0.06 (±1.8 days) for approximation
        #expect(abs(phase - 0.5) < 0.06, "Expected ~0.5 but got \(phase)")
    }

    @Test("hijriDateString returns non-empty string")
    func hijriNonEmpty() {
        let s = hijriDateString(for: Date(), offset: 0)
        #expect(!s.isEmpty)
    }

    @Test("hijriDateString format matches pattern: digit(s) Month year")
    func hijriFormat() {
        // 2026-05-11 Gregorian ≈ 13 Dhu al-Qi'dah 1447 AH
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let date = formatter.date(from: "2026-05-11")!
        let s = hijriDateString(for: date, offset: 0)
        // Should contain a number, a space, and a month name
        #expect(s.contains("1447"), "Expected year 1447 in \(s)")
        #expect(s.first?.isNumber == true, "Should start with day number")
    }

    @Test("hijriDateString offset shifts displayed day")
    func hijriOffset() {
        let date = Date()
        let base   = hijriDateString(for: date, offset: 0)
        let plus1  = hijriDateString(for: date, offset: 1)
        #expect(base != plus1, "Offset should change the displayed date")
    }
}
```

- [ ] **Step 2: Run tests — confirm they fail**

```bash
cd Packages/IqamahCore && swift test --filter MoonHijriTests 2>&1 | tail -5
```
Expected: compile error — `moonPhase` and `hijriDateString` not defined.

- [ ] **Step 3: Implement the helpers**

Create `Packages/IqamahCore/Sources/IqamahCore/Astronomy/MoonHijriHelpers.swift`:

```swift
import Foundation

// MARK: - Moon phase

/// Synodic phase fraction: 0.0 = new moon, 0.5 = full moon, 1.0 = new moon again.
/// Uses the last new moon computed by NewMoon.previous(before:) as the reference epoch.
public func moonPhase(for date: Date) -> Double {
    let previousNewMoon = NewMoon.previous(before: date)
    let elapsed = date.timeIntervalSince(previousNewMoon)
    let synodicMonth = 29.530588853 * 86400.0
    return (elapsed / synodicMonth).truncatingRemainder(dividingBy: 1.0)
}

// MARK: - Hijri date string

/// Returns a formatted Hijri date string, e.g. "9 Dhu al-Hijjah 1447".
/// The `offset` parameter shifts the displayed day (positive = later, negative = earlier)
/// without affecting the underlying astronomical calculations — matches SettingsManager.hijriDayOffset.
public func hijriDateString(for date: Date, offset: Int = 0) -> String {
    let cal = Calendar(identifier: .islamicUmmAlQura)
    var comps = cal.dateComponents([.day, .month, .year], from: date)
    comps.day = (comps.day ?? 1) + offset

    let monthNames = [
        "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
        "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
        "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah",
    ]
    let monthIndex = (comps.month ?? 1) - 1
    let monthName = monthIndex >= 0 && monthIndex < 12 ? monthNames[monthIndex] : ""
    return "\(comps.day ?? 1) \(monthName) \(comps.year ?? 1446)"
}
```

- [ ] **Step 4: Run tests — confirm they pass**

```bash
cd Packages/IqamahCore && swift test --filter MoonHijriTests 2>&1 | tail -5
```
Expected: `✔ Test run with 5 tests in 1 suite passed`

- [ ] **Step 5: Full suite still green**

```bash
swift test 2>&1 | tail -3
```
Expected: all tests pass (count ≥ 178).

- [ ] **Step 6: Commit**

```bash
cd /path/to/worktree
git add Packages/IqamahCore/
git commit -m "feat: add moonPhase(for:) + hijriDateString(for:offset:) to IqamahCore (TDD)"
```

---

## Task 2 — SettingsManager: liveActivityEnabled

**Files:**
- Modify: `Packages/IqamahCore/Sources/IqamahCore/Services/SettingsManager.swift`

- [ ] **Step 1: Add the key constant**

Read the file, find the `private enum Keys` block. Add after `hilalNotificationEnabled`:

```swift
static let liveActivityEnabled = "liveActivityEnabled"
```

- [ ] **Step 2: Add to kvsKeys set**

Find `private static let kvsKeys: Set<String>`. Add:

```swift
Keys.liveActivityEnabled,
```

- [ ] **Step 3: Add the @Published property**

Find `@Published public var hilalNotificationEnabled: Bool {` and add after it:

```swift
/// Controls whether the Live Activity / Dynamic Island is active.
/// Independent of `hilalNotificationEnabled` — users may want one without the other.
@Published public var liveActivityEnabled: Bool {
    didSet {
        defaults.set(liveActivityEnabled, forKey: Keys.liveActivityEnabled)
        guard !isApplyingRemote else { return }
        kvs.set(liveActivityEnabled, forKey: Keys.liveActivityEnabled)
    }
}
```

- [ ] **Step 4: Load in init(userDefaults:)**

Find the `hilalNotificationEnabled = userDefaults.bool(forKey: Keys.hilalNotificationEnabled)` line in `init`. Add directly after:

```swift
liveActivityEnabled = userDefaults.bool(forKey: Keys.liveActivityEnabled)
```

- [ ] **Step 5: Handle remote KVS change**

Find `case Keys.hilalNotificationEnabled:` in `applyRemoteValue(forKey:)`. Add after it:

```swift
case Keys.liveActivityEnabled:
    liveActivityEnabled = kvs.bool(forKey: key)
```

- [ ] **Step 6: Build IqamahCore, run tests**

```bash
cd Packages/IqamahCore && swift build 2>&1 | grep -E "error:|Build complete"
swift test 2>&1 | tail -3
```
Expected: Build complete; all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Packages/IqamahCore/
git commit -m "feat: add liveActivityEnabled to SettingsManager (KVS-synced, independent of notification toggle)"
```

---

## Task 3 — iOS Widget: new families

> ⚠️ **Ordering:** Execute Steps 5–6 (extend `PrayerEntry` + update provider) BEFORE Steps 1–4 (create view files). Views reference new `PrayerEntry` fields.

**Files:**
- Create: `IqamahWidget/LargeWidgetView.swift`
- Create: `IqamahWidget/CircularWidgetView.swift`
- Create: `IqamahWidget/InlineWidgetView.swift`
- Create: `IqamahWidget/macOSLargeWidgetView.swift`
- Modify: `IqamahWidget/IqamahWidget.swift`

- [ ] **Step 1: Create LargeWidgetView.swift**

```swift
import IqamahCore
import SwiftUI
import WidgetKit

/// Full today prayer schedule — all 5 prayers, past dimmed, next gold pill.
struct LargeWidgetView: View {
    let entry: PrayerEntry

    private let gold = Color(red: 1.0, green: 0.839, blue: 0.039)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("IQAMAH")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text(entry.nextPrayerTime, style: .relative)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(gold)
            }
            .padding(.bottom, 8)

            Divider().padding(.bottom, 8)

            // Prayer list
            ForEach(entry.todaysPrayers, id: \.name) { prayer in
                let isNext = prayer.name == entry.nextPrayerName
                let isPast = prayer.time < Date()
                HStack {
                    Text(prayer.name)
                        .font(.system(size: 14, weight: isNext ? .bold : .regular))
                        .foregroundStyle(isNext ? gold : .primary)
                    Spacer()
                    Text(prayer.time, style: .time)
                        .font(.system(size: 14, weight: isNext ? .bold : .regular).monospacedDigit())
                        .foregroundStyle(isNext ? gold : .primary)
                }
                .padding(.horizontal, isNext ? 6 : 0)
                .padding(.vertical, 4)
                .background(isNext ? gold.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .opacity(isPast ? 0.30 : 1.0)
            }

            Spacer()

            // Hijri footer
            Text(entry.hijriDateString)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

Note: `entry.todaysPrayers` and `entry.hijriDateString` are added to `PrayerEntry` in Step 5 below.

- [ ] **Step 2: Create CircularWidgetView.swift**

```swift
import IqamahCore
import SwiftUI
import WidgetKit

/// Progress arc + prayer initial + relative countdown.
struct CircularWidgetView: View {
    let entry: PrayerEntry

    private let gold = Color(red: 1.0, green: 0.839, blue: 0.039)

    var body: some View {
        ZStack {
            ProgressView(value: dayProgress)
                .progressViewStyle(.circular)
                .tint(gold)
            VStack(spacing: 0) {
                Text(String(entry.nextPrayerName.prefix(1)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(gold)
                Text(entry.nextPrayerTime, style: .timer)
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.7)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var dayProgress: Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: entry.date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let total = end.timeIntervalSince(start)
        let elapsed = entry.nextPrayerTime.timeIntervalSince(start)
        return min(max(elapsed / total, 0), 1)
    }
}
```

- [ ] **Step 3: Create InlineWidgetView.swift**

```swift
import IqamahCore
import SwiftUI
import WidgetKit

/// Single text line: "🕐 Asr at 3:42 PM"
struct InlineWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        Label {
            Text("\(entry.nextPrayerName) at \(entry.nextPrayerTime.formatted(.dateTime.hour().minute()))")
        } icon: {
            Image(systemName: "clock")
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

- [ ] **Step 4: Create macOSLargeWidgetView.swift**

```swift
#if os(macOS)
import IqamahCore
import SwiftUI
import WidgetKit

/// macOS Notification Center large widget — full prayer schedule.
struct macOSLargeWidgetView: View {
    let entry: PrayerEntry

    private let gold = Color(red: 1.0, green: 0.839, blue: 0.039)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Hijri date and countdown
            HStack(alignment: .firstTextBaseline) {
                Text("IQAMAH · \(entry.hijriDateString.uppercased())")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.4)
                    .lineLimit(1)
                Spacer()
                Text(entry.nextPrayerTime, style: .relative)
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(gold)
            }
            .padding(.bottom, 8)

            Divider().padding(.bottom, 8)

            ForEach(entry.todaysPrayers, id: \.name) { prayer in
                let isNext = prayer.name == entry.nextPrayerName
                let isPast = prayer.time < Date()
                HStack {
                    if isNext {
                        Circle()
                            .fill(gold)
                            .frame(width: 5, height: 5)
                    }
                    Text(prayer.name)
                        .font(.system(size: 13, weight: isNext ? .bold : .regular))
                        .foregroundStyle(isNext ? gold : .primary)
                    Spacer()
                    Text(prayer.time, style: .time)
                        .font(.system(size: 13, weight: isNext ? .bold : .regular).monospacedDigit())
                        .foregroundStyle(isNext ? gold : .primary)
                }
                .padding(.vertical, 4)
                .opacity(isPast ? 0.28 : 1.0)
            }

            Divider().padding(.top, 8).padding(.bottom, 6)

            Text(entry.cityName + " · " + entry.methodName)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
#endif
```

- [ ] **Step 5: Extend PrayerEntry with new fields**

Read `IqamahWidget/IqamahWidget.swift`. Add two new computed properties to `PrayerEntry`:

```swift
struct PrayerEntry: TimelineEntry {
    let date: Date
    let nextPrayerName: String
    let nextPrayerTime: Date
    let cityName: String
    let methodName: String      // ← add this (was missing)
    let methodName: String         // ← add; default "" in stubs
    let todaysPrayers: [(name: String, time: Date)]  // ← add; default [] in stubs
    let hijriDateString: String    // ← add; default "" in stubs

    /// Formatted relative countdown, e.g. "2h 14m"
    var countdown: String {
        let interval = nextPrayerTime.timeIntervalSince(date)
        guard interval > 0 else { return "Now" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
```

Update `PrayerTimelineProvider.placeholder(in:)` to supply the new fields:

```swift
func placeholder(in context: Context) -> PrayerEntry {
    PrayerEntry(
        date: Date(),
        nextPrayerName: "Dhuhr",
        nextPrayerTime: Date().addingTimeInterval(3600),
        cityName: "Makkah",
        methodName: "MWL",
        todaysPrayers: [
            ("Fajr",    Date().addingTimeInterval(-7200)),
            ("Dhuhr",   Date().addingTimeInterval(3600)),
            ("Asr",     Date().addingTimeInterval(10800)),
            ("Maghrib", Date().addingTimeInterval(18000)),
            ("Isha",    Date().addingTimeInterval(25200)),
        ],
        hijriDateString: "9 Dhu al-Hijjah 1447"
    )
}
```

Update `buildEntries(from:)` to populate the new fields:

```swift
private func buildEntries(from now: Date) -> [PrayerEntry] {
    let settings = SettingsManager(userDefaults: defaults)
    guard let coord = settings.activeCoordinate,
          let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier)
    else { return [placeholder(in: .init())] }

    let calc = PrayerCalculator(
        coordinate: coord, timezone: timezone,
        method: settings.calculationMethod, asrMethod: settings.asrMethod
    )
    let cityName = settings.activeCityName.isEmpty ? "—" : settings.activeCityName
    let methodName = settings.calculationMethod.shortName
    let phase = moonPhase(for: now)
    let hijri = hijriDateString(for: now, offset: settings.hijriDayOffset)

    // Today's full prayer list (for large widget)
    let todaysPrayers: [(name: String, time: Date)]
    if let times = try? calc.calculate(for: now) {
        todaysPrayers = times.prayers.filter { $0.name != "Sunrise" }
    } else {
        todaysPrayers = []
    }

    var entries: [PrayerEntry] = []
    var cursor = now

    for dayOffset in 0 ... 1 {
        guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now),
              let times = try? calc.calculate(for: day)
        else { continue }

        for prayer in times.prayers where prayer.name != "Sunrise" && prayer.time > cursor {
            entries.append(PrayerEntry(
                date: cursor,
                nextPrayerName: prayer.name,
                nextPrayerTime: prayer.time,
                cityName: cityName,
                methodName: methodName,
                todaysPrayers: todaysPrayers,
                hijriDateString: hijri
            ))
            cursor = prayer.time
        }
    }
    return entries.isEmpty ? [placeholder(in: .init())] : entries
}
```

- [ ] **Step 6: Update IqamahWidgetView switch + supportedFamilies**

In `IqamahWidget.swift`, replace the switch body and supportedFamilies:

```swift
var body: some View {
    switch family {
    case .systemSmall:
        smallView
    case .systemMedium:
        mediumView
    case .systemLarge:
        LargeWidgetView(entry: entry)
    case .systemExtraLarge:
        LargeWidgetView(entry: entry)  // uses same view; wider on iPad
    case .accessoryRectangular:
        lockScreenView
    case .accessoryCircular:
        CircularWidgetView(entry: entry)
    case .accessoryInline:
        InlineWidgetView(entry: entry)
    default:
        #if os(macOS)
        macOSLargeWidgetView(entry: entry)
        #else
        smallView
        #endif
    }
}
```

Replace `.supportedFamilies(...)`:

```swift
.supportedFamilies([
    .systemSmall,
    .systemMedium,
    .systemLarge,
    .systemExtraLarge,
    .accessoryRectangular,
    .accessoryCircular,
    .accessoryInline,
])
```

- [ ] **Step 7: Register new files in pbxproj**

Run this Python snippet from the worktree root to add the 5 new widget view files:

```python
path = "iqamah.xcodeproj/project.pbxproj"
with open(path) as f: c = f.read()

new_refs = """
\t\tWV000000000000000000001R /* LargeWidgetView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LargeWidgetView.swift; sourceTree = "<group>"; };
\t\tWV000000000000000000002R /* CircularWidgetView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CircularWidgetView.swift; sourceTree = "<group>"; };
\t\tWV000000000000000000003R /* InlineWidgetView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = InlineWidgetView.swift; sourceTree = "<group>"; };
\t\tWV000000000000000000004R /* macOSLargeWidgetView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = macOSLargeWidgetView.swift; sourceTree = "<group>"; };
"""
new_bfs = """
\t\tWV000000000000000000001 /* LargeWidgetView.swift in Sources */ = {isa = PBXBuildFile; fileRef = WV000000000000000000001R; };
\t\tWV000000000000000000002 /* CircularWidgetView.swift in Sources */ = {isa = PBXBuildFile; fileRef = WV000000000000000000002R; };
\t\tWV000000000000000000003 /* InlineWidgetView.swift in Sources */ = {isa = PBXBuildFile; fileRef = WV000000000000000000003R; };
\t\tWV000000000000000000004 /* macOSLargeWidgetView.swift in Sources */ = {isa = PBXBuildFile; fileRef = WV000000000000000000004R; };
"""
c = c.replace("/* End PBXFileReference section */", new_refs + "/* End PBXFileReference section */")
c = c.replace("/* End PBXBuildFile section */", new_bfs + "/* End PBXBuildFile section */")

# Find the IqamahWidget Sources build phase UUID — look for IqamahWidget.swift in Sources
import re
ww_sources = re.search(r'(\w{24}) /\* Sources.*?IqamahWidget.*?PBXSourcesBuildPhase', c, re.DOTALL)
# Add to existing IqamahWidget Sources build phase by finding IqamahWidget.swift build file entry
existing_line = re.search(r'\w+ /\* IqamahWidget\.swift in Sources \*/', c)
if existing_line:
    old = existing_line.group(0) + ","
    new = old + """
\t\t\t\tWV000000000000000000001 /* LargeWidgetView.swift in Sources */,
\t\t\t\tWV000000000000000000002 /* CircularWidgetView.swift in Sources */,
\t\t\t\tWV000000000000000000003 /* InlineWidgetView.swift in Sources */,
\t\t\t\tWV000000000000000000004 /* macOSLargeWidgetView.swift in Sources */,"""
    c = c.replace(old, new)

with open(path, "w") as f: f.write(c)
print("done")
```

- [ ] **Step 8: Build widget**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep "BUILD"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: swiftformat new files**

```bash
swiftformat IqamahWidget/LargeWidgetView.swift IqamahWidget/CircularWidgetView.swift \
  IqamahWidget/InlineWidgetView.swift IqamahWidget/macOSLargeWidgetView.swift
```

- [ ] **Step 10: Commit**

```bash
git add IqamahWidget/ iqamah.xcodeproj/
git commit -m "feat: iOS widget Large/Circular/Inline + macOS Large; extend PrayerEntry with todaysPrayers + hijriDateString"
```

---

## Task 4 — Live Activity: Xcode target setup

**Files:**
- Create: `IqamahLiveActivity/Info.plist`
- Create: `IqamahLiveActivity/IqamahLiveActivity.entitlements`
- Modify: `iqamah.xcodeproj/project.pbxproj`
- Create: `iqamah.xcodeproj/xcshareddata/xcschemes/IqamahLiveActivity.xcscheme`

- [ ] **Step 1: Create Info.plist**

Create `IqamahLiveActivity/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
    <key>NSSupportsLiveActivities</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: Create entitlements**

Create `IqamahLiveActivity/IqamahLiveActivity.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.fablesoft.iqamah</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 3: Add iOS Info.plist Live Activity key**

Read `iqamah/iOS/Info.plist`. Add `NSSupportsLiveActivities`:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

- [ ] **Step 4: Add IqamahLiveActivity target to pbxproj**

Run this Python snippet:

```python
path = "iqamah.xcodeproj/project.pbxproj"
with open(path) as f: c = f.read()

LA_APP    = "LA000000000000000000001"
LA_SOURCES= "LA000000000000000000002"
LA_RES    = "LA000000000000000000003"
LA_FW     = "LA000000000000000000004"
LA_PROD   = "LA000000000000000000005"
LA_CFG_D  = "LA000000000000000000006"
LA_CFG_R  = "LA000000000000000000007"
LA_CFGLIST= "LA000000000000000000008"
IC_BF_LA  = "LA000000000000000000009"
IC_PROD_DEP = "IC0000000000000000000002"  # existing IqamahCore dep

new_file_refs = f"""
\t\t{LA_PROD} /* IqamahLiveActivity.appex */ = {{isa = PBXFileReference; explicitFileType = "plug-in"; includeInIndex = 0; path = IqamahLiveActivity.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
"""
new_bfs = f"""
\t\t{IC_BF_LA} /* IqamahCore in Frameworks (LA) */ = {{isa = PBXBuildFile; productRef = {IC_PROD_DEP} /* IqamahCore */; }};
"""
new_phases = f"""
\t\t{LA_SOURCES} /* Sources (LA) */ = {{
\t\t\tisa = PBXSourcesBuildPhase; buildActionMask = 2147483647;
\t\t\tfiles = (); runOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{LA_RES} /* Resources (LA) */ = {{
\t\t\tisa = PBXResourcesBuildPhase; buildActionMask = 2147483647;
\t\t\tfiles = (); runOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{LA_FW} /* Frameworks (LA) */ = {{
\t\t\tisa = PBXFrameworksBuildPhase; buildActionMask = 2147483647;
\t\t\tfiles = ({IC_BF_LA} /* IqamahCore */,); runOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
new_target = f"""
\t\t{LA_APP} /* IqamahLiveActivity */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {LA_CFGLIST};
\t\t\tbuildPhases = ({LA_SOURCES},{LA_FW},{LA_RES},);
\t\t\tbuildRules = (); dependencies = ();
\t\t\tname = IqamahLiveActivity;
\t\t\tpackageProductDependencies = ({IC_BF_LA},);
\t\t\tproductName = IqamahLiveActivity;
\t\t\tproductReference = {LA_PROD};
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t}};
"""
new_configs = f"""
\t\t{LA_CFG_D} /* Debug (LA) */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "IqamahLiveActivity/IqamahLiveActivity.entitlements";
\t\t\t\tCODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = 96Y29SP9JR;
\t\t\t\tINFOPLIST_FILE = "IqamahLiveActivity/Info.plist";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.fablesoft.iqamah.liveactivity";
\t\t\t\tPRODUCT_NAME = IqamahLiveActivity;
\t\t\t\tSDKROOT = iphoneos; SKIP_INSTALL = YES; SWIFT_VERSION = 5.10;
\t\t\t}}; name = Debug;
\t\t}};
\t\t{LA_CFG_R} /* Release (LA) */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "IqamahLiveActivity/IqamahLiveActivity.entitlements";
\t\t\t\tCODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = 96Y29SP9JR;
\t\t\t\tINFOPLIST_FILE = "IqamahLiveActivity/Info.plist";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.fablesoft.iqamah.liveactivity";
\t\t\t\tPRODUCT_NAME = IqamahLiveActivity;
\t\t\t\tSDKROOT = iphoneos; SKIP_INSTALL = YES; SWIFT_VERSION = 5.10;
\t\t\t}}; name = Release;
\t\t}};
\t\t{LA_CFGLIST} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = ({LA_CFG_D},{LA_CFG_R},);
\t\t\tdefaultConfigurationIsVisible = 0; defaultConfigurationName = Release;
\t\t}};
"""

c = c.replace("/* End PBXFileReference section */", new_file_refs + "/* End PBXFileReference section */")
c = c.replace("/* End PBXBuildFile section */", new_bfs + "/* End PBXBuildFile section */")
c = c.replace("/* End PBXSourcesBuildPhase section */", new_phases + "/* End PBXSourcesBuildPhase section */")
c = c.replace("/* End PBXNativeTarget section */", new_target + "/* End PBXNativeTarget section */")
c = c.replace("/* End XCBuildConfiguration section */", new_configs + "/* End XCBuildConfiguration section */")
import re
c = re.sub(r'(targets = \()', f'\\1\n\t\t\t\t{LA_APP} /* IqamahLiveActivity */,', c, count=1)
with open(path, "w") as f: f.write(c)
print("done")
```

- [ ] **Step 5: Verify target recognised**

```bash
xcodebuild -project iqamah.xcodeproj -list 2>&1 | grep IqamahLiveActivity
```
Expected: `IqamahLiveActivity` listed.


- [ ] **Step 5b: Embed `IqamahLiveActivity` in iOS app target**

Without this, the extension won't ship inside the app bundle. Add a CopyFiles (Embed App Extensions) build phase to the iOS target. Run this Python snippet:

```python
import re, sys
path = "iqamah.xcodeproj/project.pbxproj"
with open(path) as f: c = f.read()
EMBED_PHASE = "LA000000000000000000020"
EMBED_BF    = "LA000000000000000000021"
LA_PROD_REF = "LA000000000000000000005"
new_bf = f"\t\t{EMBED_BF} /* IqamahLiveActivity.appex in Embed */ = {{isa = PBXBuildFile; fileRef = {LA_PROD_REF}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n"
new_phase = f"""\t\t{EMBED_PHASE} /* Embed App Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647;
\t\t\tdstPath = ""; dstSubfolderSpec = 13;
\t\t\tfiles = ({EMBED_BF} /* IqamahLiveActivity.appex in Embed */,);
\t\t\tname = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0;
\t\t}};\n"""
if "/* End PBXCopyFilesBuildPhase section */" not in c:
    c = c.replace("/* End PBXBuildFile section */", new_bf + "/* End PBXBuildFile section */")
    # Insert before first PBXNativeTarget section as a new section
    c = c.replace("/* Begin PBXNativeTarget section */",
                  "/* Begin PBXCopyFilesBuildPhase section */\n" + new_phase + "/* End PBXCopyFilesBuildPhase section */\n\n/* Begin PBXNativeTarget section */")
else:
    c = c.replace("/* End PBXBuildFile section */", new_bf + "/* End PBXBuildFile section */")
    c = c.replace("/* End PBXCopyFilesBuildPhase section */", new_phase + "/* End PBXCopyFilesBuildPhase section */")
# Add embed phase to iOS target's buildPhases list (find iOS native target)
ios_target = re.search(r"(iOS0000000000000000000040[^{]*\{[^}]*buildPhases = \()([^)]+)(\))", c, re.DOTALL)
if ios_target:
    c = c[:ios_target.start(2)] + ios_target.group(2) + f"\n\t\t\t\t{EMBED_PHASE} /* Embed App Extensions */," + c[ios_target.end(2):]
with open(path, "w") as f: f.write(c)
print("Embed phase added")
```

- [ ] **Step 6: Commit**

```bash
git add IqamahLiveActivity/ iqamah/iOS/Info.plist iqamah.xcodeproj/
git commit -m "feat: add IqamahLiveActivity Xcode target + entitlements + NSSupportsLiveActivities"
```

---

## Task 5 — PrayerActivityAttributes + Live Activity views

**Files:**
- Create: `IqamahLiveActivity/PrayerActivityAttributes.swift`
- Create: `IqamahLiveActivity/PrayerLiveActivityView.swift`

- [ ] **Step 1: Create PrayerActivityAttributes.swift**

```swift
import ActivityKit
import Foundation
import IqamahCore

public struct PrayerActivityAttributes: ActivityAttributes {
    /// Static — set once when the activity starts.
    public let cityName: String
    public let methodName: String

    public init(cityName: String, methodName: String) {
        self.cityName = cityName
        self.methodName = methodName
    }

    public struct ContentState: Codable, Hashable {
        /// The upcoming prayer name, e.g. "Asr"
        public let nextPrayerName: String
        /// When the next prayer occurs
        public let nextPrayerTime: Date
        /// The prayer after next (shown in compact trailing hint), e.g. "Maghrib"
        public let followingPrayerName: String
        /// Synodic moon phase 0–1 (drives MoonPhaseView)
        public let moonPhase: Double
        /// Formatted Hijri date, e.g. "9 Dhu al-Hijjah 1447"
        public let hijriDateString: String

        public init(
            nextPrayerName: String,
            nextPrayerTime: Date,
            followingPrayerName: String,
            moonPhase: Double,
            hijriDateString: String
        ) {
            self.nextPrayerName = nextPrayerName
            self.nextPrayerTime = nextPrayerTime
            self.followingPrayerName = followingPrayerName
            self.moonPhase = moonPhase
            self.hijriDateString = hijriDateString
        }
    }
}
```

- [ ] **Step 2: Create PrayerLiveActivityView.swift**

```swift
import ActivityKit
import IqamahCore
import SwiftUI
import WidgetKit

// MARK: - Colour

private let gold = Color(red: 1.0, green: 0.839, blue: 0.039)

// MARK: - Main dispatcher

@available(iOS 16.2, *)
struct PrayerLiveActivityView: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            // Lock Screen presentation
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color(uiColor: .systemBackground).opacity(0.0))
                .activitySystemActionForegroundColor(gold)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (tapped)
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                // Compact leading: gold dot + prayer name
                HStack(spacing: 4) {
                    Circle().fill(gold).frame(width: 7, height: 7)
                    Text(context.state.nextPrayerName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(gold)
                }
            } compactTrailing: {
                // Compact trailing: countdown
                Text(context.state.nextPrayerTime, style: .timer)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(maxWidth: 40)
            } minimal: {
                // Minimal: prayer initial
                Text(String(context.state.nextPrayerName.prefix(1)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(gold)
            }
        }
    }
}

// MARK: - Expanded sub-views

@available(iOS 16.2, *)
private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                // Moon phase — reuses app MoonPhaseView
                MoonPhaseView(size: 20, phase: context.state.moonPhase)
                Text(context.state.hijriDateString)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(context.attributes.cityName)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.leading, 4)
    }
}

@available(iOS 16.2, *)
private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(context.state.nextPrayerName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(gold)
            Text(context.state.nextPrayerTime, style: .timer)
                .font(.system(size: 28, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(maxWidth: 90, alignment: .trailing)
        }
        .padding(.trailing, 4)
    }
}

@available(iOS 16.2, *)
private struct ExpandedBottomView: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    var body: some View {
        HStack {
            Text("at \(context.state.nextPrayerTime.formatted(.dateTime.hour().minute())) · \(context.attributes.cityName)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            // "Open Iqamah" tap indicator
            Label("Open Iqamah", systemImage: "arrow.up.right")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
    }
}

// MARK: - Lock Screen

@available(iOS 16.2, *)
private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<PrayerActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Left: clock icon in gold circle
            ZStack {
                Circle()
                    .fill(gold.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: "clock")
                    .foregroundStyle(gold)
                    .font(.system(size: 18, weight: .semibold))
            }

            // Middle: prayer name + time + countdown
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(context.state.nextPrayerName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(gold)
                    Text(context.state.nextPrayerTime.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                }
                Text(context.state.nextPrayerTime, style: .relative)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Right: moon + Hijri date
            VStack(alignment: .center, spacing: 4) {
                MoonPhaseView(size: 26, phase: context.state.moonPhase)
                Text(shortHijri(context.state.hijriDateString))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 52)
            .padding(.leading, 4)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    /// Shorten "9 Dhu al-Hijjah 1447" → "9 Dhu\nal-Hijjah"
    private func shortHijri(_ full: String) -> String {
        let parts = full.split(separator: " ")
        guard parts.count >= 3 else { return full }
        return "\(parts[0]) \(parts[1])\n\(parts[2])"
    }
}
```

**Important:** `MoonPhaseView` is macOS-app-only and inaccessible from `IqamahLiveActivity`. Use this inline `CrescentView` instead:

```swift
private struct CrescentView: View {
    let phase: Double  // 0-1 synodic fraction
    let size: CGFloat
    private let gold = Color(red: 1.0, green: 0.839, blue: 0.039)

    var body: some View {
        Canvas { ctx, sz in
            let r = min(sz.width, sz.height) / 2 - 1
            let cx = sz.width / 2, cy = sz.height / 2
            // Dark disc
            let disc = Path(ellipseIn: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2))
            ctx.fill(disc, with: .color(Color(red: 0.04, green: 0.04, blue: 0.13)))
            guard phase > 0.02 else { return }
            if phase > 0.48 && phase < 0.52 {
                ctx.fill(disc, with: .color(gold.opacity(0.92))); return
            }
            let waxing = phase < 0.5
            let innerRx = abs(r * (waxing ? 1 - phase * 2 : phase * 2 - 1))
            var path = Path()
            path.move(to: CGPoint(x: cx, y: cy - r))
            path.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                        startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: !waxing)
            path.addArc(center: CGPoint(x: cx, y: cy), radius: innerRx,
                        startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: waxing)
            path.closeSubpath()
            ctx.fill(path, with: .color(gold.opacity(0.90)))
        }
        .frame(width: size, height: size)
    }
}
```

Replace all `MoonPhaseView(size: X, phase: Y)` calls in this file with `CrescentView(phase: Y, size: X)`.

- [ ] **Step 3: Register files in pbxproj**

```python
path = "iqamah.xcodeproj/project.pbxproj"
with open(path) as f: c = f.read()

new_refs = """
\t\tLA000000000000000000010R /* PrayerActivityAttributes.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PrayerActivityAttributes.swift; sourceTree = "<group>"; };
\t\tLA000000000000000000011R /* PrayerLiveActivityView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PrayerLiveActivityView.swift; sourceTree = "<group>"; };
"""
new_bfs = """
\t\tLA000000000000000000010 /* PrayerActivityAttributes.swift in Sources */ = {isa = PBXBuildFile; fileRef = LA000000000000000000010R; };
\t\tLA000000000000000000011 /* PrayerLiveActivityView.swift in Sources */ = {isa = PBXBuildFile; fileRef = LA000000000000000000011R; };
"""
c = c.replace("/* End PBXFileReference section */", new_refs + "/* End PBXFileReference section */")
c = c.replace("/* End PBXBuildFile section */", new_bfs + "/* End PBXBuildFile section */")
c = c.replace(
    "LA000000000000000000002 /* Sources (LA) */ = {\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = ();",
    "LA000000000000000000002 /* Sources (LA) */ = {\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\tLA000000000000000000010 /* PrayerActivityAttributes.swift in Sources */,\n\t\t\t\tLA000000000000000000011 /* PrayerLiveActivityView.swift in Sources */,\n\t\t\t);"
)
with open(path, "w") as f: f.write(c)
print("done")
```

- [ ] **Step 4: Build Live Activity extension**

```bash
xcodebuild -project iqamah.xcodeproj -target IqamahLiveActivity \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD" | head -10
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: swiftformat**

```bash
swiftformat IqamahLiveActivity/
```

- [ ] **Step 6: Commit**

```bash
git add IqamahLiveActivity/ iqamah.xcodeproj/
git commit -m "feat: PrayerActivityAttributes + all 4 Dynamic Island presentations (compact/expanded/lock screen/minimal)"
```

---

## Task 6 — PrayerActivityManager (iOS app service)

**Files:**
- Create: `iqamah/iOS/PrayerActivityManager.swift`

- [ ] **Step 1: Create PrayerActivityManager.swift**

```swift
#if os(iOS)
import ActivityKit
import Foundation
import IqamahCore

/// Manages the lifecycle of the prayer times Live Activity.
///
/// Call `startOrUpdateActivity(settings:)` on every app-active event.
/// The manager handles creating, updating, and ending gracefully.
@MainActor
final class PrayerActivityManager {
    static let shared = PrayerActivityManager()
    private init() {}

    private var currentActivity: Activity<PrayerActivityAttributes>?

    // MARK: - Public API

    /// Start a new activity or update the existing one.
    /// Should be called on app-active and at each prayer crossing.
    func startOrUpdateActivity(settings: SettingsManager) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              settings.liveActivityEnabled else {
            await endActivity()
            return
        }

        let state = buildContentState(settings: settings)
        guard let state else { return }

        if let activity = currentActivity {
            // Update existing
            await activity.update(using: state, alertConfiguration: nil)
        } else {
            // Start new
            let attributes = PrayerActivityAttributes(
                cityName: settings.activeCityName,
                methodName: settings.calculationMethod.shortName
            )
            do {
                currentActivity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            } catch {
                print("[PrayerActivityManager] Failed to start: \(error)")
            }
        }
    }

    /// End the Live Activity immediately.
    func endActivity() async {
        await currentActivity?.end(using: nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }

    // MARK: - Private

    private func buildContentState(settings: SettingsManager) -> PrayerActivityAttributes.ContentState? {
        guard let coord = settings.activeCoordinate,
              let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier) else { return nil }

        let calc = PrayerCalculator(
            coordinate: coord, timezone: timezone,
            method: settings.calculationMethod, asrMethod: settings.asrMethod
        )
        let now = Date()

        // Find next and following prayers
        var nextPrayer: (name: String, time: Date)?
        var followingPrayer: (name: String, time: Date)?

        for dayOffset in 0 ... 1 {
            guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now),
                  let times = try? calc.calculate(for: day) else { continue }
            let upcoming = times.prayers.filter { $0.time > now && $0.name != "Sunrise" }
            for prayer in upcoming {
                if nextPrayer == nil {
                    nextPrayer = (prayer.name, prayer.time)
                } else if followingPrayer == nil {
                    followingPrayer = (prayer.name, prayer.time)
                    break
                }
            }
            if followingPrayer != nil { break }
        }

        guard let next = nextPrayer else { return nil }

        return PrayerActivityAttributes.ContentState(
            nextPrayerName: next.name,
            nextPrayerTime: next.time,
            followingPrayerName: followingPrayer?.name ?? "",
            moonPhase: moonPhase(for: now),
            hijriDateString: hijriDateString(for: now, offset: settings.hijriDayOffset)
        )
    }
}
#endif
```

- [ ] **Step 2: Add to pbxproj iOS Sources**

```python
path = "iqamah.xcodeproj/project.pbxproj"
with open(path) as f: c = f.read()

new_ref = "\t\tAM000000000000000000001R /* PrayerActivityManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PrayerActivityManager.swift; sourceTree = \"<group>\"; };\n"
new_bf  = "\t\tAM000000000000000000001 /* PrayerActivityManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = AM000000000000000000001R /* PrayerActivityManager.swift */; };\n"
c = c.replace("/* End PBXFileReference section */", new_ref + "/* End PBXFileReference section */")
c = c.replace("/* End PBXBuildFile section */", new_bf + "/* End PBXBuildFile section */")

# Add to iOS target Sources (find existing iOS source entry)
import re
m = re.search(r'(iOS0000000000000000000001 /\* iqamahApp_iOS\.swift in Sources \*/,)', c)
if m:
    c = c.replace(m.group(0), m.group(0) + "\n\t\t\t\tAM000000000000000000001 /* PrayerActivityManager.swift in Sources */,")
with open(path, "w") as f: f.write(c)
print("done")
```

- [ ] **Step 3: Wire into iqamahApp_iOS.swift**

Read `iqamah/iOS/iqamahApp_iOS.swift`. Add to the `WindowGroup` modifiers:

```swift
.onChange(of: settings.liveActivityEnabled) { _, enabled in
    Task {
        if enabled {
            await PrayerActivityManager.shared.startOrUpdateActivity(settings: settings)
        } else {
            await PrayerActivityManager.shared.endActivity()
        }
    }
}
.onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
    guard settings.liveActivityEnabled else { return }
    Task { await PrayerActivityManager.shared.startOrUpdateActivity(settings: settings) }
}
// On each app-active, refresh the activity (advances the prayer crossing)
.onChange(of: scenePhase) { _, phase in
    if phase == .active {
        reschedule()
        reloadWidget()
        if settings.liveActivityEnabled {
            Task { await PrayerActivityManager.shared.startOrUpdateActivity(settings: settings) }
        }
    }
}
```

Also add `reloadWidget()` helper if not already present:

```swift
private func reloadWidget() {
    WidgetCenter.shared.reloadAllTimelines()
}
```

- [ ] **Step 4: Add Live Activity toggle to iOS Settings**

Read `iqamah/Views/SettingsSheetView.swift`. Find the "Notifications" section and add a toggle for Live Activity:

```swift
Toggle("Live Activity / Dynamic Island", isOn: $settings.liveActivityEnabled)
    .help("Shows prayer countdown in Dynamic Island and lock screen all day")
```

- [ ] **Step 5: Build iOS**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep "BUILD"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: swiftformat**

```bash
swiftformat iqamah/iOS/PrayerActivityManager.swift iqamah/iOS/iqamahApp_iOS.swift
swiftlint lint --strict --quiet iqamah/iOS/PrayerActivityManager.swift
```

- [ ] **Step 7: Commit**

```bash
git add iqamah/ iqamah.xcodeproj/
git commit -m "feat: PrayerActivityManager + liveActivityEnabled Settings toggle + app wiring"
```

---

## Task 7 — IqamahCore unit tests + final verification

**Files:**
- Confirm tests pass; verify all three targets build

- [ ] **Step 1: Run IqamahCore tests**

```bash
cd Packages/IqamahCore && swift test 2>&1 | tail -5
```
Expected: all tests pass (count ≥ 183 — 178 existing + 5 new moon/Hijri tests).

- [ ] **Step 2: Build macOS**

```bash
cd /path/to/worktree
xcodebuild -project iqamah.xcodeproj -scheme iqamah \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | grep "BUILD"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Build iOS**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep "BUILD"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: swiftformat + swiftlint full pass**

```bash
swiftformat IqamahWidget/ IqamahLiveActivity/ iqamah/iOS/
swiftlint lint --strict --quiet IqamahWidget/ IqamahLiveActivity/ iqamah/iOS/
```
Expected: 0 violations.

- [ ] **Step 5: Push and open PR**

```bash
git push -u origin feat/EPIC-0013-widget-platform

gh pr create --base develop \
  --title "feat(EPIC-0013): Widget Platform — Live Activity + iOS widgets + macOS widget" \
  --body "Implements EPIC-0013 (US-0058/0059/0060):
- Dynamic Island / Live Activity: compact, expanded, lock screen, minimal
- iOS new widget families: Large, ExtraLarge, StandBy, Circular, Inline
- macOS Notification Center: Small+Medium (free reuse), Large (new view)
- IqamahCore: moonPhase(for:) + hijriDateString(for:offset:)
- SettingsManager: liveActivityEnabled (KVS-synced, independent of notifications)"
```

---

## Self-Review

**Spec coverage:**
- ✅ `PrayerActivityAttributes` with all fields (Task 5)
- ✅ Lifecycle — start on active, update at prayer crossing, end at next Fajr pattern (Task 6)
- ✅ `liveActivityEnabled` independent toggle (Task 2 + Task 6)
- ✅ All 4 DI presentations (Task 5)
- ✅ `moonPhase(for:)` + `hijriDateString(for:offset:)` (Task 1)
- ✅ iOS Large, ExtraLarge, Circular, Inline, StandBy (Task 3)
- ✅ macOS Small/Medium (free) + Large (Task 3 — macOSLargeWidgetView)
- ✅ `MoonPhaseView` reuse noted with inline alternative (Task 5)
- ✅ `.stale(after: nextPrayerTime)` — handled by `refreshPolicy(for:)` in existing `PrayerTimelineProvider` (returns `.after(lastEntry.nextPrayerTime)` which covers this)

**Type consistency check:**
- `PrayerEntry.todaysPrayers` defined Task 3 Step 5, used in `LargeWidgetView` Task 3 Step 1 ✅
- `PrayerEntry.hijriDateString` defined Task 3 Step 5, used in `LargeWidgetView` and `macOSLargeWidgetView` ✅
- `PrayerActivityAttributes.ContentState` defined Task 5 Step 1, used in `PrayerActivityManager` Task 6 Step 1 ✅
- `moonPhase(for:)` defined Task 1, called in `PrayerTimelineProvider` (Task 3) and `PrayerActivityManager` (Task 6) ✅
- `hijriDateString(for:offset:)` defined Task 1, called in both providers ✅

**Review fixes applied 2026-05-11:** Task 3 ordering warning added; PrayerEntry new fields get empty defaults; CrescentView inline code replaces MoonPhaseView note; embed step added to Task 4; ExtraLargeWidgetView clarified as not needed.

**Last Updated:** 2026-05-11 (post-review)
