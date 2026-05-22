import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

#if DEBUG
// MARK: - BUG-0068 fix (developer-only — wrapped in #if DEBUG)

/// Watch-specific app icon designs aimed at fixing BUG-0068 (App Store rejection
/// citing Guideline 4 — Design: existing watch icon background blends into the
/// black watchOS home-screen wallpaper).
///
/// This file lives in the macOS app target so we can preview every variant in
/// Xcode and export PNGs from a single dev-time call. The chosen variant gets
/// rendered at 1024×1024 and replaces `IqamahWatch/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png`.
///
/// Apple-style note: watchOS renders icons as fully circular crops with no
/// system chrome. The background color IS the visual boundary, so it must
/// contrast the watch face wallpaper (typically black). Apple's own system
/// icons (Maps, Weather, Compass) use solid mid-luminance fills or
/// brighter-centre radial gradients for exactly this reason.

enum WatchIconVariant: String, CaseIterable, Identifiable {
    case goldSolid       // A — solid gold background, dark minaret
    case lighterNavy     // B — lighter linear gradient, existing gold minaret
    case radialGlow      // C — radial gradient with brighter centre (recommended)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .goldSolid: "A · Gold solid"
        case .lighterNavy: "B · Lighter navy"
        case .radialGlow: "C · Radial glow (recommended)"
        }
    }
}

struct WatchAppIconView: View {
    let size: CGFloat
    let variant: WatchIconVariant

    init(size: CGFloat = 1024, variant: WatchIconVariant = .radialGlow) {
        self.size = size
        self.variant = variant
    }

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
                    Color(red: 0.92, green: 0.71, blue: 0.20),  // bright gold top
                    Color(red: 0.74, green: 0.54, blue: 0.10)   // deeper gold bottom
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .lighterNavy:
            LinearGradient(
                colors: [
                    Color(red: 0.23, green: 0.31, blue: 0.47),  // #3A5078
                    Color(red: 0.12, green: 0.16, blue: 0.23)   // #1F2A3A
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .radialGlow:
            RadialGradient(
                colors: [
                    Color(red: 0.29, green: 0.38, blue: 0.56),  // #4A6090 — bright centre
                    Color(red: 0.18, green: 0.24, blue: 0.36),  // mid
                    Color(red: 0.12, green: 0.16, blue: 0.23)   // #1F2A3A — darker edge
                ],
                center: .center,
                startRadius: 0,
                endRadius: size * 0.62
            )
        }
    }

    private var minaretFill: LinearGradient {
        switch variant {
        case .goldSolid:
            // Dark navy minaret pops on the gold background
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.16, blue: 0.24),
                    Color(red: 0.04, green: 0.08, blue: 0.14)
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .lighterNavy, .radialGlow:
            // Existing gold gradient — unchanged from current design
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

// MARK: - Previews

#Preview("All three variants — watch home grid sim") {
    let icons = WatchIconVariant.allCases
    let neighbors = ["map.fill", "cloud.fill", "compass.drawing", "applewatch"]
    return ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            ForEach(icons) { variant in
                VStack(spacing: 8) {
                    Text(variant.label)
                        .font(.caption).foregroundStyle(.white)
                    HStack(spacing: 12) {
                        WatchAppIconView(size: 88, variant: variant)
                            .clipShape(Circle())
                        ForEach(neighbors, id: \.self) { sf in
                            ZStack {
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.85),
                                        Color(white: 0.55)
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                                Image(systemName: sf)
                                    .font(.system(size: 36, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 88, height: 88)
                            .clipShape(Circle())
                        }
                    }
                }
            }
        }
        .padding(24)
    }
}

#Preview("Variant A — Gold solid (88pt)") {
    ZStack {
        Color.black.ignoresSafeArea()
        WatchAppIconView(size: 88, variant: .goldSolid).clipShape(Circle())
    }
}

#Preview("Variant B — Lighter navy (88pt)") {
    ZStack {
        Color.black.ignoresSafeArea()
        WatchAppIconView(size: 88, variant: .lighterNavy).clipShape(Circle())
    }
}

#Preview("Variant C — Radial glow (88pt)") {
    ZStack {
        Color.black.ignoresSafeArea()
        WatchAppIconView(size: 88, variant: .radialGlow).clipShape(Circle())
    }
}

// MARK: - Export utility (run from a dev-time button)

#if canImport(AppKit)
extension WatchAppIconView {
    /// Renders the given variant at 1024×1024 and writes the PNG to
    /// `~/Desktop/IqamahWatchIcons/icon_<variant>_1024x1024.png`.
    /// Call from a debug button or `IconExporterView`; not shipped in release builds.
    static func exportVariantToDesktop(_ variant: WatchIconVariant) {
        let view = WatchAppIconView(size: 1024, variant: variant)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(x: 0, y: 0, width: 1024, height: 1024)

        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else { return }
        bitmapRep.size = NSSize(width: 1024, height: 1024)
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

        guard let tiff = NSImage(size: NSSize(width: 1024, height: 1024)).pngFrom(rep: bitmapRep) else { return }

        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let dir = desktop.appendingPathComponent("IqamahWatchIcons")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("icon_\(variant.rawValue)_1024x1024.png")
        try? tiff.write(to: url)
        print("✅ Wrote \(url.path)")
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: dir.path)
    }

    /// Convenience: export all three variants in one call.
    static func exportAllVariantsToDesktop() {
        for variant in WatchIconVariant.allCases {
            exportVariantToDesktop(variant)
        }
    }
}

private extension NSImage {
    func pngFrom(rep: NSBitmapImageRep) -> Data? {
        rep.representation(using: .png, properties: [:])
    }
}
#endif // canImport(AppKit)
#endif // DEBUG
