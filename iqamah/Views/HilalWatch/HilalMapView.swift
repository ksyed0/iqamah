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
    func updateMap(_ map: MKMapView) {
        map.removeOverlays(map.overlays)
        var overlays = [HilalCellOverlay]()
        overlays.reserveCapacity(HilalCalculator.cellCount)
        for latBand in 0 ..< HilalCalculator.latitudeBands {
            let lat = Double(latBand) * 2.0 - 88.0
            for lonBand in 0 ..< HilalCalculator.longitudeBands {
                let lon = Double(lonBand) * 2.0 - 178.0
                let idx = latBand * HilalCalculator.longitudeBands + lonBand
                let rawCategory = grid[idx]
                var coords = [
                    CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    CLLocationCoordinate2D(latitude: lat, longitude: lon + 2.0),
                    CLLocationCoordinate2D(latitude: lat + 2.0, longitude: lon + 2.0),
                    CLLocationCoordinate2D(latitude: lat + 2.0, longitude: lon),
                ]
                let overlay = HilalCellOverlay(coordinates: &coords, count: 4)
                overlay.category = VisibilityCategory(rawValue: Int(rawCategory)) ?? .D
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
