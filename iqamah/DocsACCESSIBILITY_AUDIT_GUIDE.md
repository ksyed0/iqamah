# Accessibility Audit Guide — WCAG 2.1 AA Compliance

**App:** Iqamah  
**Standard:** WCAG 2.1 Level AA  
**Date:** 2026-03-12  
**Auditor:** [Name]

---

## ✅ Pre-Audit Checklist

- [ ] VoiceOver enabled (System Settings → Accessibility → VoiceOver)
- [ ] Accessibility Inspector open (Xcode → Open Developer Tool → Accessibility Inspector)
- [ ] Color contrast analyzer tool ready (e.g., Color Contrast Analyser app)
- [ ] App running in simulator or on device

---

## 1. VoiceOver Testing

### **Goal:** All content accessible via screen reader

#### **Prayer Times Screen**

- [ ] **App name and city** — VO announces "Iqamah" and city name
- [ ] **Date displays** — VO reads Gregorian and Hijri dates
- [ ] **Each prayer row** — VO announces prayer name, time, adjustment status, "next prayer" indicator
- [ ] **Qiblah button** — VO says "Show Qiblah direction, button"
- [ ] **Settings button** — VO says "Change location and calculation settings, button"
- [ ] **Prayer adjustment buttons (+/-)** — VO says "Increase/Decrease [Prayer] time by 1 minute"
- [ ] **Current adjustment hint** — VO provides context "Current adjustment: X minutes"

**Pass Criteria:** All elements announce their purpose clearly without visual inspection

#### **Qiblah View**

- [ ] **Close button** — VO says "Close Qiblah direction window, button"
- [ ] **Direction heading** — VO announces bearing in degrees and cardinal direction
- [ ] **Compass** — VO describes "Qiblah compass showing X degrees Y direction from your location"
- [ ] **Prayer mat icon** — VO says "Prayer mat pointing toward Qiblah"
- [ ] **Kaabah indicator** — VO says "Ka'bah direction indicator"

**Pass Criteria:** User can understand Qiblah direction without seeing compass visually

#### **Onboarding Screens**

- [ ] **Splash screen** — VO announces app name and tagline
- [ ] **Location setup** — VO reads all options ("Use Current Location", "Select City Manually")
- [ ] **Country/City pickers** — VO announces selected options
- [ ] **Calculation method selection** — VO reads method names and descriptions
- [ ] **Continue buttons** — VO says purpose and availability status

**Pass Criteria:** Complete onboarding possible using only VoiceOver

---

## 2. Keyboard Navigation

### **Goal:** All functionality accessible via keyboard only (no mouse/trackpad)

#### **Tab Order Test**

- [ ] Press Tab repeatedly — focus moves logically (top-to-bottom, left-to-right)
- [ ] Shift+Tab — focus moves backward correctly
- [ ] No focus traps — can always move forward or backward
- [ ] Focus indicator visible — clear outline or highlight on focused element

#### **Keyboard Shortcuts**

- [ ] **Cmd+Q** — Quits app
- [ ] **Esc** — Closes modal windows (Qiblah view)
- [ ] **Space/Return** — Activates buttons
- [ ] **Arrow keys** — Navigate within pickers and lists

**Pass Criteria:** Complete app navigation without touching mouse

---

## 3. Color Contrast (WCAG 2.1 AA: 4.5:1 for text, 3:1 for large text/UI)

### **Text Pairs to Check**

| **Element** | **Foreground** | **Background** | **Ratio** | **Required** | **Pass/Fail** |
|-------------|----------------|----------------|-----------|--------------|---------------|
| App title (gold) | #F2C20F | Window BG | ___ : 1 | 4.5:1 | ☐ |
| Prayer name | Primary text | Window BG | ___ : 1 | 4.5:1 | ☐ |
| Prayer time | Primary text | Window BG | ___ : 1 | 4.5:1 | ☐ |
| Adjustment value (red) | Red | Window BG | ___ : 1 | 4.5:1 | ☐ |
| Hijri date (secondary) | Secondary text | Window BG | ___ : 1 | 4.5:1 | ☐ |
| Next prayer highlight | Primary text | Accent BG | ___ : 1 | 4.5:1 | ☐ |
| Button text | Button FG | Button BG | ___ : 1 | 4.5:1 | ☐ |

**Tool:** Use Color Contrast Analyser app or online tool (e.g., WebAIM Contrast Checker)

**Method:**
1. Take screenshot of each element
2. Use eyedropper to get exact hex colors
3. Enter into contrast checker
4. Record ratio

**Pass Criteria:** All ratios meet or exceed required minimum

---

## 4. Information Not Conveyed by Color Alone

### **Elements to Check**

- [ ] **Next prayer indicator** — Uses background color AND text/icon indicator
- [ ] **Prayer adjustment** — Uses red text AND explicit "+5" or "-3" label
- [ ] **Error states** — Uses color AND icon/text message
- [ ] **Status indicators** — Use color AND symbol/text

**Test Method:** View app in grayscale mode (System Settings → Accessibility → Display → Color Filters → Grayscale)

**Pass Criteria:** All information still understandable in grayscale

---

## 5. Dynamic Type Support

### **Goal:** App scales text with system text size settings

#### **Test Procedure**

