import Foundation

/// Geocentric Sun position (Meeus Ch. 25 low-precision, ±0.01°).
public struct SunPosition {
    public let longitude: Double // ecliptic longitude, degrees
    public let rightAscension: Double // degrees
    public let declination: Double // degrees

    public static func compute(julianDay jd: Double) -> SunPosition {
        let T = (jd - 2_451_545.0) / 36525.0
        let d2r = Double.pi / 180.0

        // Geometric mean longitude (deg)
        var L0 = 280.46646 + 36000.76983 * T + 0.0003032 * T * T
        L0 = L0.truncatingRemainder(dividingBy: 360.0)

        // Mean anomaly (deg)
        var M = 357.52911 + 35999.05029 * T - 0.0001537 * T * T
        M = M.truncatingRemainder(dividingBy: 360.0)

        // Equation of centre
        let Mrad = M * d2r
        let C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * sin(Mrad)
            + (0.019993 - 0.000101 * T) * sin(2 * Mrad)
            + 0.000289 * sin(3 * Mrad)

        // Sun's true longitude
        var sunLon = L0 + C

        // Apparent longitude (correct for aberration and nutation)
        let omega = 125.04 - 1934.136 * T
        var lambda = sunLon - 0.00569 - 0.00478 * sin(omega * d2r)
        lambda = lambda.truncatingRemainder(dividingBy: 360.0)
        if lambda < 0 { lambda += 360.0 }
        sunLon = sunLon.truncatingRemainder(dividingBy: 360.0)
        if sunLon < 0 { sunLon += 360.0 }

        // Obliquity
        let eps0 = 23.439291111 - 0.013004167 * T
        let eps = eps0 + 0.00256 * cos(omega * d2r)
        let epsR = eps * d2r
        let lamR = lambda * d2r

        var ra = atan2(cos(epsR) * sin(lamR), cos(lamR)) * 180.0 / Double.pi
        if ra < 0 { ra += 360.0 }
        let dec = asin(sin(epsR) * sin(lamR)) * 180.0 / Double.pi

        return SunPosition(longitude: sunLon, rightAscension: ra, declination: dec)
    }

    /// Estimate Julian Day of sunset at given coordinates (±15 min approximation).
    /// Uses iterative altitude calculation.
    public static func sunsetJD(julianDay jd: Double, latitude: Double, longitude: Double) -> Double {
        let d2r = Double.pi / 180.0

        // Initial estimate: transit + 6 hours
        var jdEstimate = jd + 0.25 // rough noon

        for _ in 0 ..< 3 {
            let sun = SunPosition.compute(julianDay: jdEstimate)
            // Hour angle at sunset (h = -0.8333° for standard refraction)
            let latR = latitude * d2r
            let decR = sun.declination * d2r
            let h0 = -0.8333 * d2r
            let cosH = (sin(h0) - sin(latR) * sin(decR)) / (cos(latR) * cos(decR))
            guard cosH >= -1, cosH <= 1 else { return jdEstimate }
            let H = acos(cosH) * 180.0 / Double.pi

            // Greenwich sidereal time
            let T = (jd - 2_451_545.0) / 36525.0
            var theta0 = 280.46061837 + 360.98564736629 * (jd - 2_451_545.0)
                + 0.000387933 * T * T - T * T * T / 38_710_000.0
            theta0 = theta0.truncatingRemainder(dividingBy: 360.0)
            if theta0 < 0 { theta0 += 360.0 }

            // Local hour angle at sunset
            var n = (sun.rightAscension - longitude - theta0 + H) / 360.0
            n = n - floor(n) // fractional day
            jdEstimate = jd + n
        }
        return jdEstimate
    }
}
