import SwiftUI

// MARK: - Banner root view

struct AdhaanBannerView: View {
    let prayerName: String
    let prayerTime: Date
    let adhaanDisplayName: String
    let allPrayers: [(name: String, time: Date)] // adjusted times, no Sunrise
    let timezone: TimeZone
    let onStop: () -> Void
    let onClose: () -> Void

    @ObservedObject private var player = AdhaaanPlayer.shared

    var body: some View {
        VStack(spacing: 0) {
            // ── Top row ──────────────────────────────────────
            HStack(spacing: 16) {
                WaveformView(isAnimating: player.isPlaying)
                    .frame(width: 28, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("TIME FOR PRAYER")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundColor(Color.appGold.opacity(0.75))

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(prayerName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text(formattedTime)
                            .font(.system(size: 22, weight: .light))
                            .monospacedDigit()
                            .foregroundColor(Color.appGold.opacity(0.85))
                    }

                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.appGold.opacity(player.isPlaying ? 0.8 : 0.3))
                            .frame(width: 4, height: 4)
                            .animation(player.isPlaying
                                ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                : .default,
                                value: player.isPlaying)
                        Text(player.isPlaying
                            ? "\(adhaanDisplayName) · playing"
                            : "\(adhaanDisplayName) · finished")
                            .font(.system(size: 11))
                            .foregroundColor(Color.appGold.opacity(0.6))
                    }
                }

                Spacer(minLength: 0)

                // Stop / Close button
                Button(action: player.isPlaying ? onStop : onClose) {
                    ZStack {
                        Circle()
                            .fill(player.isPlaying
                                ? Color.red.opacity(0.18)
                                : Color.white.opacity(0.08))
                            .frame(width: 52, height: 52)
                        Circle()
                            .strokeBorder(player.isPlaying
                                ? Color.red.opacity(0.55)
                                : Color.white.opacity(0.22),
                                lineWidth: 1.5)
                            .frame(width: 52, height: 52)

                        if player.isPlaying {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.red)
                                .frame(width: 18, height: 18)
                        } else {
                            Text("✕")
                                .font(.system(size: 17, weight: .light))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(player.isPlaying ? "Stop adhaan" : "Dismiss")
                .overlay(alignment: .bottom) {
                    Text(player.isPlaying ? "STOP" : "CLOSE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.38))
                        .tracking(0.5)
                        .offset(y: 14)
                }
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // ── Sun arc ──────────────────────────────────────
            Divider().opacity(0.06)

            SunArcView(
                allPrayers: allPrayers,
                currentPrayerName: prayerName
            )
            .frame(height: 70)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 14)
        }
        .background {
            if #available(macOS 26, *) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .glassEffect(.regular.tint(Color.appGold.opacity(0.08)))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.appGold.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 32, x: 0, y: 8)
    }

    private var formattedTime: String {
        let fmt = DateFormatter()
        fmt.timeZone = timezone
        fmt.dateFormat = SettingsManager.shared.use24HourTime ? "HH:mm" : "h:mm a"
        return fmt.string(from: prayerTime)
    }
}

// MARK: - Waveform animation

private struct WaveformView: View {
    let isAnimating: Bool
    private let delays: [Double] = [0, 0.15, 0.3, 0.15, 0]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0 ..< 5, id: \.self) { i in
                WaveBar(delay: delays[i], isAnimating: isAnimating)
            }
        }
    }
}

private struct WaveBar: View {
    let delay: Double
    let isAnimating: Bool
    @State private var scaleY: CGFloat = 0.35

    var body: some View {
        Capsule()
            .fill(Color.appGold)
            .frame(width: 3.5, height: 26)
            .scaleEffect(y: scaleY, anchor: .center)
            .onAppear { updateAnimation() }
            .onChange(of: isAnimating) { _, _ in updateAnimation() }
    }

    private func updateAnimation() {
        if isAnimating {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay)) {
                scaleY = 1.0
            }
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                scaleY = 0.25
            }
        }
    }
}

// MARK: - Sun arc

private struct SunArcView: View {
    let allPrayers: [(name: String, time: Date)]
    let currentPrayerName: String

