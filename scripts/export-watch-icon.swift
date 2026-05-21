#!/usr/bin/env swift

// BUG-0068 watch icon exporter (CLI).
// Renders one or all WatchAppIconView variants to ~/Desktop/IqamahWatchIcons/*.png.
//
// Usage:
//   swift scripts/export-watch-icon.swift            # exports all three variants
//   swift scripts/export-watch-icon.swift B          # exports just variant B
//   swift scripts/export-watch-icon.swift A B C      # exports specified variants
//
// Variants: A = goldSolid, B = lighterNavy, C = radialGlow (recommended)

import SwiftUI
import AppKit

// MARK: - MinaretShape (inlined from iqamah/ContentView.swift to keep this script self-contained)

struct MinaretShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        let crescentTop = height * 0.05
        let crescentWidth = width * 0.3
        let crescentHeight = height * 0.08
        let crescentCenter = CGPoint(x: width / 2, y: crescentTop)

        path.addArc(
            center: CGPoint(x: crescentCenter.x - crescentWidth * 0.15, y: crescentCenter.y),
            radius: crescentWidth * 0.35,
            startAngle: .degrees(-30), endAngle: .degrees(210), clockwise: false
        )
        path.addArc(
            center: CGPoint(x: crescentCenter.x + crescentWidth * 0.05, y: crescentCenter.y),
            radius: crescentWidth * 0.25,
            startAngle: .degrees(150), endAngle: .degrees(-70), clockwise: true
        )

        let spireTop = crescentTop + crescentHeight
        let spireBottom = height * 0.18
        let spireWidth = width * 0.08
        path.move(to: CGPoint(x: width / 2, y: spireTop))
        path.addLine(to: CGPoint(x: width / 2 - spireWidth / 2, y: spireBottom))
        path.addLine(to: CGPoint(x: width / 2 + spireWidth / 2, y: spireBottom))
        path.closeSubpath()

        let domeTop = spireBottom
        let domeBottom = height * 0.28
        let domeWidth = width * 0.45
        path.move(to: CGPoint(x: width / 2 - domeWidth / 2, y: domeBottom))
        path.addQuadCurve(
            to: CGPoint(x: width / 2 + domeWidth / 2, y: domeBottom),
            control: CGPoint(x: width / 2, y: domeTop)
        )
        path.addLine(to: CGPoint(x: width / 2 + domeWidth / 2, y: domeBottom))
        path.closeSubpath()

        let balconyY = domeBottom
        let balconyWidth = width * 0.55
        let balconyHeight = height * 0.04
        path.addRoundedRect(
            in: CGRect(x: width / 2 - balconyWidth / 2, y: balconyY, width: balconyWidth, height: balconyHeight),
            cornerSize: CGSize(width: balconyHeight * 0.3, height: balconyHeight * 0.3)
        )

        let towerTop = balconyY + balconyHeight
        let towerBottom = height * 0.88
        let towerTopWidth = width * 0.42
        let towerBottomWidth = width * 0.55
        path.move(to: CGPoint(x: width / 2 - towerTopWidth / 2, y: towerTop))
        path.addLine(to: CGPoint(x: width / 2 - towerBottomWidth / 2, y: towerBottom))
        path.addLine(to: CGPoint(x: width / 2 + towerBottomWidth / 2, y: towerBottom))
        path.addLine(to: CGPoint(x: width / 2 + towerTopWidth / 2, y: towerTop))
        path.closeSubpath()

        let windowY1 = height * 0.45
        let windowY2 = height * 0.60
        let windowY3 = height * 0.75
        let windowWidth = width * 0.18
        let windowHeight = height * 0.08
        for windowY in [windowY1, windowY2, windowY3] {
            path.move(to: CGPoint(x: width / 2 - windowWidth * 1.2, y: windowY + windowHeight))
            path.addQuadCurve(
                to: CGPoint(x: width / 2 - windowWidth * 1.2 + windowWidth * 0.6, y: windowY + windowHeight),
                control: CGPoint(x: width / 2 - windowWidth * 0.9, y: windowY)
            )
            path.move(to: CGPoint(x: width / 2 + windowWidth * 0.6, y: windowY + windowHeight))
            path.addQuadCurve(
                to: CGPoint(x: width / 2 + windowWidth * 1.2, y: windowY + windowHeight),
                control: CGPoint(x: width / 2 + windowWidth * 0.9, y: windowY)
            )
        }

        let baseY = towerBottom
        let baseWidth = width * 0.8
        let baseHeight = height * 0.12
        path.addRoundedRect(
            in: CGRect(x: width / 2 - baseWidth / 2, y: baseY, width: baseWidth, height: baseHeight),
            cornerSize: CGSize(width: baseHeight * 0.2, height: baseHeight * 0.2)
        )

        return path
    }
}

