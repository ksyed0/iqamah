import MapKit
import SwiftUI
import IqamahCore

#if os(macOS)
    struct HilalMapView: NSViewRepresentable {
        let grid: ContiguousArray<Int8>
        @Environment(\.colorScheme) var colorScheme

        func makeNSView(context: Context) -> MKMapView {
            let map = MKMapView()
            map.mapType = .mutedStandard
            map.delegate = context.coordinator
            return map
        }

        func updateNSView(_ map: MKMapView, context _: Context) {
            updateMap(map)
        }

        func makeCoordinator() -> HilalMapCoordinator {
            HilalMapCoordinator(colorScheme: colorScheme)
        }
    }
#else
    struct HilalMapView: UIViewRepresentable {
        let grid: ContiguousArray<Int8>
        @Environment(\.colorScheme) var colorScheme

        func makeUIView(context: Context) -> MKMapView {
            let map = MKMapView()
            map.mapType = .mutedStandard
            map.delegate = context.coordinator
            return map
        }

        func updateUIView(_ map: MKMapView, context _: Context) {
            updateMap(map)
        }

        func makeCoordinator() -> HilalMapCoordinator {
            HilalMapCoordinator(colorScheme: colorScheme)
        }
    }
#endif

// MARK: - Shared map update logic

private extension HilalMapView {
    /// Display step in bands: 2 = 4°×4° display cells (4,050 polygons vs 16,200).
    /// The data grid stays full-resolution; we just merge 2×2 blocks for rendering
    /// to stay well under MapKit's 50,000 Metal buffer threshold.
    static let displayStep = 2

    func updateMap(_ map: MKMapView) {
        map.removeOverlays(map.overlays)
        let step = Self.displayStep
        var overlays = [HilalCellOverlay]()
        overlays.reserveCapacity(HilalCalculator.cellCount / (step * step))
        for latBand in stride(from: 0, to: HilalCalculator.latitudeBands, by: step) {
            let lat = Double(latBand) * 2.0 - 88.0
            for lonBand in stride(from: 0, to: HilalCalculator.longitudeBands, by: step) {
                let lon = Double(lonBand) * 2.0 - 178.0
                // Merge step×step cells: take the most-favourable category
                var best = Int8(VisibilityCategory.D.rawValue)
                for dl in 0 ..< step {
                    for dm in 0 ..< step {
                        let r = latBand + dl, c = lonBand + dm
                        guard r < HilalCalculator.latitudeBands,
                              c < HilalCalculator.longitudeBands else { continue }
                        let v = grid[r * HilalCalculator.longitudeBands + c]
                        if v > best { best = v }
                    }
                }
                let size = Double(step) * 2.0
                var coords = [
                    CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    CLLocationCoordinate2D(latitude: lat, longitude: lon + size),
                    CLLocationCoordinate2D(latitude: lat + size, longitude: lon + size),
                    CLLocationCoordinate2D(latitude: lat + size, longitude: lon),
                ]
                let overlay = HilalCellOverlay(coordinates: &coords, count: 4)
                overlay.category = VisibilityCategory(rawValue: Int(best)) ?? .D
                overlays.append(overlay)
            }
        }
        map.addOverlays(overlays, level: .aboveRoads)
    }
}

// MARK: - Shared coordinator

final class HilalMapCoordinator: NSObject, MKMapViewDelegate {
    var colorScheme: ColorScheme
    init(colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
    }

    func mapView(_: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let cell = overlay as? HilalCellOverlay else {
            return MKOverlayRenderer(overlay: overlay)
        }
        let renderer = MKPolygonRenderer(polygon: cell)
        let color = HilalPalette.fill(for: cell.category, colorScheme: colorScheme)
        let alpha = HilalPalette.alpha(for: cell.category, colorScheme: colorScheme)
        #if os(macOS)
            renderer.fillColor = NSColor(color).withAlphaComponent(alpha)
        #else
            renderer.fillColor = UIColor(color).withAlphaComponent(alpha)
        #endif
        renderer.strokeColor = .clear
        return renderer
    }
}
