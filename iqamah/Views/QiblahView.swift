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
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .frame(width: 420, height: 520)
        .accessibilityElement(children: .contain)
    }

    private var compassView: some View {
        VStack(spacing: 0) {
            // Title
            Text("Qiblah Direction")
                .font(.title2.bold())
                .padding(.top, 28)
                .accessibilityAddTraits(.isHeader)

            Text(String(format: "%.1f° %@", qiblahBearing, cardinalDirection))
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .padding(.top, 6)
                .accessibilityLabel("Qiblah: \(Int(qiblahBearing)) degrees \(cardinalDirection)")

            // AC-0134: city context — use .secondary (no manual opacity, meets contrast floor)
            if !cityName.isEmpty {
                Text("from \(cityName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }

            // Compass
            ZStack {
                // ── Bezel ring ──────────────────────────────────────────
                Circle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 320, height: 320)

                Circle()
                    .stroke(Color.primary.opacity(0.18), lineWidth: 2)
                    .frame(width: 320, height: 320)

                // ── iOS-style tick marks: every 5° (72 ticks) ───────────
                // Major = 0/90/180/270, Semi = 45/135/225/315,
                // Medium = every 10°, Minor = every 5°
                ForEach(0 ..< 72, id: \.self) { i in
                    let angle = Double(i) * 5
                    let isCardinal  = i % 18 == 0          // 0 90 180 270
                    let isSemiCard  = i % 9 == 0 && !isCardinal  // 45 135 225 315
                    let isMedium    = i % 2 == 0 && !isCardinal && !isSemiCard // every 10°
                    let tickLen: CGFloat = isCardinal ? 22 : isSemiCard ? 14 : isMedium ? 9 : 5
                    let tickW: CGFloat   = isCardinal ? 2.5 : isSemiCard ? 1.5 : 1
                    let opacity: Double  = isCardinal ? 0.90 : isSemiCard ? 0.60 : isMedium ? 0.35 : 0.20
                    Rectangle()
                        .fill(Color.primary.opacity(opacity))
                        .frame(width: tickW, height: tickLen)
                        .offset(y: -(160 - tickLen / 2))
                        .rotationEffect(.degrees(angle))
                        .accessibilityHidden(true)
                }

                // ── Degree labels at 45 / 135 / 225 / 315 ───────────────
                ForEach([(45.0, "45"), (135.0, "135"), (225.0, "225"), (315.0, "315")], id: \.1) { angle, label in
                    Text(label)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.50))
                        .offset(
                            x: 138 * CGFloat(sin(angle * .pi / 180)),
                            y: -138 * CGFloat(cos(angle * .pi / 180))
                        )
                        .accessibilityHidden(true)
                }

                // ── Cardinal labels ─────────────────────────────────────
                ForEach([("N", 0.0), ("E", 90.0), ("S", 180.0), ("W", 270.0)], id: \.0) { label, angle in
                    Text(label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(
                            label == "N"
                                ? Color(red: 0.95, green: 0.28, blue: 0.22)
                                : .primary.opacity(0.70)
                        )
                        .offset(
                            x: 138 * CGFloat(sin(angle * .pi / 180)),
                            y: -138 * CGFloat(cos(angle * .pi / 180))
                        )
                        .accessibilityHidden(true)
                }

                // ── N triangle marker on ring ────────────────────────────
                Triangle()
                    .fill(Color(red: 0.95, green: 0.28, blue: 0.22))
                    .frame(width: 10, height: 10)
                    .offset(y: -154)
                    .accessibilityHidden(true)

                // ── Dashed gold line from mat edge to ring ───────────────
                // Drawn as a Canvas shape from matEdge to ringEdge
                Canvas { ctx, size in
                    let cx = size.width / 2
                    let cy = size.height / 2
                    let rad = qiblahBearing * .pi / 180
                    let matEdge: Double = 52        // half mat height
                    let ringEdge: Double = 134      // inner edge of tick ring
                    let x1 = cx + CGFloat(sin(rad) * matEdge)
                    let y1 = cy - CGFloat(cos(rad) * matEdge)
                    let x2 = cx + CGFloat(sin(rad) * ringEdge)
                    let y2 = cy - CGFloat(cos(rad) * ringEdge)
                    var path = Path()
                    path.move(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))
                    ctx.stroke(
                        path,
                        with: .color(Color.appGold.opacity(0.80)),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4], dashPhase: 0)
                    )
                    // Arrowhead at ring edge
                    let backLen: Double = 10
                    let perpAngle = rad + .pi / 2
                    let tipX = x2, tipY = y2
                    let baseX = x2 - CGFloat(sin(rad) * backLen)
                    let baseY = y2 + CGFloat(cos(rad) * backLen)
                    let left  = CGPoint(x: baseX + CGFloat(cos(perpAngle) * 5), y: baseY + CGFloat(sin(perpAngle) * 5))
                    let right = CGPoint(x: baseX - CGFloat(cos(perpAngle) * 5), y: baseY - CGFloat(sin(perpAngle) * 5))
                    var arrow = Path()
                    arrow.move(to: CGPoint(x: tipX, y: tipY))
                    arrow.addLine(to: left)
                    arrow.addLine(to: right)
                    arrow.closeSubpath()
                    ctx.fill(arrow, with: .color(Color.appGold.opacity(0.90)))
                }
                .frame(width: 320, height: 320)
                .accessibilityHidden(true)

                // ── Prayer mat (rotates toward Qibla) ───────────────────
                Image("PrayerMat")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 108)
                    .drawingGroup()
                    .rotationEffect(.degrees(qiblahBearing))
                    .accessibilityLabel("Prayer mat facing Qiblah direction")

                // ── Ka'bah icon on ring edge ─────────────────────────────
                Image("KaabahIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .drawingGroup()
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.appGold, lineWidth: 2))
                    .shadow(color: Color.appGold.opacity(0.45), radius: 4)
                    .offset(
                        x: 148 * CGFloat(sin(qiblahBearing * .pi / 180)),
                        y: -148 * CGFloat(cos(qiblahBearing * .pi / 180))
                    )
                    .accessibilityLabel("Ka'bah direction marker")

                // ── Centre pivot dot ─────────────────────────────────────
                Circle()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }
            .frame(width: 380, height: 380)
            .padding(.top, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Qiblah direction: \(Int(qiblahBearing)) degrees \(cardinalDirection(for: qiblahBearing))")
            .accessibilityValue("Face \(cardinalDirection(for: qiblahBearing)) to face Mecca")

            Spacer()

            // BUG-0027: gold tint matches app brand instead of default system accent
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.appGold)
                .controlSize(.regular)
                .padding(.bottom, 24)
        }
        .frame(width: 440, height: 560)
        .background {
            Rectangle().fill(.regularMaterial)
        }
    }
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
