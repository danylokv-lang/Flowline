import SwiftUI
import Combine

// MARK: - CelebrationManager
//
// Lightweight singleton that drives confetti bursts from anywhere in the app.
// Usage: CelebrationManager.shared.triggerConfetti()
// Mount the overlay once at the root: someView.withCelebrations()

@MainActor
final class CelebrationManager: ObservableObject {
    static let shared = CelebrationManager()

    /// Changing this UUID triggers a fresh confetti burst in the overlay.
    @Published private(set) var confettiID: UUID? = nil

    private init() {}

    /// Fire a confetti burst. Each call starts a new independent burst.
    func triggerConfetti() {
        confettiID = UUID()
    }
}

// MARK: - Confetti Particle (immutable, pre-generated at launch)

private struct ConfettiParticle {
    let x: CGFloat       // 0–1 normalised start-x across canvas width
    let vx: CGFloat      // px/s horizontal drift
    let vy: CGFloat      // px/s initial vertical (negative = upward)
    let color: Color
    let w: CGFloat       // rectangle width
    let h: CGFloat       // rectangle height
    let spin: CGFloat    // radians/s rotation
    let phase: CGFloat   // initial rotation offset
}

// MARK: - Confetti Overlay View
//
// Full-screen Canvas overlay, rendered at 60 fps for ~2.8 s then self-removes.
// allowsHitTesting(false) so it never blocks taps.

struct ConfettiOverlay: View {
    let id: UUID

    @State private var startDate = Date()
    @State private var isDone = false

    // Particles are generated once (deterministic) and shared across all bursts.
    private static let particles: [ConfettiParticle] = {
        let palette: [Color] = [
            Color(hex: "#a78bfa"), Color(hex: "#818cf8"), Color(hex: "#c4b5fd"),
            Color(hex: "#34d399"), Color(hex: "#6ee7b7"),
            Color(hex: "#fbbf24"), Color(hex: "#fde68a"),
            Color(hex: "#f87171"), Color(hex: "#38bdf8"),
            Color(hex: "#fb923c"), Color(hex: "#e879f9"), .white
        ]
        var rng = SystemRandomNumberGenerator()
        return (0..<70).map { _ in
            ConfettiParticle(
                x:     .random(in: 0.05...0.95, using: &rng),
                vx:    .random(in: -100...100,  using: &rng),
                vy:    .random(in: -800...(-200), using: &rng),
                color: palette.randomElement(using: &rng)!,
                w:     .random(in: 5...10,       using: &rng),
                h:     .random(in: 9...17,       using: &rng),
                spin:  .random(in: -8...8,       using: &rng),
                phase: .random(in: 0...(.pi * 2), using: &rng)
            )
        }
    }()

    var body: some View {
        if !isDone {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                Canvas { ctx, size in
                    let t       = CGFloat(tl.date.timeIntervalSince(startDate))
                    let gravity: CGFloat = 500

                    for p in Self.particles {
                        let x = p.x * size.width + p.vx * t
                        let y = size.height * 0.55 + p.vy * t + 0.5 * gravity * t * t

                        // Fade out in the last second
                        let alpha = t < 1.8
                            ? 1.0
                            : Double(max(0, 1.0 - (t - 1.8) / 1.0))
                        guard alpha > 0.01 else { continue }

                        let rot = p.phase + p.spin * t

                        var copy = ctx
                        copy.opacity   = alpha
                        copy.transform = CGAffineTransform(translationX: x, y: y)
                            .rotated(by: rot)
                        copy.fill(
                            Path(CGRect(x: -p.w / 2, y: -p.h / 2,
                                        width: p.w,  height: p.h)),
                            with: .color(p.color)
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .task {
                try? await Task.sleep(for: .seconds(2.8))
                isDone = true
            }
        }
    }
}

// MARK: - View Modifier

private struct CelebrationModifier: ViewModifier {
    @ObservedObject private var manager = CelebrationManager.shared

    func body(content: Content) -> some View {
        ZStack {
            content
            if let cid = manager.confettiID {
                ConfettiOverlay(id: cid)
                    .id(cid)     // re-create on every new burst
                    .zIndex(999)
            }
        }
    }
}

extension View {
    /// Mount once at the root view to enable app-wide confetti celebrations.
    func withCelebrations() -> some View {
        modifier(CelebrationModifier())
    }
}
