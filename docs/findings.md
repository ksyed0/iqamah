# findings.md — Research, Discoveries & Constraints

Documents research outcomes, technical discoveries, dependency justifications, and constraints discovered during development.

---

## 🔍 Code Analysis Findings

### **Existing Features Identified (2026-03-12)**

**Prayer Times Display:**
- Displays 6 prayer times: Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha
- Each prayer shows icon, name, time, and adjustment value
- Next prayer is highlighted with accent color
- Times are monospaced for clean alignment

**Time Adjustments:**
- User can adjust individual prayers in 1-minute increments
- Adjustments persist via `SettingsManager`
- Adjustment value displayed in red
- ±1 minute buttons appear on row hover

**Location Services:**
- Uses CoreLocation for user coordinates
- Handles authorization states (not determined, authorized, denied)
- Supports both delegate-based and async/await patterns
- Location accuracy: kilometer level (not precise GPS)

**Date Display:**
- Shows both Gregorian and Hijri (Islamic) dates
- Updates every 60 seconds via timer
- Recalculates prayer times at midnight

**Qiblah Feature:**
- Sheet modal presentation
- Takes latitude/longitude as input
- Implementation details in `QiblahView.swift`

**App Icon:**
- Programmatically generated using SwiftUI
- Golden minaret with lowercase "i" design
- Export tool creates all required sizes
- Manual asset catalog setup required

**UI/UX Features:**
- Window size: 580-620px wide, 640-680px tall
- Header includes app icon, city name, calculation method, Qiblah and settings buttons
- Hover states on prayer rows reveal controls
- Clean modern design with rounded corners and subtle shadows

---

## 🧩 Dependencies Analysis

**Native Frameworks (No External Dependencies):**
- ✅ **Foundation** — Date/time, UserDefaults, basic utilities
- ✅ **SwiftUI** — UI framework
- ✅ **CoreLocation** — Location services

**Third-Party Packages:**
- None identified yet in visible code
- Prayer calculation appears to be custom implementation (internal)

**Unknown Implementations:**
- `PrayerCalculator` — not yet examined
- `SettingsManager` — not yet examined
- `City` model — not yet examined
- `CalculationMethod` enum — not yet examined
- `AsrJuristicMethod` enum — not yet examined

---

## ⚠️ Technical Constraints Discovered

1. **Thread Safety:** `LocationService` requires `@MainActor` because it publishes to UI
2. **Location Timing:** Location must be available before prayer times can be calculated
3. **Permission Flow:** Location permission blocks app functionality if denied
4. **Date Boundary:** Prayer times must recalculate at midnight in user's timezone
5. **Timer Precision:** 60-second timer may cause 1-minute lag in "next prayer" highlighting

---

## 🔬 Research Needed

1. **Prayer Calculation Algorithm:**
   - What library/formula is used?
   - How accurate is it across different geographic locations?
   - Does it handle edge cases (high latitudes, polar regions)?

2. **Settings Persistence:**
   - UserDefaults or SwiftData?
   - What happens if settings are corrupted?
   - Is there a settings reset mechanism?

3. **Calculation Methods:**
   - How many methods are supported?
   - Which organizations define these methods?
   - Are they user-selectable?

4. **Notifications:**
   - Are prayer time notifications implemented?
   - If yes, how are they scheduled?
   - Do they respect Do Not Disturb?

5. **City Selection:**
   - Is there a city database/search?
   - Manual coordinate entry?
   - GPS-only?

---

## 📊 Test Coverage Status

**Current Coverage:** 0% (no test suite exists)  
**Target:** ≥80% per AGENTS.md §8  
**Blocker:** Test suite must be created before any new features

---

## 🎯 Architectural Decisions Needed

1. **Error Handling Strategy:** Need to define error taxonomy per AGENTS.md §13
2. **API Design:** If external APIs are added, need versioning per AGENTS.md §15
3. **Accessibility:** Need WCAG 2.1 AA audit per AGENTS.md §16
4. **Performance Baselines:** Need to measure and document per AGENTS.md §17
5. **Logging:** Need structured logging implementation per AGENTS.md §18

---

**Last Updated:** 2026-03-12 (Project Initialization)
