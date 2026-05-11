# EPIC-0012 — Apple Watch App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native watchOS app (prayer list, Qibla, settings) and WidgetKit complications to Iqamah, running fully independently via on-watch GPS and syncing settings from iPhone via WCSession.

**Architecture:** Two new Xcode targets — `IqamahWatch` (SwiftUI 3-tab app) and `IqamahWatchWidget` (WidgetKit complications) — both linked against `IqamahCore`. `SettingsManager` already uses App Group `group.com.fablesoft.iqamah`, so the watch reads/writes the same store with zero package changes.

**Tech Stack:** Swift 5.10, SwiftUI, WatchKit, WidgetKit, ClockKit (watchOS 10), CoreLocation (`CLLocationManager` + `CLLocationHeading`), UserNotifications, WatchConnectivity (`WCSession`), `IqamahCore` (local Swift Package).

---

## File Map

### New files — `IqamahWatch/` (watchOS app target)
| File | Responsibility |
|------|---------------|
| `IqamahWatch/IqamahWatchApp.swift` | `@main` entry, first-launch GPS gate, `TabView` root |
| `IqamahWatch/LocationSetupView.swift` | Spinner + permission prompt shown before any prayer data |
| `IqamahWatch/PrayerTimesTab.swift` | Tab 1 — Hijri header + 6-row prayer list with gold highlight |
| `IqamahWatch/QiblaTab.swift` | Tab 2 — arc ring + Ka'bah icon + live heading instruction |
| `IqamahWatch/SettingsTab.swift` | Tab 3 — Form (location, method, adjustments, notifications, display) |
| `IqamahWatch/WatchSessionManager.swift` | `WCSession` delegate — receives `transferUserInfo` from iPhone |
| `IqamahWatch/WatchNotificationScheduler.swift` | Schedules `UNNotificationRequest` per enabled prayer (7-day window) |
| `IqamahWatch/Assets.xcassets` | App icon + `AccentColor` (#FFD60A) |
| `IqamahWatch/Info.plist` | `NSLocationWhenInUseUsageDescription`, `NSMotionUsageDescription` |
| `IqamahWatch/IqamahWatch.entitlements` | App Group `group.com.fablesoft.iqamah` |

### New files — `IqamahWatchWidget/` (watchOS Widget Extension)
| File | Responsibility |
|------|---------------|
| `IqamahWatchWidget/IqamahWatchWidget.swift` | `WidgetBundle` + `Widget` + all 4 complication views |
| `IqamahWatchWidget/PrayerEntry.swift` | `TimelineEntry` struct (5 fields) |
| `IqamahWatchWidget/PrayerTimelineProvider.swift` | `TimelineProvider` — builds entries, sets `.after` policy |
| `IqamahWatchWidget/Assets.xcassets` | `widgetAccentColor` (#FFD60A) |
| `IqamahWatchWidget/Info.plist` | `NSExtension` with `com.apple.widgetkit-extension` point |
| `IqamahWatchWidget/IqamahWatchWidget.entitlements` | App Group `group.com.fablesoft.iqamah` |

### New files — `IqamahWatchTests/`
| File | Responsibility |
|------|---------------|
| `IqamahWatchTests/TimelineTests.swift` | 5 timeline/complication unit tests |
| `IqamahWatchTests/QiblaTests.swift` | 2 Qibla bearing accuracy tests |

### New files — `IqamahCore`
| File | Responsibility |
|------|---------------|
| `Packages/IqamahCore/Sources/IqamahCore/Astronomy/QiblaCalculator.swift` | `qiblaBearing(from:) → Double` (great-circle bearing to Makkah) |

### Modified files
| File | Change |
|------|--------|
| `iqamah.xcodeproj/project.pbxproj` | Add 3 new targets + schemes + App Group capability |
| `iqamah.xcodeproj/xcshareddata/xcschemes/IqamahWatch.xcscheme` | New scheme for build + test |
| `iqamah/iOS/iqamahApp_iOS.swift` | Add `WCSession.transferUserInfo` on `settingsDidChange` |
| `.github/workflows/ci.yml` | Add `IqamahWatch` to build matrix |

---

## Task 1 — QiblaCalculator in IqamahCore (TDD first)

This function is needed by both the watch app and tests, so it lands first.

**Files:**
- Create: `Packages/IqamahCore/Sources/IqamahCore/Astronomy/QiblaCalculator.swift`
- Modify (tests): `Packages/IqamahCore/Tests/IqamahCoreTests/` — add inline

- [ ] **Step 1: Write the failing test in a new file**

Create `Packages/IqamahCore/Tests/IqamahCoreTests/QiblaCalculatorTests.swift`:

```swift
import CoreLocation
import IqamahCore
import Testing

@Suite("QiblaCalculator Tests")
struct QiblaCalculatorTests {

    @Test("Qibla bearing from Riyadh is ~247°")
    func riyadhBearing() {
        let riyadh = CLLocationCoordinate2D(latitude: 24.7, longitude: 46.7)
        let bearing = qiblaBearing(from: riyadh)
        #expect(abs(bearing - 247.0) < 2.0, "Expected ~247°, got \(bearing)")
    }

    @Test("Qibla bearing from London is ~119°")
    func londonBearing() {
        let london = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1)
        let bearing = qiblaBearing(from: london)
        #expect(abs(bearing - 119.0) < 2.0, "Expected ~119°, got \(bearing)")
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd Packages/IqamahCore && swift test --filter QiblaCalculatorTests 2>&1 | tail -5
```

Expected: compile error — `qiblaBearing` not defined.

- [ ] **Step 3: Implement QiblaCalculator**

Create `Packages/IqamahCore/Sources/IqamahCore/Astronomy/QiblaCalculator.swift`:

```swift
import CoreLocation
import Foundation

/// Returns the great-circle bearing (degrees, 0–360 clockwise from north)
/// from the given coordinate to the Ka'bah in Makkah (21.4225°N, 39.8262°E).
public func qiblaBearing(from coordinate: CLLocationCoordinate2D) -> Double {
    let makkahLat = 21.4225 * .pi / 180
    let makkahLon = 39.8262 * .pi / 180
    let lat1 = coordinate.latitude * .pi / 180
    let deltaLon = makkahLon - coordinate.longitude * .pi / 180

    let y = sin(deltaLon) * cos(makkahLat)
    let x = cos(lat1) * sin(makkahLat) - sin(lat1) * cos(makkahLat) * cos(deltaLon)
    var bearing = atan2(y, x) * 180 / .pi
    if bearing < 0 { bearing += 360 }
    return bearing
}

/// Distance in km from the given coordinate to the Ka'bah.
public func distanceToMakkahKm(from coordinate: CLLocationCoordinate2D) -> Double {
    let earthRadius = 6371.0
    let makkahLat = 21.4225 * .pi / 180
    let makkahLon = 39.8262 * .pi / 180
    let lat1 = coordinate.latitude * .pi / 180
    let lat2 = makkahLat
    let deltaLat = lat2 - lat1
    let deltaLon = makkahLon - coordinate.longitude * .pi / 180

    let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
cd Packages/IqamahCore && swift test --filter QiblaCalculatorTests 2>&1 | tail -5
```

Expected: `✔ Test run with 2 tests in 1 suite passed`

- [ ] **Step 5: Verify full suite still passes**

```bash
swift test 2>&1 | tail -3
```

Expected: `✔ Test run with 176 tests in 32 suites passed`

- [ ] **Step 6: Commit**

```bash
cd /path/to/worktree && git add Packages/IqamahCore/
git commit -m "feat(EPIC-0012): add qiblaBearing + distanceToMakkahKm to IqamahCore"
```

---

## Task 2 — Xcode project setup (pbxproj)

Add `IqamahWatch`, `IqamahWatchWidget`, and `IqamahWatchTests` targets. Use Python to edit `project.pbxproj`. Use UUID prefixes `WA` (watch app), `WW` (watch widget), `WT` (watch tests).

**Files:**
- Modify: `iqamah.xcodeproj/project.pbxproj`
- Create: `iqamah.xcodeproj/xcshareddata/xcschemes/IqamahWatch.xcscheme`
- Create: `IqamahWatch/Info.plist`
- Create: `IqamahWatch/IqamahWatch.entitlements`
- Create: `IqamahWatchWidget/Info.plist`
- Create: `IqamahWatchWidget/IqamahWatchWidget.entitlements`

- [ ] **Step 1: Create the Info.plist files**

Create `IqamahWatch/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Iqamah uses your location to calculate accurate prayer times on your wrist.</string>
    <key>NSMotionUsageDescription</key>
    <string>Iqamah uses the compass to show the Qibla direction.</string>
    <key>WKWatchOnly</key>
    <true/>
</dict>
</plist>
```

Create `IqamahWatch/IqamahWatch.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.fablesoft.iqamah</string>
    </array>
    <key>com.apple.developer.ubiquity-kvstore-identifier</key>
    <string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
</dict>
</plist>
```

Create `IqamahWatchWidget/Info.plist`:
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
</dict>
</plist>
```

Create `IqamahWatchWidget/IqamahWatchWidget.entitlements`:
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

- [ ] **Step 2: Edit project.pbxproj with Python**

Run this script from the worktree root:

```python
import re, uuid

path = "iqamah.xcodeproj/project.pbxproj"
with open(path) as f:
    content = f.read()

# ── Helper UUIDs (deterministic prefix WA/WW/WT) ────────────────────────────
WA_APP    = "WA000000000000000000001"   # IqamahWatch native target
WA_SOURCES= "WA000000000000000000002"   # Sources build phase
WA_RES    = "WA000000000000000000003"   # Resources build phase
WA_FW     = "WA000000000000000000004"   # Frameworks build phase
WA_COPY   = "WA000000000000000000005"   # CopyFiles (embed widget)
WA_PROD   = "WA000000000000000000006"   # Product file ref
WA_CFG_D  = "WA000000000000000000007"   # Debug build config
WA_CFG_R  = "WA000000000000000000008"   # Release build config
WA_CFGLIST= "WA000000000000000000009"   # Config list

WW_EXT    = "WW000000000000000000001"   # IqamahWatchWidget extension target
WW_SOURCES= "WW000000000000000000002"
WW_RES    = "WW000000000000000000003"
WW_FW     = "WW000000000000000000004"
WW_PROD   = "WW000000000000000000005"
WW_CFG_D  = "WW000000000000000000006"
WW_CFG_R  = "WW000000000000000000007"
WW_CFGLIST= "WW000000000000000000008"
WW_DEP_PROXY = "WW000000000000000000009"   # container item proxy
WW_DEP    = "WW000000000000000000010"   # target dependency from WA → WW

WT_TEST   = "WT000000000000000000001"   # IqamahWatchTests target
WT_SOURCES= "WT000000000000000000002"
WT_CFG_D  = "WT000000000000000000003"
WT_CFG_R  = "WT000000000000000000004"
WT_CFGLIST= "WT000000000000000000005"
WT_PROD   = "WT000000000000000000006"

# Re-use the IqamahCore package product dep UUID from existing project
# (IC0000000000000000000002 was set up in US-0040)
IC_PROD_DEP = "IC0000000000000000000002"
IC_BF       = "IC0000000000000000000003"  # IqamahCore build file (already exists for macOS)

# New IqamahCore build files for watch targets
IC_BF_WA  = "WA000000000000000000020"
IC_BF_WW  = "WW000000000000000000020"

new_file_refs = f"""
\t\t{WA_PROD} /* IqamahWatch.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "IqamahWatch.app"; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{WW_PROD} /* IqamahWatchWidget.appex */ = {{isa = PBXFileReference; explicitFileType = "plug-in"; includeInIndex = 0; path = IqamahWatchWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{WT_PROD} /* IqamahWatchTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = IqamahWatchTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
"""

new_build_files = f"""
\t\t{IC_BF_WA} /* IqamahCore in Frameworks (Watch) */ = {{isa = PBXBuildFile; productRef = {IC_PROD_DEP} /* IqamahCore */; }};
\t\t{IC_BF_WW} /* IqamahCore in Frameworks (Widget) */ = {{isa = PBXBuildFile; productRef = {IC_PROD_DEP} /* IqamahCore */; }};
"""

new_build_phases_wa = f"""
\t\t{WA_SOURCES} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{WA_RES} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{WA_FW} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{IC_BF_WA} /* IqamahCore in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""

new_build_phases_ww = f"""
\t\t{WW_SOURCES} /* Sources (Widget) */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{WW_RES} /* Resources (Widget) */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{WW_FW} /* Frameworks (Widget) */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{IC_BF_WW} /* IqamahCore in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""

new_build_phases_wt = f"""
\t\t{WT_SOURCES} /* Sources (Tests) */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""

new_targets = f"""
\t\t{WA_APP} /* IqamahWatch */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {WA_CFGLIST} /* Build configuration list for PBXNativeTarget "IqamahWatch" */;
\t\t\tbuildPhases = (
\t\t\t\t{WA_SOURCES} /* Sources */,
\t\t\t\t{WA_FW} /* Frameworks */,
\t\t\t\t{WA_RES} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{WW_DEP} /* IqamahWatchWidget */,
\t\t\t);
\t\t\tname = IqamahWatch;
\t\t\tpackageProductDependencies = (
\t\t\t\t{IC_BF_WA} /* IqamahCore */,
\t\t\t);
\t\t\tproductName = IqamahWatch;
\t\t\tproductReference = {WA_PROD} /* IqamahWatch.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
\t\t{WW_EXT} /* IqamahWatchWidget */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {WW_CFGLIST} /* Build configuration list for PBXNativeTarget "IqamahWatchWidget" */;
\t\t\tbuildPhases = (
\t\t\t\t{WW_SOURCES} /* Sources */,
\t\t\t\t{WW_FW} /* Frameworks */,
\t\t\t\t{WW_RES} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = IqamahWatchWidget;
\t\t\tpackageProductDependencies = (
\t\t\t\t{IC_BF_WW} /* IqamahCore */,
\t\t\t);
\t\t\tproductName = IqamahWatchWidget;
\t\t\tproductReference = {WW_PROD} /* IqamahWatchWidget.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t}};
\t\t{WT_TEST} /* IqamahWatchTests */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {WT_CFGLIST};
\t\t\tbuildPhases = (
\t\t\t\t{WT_SOURCES} /* Sources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = IqamahWatchTests;
\t\t\tproductName = IqamahWatchTests;
\t\t\tproductReference = {WT_PROD} /* IqamahWatchTests.xctest */;
\t\t\tproductType = "com.apple.product-type.bundle.unit-test";
\t\t}};
"""

new_dep = f"""
\t\t{WW_DEP_PROXY} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = AA0000000000000000000040 /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {WW_EXT};
\t\t\tremoteInfo = IqamahWatchWidget;
\t\t}};
\t\t{WW_DEP} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {WW_EXT} /* IqamahWatchWidget */;
\t\t\ttargetProxy = {WW_DEP_PROXY} /* PBXContainerItemProxy */;
\t\t}};
"""

new_configs = f"""
\t\t{WA_CFG_D} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "IqamahWatch/IqamahWatch.entitlements";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tDEVELOPMENT_TEAM = 96Y29SP9JR;
\t\t\t\tINFOPLIST_FILE = "IqamahWatch/Info.plist";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = "";
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.fablesoft.iqamah.watch";
\t\t\t\tPRODUCT_NAME = IqamahWatch;
\t\t\t\tSDKROOT = watchos;
\t\t\t\tSWIFT_VERSION = 5.10;
\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 10.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{WA_CFG_R} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "IqamahWatch/IqamahWatch.entitlements";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tDEVELOPMENT_TEAM = 96Y29SP9JR;
\t\t\t\tINFOPLIST_FILE = "IqamahWatch/Info.plist";
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.fablesoft.iqamah.watch";
\t\t\t\tPRODUCT_NAME = IqamahWatch;
\t\t\t\tSDKROOT = watchos;
\t\t\t\tSWIFT_VERSION = 5.10;
\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 10.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{WA_CFGLIST} /* Build configuration list for PBXNativeTarget "IqamahWatch" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{WA_CFG_D} /* Debug */,
\t\t\t\t{WA_CFG_R} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{WW_CFG_D} /* Debug (Widget) */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "IqamahWatchWidget/IqamahWatchWidget.entitlements";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tDEVELOPMENT_TEAM = 96Y29SP9JR;
\t\t\t\tINFOPLIST_FILE = "IqamahWatchWidget/Info.plist";
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.fablesoft.iqamah.watch.widget";
\t\t\t\tPRODUCT_NAME = IqamahWatchWidget;
\t\t\t\tSDKROOT = watchos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.10;
\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 10.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{WW_CFG_R} /* Release (Widget) */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "IqamahWatchWidget/IqamahWatchWidget.entitlements";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tDEVELOPMENT_TEAM = 96Y29SP9JR;
\t\t\t\tINFOPLIST_FILE = "IqamahWatchWidget/Info.plist";
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.fablesoft.iqamah.watch.widget";
\t\t\t\tPRODUCT_NAME = IqamahWatchWidget;
\t\t\t\tSDKROOT = watchos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.10;
\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 10.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{WW_CFGLIST} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{WW_CFG_D} /* Debug */,
\t\t\t\t{WW_CFG_R} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{WT_CFG_D} /* Debug (Tests) */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tDEVELOPMENT_TEAM = 96Y29SP9JR;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.fablesoft.iqamah.watch.tests";
\t\t\t\tPRODUCT_NAME = IqamahWatchTests;
\t\t\t\tSDKROOT = watchos;
\t\t\t\tSWIFT_VERSION = 5.10;
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/IqamahWatch.app/IqamahWatch";
\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 10.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{WT_CFG_R} /* Release (Tests) */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tDEVELOPMENT_TEAM = 96Y29SP9JR;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.fablesoft.iqamah.watch.tests";
\t\t\t\tPRODUCT_NAME = IqamahWatchTests;
\t\t\t\tSDKROOT = watchos;
\t\t\t\tSWIFT_VERSION = 5.10;
\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 10.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{WT_CFGLIST} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{WT_CFG_D} /* Debug */,
\t\t\t\t{WT_CFG_R} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
"""

# Inject into the right sections
content = content.replace("/* End PBXFileReference section */",
    new_file_refs + "/* End PBXFileReference section */")
content = content.replace("/* End PBXBuildFile section */",
    new_build_files + "/* End PBXBuildFile section */")
content = content.replace("/* End PBXSourcesBuildPhase section */",
    new_build_phases_wa + new_build_phases_ww + new_build_phases_wt +
    "/* End PBXSourcesBuildPhase section */")
content = content.replace("/* End PBXNativeTarget section */",
    new_targets + "/* End PBXNativeTarget section */")
content = content.replace("/* End PBXContainerItemProxy section */",
    new_dep + "/* End PBXContainerItemProxy section */")
content = content.replace("/* End XCBuildConfiguration section */",
    new_configs + "/* End XCBuildConfiguration section */")

# Add targets to the project's target list
content = content.replace(
    "targets = (\n\t\t\t\tAA0000000000000000000040",
    f"targets = (\n\t\t\t\t{WA_APP} /* IqamahWatch */,\n\t\t\t\t{WW_EXT} /* IqamahWatchWidget */,\n\t\t\t\t{WT_TEST} /* IqamahWatchTests */,\n\t\t\t\tAA0000000000000000000040"
)

with open(path, "w") as f:
    f.write(content)

print("project.pbxproj updated")
```

- [ ] **Step 3: Create the Xcode scheme**

Create `iqamah.xcodeproj/xcshareddata/xcschemes/IqamahWatch.xcscheme`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2620" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES"
             buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference BuildableIdentifier="primary"
               BlueprintIdentifier="WA000000000000000000001"
               BuildableName="IqamahWatch.app"
               BlueprintName="IqamahWatch"
               ReferencedContainer="container:iqamah.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug"
      selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv="YES">
      <Testables>
         <TestableReference skipped="NO">
            <BuildableReference BuildableIdentifier="primary"
               BlueprintIdentifier="WT000000000000000000001"
               BuildableName="IqamahWatchTests.xctest"
               BlueprintName="IqamahWatchTests"
               ReferencedContainer="container:iqamah.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Debug"
      selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle="0" useCustomWorkingDirectory="NO"
      ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"
      debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary"
            BlueprintIdentifier="WA000000000000000000001"
            BuildableName="IqamahWatch.app"
            BlueprintName="IqamahWatch"
            ReferencedContainer="container:iqamah.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <AnalyzeAction buildConfiguration="Debug"/>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
```

- [ ] **Step 4: Verify target is recognised**

```bash
xcodebuild -project iqamah.xcodeproj -list 2>&1 | grep -E "IqamahWatch|IqamahWatchWidget|IqamahWatchTests"
```

Expected output:
```
        IqamahWatch
        IqamahWatchWidget
        IqamahWatchTests
```

- [ ] **Step 5: Commit**

```bash
git add IqamahWatch/ IqamahWatchWidget/ iqamah.xcodeproj/
git commit -m "feat(EPIC-0012): add IqamahWatch + IqamahWatchWidget + IqamahWatchTests Xcode targets"
```

---

## Task 3 — PrayerEntry + PrayerTimelineProvider (TDD)

**Files:**
- Create: `IqamahWatchWidget/PrayerEntry.swift`
- Create: `IqamahWatchWidget/PrayerTimelineProvider.swift`
- Create: `IqamahWatchTests/TimelineTests.swift` (tests first)

- [ ] **Step 1: Write all timeline unit tests**

Create `IqamahWatchTests/TimelineTests.swift` and add it to the `IqamahWatchTests` Sources build phase in pbxproj (UUID `WT000000000000000000010`):

```swift
import IqamahCore
import Testing
@testable import IqamahWatchWidget

@Suite("Complication Timeline Tests")
struct TimelineTests {

    // Seed a known location into a fresh UserDefaults suite before each test
    private func seedDefaults() -> UserDefaults {
        let suite = UserDefaults(suiteName: "test.timeline.\(UUID().uuidString)")!
        suite.set("manual", forKey: "locationSource")
        suite.set("Riyadh", forKey: "selectedCityName")
        suite.set("SA", forKey: "selectedCityCountryCode")
        suite.set(24.6877, forKey: "selectedCityLatitude")
        suite.set(46.7219, forKey: "selectedCityLongitude")
        suite.set("Asia/Riyadh", forKey: "selectedCityTimezone")
        suite.set("isna", forKey: "calculationMethod")
        suite.set("standard", forKey: "asrMethod")
        return suite
    }

    @Test("Timeline generates at least 10 entries covering today + tomorrow")
    func testTimelineEntriesCount() async throws {
        let defaults = seedDefaults()
        let provider = PrayerTimelineProvider(defaults: defaults)
        let entries = provider.buildEntries(from: Date())
        #expect(entries.count >= 10, "Expected ≥10 entries, got \(entries.count)")
    }

    @Test("Timeline refresh policy equals nextPrayerTime of the last entry")
    func testTimelineRefreshPolicy() async throws {
        let defaults = seedDefaults()
        let provider = PrayerTimelineProvider(defaults: defaults)
        let entries = provider.buildEntries(from: Date())
        let lastEntry = try #require(entries.last)
        let policy = provider.refreshPolicy(for: entries)
        if case .after(let date) = policy {
            #expect(date == lastEntry.nextPrayerTime)
        } else {
            Issue.record("Expected .after policy")
        }
    }

    @Test("All entries have non-empty cityName and methodName")
    func testPrayerEntryFieldsNonEmpty() async throws {
        let defaults = seedDefaults()
        let provider = PrayerTimelineProvider(defaults: defaults)
        let entries = provider.buildEntries(from: Date())
        for entry in entries {
            #expect(!entry.cityName.isEmpty, "cityName is empty in entry \(entry.date)")
            #expect(!entry.methodName.isEmpty, "methodName is empty in entry \(entry.date)")
        }
    }

    @Test("No entry has nextPrayerTime in the past relative to entry.date")
    func testNextPrayerIsAlwaysInFuture() async throws {
        let defaults = seedDefaults()
        let provider = PrayerTimelineProvider(defaults: defaults)
        let entries = provider.buildEntries(from: Date())
        for entry in entries {
            #expect(entry.nextPrayerTime >= entry.date,
                "\(entry.nextPrayerName) at \(entry.nextPrayerTime) is before entry.date \(entry.date)")
        }
    }

    @Test("placeholder(in:) returns stub without crashing on empty App Group")
    func testEmptyAppGroupShowsPlaceholder() {
        let empty = UserDefaults(suiteName: "test.empty.\(UUID().uuidString)")!
        let provider = PrayerTimelineProvider(defaults: empty)
        let stub = provider.placeholder()
        #expect(!stub.nextPrayerName.isEmpty)
        #expect(stub.cityName == "—")
    }
}
```

- [ ] **Step 2: Create PrayerEntry**

Create `IqamahWatchWidget/PrayerEntry.swift` and add to `IqamahWatchWidget` Sources (UUID `WW000000000000000000030`):

```swift
import Foundation
import WidgetKit

struct PrayerEntry: TimelineEntry {
    let date: Date
    let nextPrayerName: String
    let nextPrayerTime: Date
    let cityName: String
    let methodName: String

    /// Formatted relative countdown string, e.g. "2h 14m"
    var countdown: String {
        let interval = nextPrayerTime.timeIntervalSince(date)
        guard interval > 0 else { return "Now" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
```

- [ ] **Step 3: Create PrayerTimelineProvider**

Create `IqamahWatchWidget/PrayerTimelineProvider.swift` and add to `IqamahWatchWidget` Sources (UUID `WW000000000000000000031`):

```swift
import Foundation
import IqamahCore
import WidgetKit

struct PrayerTimelineProvider: TimelineProvider {
    private let defaults: UserDefaults

    /// Designated init uses the live App Group store.
    init(defaults: UserDefaults = UserDefaults(suiteName: "group.com.fablesoft.iqamah") ?? .standard) {
        self.defaults = defaults
    }

    func placeholder(in context: Context) -> PrayerEntry { placeholder() }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let entries = buildEntries(from: Date())
        let policy = refreshPolicy(for: entries)
        completion(Timeline(entries: entries, policy: policy))
    }

    // MARK: - Internal (internal for testability)

    func placeholder() -> PrayerEntry {
        PrayerEntry(
            date: Date(),
            nextPrayerName: "Asr",
            nextPrayerTime: Date().addingTimeInterval(3600),
            cityName: "—",
            methodName: "—"
        )
    }

    func buildEntries(from now: Date) -> [PrayerEntry] {
        let settings = SettingsManager(userDefaults: defaults)
        guard let coord = settings.activeCoordinate,
              let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier)
        else { return [placeholder()] }

        let calc = PrayerCalculator(
            coordinate: coord,
            timezone: timezone,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )
        let cityName = settings.activeCityName.isEmpty ? "—" : settings.activeCityName
        let methodName = settings.calculationMethod.shortName

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
                    methodName: methodName
                ))
                cursor = prayer.time
            }
        }

        return entries.isEmpty ? [placeholder()] : entries
    }

    func refreshPolicy(for entries: [PrayerEntry]) -> TimelineReloadPolicy {
        guard let last = entries.last else { return .after(Date().addingTimeInterval(3600)) }
        return .after(last.nextPrayerTime)
    }

    private func makeEntry(for date: Date) -> PrayerEntry {
        buildEntries(from: date).first ?? placeholder()
    }
}
```

- [ ] **Step 4: Add source files to pbxproj build phases**

Run this Python snippet to register the new files:

```python
path = "iqamah.xcodeproj/project.pbxproj"
with open(path) as f: content = f.read()

new_build_files = """
\t\tWW000000000000000000030 /* PrayerEntry.swift in Sources */ = {isa = PBXBuildFile; fileRef = WW000000000000000000030R /* PrayerEntry.swift */; };
\t\tWW000000000000000000031 /* PrayerTimelineProvider.swift in Sources */ = {isa = PBXBuildFile; fileRef = WW000000000000000000031R /* PrayerTimelineProvider.swift */; };
\t\tWT000000000000000000010 /* TimelineTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = WT000000000000000000010R /* TimelineTests.swift */; };
"""
new_refs = """
\t\tWW000000000000000000030R /* PrayerEntry.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PrayerEntry.swift; sourceTree = "<group>"; };
\t\tWW000000000000000000031R /* PrayerTimelineProvider.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PrayerTimelineProvider.swift; sourceTree = "<group>"; };
\t\tWT000000000000000000010R /* TimelineTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TimelineTests.swift; sourceTree = "<group>"; };
"""
# Add build files to IqamahWatchWidget Sources phase
content = content.replace(
    f"WW000000000000000000002 /* Sources (Widget) */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);",
    f"WW000000000000000000002 /* Sources (Widget) */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\tWW000000000000000000030 /* PrayerEntry.swift in Sources */,\n\t\t\t\tWW000000000000000000031 /* PrayerTimelineProvider.swift in Sources */,\n\t\t\t);"
)
# Add to IqamahWatchTests Sources
content = content.replace(
    f"WT000000000000000000002 /* Sources (Tests) */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);",
    f"WT000000000000000000002 /* Sources (Tests) */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\tWT000000000000000000010 /* TimelineTests.swift in Sources */,\n\t\t\t);"
)
content = content.replace("/* End PBXBuildFile section */", new_build_files + "/* End PBXBuildFile section */")
content = content.replace("/* End PBXFileReference section */", new_refs + "/* End PBXFileReference section */")
with open(path, "w") as f: f.write(content)
print("Sources registered")
```

- [ ] **Step 5: Build IqamahWatchWidget — verify it compiles**

```bash
xcodebuild -project iqamah.xcodeproj -scheme IqamahWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Run timeline tests**

```bash
xcodebuild -project iqamah.xcodeproj -scheme IqamahWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  test CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "passed|failed|error:" | tail -10
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add IqamahWatchWidget/ IqamahWatchTests/ iqamah.xcodeproj/
git commit -m "feat(EPIC-0012): PrayerEntry + PrayerTimelineProvider + 5 timeline tests (TDD)"
```

---

## Task 4 — Complication views (all 4 families)

**Files:**
- Create: `IqamahWatchWidget/IqamahWatchWidget.swift`

- [ ] **Step 1: Create the widget file**

Create `IqamahWatchWidget/IqamahWatchWidget.swift` (add to pbxproj: UUID `WW000000000000000000032`):

```swift
import IqamahCore
import SwiftUI
import WidgetKit

// MARK: - Rectangular (most real estate)

struct RectangularView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("IQAMAH")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
                .widgetAccentable()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.nextPrayerName)
                    .font(.system(size: 15, weight: .bold))
                Text(entry.countdown)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.839, blue: 0.039))
                    .widgetAccentable()
            }
            Text("\(entry.cityName) · \(entry.methodName)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Circular (progress arc)

struct CircularView: View {
    let entry: PrayerEntry

    var body: some View {
        ZStack {
            // Progress arc: fraction of day elapsed toward next prayer
            ProgressView(value: dayProgress)
                .progressViewStyle(.circular)
                .tint(Color(red: 1.0, green: 0.839, blue: 0.039))
                .widgetAccentable()
            VStack(spacing: 0) {
                Text(entry.nextPrayerName.prefix(3))
                    .font(.system(size: 11, weight: .semibold))
                Text(entry.countdown)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dayProgress: Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: entry.date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let total = end.timeIntervalSince(start)
        let elapsed = entry.nextPrayerTime.timeIntervalSince(start)
        return min(max(elapsed / total, 0), 1)
    }
}

// MARK: - Corner (letter + countdown)

struct CornerView: View {
    let entry: PrayerEntry

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    Color(red: 1.0, green: 0.839, blue: 0.039),
                    lineWidth: 2
                )
                .widgetAccentable()
            VStack(spacing: 0) {
                Text(String(entry.nextPrayerName.prefix(1)))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.839, blue: 0.039))
                    .widgetAccentable()
                Text(entry.countdown)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Inline (plain text)

struct InlineView: View {
    let entry: PrayerEntry

    var body: some View {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return Text("\(entry.nextPrayerName) at \(formatter.string(from: entry.nextPrayerTime))")
            .widgetAccentable()
    }
}

// MARK: - Combined view dispatcher

struct IqamahWatchWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: PrayerEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            RectangularView(entry: entry)
        case .accessoryCircular:
            CircularView(entry: entry)
        case .accessoryCorner:
            CornerView(entry: entry)
        case .accessoryInline:
            InlineView(entry: entry)
        default:
            RectangularView(entry: entry)
        }
    }
}

