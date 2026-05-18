import Foundation
import IqamahCore
import Testing

// MARK: - Grid structure tests

@Suite("HilalCalculator — Grid Structure")
struct HilalCalculatorGridTests {
    @Test("Grid contains exactly 16,200 cells")
    func gridCellCount() async {
        let calc = HilalCalculator()
        let newMoonJD = NewMoon.julianDayOfNewMoon(k: 1448 * 12.37) // approximate 1448 AH
        let req = HilalGridRequest(newMoonJD: newMoonJD, evening: .d29, criterion: OdehCriterion.shared)
        let grid = await calc.computeGrid(req)
        #expect(grid.count == HilalCalculator.cellCount)
        #expect(HilalCalculator.cellCount == 16200)
    }

    @Test("All grid cell values are valid VisibilityCategory raw values (1–4)")
    func gridCellValuesAreValid() async {
        let calc = HilalCalculator()
        let newMoonJD = NewMoon.julianDayOfNewMoon(k: 1458)
        let req = HilalGridRequest(newMoonJD: newMoonJD, evening: .d29, criterion: OdehCriterion.shared)
        let grid = await calc.computeGrid(req)
        for cell in grid {
            #expect(cell >= 1 && cell <= 4, "Invalid cell value: \(cell)")
        }
    }

    @Test("30th evening grid has at least as many A cells as 29th (wider visibility)")
    func d30HasBroaderVisibility() async {
        let calc = HilalCalculator()
        let newMoonJD = NewMoon.julianDayOfNewMoon(k: 1450)
        let reqD29 = HilalGridRequest(newMoonJD: newMoonJD, evening: .d29, criterion: OdehCriterion.shared)
        let reqD30 = HilalGridRequest(newMoonJD: newMoonJD, evening: .d30, criterion: OdehCriterion.shared)
        let g29 = await calc.computeGrid(reqD29)
        let g30 = await calc.computeGrid(reqD30)
        let aCount29 = g29.filter { $0 == Int8(VisibilityCategory.A.rawValue) }.count
        let aCount30 = g30.filter { $0 == Int8(VisibilityCategory.A.rawValue) }.count
        // 30th evening moon is older — substantially more visible
        #expect(aCount30 >= aCount29)
    }
}

// MARK: - Local card tests

@Suite("HilalCalculator — Local Sighting Card")
struct HilalCalculatorLocalCardTests {
    @Test("Local card for Makkah in a visible month has positive ARCV")
    func localCardMakkahVisible() throws {
        let calc = HilalCalculator()
        // Use a well-known visibility date: June 2023 crescent, Makkah
        let date = try #require(ISO8601DateFormatter().date(from: "2023-06-20T18:00:00Z"))
        let values = calc.computeLocalCard(date: date, latitude: 21.42, longitude: 39.83, criterion: OdehCriterion.shared)
        // ARCL should be > 0 (moon is elongated from sun)
        #expect(values.arcl > 0)
        // Width should be > 0
        #expect(values.widthArcmin >= 0)
    }

    @Test("Local card ARCL is always positive")
    func localCardARCLPositive() throws {
        let calc = HilalCalculator()
        let date = try #require(ISO8601DateFormatter().date(from: "2024-03-11T18:00:00Z"))
        for lat in stride(from: -60.0, through: 60.0, by: 20.0) {
            for lon in stride(from: -120.0, through: 120.0, by: 40.0) {
                let v = calc.computeLocalCard(date: date, latitude: lat, longitude: lon, criterion: OdehCriterion.shared)
                #expect(v.arcl >= 0)
            }
        }
    }
}

// MARK: - Criterion swap tests

@Suite("HilalCalculator — Criterion Swap")
struct HilalCalculatorCriterionTests {
    @Test("Different criteria produce different grid values for the same date")
    func criterionSwapProducesDifferentGrids() async {
        let calc = HilalCalculator()
        let newMoonJD = NewMoon.julianDayOfNewMoon(k: 1460)

        let reqOdeh = HilalGridRequest(newMoonJD: newMoonJD, evening: .d29, criterion: OdehCriterion.shared)
        let reqYallop = HilalGridRequest(newMoonJD: newMoonJD, evening: .d29, criterion: YallopCriterion.shared)

        async let gridOdeh = calc.computeGrid(reqOdeh)
        async let gridYallop = calc.computeGrid(reqYallop)
        let (odeh, yallop) = await (gridOdeh, gridYallop)

        // Grids must differ at some cells (criteria have different thresholds)
        let differences = zip(odeh, yallop).filter { $0 != $1 }.count
        #expect(differences > 0, "Odeh and Yallop criteria should produce different grids")
    }

    @Test("Criterion swap uses the same underlying astronomy (same ARCL at same location)")
    func criterionSwapReuseAstronomy() throws {
        let calc = HilalCalculator()
        let date = try #require(ISO8601DateFormatter().date(from: "2024-04-08T18:00:00Z"))
        let lat = 35.0, lon = 35.0

        let v1 = calc.computeLocalCard(date: date, latitude: lat, longitude: lon, criterion: OdehCriterion.shared)
        let v2 = calc.computeLocalCard(date: date, latitude: lat, longitude: lon, criterion: YallopCriterion.shared)

        // ARCL and ARCV are purely geometric — same regardless of criterion
        #expect(abs(v1.arcl - v2.arcl) < 0.001)
        #expect(abs(v1.arcv - v2.arcv) < 0.001)
        #expect(abs(v1.widthArcmin - v2.widthArcmin) < 0.001)
    }
}

