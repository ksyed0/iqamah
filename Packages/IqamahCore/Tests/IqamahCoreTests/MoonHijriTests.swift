import Foundation
import IqamahCore
import Testing

@Suite("Moon + Hijri helpers")
struct MoonHijriTests {
    @Test("moonPhase returns value in [0, 1]")
    func moonPhaseRange() {
        let phase = moonPhase(for: Date())
        #expect(phase >= 0.0 && phase <= 1.0)
    }

    @Test("moonPhase near known full moon is approximately 0.5")
    func moonPhaseFull() throws {
        // 2024-Feb-24 was a full moon
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let fullMoonDate = try #require(formatter.date(from: "2024-02-24"))
        let phase = moonPhase(for: fullMoonDate)
        // Allow ±0.06 (±1.8 days) for approximation
        #expect(abs(phase - 0.5) < 0.06, "Expected ~0.5 but got \(phase)")
    }

    @Test("hijriDateString returns non-empty string")
    func hijriNonEmpty() {
        let s = hijriDateString(for: Date(), offset: 0)
        #expect(!s.isEmpty)
    }

    @Test("hijriDateString contains year 1447 for 2026-05-11")
    func hijriFormat() throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let date = try #require(formatter.date(from: "2026-05-11"))
        let s = hijriDateString(for: date, offset: 0)
        #expect(s.contains("1447"), "Expected year 1447 in \(s)")
        #expect(s.first?.isNumber == true, "Should start with day number")
    }

    @Test("hijriDateString offset shifts displayed day")
    func hijriOffset() {
        let date = Date()
        let base = hijriDateString(for: date, offset: 0)
        let plus1 = hijriDateString(for: date, offset: 1)
        #expect(base != plus1, "Offset should change the displayed date")
    }
}