// MARK: - Widget + Bundle

struct IqamahWatchComplicationWidget: Widget {
    let kind = "IqamahWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            IqamahWatchWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Iqamah")
        .description("Next prayer countdown on your watch face.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
        ])
    }
}

@main
struct IqamahWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        IqamahWatchComplicationWidget()
    }
}
```

- [ ] **Step 2: Register file in pbxproj**

```python
path = "iqamah.xcodeproj/project.pbxproj"
with open(path) as f: c = f.read()
c = c.replace("/* End PBXFileReference section */",
    '\t\tWW000000000000000000032R /* IqamahWatchWidget.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = IqamahWatchWidget.swift; sourceTree = "<group>"; };\n/* End PBXFileReference section */')
c = c.replace("/* End PBXBuildFile section */",
    '\t\tWW000000000000000000032 /* IqamahWatchWidget.swift in Sources */ = {isa = PBXBuildFile; fileRef = WW000000000000000000032R /* IqamahWatchWidget.swift */; };\n/* End PBXBuildFile section */')
c = c.replace(
    "WW000000000000000000031 /* PrayerTimelineProvider.swift in Sources */,\n\t\t\t);",
    "WW000000000000000000031 /* PrayerTimelineProvider.swift in Sources */,\n\t\t\t\tWW000000000000000000032 /* IqamahWatchWidget.swift in Sources */,\n\t\t\t);"
)
with open(path, "w") as f: f.write(c)
print("done")
```

- [ ] **Step 3: Add widgetAccentColor to IqamahWatchWidget/Assets.xcassets**

Create `IqamahWatchWidget/Assets.xcassets/widgetAccentColor.colorset/Contents.json`:

```json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": { "red": "1.0", "green": "0.839", "blue": "0.039", "alpha": "1.0" }
      },
      "idiom": "universal"
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

