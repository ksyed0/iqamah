# Adaptive Layout (EPIC-0014) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all hardcoded macOS-sized frames with adaptive layouts that work correctly on iPhone, iPad portrait, iPad landscape, and macOS.

**Architecture:** Three user stories executed in dependency order: (1) `Adhaan.availableForSunrise` in IqamahCore (no UI dependencies), (2) new iOS-only view files (`PrayerHeroCard`, `PrayerRowMobileView`, `AdhaanChipTray`) with `PrayerTimesTable` wired to use them, (3) adaptive layout in `PrayerTimesView` using `horizontalSizeClass` + `GeometryReader`, (4) `QiblahCompassView` extracted and scaled with `GeometryReader`.

**Tech Stack:** SwiftUI, `@Environment(\.horizontalSizeClass)`, `GeometryReader`, `withAnimation(.spring)`, iOS 17+ `Path.subtracting` (already in codebase), `LazyVGrid` for chip wrap.

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `Packages/IqamahCore/Sources/IqamahCore/Models/Adhaan.swift` | Modify | Add `availableForSunrise` |
| `Packages/IqamahCore/Tests/IqamahCoreTests/IqamahModelTests.swift` | Modify | Sunrise adhaan tests |
| `iqamah/iOS/PrayerHeroCard.swift` | **Create** | Moon + Hijri + countdown + Hilal Watch button |
| `iqamah/iOS/PrayerRowMobileView.swift` | **Create** | Compact row + chip tray (iOS only) |
| `iqamah/Views/PrayerTimesComponents.swift` | Modify | Wire iOS mobile rows; shared expand state |
| `iqamah/Views/PrayerTimesView.swift` | Modify | Layout branches + remove fixed frame |
| `iqamah/Views/QiblahView.swift` | Modify | Extract `QiblahCompassView`; GeometryReader |

---

## Task 1: `Adhaan.availableForSunrise` (TDD)

**Files:**
- Modify: `Packages/IqamahCore/Sources/IqamahCore/Models/Adhaan.swift:35-42`
- Test: `Packages/IqamahCore/Tests/IqamahCoreTests/IqamahModelTests.swift`

- [ ] **Step 1: Write failing tests**

Open `Packages/IqamahCore/Tests/IqamahCoreTests/IqamahModelTests.swift` and add at the end of the file (before the final `}`):

```swift
// MARK: - Sunrise adhaan options (AC-0290, AC-0291)

func testAvailableForSunriseContainsSilentAndAlertTones() {
    let options = Adhaan.availableForSunrise
    XCTAssertTrue(options.contains(where: { $0.id == "silent" }),
                  "availableForSunrise must include .silent")
    for tone in Adhaan.alertTones {
        XCTAssertTrue(options.contains(where: { $0.id == tone.id }),
                      "availableForSunrise must include alert tone \(tone.id)")
    }
}

func testAvailableForSunriseContainsNoAdhaanRecordings() {
    let options = Adhaan.availableForSunrise
    let forbidden = options.filter {
        $0.id.hasPrefix("adhaan_") || $0.id.hasPrefix("fajr_")
    }
    XCTAssertTrue(forbidden.isEmpty,
                  "availableForSunrise must not contain adhaan recordings: \(forbidden.map(\.id))")
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd Packages/IqamahCore
swift test --filter "testAvailableForSunrise" 2>&1 | tail -10
```
Expected: `error: value of type 'Adhaan' has no member 'availableForSunrise'`

- [ ] **Step 3: Add `availableForSunrise` to Adhaan.swift**

In `Packages/IqamahCore/Sources/IqamahCore/Models/Adhaan.swift`, after `availableForFajr` (around line 42), insert:

```swift
/// Alert tones only — suitable for Sunrise which is not a prayer.
/// No adhaan recordings; silence is the default ("No alert").
public static var availableForSunrise: [Adhaan] {
    var options: [Adhaan] = [.silent]
    options += alertTones
    return options
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
cd Packages/IqamahCore
swift test --filter "testAvailableForSunrise" 2>&1 | tail -10
```
Expected: `Test Suite 'Selected tests' passed`

- [ ] **Step 5: Run full IqamahCore test suite**

```bash
cd Packages/IqamahCore
swift test 2>&1 | tail -5
```
Expected: `Test Suite 'All tests' passed`

- [ ] **Step 6: Commit**

```bash
git add Packages/IqamahCore/Sources/IqamahCore/Models/Adhaan.swift \
        Packages/IqamahCore/Tests/IqamahCoreTests/IqamahModelTests.swift
git commit -m "feat(EPIC-0014): add Adhaan.availableForSunrise — alert tones only (AC-0290)"
```

---

## Task 2: `PrayerHeroCard` — iOS hero card view

**Files:**
- Create: `iqamah/iOS/PrayerHeroCard.swift`

The hero card shows moon phase, Hijri date, moon subtitle, countdown to next prayer, and Hilal Watch button. It is iOS-only and sits above the prayer list on iPhone and iPad portrait.

- [ ] **Step 1: Create the file**

Create `iqamah/iOS/PrayerHeroCard.swift`:

```swift
import IqamahCore
import SwiftUI

/// Hero card shown above the prayer list on iPhone and iPad portrait.
/// Displays the current moon phase, Hijri date, countdown to next prayer,
/// and a Hilal Watch entry button.
struct PrayerHeroCard: View {
    let moonPhase: Double
    let hijriDateLabel: String
    let moonPhaseSubtitle: String
    let isHilalWatchEvening: Bool
    let nextPrayerTime: Date?
    let onHilalWatch: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var gold: Color { colorScheme == .dark ? .appGold : .appGoldDark }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            MoonPhaseView(phase: moonPhase, size: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(hijriDateLabel)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(isHilalWatchEvening ? "Hilal Watch tonight" : moonPhaseSubtitle)
                    .font(.caption)
                    .foregroundStyle(isHilalWatchEvening ? Color.orange : Color.secondary)

                Button(action: onHilalWatch) {
                    Text("Hilal Watch ›")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(gold)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Hilal Watch")
            }

            Spacer()

            if let nextTime = nextPrayerTime {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(nextTime, style: .timer)
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(gold)
                        .multilineTextAlignment(.trailing)
                    Text("until next prayer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Time until next prayer")
                .accessibilityValue(Text(nextTime, style: .relative))
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
```

- [ ] **Step 2: Add to Xcode iOS target**

The file must be in the `iqamah-iOS` target. Run:

```bash
cd /Users/Kamal_Syed/Projects/iqamah/iqamah
python3 - << 'EOF'
with open("iqamah.xcodeproj/project.pbxproj") as f:
    content = f.read()

# Check if already added
if "PrayerHeroCard.swift" in content:
    print("Already present")
else:
    # Add PBXFileReference
    fr = '\n\t\tHC000000000000000000001 /* PrayerHeroCard.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PrayerHeroCard.swift; sourceTree = "<group>"; };'
    content = content.replace("/* End PBXFileReference section */",
                               fr + "\n\t\t/* End PBXFileReference section */")
    # Add PBXBuildFile
    bf = '\n\t\tHC000000000000000000002 /* PrayerHeroCard.swift in Sources */ = {isa = PBXBuildFile; fileRef = HC000000000000000000001 /* PrayerHeroCard.swift */; };'
    content = content.replace("/* End PBXBuildFile section */",
                               bf + "\n\t\t/* End PBXBuildFile section */")
    # Add to iOS Sources phase (after AM000000000000000000001)
    content = content.replace(
        "AM000000000000000000001 /* PrayerActivityManager.swift in Sources */,",
        "AM000000000000000000001 /* PrayerActivityManager.swift in Sources */,\n\t\t\t\tHC000000000000000000002 /* PrayerHeroCard.swift in Sources */,"
    )
    # Add to iOS group (after HilalWatchSheet.swift)
    content = content.replace(
        "B5000000000000000000010 /* HilalWatchSheet.swift */,",
        "B5000000000000000000010 /* HilalWatchSheet.swift */,\n\t\t\t\tHC000000000000000000001 /* PrayerHeroCard.swift */,"
    )
    with open("iqamah.xcodeproj/project.pbxproj", "w") as f:
        f.write(content)
    print("Added PrayerHeroCard.swift to iOS target")
EOF
```

- [ ] **Step 3: Build iOS to verify it compiles**

```bash
xcodebuild -project iqamah.xcodeproj -scheme "iqamah-iOS" -configuration Debug \
  -destination 'platform=iOS Simulator,id=EEDE8413-6F50-443B-97C1-7666DDEBD2F1' \
  -allowProvisioningUpdates build 2>&1 | grep -E "BUILD|error:" | grep -v "^---" | head -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add iqamah/iOS/PrayerHeroCard.swift iqamah.xcodeproj/project.pbxproj
git commit -m "feat(EPIC-0014): add PrayerHeroCard — iOS moon/countdown/Hilal Watch card (US-0061)"
```

---

## Task 3: `PrayerRowMobileView` — compact iOS prayer row

**Files:**
- Create: `iqamah/iOS/PrayerRowMobileView.swift`

This is the iOS-only compact prayer row: `icon · name · [pill] · time`. Tapping the row calls `onTap`; the parent manages expand state. The Sunrise variant uses amber pill styling.

- [ ] **Step 1: Create the file**

Create `iqamah/iOS/PrayerRowMobileView.swift`:

```swift
import IqamahCore
import SwiftUI

/// Compact prayer row for iOS: icon · name · adhaan pill · time.
/// Tapping the row signals the parent to toggle the chip tray.
/// `isPast` dims the row; `isNext` applies gold highlight.
struct PrayerRowMobileView: View {
    let name: String
    let time: Date
    let formatter: DateFormatter
    let isPast: Bool
    let isNext: Bool
    let selectedAdhaan: Adhaan
    let isExpanded: Bool
    let onTap: () -> Void
    let onSelectAdhaan: (Adhaan) -> Void
    let onToggleMute: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var gold: Color { colorScheme == .dark ? .appGold : .appGoldDark }
    private var isSunrise: Bool { name == "Sunrise" }

    var body: some View {
        VStack(spacing: 0) {
            rowContent
            if isExpanded {
                AdhaanChipTray(
                    prayerName: name,
                    selectedAdhaan: selectedAdhaan,
                    onSelectAdhaan: onSelectAdhaan,
                    onToggleMute: onToggleMute
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var rowContent: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(isNext ? gold.opacity(0.15) : Color.secondary.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: iconName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(isNext ? gold : .secondary)
                }

                // Prayer name
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(isNext ? .body.bold() : .body)
                        .foregroundStyle(isNext ? gold : .primary)
                    if isNext {
                        Text("NEXT")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(gold.opacity(0.85))
                            .tracking(1.0)
                    }
                }

                Spacer()

                // Adhaan / alert pill (between name and time)
                if isSunrise {
                    alertPill
                } else {
                    adhaanPill
                }

                // Time
                Text(formatter.string(from: time))
                    .font(isNext ? .body.bold() : .body)
                    .foregroundStyle(isNext ? gold : .primary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isPast ? 0.28 : 1.0)
        .background {
            if isNext {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(gold.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(gold.opacity(0.20), lineWidth: 1)
                    )
            }
        }
    }

    private var adhaanPill: some View {
        let isSet = selectedAdhaan.id != "silent"
        return Text(isSet ? selectedAdhaan.shortName : "No adhaan")
            .font(.caption.weight(.medium))
            .foregroundStyle(isSet ? gold : Color.secondary.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isSet ? gold.opacity(0.12) : Color.secondary.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSet ? gold.opacity(0.30) : Color.secondary.opacity(0.15),
                                  lineWidth: 0.5)
            )
    }

    private var alertPill: some View {
        let isSet = selectedAdhaan.id != "silent"
        return Text(isSet ? selectedAdhaan.shortName : "No alert")
            .font(.caption.weight(.medium))
            .foregroundStyle(isSet ? Color.orange : Color.orange.opacity(0.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.orange.opacity(0.08)))
            .overlay(Capsule().strokeBorder(Color.orange.opacity(0.20), lineWidth: 0.5))
    }

    private var iconName: String {
        switch name {
        case "Fajr": return "moon.stars.fill"
        case "Sunrise": return "sunrise.fill"
        case "Dhuhr": return "sun.max.fill"
        case "Asr": return "sun.haze.fill"
        case "Maghrib": return "sunset.fill"
        case "Isha": return "moon.fill"
        default: return "clock"
        }
    }
}
```

- [ ] **Step 2: Create `AdhaanChipTray` in the same file**

Append to `iqamah/iOS/PrayerRowMobileView.swift`:

```swift

// MARK: - Adhaan Chip Tray

/// Inline chip picker that expands below a prayer row.
/// Standard prayers: alert tones + adhaan recordings + Mute.
/// Sunrise: alert tones only, no adhaan recordings, no Mute.
/// Fajr: alert tones + Fajr adhaan recordings + standard adhaan recordings.
struct AdhaanChipTray: View {
    let prayerName: String
    let selectedAdhaan: Adhaan
    let onSelectAdhaan: (Adhaan) -> Void
    let onToggleMute: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var gold: Color { colorScheme == .dark ? .appGold : .appGoldDark }

    private var isSunrise: Bool { prayerName == "Sunrise" }
    private var isFajr: Bool { prayerName == "Fajr" }

    private var alertTones: [Adhaan] { Adhaan.alertTones }
    private var adhaanRecordings: [Adhaan] {
        if isSunrise { return [] }
        if isFajr { return Adhaan.adhaanFajrRecordings + Adhaan.adhaanRecordings }
        return Adhaan.adhaanRecordings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Alert tones section
            chipSection(
                label: "🔔 Alert tones",
                chips: [.silent] + alertTones,
                accent: .orange,
                silentLabel: isSunrise ? "No alert" : nil
            )

            // Adhaan recordings section (prayers only)
            if !adhaanRecordings.isEmpty {
                chipSection(
                    label: "🕌 Adhaan",
                    chips: adhaanRecordings,
                    accent: gold,
                    silentLabel: nil
                )

                // Mute chip
                Button(action: onToggleMute) {
                    Label("Mute", systemImage: "speaker.slash.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.red.opacity(0.08)))
                        .overlay(Capsule().strokeBorder(Color.red.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    private func chipSection(
        label: String,
        chips: [Adhaan],
        accent: Color,
        silentLabel: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78, maximum: 120))],
                      alignment: .leading, spacing: 5) {
                ForEach(chips) { adhaan in
                    let isSelected = selectedAdhaan.id == adhaan.id
                    let displayName: String = {
                        if adhaan.id == "silent" { return silentLabel ?? "No adhaan" }
                        return adhaan.shortName
                    }()
                    Button(action: { onSelectAdhaan(adhaan) }) {
                        Text(displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(isSelected ? .white : accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(isSelected ? accent : accent.opacity(0.08)))
                            .overlay(Capsule().strokeBorder(
                                accent.opacity(isSelected ? 0 : 0.25), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Add `PrayerRowMobileView.swift` to Xcode iOS target**

```bash
cd /Users/Kamal_Syed/Projects/iqamah/iqamah
python3 - << 'EOF'
with open("iqamah.xcodeproj/project.pbxproj") as f:
    content = f.read()

