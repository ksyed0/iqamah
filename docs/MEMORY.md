# MEMORY.md — Persistent Knowledge Base

Organized by topic. Updated whenever new learnings emerge. Old/wrong information is removed, not accumulated.

---

## 📱 Application Overview

**App Name:** Iqamah  
**Platform:** macOS (SwiftUI)  
**Purpose:** Display Islamic prayer times based on user location with adjustable times and Qiblah direction

---

## 🏗️ Architecture

### **Layer Structure**
- **Views:** SwiftUI views (PrayerTimesView, QiblahView, etc.)
- **Services:** LocationService (manages CoreLocation)
- **Models:** City, PrayerTimes, CalculationMethod, AsrJuristicMethod
- **Utilities:** PrayerCalculator, SettingsManager, DateFormatter extensions

### **Key Services**

**LocationService:**
- Manages CoreLocation permissions and requests
- Uses `@MainActor` for thread safety
- Provides both completion-based and async/await interfaces
- Handles authorization status changes
- Location accuracy: `kCLLocationAccuracyKilometer`

**SettingsManager:**
- Persists prayer time adjustments per prayer name
- Singleton pattern (`SettingsManager.shared`)
- Storage mechanism: *[To be verified — likely UserDefaults]*

---

## 🎨 Design System

### **App Icon Design**
- Golden minaret with lowercase "i"
- Background: Dark blue gradient (#26394D → #141925)
- Minaret/Text: Golden gradient (#F2C20F → #D9A521)
- Sizes generated: 16, 32, 64, 128, 256, 512, 1024px
- Export tool: `AppIconExporterView` (creates desktop folder)

### **Visual Hierarchy**
- Next prayer highlighted with accent color
- Hovering reveals adjustment controls (±1 minute buttons)
- Red text shows current adjustment value
- Monospaced digits for time display (alignment)

---

## 🕌 Prayer Time Calculation

**Prayers Tracked:**
1. Fajr (dawn)
2. Sunrise (not a prayer, but tracked)
3. Dhuhr (noon)
4. Asr (afternoon)
5. Maghrib (sunset)
6. Isha (night)

**Calculation Methods:**
- Multiple methods supported via `CalculationMethod` enum
- Display names exposed via `displayName` property
- Asr calculation: Two juristic methods (`AsrJuristicMethod`)

**Time Adjustments:**
- User can adjust individual prayer times in ±1 minute increments
- Adjustments persist across sessions
- Displayed in red next to prayer time
- Accessed via +/- buttons on hover

---

## 📅 Date & Time Handling

**Display Formats:**
- Gregorian: Custom format via `formattedGregorianDate()`
- Hijri (Islamic): Custom format via `formattedHijriDate()`
- Prayer times: "h:mm a" format (12-hour with AM/PM)

**Update Logic:**
- Timer fires every 60 seconds
- If day changes: Recalculate all prayer times
- If same day: Update current time only
- Next prayer detection: First prayer after current time, or Fajr if all passed

---

## 🧭 Qiblah Feature

- Sheet modal presentation
- Requires latitude/longitude input
- Implementation: `QiblahView`
- Icon: Custom `PrayerMatIcon` (20pt size)

---

## 🛠️ Technical Constraints

**Platform Requirements:**
- macOS (SwiftUI app)
- Minimum version: *[To be verified in Xcode project settings]*
- Requires location permissions (When In Use)

**Thread Safety:**
- `LocationService` uses `@MainActor` to ensure UI updates on main thread
- Async/await pattern for location requests
- `CheckedContinuation` for bridging delegate callbacks to async

**Error Handling:**
- Location errors displayed as user-facing strings
- Authorization denied: Prompts user to enable in System Settings
- Network/calculation errors: *[To be verified in PrayerCalculator]*

---

## 🔗 File Relationships

**Main Views:**
- `PrayerTimesView` → container, manages state, timer
- `PrayerTimesTable` → table layout, loads adjustments
- `PrayerTimeRow` → individual prayer row with adjustment controls
- `QiblahView` → modal sheet for Qiblah direction
- `AppIconView` → reusable icon component (used in header and splash)

**Services:**
- `LocationService` → location permission and coordinate fetching
- `SettingsManager` → prayer time adjustment persistence

**Models:**
- `City` → name, latitude, longitude, timezone
- `PrayerTimes` → calculated times for all prayers
- `CalculationMethod` → calculation algorithm enum
- `AsrJuristicMethod` → Asr calculation variant

---

## 📝 Open Questions

1. ✅ **RESOLVED:** What prayer calculation library/algorithm is used? — Custom implementation in `PrayerCalculator.swift` using astronomical algorithms
2. ✅ **RESOLVED:** Where is `SettingsManager` implemented? — UserDefaults with iCloud sync
3. ✅ **RESOLVED:** What is the minimum macOS version requirement? — macOS 12.0 Monterey (last 5 years)
4. ❓ Are notifications implemented? — No (deferred to v1.1)
5. ✅ **RESOLVED:** Is there a city selection/search feature? — Yes, implemented in `Location.swift` and `CitiesLoader`
6. ✅ **RESOLVED:** What is the `Location.swift` model structure? — City, Country, CitiesDatabase models with bundled cities.json
7. ✅ **RESOLVED:** What is the `CalculationMethod.swift` enum definition? — 6 methods (MWL, ISNA, Egyptian, Umm Al-Qura, Karachi, Tehran) with Fajr/Isha angles

**New Questions:**
1. ❓ Where is `cities.json` located? Need to verify bundled resource exists.
2. ❓ What is the ContentView.swift structure? (428 lines — likely onboarding/setup flow)
3. ❓ Is there a splash screen or onboarding flow?
4. ❓ How is first-launch setup handled?

---

**Last Updated:** 2026-03-12 (Discovery Complete + Release Plan Created)
