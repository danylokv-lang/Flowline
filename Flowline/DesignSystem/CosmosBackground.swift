import SwiftUI

/// Full-screen animated star-field background used across all Flowline views.
///
/// Four particle layers + two nebula glows produce a vivid deep-space effect
/// while remaining entirely GPU-accelerated through Canvas + TimelineView.
/// Zero SwiftUI view overhead — no `@State`, no layout passes per particle.
struct CosmosBackground: View {

    // Accent purple (matches FlowLineTheme.accent #3b82f6)
    private let aR: Double = 0.427
    private let aG: Double = 0.298
    private let aB: Double = 0.980

    // Lavender highlight (matches FlowLineTheme.accentHi #60a5fa)
    private let lR: Double = 0.545
    private let lG: Double = 0.427
    private let lB: Double = 1.000

    var body: some View {
        ZStack {
            // ── Static nebula glows (zero animation cost) ──────────────────

            // Top-center glow (main)
            RadialGradient(
                colors: [
                    Color(red: aR, green: aG, blue: aB).opacity(0.28),
                    Color(red: lR, green: lG, blue: lB).opacity(0.10),
                    .clear
                ],
                center: .init(x: 0.50, y: 0.05),
                startRadius: 0,
                endRadius: 320
            )

            // Bottom-right corner aurora
            RadialGradient(
                colors: [
                    Color(red: aR, green: aG, blue: aB).opacity(0.18),
                    .clear
                ],
                center: .init(x: 0.88, y: 0.92),
                startRadius: 0,
                endRadius: 240
            )

            // ── Animated particle field at 30 fps ──────────────────────────
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate

                    // ── Layer 1: deep star field (70 tiny white stars) ──────
                    // Quasi-random positions via golden-ratio spacing.
                    // Very slow drift (±3 %) + per-star twinkle frequency.
                    for i in 0..<70 {
                        let fi = Double(i) * 2.6180339
                        let bx = sin(fi * 1.237) * 0.5 + 0.5
                        let by = cos(fi * 0.891) * 0.5 + 0.5
                        let x  = (bx + sin(fi * 0.413 + t * 0.007) * 0.030) * size.width
                        let y  = (by + cos(fi * 0.731 + t * 0.005) * 0.030) * size.height
                        let r  = 0.40 + fmod(fi * 0.19, 0.55)
                        // Twinkle — each star has its own frequency between 0.18 and 0.65 Hz
                        let tw = 0.13 + sin(fi * 4.71 + t * (0.18 + fmod(fi * 0.07, 0.47))) * 0.07
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(.white.opacity(max(0, tw)))
                        )
                    }

                    // ── Layer 2: mid-field accent drifters (28 purple) ──────
                    for i in 0..<28 {
                        let fi = Double(i) * 4.113 + 3.0
                        let x  = (sin(fi * 1.09 + t * 0.038) * 0.5 + 0.5) * size.width
                        let y  = (cos(fi * 0.83 + t * 0.028) * 0.5 + 0.5) * size.height
                        let r  = 1.00 + sin(fi * 2.3 + t * 0.14) * 0.70
                        let op = 0.22 + sin(fi * 1.71 + t * 0.19) * 0.10
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(Color(red: aR, green: aG, blue: aB).opacity(max(0, op)))
                        )
                    }

                    // ── Layer 3: bright foreground stars (12 large white) ───
                    for i in 0..<12 {
                        let fi = Double(i) * 7.231 + 1.5
                        let x  = (sin(fi * 0.713 + t * 0.018) * 0.5 + 0.5) * size.width
                        let y  = (cos(fi * 1.127 + t * 0.015) * 0.5 + 0.5) * size.height
                        let r  = 1.30 + sin(fi * 3.07 + t * 0.38) * 0.90
                        let op = 0.30 + sin(fi * 2.31 + t * 0.32) * 0.12
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(.white.opacity(max(0, op)))
                        )
                    }

                    // ── Layer 4: lavender sparkle orbs (9, slow + large) ────
                    for i in 0..<9 {
                        let fi = Double(i) * 11.317 + 5.5
                        let x  = (sin(fi * 0.531 + t * 0.022) * 0.5 + 0.5) * size.width
                        let y  = (cos(fi * 0.741 + t * 0.016) * 0.5 + 0.5) * size.height
                        let r  = 2.20 + sin(fi * 1.87 + t * 0.11) * 1.30
                        let op = 0.18 + sin(fi * 3.13 + t * 0.14) * 0.09
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(Color(red: lR, green: lG, blue: lB).opacity(max(0, op)))
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color(red: 0.031, green: 0.031, blue: 0.063)
            .ignoresSafeArea()
        CosmosBackground()
            .ignoresSafeArea()
    }
}
