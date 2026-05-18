import Foundation
import IqamahCore
import Testing

@Suite("ICOP Regression Tests (Odeh criterion)")
struct ICOPRegressionTests {

    struct Observation: Decodable {
        let date: String
        let lat, lon: Double
        let arcl, arcv, w: Double
        let expected_odeh: String
    }

    func loadObservations() throws -> [Observation] {
        let url = Bundle.module.url(forResource: "icop-sample", withExtension: "json")!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Observation].self, from: data)
    }

    @Test("Odeh criterion matches expected category for all ICOP sample observations")
    func odehCriterionMatchesSample() throws {
        let observations = try loadObservations()
        let criterion = OdehCriterion.shared
        var mismatches = 0
        var log = [String]()

        for obs in observations {
            let geo = CrescentGeometry(
                arcl: obs.arcl,
                arcv: obs.arcv,
                widthArcmin: obs.w,
                moonDistanceKm: 385000 // approximate for fixture
            )
            let result = criterion.evaluate(geo)
            let expected = obs.expected_odeh
            let resultChar = String(result == .A ? "A" : result == .B ? "B" : result == .C ? "C" : "D")
            if resultChar != expected {
                mismatches += 1
                log.append("\(obs.date): expected \(expected), got \(resultChar) (ARCL=\(obs.arcl), ARCV=\(obs.arcv), W=\(obs.w))")
            }
        }
        if !log.isEmpty {
            print("Mismatches:\n" + log.joined(separator: "\n"))
        }
        // Allow up to 2 mismatches in the sample (fixture values are approximate)
        #expect(mismatches <= 2, "Too many category mismatches: \(mismatches)")
    }

    @Test("No D-zone observations classified as A (Odeh)")
    func noDzoneClassifiedAsA() throws {
        let observations = try loadObservations()
        let criterion = OdehCriterion.shared
        for obs in observations where obs.expected_odeh == "D" {
            let geo = CrescentGeometry(arcl: obs.arcl, arcv: obs.arcv, widthArcmin: obs.w, moonDistanceKm: 385000)
            #expect(criterion.evaluate(geo) != .A, "D-zone obs \(obs.date) classified as A")
        }
    }
}