- [ ] **Step 4: Build — verify clean**

```bash
xcodebuild -project iqamah.xcodeproj -scheme IqamahWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep "BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add IqamahWatchWidget/ iqamah.xcodeproj/
git commit -m "feat(EPIC-0012): all 4 complication families — rectangular, circular, corner, inline"
```

---

## Task 5 — Watch app entry point + Prayer Times tab

**Files:**
- Create: `IqamahWatch/IqamahWatchApp.swift`
- Create: `IqamahWatch/LocationSetupView.swift`
- Create: `IqamahWatch/PrayerTimesTab.swift`

- [ ] **Step 1: Create IqamahWatchApp.swift**

```swift
import IqamahCore
import SwiftUI

@main
struct IqamahWatchApp: App {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var locationSetup = WatchLocationSetup()

    var body: some Scene {
        WindowGroup {
            Group {
                if locationSetup.isReady {
                    MainWatchView()
                        .environmentObject(settings)
                } else {
                    LocationSetupView(setup: locationSetup)
                }
            }
            .onAppear { locationSetup.start(settings: settings) }
        }
    }
}

// MARK: - Main tab container

struct MainWatchView: View {
    var body: some View {
        TabView {
            PrayerTimesTab()
            QiblaTab()
            SettingsTab()
        }
        .tabViewStyle(.page)
    }
}

// MARK: - Location readiness observable

@MainActor
final class WatchLocationSetup: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isReady = false
    @Published var status: String = "Detecting your location…"
    private let manager = CLLocationManager()
    private var settings: SettingsManager?

    func start(settings: SettingsManager) {
        self.settings = settings
        // If we already have coordinates in the App Group, go straight through
        if settings.activeCoordinate != nil {
            isReady = true
            return
        }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                status = "Enable location in Watch Settings"
                isReady = true // show app with error state
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        Task { @MainActor in
            let settings = self.settings!
            settings.saveGPSCoordinates(loc.coordinate)
            settings.locationSource = "gps"
            let tz = TimeZone.current.identifier
            settings.gpsTimezone = tz
            settings.gpsLocality = ""
            isReady = true
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            status = "Location unavailable — tap to retry"
            isReady = true
        }
    }
}
```

