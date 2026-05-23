import Testing
import Foundation
@testable import IqamahCore

@Suite("CalculationMethod Ja'fari + isShiaMethod")
struct CalculationMethodJafariTests {
    @Test("jafari case has expected angles")
    func jafariAngles() {
        #expect(CalculationMethod.jafari.fajrAngle == 16.0)
        #expect(CalculationMethod.jafari.ishaAngle == 14.0)
        #expect(CalculationMethod.jafari.maghribAngle == 4.0)
    }

    @Test("jafari case identifies as Shia")
    func jafariIsShia() {
        #expect(CalculationMethod.jafari.isShiaMethod == true)
    }

    @Test("tehran case identifies as Shia")
    func tehranIsShia() {
        #expect(CalculationMethod.tehran.isShiaMethod == true)
    }

    @Test("sunni methods are not Shia")
    func sunniMethodsNotShia() {
        for method in [CalculationMethod.muslimWorldLeague, .isna, .egypt, .ummAlQura, .karachi] {
            #expect(method.isShiaMethod == false, "\(method) should not be Shia")
        }
    }

    @Test("jafari has displayName and shortName")
    func jafariNaming() {
        #expect(!CalculationMethod.jafari.displayName.isEmpty)
        #expect(!CalculationMethod.jafari.shortName.isEmpty)
    }
}