// MARK: - WatchIconVariant + WatchAppIconView (inlined from iqamah/WatchAppIconView.swift)

enum WatchIconVariant: String, CaseIterable {
    case goldSolid       // A
    case lighterNavy     // B
    case radialGlow      // C

    static func from(_ letter: String) -> WatchIconVariant? {
        switch letter.uppercased() {
        case "A", "GOLDSOLID": return .goldSolid
        case "B", "LIGHTERNAVY": return .lighterNavy
        case "C", "RADIALGLOW": return .radialGlow
        default: return nil
        }
    }
}

struct WatchAppIconView: View {
    let size: CGFloat
    let variant: WatchIconVariant

    var body: some View {
        ZStack {
            background
            MinaretShape()
                .fill(minaretFill)
                .frame(width: size * 0.38, height: size * 0.50)
                .shadow(color: Color.black.opacity(0.35), radius: size * 0.02, x: 0, y: size * 0.012)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .goldSolid:
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.71, blue: 0.20),
                    Color(red: 0.74, green: 0.54, blue: 0.10)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .lighterNavy:
            LinearGradient(
                colors: [
                    Color(red: 0.23, green: 0.31, blue: 0.47),
                    Color(red: 0.12, green: 0.16, blue: 0.23)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .radialGlow:
            RadialGradient(
                colors: [
                    Color(red: 0.29, green: 0.38, blue: 0.56),
                    Color(red: 0.18, green: 0.24, blue: 0.36),
                    Color(red: 0.12, green: 0.16, blue: 0.23)
                ],
                center: .center, startRadius: 0, endRadius: size * 0.62
            )
        }
    }

    private var minaretFill: LinearGradient {
        switch variant {
        case .goldSolid:
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.16, blue: 0.24),
                    Color(red: 0.04, green: 0.08, blue: 0.14)
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .lighterNavy, .radialGlow:
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.76, blue: 0.06),
                    Color(red: 0.85, green: 0.65, blue: 0.13)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}

// MARK: - Render + write helpers

@MainActor
func renderPNG(variant: WatchIconVariant, size: CGFloat = 1024) -> Data? {
    let view = WatchAppIconView(size: size, variant: variant)
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = CGRect(x: 0, y: 0, width: size, height: size)

    guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
        return nil
    }
    bitmapRep.size = NSSize(width: size, height: size)
    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)
    return bitmapRep.representation(using: .png, properties: [:])
}

@MainActor
func exportVariant(_ variant: WatchIconVariant, to dir: URL) throws {
    guard let data = renderPNG(variant: variant) else {
        throw NSError(domain: "WatchIconExporter", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to render \(variant.rawValue)"])
    }
    let url = dir.appendingPathComponent("icon_\(variant.rawValue)_1024x1024.png")
    try data.write(to: url)
    print("✅ \(url.path)")
}

@MainActor
func main() {
    // Parse args. Args after the script name; default to all variants.
    let args = CommandLine.arguments.dropFirst()
    let variants: [WatchIconVariant]
    if args.isEmpty {
        variants = WatchIconVariant.allCases
    } else {
        variants = args.compactMap { WatchIconVariant.from($0) }
        if variants.isEmpty {
            print("❌ No valid variants in \(Array(args)). Use A, B, or C.")
            exit(1)
        }
    }

    let fm = FileManager.default
    let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask).first!
    let dir = desktop.appendingPathComponent("IqamahWatchIcons")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

    for variant in variants {
        do {
            try exportVariant(variant, to: dir)
        } catch {
            print("❌ \(variant.rawValue): \(error.localizedDescription)")
        }
    }

    print("\n📁 Wrote PNGs to \(dir.path)")
    print("   Reveal in Finder: open \(dir.path)")
}

// Kick off main on the main actor
let app = NSApplication.shared
_ = app  // ensure NSApplication is initialized for NSHostingView
Task { @MainActor in
    main()
    exit(0)
}
RunLoop.main.run()