- [ ] **Step 2: Create LocationSetupView.swift**

```swift
import SwiftUI

struct LocationSetupView: View {
    @ObservedObject var setup: WatchLocationSetup

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text(setup.status)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
```

- [ ] **Step 3: Create PrayerTimesTab.swift**

```swift
import IqamahCore
import SwiftUI

struct PrayerTimesTab: View {
    @EnvironmentObject private var settings: SettingsManager
    @State private var prayers: [(name: String, time: Date)] = []
    @State private var nextPrayerName: String = ""

    private let gold = Color(red: 1.0, green: 0.839, blue: 0.039)

    var body: some View {
        VStack(spacing: 0) {
            // Hijri date header
            Text(hijriHeader)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 4)

            List {
                ForEach(prayers, id: \.name) { prayer in
                    HStack {
                        Text(prayer.name)
                            .font(prayer.name == nextPrayerName ? .system(size: 13, weight: .bold) : .system(size: 13))
                        Spacer()
                        Text(formattedTime(prayer.time))
                            .font(prayer.name == nextPrayerName ? .system(size: 13, weight: .bold) : .system(size: 13))
                    }
                    .foregroundStyle(rowColor(for: prayer))
                    .listRowBackground(
                        prayer.name == nextPrayerName
                            ? gold.opacity(0.12).clipShape(RoundedRectangle(cornerRadius: 5))
                            : Color.clear
                    )
                    .opacity(isPast(prayer.time) ? 0.28 : 1.0)
                }
            }
            .listStyle(.plain)
        }
        .onAppear { loadPrayers() }
        .onChange(of: settings.calculationMethod) { _, _ in loadPrayers() }
        .onChange(of: settings.asrMethod) { _, _ in loadPrayers() }
    }

    // MARK: - Helpers

    private func rowColor(for prayer: (name: String, time: Date)) -> Color {
        prayer.name == nextPrayerName ? gold : .primary
    }

    private func isPast(_ date: Date) -> Bool { date < Date() }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = settings.use24HourTime ? "HH:mm" : "h:mm"
        return f.string(from: date)
    }

    private var hijriHeader: String {
        let cal = Calendar(identifier: .islamicUmmAlQura)
        var c = cal.dateComponents([.day, .month, .year], from: Date())
        c.day = (c.day ?? 1) + settings.hijriDayOffset
        let months = ["Muharram","Safar","Rabi' I","Rabi' II",
                      "Jumada I","Jumada II","Rajab","Sha'ban",
                      "Ramadan","Shawwal","Dhu al-Qi'dah","Dhu al-Hijjah"]
        let m = (c.month ?? 1) - 1
        let name = m >= 0 && m < 12 ? months[m] : ""
        let dayName = Date().formatted(.dateTime.weekday(.abbreviated)).uppercased()
        return "\(c.day ?? 1) \(name.uppercased()) · \(dayName)"
    }

    private func loadPrayers() {
        guard let coord = settings.activeCoordinate,
              let tz = TimeZone(identifier: settings.activeTimezoneIdentifier) else { return }
        let calc = PrayerCalculator(coordinate: coord, timezone: tz,
                                    method: settings.calculationMethod,
                                    asrMethod: settings.asrMethod)
        guard let times = try? calc.calculate(for: Date()) else { return }
        prayers = times.prayers
        nextPrayerName = times.prayers.first(where: { $0.time > Date() && $0.name != "Sunrise" })?.name ?? ""
    }
}
```

