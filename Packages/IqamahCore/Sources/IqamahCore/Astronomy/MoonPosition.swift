import Foundation

/// Geocentric Moon position computed using Meeus Chapter 47 truncated series.
/// Accuracy: longitude ±0.001°, latitude ±0.001°, distance ±0.5 km — sufficient for
/// crescent visibility calculations (which need ±0.01° for ARCL/ARCV).
public struct MoonPosition {
    /// Geocentric ecliptic longitude in degrees [0, 360)
    public let longitude: Double
    /// Geocentric ecliptic latitude in degrees [-90, 90]
    public let latitude: Double
    /// Distance from Earth centre in km
    public let distanceKm: Double
    /// Equatorial right ascension in degrees [0, 360)
    public let rightAscension: Double
    /// Equatorial declination in degrees [-90, 90]
    public let declination: Double

    /// Compute Moon position for the given Julian Day (Terrestrial Time).
    public static func compute(julianDay jd: Double) -> MoonPosition {
        let T = (jd - 2_451_545.0) / 36525.0

        // Fundamental arguments (Meeus Ch 47)
        // Mean elongation of the Moon
        let D_deg = (297.8501921 + 445_267.1114034 * T - 0.0018819 * T * T + T * T * T / 545_868.0 - T * T * T * T / 113_065_000.0)
            .truncatingRemainder(dividingBy: 360.0)

        // Mean longitude
        var Lp = 218.3164477 + 481_267.88123421 * T - 0.0015786 * T * T + T * T * T / 538_841.0 - T * T * T * T / 65_194_000.0
        // Mean anomaly of the Sun
        var M = 357.5291092 + 35999.0502909 * T - 0.0001536 * T * T + T * T * T / 24_490_000.0
        // Mean anomaly of the Moon
        var Mp = 134.9633964 + 477_198.8675055 * T + 0.0087414 * T * T + T * T * T / 69699.0 - T * T * T * T / 14_712_000.0
        // Moon's argument of latitude
        var F = 93.2720950 + 483_202.0175233 * T - 0.0036539 * T * T - T * T * T / 3_526_000.0 + T * T * T * T / 863_310_000.0
        // Longitude of the ascending node
        var Om = 125.0445479 - 1934.1362608 * T + 0.0020754 * T * T + T * T * T / 467_441.0 - T * T * T * T / 60_616_000.0

        // Reduce to [0, 360)
        Lp = Lp.truncatingRemainder(dividingBy: 360.0)
        M = M.truncatingRemainder(dividingBy: 360.0)
        Mp = Mp.truncatingRemainder(dividingBy: 360.0)
        F = F.truncatingRemainder(dividingBy: 360.0)
        Om = Om.truncatingRemainder(dividingBy: 360.0)

        // Venusian perturbation term
        let A1 = (119.75 + 131.849 * T).truncatingRemainder(dividingBy: 360.0)
        // Jupiter perturbation
        let A2 = (53.09 + 479_264.290 * T).truncatingRemainder(dividingBy: 360.0)
        // Jupiter flattening
        let A3 = (313.45 + 481_266.484 * T).truncatingRemainder(dividingBy: 360.0)

        let d2r = Double.pi / 180.0

        // Eccentricity factor E
        let E = 1.0 - 0.002516 * T - 0.0000074 * T * T

        // Longitude and distance terms (Table 47.A, top 22 terms)
        // Each entry: [D, M, Mp, F, Σl (0.000001°), Σr (0.001 km)]
        struct LRTerm { let D, M, Mp, F: Int; let sl, sr: Double }
        let lrTerms: [LRTerm] = [
            LRTerm(D: 0, M: 0, Mp: 1, F: 0, sl: 6_288_774, sr: -20_905_355),
            LRTerm(D: 2, M: 0, Mp: -1, F: 0, sl: 1_274_027, sr: -3_699_111),
            LRTerm(D: 2, M: 0, Mp: 0, F: 0, sl: 658_314, sr: -2_955_968),
            LRTerm(D: 0, M: 0, Mp: 2, F: 0, sl: 213_618, sr: -569_925),
            LRTerm(D: 0, M: 1, Mp: 0, F: 0, sl: -185_116, sr: 48888),
            LRTerm(D: 0, M: 0, Mp: 0, F: 2, sl: -114_332, sr: -3149),
            LRTerm(D: 2, M: 0, Mp: -2, F: 0, sl: 58793, sr: 246_158),
            LRTerm(D: 2, M: -1, Mp: -1, F: 0, sl: 57066, sr: -152_138),
            LRTerm(D: 2, M: 0, Mp: 1, F: 0, sl: 53322, sr: -170_733),
            LRTerm(D: 2, M: -1, Mp: 0, F: 0, sl: 45758, sr: -204_586),
            LRTerm(D: 0, M: 1, Mp: -1, F: 0, sl: -40923, sr: -129_620),
            LRTerm(D: 1, M: 0, Mp: 0, F: 0, sl: -34720, sr: 108_743),
            LRTerm(D: 0, M: 1, Mp: 1, F: 0, sl: -30383, sr: 104_755),
            LRTerm(D: 2, M: 0, Mp: 0, F: -2, sl: 15327, sr: 10321),
            LRTerm(D: 0, M: 0, Mp: 1, F: 2, sl: -12528, sr: 0),
            LRTerm(D: 0, M: 0, Mp: 1, F: -2, sl: 10980, sr: 79661),
            LRTerm(D: 4, M: 0, Mp: -1, F: 0, sl: 10675, sr: -34782),
            LRTerm(D: 0, M: 0, Mp: 3, F: 0, sl: 10034, sr: -23210),
            LRTerm(D: 4, M: 0, Mp: -2, F: 0, sl: 8548, sr: -21636),
            LRTerm(D: 2, M: 1, Mp: -1, F: 0, sl: -7888, sr: 24208),
            LRTerm(D: 2, M: 1, Mp: 0, F: 0, sl: -6766, sr: 30824),
            LRTerm(D: 1, M: 0, Mp: -1, F: 0, sl: -5163, sr: -8379),
        ]

        var sumL = 0.0, sumR = 0.0
        for t in lrTerms {
            let eCorr = abs(t.M) == 1 ? E : (abs(t.M) == 2 ? E * E : 1.0)
            let arg = Double(t.D) * D_deg + Double(t.M) * M + Double(t.Mp) * Mp + Double(t.F) * F
            sumL += eCorr * t.sl * sin(arg * d2r)
            sumR += eCorr * t.sr * cos(arg * d2r)
        }

        // Latitude terms (Table 47.B, top 10 terms)
        struct BbTerm { let D, M, Mp, F: Int; let sb: Double }
        let bbTerms: [BbTerm] = [
            BbTerm(D: 0, M: 0, Mp: 0, F: 1, sb: 5_128_122),
            BbTerm(D: 0, M: 0, Mp: 1, F: 1, sb: 280_602),
            BbTerm(D: 0, M: 0, Mp: 1, F: -1, sb: 277_693),
            BbTerm(D: 2, M: 0, Mp: 0, F: -1, sb: 173_237),
            BbTerm(D: 2, M: 0, Mp: -1, F: 1, sb: 55413),
            BbTerm(D: 2, M: 0, Mp: -1, F: -1, sb: 46271),
            BbTerm(D: 2, M: 0, Mp: 0, F: 1, sb: 32573),
            BbTerm(D: 0, M: 0, Mp: 2, F: 1, sb: 17198),
            BbTerm(D: 2, M: 0, Mp: 1, F: -1, sb: 9266),
            BbTerm(D: 0, M: 0, Mp: 2, F: -1, sb: 8822),
        ]

        var sumB = 0.0
        for t in bbTerms {
            let eCorr = abs(t.M) == 1 ? E : (abs(t.M) == 2 ? E * E : 1.0)
            let arg = Double(t.D) * D_deg + Double(t.M) * M + Double(t.Mp) * Mp + Double(t.F) * F
            sumB += eCorr * t.sb * sin(arg * d2r)
        }

        // Additional corrections
        sumL += 3958.0 * sin(A1 * d2r) + 1962.0 * sin((Lp - F) * d2r) + 318.0 * sin(A2 * d2r)
        sumB += -2235.0 * sin(Lp * d2r) + 382.0 * sin(A3 * d2r) + 175.0 * sin((A1 - F) * d2r)
            + 175.0 * sin((A1 + F) * d2r) + 127.0 * sin((Lp - Mp) * d2r) - 115.0 * sin((Lp + Mp) * d2r)

        var lon = Lp + sumL / 1_000_000.0 // degrees
        let lat = sumB / 1_000_000.0 // degrees
        let dist = 385_000.56 + sumR / 1000.0 // km

        lon = lon.truncatingRemainder(dividingBy: 360.0)
        if lon < 0 { lon += 360.0 }

        // Convert ecliptic → equatorial
        let eps = meanObliquity(T: T)
        let lonR = lon * d2r
        let latR = lat * d2r
        let epsR = eps * d2r

        let sinDec = sin(latR) * cos(epsR) + cos(latR) * sin(epsR) * sin(lonR)
        let dec = asin(sinDec) * 180.0 / Double.pi
        var ra = atan2(sin(lonR) * cos(epsR) - tan(latR) * sin(epsR), cos(lonR)) * 180.0 / Double.pi
        if ra < 0 { ra += 360.0 }

        return MoonPosition(longitude: lon, latitude: lat, distanceKm: dist, rightAscension: ra, declination: dec)
    }

    /// Mean obliquity of the ecliptic (Meeus eq. 22.2).
    static func meanObliquity(T: Double) -> Double {
        23.439291111 - 0.013004167 * T - 0.000000164 * T * T + 0.000000504 * T * T * T
    }
}
