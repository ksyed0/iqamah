import CoreLocation
import IqamahCore
import SwiftUI

struct QiblaTab: View {
    @EnvironmentObject private var settings: SettingsManager
    @StateObject private var headingObserver = HeadingObserver()

    private let gold = Color(red: 1.0, green: 0.839, blue: 0.039)

    var body: some View {
        VStack(spacing: 8) {
            if let coord = settings.activeCoordinate {
                let bearing = qiblaBearing(from: coord)
                let distance = distanceToMakkahKm(from: coord)

                ZStack {
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: 0.12)
                        .stroke(gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(bearing - 90))
                        .animation(.easeInOut(duration: 0.3), value: bearing)
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(gold, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(gold.opacity(0.2))
                        )
                }
                .frame(width: 80, height: 80)

                Text(faceText(bearing: bearing))
                    .font(.system(size: 13, weight: .semibold))

                if let currentHeading = headingObserver.currentHeading {
                    Text(turnText(current: currentHeading, target: bearing))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Heading unavailable")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Text(String(format: "Makkah · %.0f km", distance))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.6))
            } else {
                Image(systemName: "location.slash")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Location needed\nfor Qibla")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { headingObserver.start() }
        .onDisappear { headingObserver.stop() }
    }

    private func faceText(bearing: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let idx = Int((bearing + 22.5) / 45) % 8
        return String(format: "Face %.0f° %@", bearing, directions[idx])
    }

    private func turnText(current: Double, target: Double) -> String {
        var delta = target - current
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        let absD = abs(delta)
        if absD < 5 { return "You're facing Qibla ✓" }
        let dir = delta > 0 ? "right" : "left"
        return String(format: "Turn %.0f° %@", absD, dir)
    }
}

@MainActor
final class HeadingObserver: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentHeading: Double?
    private let manager = CLLocationManager()

    func start() {
        manager.delegate = self
        manager.headingFilter = 2.0
        manager.startUpdatingHeading()
    }

    func stop() {
        manager.stopUpdatingHeading()
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateHeading heading: CLHeading) {
        guard heading.headingAccuracy >= 0 else { return }
        Task { @MainActor in self.currentHeading = heading.trueHeading }
    }
}