- [ ] **Step 4: Register files in pbxproj and build**

Add `IqamahWatchApp.swift`, `LocationSetupView.swift`, `PrayerTimesTab.swift` to `IqamahWatch` Sources build phase with new UUIDs `WA000000000000000000011`–`WA000000000000000000013`. Follow the same Python pbxproj pattern from Task 3 Step 4.

- [ ] **Step 5: Build**

```bash
xcodebuild -project iqamah.xcodeproj -scheme IqamahWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep "BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add IqamahWatch/ iqamah.xcodeproj/
git commit -m "feat(EPIC-0012): watch app entry point + prayer times tab with gold highlight"
```

---

## Task 6 — Qibla tab

**Files:**
- Create: `IqamahWatch/QiblaTab.swift`

- [ ] **Step 1: Create QiblaTab.swift**

```swift
import CoreLocation
import IqamahCore
import SwiftUI

struct QiblaTab: View {
    @EnvironmentObject private var settings: SettingsManager
    @StateObject private var heading = HeadingObserver()

    private let gold = Color(red: 1.0, green: 0.839, blue: 0.039)

    var body: some View {
        VStack(spacing: 8) {
            if let coord = settings.activeCoordinate {
                let bearing = qiblaBearing(from: coord)
                let distance = distanceToMakkahKm(from: coord)

                ZStack {
                    // Background ring
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 4)

                    // Gold arc showing Qibla direction
                    Circle()
                        .trim(from: 0, to: 0.12)
                        .stroke(gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(bearing - 90))
                        .animation(.easeInOut(duration: 0.3), value: bearing)

                    // Ka'bah icon
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(gold, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(gold.opacity(0.2))
                        )
                }
                .frame(width: 80, height: 80)

                // Instruction text
                Text(faceText(bearing: bearing))
                    .font(.system(size: 13, weight: .semibold))

                if let currentHeading = heading.currentHeading {
                    let delta = turnDelta(current: currentHeading, target: bearing)
                    Text(turnText(delta: delta))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Heading unavailable")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Text(String(format: "Makkah · %.0f km", distance))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.6))

            } else {
                Image(systemName: "location.slash")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Location needed\nfor Qibla")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { heading.start() }
        .onDisappear { heading.stop() }
    }

    private func faceText(bearing: Double) -> String {
        let directions = ["N","NE","E","SE","S","SW","W","NW"]
        let idx = Int((bearing + 22.5) / 45) % 8
        return String(format: "Face %.0f° %@", bearing, directions[idx])
    }

    private func turnDelta(current: Double, target: Double) -> Double {
        var delta = target - current
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    private func turnText(delta: Double) -> String {
        let abs = Swift.abs(delta)
        if abs < 5 { return "You're facing Qibla ✓" }
        let dir = delta > 0 ? "right" : "left"
        return String(format: "Turn %.0f° %@", abs, dir)
    }
}

// MARK: - Heading observer

@MainActor
final class HeadingObserver: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentHeading: Double?
    private let manager = CLLocationManager()

    func start() {
        manager.delegate = self
        manager.headingFilter = 2.0
        manager.startUpdatingHeading()
    }

    func stop() { manager.stopUpdatingHeading() }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        guard heading.headingAccuracy >= 0 else { return }
        Task { @MainActor in self.currentHeading = heading.trueHeading }
    }
}
```