if "PrayerRowMobileView.swift" in content:
    print("Already present")
else:
    fr = '\n\t\tHC000000000000000000003 /* PrayerRowMobileView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PrayerRowMobileView.swift; sourceTree = "<group>"; };'
    content = content.replace("/* End PBXFileReference section */",
                               fr + "\n\t\t/* End PBXFileReference section */")
    bf = '\n\t\tHC000000000000000000004 /* PrayerRowMobileView.swift in Sources */ = {isa = PBXBuildFile; fileRef = HC000000000000000000003 /* PrayerRowMobileView.swift */; };'
    content = content.replace("/* End PBXBuildFile section */",
                               bf + "\n\t\t/* End PBXBuildFile section */")
    content = content.replace(
        "HC000000000000000000002 /* PrayerHeroCard.swift in Sources */,",
        "HC000000000000000000002 /* PrayerHeroCard.swift in Sources */,\n\t\t\t\tHC000000000000000000004 /* PrayerRowMobileView.swift in Sources */,"
    )
    content = content.replace(
        "HC000000000000000000001 /* PrayerHeroCard.swift */,",
        "HC000000000000000000001 /* PrayerHeroCard.swift */,\n\t\t\t\tHC000000000000000000003 /* PrayerRowMobileView.swift */,"
    )
    with open("iqamah.xcodeproj/project.pbxproj", "w") as f:
        f.write(content)
    print("Added PrayerRowMobileView.swift to iOS target")
EOF
```

- [ ] **Step 4: Build iOS**

```bash
xcodebuild -project iqamah.xcodeproj -scheme "iqamah-iOS" -configuration Debug \
  -destination 'platform=iOS Simulator,id=EEDE8413-6F50-443B-97C1-7666DDEBD2F1' \
  -allowProvisioningUpdates build 2>&1 | grep -E "BUILD|error:" | grep -v "^---" | head -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add iqamah/iOS/PrayerRowMobileView.swift iqamah.xcodeproj/project.pbxproj
git commit -m "feat(EPIC-0014): PrayerRowMobileView + AdhaanChipTray — compact iOS prayer row (US-0062)"
```

---

## Task 4: Wire iOS mobile rows into `PrayerTimesTable`

**Files:**
- Modify: `iqamah/Views/PrayerTimesComponents.swift`

`PrayerTimesTable` currently uses `PrayerTimeRow` (macOS-native wide row) and `SunriseRow` (no controls). On iOS, switch to `PrayerRowMobileView`. Add a `dayOffset` parameter so two-column iPad landscape can share expand state across columns.

- [ ] **Step 1: Add `PrayerRowID` and update state in `PrayerTimesTable`**

In `iqamah/Views/PrayerTimesComponents.swift`, replace the beginning of `PrayerTimesTable`:

```swift
// MARK: - Prayer Times Table

/// Identifies a unique row across two columns (today/tomorrow).
struct PrayerRowID: Hashable {
    let dayOffset: Int   // 0 = today, 1 = tomorrow
    let name: String
}

struct PrayerTimesTable: View {
    let prayerTimes: PrayerTimes
    let timezone: TimeZone
    /// 0 = today, 1 = tomorrow. Used in iPad landscape two-column layout.
    var dayOffset: Int = 0
    /// Shared across columns in iPad landscape so only one row is open at a time.
    @Binding var expandedRowID: PrayerRowID?

    @State private var adjustments: [String: Int] = [:]
    @State private var adhaanSelections: [String: Adhaan] = [:]
    @State private var prayerMuted: [String: Bool] = [:]
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var player = AdhaaanPlayer.shared
```

> **Note:** `PrayerTimesTable` now takes a `@Binding var expandedRowID`. Call sites that own the state will pass `$expandedRowID`; call sites in macOS can pass `.constant(nil)`.

- [ ] **Step 2: Replace the `body` ForEach in `PrayerTimesTable`**

Replace the `body` property (the `VStack(spacing: 1)` block):

```swift
    var body: some View {
        VStack(spacing: 1) {
            ForEach(prayerTimes.prayers, id: \.name) { prayer in
                let isSunrise = prayer.name == "Sunrise"
                let adjusted = adjustedTime(for: prayer)
                let rowID = PrayerRowID(dayOffset: dayOffset, name: prayer.name)

                #if os(iOS)
                PrayerRowMobileView(
                    name: prayer.name,
                    time: adjusted,
                    formatter: timeFormatter,
                    isPast: adjusted < Date(),
                    isNext: isNextPrayer(adjustedTime: adjusted),
                    selectedAdhaan: adhaanSelections[prayer.name] ?? .silent,
                    isExpanded: expandedRowID == rowID,
                    onTap: {
                        withAnimation(.spring(duration: 0.25)) {
                            expandedRowID = expandedRowID == rowID ? nil : rowID
                        }
                    },
                    onSelectAdhaan: { adhaan in
                        adhaanSelections[prayer.name] = adhaan
                        settingsManager.setAdhaan(adhaan, for: prayer.name)
                        withAnimation(.spring(duration: 0.2)) { expandedRowID = nil }
                    },
                    onToggleMute: {
                        let muted = !(prayerMuted[prayer.name] ?? false)
                        prayerMuted[prayer.name] = muted
                        settingsManager.setPrayerMuted(muted, for: prayer.name)
                        withAnimation(.spring(duration: 0.2)) { expandedRowID = nil }
                    }
                )
                #else
                if isSunrise {
                    SunriseRow(time: adjusted, formatter: timeFormatter)
                } else {
                    PrayerTimeRow(
                        name: prayer.name,
                        time: adjusted,
                        formatter: timeFormatter,
                        adjustment: adjustments[prayer.name] ?? 0,
                        selectedAdhaan: Binding(
                            get: { adhaanSelections[prayer.name] ?? .silent },
                            set: { newAdhaan in
                                adhaanSelections[prayer.name] = newAdhaan
                                settingsManager.setAdhaan(newAdhaan, for: prayer.name)
                            }
                        ),
                        isPrayerMuted: Binding(
                            get: { prayerMuted[prayer.name] ?? false },
                            set: { muted in
                                prayerMuted[prayer.name] = muted
                                settingsManager.setPrayerMuted(muted, for: prayer.name)
                            }
                        ),
                        isHighlighted: isNextPrayer(adjustedTime: adjusted),
                        isPickerExpanded: expandedRowID?.name == prayer.name,
                        onTogglePicker: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                let rid = PrayerRowID(dayOffset: dayOffset, name: prayer.name)
                                expandedRowID = expandedRowID == rid ? nil : rid
                            }
                        },
                        onAdjust: { delta in adjustPrayerTime(for: prayer.name, delta: delta) }
                    )
                }
                #endif
            }
        }
        .onAppear { loadAdjustments() }
