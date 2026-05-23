import Testing
import Foundation
@testable import IqamahCore

@Suite("FastingModeSettings Codec")
struct FastingModeSettingsCodecTests {
    @Test("default settings round-trip preserves all fields")
    func defaultRoundTrip() throws {
        let original = FastingModeSettings()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FastingModeSettings.self, from: data)
        #expect(decoded == original)
    }

    @Test("populated settings round-trip preserves all fields")
    func populatedRoundTrip() throws {
        var original = FastingModeSettings()
        original.enabled = true
        original.weeklyDays = [2, 5]    // Mon, Thu
        original.midShaban = true
        original.suhoorLeadMinutes = 60
        original.iftarLeadMinutes = 20
        original.dayBeforeHour = 21
        original.dayBeforeMinute = 30
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FastingModeSettings.self, from: data)
        #expect(decoded == original)
    }

    @Test("legacy JSON missing new fields decodes with defaults")
    func forwardCompatDecode() throws {
        // Simulates a v1.6 install whose persisted JSON only had the original fields,
        // before midShaban/mabath/dayBeforeMinute were added. Decoding must fall back
        // to struct defaults for the absent fields.
        let legacyJSON = """
        {
            "enabled": true,
            "autoRamadan": true,
            "weeklyDays": [2, 5],
            "ayyamAlBeed": false,
            "sixDaysShawwal": false,
            "dayOfArafah": false,
            "firstNineDhulHijjah": false,
            "muharramFast": false,
            "suhoorLeadMinutes": 30,
            "iftarLeadMinutes": 15,
            "dayBeforeEnabled": true,
            "dayBeforeHour": 20,
            "notificationsEnabled": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(FastingModeSettings.self, from: legacyJSON)
        #expect(decoded.enabled == true)
        #expect(decoded.weeklyDays == [2, 5])
        #expect(decoded.midShaban == false)       // defaulted (absent in JSON)
        #expect(decoded.mabath == false)          // defaulted (absent in JSON)
        #expect(decoded.dayBeforeMinute == 0)     // defaulted (absent in JSON)
    }

    @Test("Friday-alone warning triggers when only Fri")
    func fridayAloneAlone() {
        var s = FastingModeSettings()
        s.weeklyDays = [6]
        #expect(s.hasFridayAloneWarning == true)
    }

    @Test("Friday-alone warning clears when paired with Thursday")
    func fridayWithThursdayClears() {
        var s = FastingModeSettings()
        s.weeklyDays = [5, 6]
        #expect(s.hasFridayAloneWarning == false)
    }

    @Test("Friday-alone warning clears when paired with Saturday")
    func fridayWithSaturdayClears() {
        var s = FastingModeSettings()
        s.weeklyDays = [6, 7]
        #expect(s.hasFridayAloneWarning == false)
    }

    @Test("Saturday-alone warning triggers when only Sat")
    func saturdayAlone() {
        var s = FastingModeSettings()
        s.weeklyDays = [7]
        #expect(s.hasSaturdayAloneWarning == true)
    }

    @Test("Saturday-alone warning clears when paired with Friday")
    func saturdayWithFridayClears() {
        var s = FastingModeSettings()
        s.weeklyDays = [6, 7]
        #expect(s.hasSaturdayAloneWarning == false)
    }
}
