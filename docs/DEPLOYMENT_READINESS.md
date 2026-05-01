# DEPLOYMENT_READINESS.md — Comprehensive Project Status

**Date:** 2026-03-12  
**Project:** Iqamah macOS Prayer Times App  
**Version:** 0.1.0 (Pre-MVP)

---

## 🚦 Deployment Readiness Status: 🔴 **BLOCKED**

**Cannot deploy to production.** Critical issues and missing implementations must be resolved first.

---

## 📊 Implementation Status Summary

### **Completed Features** ✅

**Total Implemented User Stories:** 8/13 MVP stories (61.5%)

1. **US-0002:** City Selection from Database ✅
2. **US-0003:** Auto-suggest nearest city from GPS ✅
3. **US-0004:** Display accurate prayer times ✅
4. **US-0005:** 6 calculation methods supported ✅
5. **US-0006:** Asr juristic methods (Standard/Hanafi) ✅
6. **US-0007:** Prayer time adjustments (±minutes) ✅
7. **US-0008:** Gregorian + Hijri date display ✅
8. **US-0009:** Qibla direction calculation ✅
9. **US-0010:** Compass interface for Qibla ✅

**Bonus Feature (Not in MVP):**
- **US-0019:** Status bar menu integration ✅

---

### **Critical Missing Implementations** 🔴

**BLOCKER:** App will not compile without these.

1. **BUG-0001:** Missing view implementations
   - `SplashScreenView.swift` — Not implemented
   - `LocationSetupView.swift` — Not implemented
   - `CalculationMethodView.swift` — Not implemented
   - **Impact:** App crashes at compilation
   - **Story:** US-0018 (Onboarding & First Launch) — NEW STORY

2. **BUG-0008:** Missing `cities.json` resource
   - File referenced in code but not found in project
   - **Impact:** City selection will fail at runtime
   - **Story:** US-0002

---

### **Critical Bugs** 🐛

**Total Bugs Found:** 9  
**Critical:** 3 (4 including missing implementations)  
**High:** 3  
**Medium:** 2  

**Must Fix Before MVP:**

1. **BUG-0003:** `fatalError` in PrayerCalculator (app crash risk)
   - Violates AGENTS.md §13 (Error Handling Standard)
   - Replace with proper `throw IqamahError.invalidDate`

2. **BUG-0002:** No error handling for cities.json load failure
   - App shows empty pickers with no explanation
   - Need graceful fallback

3. **BUG-0004:** No coordinate validation
   - Can lead to incorrect prayer calculations
   - Need to validate lat ∈ [-90, 90], lon ∈ [-180, 180]

4. **BUG-0009:** Missing accessibility labels
   - Violates WCAG 2.1 AA (AGENTS.md §16)
   - VoiceOver users cannot use the app

---

### **Testing Status** 🧪

| **Test Category** | **Status** | **Coverage** | **Required** |
|-------------------|------------|--------------|--------------|
| Unit Tests        | ⚠️ Partial  | ~15%         | ≥80%         |
| Functional Tests  | 🔴 None    | 0%           | 100% of ACs  |
| Accessibility Tests | 🔴 None  | 0%           | WCAG 2.1 AA  |
| Performance Tests | ⚠️ Partial  | 1 test       | All baselines |
| Integration Tests | 🔴 None    | 0%           | Key flows    |

**Blocker:** Test coverage is ~15% (requirement: ≥80% per AGENTS.md §8)

**Created Tests:**
- ✅ `Tests/PrayerCalculatorTests.swift` — 25 test cases covering:
  - All 6 calculation methods
  - Asr juristic methods
  - High latitude edge cases
  - Timezone handling
  - Major Islamic cities validation
  - Hijri date conversion
  - Performance benchmarks

**Missing Tests:**
- 🔴 LocationService tests (authorization flow, GPS, errors)
- 🔴 SettingsManager tests (persistence, iCloud sync)
- 🔴 City model tests (validation, distance calculation)
- 🔴 QiblahView tests (bearing accuracy, compass UI)
- 🔴 PrayerTimesView tests (UI state, timer, adjustments)
- 🔴 AppDelegate tests (status bar updates, menu actions)
- 🔴 Integration tests (onboarding flow, end-to-end)