```

- [ ] **Step 3: Update the reset button block**

The reset button and remaining helpers stay the same. Only add `timeFormatter` if it isn't already a computed property:

Check that `PrayerTimesTable` has this computed property (it should already):
```swift
    private var timeFormatter: DateFormatter {
        PrayerTimes.timeFormatter(for: timezone, use24Hour: settingsManager.use24HourTime)
    }
```

- [ ] **Step 4: Fix the existing `PrayerTimesTable` call site in `PrayerTimesView`**

The current call in `PrayerTimesView.swift` is:
```swift
PrayerTimesTable(prayerTimes: prayerTimes, timezone: TimeZone(identifier: city.timezone) ?? .current)
```

This will no longer compile because `expandedRowID` binding is now required. You will fix this in Task 5. For now, add a temporary `@State` to `PrayerTimesTable` itself as a workaround so the macOS build doesn't break immediately:

Add this **after** the `@Binding var expandedRowID` declaration:
```swift
    /// Convenience initialiser for call sites that don't need shared expand state (macOS).
    init(prayerTimes: PrayerTimes, timezone: TimeZone, dayOffset: Int = 0,
         expandedRowID: Binding<PrayerRowID?> = .constant(nil)) {
        self.prayerTimes = prayerTimes
        self.timezone = timezone
        self.dayOffset = dayOffset
        self._expandedRowID = expandedRowID
    }
```

- [ ] **Step 5: Build both targets**

```bash
# macOS
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "BUILD|error:" | grep -v "^---" | head -5

# iOS
xcodebuild -project iqamah.xcodeproj -scheme "iqamah-iOS" -configuration Debug \
  -destination 'platform=iOS Simulator,id=EEDE8413-6F50-443B-97C1-7666DDEBD2F1' \
  -allowProvisioningUpdates build 2>&1 | grep -E "BUILD|error:" | grep -v "^---" | head -5
```
Both: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add iqamah/Views/PrayerTimesComponents.swift
git commit -m "feat(EPIC-0014): wire PrayerRowMobileView into PrayerTimesTable — iOS expand-on-tap (US-0062)"
```

---

## Task 5: iPhone + iPad portrait layout in `PrayerTimesView`

**Files:**
- Modify: `iqamah/Views/PrayerTimesView.swift`

Remove the macOS frame constraint on iOS, add `@Environment(\.horizontalSizeClass)`, wrap the iOS body in a `ScrollView`, and slot in the `PrayerHeroCard`.

- [ ] **Step 1: Add environment and state to `PrayerTimesView`**

In `PrayerTimesView.swift`, add these properties after the existing `@State` declarations:

```swift
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var expandedRowID: PrayerRowID? = nil
    @State private var tomorrowPrayerTimes: PrayerTimes? = nil
```

- [ ] **Step 2: Add `nextPrayerTime` computed property**

After the `hijriDateLabel` computed property (around line 240), add:

```swift
    private var nextPrayerTime: Date? {
        prayerTimes?.prayers
            .first(where: { adjustedPrayerTime($0) > Date() && $0.name != "Sunrise" })
            .map { adjustedPrayerTime($0) }
    }

    private func adjustedPrayerTime(_ prayer: (name: String, time: Date)) -> Date {
        let adj = settingsStore.getAdjustment(for: prayer.name)
        return Calendar.current.date(byAdding: .minute, value: adj, to: prayer.time) ?? prayer.time
    }
```

- [ ] **Step 3: Add `calculateTomorrowPrayerTimes()`**

After `calculatePrayerTimes()`:

```swift
    private func calculateTomorrowPrayerTimes() {
        let timezone = TimeZone(identifier: city.timezone) ?? .current
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        let calculator = PrayerCalculator(
            coordinate: city.coordinate,
            timezone: timezone,
            method: calculationMethod,
            asrMethod: asrMethod
        )
        tomorrowPrayerTimes = try? calculator.calculate(for: tomorrow)
    }
```

- [ ] **Step 4: Replace the `body` with platform-conditional layout**

Replace the entire `body` property:

```swift
    var body: some View {
        #if os(iOS)
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let isRegular = hSizeClass == .regular
            if isRegular && isLandscape {
                iPadLandscapeBody
            } else {
                portraitBody
            }
        }
        .sheet(isPresented: $showAbout) { AboutView() }
        .onAppear {
            calculatePrayerTimes()
            calculateTomorrowPrayerTimes()
            timerSubscription = timer.connect()
        }
        .onDisappear { timerSubscription?.cancel(); timerSubscription = nil }
        .onReceive(timer) { _ in updateDate() }
        #else
        macOSBody
        #endif
    }
```

- [ ] **Step 5: Add `portraitBody` (iPhone + iPad portrait)**

Add this computed property:

```swift
    @ViewBuilder
    private var portraitBody: some View {
        ScrollView {
            VStack(spacing: 0) {
                primaryHeader
                secondaryToolbarAboutOnly
                if let times = prayerTimes {
                    let tz = TimeZone(identifier: city.timezone) ?? .current
                    PrayerHeroCard(
                        moonPhase: currentMoonPhase,
                        hijriDateLabel: hijriDateLabel,
                        moonPhaseSubtitle: moonPhaseSubtitle,
                        isHilalWatchEvening: isHilalWatchEvening,
                        nextPrayerTime: nextPrayerTime,
                        onHilalWatch: openHilalWatch
                    )
                    Text(currentDate.formattedGregorianDate())
                        .font(.subheadline.bold())
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.06))
                    PrayerTimesTable(
                        prayerTimes: times,
                        timezone: tz,
                        dayOffset: 0,
                        expandedRowID: $expandedRowID
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                } else {
                    ProgressView().padding(.vertical, 40)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
```

- [ ] **Step 6: Extract `primaryHeader` and `secondaryToolbarAboutOnly` from the existing body**

The existing `HStack` blocks for the header and secondary toolbar are already in the body. Extract them as computed properties:

```swift
    /// Shared header: app icon, brand name, city, method, mute toggle.
    @ViewBuilder private var primaryHeader: some View {
        HStack(spacing: 12) {
            Image("AppIcon")
                .resizable()
                .frame(width: 48, height: 48)
                .shadow(color: Color.primary.opacity(0.10), radius: 3, x: 0, y: 1)
            Text("Iqamah")
                .font(.system(size: titleFontSize, weight: .bold, design: .serif))
                .foregroundStyle(LinearGradient(
                    colors: [Color.appGoldDim, Color(red: 0.85, green: 0.65, blue: 0.13)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(calculationMethod.shortName)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { AdhaaanPlayer.shared.toggleMute() }) {
                Image(systemName: AdhaaanPlayer.shared.isMuted
                      ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title3)
                    .foregroundColor(AdhaaanPlayer.shared.isMuted ? .secondary : .accentColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background { Rectangle().fill(.ultraThinMaterial) }
    }

    /// iOS-only toolbar: About only (Qiblah + Settings are in the tab bar).
    @ViewBuilder private var secondaryToolbarAboutOnly: some View {
        HStack(spacing: 0) {
            SecondaryToolbarButton(
                label: "About",
                systemImage: "info.circle",
                action: { showAbout = true }
            )
            Spacer()
        }
        .background { Rectangle().fill(.ultraThinMaterial) }
    }
```

