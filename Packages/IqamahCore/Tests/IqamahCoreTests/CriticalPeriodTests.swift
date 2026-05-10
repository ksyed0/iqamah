import Foundation
import IqamahCore
import Testing

@Suite("Criterion Consistency Tests")
struct CriticalPeriodTests {

    // Test that HMNAO >= Yallop >= Odeh in terms of conservatism
    // (HMNAO should be the most conservative — fewest A classifications)
    @Test("Criterion ordering: HMNAO is at least as conservative as Yallop")
    func hmnaoAtLeastAsConservativeAsYallop() {
        let testCases: [(arcl: Double, arcv: Double, w: Double)] = [
            (8.0, 4.0, 0.12),
            (10.0, 6.0, 0.25),
            (6.0, 2.0, 0.06),
            (12.0, 8.0, 0.40),
            (5.0, 1.0, 0.03),
        ]
        let yallop = YallopCriterion.shared
        let hmnao = HMNAOCriterion.shared

        for tc in testCases {
            let geo = CrescentGeometry(arcl: tc.arcl, arcv: tc.arcv, widthArcmin: tc.w, moonDistanceKm: 385000)
            let yResult = yallop.evaluate(geo)
            let hResult = hmnao.evaluate(geo)
            // HMNAO should be <= Yallop in category (same or more conservative)
            #expect(hResult <= yResult, "HMNAO (\(hResult)) more optimistic than Yallop (\(yResult)) for ARCL=\(tc.arcl), ARCV=\(tc.arcv)")
        }
    }

    @Test("Easily-visible geometry (ARCL=12, ARCV=8, W=2.0) is A for all criteria")
    func highlyVisibleIsAForAll() {
        // W=2.0 arcmin: Odeh poly = -3.37, V = 8.0-(-3.37) = 11.37 → A
        // Yallop/HMNAO: poly(ARCL=12) = -134.55, q = 14.3 → A
        let geo = CrescentGeometry(arcl: 12.0, arcv: 8.0, widthArcmin: 2.0, moonDistanceKm: 385000)
        #expect(OdehCriterion.shared.evaluate(geo) == .A)
        #expect(YallopCriterion.shared.evaluate(geo) == .A)
        #expect(HMNAOCriterion.shared.evaluate(geo) == .A)
    }

    @Test("Below-horizon geometry (ARCL=1, ARCV=-2) is D for all criteria")
    func belowHorizonIsDForAll() {
        // ARCL=1: Yallop poly=6.14, q=(-2-6.14)/10=-0.814 → D; Odeh V=(-2-7.10)=-9.1 → D
        let geo = CrescentGeometry(arcl: 1.0, arcv: -2.0, widthArcmin: 0.01, moonDistanceKm: 385000)
        #expect(OdehCriterion.shared.evaluate(geo) == .D)
        #expect(YallopCriterion.shared.evaluate(geo) == .D)
        #expect(HMNAOCriterion.shared.evaluate(geo) == .D)
    }

    @Test("Odeh V-value formula matches hand-computed example")
    func odehVValueFormula() {
        // W = 0.25 arcmin: poly = -0.1018*(0.25^3) + 0.7319*(0.25^2) - 6.3226*0.25 + 7.1651
        //                       = -0.001588 + 0.045744 - 1.58065 + 7.1651 ≈ 5.629
        // V = ARCV - poly = 6.0 - 5.629 = 0.371 → 0.371 is in [-0.96, 2.00) → category C
        let geo = CrescentGeometry(arcl: 9.0, arcv: 6.0, widthArcmin: 0.25, moonDistanceKm: 385000)
        let result = OdehCriterion.shared.evaluate(geo)
        #expect(result == .C)
    }

    @Test("Yallop q-value formula matches hand-computed example")
    func yallopQValueFormula() {
        // ARCL = 3.0:
        // poly = 11.8371 - 6.3226*3 + 0.7319*9 - 0.1018*27
        //      = 11.8371 - 18.9678 + 6.5871 - 2.7486 = -3.2922
        // q = (ARCV - poly) / 10 = (1.5 - (-3.2922)) / 10 = 0.4792 → A
        let geo = CrescentGeometry(arcl: 3.0, arcv: 1.5, widthArcmin: 0.01, moonDistanceKm: 385000)
        let result = YallopCriterion.shared.evaluate(geo)
        #expect(result == .A)
    }
}