---

## 📋 Release Plan Analysis

### **MVP Scope (v1.0.0)**

**Epics:** 4  
**User Stories:** 13 (8 implemented, 1 needs creation, 4 QA)  
**Acceptance Criteria:** 70 (AC-0001 through AC-0070)

**Epic Completion:**
- **EPIC-0001:** Location & City Selection — 🟡 67% (US-0001 pending verification, US-0002 ✅, US-0003 ✅)
- **EPIC-0002:** Prayer Times Calculation — ✅ 100% (US-0004 through US-0008 all implemented)
- **EPIC-0003:** Qibla Direction — ✅ 100% (US-0009, US-0010 implemented)
- **EPIC-0004:** Testing & QA — 🔴 0% (US-0011, US-0012, US-0013 not started)

---

### **NEW User Story Required**

**US-0018 (EPIC-0001):** As a new user, I want a guided onboarding flow, so that I can set up the app quickly.

**Description:** Splash screen → Location setup → Calculation method selection → Prayer times display

**Priority:** Critical (blocking compilation)  
**Estimate:** 8 Story Points  
**Status:** 🔴 Not Started

**Acceptance Criteria:**
- AC-0071: Splash screen displays app branding for 2-3 seconds (skippable)
- AC-0072: Location setup offers GPS or manual city selection
- AC-0073: Calculation method selection shows 6 methods with descriptions
- AC-0074: Setup completion saves all settings via SettingsManager
- AC-0075: Returning users skip directly to prayer times view
- AC-0076: Settings can be changed later without re-onboarding

**Components to Implement:**
1. `SplashScreenView` — Branding screen with app icon
2. `LocationSetupView` — GPS permission request + city picker
3. `CalculationMethodView` — Method selection with Asr option

---

## 🔧 Deployment Blockers

### **Phase 1: Compilation Blockers (Immediate)**

1. ✅ **Implement SplashScreenView**
   - Display app icon/branding
   - 2-3 second delay (skippable on tap)
   - Transition to location setup or main view

2. ✅ **Implement LocationSetupView**
   - GPS permission request UI
   - City selection from database
   - Country/city pickers
   - Handle cities.json load failures

3. ✅ **Implement CalculationMethodView**
   - Show 6 calculation methods with descriptions
   - Asr method selection (Standard/Hanafi)
   - Save button to complete setup

4. ✅ **Create or locate cities.json**
   - Minimum: 50+ major Islamic cities worldwide
   - Format: `[{name, countryCode, latitude, longitude, timezone}]`
   - Include Ka'bah coordinates validation

---

### **Phase 2: Critical Bug Fixes (Before MVP)**

1. ✅ **Fix BUG-0003:** Replace fatalError with throws
2. ✅ **Fix BUG-0002:** Graceful cities.json error handling
3. ✅ **Fix BUG-0004:** Add coordinate validation
4. ✅ **Fix BUG-0009:** Add accessibility labels

---

### **Phase 3: Test Coverage (Before MVP)**

1. ✅ **Create comprehensive unit test suite**
   - Target: ≥80% coverage
   - All models, services, calculators
   - Use Swift Testing framework

2. ✅ **Create functional test cases**
   - Map to all 70 acceptance criteria
   - Document in `docs/TEST_CASES.md`
   - Include pass/fail status

3. ✅ **Conduct accessibility audit**
   - VoiceOver testing
   - Keyboard navigation
   - Color contrast validation
   - Dynamic Type support

4. ✅ **Establish performance baselines**
   - Prayer calculation: <100ms
   - City database load: <500ms
   - UI updates: <50ms
   - Memory usage: <100MB
   - App launch: <2s

---

### **Phase 4: Quality Assurance (Before Beta)**

1. ✅ **Fix medium-priority bugs**
   - BUG-0005: Timer memory leak in PrayerTimesView
   - BUG-0006: AppDelegate timer lifecycle