    // Time-of-day gradient matching mockup: dawn → golden midday → sunset → night
    private let arcGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.10, green: 0.04, blue: 0.23), location: 0.00),
            .init(color: Color(red: 0.24, green: 0.11, blue: 0.42), location: 0.12),
            .init(color: Color(red: 0.91, green: 0.52, blue: 0.36), location: 0.22),
            .init(color: Color(red: 0.98, green: 0.84, blue: 0.43), location: 0.48),
            .init(color: Color(red: 0.96, green: 0.57, blue: 0.24), location: 0.72),
            .init(color: Color(red: 0.75, green: 0.22, blue: 0.17), location: 0.85),
            .init(color: Color(red: 0.05, green: 0.05, blue: 0.17), location: 1.00),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Horizon
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h - 7))
                    p.addLine(to: CGPoint(x: w, y: h - 7))
                }
                .stroke(Color.white.opacity(0.07), lineWidth: 1)

                // Arc
                arcPath(w: w, h: h)
                    .stroke(arcGradient, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                // Prayer dots + labels
                ForEach(allPrayers, id: \.name) { prayer in
                    let pt = pointOnArc(for: prayer.time, w: w, h: h)
                    let isActive = prayer.name == currentPrayerName

                    // Dot
                    Circle()
                        .fill(isActive ? Color.appGold.opacity(0.9) : Color.appGold.opacity(0.32))
                        .frame(width: isActive ? 9 : 6, height: isActive ? 9 : 6)
                        .animation(.easeInOut(duration: 0.4), value: isActive)
                        .position(x: pt.x, y: pt.y)

                    // Label
                    Text(shortName(prayer.name))
                        .font(.system(size: 9, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? Color.appGold.opacity(0.9) : Color.white.opacity(0.32))
                        .animation(.easeInOut(duration: 0.3), value: isActive)
                        .position(x: clamp(pt.x, lo: 16, hi: w - 16), y: h)
                }

                // Sun glow + core
                if let current = allPrayers.first(where: { $0.name == currentPrayerName }) {
                    let pt = pointOnArc(for: current.time, w: w, h: h)

                    Circle()
                        .fill(Color.appGold.opacity(0.22))
                        .frame(width: 22, height: 22)
                        .blur(radius: 5)
                        .position(x: pt.x, y: pt.y)
                        .animation(.easeInOut(duration: 0.6), value: pt.x)

                    Circle()
                        .fill(Color.appGold)
                        .frame(width: 10, height: 10)
                        .shadow(color: Color.appGold.opacity(0.6), radius: 4)
                        .position(x: pt.x, y: pt.y)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: pt.x)
                }
            }
        }
    }

    // MARK: Bezier helpers

    /// Arc endpoints share the horizon; control point is at the top centre.
    private func arcPath(w: CGFloat, h: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 8, y: h - 7))
        p.addQuadCurve(
            to: CGPoint(x: w - 8, y: h - 7),
            control: CGPoint(x: w / 2, y: 6)
        )
        return p
    }

    private func pointOnArc(for time: Date, w: CGFloat, h: CGFloat) -> CGPoint {
        let t = tValue(for: time)
        let p0 = CGPoint(x: 8, y: h - 7)
        let p1 = CGPoint(x: w / 2, y: 6)
        let p2 = CGPoint(x: w - 8, y: h - 7)
        return bezier(t: t, p0: p0, p1: p1, p2: p2)
    }

    /// Maps a time to parameter t ∈ [0,1] across the Fajr→Isha span.
    private func tValue(for time: Date) -> Double {
        guard let fajr = allPrayers.first(where: { $0.name == "Fajr" })?.time,
              let isha = allPrayers.first(where: { $0.name == "Isha" })?.time else { return 0.5 }
        let span = isha.timeIntervalSince(fajr)
        guard span > 0 else { return 0.5 }
        return max(0.02, min(0.98, time.timeIntervalSince(fajr) / span))
    }

    private func bezier(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        let mt = 1 - t
        return CGPoint(
            x: mt * mt * p0.x + 2 * t * mt * p1.x + t * t * p2.x,
            y: mt * mt * p0.y + 2 * t * mt * p1.y + t * t * p2.y
        )
    }

    private func shortName(_ name: String) -> String {
        name == "Maghrib" ? "Mghrb" : name
    }

    private func clamp(_ v: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
        max(lo, min(hi, v))
    }
}
