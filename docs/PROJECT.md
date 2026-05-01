# PROJECT.md — Project Constitution

**Project Name:** Iqamah  
**Platform:** macOS  
**Language:** Swift (SwiftUI)  
**Type:** Prayer Times Application  
**Version:** 1.0.0 (In Development)

---

## §1 — Project North Star

**Singular Desired Outcome:**
Enable macOS users to:
1. **Find their location** automatically via GPS or manually via city selection
2. **Calculate accurate Islamic prayer times** based on location and selected calculation methodology
3. **Determine the Islamic Hijri date** corresponding to the current Gregorian date
4. **Find the Qibla direction** using compass visualization

**Success Criteria:**
- Prayer times are calculated accurately using astronomy-based algorithms
- Users can select from multiple recognized calculation methods (MWL, ISNA, Egyptian, Umm Al-Qura, Karachi, Tehran)
- Hijri date conversion is accurate and automatic
- Qibla bearing is calculated precisely from user location to Ka'bah coordinates

---

## §2 — Integrations & Services

**External Services:** None required at this time.

**Native macOS Frameworks Used:**
- **CoreLocation** — User location services (GPS or manual city selection)
- **Foundation** — Date/time calculations, UserDefaults persistence
- **SwiftUI** — User interface
- **CoreGraphics** — Custom shapes (prayer mat, compass, Ka'bah icon)

**Local Data Sources:**
- `cities.json` — Database of cities with coordinates and timezones
- All prayer time calculations performed locally using astronomical algorithms

**No API keys or credentials required.**

---

## §3 — Source of Truth

**Primary Data Storage:** User's device (local) with iCloud sync

**Data Categories:**

1. **User Preferences** (persisted via UserDefaults with iCloud sync):
   - Selected city (name, country code, coordinates, timezone)
   - Calculation method (MWL, ISNA, etc.)
   - Asr juristic method (Standard/Hanafi)
   - Prayer time adjustments (±minutes per prayer)
   - Setup completion status

2. **Cities Database** (static bundled JSON):
   - `cities.json` — Pre-loaded city database with coordinates and timezones
   - Loaded via `CitiesLoader.shared`

3. **Calculated Data** (ephemeral, recalculated daily):
   - Prayer times for current date
   - Hijri date conversion
   - Qibla bearing

**Data Flow:**
```
User Location → Coordinates → PrayerCalculator → PrayerTimes
                                     ↓
                            SettingsManager (adjustments) → Final Display Times
```

---

## §4 — Delivery Payload

**Distribution Strategy:**

1. **Development Phase:**
   - GitHub public repository for version control and collaboration
   - Local Xcode builds for testing

2. **Beta Phase:**
   - TestFlight distribution for beta testers
   - Collect feedback before public launch

3. **Production Phase:**
   - Mac App Store distribution (primary)
   - Direct download option (secondary, if needed)

**Packaging Requirements:**
- Code signing with Apple Developer certificate
- Notarization for macOS Gatekeeper compliance
- App Store compliance review
- Sandboxing requirements for App Store

---

## §5 — Behavioral Rules & User Profile

**User Profile:**
- **Demographic:** Muslim macOS users of all ages
- **Technical Comfort Level:** General macOS users (not developers specifically)
- **Mental Model:** Familiar with macOS native apps (Calendar, Weather, etc.)
- **Usage Context:** Daily prayer time reference, Qibla direction when traveling
- **Primary Goals:**
  1. View accurate prayer times at a glance
  2. Find Qibla direction quickly
  3. Adjust prayer times for personal preferences (mosque timing variations)
  4. See both Gregorian and Hijri dates

**Behavioral Rules:**

**DO:**
- Request system permissions explicitly (Location, Notifications in future)
- Persist permissions state between sessions
- Use clean, modern visual design aligned with macOS Human Interface Guidelines
- Support accessibility features (VoiceOver, Dynamic Type, keyboard navigation)
- Provide clear error messages when location is unavailable
- Respect user's timezone and calculation method preferences
- Save all settings to iCloud for multi-device sync

**DO NOT:**
- Require account creation or login
- Send data to external servers
- Show prayer times without location permission (display clear prompt instead)
- Override system accessibility settings
- Use outdated or inaccurate calculation methods
- Hardcode timezones or assume location

**Future Enhancements (Not MVP):**
- Adhan (call to prayer) audio alerts
- Internationalization (i18n) with UI language selection
- Widget support for macOS
- Menu bar quick view

---

## §6 — Design System

### **Colors**

| **Element** | **Color Value** | **Usage** |
|-------------|-----------------|-----------|
| Background Gradient 1 | `#26394D` | App icon background (top) |
| Background Gradient 2 | `#141925` | App icon background (bottom) |
| Gold Gradient 1 | `#F2C20F` (RGB: 0.95, 0.76, 0.06) | Primary brand color (light) |
| Gold Gradient 2 | `#D9A521` (RGB: 0.85, 0.65, 0.13) | Primary brand color (dark) |
| Accent Color | System Accent | Highlighted prayer, interactive elements |
| Error/Adjustment | Red (System) | Time adjustments display |

### **Typography**

| **Element** | **Font** | **Size** | **Weight** |
|-------------|----------|----------|------------|
| App Title | System Serif | 20pt | Bold |
| City Name | System | 16pt | Semibold |
| Calculation Method | System | 11pt | Medium |
| Prayer Name | System | 17pt | Semibold |
| Prayer Time | System Monospaced | 22pt | Medium |
| Date (Gregorian) | System | 17pt | Semibold |
| Date (Hijri) | System | 15pt | Regular |

### **Component Patterns**

- **App Icon:** 40×40pt with 8pt rounded corners, 3pt shadow
- **Prayer Row:** 20px horizontal padding, 16px vertical padding, 10pt rounded corners
- **Icon Circle:** 44×44pt, filled with accent or secondary color at 8-15% opacity
- **Window Size:** Min 580×640pt, Ideal 620×680pt

### **Spacing**

- Header padding: 24px horizontal, 50px top, 18px bottom
- Content padding: 24px horizontal, 24px bottom
- Icon spacing: 12-14px from text
- Row internal spacing: 16px between elements

---

## §7 — Data Schema

### **Input Schema**

```json
{
  "city": {
    "name": "string",
    "latitude": "number",
    "longitude": "number",
    "timezone": "string (IANA timezone identifier)"
  },
  "calculationMethod": {
    "type": "CalculationMethod enum",
    "displayName": "string"
  },
  "asrMethod": {
    "type": "AsrJuristicMethod enum"
  },
  "date": "ISO8601 DateTime"
}
```

### **Output Schema**

```json
{
  "prayerTimes": {
    "fajr": "ISO8601 DateTime",
    "sunrise": "ISO8601 DateTime",
    "dhuhr": "ISO8601 DateTime",
    "asr": "ISO8601 DateTime",
    "maghrib": "ISO8601 DateTime",
    "isha": "ISO8601 DateTime"
  },
  "adjustments": {
    "prayerName": "integer (minutes adjustment)"
  },
  "hijriDate": "string",
  "gregorianDate": "string"
}
```

### **Location Schema**

```json
{
  "coordinate": {
    "latitude": "number",
    "longitude": "number"
  },
  "authorizationStatus": "CLAuthorizationStatus enum",
  "error": "string | null"
}
```

---

## §8 — Architectural Invariants

**Core Principles:**

1. **Prayer times MUST be calculated locally** — No external API dependency for core functionality. All astronomical calculations performed on-device using `PrayerCalculator`.

2. **Location permission MUST be requested explicitly** — Never assume authorization. Show clear prompt when denied with instructions to enable in System Settings.

3. **All times MUST display in user's local timezone** — Respect city timezone setting. Use `TimeZone(identifier: city.timezone)` for all time formatting.

4. **Prayer time adjustments MUST persist** — Settings survive app restarts via UserDefaults with iCloud sync.

5. **Date updates MUST happen automatically** — Recalculate prayer times at midnight when day changes. Timer fires every 60 seconds to detect day boundary.

6. **Next prayer MUST always be highlighted** — Visual indicator for current prayer window. First prayer after current time, or Fajr if all passed.

7. **Data MUST sync via iCloud** — User preferences, city selection, and prayer adjustments sync across devices via UserDefaults iCloud container.

8. **Calculation accuracy MUST be maintained** — Use recognized Islamic calculation methods (MWL, ISNA, Egyptian, Umm Al-Qura, Karachi, Tehran) with correct astronomical parameters.

9. **Qibla bearing MUST be precise** — Calculate from user coordinates to Ka'bah coordinates (21.4225°N, 39.8262°E) using great circle navigation.

10. **UI MUST be accessible** — Support VoiceOver, Dynamic Type, keyboard navigation. Meet WCAG 2.1 AA standards.

11. **macOS version compatibility** — Support macOS versions from the last 5 years (macOS 12.0 Monterey minimum as of 2026).

---

## §9 — Known Dependencies

| **Package** | **Version** | **Purpose** | **License** |
|-------------|-------------|-------------|-------------|
| CoreLocation | System (macOS SDK) | User location services | Apple SDK |
| SwiftUI | System (macOS SDK) | UI framework | Apple SDK |
| Foundation | System (macOS SDK) | Date/time, UserDefaults | Apple SDK |
| CoreGraphics | System (macOS SDK) | Custom shapes | Apple SDK |

**No third-party dependencies.** All functionality uses native macOS frameworks.

**Bundled Resources:**
- `cities.json` — Cities database with coordinates and timezones (bundled with app)

---

## §10 — Maintenance Log

| **Date** | **Version** | **Change** | **Author** |
|----------|-------------|------------|------------|
| 2026-03-12 | 0.1.0 | Project initialization, Discovery Questions answered | AI Agent |
| 2026-03-12 | 0.1.0 | PROJECT.md updated with confirmed vision and data schema | AI Agent |

---

## §11 — Testing Strategy

**Test Framework:** Swift Testing (preferred) or XCTest  
**Target Coverage:** ≥80% for all production code  
**CI Integration:** GitHub Actions (run tests on every PR)

**Critical Test Areas:**

1. **Prayer Time Calculation Accuracy**
   - Test against known prayer times for major cities
   - Verify all 6 calculation methods produce expected results
   - Test edge cases: high latitudes, polar regions, date boundary (23:59 → 00:00)
   - Validate Asr calculation for both Hanafi and Standard methods

2. **Location Service Authorization Flow**
   - Test all authorization states: not determined, authorized, denied, restricted
   - Verify permission persistence between sessions
   - Test fallback to manual city selection when location denied

3. **Settings Persistence and Retrieval**
   - Verify UserDefaults save/load for all settings
   - Test iCloud sync behavior (mock iCloud container)
   - Test prayer time adjustment persistence

4. **Date Boundary Transitions**
   - Test midnight recalculation (23:59 → 00:00)
   - Verify Hijri date updates correctly
   - Test timer-based day change detection

5. **Time Zone Handling**
   - Test cities in different timezones
   - Verify daylight saving time transitions
   - Test edge cases: UTC, UTC+14, UTC-12

6. **Qibla Calculation Accuracy**
   - Test bearing calculation for known locations
   - Verify antipodal point handling (opposite side of Earth from Ka'bah)
   - Test cardinal direction mapping (N, NE, E, SE, S, SW, W, NW)

7. **UI State Management**
   - Test next prayer highlighting logic
   - Verify timer updates current time without recalculating prayers
   - Test hover states and adjustment controls

8. **Accessibility**
   - VoiceOver labels for all interactive elements
   - Keyboard navigation completeness
   - Dynamic Type scaling

---

## §12 — Deployment Strategy

**Target Platform:** macOS 12.0 Monterey or later (last 5 years as of 2026)  
**Minimum macOS Version:** 12.0 (released October 2021)

**Distribution Timeline:**

1. **Development (Current)**
   - GitHub public repository
   - Local Xcode builds
   - Version: 0.x.x (pre-release)

2. **Beta Testing (Future)**
   - TestFlight distribution
   - Invite-only beta testers
   - Version: 1.0.0-beta.x

3. **Production Launch (Future)**
   - Mac App Store distribution
   - Public release
   - Version: 1.0.0

**Code Signing & Notarization:**
- Apple Developer Program membership required
- Code signing certificate: "Developer ID Application" for direct download, "Mac App Store" for App Store
- Notarization via Xcode or notarytool for distribution outside App Store
- App Sandbox enabled (required for App Store)

**App Store Requirements:**
- Privacy Policy (location data usage disclosure)
- App Store screenshots and promotional materials
- App Store description and keywords
- App category: Productivity or Lifestyle
- Age rating: 4+ (no restricted content)

---

**Status:** ✅ Discovery Complete — Ready for Release Planning
