# Manual Test Execution Checklist

**Date:** 2026-03-12  
**Tester:** [Name]  
**App Version:** 0.1.0  
**macOS Version:** [e.g., macOS 14.3]

---

## Pre-Test Setup

- [ ] App compiled successfully in Xcode
- [ ] All test files added to project
- [ ] cities.json added to Copy Bundle Resources
- [ ] Clean build completed (Cmd+Shift+K, then Cmd+B)
- [ ] Unit tests pass (Cmd+U) — Expected: 85+ tests passing

---

## Test Execution Checklist

### **EPIC-0001: Location & City Selection**

#### **US-0001: Location Permission**

- [ ] **TC-0001:** Request location permission on first launch
  - Fresh install → Launch app → Click "Use Current Location"
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0002:** Permission state persists between sessions
  - Grant permission → Quit → Relaunch → Use location
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0003:** Denied permission shows actionable message
  - Deny permission → Observe error message
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0004:** Authorization state changes handled
  - Denied → Go to System Settings → Enable → Return to app
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

#### **US-0002: Manual City Selection**

- [ ] **TC-0005:** Cities database loads from bundled JSON
  - Launch app → Go to location setup → Check country picker
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0006:** Cities browsable by country
  - Select "Saudi Arabia" → Check city picker shows Makkah, Madinah
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0008:** Selected city persists between sessions
  - Select city → Complete setup → Quit → Relaunch
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

#### **US-0003: Auto-suggest nearest city**

- [ ] **TC-0010:** Closest city calculation from GPS
  - Click "Use Current Location" → Verify closest city selected
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0011:** Auto-selected city can be overridden
  - GPS selects city → Manually select different city → Verify override
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

---

### **EPIC-0002: Prayer Time Calculation & Display**

#### **US-0004: Accurate Prayer Times**

- [ ] **TC-0012:** All 6 prayer times displayed
  - View main screen → Count prayers (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha)
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0013:** Times calculated accurately
  - Set location to known city → Compare with IslamicFinder.org (±3 min tolerance)
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0014:** Times display in local timezone
  - Select city in different timezone → Verify times shown in that TZ
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0015:** Times formatted in 12-hour with AM/PM
  - Check all times show "h:mm a" format (e.g., "6:12 AM")
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0016:** Prayer times recalculate at midnight
  - Leave app running near midnight → Verify times update for new day
  - ✓ Pass / ✗ Fail: _____ | Notes: _____ | (Optional — time-dependent)

- [ ] **TC-0017:** Next prayer highlighted
  - Check time → Verify next upcoming prayer has colored background
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

#### **US-0005: Calculation Method Selection**

- [ ] **TC-0018:** 6 calculation methods available
  - Go to calculation method screen → Count methods
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0019:** MWL method uses correct angles
  - Select MWL → Verify Fajr 18°, Isha 17° in description
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0020:** Umm Al-Qura Isha uses 90-minute interval
  - Select Umm Al-Qura → Note Maghrib time → Note Isha time → Calculate difference
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0021:** Selected method persists
  - Select ISNA → Quit → Relaunch → Verify ISNA still selected
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0022:** Prayer times update when method changes
  - Note Fajr with MWL → Change to ISNA → Verify Fajr time changes
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

#### **US-0006: Asr Calculation Methods**

- [ ] **TC-0023:** Standard and Hanafi Asr methods available
  - View Asr method options → Verify both listed
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0024:** Hanafi Asr is later than Standard
  - Note Asr with Standard → Change to Hanafi → Verify later time (30-60 min)
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

#### **US-0007: Prayer Time Adjustments**

- [ ] **TC-0025:** Adjust prayer time in 1-minute increments
  - Hover over Fajr → Click + three times → Verify +3 minutes
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0026:** Adjustment controls appear on hover
  - Move mouse over prayer row → Verify +/- buttons visible
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0027:** Adjustment value displayed in red
  - Adjust prayer → Verify adjustment shown in red (e.g., "+5")
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0028:** Adjustments persist
  - Adjust Asr by -2 → Quit → Relaunch → Verify -2 still shown
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

