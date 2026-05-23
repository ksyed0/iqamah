import Testing
import Foundation
@testable import IqamahCore

@Suite("FastingLabelFormatter")
struct FastingLabelFormatterTests {
    static let now = Date(timeIntervalSince1970: 1_745_000_000)

    @Test("inactive state returns original prayer name")
    func inactivePassthrough() {
        let state = FastingDayState.inactive(date: Self.now)
        let result = FastingLabelFormatter.relabel(
            prayerName: "Fajr",
            prayerTime: Self.now.addingTimeInterval(60 * 60),
            currentTime: Self.now,
            state: state
        )
        #expect(result == "Fajr")
    }

    @Test("active Ramadan within 2h relabels Fajr to Suhoor with moon glyph")
    func ramadanRelabelFajr() {
        let state = FastingDayState(
            isActive: true, trigger: .autoRamadan, prohibition: nil, date: Self.now
        )
        let result = FastingLabelFormatter.relabel(
            prayerName: "Fajr",
            prayerTime: Self.now.addingTimeInterval(42 * 60),
            currentTime: Self.now,
            state: state
        )
        #expect(result == "🌙 Suhoor")
    }

    @Test("active Ramadan within 2h relabels Maghrib to Iftar")
    func ramadanRelabelMaghrib() {
        let state = FastingDayState(
            isActive: true, trigger: .autoRamadan, prohibition: nil, date: Self.now
        )
        let result = FastingLabelFormatter.relabel(
            prayerName: "Maghrib",
            prayerTime: Self.now.addingTimeInterval(60 * 60),
            currentTime: Self.now,
            state: state
        )
        #expect(result == "🌙 Iftar")
    }

    @Test("active Nawafil uses clock glyph instead of moon")
    func nawafilUsesClockGlyph() {
        let state = FastingDayState(
            isActive: true, trigger: .weeklySchedule, prohibition: nil, date: Self.now
        )
        let result = FastingLabelFormatter.relabel(
            prayerName: "Fajr",
            prayerTime: Self.now.addingTimeInterval(60 * 60),
            currentTime: Self.now,
            state: state
        )
        #expect(result == "🕗 Suhoor")
    }

    @Test("outside 2h window returns original prayer name even when active")
    func outsideWindowPassthrough() {
        let state = FastingDayState(
            isActive: true, trigger: .autoRamadan, prohibition: nil, date: Self.now
        )
        let result = FastingLabelFormatter.relabel(
            prayerName: "Fajr",
            prayerTime: Self.now.addingTimeInterval(3 * 60 * 60),
            currentTime: Self.now,
            state: state
        )
        #expect(result == "Fajr")
    }

    @Test("only Fajr and Maghrib are relabeled — other prayers untouched")
    func otherPrayersUntouched() {
        let state = FastingDayState(
            isActive: true, trigger: .autoRamadan, prohibition: nil, date: Self.now
        )
        for prayer in ["Sunrise", "Dhuhr", "Asr", "Isha"] {
            let result = FastingLabelFormatter.relabel(
                prayerName: prayer,
                prayerTime: Self.now.addingTimeInterval(60 * 60),
                currentTime: Self.now,
                state: state
            )
            #expect(result == prayer, "\(prayer) should not be relabeled")
        }
    }

    @Test("prohibition state does not relabel")
    func prohibitionNoRelabel() {
        let state = FastingDayState(
            isActive: false, trigger: nil, prohibition: .eidAlFitr, date: Self.now
        )
        let result = FastingLabelFormatter.relabel(
            prayerName: "Fajr",
            prayerTime: Self.now.addingTimeInterval(60 * 60),
            currentTime: Self.now,
            state: state
        )
        #expect(result == "Fajr")
    }
}
