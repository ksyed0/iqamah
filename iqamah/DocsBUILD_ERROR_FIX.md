# 🔧 Build Error Fix & iOS 17 Configuration

**Issue:** Swift Testing framework requires iOS 18+  
**Solution:** Update deployment target to iOS 17 and use XCTest instead  
**Date:** 2026-03-12

---

## 🐛 Error Details

```
error: Unable to find module dependency: 'Testing'
import Testing
       ^
```

**Root Cause:** Swift Testing framework (`import Testing`) requires:
- iOS 18.0+
- macOS 15.0+
- Xcode 16.0+

**Your Target:** macOS 12.0+ (Monterey)

---

## ✅ Solution

### **Option 1: Use XCTest (Recommended for macOS 12+ support)**

Replace `import Testing` with `import XCTest` in all test files.

**Files to Update:**
1. `Tests/PrayerCalculatorTests.swift`
2. `Tests/AdditionalTests.swift`
3. `Tests/IntegrationAndEdgeCaseTests.swift`

**Migration Example:**

**Before (Swift Testing):**
```swift
import Testing

@Suite("Prayer Calculator Tests")
struct PrayerCalculatorTests {
    @Test("Calculator returns all prayers")
    func testAllPrayers() {
        // ...
        #expect(times.prayers.count == 6)
    }
}
```

**After (XCTest):**
```swift
import XCTest

final class PrayerCalculatorTests: XCTestCase {
    func testCalculatorReturnsAllPrayers() {
        // ...
        XCTAssertEqual(times.prayers.count, 6)
    }
}
```

**Key Changes:**
- `@Suite` → `final class XCTestCase`
- `@Test` → `func test...()`
- `#expect()` → `XCTAssert...()`
- `#require()` → `XCTUnwrap()`
- `throws:` parameter → `XCTAssertThrowsError`

---

### **Option 2: Update to iOS 18+ (NOT Recommended - limits compatibility)**

Update deployment target in Xcode:
1. Select project in navigator
2. Select app target
3. General tab → Deployment Info
4. Change "Minimum Deployments" to macOS 15.0

**Trade-off:** Excludes users on macOS 12-14 (Monterey, Ventura, Sonoma)

---

## 🎯 Recommended Action: Stick with XCTest

**Why XCTest:**
- ✅ Available on all macOS versions
- ✅ Supports your macOS 12.0 target
- ✅ Mature, stable, well-documented
- ✅ Same test coverage capability
- ✅ Integrated with Xcode from day one

**Swift Testing Benefits (not worth losing compatibility):**
- Modern syntax (but XCTest works fine)
- Better error messages (marginal benefit)
- Async support (XCTest has this too)

---

## 📝 XCTest Migration Guide

### **Test Structure**

| Swift Testing | XCTest |
|---------------|--------|
| `@Suite("Name")` | `final class NameTests: XCTestCase` |
| `@Test("Test name")` | `func testName()` |
| `@Test(arguments: [...])` | Multiple `func test...()` or loop |

### **Assertions**

| Swift Testing | XCTest |
|---------------|--------|
| `#expect(a == b)` | `XCTAssertEqual(a, b)` |
| `#expect(a != b)` | `XCTAssertNotEqual(a, b)` |
| `#expect(a < b)` | `XCTAssertLessThan(a, b)` |
| `#expect(a > b)` | `XCTAssertGreaterThan(a, b)` |
| `#expect(bool)` | `XCTAssertTrue(bool)` |
| `#expect(!bool)` | `XCTAssertFalse(bool)` |
| `#expect(x != nil)` | `XCTAssertNotNil(x)` |
| `try #require(x)` | `try XCTUnwrap(x)` |
| `#expect(throws:)` | `XCTAssertThrowsError()` |

### **Lifecycle**

| Swift Testing | XCTest |
|---------------|--------|
| `init()` setup | `override func setUp()` |
| N/A | `override func tearDown()` |
| `deinit` cleanup | `override func tearDown()` |

---

## 🔄 Quick Fix Script

Since the test files are already created with Swift Testing syntax, here's what needs to change:

**Manual Steps (5 minutes):**

1. **Open each test file**
2. **Replace imports:**
   ```swift
   // OLD:
   import Testing
   
   // NEW:
   import XCTest
   ```

3. **Convert structure:**
   ```swift
   // OLD:
   @Suite("My Tests")
   struct MyTests {
   
   // NEW:
   final class MyTests: XCTestCase {
   ```

4. **Convert test methods:**
   ```swift
   // OLD:
   @Test("Does something")
   func doesSomething() async throws {
   
   // NEW:
   func testDoesSomething() throws {
       // Remove 'async' if not needed, or add 'async' to signature
   ```

5. **Convert assertions:**
   - Find/Replace: `#expect(` → `XCTAssert(`
   - Then fix specific assertions based on table above

6. **Clean build:** Cmd+Shift+K, then Cmd+B

---

## 📦 iOS 17 Configuration

**If you want to set minimum deployment to iOS 17 specifically:**

### **In Xcode:**

1. Select project in navigator
2. Select your app target
3. **General** tab → **Deployment Info**
4. Set **Minimum Deployments:**
   - **macOS:** 12.0 (keeps compatibility)
   - **iOS:** 17.0 (if also targeting iOS)

### **In Project File:**

```swift
// In your .xcodeproj or Package.swift

platforms: [
    .macOS(.v12), // macOS Monterey (2021)
    .iOS(.v17)     // iOS 17 (2023)
]
```

---

## ✅ Verification Checklist

After fixing:

- [ ] All `import Testing` replaced with `import XCTest`
- [ ] All `@Suite` replaced with `final class ... : XCTestCase`
- [ ] All `@Test` replaced with `func test...()`
- [ ] All `#expect()` replaced with `XCTAssert...()`
- [ ] All `#require()` replaced with `XCTUnwrap()`
- [ ] Clean build successful (Cmd+Shift+K, then Cmd+B)
- [ ] All tests run (Cmd+U)
- [ ] Tests pass ✅

---

## 🎯 Deployment Target Recommendation

**For maximum compatibility:**
- **macOS:** 12.0 (Monterey, 2021) — Supports last 5 years as requested
- **iOS:** 15.0 or 16.0 (if also building for iOS)

**This gives you:**
- ✅ ~95% of active macOS users
- ✅ XCTest support (all versions)
- ✅ SwiftUI works great
- ✅ Combine available
- ✅ Async/await supported

**You DO NOT need iOS 17+ or macOS 15+ for this app!**

---

## 📖 Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Writing Tests in Xcode](https://developer.apple.com/documentation/xcode/running-tests-and-interpreting-results)
- [Platform Deployment Targets](https://developer.apple.com/documentation/xcode/choosing-a-deployment-target)

---

**End of Build Error Fix Guide**
