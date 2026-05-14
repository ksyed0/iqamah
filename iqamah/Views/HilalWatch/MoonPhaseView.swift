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

            // Crescent via Path.subtracting (iOS 17+ / macOS 14+).
            //
            // The shadow circle starts perfectly centered on the disc (new moon = 0 % lit)
            // and moves sideways until it no longer overlaps (full moon = 100 % lit).
            // disc.subtracting(shadow) = the lit portion inside the disc.
            //
            //   Waxing (phase 0 → 0.5): shadow moves LEFT → exposes right crescent
            //   Waning (phase 0.5 → 1): shadow moves RIGHT → exposes left crescent
            let shadowX: CGFloat = if phase < 0.5 {
                -2 * r * CGFloat(2 * phase) // 0 at new → -2r at full
            } else {
                2 * r * CGFloat(2 - 2 * phase) // +2r at full → 0 at new
            }

            let shadowRect = CGRect(x: cx - r + shadowX, y: cy - r, width: r * 2, height: r * 2)
            let shadow = Path(ellipseIn: shadowRect)
            let crescentPath = disc.subtracting(shadow)

            ctx.fill(crescentPath, with: .color(.yellow.opacity(0.9)))
        }
        .frame(width: size, height: size)
        .background(Color.black.opacity(0.3), in: Circle())
    }
}
