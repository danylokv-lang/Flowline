import SwiftUI
import SwiftData

// MARK: - Streak color helpers

/// Returns the base hue for a given streak day.
/// Day 1 = red-orange (0.03), Day 7 = blue (0.62), Day 14+ = violet (0.78)
private func streakHue(for streak: Int) -> Double {
    if streak <= 7 {
        let t = Double(streak - 1) / 6.0          // 0…1
        return 0.03 + t * 0.59                     // 0.03 → 0.62
    } else {
        let t = min(Double(streak - 7) / 7.0, 1.0) // 0…1
        return 0.62 + t * 0.16                     // 0.62 → 0.78
    }
}

/// Particle size multiplier — tiny at day 1, full at day 7
private func streakSizeScale(for streak: Int) -> Double {
    0.45 + min(Double(streak - 1) / 6.0, 1.0) * 0.55   // 0.45 → 1.0
}

// MARK: - Animated Fire View

private struct FireParticle {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var life: Double
    var decay: Double
    var size: Double
    var hue: Double
}

private struct AnimatedFireView: View {
    let streak: Int

    private let w: Double = 36
    private let h: Double = 44

    @State private var particles: [FireParticle] = []
    @State private var frame: Double = 0

    // Base hue for this streak level
    private var baseHue: Double { streakHue(for: streak) }
    // How wide the hue spread is (fire has orange spread; ice/violet is narrower)
    private var hueSpread: Double {
        streak <= 3 ? 0.10 : (streak <= 7 ? 0.08 : 0.06)
    }
    private var sizeScale: Double { streakSizeScale(for: streak) }
    // Spawn more particles as streak grows
    private var spawnCount: Int { max(2, Int(sizeScale * 5)) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            Canvas { context, _ in
                for p in particles {
                    let alpha = p.life * p.life
                    let r     = p.size * p.life
                    guard r > 0.3 else { continue }
                    // as particle rises (life drops) it shifts toward the pure base hue
                    let hue = p.hue + (baseHue - p.hue) * (1.0 - p.life) * 0.5
                    let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                    // 3 glow layers
                    for i in 0..<3 {
                        let expand    = r * (0.55 * Double(i))
                        let glowRect  = rect.insetBy(dx: -expand, dy: -expand)
                        let glowAlpha = alpha * (0.40 - Double(i) * 0.12)
                        context.fill(
                            Path(ellipseIn: glowRect),
                            with: .color(Color(hue: hue, saturation: 1, brightness: 1).opacity(glowAlpha))
                        )
                    }
                    // solid core
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color(hue: hue, saturation: 1, brightness: 1).opacity(alpha * 0.9))
                    )
                }
            }
            .frame(width: w, height: h)
            .onChange(of: ctx.date) {
                frame += 1
                stepSimulation()
            }
        }
    }

    // MARK: - Simulation

    private func stepSimulation() {
        var next = particles

        let n = spawnCount + Int(rng(frame * 0.01) * 2)
        for i in 0..<n {
            let ix     = Double(i)
            let spread = (rng(frame * 0.11 + ix * 13.7) - 0.5) * (10.0 * sizeScale)
            // hue near baseHue ± hueSpread/2
            let particleHue = baseHue - hueSpread * 0.5 + rng(frame * 0.61 + ix * 11.1) * hueSpread
            next.append(FireParticle(
                x:     w * 0.5 + spread,
                y:     h * 0.90,
                vx:    (rng(frame * 0.31 + ix * 3.1) - 0.5) * 1.4,
                vy:    -(2.5 + rng(frame * 0.41 + ix * 9.7) * 3.0) * sizeScale,
                life:  1.0,
                decay: 0.030 + rng(frame * 0.51 + ix * 5.5) * 0.030,
                size:  (3.0 + rng(frame * 0.21 + ix * 7.3) * 5.0) * sizeScale,
                hue:   particleHue
            ))
        }

        var alive: [FireParticle] = []
        alive.reserveCapacity(next.count)
        for var p in next {
            p.life -= p.decay
            guard p.life > 0 else { continue }
            p.vx += (rng(p.x * 0.29 + p.y * 0.73 + frame) - 0.5) * 0.35
            p.x  += p.vx
            p.y  += p.vy * (1.0 / 30.0) * 18.0
            alive.append(p)
        }

        let cap = 60 + spawnCount * 14
        if alive.count > cap { alive.removeFirst(alive.count - cap) }
        particles = alive
    }

    // MARK: - RNG

    private func rng(_ n: Double) -> Double {
        let x = sin(n * 127.1 + frame * 311.7) * 43758.5453
        return x - floor(x)
    }
}

