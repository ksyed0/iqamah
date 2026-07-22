import CoreLocation
import SwiftUI

struct QiblahView: View {
    let latitude: Double
    let longitude: Double
    let cityName: String // AC-0134

    private let kaabahLat = 21.4225
    private let kaabahLon = 39.8262

    private var isValidCoordinate: Bool {
        latitude.isFinite && longitude.isFinite &&
            latitude >= -90 && latitude <= 90 &&
            longitude >= -180 && longitude <= 180
    }

    private var qiblahBearing: Double {
        let lat1 = latitude * .pi / 180
        let lat2 = kaabahLat * .pi / 180
        let deltaLon = (kaabahLon - longitude) * .pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private var cardinalDirection: String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return directions[Int((qiblahBearing + 22.5).truncatingRemainder(dividingBy: 360) / 45)]
    }

    private func cardinalDirection(for bearing: Double) -> String {
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return dirs[Int((bearing + 22.5) / 45) % 8]
    }

    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var hSizeClass
        // Live compass heading — rotates the ring so the Mecca marker tracks physical direction
        @StateObject private var headingObserver = QiblahHeadingObserver()
    #elseif os(visionOS)
        @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        guard isValidCoordinate else {
            return AnyView(invalidCoordinateView)
        }
        return AnyView(compassView)
    }

    private var invalidCoordinateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Location Unavailable")
                .font(.title3.bold())
            Text("A valid location is required to calculate the Qiblah direction.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            #if os(macOS)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            #endif
        }
        .frame(width: 420, height: 520)
        .accessibilityElement(children: .contain)
    }

    private var compassView: some View {
        #if os(iOS)
            GeometryReader { geo in
                let isLandscape = geo.size.width > geo.size.height
                let isRegular = hSizeClass == .regular
                if isRegular, isLandscape {
                    iPadLandscapeQibla(geo: geo)
                } else {
                    portraitQibla
                }
            }
            .background { Rectangle().fill(.regularMaterial) }
            .onAppear { headingObserver.start() }
            .onDisappear { headingObserver.stop() }
        #elseif os(visionOS)
            visionOSQibla
        #else
            macOSQibla
        #endif
    }

    #if os(iOS)
        private var compassHeader: some View {
            VStack(spacing: 3) {
                Text("Qiblah Direction")
                    .font(.title2.bold())
                    .padding(.top, 16)
                    .accessibilityAddTraits(.isHeader)
                Text(String(format: "%.1f° %@", qiblahBearing, cardinalDirection))
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.secondary)
                if !cityName.isEmpty {
                    Text("from \(cityName)")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 8)
        }

        private var portraitQibla: some View {
            VStack(spacing: 0) {
                compassHeader
                GeometryReader { geo in
                    let diameter = min(geo.size.width, geo.size.height) * 0.85
                    QiblahCompassView(diameter: diameter, bearing: qiblahBearing)
                        // Rotate the ring by -heading so the Ka'bah marker tracks physical Mecca
                        .rotationEffect(.degrees(-(headingObserver.currentHeading ?? 0)))
                        .animation(.easeInOut(duration: 0.12), value: headingObserver.currentHeading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        // XCUITest identifier (AC-0333, US-0067)
                        .accessibilityIdentifier("qiblahCompass")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func iPadLandscapeQibla(geo: GeometryProxy) -> some View {
            let panelWidth = min(220, geo.size.width * 0.28)
            return HStack(alignment: .center, spacing: 0) {
                // Compass fills left portion
                GeometryReader { inner in
                    let diameter = min(inner.size.width, inner.size.height) * 0.88
                    QiblahCompassView(diameter: diameter, bearing: qiblahBearing)
                        .rotationEffect(.degrees(-(headingObserver.currentHeading ?? 0)))
                        .animation(.easeInOut(duration: 0.12), value: headingObserver.currentHeading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Info panel
                VStack(alignment: .leading, spacing: 20) {
                    Spacer()
                    infoPanelRow(label: "Bearing",
                                 value: String(format: "%.1f°", qiblahBearing),
                                 detail: cardinalDirection)
                    infoPanelRow(label: "From",
                                 value: cityName.isEmpty ? "—" : cityName,
                                 detail: String(format: "%.4f°N · %.4f°E", latitude, longitude))
                    infoPanelRow(label: "To",
                                 value: "Makkah al-Mukarramah",
                                 detail: "21.4225°N · 39.8262°E")
                    Spacer()
                }
                .padding(.horizontal, 20)
                .frame(width: panelWidth)
                .background(Color.primary.opacity(0.05))
            }
        }

        private func infoPanelRow(label: String, value: String, detail: String) -> some View {
            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(Color.appGoldDim)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(label): \(value), \(detail)")
        }
    #endif

    #if os(macOS)
        private var macOSQibla: some View {
            VStack(spacing: 0) {
                Text("Qiblah Direction")
                    .font(.title2.bold())
                    .padding(.top, 20)
                    .accessibilityAddTraits(.isHeader)
                Text(String(format: "%.1f° %@", qiblahBearing, cardinalDirection))
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                if !cityName.isEmpty {
                    Text("from \(cityName)")
                        .font(.caption).foregroundColor(.secondary).padding(.top, 2)
                }
                GeometryReader { geo in
                    let diameter = min(geo.size.width, geo.size.height) * 0.85
                    QiblahCompassView(diameter: diameter, bearing: qiblahBearing)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appGold)
                    .controlSize(.regular)
                    .padding(.bottom, 24)
                    .padding(.top, 8)
            }
            .frame(minWidth: 380, minHeight: 480)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { Rectangle().fill(.regularMaterial) }
        }
    #endif

    #if os(visionOS)
        private var visionOSQibla: some View {
            VStack(spacing: 20) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.appGold)
                Text("Qiblah Direction")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(String(format: "%.1f° %@", qiblahBearing, cardinalDirection))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if !cityName.isEmpty {
                    Text("from \(cityName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    openWindow(id: VisionSceneIDs.qiblaVolume)
                } label: {
                    Label("Open 3D Qibla", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appGold)
                .accessibilityIdentifier("open3DQiblaButton")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { Rectangle().fill(.regularMaterial) }
        }
    #endif
}

// MARK: - Triangle (N marker)

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Scalable Compass

/// Self-contained compass that scales to any diameter.
/// All element sizes are proportional to the radius (diameter / 2).
/// Public so snapshot tests can render it directly without @testable import (AC-0310, US-0065).
public struct QiblahCompassView: View {
    public let diameter: CGFloat
    public let bearing: Double
    public init(diameter: CGFloat, bearing: Double) {
        self.diameter = diameter; self.bearing = bearing
    }

    private var r: CGFloat { diameter / 2 }

    public var body: some View {
        ZStack {
            // ── Bezel ring ──────────────────────────────────────────
            Circle()
                .fill(Color.primary.opacity(0.05))
                .frame(width: diameter, height: diameter)
            Circle()
                .stroke(Color.primary.opacity(0.28), lineWidth: 3.5)
                .frame(width: diameter, height: diameter)

            // ── Tick marks (72 × 5° = 360°) ─────────────────────────
            ForEach(0 ..< 72, id: \.self) { i in
                let angle = Double(i) * 5
                let isCardinal = i % 18 == 0
                let isSemiCard = i % 9 == 0 && !isCardinal
                let isMedium = i % 2 == 0 && !isCardinal && !isSemiCard
                let tickLen: CGFloat = isCardinal ? r * 0.14
                    : isSemiCard ? r * 0.09
                    : isMedium ? r * 0.06
                    : r * 0.032
                let tickW: CGFloat = isCardinal ? 2.5 : isSemiCard ? 1.5 : 1.0
                let opacity: Double = isCardinal ? 0.90 : isSemiCard ? 0.60
                    : isMedium ? 0.35 : 0.20
                Rectangle()
                    .fill(Color.primary.opacity(opacity))
                    .frame(width: tickW, height: tickLen)
                    .offset(y: -(r - tickLen / 2))
                    .rotationEffect(.degrees(angle))
                    .accessibilityHidden(true)
            }

            // ── Degree labels at 45 / 135 / 225 / 315 ───────────────
            ForEach([(45.0, "45"), (135.0, "135"), (225.0, "225"), (315.0, "315")], id: \.1) { angle, label in
                Text(label)
                    .font(.system(size: max(7, r * 0.056), weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.50))
                    .offset(
                        x: r * 0.86 * CGFloat(sin(angle * .pi / 180)),
                        y: -r * 0.86 * CGFloat(cos(angle * .pi / 180))
                    )
                    .accessibilityHidden(true)
            }

            // ── Cardinal labels ─────────────────────────────────────
            ForEach([("N", 0.0), ("E", 90.0), ("S", 180.0), ("W", 270.0)], id: \.0) { label, angle in
                Text(label)
                    .font(.system(size: max(10, r * 0.088), weight: .bold))
                    .foregroundColor(
                        label == "N"
                            ? Color(red: 0.95, green: 0.28, blue: 0.22)
                            : .primary.opacity(0.70)
                    )
                    .offset(
                        x: r * 0.86 * CGFloat(sin(angle * .pi / 180)),
                        y: -r * 0.86 * CGFloat(cos(angle * .pi / 180))
                    )
                    .accessibilityHidden(true)
            }

            // ── N triangle marker ────────────────────────────────────
            Triangle()
                .fill(Color(red: 0.95, green: 0.28, blue: 0.22))
                .frame(width: r * 0.063, height: r * 0.063)
                .offset(y: -(r * 0.963))
                .accessibilityHidden(true)

            // ── Dashed gold needle from center to ring ───────────────
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                let rad = bearing * .pi / 180
                let needleR = Double(r) * 0.875
                let x2 = cx + CGFloat(sin(rad) * needleR)
                let y2 = cy - CGFloat(cos(rad) * needleR)
                var path = Path()
                path.move(to: CGPoint(x: cx, y: cy))
                path.addLine(to: CGPoint(x: x2, y: y2))
                ctx.stroke(path, with: .color(Color.appGold.opacity(0.50)),
                           style: StrokeStyle(lineWidth: 3.5, dash: [8, 5], dashPhase: 0))
                // Arrowhead
                let backLen: Double = Double(r) * 0.065
                let perpAngle = rad + .pi / 2
                let baseX = x2 - CGFloat(sin(rad) * backLen)
                let baseY = y2 + CGFloat(cos(rad) * backLen)
                let left = CGPoint(x: baseX + CGFloat(cos(perpAngle) * backLen * 0.4),
                                   y: baseY + CGFloat(sin(perpAngle) * backLen * 0.4))
                let right = CGPoint(x: baseX - CGFloat(cos(perpAngle) * backLen * 0.4),
                                    y: baseY - CGFloat(sin(perpAngle) * backLen * 0.4))
                var arrow = Path()
                arrow.move(to: CGPoint(x: x2, y: y2))
                arrow.addLine(to: left)
                arrow.addLine(to: right)
                arrow.closeSubpath()
                ctx.fill(arrow, with: .color(Color.appGold.opacity(0.90)))
            }
            .frame(width: diameter, height: diameter)
            .accessibilityHidden(true)

            // ── Prayer mat — CENTERED, rotated to Qibla ─────────────
            // Mat is the centerpiece: the needle points from it toward Makkah.
            let matW = r * 0.72
            let matH = r * 0.96
            Image("PrayerMat")
                .resizable()
                .scaledToFit()
                .frame(width: matW, height: matH)
                .drawingGroup()
                .rotationEffect(.degrees(bearing))
                .accessibilityLabel("Prayer mat facing Qiblah direction")

            // ── Ka'bah icon at ring edge ─────────────────────────────
            let kaabahSize = r * 0.36
            let kaabahR = r * 0.925
            Image("KaabahIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: kaabahSize, height: kaabahSize)
                .drawingGroup()
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.appGold, lineWidth: 2))
                .shadow(color: Color.appGold.opacity(0.45), radius: 4)
                .offset(
                    x: kaabahR * CGFloat(sin(bearing * .pi / 180)),
                    y: -kaabahR * CGFloat(cos(bearing * .pi / 180))
                )
                .accessibilityLabel("Ka'bah direction marker")

            // ── Centre pivot dot ─────────────────────────────────────
            Circle()
                .fill(Color.secondary.opacity(0.45))
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Qibla compass")
    }
}

// MARK: - Ka'bah Marker

/// A small gold-outlined cube representing the Ka'bah on the compass ring.
private struct KaabahMarker: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(red: 0.15, green: 0.12, blue: 0.08))
                .frame(width: 20, height: 20)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(Color(red: 0.85, green: 0.68, blue: 0.25), lineWidth: 1.5)
                .frame(width: 20, height: 20)
            // Kiswa gold band
            Rectangle()
                .fill(Color(red: 0.85, green: 0.68, blue: 0.25).opacity(0.6))
                .frame(width: 20, height: 3)
                .offset(y: -3)
        }
    }
}

// MARK: - Kaabah Shape (kept for backwards compatibility)

struct KaabahShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.addRoundedRect(
            in: CGRect(x: 0, y: h * 0.1, width: w, height: h * 0.9),
            cornerSize: CGSize(width: w * 0.08, height: w * 0.08)
        )
        path.addRect(CGRect(x: 0, y: h * 0.35, width: w, height: h * 0.12))
        path.addRect(CGRect(x: -w * 0.03, y: h * 0.08, width: w * 1.06, height: h * 0.06))
        return path
    }
}