2. ✅ **Code review and refactoring**
   - Remove duplicate AppIconView definition (exists in both ContentView.swift and AppIconView.swift)
   - Consolidate error handling per ERROR_TAXONOMY.md
   - Apply lessons to LESSONS.md

3. ✅ **Documentation completion**
   - API documentation (inline comments)
   - User guide (README.md)
   - Developer onboarding (CONTRIBUTING.md)

---

## 📈 Test Coverage Roadmap

### **Current Coverage: ~15%**

**Covered:**
- PrayerCalculator (25 test cases) ✅
- Hijri date conversion ✅
- Basic performance test ✅

**Missing Coverage (65% gap):**

| **Component** | **Test Cases Needed** | **Estimated Tests** |
|---------------|----------------------|---------------------|
| LocationService | Authorization states, GPS, errors, async/await | 10 tests |
| SettingsManager | Save/load, iCloud sync, adjustments | 8 tests |
| City/CitiesDatabase | Validation, distance, closest city, JSON parsing | 10 tests |
| QiblahView | Bearing calculation, compass UI | 5 tests |
| Prayer Times UI | Highlighting, timer, adjustments | 8 tests |
| AppDelegate | Status bar, menu, timer, window management | 8 tests |
| Integration | Onboarding flow, settings persistence end-to-end | 6 tests |
| Edge Cases | Invalid data, nil handling, timezone edge cases | 10 tests |

**Total Additional Tests Required:** ~65 tests

---

## ✅ Action Plan to Unblock Deployment

### **Step 1: Implement Missing Views (Est: 6-8 hours)**

Create three view files with proper implementation:

```
/iqamah/Views/SplashScreenView.swift
/iqamah/Views/LocationSetupView.swift
/iqamah/Views/CalculationMethodView.swift
```

### **Step 2: Create cities.json (Est: 2 hours)**

Populate with 50+ major cities:
- Makkah, Madinah, Riyadh, Jeddah
- Istanbul, Cairo, Jakarta, Kuala Lumpur
- London, New York, Toronto, Sydney
- Include all required fields (lat, lon, timezone)

### **Step 3: Fix Critical Bugs (Est: 4 hours)**

- Replace `fatalError` with `throw` statements
- Add coordinate validation
- Implement cities.json error handling
- Add accessibility labels

### **Step 4: Expand Test Suite (Est: 8-10 hours)**

- Write 65 additional unit tests
- Achieve ≥80% coverage
- Document test cases in TEST_CASES.md

### **Step 5: Accessibility Audit (Est: 3 hours)**

- VoiceOver walkthrough
- Keyboard navigation testing
- Color contrast validation
- Fix identified issues

### **Step 6: Performance Validation (Est: 2 hours)**

- Measure all baseline metrics
- Optimize if needed
- Document results

---

## 🎯 Estimated Time to MVP Readiness

**Total Effort:** 25-30 hours  
**Timeline:** 3-4 working days (assuming full-time work)

**Breakdown:**
- Missing implementations: 6-8 hours
- Bug fixes: 4 hours
- Test suite expansion: 8-10 hours
- Accessibility audit: 3 hours
- Performance validation: 2 hours
- Documentation: 2 hours

---

## 📝 Recommendations

1. **Prioritize BUG-0001** — App won't compile until views are implemented
2. **Create cities.json immediately** — Use a curated list of 50-100 cities
3. **Replace all `fatalError` calls** — Critical safety issue
4. **Automate test coverage reporting** — Add to CI/CD pipeline
5. **Consider test-driven development** — Write tests before fixing bugs

---

## 🎓 Lessons Learned (to be encoded in LESSONS.md)

1. **Never reference unimplemented views in production code** — Always stub or use conditional compilation
2. **Always bundle required resources** — cities.json should have been verified
3. **Avoid `fatalError` in production code** — Use proper error handling
4. **Accessibility is not optional** — Should be built in from day one
5. **Test coverage should be tracked from day one** — Not a post-development task

---

**Status:** Deployment readiness assessment complete. Awaiting implementation of action plan.

**Next Step:** Begin Step 1 (Implement missing views) or request prioritization guidance from stakeholder.