- [ ] **Step 2: Register in pbxproj and build clean**

Add to `IqamahWatch` Sources (UUID `WA000000000000000000014`). Build:

```bash
xcodebuild -project iqamah.xcodeproj -scheme IqamahWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep "BUILD"
```

- [ ] **Step 3: Commit**

```bash
git add IqamahWatch/ iqamah.xcodeproj/
git commit -m "feat(EPIC-0012): Qibla tab — arc + Ka'bah icon + live heading turn instruction"
```

---

## Task 7 — Settings tab + Qibla unit tests

**Files:**
- Create: `IqamahWatch/SettingsTab.swift`
- Create: `IqamahWatchTests/QiblaTests.swift`

- [ ] **Step 1: Write Qibla unit tests first**

Create `IqamahWatchTests/QiblaTests.swift` (UUID `WT000000000000000000020`):

```swift
import CoreLocation
import IqamahCore
import Testing

@Suite("Qibla Bearing Tests")
struct QiblaTests {

    @Test("Qibla from Riyadh is approximately 247°")
    func riyadhQibla() {
        let riyadh = CLLocationCoordinate2D(latitude: 24.7, longitude: 46.7)
        let bearing = qiblaBearing(from: riyadh)
        #expect(abs(bearing - 247.0) < 2.0,
            "Expected ~247° but got \(String(format: "%.1f", bearing))°")
    }

    @Test("Qibla from London is approximately 119°")
    func londonQibla() {
        let london = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1)
        let bearing = qiblaBearing(from: london)
        #expect(abs(bearing - 119.0) < 2.0,
            "Expected ~119° but got \(String(format: "%.1f", bearing))°")
    }
}
```

- [ ] **Step 2: Run Qibla tests**

```bash
xcodebuild -project iqamah.xcodeproj -scheme IqamahWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  test CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "passed|failed" | tail -5
```

Expected: `** TEST SUCCEEDED **` (7 tests now)

- [ ] **Step 3: Create SettingsTab.swift**

