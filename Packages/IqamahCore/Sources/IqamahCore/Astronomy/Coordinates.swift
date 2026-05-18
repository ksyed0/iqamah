import Foundation

/// Horizon coordinates and crescent geometry helpers.
public struct HorizonCoordinates {
    /// Altitude above the horizon, degrees.
    public let altitude: Double
    /// Azimuth (N=0, E=90), degrees.
    public let azimuth: Double
}

public extension HorizonCoordinates {
    /// Convert equatorial (RA, Dec) to horizon coordinates at the given observer location and sidereal time.
    static func from(
        rightAscension ra: Double,
        declination dec: Double,
        latitude: Double,
        localSiderealTime lst: Double
    ) -> HorizonCoordinates {
        let d2r = Double.pi / 180.0
        let hourAngle = (lst - ra).truncatingRemainder(dividingBy: 360.0)
        let haR = hourAngle * d2r
        let latR = latitude * d2r
        let decR = dec * d2r

        let sinAlt = sin(latR) * sin(decR) + cos(latR) * cos(decR) * cos(haR)
        let alt = asin(max(-1, min(1, sinAlt))) * 180.0 / Double.pi

        let cosAz = (sin(decR) - sin(latR) * sinAlt) / (cos(latR) * cos(alt * d2r))
        var az = acos(max(-1, min(1, cosAz))) * 180.0 / Double.pi
        if sin(haR) > 0 { az = 360.0 - az }

        return HorizonCoordinates(altitude: alt, azimuth: az)
    }
}

/// Angular separation between two points on the celestial sphere (degrees).
public func angularSeparation(ra1: Double, dec1: Double, ra2: Double, dec2: Double) -> Double {
    let d2r = Double.pi / 180.0
    let dra = (ra1 - ra2) * d2r
    let d1 = dec1 * d2r
    let d2 = dec2 * d2r
    let cosDist = sin(d1) * sin(d2) + cos(d1) * cos(d2) * cos(dra)
    return acos(max(-1, min(1, cosDist))) * 180.0 / Double.pi
}

/// Crescent width in arcminutes from elongation and Moon distance.
/// Uses Yallop (1997) formulation: W = SD × (1 − cos(ARCL))
public func crescentWidthArcmin(arclDegrees: Double, moonDistanceKm: Double) -> Double {
    let d2r = Double.pi / 180.0
    // Semi-diameter of Moon in arcmin
    let semiDiamArcmin = asin(1737.4 / moonDistanceKm) * 180.0 / Double.pi * 60.0
    // W = SD × (1 − cos(ARCL)) / 2  (Odeh 2004, eq. 10 approximation)
    return semiDiamArcmin * (1.0 - cos(arclDegrees * d2r)) / 2.0
}