- [ ] **Step 7: Move the macOS body into a `macOSBody` computed property**

Take the entire existing body that was in `PrayerTimesView` (the `VStack(spacing: 0)` with `.frame(minWidth: 580...)`) and put it in:

```swift
    @ViewBuilder private var macOSBody: some View {
        VStack(spacing: 0) {
            // ── Primary header ───────────────────────────────────
            HStack(spacing: 12) {
                Image("AppIcon")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.primary.opacity(0.10), radius: 3, x: 0, y: 1)
                Text("Iqamah")
                    .font(.system(size: titleFontSize, weight: .bold, design: .serif))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.appGoldDim, Color(red: 0.85, green: 0.65, blue: 0.13)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name).font(.title3.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.85)
                    Text(calculationMethod.shortName).font(.caption.weight(.medium)).foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { AdhaaanPlayer.shared.toggleMute() }) {
                    Image(systemName: AdhaaanPlayer.shared.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundColor(AdhaaanPlayer.shared.isMuted ? .secondary : .accentColor)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help(AdhaaanPlayer.shared.isMuted ? "Unmute Adhaan" : "Mute Adhaan")
            }
            .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 10)
            .background { Rectangle().fill(.ultraThinMaterial) }

            // ── Secondary toolbar (macOS: Qiblah, Settings, About) ──
            HStack(spacing: 0) {
                SecondaryToolbarButton(label: "Qiblah", systemImage: "location.north.line.fill",
                                       action: { showQiblah = true })
                SecondaryToolbarButton(label: "Settings", systemImage: "gearshape",
                                       action: { showSettings = true })
                    .keyboardShortcut(",", modifiers: .command)
                SecondaryToolbarButton(label: "About", systemImage: "info.circle",
                                       action: { showAbout = true })
                Spacer()
            }
            .background { Rectangle().fill(.ultraThinMaterial) }

            // ── Moon / Hilal Watch ──
            HStack(spacing: 12) {
                MoonPhaseView(phase: currentMoonPhase, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(hijriDateLabel).font(.subheadline)
                    Text(isHilalWatchEvening ? "Hilal Watch tonight" : moonPhaseSubtitle)
                        .font(.caption).foregroundStyle(isHilalWatchEvening ? .orange : .secondary)
                }
                Spacer()
                Button("Details") { openHilalWatch() }.buttonStyle(.borderless).font(.caption)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background { Rectangle().fill(.ultraThinMaterial) }

            Divider()

            Text(currentDate.formattedGregorianDate())
                .font(.subheadline.bold()).padding(.vertical, 12).frame(maxWidth: .infinity)
                .background { Rectangle().fill(.ultraThinMaterial.opacity(0.6)) }

            if let prayerTimes {
                PrayerTimesTable(
                    prayerTimes: prayerTimes,
                    timezone: TimeZone(identifier: city.timezone) ?? .current
                )
                .padding(.horizontal, 24).padding(.bottom, 24)
            } else {
                ProgressView().padding(.vertical, 40)
            }
            Spacer(minLength: 0)
        }
        .frame(minWidth: 580, idealWidth: 620, minHeight: 640, idealHeight: 680)
        .sheet(isPresented: $showQiblah) {
            QiblahView(latitude: city.latitude, longitude: city.longitude, cityName: city.name)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView(
                currentCity: city, currentMethod: calculationMethod, currentAsrMethod: asrMethod,
                onSave: { newCity, newMethod, newAsr in
                    showSettings = false; onSettingsSaved(newCity, newMethod, newAsr)
                },
                onCancel: { showSettings = false }
            )
        }
        .sheet(isPresented: $showAbout) { AboutView() }
        .onAppear { calculatePrayerTimes(); timerSubscription = timer.connect() }
        .onDisappear { timerSubscription?.cancel(); timerSubscription = nil }
        .onReceive(timer) { _ in updateDate() }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in showSettings = true }
    }
```

- [ ] **Step 8: Build both platforms**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "BUILD|error:" | grep -v "^---" | head -5

xcodebuild -project iqamah.xcodeproj -scheme "iqamah-iOS" -configuration Debug \
  -destination 'platform=iOS Simulator,id=EEDE8413-6F50-443B-97C1-7666DDEBD2F1' \
  -allowProvisioningUpdates build 2>&1 | grep -E "BUILD|error:" | grep -v "^---" | head -5
```
Both: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Install and smoke-test on iPhone 17 sim**

```bash
APP="/tmp/iqamah-ios-build/Build/Products/Debug-iphonesimulator/iqamah-iOS.app"
xcodebuild -project iqamah.xcodeproj -scheme "iqamah-iOS" -configuration Debug \
  -destination 'platform=iOS Simulator,id=EEDE8413-6F50-443B-97C1-7666DDEBD2F1' \
  -derivedDataPath /tmp/iqamah-ios-build -allowProvisioningUpdates build 2>&1 | tail -3