1. System Settings → Accessibility → Display → Text Size
2. Move slider to **smallest** setting → Check app
3. Move slider to **largest** setting → Check app

#### **Check Points**

- [ ] All text scales proportionally
- [ ] No truncation occurs
- [ ] Layout adapts without overlapping
- [ ] Buttons remain usable
- [ ] Scrolling enabled if content doesn't fit

**Pass Criteria:** App remains fully usable at all text sizes

---

## 6. Reduced Motion

### **Goal:** Respects user's motion sensitivity

#### **Test Procedure**

1. System Settings → Accessibility → Motion → Reduce motion (ON)
2. Launch app
3. Navigate through all screens

#### **Check Points**

- [ ] Animations simplified or removed
- [ ] No spinning/rotating elements
- [ ] Transitions are instant or fade-based
- [ ] Essential animations still provide feedback

**Pass Criteria:** App usable without triggering motion sickness

---

## 7. Focus Indicators

### **Goal:** Keyboard focus always visible

#### **Test All Interactive Elements**

- [ ] Buttons show clear focus ring
- [ ] Pickers show focus indicator
- [ ] Text fields show focus indicator
- [ ] Custom controls show focus state
- [ ] Focus indicator has sufficient contrast (3:1 minimum)

**Pass Criteria:** Never lose track of keyboard focus

---

## 8. Touch/Click Targets

### **Goal:** All targets at least 44×44 points (iOS) / 24×24 points (macOS)

#### **Minimum Sizes**

- [ ] Prayer adjustment buttons (+/-) — 22pt icons, should be 24pt+ ⚠️
- [ ] Qiblah button — 20pt icon, 40pt touch area ✓
- [ ] Settings button — 18pt icon, touch area? _____
- [ ] Close button — 20pt icon, adequate touch area? _____

**Action Items:**
- Consider increasing prayer adjustment button size to 24pt
- Add larger tap target padding if needed

---

## 9. Semantic HTML/UI Elements

### **Goal:** Use platform-native controls

- [ ] Buttons use `Button` (not clickable text)
- [ ] Pickers use native `Picker`
- [ ] Text uses native `Text` (not images)
- [ ] Headers use semantic markup (`.font(.title)`, `.accessibilityAddTraits(.isHeader)`)

**Pass Criteria:** All controls use appropriate semantic elements

---

## 10. Error Messages

### **Goal:** Errors are clear, actionable, and accessible

#### **Test Error Scenarios**

- [ ] Location denied — Clear message with recovery steps
- [ ] cities.json missing — Error message explains problem
- [ ] Invalid coordinates — User-friendly explanation
- [ ] Network failure — Helpful guidance

#### **Check Points**

- [ ] Error messages announced by VoiceOver
- [ ] Messages explain what went wrong
- [ ] Messages suggest how to fix
- [ ] Error messages have sufficient contrast
- [ ] Errors don't use color alone

**Pass Criteria:** User can understand and recover from all error states

---

## Audit Summary

### **Results by Category**

| **Category** | **Pass** | **Fail** | **N/A** | **Notes** |
|--------------|----------|----------|---------|-----------|
| VoiceOver Support | ☐ | ☐ | ☐ | _____ |
| Keyboard Navigation | ☐ | ☐ | ☐ | _____ |
| Color Contrast | ☐ | ☐ | ☐ | _____ |
| Color Independence | ☐ | ☐ | ☐ | _____ |
| Dynamic Type | ☐ | ☐ | ☐ | _____ |
| Reduced Motion | ☐ | ☐ | ☐ | _____ |
| Focus Indicators | ☐ | ☐ | ☐ | _____ |
| Touch Targets | ☐ | ☐ | ☐ | _____ |
| Semantic Elements | ☐ | ☐ | ☐ | _____ |
| Error Handling | ☐ | ☐ | ☐ | _____ |

### **Overall Assessment**

- [ ] **PASS** — Meets WCAG 2.1 AA
- [ ] **CONDITIONAL PASS** — Minor issues, acceptable for release
- [ ] **FAIL** — Major issues require fixing before release

---

## Issues Found

### **Issue 1**
**Severity:** Critical / High / Medium / Low  
**Category:** _____  
**Description:** _____  
**WCAG Criteria Violated:** _____  
**Recommended Fix:** _____  
**Bug ID:** BUG-XXXX

### **Issue 2**
**Severity:** Critical / High / Medium / Low  
**Category:** _____  
**Description:** _____  
**WCAG Criteria Violated:** _____  
**Recommended Fix:** _____  
**Bug ID:** BUG-XXXX

---

## Recommendations

1. _____________________________________
2. _____________________________________
3. _____________________________________

---

## Re-Audit Required

- [ ] Yes — Critical issues found
- [ ] No — All issues minor or fixed
- [ ] N/A — No issues found

**Re-Audit Date:** _____

---

**Auditor Signature:** ___________________  
**Date:** ___________________

---

**Accessibility Statement (for App Store):**

"Iqamah is committed to accessibility. The app meets WCAG 2.1 Level AA standards and supports:
- Full VoiceOver compatibility
- Keyboard navigation
- Dynamic Type
- Reduced motion preferences
- High contrast modes
- All essential functions accessible without vision"

---

**End of Accessibility Audit Guide**