```swift
import IqamahCore
import SwiftUI
import WidgetKit

struct SettingsTab: View {
    @EnvironmentObject private var settings: SettingsManager
    @StateObject private var locationUpdater = WatchLocationSetup()
    @State private var isUpdatingLocation = false

    var body: some View {
        Form {
            // Location
            Section("Location") {
                HStack {
                    Text(locationLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Button(isUpdatingLocation ? "Updating…" : "Update Location") {
                    isUpdatingLocation = true
                    locationUpdater.start(settings: settings)
                }
                .disabled(isUpdatingLocation)
                .onChange(of: locationUpdater.isReady) { _, ready in
                    if ready { isUpdatingLocation = false; reloadComplications() }
                }
            }

            // Prayer Times
            Section("Prayer Times") {
                Picker("Method", selection: $settings.calculationMethod) {
                    ForEach(CalculationMethod.allCases) { m in
                        Text(m.shortName).tag(m)
                    }
                }
                Picker("Asr", selection: $settings.asrMethod) {
                    Text("Standard").tag(AsrJuristicMethod.standard)
                    Text("Hanafi").tag(AsrJuristicMethod.hanafi)
                }
            }
            .onChange(of: settings.calculationMethod) { _, _ in reloadComplications() }
            .onChange(of: settings.asrMethod) { _, _ in reloadComplications() }

            // Adjustments
            Section("Adjustments") {
                ForEach(["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"], id: \.self) { prayer in
                    Stepper(
                        value: adjustmentBinding(for: prayer),
                        in: -15 ... 15
                    ) {
                        let val = settings.getAdjustment(for: prayer)
                        Text("\(prayer): \(val > 0 ? "+" : "")\(val)m")
                            .font(.caption)
                    }
                }
            }

            // Notifications
            Section("Notifications") {
                Toggle("Prayer haptics", isOn: $settings.hilalNotificationEnabled)
            }

            // Display
            Section("Display") {
                Toggle("24-hour time", isOn: $settings.use24HourTime)
            }
        }
    }

    private var locationLabel: String {
        if let city = settings.loadCity() { return city.name }
        if let coord = settings.activeCoordinate {
            return String(format: "%.2f°, %.2f°", coord.latitude, coord.longitude)
        }
        return "Not set"
    }

    private func adjustmentBinding(for prayer: String) -> Binding<Int> {
        Binding(
            get: { settings.getAdjustment(for: prayer) },
            set: { settings.setAdjustment($0, for: prayer); reloadComplications() }
        )
    }

    private func reloadComplications() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
```

- [ ] **Step 4: Register files and build**

Add `SettingsTab.swift` (UUID `WA000000000000000000015`) and `QiblaTests.swift` (UUID `WT000000000000000000020`) to pbxproj. Build:

```bash
xcodebuild -project iqamah.xcodeproj -scheme IqamahWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep "BUILD"
```

- [ ] **Step 5: Run all 7 tests**

```bash
xcodebuild -project iqamah.xcodeproj -scheme IqamahWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  test CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
```

Expected: `** TEST SUCCEEDED **` with 7 tests.

- [ ] **Step 6: Commit**

```bash
git add IqamahWatch/ IqamahWatchTests/ iqamah.xcodeproj/
git commit -m "feat(EPIC-0012): settings tab + Qibla bearing unit tests — all 7 tests green"
```

---

## Task 8 — Haptic notifications + WCSession sync

**Files:**
- Create: `IqamahWatch/WatchNotificationScheduler.swift`
- Create: `IqamahWatch/WatchSessionManager.swift`
- Modify: `iqamah/iOS/iqamahApp_iOS.swift`

- [ ] **Step 1: Create WatchNotificationScheduler.swift**

```swift
import IqamahCore
import UserNotifications

@MainActor
final class WatchNotificationScheduler {
    static let shared = WatchNotificationScheduler()
    private let center = UNUserNotificationCenter.current()

    func rescheduleAll(settings: SettingsManager) async {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        center.removeAllPendingNotificationRequests()

        guard let coord = settings.activeCoordinate,
              let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier) else { return }

        let calc = PrayerCalculator(
            coordinate: coord,
            timezone: timezone,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)

        for dayOffset in 0 ..< 7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let times = try? calc.calculate(for: day) else { continue }

            for prayer in times.prayers {
                guard settings.isPrayerEnabled(prayer.name),
                      prayer.name != "Sunrise",
                      prayer.time > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Time for \(prayer.name)"
                content.subtitle = settings.activeCityName
                content.sound = .default
                content.userInfo = ["prayerName": prayer.name]

                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                let id = "watch.prayer.\(prayer.name).\(f.string(from: day))"
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: prayer.time)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }

    func cancel() {
        center.removeAllPendingNotificationRequests()
    }
}
```

- [ ] **Step 2: Create WatchSessionManager.swift**

```swift
import IqamahCore
import WatchConnectivity

@MainActor
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()
    private var settings: SettingsManager?

    func activate(settings: SettingsManager) {
        self.settings = settings
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor in
            guard let settings = self.settings else { return }
            // Write each received key directly to App Group via SettingsManager
            if let methodRaw = userInfo["calculationMethod"] as? String,
               let method = CalculationMethod(rawValue: methodRaw) {
                settings.calculationMethod = method
            }
            if let asrRaw = userInfo["asrMethod"] as? String,
               let asr = AsrJuristicMethod(rawValue: asrRaw) {
                settings.asrMethod = asr
            }
            if let use24 = userInfo["use24HourTime"] as? Bool {
                settings.use24HourTime = use24
            }
            if let cityName = userInfo["selectedCityName"] as? String,
               let countryCode = userInfo["selectedCityCountryCode"] as? String,
               let lat = userInfo["selectedCityLatitude"] as? Double,
               let lon = userInfo["selectedCityLongitude"] as? Double,
               let tz = userInfo["selectedCityTimezone"] as? String,
               let city = try? City(name: cityName, countryCode: countryCode,
                                    latitude: lat, longitude: lon, timezone: tz) {
                settings.saveCity(city)
                settings.locationSource = "manual"
            }
            // Reload complications after sync
            import WidgetKit
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith
        activationState: WCSessionActivationState, error: Error?) {}
}
```

