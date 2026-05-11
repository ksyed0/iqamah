import CoreLocation
import Foundation

private let makkahLatitudeDeg = 21.4225
private let makkahLongitudeDeg = 39.8262
private let earthRadiusKm = 6371.0

/// Returns the great-circle bearing (degrees, 0–360 clockwise from north)
/// from the given coordinate to the Ka'bah in Makkah (21.4225°N, 39.8262°E).
///
/// - Note: When called from the Ka'bah itself, the bearing is geometrically
///   undefined; this function returns 0° in that case (Swift's atan2(0,0) convention).
public func qiblaBearing(from coordinate: CLLocationCoordinate2D) -> Double {
    let makkahLat = makkahLatitudeDeg * .pi / 180
    let makkahLon = makkahLongitudeDeg * .pi / 180
    let lat1 = coordinate.latitude * .pi / 180
    let deltaLon = makkahLon - coordinate.longitude * .pi / 180

    let y = sin(deltaLon) * cos(makkahLat)
    let x = cos(lat1) * sin(makkahLat) - sin(lat1) * cos(makkahLat) * cos(deltaLon)
    var bearing = atan2(y, x) * 180 / .pi
    if bearing < 0 { bearing += 360 }
    return bearing
}

/// Distance in km from the given coordinate to the Ka'bah.
public func distanceToMakkahKm(from coordinate: CLLocationCoordinate2D) -> Double {
    let makkahLat = makkahLatitudeDeg * .pi / 180
    let makkahLon = makkahLongitudeDeg * .pi / 180
    let lat1 = coordinate.latitude * .pi / 180
    let lat2 = makkahLat
    let deltaLat = lat2 - lat1
    let deltaLon = makkahLon - coordinate.longitude * .pi / 180

    let a = sin(deltaLat / 2) * sin(deltaLat / 2)
        + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
    return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a))
}