#### **US-0008: Gregorian + Hijri Date Display**

- [ ] **TC-0029:** Gregorian date in full format
  - Check format is "Weekday, Month Day, Year"
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0030:** Hijri date with month name
  - Check format is "Day MonthName Year AH"
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0031:** Hijri month names in English
  - Verify month name is one of: Muharram, Safar, Rabi' al-Awwal, etc.
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

---

### **EPIC-0003: Qiblah Direction Finder**

#### **US-0009: Qiblah Bearing Calculation**

- [ ] **TC-0033:** Qiblah bearing calculated from coordinates
  - Set location to New York → Open Qiblah → Verify ~58° (NE)
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0034:** Bearing displayed in degrees 0-360
  - Open Qiblah → Check bearing is 0-360 range
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0035:** Cardinal direction displayed
  - Open Qiblah → Check direction is one of: N, NE, E, SE, S, SW, W, NW
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

#### **US-0010: Compass Interface**

- [ ] **TC-0036:** Compass displays cardinal directions
  - Open Qiblah → Verify N, E, S, W labels on compass
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0037:** Tick marks every 10 degrees
  - Open Qiblah → Count tick marks (should be 36)
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0038:** North marked in red
  - Open Qiblah → Verify "N" is red
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0039:** Qiblah window is modal sheet
  - Click Qiblah button → Verify modal opens (380×480pt)
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0040:** Close button in top-right
  - Open Qiblah → Click X button → Verify sheet closes
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

---

### **EPIC-0004: Testing & Quality Assurance**

#### **US-0012: Accessibility Audit**

- [ ] **TC-0049:** All interactive elements have VoiceOver labels
  - Enable VoiceOver → Navigate all controls → Verify each announces purpose
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0050:** Tab order is logical
  - Press Tab repeatedly → Verify focus moves top-to-bottom, left-to-right
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0051:** Keyboard shortcuts work
  - Try Cmd+Q (quit), Esc (close modals)
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0052:** Color contrast meets WCAG 2.1 AA
  - Use contrast analyzer on text/background pairs (4.5:1 minimum)
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0053:** Dynamic Type supported
  - Change system text size to largest → Verify text scales, no truncation
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0054:** No information conveyed by color alone
  - Check highlighted prayer has non-color indicator
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

#### **US-0013: Performance Benchmarks**

- [ ] **TC-0055:** Prayer calculation <100ms
  - Run unit test `calculationPerformance` → Verify passes
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0056:** City database loads <500ms
  - Run unit test `databaseLoadPerformance` → Verify passes
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0057:** UI updates complete <50ms
  - Click prayer adjustment → Observe responsiveness (should feel instant)
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0058:** Memory usage <100MB
  - Open Activity Monitor → Check Iqamah memory usage
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

- [ ] **TC-0059:** App launches <2 seconds
  - Time from click to splash screen visible
  - ✓ Pass / ✗ Fail: _____ | Notes: _____

---

## Summary

**Total Tests:** 48  
**Passed:** _____  
**Failed:** _____  
**Blocked:** _____  
**Not Run:** _____  

**Pass Rate:** _____% 

**Critical Issues Found:** _____

**Notes/Observations:**
_________________________________________
_________________________________________
_________________________________________

**Recommendation:**
- [ ] Ready for Beta Release
- [ ] Minor fixes required
- [ ] Major issues — not ready

---

**Tester Signature:** ___________________  
**Date Completed:** ___________________

---

## Failed Test Details

*For each failed test, fill out:*

**TC-XXXX:**  
**Actual Result:** _____  
**Screenshots/Logs:** _____  
**Bug ID Raised:** BUG-XXXX  
**Severity:** Critical / High / Medium / Low  

---

**End of Manual Test Execution Checklist**