⚠️ Fix: Move `import WidgetKit` to the top of the file (it can't be inside a function). The line inside the function above is a placeholder reminder — put the import at the top.

- [ ] **Step 3: Wire scheduler and session in IqamahWatchApp.swift**

Update `IqamahWatchApp.swift` — modify the `onAppear` in the `WindowGroup`:

```swift
// Replace the existing .onAppear in IqamahWatchApp body with:
.onAppear {
    locationSetup.start(settings: settings)
    WatchSessionManager.shared.activate(settings: settings)
}
.onChange(of: settings.hilalNotificationEnabled) { _, enabled in
    Task {
        if enabled {
            await WatchNotificationScheduler.shared.rescheduleAll(settings: settings)
        } else {
            WatchNotificationScheduler.shared.cancel()
        }
    }
}
// Re-schedule on each app-active
.onReceive(NotificationCenter.default.publisher(for: WKApplication.didBecomeActiveNotification)) { _ in
    guard settings.hilalNotificationEnabled else { return }
    Task { await WatchNotificationScheduler.shared.rescheduleAll(settings: settings) }
}
```

- [ ] **Step 4: Modify iOS app to push settings on change**

Read `iqamah/iOS/iqamahApp_iOS.swift` and add a `WCSession` push inside the existing `.onChange` handlers. Add this helper and wire it:

```swift
// Add inside IqamahiOSApp body, after existing .onChange handlers:
.onChange(of: settings.calculationMethod) { _, _ in pushSettingsToWatch() }
.onChange(of: settings.asrMethod)         { _, _ in pushSettingsToWatch() }
.onChange(of: settings.use24HourTime)     { _, _ in pushSettingsToWatch() }
.onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
    pushSettingsToWatch()
}

// Add helper function inside IqamahiOSApp:
private func pushSettingsToWatch() {
    guard WCSession.isSupported(),
          WCSession.default.activationState == .activated,
          WCSession.default.isWatchAppInstalled else { return }
    var info: [String: Any] = [
        "calculationMethod": settings.calculationMethod.rawValue,
        "asrMethod": settings.asrMethod.rawValue,
        "use24HourTime": settings.use24HourTime,
    ]
    if let city = settings.loadCity() {
        info["selectedCityName"] = city.name
        info["selectedCityCountryCode"] = city.countryCode
        info["selectedCityLatitude"] = city.latitude
        info["selectedCityLongitude"] = city.longitude
        info["selectedCityTimezone"] = city.timezone
    }
    WCSession.default.transferUserInfo(info)
}
```

Also add `import WatchConnectivity` at the top of `iqamahApp_iOS.swift` and activate the session in the init or first `.onAppear`:

```swift
.onAppear {
    reschedule()
    if WCSession.isSupported() {
        WCSession.default.activate()  // delegate not needed on iOS side for transferUserInfo
    }
}
```

- [ ] **Step 5: Build both targets**

```bash
# Watch
xcodebuild -project iqamah.xcodeproj -scheme IqamahWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep "BUILD"

# iOS (verify not broken)
xcodebuild -project iqamah.xcodeproj -scheme iqamah-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep "BUILD"
```

Both: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Run all tests**

```bash
xcodebuild -project iqamah.xcodeproj -scheme IqamahWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  test CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
```

Expected: `** TEST SUCCEEDED **` (7 tests)

- [ ] **Step 7: Commit**

```bash
git add IqamahWatch/ iqamah/iOS/iqamahApp_iOS.swift iqamah.xcodeproj/
git commit -m "feat(EPIC-0012): haptic notifications + WCSession sync (iPhone → Watch)"
```

---

## Task 9 — App icons + CI + final verification

**Files:**
- Create: `IqamahWatch/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add watch app icon**

Create `IqamahWatch/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images": [
    {
      "idiom": "watch",
      "scale": "2x",
      "size": "44x44"
    },
    {
      "idiom": "watch",
      "scale": "2x",
      "size": "50x50"
    },
    {
      "idiom": "watch",
      "scale": "2x",
      "size": "86x86"
    },
    {
      "idiom": "watch",
      "scale": "2x",
      "size": "98x98"
    },
    {
      "idiom": "watch",
      "scale": "2x",
      "size": "108x108"
    },
    {
      "idiom": "watch-marketing",
      "scale": "1x",
      "size": "1024x1024"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

Generate icon images using the existing `AppIconGenerator.swift` pattern or export from design tool. Place PNG files alongside `Contents.json`. For a minimum CI-passing build, Xcode accepts an asset catalog with no images (it will warn, not error, with `ASSETCATALOG_COMPILER_SKIP_APP_STORE_DEPLOYMENT = YES` in Debug).

Add to Debug build settings in pbxproj for `IqamahWatch`:
```
ASSETCATALOG_COMPILER_SKIP_APP_STORE_DEPLOYMENT = YES;
```

- [ ] **Step 2: Add IqamahWatch to CI matrix**

Read `.github/workflows/ci.yml`. Find the `Build (Debug)` job step that runs `xcodebuild`. After the existing macOS build step, add:

```yaml
      - name: Build IqamahWatch (Debug)
        run: |
          xcodebuild \
            -project ${{ env.PROJECT }} \
            -scheme IqamahWatch \
            -configuration Debug \
            -destination 'platform=watchOS Simulator,OS=latest,name=Apple Watch Series 9 (45mm)' \
            build \
            CODE_SIGNING_ALLOWED=NO \
            | xcpretty --color && exit ${PIPESTATUS[0]}
```

And add to the Test job:

```yaml
      - name: Run IqamahWatch tests
        run: |
          xcodebuild \
            -project ${{ env.PROJECT }} \
            -scheme IqamahWatch \
            -configuration Debug \
            -destination 'platform=watchOS Simulator,OS=latest,name=Apple Watch Series 9 (45mm)' \
            test \
            CODE_SIGNING_ALLOWED=NO \
            | xcpretty --color && exit ${PIPESTATUS[0]}
```

- [ ] **Step 3: Verify macOS target still builds (regression check)**

```bash
xcodebuild -project iqamah.xcodeproj -scheme iqamah \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep "BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run swiftformat + swiftlint on all new watch files**

```bash
swiftformat IqamahWatch/ IqamahWatchWidget/ IqamahWatchTests/
swiftlint lint --strict --quiet IqamahWatch/ IqamahWatchWidget/ IqamahWatchTests/
```

Fix any violations before committing.

- [ ] **Step 5: Final commit + push**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat(EPIC-0012): Apple Watch app — prayer times, Qibla, complications, notifications

Two new targets: IqamahWatch (watchOS 10, SwiftUI) + IqamahWatchWidget (WidgetKit)

IqamahWatch:
- 3-tab TabView: Prayer Times | Qibla | Settings
- Prayer list: 6-row two-column grid, next prayer gold + pill highlight,
  past prayers 28% opacity, Hijri date header with offset
- Qibla tab: arc ring + Ka'bah icon + live CLHeading turn instruction
- Settings tab: method picker, Asr picker, per-prayer adjustments ±15m,
  notification toggle, 24h toggle, GPS location update
- First-launch: on-watch CLLocationManager GPS, no iPhone required
- WCSession: receives transferUserInfo from iPhone, silently updates App Group

IqamahWatchWidget:
- PrayerEntry (5 fields) + PrayerTimelineProvider (.policy .after)
- 4 families: .accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline
- widgetAccentColor #FFD60A registered in Assets

WatchNotificationScheduler:
- UNNotificationRequest per enabled prayer, 7-day rolling window
- System haptic only (watchOS limitation)

IqamahCore:
- qiblaBearing(from:) + distanceToMakkahKm(from:) added

Tests: 7 unit tests (5 timeline + 2 Qibla) — all passing
CI: IqamahWatch added to build + test matrix

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"

git push -u origin feat/EPIC-0012-watch-app
```

- [ ] **Step 6: Open PR**

```bash
gh pr create --base develop \
  --title "feat(EPIC-0012): Apple Watch app — prayer times, Qibla, complications" \
  --body "$(cat <<'EOF'
## Summary

Native watchOS app (EPIC-0012) — fully independent, no iPhone required at runtime.

## What ships

| Component | Description |
|-----------|-------------|
| `IqamahWatch` | 3-tab SwiftUI app: Prayer Times, Qibla, Settings |
| `IqamahWatchWidget` | 4 WidgetKit complication families |
| `IqamahCore` | `qiblaBearing` + `distanceToMakkahKm` |
| `IqamahWatchTests` | 7 unit tests |

## ACs covered

AC-0252 through AC-0275 (all 24 ACs of EPIC-0012)

## Test plan

- [x] 7 unit tests passing
- [x] macOS BUILD SUCCEEDED
- [x] iOS BUILD SUCCEEDED  
- [x] IqamahWatch BUILD SUCCEEDED
- [ ] All 4 complications render in Watch Simulator
- [ ] Gold accent on tinted watch face
- [ ] Qibla arc rotates with simulated heading
- [ ] Haptic fires at prayer time (physical watch)
- [ ] First-launch GPS without iPhone

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review Notes

**Spec coverage check:**
- ✅ AC-0252/253: IqamahWatch target, IqamahCore dep → Task 2
- ✅ AC-0254: Universal purchase bundle ID prefix → Task 2 build settings
- ✅ AC-0255: Prayer list on launch → Task 5
- ✅ AC-0256–261: WidgetKit provider + 4 families → Tasks 3+4
- ✅ AC-0262: Complications read from App Group → Task 3 (SettingsManager default init)
- ✅ AC-0263–267: Haptic notifications → Task 8
- ✅ AC-0268: On-watch PrayerCalculator → Task 5
- ✅ AC-0269: WCSession transferUserInfo → Task 8
- ✅ AC-0270: First-launch placeholder → Task 5 (LocationSetupView)
- ✅ AC-0271: App Group fallback → Task 5 (WatchLocationSetup starts only if coord nil)
- ✅ AC-0272: List + Digital Crown → Task 5 (List with .plain style)
- ✅ AC-0273: Gold highlight + dimmed past → Task 5
- ✅ AC-0274: 12h/24h → Task 5 (formattedTime uses use24HourTime)
- ✅ AC-0275: App icon → Task 9

**Last Updated:** 2026-05-10