// MARK: - Toast background / shadow helpers

/// Background gradient colors for the toast, keyed to the streak color
private func toastBgColors(streak: Int) -> [Color] {
    let h = streakHue(for: streak)
    return [
        Color(hue: h, saturation: 0.90, brightness: 0.08),
        Color(hue: h, saturation: 0.95, brightness: 0.18),
        Color(hue: h, saturation: 1.00, brightness: 0.65)
    ]
}

private func toastGlowColor(streak: Int) -> Color {
    Color(hue: streakHue(for: streak), saturation: 1, brightness: 1)
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showStreakToast = false
    @Environment(\.openSettings) private var openSettings

    @Query(filter: #Predicate<CapturedTask> { !$0.isScheduled })
    private var pendingTasks: [CapturedTask]
    private var pendingCount: Int { pendingTasks.count }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                PlanningChatView(selectedTab: $selectedTab)
                    .tabItem { Label("Plan", systemImage: "sparkles") }
                    .tag(0)

                CalendarView()
                    .tabItem { Label("Week", systemImage: "calendar") }
                    .tag(1)

                FocusTimerView()
                    .tabItem { Label("Focus", systemImage: "timer") }
                    .help("Run a focus timer for any block from your daily plan")
                    .tag(2)

                TaskInboxView()
                    .tabItem { Label("Inbox", systemImage: "tray.full") }
                    .badge(pendingCount > 0 ? pendingCount : 0)
                    .help("Capture tasks here — the AI will slot them into your plan when you ask")
                    .tag(3)
            }
            .tint(FlowLineTheme.accent)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button { openSettings() } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(FlowLineTheme.secondTxt)
                    }
                    .help("Settings  ⌘,")
                }
            }

            // ── Streak launch toast ────────────────────────────────────────
            if showStreakToast {
                streakToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showStreakToast = true
                }
                // Auto-dismiss after 6s if user doesn't tap
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showStreakToast = false
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showStreakToast)
    }

    private var streakToast: some View {
        let raw    = StreakManager.shared.currentStreak
        let streak = max(raw, 1)                              // always at least day 1
        let glow   = toastGlowColor(streak: streak)
        let fireW  = 28.0 + streakSizeScale(for: streak) * 12.0
        let fireH  = fireW * (44.0 / 36.0)

        let title    = raw == 0 ? "Start your streak today!" : "\(streak)-day streak"
        let subtitle = raw == 0 ? "Build a habit — plan your first day"
                                : "Keep the momentum going today"

        return HStack(spacing: 4) {
            AnimatedFireView(streak: streak)
                .frame(width: fireW, height: fireH)
                .clipped()

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer(minLength: 8)

            // Tap to dismiss
            Button {
                withAnimation(.easeOut(duration: 0.25)) { showStreakToast = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(5)
                    .background(Circle().fill(.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: toastBgColors(streak: streak),
                startPoint: .leading, endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(glow.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: glow.opacity(0.55), radius: 14, x: 0, y: 4)
        .shadow(color: glow.opacity(0.28), radius: 5,  x: 0, y: 2)
        .padding(.top, 8)
    }
}

// MARK: - Previews

#Preview {
    MainTabView()
}

#Preview("Fire — all streak levels") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach([1, 2, 3, 4, 5, 6, 7, 9, 12, 14], id: \.self) { day in
                let glow  = toastGlowColor(streak: day)
                let fireW = 28.0 + streakSizeScale(for: day) * 12.0
                let fireH = fireW * (44.0 / 36.0)
                HStack(spacing: 4) {
                    AnimatedFireView(streak: day)
                        .frame(width: fireW, height: fireH)
                        .clipped()
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Day \(day) streak")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.white)
                        Text("Keep the momentum going today")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .padding(.leading, 6)
                .padding(.trailing, 18)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: toastBgColors(streak: day),
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(glow.opacity(0.65), lineWidth: 1)
                )
                .shadow(color: glow.opacity(0.50), radius: 12, x: 0, y: 3)
            }
        }
        .padding(20)
    }
    .background(Color(hex: "#0d0d14").ignoresSafeArea())
    .frame(width: 380, height: 620)
}