// MARK: - Prayer Mat Shape (kept for backwards compatibility / other uses)

struct PrayerMatShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cornerRadius = w * 0.1
        let archHeight = h * 0.25
        let archWidth = w * 0.5
        path.move(to: CGPoint(x: cornerRadius, y: h))
        path.addLine(to: CGPoint(x: w - cornerRadius, y: h))
        path.addQuadCurve(to: CGPoint(x: w, y: h - cornerRadius), control: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: w, y: cornerRadius))
        path.addQuadCurve(to: CGPoint(x: w - cornerRadius, y: 0), control: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w / 2 + archWidth / 2, y: 0))
        path.addCurve(to: CGPoint(x: w / 2, y: archHeight),
                      control1: CGPoint(x: w / 2 + archWidth * 0.4, y: 0),
                      control2: CGPoint(x: w / 2 + archWidth * 0.15, y: archHeight))
        path.addCurve(to: CGPoint(x: w / 2 - archWidth / 2, y: 0),
                      control1: CGPoint(x: w / 2 - archWidth * 0.15, y: archHeight),
                      control2: CGPoint(x: w / 2 - archWidth * 0.4, y: 0))
        path.addLine(to: CGPoint(x: cornerRadius, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: cornerRadius), control: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: cornerRadius, y: h), control: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - Prayer Mat Icon (header button)

struct PrayerMatIcon: View {
    var size: CGFloat = 20
    var body: some View {
        Image("PrayerMat")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size * 0.65, height: size)
    }
}

// MARK: - Live Heading (iOS only)

#if os(iOS)
    /// Subscribes to CLLocationManager heading updates and publishes the
    /// device's true (or magnetic) heading in degrees [0, 360).
    /// Used by QiblahView to rotate the compass ring so the Ka'bah marker
    /// always points toward physical Mecca as the user turns their phone.
    @MainActor
    final class QiblahHeadingObserver: NSObject, ObservableObject, CLLocationManagerDelegate {
        @Published var currentHeading: Double?
        private let manager = CLLocationManager()

        func start() {
            guard CLLocationManager.headingAvailable() else { return }
            manager.delegate = self
            manager.headingFilter = 1 // update when heading changes by ≥ 1°
            manager.startUpdatingHeading()
        }

        func stop() {
            manager.stopUpdatingHeading()
        }

        nonisolated func locationManager(_: CLLocationManager, didUpdateHeading heading: CLHeading) {
            // Prefer true heading (requires location fix); fall back to magnetic.
            let value = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
            Task { @MainActor in self.currentHeading = value }
        }
    }
#endif
