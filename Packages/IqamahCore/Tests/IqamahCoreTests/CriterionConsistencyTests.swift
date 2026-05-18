import Foundation
import IqamahCore
import Testing

@Suite("Criterion Boundary Tests")
struct CriterionConsistencyTests {

    @Test("Odeh A/B boundary at V = 5.65")
    func odehABBoundary() {
        // Find W and ARCV that give V > 5.65
        // poly(W=0.1) = -0.1018*0.001 + 0.7319*0.01 - 6.3226*0.1 + 7.1651 ≈ 6.544
        // V = ARCV - 6.544 = 5.65 → ARCV ≈ 12.194; use 12.2 for category A
        let geo = CrescentGeometry(arcl: 9.0, arcv: 12.2, widthArcmin: 0.1, moonDistanceKm: 385000)
        #expect(OdehCriterion.shared.evaluate(geo) == .A)
    }

    @Test("Odeh C/D boundary at V = -0.96")
    func odehCDBoundary() {
        // poly(W=0.5) = -0.1018*0.125 + 0.7319*0.25 - 6.3226*0.5 + 7.1651 ≈ 4.1
        // V = ARCV - 4.1 = -1.0 → ARCV = 3.1 → category D
        let geo = CrescentGeometry(arcl: 9.0, arcv: 3.0, widthArcmin: 0.5, moonDistanceKm: 385000)
        #expect(OdehCriterion.shared.evaluate(geo) == .D)
    }

    @Test("Yallop A boundary at q = 0.216")
    func yallopABoundary() {
        // ARCL = 1.0:
        // poly(1) = 11.8371 - 6.3226 + 0.7319 - 0.1018 = 6.1446
        // For ARCV = 8.4: q = (8.4 - 6.1446)/10 = 0.2255 → A
        let geoA = CrescentGeometry(arcl: 1.0, arcv: 8.4, widthArcmin: 0.01, moonDistanceKm: 385000)
        #expect(YallopCriterion.shared.evaluate(geoA) == .A)
    }

    @Test("All three criteria give D for moon well below horizon (ARCL=1, ARCV=-2)")
    func belowHorizonAllD() {
        // ARCL=1: Yallop poly=6.14, q=-0.814 → D; Odeh poly=7.10, V=-9.1 → D
        let geo = CrescentGeometry(arcl: 1.0, arcv: -2.0, widthArcmin: 0.01, moonDistanceKm: 385000)
        for criterion in [OdehCriterion.shared as any VisibilityCriterion,
                          YallopCriterion.shared,
                          HMNAOCriterion.shared]
        {
            #expect(criterion.evaluate(geo) == .D)
        }
    }
}
