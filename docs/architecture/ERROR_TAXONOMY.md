# Error Taxonomy

Defines the project-wide error hierarchy for consistent, structured error handling across all application code.

---

## Error Hierarchy

All errors in this application are categorized into four primary types:

### 1. **ValidationError**
**Definition:** Bad input from the user or external system.

**When to use:**
- User enters invalid data
- API response is malformed
- Date/time is out of valid range
- Coordinates are invalid (e.g., latitude > 90°)

**Example Error Messages:**
- "Invalid city coordinates: latitude must be between -90 and 90"
- "Calculation method not recognized"
- "Date format is invalid"

**Handling Strategy:**
- Log at `WARN` level
- Return user-friendly error message
- Do not crash — provide fallback or prompt for correction

---

### 2. **IntegrationError**
**Definition:** External service (API, database, third-party) failed.

**When to use:**
- Location services denied or failed
- Network request timeout
- Third-party API returns error
- File system read/write failure

**Example Error Messages:**
- "Location services denied. Please enable in System Settings."
- "Failed to fetch prayer times from server: timeout"
- "Unable to save settings to disk"

**Handling Strategy:**
- Log at `ERROR` level with full context
- Implement retry logic with exponential backoff (for transient failures)
- Display user-friendly message with actionable next steps
- Provide offline fallback where possible

---

### 3. **BusinessLogicError**
**Definition:** A rule or constraint of the domain was violated.

**When to use:**
- Prayer time calculation produces impossible result
- Qiblah angle is out of valid range (0-360°)
- Date boundary logic fails (midnight transition)
- Time adjustment exceeds allowed range

**Example Error Messages:**
- "Calculated prayer time is before sunrise — check location coordinates"
- "Qiblah angle calculation failed: invalid geographic data"
- "Time adjustment cannot exceed ±60 minutes"

**Handling Strategy:**
- Log at `ERROR` level
- Halt the operation — do not proceed with invalid data
- Alert developer/administrator (this indicates a logic bug)
- Provide safe default or previous known-good state

---

### 4. **SystemError**
**Definition:** Unexpected internal failure (catch-all; should be rare).

**When to use:**
- Unhandled exception from framework
- Memory allocation failure
- Catastrophic state corruption
- Unknown error from third-party library

**Example Error Messages:**
- "An unexpected error occurred. Please restart the app."
- "System resource unavailable"
- "Fatal error: unable to initialize core services"

**Handling Strategy:**
- Log at `CRITICAL` level with full stack trace
- Attempt graceful shutdown
- Preserve user data if possible
- Display generic error message (do not expose internal details)

---

## Error Handling Rules (AGENTS.md §13)

1. **Every function that can fail must have explicit error handling** — no silent failures
2. **No bare `catch` or `except` blocks** — always specify error type
3. **Errors must be logged** with: timestamp, error type, message, context, stack trace
4. **End-user error messages must be human-readable** — never expose stack traces
5. **Transient errors must retry** with exponential backoff and max retry count
6. **All errors logged to `progress.md`** during development
7. **Errors must be caught at the appropriate layer** and transformed before crossing boundaries

---

## Swift Error Implementation

```swift
enum IqamahError: Error {
    // ValidationError
    case invalidCoordinates(latitude: Double, longitude: Double)
    case invalidDate(String)
    case invalidCalculationMethod(String)
    
    // IntegrationError
    case locationServicesDenied
    case locationServicesFailed(underlyingError: Error)
    case settingsPersistenceFailed(underlyingError: Error)
    
    // BusinessLogicError
    case invalidPrayerTime(prayer: String, reason: String)
    case invalidQiblahAngle(angle: Double)
    case adjustmentOutOfRange(minutes: Int, allowedRange: ClosedRange<Int>)
    
    // SystemError
    case unexpectedError(message: String)
    case serviceInitializationFailed(service: String)
}

extension IqamahError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidCoordinates(let lat, let lon):
            return "Invalid coordinates: latitude \(lat), longitude \(lon). Please check your location."
        case .locationServicesDenied:
            return "Location access denied. Please enable in System Settings."
        // ... etc
        }
    }
}
```

---

## Error Logging Format

```swift
func logError(_ error: Error, context: String, storyID: String? = nil) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let errorType = type(of: error)
    let message = error.localizedDescription
    
    print("""
    [\(timestamp)] ERROR
    Type: \(errorType)
    Context: \(context)
    Story: \(storyID ?? "N/A")
    Message: \(message)
    ---
    """)
    
    // In production: route to logging service
}
```

---

## Retry Logic for Transient Errors

```swift
func retryWithBackoff<T>(
    maxRetries: Int = 3,
    initialDelay: TimeInterval = 1.0,
    operation: () async throws -> T
) async throws -> T {
    var currentDelay = initialDelay
    var lastError: Error?
    
    for attempt in 1...maxRetries {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < maxRetries {
                try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                currentDelay *= 2 // Exponential backoff
            }
        }
    }
    
    throw lastError!
}
```

---

**Last Updated:** 2026-03-12 (Initial Error Taxonomy)
