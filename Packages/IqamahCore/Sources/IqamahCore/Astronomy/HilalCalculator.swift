import Foundation

/// Computes the global crescent-visibility grid and local sighting values for Hilal Watch.
///
/// Grid layout: 2° × 2° cells covering the globe.
/// - Latitude bands: 90 bands from −88° to +88° (centre at −87, −85, …, +87).
/// - Longitude bands: 180 bands from −178° to +178° (centre at −179, −177, …, +179).
/// - Total cells: 90 × 180 = 16,200, stored row-major (lat outer, lon inner).
/// - Cell value: Int8 raw value of VisibilityCategory (A=4, B=3, C=2, D=1).
///
/// Grid computation uses `withTaskGroup` parallel execution over latitude bands.
/// Results are cached in a max-6 LRU cache keyed on (newMoonJD, criterionName).
public final class HilalCalculator: Sendable {
    public static let shared = HilalCalculator()

    /// Grid dimensions
    public static let latitudeBands = 90 // −88…+88 in 2° steps
    public static let longitudeBands = 180 // −178…+178 in 2° steps
    public static let cellCount = latitudeBands * longitudeBands // 16,200

    private let cache = HilalLRUCache(capacity: 6)

    public init() {}

    // MARK: - Public API

    /// Computes (or retrieves from cache) the 16,200-cell visibility grid.
    /// Returns a flat `ContiguousArray<Int8>` in row-major order (lat × lon).
    public func computeGrid(_ req: HilalGridRequest) async -> ContiguousArray<Int8> {
        let cacheKey = HilalCacheKey(newMoonJD: req.newMoonJD, criterion: req.criterion)

        // Cache hit — return immediately
        if let pair = cache.get(key: cacheKey) {
            return req.evening == .d29 ? pair.d29 : pair.d30
        }

        // Compute both evenings together (caller will likely switch tabs)
        async let d29 = computeGridRaw(newMoonJD: req.newMoonJD, eveningOffset: 1, criterion: req.criterion)
        async let d30 = computeGridRaw(newMoonJD: req.newMoonJD, eveningOffset: 2, criterion: req.criterion)

        let (g29, g30) = await (d29, d30)
        let pair = CachedGridPair(d29: g29, d30: g30)
        cache.set(key: cacheKey, value: pair)

        return req.evening == .d29 ? g29 : g30
    }

    /// Computes the precise local sighting values for one observer location.
    public func computeLocalCard(
        date: Date,
        latitude: Double,
        longitude: Double,
        criterion: any VisibilityCriterion
    ) -> LocalSightingValues {
        computeCell(date: date, latitude: latitude, longitude: longitude, criterion: criterion)
    }

    // MARK: - Internal grid computation

    private func computeGridRaw(
        newMoonJD: Double,
        eveningOffset: Int, // 1 = d29, 2 = d30
        criterion: any VisibilityCriterion
    ) async -> ContiguousArray<Int8> {
        // Watch evening = day of new moon + offset (sunset time)
        let watchJD = newMoonJD + Double(eveningOffset)
        let watchDate = Date.fromJulianDay(watchJD)

        var result = ContiguousArray<Int8>(repeating: 1, count: Self.cellCount)

        // Parallel compute over latitude bands
        let processorCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
        let bandsPerWorker = Int(ceil(Double(Self.latitudeBands) / Double(processorCount)))

        await withTaskGroup(of: [(index: Int, value: Int8)].self) { group in
            for workerIdx in 0 ..< processorCount {
                let startBand = workerIdx * bandsPerWorker
                let endBand = min(startBand + bandsPerWorker, Self.latitudeBands)
                guard startBand < endBand else { continue }

                let criterion = criterion // capture for Sendable
                group.addTask {
                    var cells = [(index: Int, value: Int8)]()
                    cells.reserveCapacity((endBand - startBand) * Self.longitudeBands)

                    for latBand in startBand ..< endBand {
                        let lat = Double(latBand) * 2.0 - 88.0 // −88…+88 step 2
                        for lonBand in 0 ..< Self.longitudeBands {
                            let lon = Double(lonBand) * 2.0 - 178.0 // −178…+178 step 2
                            let values = self.computeCell(
                                date: watchDate,
                                latitude: lat,
                                longitude: lon,
                                criterion: criterion
                            )
                            let idx = latBand * Self.longitudeBands + lonBand
                            cells.append((index: idx, value: Int8(values.category.rawValue)))
                        }
                    }
                    return cells
                }
            }

            for await cells in group {
                for cell in cells {
                    result[cell.index] = cell.value
                }
            }
        }

        return result
    }

    // MARK: - Single-cell computation

    /// Computes crescent visibility for one (lat, lon) observer on the given date.
    func computeCell(
        date: Date,
        latitude: Double,
        longitude: Double,
        criterion: any VisibilityCriterion
    ) -> LocalSightingValues {
        let jd = date.julianDay

        // Sunset JD for this observer
        let sunsetJD = SunPosition.sunsetJD(julianDay: jd, latitude: latitude, longitude: longitude)

        // Moon and Sun positions at sunset
        let moon = MoonPosition.compute(julianDay: sunsetJD)
        let sun = SunPosition.compute(julianDay: sunsetJD)

        // Local sidereal time at sunset
        let T = (sunsetJD - 2_451_545.0) / 36525.0
        var lst = 280.46061837 + 360.98564736629 * (sunsetJD - 2_451_545.0)
            + 0.000387933 * T * T - T * T * T / 38_710_000.0
            + longitude
        lst = lst.truncatingRemainder(dividingBy: 360.0)
        if lst < 0 { lst += 360.0 }

        // Moon altitude at sunset
        let moonHorizon = HorizonCoordinates.from(
            rightAscension: moon.rightAscension,
            declination: moon.declination,
            latitude: latitude,
            localSiderealTime: lst
        )
        let arcv = moonHorizon.altitude

        // ARCL = angular separation Moon–Sun
        let arcl = angularSeparation(
            ra1: moon.rightAscension, dec1: moon.declination,
            ra2: sun.rightAscension, dec2: sun.declination
        )

        // Crescent width
        let w = crescentWidthArcmin(arclDegrees: arcl, moonDistanceKm: moon.distanceKm)

        let geometry = CrescentGeometry(
            arcl: arcl,
            arcv: arcv,
            widthArcmin: w,
            moonDistanceKm: moon.distanceKm
        )
        let category = criterion.evaluate(geometry)

        // criterionValue: V for Odeh, q×10 for Yallop/HMNAO
        let criterionValue: Double
        if criterion.name == OdehCriterion.shared.name {
            let poly = -0.1018 * w * w * w + 0.7319 * w * w - 6.3226 * w + 7.1651
            criterionValue = arcv - poly
        } else {
            let poly = 11.8371 - 6.3226 * arcl + 0.7319 * arcl * arcl - 0.1018 * arcl * arcl * arcl
            criterionValue = (arcv - poly) / 10.0
        }

        return LocalSightingValues(
            arcl: arcl,
            arcv: arcv,
            widthArcmin: w,
            criterionValue: criterionValue,
            category: category
        )
    }

    // MARK: - Cache inspection (for tests)

    /// Number of cached grid pairs.
    public var cachedEntryCount: Int { cache.count }

    /// Clear the cache (for testing).
    public func clearCache() {
        cache.clear()
    }
}