xcrun simctl terminate EEDE8413-6F50-443B-97C1-7666DDEBD2F1 com.fablesoft.iqamah 2>/dev/null; true
xcrun simctl install EEDE8413-6F50-443B-97C1-7666DDEBD2F1 "$APP"
xcrun simctl launch EEDE8413-6F50-443B-97C1-7666DDEBD2F1 com.fablesoft.iqamah
```

Verify on simulator:
- All 6 prayer rows visible without horizontal scrolling (AC-0276)
- Hero card visible above prayer list (AC-0277)
- Countdown timer ticking in hero card (AC-0278)
- Tapping a prayer row expands chip tray (AC-0285/0286)

- [ ] **Step 10: Commit**

```bash
git add iqamah/Views/PrayerTimesView.swift
git commit -m "feat(EPIC-0014): iPhone + iPad portrait adaptive layout — hero card, remove frame constraint (US-0061)"
```

---

## Task 6: iPad landscape layout — two-column today/tomorrow

**Files:**
- Modify: `iqamah/Views/PrayerTimesView.swift`

Add `iPadLandscapeBody` with the full-width header and today/tomorrow split.

- [ ] **Step 1: Add `iPadLandscapeBody` computed property**

```swift
    @ViewBuilder
    private var iPadLandscapeBody: some View {
        let tz = TimeZone(identifier: city.timezone) ?? .current
        VStack(spacing: 0) {
            // Full-width landscape header
            HStack(spacing: 16) {
                Image("AppIcon").resizable().frame(width: 36, height: 36)
                    .shadow(color: Color.primary.opacity(0.10), radius: 2)
                Text("Iqamah")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.appGoldDim, Color(red: 0.85, green: 0.65, blue: 0.13)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(alignment: .leading, spacing: 1) {
                    Text(city.name).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(calculationMethod.shortName).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                MoonPhaseView(phase: currentMoonPhase, size: 32)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(hijriDateLabel).font(.caption.weight(.medium))
                    Text(moonPhaseSubtitle).font(.caption2).foregroundStyle(.secondary)
                }
                if let nextTime = nextPrayerTime {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(nextTime, style: .timer)
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(Color.appGoldDim)
                        Text("until next").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Button(action: { AdhaaanPlayer.shared.toggleMute() }) {
                    Image(systemName: AdhaaanPlayer.shared.isMuted
                          ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.body)
                        .foregroundColor(AdhaaanPlayer.shared.isMuted ? .secondary : .accentColor)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background { Rectangle().fill(.ultraThinMaterial) }

            // Two columns: today | tomorrow
            HStack(alignment: .top, spacing: 0) {
                // Today
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("Today · \(currentDate.formattedGregorianDate())")
                        if let times = prayerTimes {
                            PrayerTimesTable(
                                prayerTimes: times,
                                timezone: tz,
                                dayOffset: 0,
                                expandedRowID: $expandedRowID
                            )
                            .padding(.horizontal, 12).padding(.bottom, 12)
                        }
                        Button(action: openHilalWatch) {
                            Label("Hilal Watch", systemImage: "moon.haze.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appGoldDim)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16).padding(.bottom, 12)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider()

                // Tomorrow
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        let tomorrow = Calendar.current.date(
                            byAdding: .day, value: 1, to: currentDate) ?? currentDate
                        sectionHeader("Tomorrow · \(tomorrow.formattedGregorianDate())")
                        if let times = tomorrowPrayerTimes {
                            PrayerTimesTable(
                                prayerTimes: times,
                                timezone: tz,
                                dayOffset: 1,
                                expandedRowID: $expandedRowID
                            )
                            .padding(.horizontal, 12).padding(.bottom, 12)
                        } else {
                            ProgressView().padding(.vertical, 20)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }
```

- [ ] **Step 2: Wire `calculateTomorrowPrayerTimes` into `onAppear` and timer**

Update the iOS `body` `.onAppear` call to also compute tomorrow:

In the `#if os(iOS)` body section `.onAppear`:
```swift
        .onAppear {
            calculatePrayerTimes()
            calculateTomorrowPrayerTimes()
            timerSubscription = timer.connect()
        }
```

And in `updateDate()`, after `calculatePrayerTimes()`:
```swift
    private func updateDate() {
        let newDate = Date()
        let calendar = Calendar.current
        if !calendar.isDate(newDate, inSameDayAs: currentDate) {
            currentDate = newDate
            calculatePrayerTimes()
            calculateTomorrowPrayerTimes()
        } else {
            currentDate = newDate
        }
    }
```

- [ ] **Step 3: Build and install on iPad simulator**

```bash
xcodebuild -project iqamah.xcodeproj -scheme "iqamah-iOS" -configuration Debug \
  -destination 'platform=iOS Simulator,id=07B8F745-CE6A-45F2-82B2-4FF19F89482E' \
  -derivedDataPath /tmp/iqamah-ios-build -allowProvisioningUpdates build 2>&1 | tail -3

APP="/tmp/iqamah-ios-build/Build/Products/Debug-iphonesimulator/iqamah-iOS.app"
xcrun simctl terminate 07B8F745-CE6A-45F2-82B2-4FF19F89482E com.fablesoft.iqamah 2>/dev/null; true
xcrun simctl install 07B8F745-CE6A-45F2-82B2-4FF19F89482E "$APP"
xcrun simctl launch 07B8F745-CE6A-45F2-82B2-4FF19F89482E com.fablesoft.iqamah
```

Rotate the iPad to landscape in the simulator (Device menu → Rotate Left). Verify:
- Two-column layout with today and tomorrow (AC-0280)
- Full-width header with moon and countdown (AC-0283)
- Chip tray works in both columns; only one open at a time (AC-0281/0282)

- [ ] **Step 4: Commit**

```bash
git add iqamah/Views/PrayerTimesView.swift
git commit -m "feat(EPIC-0014): iPad landscape two-column layout — today/tomorrow with shared expand state (US-0061)"
```

---

## Task 7: `QiblahCompassView` — GeometryReader + centered mat

**Files:**
- Modify: `iqamah/Views/QiblahView.swift`

Extract a `QiblahCompassView(diameter:bearing:)` struct from the existing compass `ZStack`. Replace all hardcoded `320`, `380`, `440` frames with values derived from `diameter`. Center the prayer mat.

- [ ] **Step 1: Extract `QiblahCompassView`**

After the `Triangle` struct at the bottom of `QiblahView.swift`, add:

```swift
// MARK: - Scalable Compass

/// Self-contained compass that scales to any diameter.
/// All element sizes are proportional to the radius (diameter / 2).
private struct QiblahCompassView: View {
    let diameter: CGFloat
    let bearing: Double

    private var r: CGFloat { diameter / 2 }

    var body: some View {
        ZStack {
            // ── Bezel ring ──────────────────────────────────────────
            Circle()
                .fill(Color.primary.opacity(0.05))
                .frame(width: diameter, height: diameter)
            Circle()
                .stroke(Color.primary.opacity(0.18), lineWidth: 2)
                .frame(width: diameter, height: diameter)

            // ── Tick marks (72 × 5° = 360°) ─────────────────────────
            ForEach(0 ..< 72, id: \.self) { i in
                let angle = Double(i) * 5
                let isCardinal = i % 18 == 0
                let isSemiCard = i % 9 == 0 && !isCardinal
                let isMedium   = i % 2 == 0 && !isCardinal && !isSemiCard
                let tickLen: CGFloat = isCardinal ? r * 0.14
                    : isSemiCard ? r * 0.09
                    : isMedium   ? r * 0.06
                    : r * 0.032
                let tickW: CGFloat = isCardinal ? 2.5 : isSemiCard ? 1.5 : 1.0
                let opacity: Double = isCardinal ? 0.90 : isSemiCard ? 0.60
                    : isMedium ? 0.35 : 0.20
                Rectangle()
                    .fill(Color.primary.opacity(opacity))
                    .frame(width: tickW, height: tickLen)
                    .offset(y: -(r - tickLen / 2))
                    .rotationEffect(.degrees(angle))
                    .accessibilityHidden(true)
            }

            // ── Degree labels at 45 / 135 / 225 / 315 ───────────────
            ForEach([(45.0, "45"), (135.0, "135"), (225.0, "225"), (315.0, "315")], id: \.1) { angle, label in
                Text(label)
                    .font(.system(size: max(7, r * 0.056), weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.50))
                    .offset(
                        x: r * 0.86 * CGFloat(sin(angle * .pi / 180)),
                        y: -r * 0.86 * CGFloat(cos(angle * .pi / 180))
                    )
                    .accessibilityHidden(true)
            }

            // ── Cardinal labels ─────────────────────────────────────
            ForEach([("N", 0.0), ("E", 90.0), ("S", 180.0), ("W", 270.0)], id: \.0) { label, angle in
                Text(label)
                    .font(.system(size: max(10, r * 0.088), weight: .bold))
                    .foregroundColor(
                        label == "N"
                            ? Color(red: 0.95, green: 0.28, blue: 0.22)
                            : .primary.opacity(0.70)
                    )
                    .offset(
                        x: r * 0.86 * CGFloat(sin(angle * .pi / 180)),
                        y: -r * 0.86 * CGFloat(cos(angle * .pi / 180))
                    )
                    .accessibilityHidden(true)
            }

            // ── N triangle marker ────────────────────────────────────
            Triangle()
                .fill(Color(red: 0.95, green: 0.28, blue: 0.22))
                .frame(width: r * 0.063, height: r * 0.063)
                .offset(y: -(r * 0.963))
                .accessibilityHidden(true)

            // ── Dashed gold needle from center to ring ───────────────
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                let rad = bearing * .pi / 180
                let needleR = Double(r) - 20
                let x2 = cx + CGFloat(sin(rad) * needleR)
                let y2 = cy - CGFloat(cos(rad) * needleR)
                var path = Path()
                path.move(to: CGPoint(x: cx, y: cy))
                path.addLine(to: CGPoint(x: x2, y: y2))
                ctx.stroke(path, with: .color(Color.appGold.opacity(0.80)),
                           style: StrokeStyle(lineWidth: 2, dash: [6, 4], dashPhase: 0))
                // Arrowhead
                let backLen: Double = Double(r) * 0.065
                let perpAngle = rad + .pi / 2
                let baseX = x2 - CGFloat(sin(rad) * backLen)
                let baseY = y2 + CGFloat(cos(rad) * backLen)
                let left  = CGPoint(x: baseX + CGFloat(cos(perpAngle) * backLen * 0.4),
                                    y: baseY + CGFloat(sin(perpAngle) * backLen * 0.4))
                let right = CGPoint(x: baseX - CGFloat(cos(perpAngle) * backLen * 0.4),
                                    y: baseY - CGFloat(sin(perpAngle) * backLen * 0.4))
                var arrow = Path()
                arrow.move(to: CGPoint(x: x2, y: y2))
                arrow.addLine(to: left)
                arrow.addLine(to: right)
                arrow.closeSubpath()
                ctx.fill(arrow, with: .color(Color.appGold.opacity(0.90)))
            }
            .frame(width: diameter, height: diameter)
            .accessibilityHidden(true)

            // ── Prayer mat — CENTERED, rotated to Qibla ─────────────
            // Mat is the centerpiece: you stand here and face the direction the needle points.
            let matW = r * 0.24
            let matH = r * 0.32
            Image("PrayerMat")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: matW, height: matH)
                .drawingGroup()
                .rotationEffect(.degrees(bearing))
                .accessibilityLabel("Prayer mat facing Qiblah direction")

            // ── Ka'bah icon at ring edge ─────────────────────────────
            let kaabahSize = r * 0.18
            let kaabahR    = r * 0.925
            Image("KaabahIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: kaabahSize, height: kaabahSize)
                .drawingGroup()
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.appGold, lineWidth: 2))
                .shadow(color: Color.appGold.opacity(0.45), radius: 4)
                .offset(
                    x: kaabahR * CGFloat(sin(bearing * .pi / 180)),
                    y: -kaabahR * CGFloat(cos(bearing * .pi / 180))
                )
                .accessibilityLabel("Ka'bah direction marker")

            // ── Centre pivot dot ─────────────────────────────────────
            Circle()
                .fill(Color.secondary.opacity(0.45))
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Qibla compass")
    }
}
```

- [ ] **Step 2: Replace `compassView` to use `QiblahCompassView` with `GeometryReader`**

Replace the entire `compassView` computed property in `QiblahView`:

```swift
    private var compassView: some View {
        VStack(spacing: 0) {
            Text("Qiblah Direction")
                .font(.title2.bold())
                .padding(.top, 20)
                .accessibilityAddTraits(.isHeader)
            Text(String(format: "%.1f° %@", qiblahBearing, cardinalDirection))
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .padding(.top, 4)
                .accessibilityLabel("Qiblah: \(Int(qiblahBearing)) degrees \(cardinalDirection)")
            if !cityName.isEmpty {
                Text("from \(cityName)")
                    .font(.caption).foregroundColor(.secondary).padding(.top, 2)
            }

            GeometryReader { geo in
                let diameter = min(geo.size.width, geo.size.height) * 0.85
                ZStack {
                    QiblahCompassView(diameter: diameter, bearing: qiblahBearing)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .accessibilityLabel("Qiblah direction: \(Int(qiblahBearing)) degrees \(cardinalDirection(for: qiblahBearing))")
            .accessibilityValue("Face \(cardinalDirection(for: qiblahBearing)) to face Mecca")

            #if os(macOS)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.appGold)
                .controlSize(.regular)
                .padding(.bottom, 24)
                .padding(.top, 8)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 480)
        #endif
        .background { Rectangle().fill(.regularMaterial) }
    }
```

> Remove the old `.frame(width: 440, height: 560)` — the new view uses `maxWidth/maxHeight: .infinity`.

- [ ] **Step 3: Remove the old hardcoded ZStack inside `compassView`**

Verify the old ZStack (with `Circle().frame(width: 320)`, the old Canvas, and `Image("PrayerMat").frame(width: 72, height: 108)` positioned at the needle tip) has been completely replaced by `QiblahCompassView`.

- [ ] **Step 4: Build both platforms**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "BUILD|error:" | grep -v "^---" | head -5

xcodebuild -project iqamah.xcodeproj -scheme "iqamah-iOS" -configuration Debug \
  -destination 'platform=iOS Simulator,id=EEDE8413-6F50-443B-97C1-7666DDEBD2F1' \
  -allowProvisioningUpdates build 2>&1 | grep -E "BUILD|error:" | grep -v "^---" | head -5
```
Both: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add iqamah/Views/QiblahView.swift
git commit -m "feat(EPIC-0014): scalable QiblahCompassView via GeometryReader — centered mat, proportional elements (US-0063)"
```

---

## Task 8: iPad landscape Qibla info panel

**Files:**
- Modify: `iqamah/Views/QiblahView.swift`

On iPad landscape, show compass on the left and a bearing/city info panel on the right.

- [ ] **Step 1: Add `horizontalSizeClass` environment to `QiblahView`**

Add at the top of `QiblahView`'s properties:

```swift
    @Environment(\.horizontalSizeClass) private var hSizeClass
```

- [ ] **Step 2: Replace `compassView` body to branch on iPad landscape**

Update `compassView` to detect iPad landscape and show the info panel:

```swift
    private var compassView: some View {
        #if os(iOS)
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let isRegular = hSizeClass == .regular
            if isRegular && isLandscape {
                iPadLandscapeLayout(geo: geo)
            } else {
                portraitCompass(geo: geo)
            }
        }
        .background { Rectangle().fill(.regularMaterial) }
        #else
        macOSCompass
        #endif
    }

    @ViewBuilder
    private func portraitCompass(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            compassHeader
            GeometryReader { inner in
                let diameter = min(inner.size.width, inner.size.height) * 0.85
                QiblahCompassView(diameter: diameter, bearing: qiblahBearing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func iPadLandscapeLayout(geo: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Compass fills left portion
            GeometryReader { inner in
                let diameter = min(inner.size.width, inner.size.height) * 0.88
                QiblahCompassView(diameter: diameter, bearing: qiblahBearing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // Info panel
            let panelWidth = min(220, geo.size.width * 0.28)
            VStack(alignment: .leading, spacing: 20) {
                Spacer()
                infoPanelRow(label: "Bearing",
                             value: String(format: "%.1f°", qiblahBearing),
                             detail: cardinalDirection)
                infoPanelRow(label: "From",
                             value: cityName.isEmpty ? "—" : cityName,
                             detail: String(format: "%.4f°N · %.4f°E", latitude, longitude))
                infoPanelRow(label: "To",
                             value: "Makkah al-Mukarramah",
                             detail: "21.4225°N · 39.8262°E")
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(width: panelWidth)
            .background(Color.secondary.opacity(0.06))
        }
    }

    private func infoPanelRow(label: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Color.appGoldDim)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var compassHeader: some View {
        VStack(spacing: 3) {
            Text("Qiblah Direction")
                .font(.title2.bold())
                .padding(.top, 16)
                .accessibilityAddTraits(.isHeader)
            Text(String(format: "%.1f° %@", qiblahBearing, cardinalDirection))
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
            if !cityName.isEmpty {
                Text("from \(cityName)")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder private var macOSCompass: some View {
        VStack(spacing: 0) {
            compassHeader
            GeometryReader { geo in
                let diameter = min(geo.size.width, geo.size.height) * 0.85
                QiblahCompassView(diameter: diameter, bearing: qiblahBearing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.appGold)
                .controlSize(.regular)
                .padding(.bottom, 20)
                .padding(.top, 8)
        }
        .frame(minWidth: 380, minHeight: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Rectangle().fill(.regularMaterial) }
    }
```

- [ ] **Step 2: Build both platforms**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "BUILD|error:" | grep -v "^---" | head -5

xcodebuild -project iqamah.xcodeproj -scheme "iqamah-iOS" -configuration Debug \
  -destination 'platform=iOS Simulator,id=EEDE8413-6F50-443B-97C1-7666DDEBD2F1' \
  -allowProvisioningUpdates build 2>&1 | grep -E "BUILD|error:" | grep -v "^---" | head -5
```
Both: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Install on iPad and rotate to landscape**

```bash
APP="/tmp/iqamah-ios-build/Build/Products/Debug-iphonesimulator/iqamah-iOS.app"
xcrun simctl install 07B8F745-CE6A-45F2-82B2-4FF19F89482E "$APP"
xcrun simctl launch 07B8F745-CE6A-45F2-82B2-4FF19F89482E com.fablesoft.iqamah
```
Navigate to Qiblah tab. Rotate iPad to landscape. Verify info panel appears on the right (AC-0299).

- [ ] **Step 4: Run SwiftLint + SwiftFormat**

```bash
cd /Users/Kamal_Syed/Projects/iqamah/iqamah
swiftformat iqamah/Views/ iqamah/iOS/ 2>&1 | tail -3
swiftlint lint --quiet iqamah/Views/ iqamah/iOS/ 2>&1 | grep -v "^$" | head -10
```
Expected: No lint errors.

- [ ] **Step 5: Run full IqamahCore tests**

```bash
cd Packages/IqamahCore && swift test 2>&1 | tail -5
```
Expected: `Test Suite 'All tests' passed`

- [ ] **Step 6: Final commit**

```bash
cd /Users/Kamal_Syed/Projects/iqamah/iqamah
git add iqamah/Views/QiblahView.swift
git commit -m "feat(EPIC-0014): iPad landscape Qibla info panel + macOS GeometryReader compass (US-0063)"
```

---

## Task 9: PR, CI, and merge

- [ ] **Step 1: Create branch and push**

```bash
cd /Users/Kamal_Syed/Projects/iqamah/iqamah
# If on develop, branch first:
git checkout -b feat/EPIC-0014-adaptive-layout
git push -u origin feat/EPIC-0014-adaptive-layout
```

- [ ] **Step 2: Open PR**

```bash
gh pr create \
  --title "feat(EPIC-0014): Adaptive layout — iPhone/iPad/macOS prayer times + scalable Qibla compass" \
  --base develop \
  --body "$(cat <<'EOF'
## Summary

Implements EPIC-0014 — Adaptive Layout (US-0061–US-0063, AC-0276–AC-0300).

- **US-0061 Prayer times layout:**
  - iPhone: hero card (moon + Hijri + countdown + Hilal Watch) + single-column prayer list
  - iPad portrait: same as iPhone but larger
  - iPad landscape: full-width header + today/tomorrow two-column split with shared expand state
  - macOS: unchanged

- **US-0062 Adaptive prayer row (iOS):**
  - Compact default: icon · name · adhaan pill · time — no ±controls (Settings only)
  - Tap to expand inline chip tray with alert tones + adhaan recordings + Mute
  - Sunrise: amber "No alert" pill → alert-tone-only chip tray (Adhaan.availableForSunrise)

- **US-0063 Qibla compass:**
  - GeometryReader on all platforms — diameter = min(width, height) × 0.85
  - Prayer mat centered in compass, rotated to qibla, proportional to radius
  - iPad landscape: compass left + bearing/city/Makkah info panel right

## Test Plan
- [ ] iPhone 17 sim: all prayers visible; hero card; tap row → chip tray expands
- [ ] iPad Pro 11" portrait: hero card + single column
- [ ] iPad Pro 11" landscape: today/tomorrow split; chip tray shared across columns
- [ ] Qibla compass fills screen on all devices; mat centered; iPad landscape info panel
- [ ] macOS: prayer layout unchanged; compass scales with window

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Monitor CI**

```bash
gh pr checks <PR_NUMBER> --watch 2>&1 | tail -10
```

- [ ] **Step 4: Merge when green**

```bash
gh pr merge <PR_NUMBER> --squash --delete-branch
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| `Adhaan.availableForSunrise` | Task 1 |
| PrayerHeroCard view | Task 2 |
| Compact iOS row pill between name and time | Task 3 |
| Chip tray expand-on-tap | Task 3 |
| Sunrise amber pill + alert-only tray | Task 3 |
| `PrayerTimesTable` wired to mobile rows | Task 4 |
| Expand state shared across columns (PrayerRowID) | Task 4 |
| iPhone portrait layout + remove frame constraint | Task 5 |
| iPad portrait layout (hero card + single col) | Task 5 |
| iPad landscape two-column today/tomorrow | Task 6 |
| Tomorrow column with adhaan controls | Task 6 |
| `QiblahCompassView` GeometryReader scaling | Task 7 |
| Centered prayer mat proportional to radius | Task 7 |
| iPad landscape Qibla info panel | Task 8 |
| macOS Qibla compass scales with window | Task 8 |

**Placeholder scan:** All steps have concrete code. No TBD/TODO.

**Type consistency:**
- `PrayerRowID` defined in Task 4 (`PrayerTimesComponents.swift`), used in Tasks 5 and 6 (`PrayerTimesView.swift`) ✓
- `PrayerHeroCard` created in Task 2, used in Task 5 ✓
- `PrayerRowMobileView` + `AdhaanChipTray` created in Task 3, used in Task 4 ✓
- `QiblahCompassView` created in Task 7, used in Task 8 ✓
- `expandedRowID: $expandedRowID` passed to both columns in Task 6 ✓
