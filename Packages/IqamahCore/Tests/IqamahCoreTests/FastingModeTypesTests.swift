import Testing
import Foundation
@testable import IqamahCore

@Suite("FastingModeSettings + FastingDayState")
struct FastingModeTypesTests {
    @Test("FastingModeSettings has expected defaults")
    func fastingModeSettingsDefaults() {
        let settings = FastingModeSettings()
        #expect(!settings.enabled)
        #expect(settings.autoRamadan)
        #expect(settings.weeklyDays == [])
        #expect(!settings.ayyamAlBeed)
        #expect(!settings.sixDaysShawwal)
        #expect(!settings.dayOfArafah)
        #expect(!settings.firstNineDhulHijjah)
        #expect(!settings.muharramFast)
        #expect(!settings.midShaban)
        #expect(!settings.mabath)
        #expect(settings.suhoorLeadMinutes == 30)
        #expect(settings.iftarLeadMinutes == 15)
        #expect(settings.dayBeforeEnabled)
        #expect(settings.dayBeforeHour == 20)
        #expect(settings.dayBeforeMinute == 0)
        #expect(settings.notificationsEnabled)
    }

    @Test("Friday-alone weekly selection triggers warning")
    func fridayAloneWarning() {
        var settings = FastingModeSettings()
        settings.weeklyDays = [6]
        #expect(settings.hasFridayAloneWarning)

        settings.weeklyDays = [5, 6]
        #expect(!settings.hasFridayAloneWarning)

        settings.weeklyDays = [6, 7]
        #expect(!settings.hasFridayAloneWarning)
    }

    @Test("Saturday-alone weekly selection triggers warning")
    func saturdayAloneWarning() {
        var settings = FastingModeSettings()
        settings.weeklyDays = [7]
        #expect(settings.hasSaturdayAloneWarning)

        settings.weeklyDays = [6, 7]
        #expect(!settings.hasSaturdayAloneWarning)
    }

    @Test("FastingModeSettings round-trips through Codable")
    func codableRoundTrip() throws {
        let original = FastingModeSettings(
            enabled: true,
            autoRamadan: false,
            weeklyDays: [2, 5],
            ayyamAlBeed: true,
            sixDaysShawwal: true,
            dayOfArafah: true,
            firstNineDhulHijjah: true,
            muharramFast: true,
            midShaban: true,
            mabath: true,
            suhoorLeadMinutes: 45,
            iftarLeadMinutes: 20,
            dayBeforeEnabled: false,
            dayBeforeHour: 19,
            dayBeforeMinute: 30,
            notificationsEnabled: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FastingModeSettings.self, from: data)
        #expect(original == decoded)
    }

    @Test("FastingDayState.inactive convenience produces an inactive state")
    func inactiveConvenience() {
        let date = Date()
        let state = FastingDayState.inactive(date: date)
        #expect(!state.isActive)
        #expect(state.trigger == nil)
        #expect(state.prohibition == nil)
        #expect(state.date == date)
    }
}