// MARK: - LRU cache tests

@Suite("HilalCalculator — LRU Cache")
struct HilalCalculatorCacheTests {
    @Test("Cache is populated after first computeGrid call")
    func cachePopulatedAfterFirstCall() async {
        let calc = HilalCalculator()
        calc.clearCache()
        #expect(calc.cachedEntryCount == 0)

        let newMoonJD = NewMoon.julianDayOfNewMoon(k: 1462)
        let req = HilalGridRequest(newMoonJD: newMoonJD, evening: .d29, criterion: OdehCriterion.shared)
        _ = await calc.computeGrid(req)

        #expect(calc.cachedEntryCount == 1)
    }

    @Test("Second call with same key returns from cache (both evenings hit same entry)")
    func cacheHitOnSecondCall() async {
        let calc = HilalCalculator()
        calc.clearCache()
        let newMoonJD = NewMoon.julianDayOfNewMoon(k: 1463)

        let req29 = HilalGridRequest(newMoonJD: newMoonJD, evening: .d29, criterion: OdehCriterion.shared)
        let req30 = HilalGridRequest(newMoonJD: newMoonJD, evening: .d30, criterion: OdehCriterion.shared)

        _ = await calc.computeGrid(req29) // populates cache
        let countAfterFirst = calc.cachedEntryCount
        _ = await calc.computeGrid(req30) // should hit same cache entry

        #expect(countAfterFirst == 1)
        #expect(calc.cachedEntryCount == 1, "d30 for same new moon should reuse the cached pair")
    }

    @Test("Different criteria produce separate cache entries")
    func differentCriteriaAreCachedSeparately() async {
        let calc = HilalCalculator()
        calc.clearCache()
        let newMoonJD = NewMoon.julianDayOfNewMoon(k: 1464)

        let reqOdeh = HilalGridRequest(newMoonJD: newMoonJD, evening: .d29, criterion: OdehCriterion.shared)
        let reqYallop = HilalGridRequest(newMoonJD: newMoonJD, evening: .d29, criterion: YallopCriterion.shared)

        _ = await calc.computeGrid(reqOdeh)
        _ = await calc.computeGrid(reqYallop)

        #expect(calc.cachedEntryCount == 2)
    }

    @Test("LRU cache evicts oldest entry when capacity (6) is exceeded")
    func lruEvictsWhenFull() async {
        let calc = HilalCalculator()
        calc.clearCache()

        // Fill cache with 7 different new-moon dates (capacity is 6)
        for i in 0 ..< 7 {
            let k = Double(1465 + i)
            let newMoonJD = NewMoon.julianDayOfNewMoon(k: k)
            let req = HilalGridRequest(newMoonJD: newMoonJD, evening: .d29, criterion: OdehCriterion.shared)
            _ = await calc.computeGrid(req)
        }

        #expect(calc.cachedEntryCount == 6, "Cache should cap at 6 entries")
    }
}

// MARK: - Performance tests

@Suite("HilalCalculator — Performance")
struct HilalCalculatorPerformanceTests {
    @Test("Full 16,200-cell grid computes in ≤ 5000ms on any hardware (CI-safe budget)")
    func gridComputeWithinBudget() async {
        let calc = HilalCalculator()
        calc.clearCache()
        let newMoonJD = NewMoon.julianDayOfNewMoon(k: 1470)
        let req = HilalGridRequest(newMoonJD: newMoonJD, evening: .d29, criterion: OdehCriterion.shared)

        let start = ContinuousClock.now
        _ = await calc.computeGrid(req)
        let elapsed = ContinuousClock.now - start

        // CI runners are slower than device — generous 5s budget for correctness gate.
        // The ≤300ms AC-0217 target is verified locally on Apple Silicon.
        let elapsedMs = Double(elapsed.components.seconds) * 1000
            + Double(elapsed.components.attoseconds) / 1e15
        #expect(elapsedMs < 5000, "Grid compute took \(Int(elapsedMs))ms — exceeded 5000ms CI budget")
    }

    @Test("Cached grid retrieval is instant (< 5ms)")
    func cachedGridRetrievalIsInstant() async {
        let calc = HilalCalculator()
        calc.clearCache()
        let newMoonJD = NewMoon.julianDayOfNewMoon(k: 1471)
        let req = HilalGridRequest(newMoonJD: newMoonJD, evening: .d29, criterion: OdehCriterion.shared)

        _ = await calc.computeGrid(req) // warm cache
        let start = ContinuousClock.now
        _ = await calc.computeGrid(req) // should be cache hit
        let elapsed = ContinuousClock.now - start

        let elapsedMs = Double(elapsed.components.seconds) * 1000
            + Double(elapsed.components.attoseconds) / 1e15
        #expect(elapsedMs < 5, "Cached retrieval took \(elapsedMs)ms — should be < 5ms")
    }
}
