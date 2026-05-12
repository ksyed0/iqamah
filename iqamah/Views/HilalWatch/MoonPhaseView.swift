import SwiftUI
import IqamahCore

/// Renders a crescent moon using SwiftUI Canvas.
/// `phase` is the synodic phase fraction [0=new, 0.5=full, 1=new again].
struct MoonPhaseView: View {
    let phase: Double // 0–1
    let size: CGFloat

    var body: some View {
        Canvas { ctx, canvasSize in
            let r = min(canvasSize.width, canvasSize.height) / 2 - 2
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2
            let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)

            // Full disc — faint white tint so the circle reads as the moon body
            let disc = Path(ellipseIn: rect)
            ctx.fill(disc, with: .color(.white.opacity(0.15)))

            // Crescent via Path boolean subtraction (iOS 17+ / macOS 14+).
            // No blend modes needed — geometrically correct on all display scales.
            let illumination = abs(phase - 0.5) * 2 // 0 = full moon, 1 = new moon
            let xOffset = (1.0 - illumination * 2) * r
            let shadowRect = CGRect(x: cx - r + xOffset, y: cy - r, width: r * 2, height: r * 2)
            let shadow = Path(ellipseIn: shadowRect)

            let crescentPath: Path
            if phase < 0.5 {
                // Waxing — lit on right: disc minus shadow leaves right crescent
                crescentPath = disc.subtracting(shadow)
            } else {
                // Waning — lit on left: shadow minus disc leaves left crescent
                crescentPath = shadow.subtracting(disc)
            }
            ctx.fill(crescentPath, with: .color(.yellow.opacity(0.9)))
        }
        .frame(width: size, height: size)
        .background(Color.black.opacity(0.3), in: Circle())
    }
}
