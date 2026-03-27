import SwiftUI

// MARK: - App Intro (single welcome screen, replaces 7-page carousel)

struct AppIntroView: View {
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    // Staggered entrance animation
    @State private var showLogo      = false
    @State private var showHeadline  = false
    @State private var showProps     = false
    @State private var showCTA       = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FlowLineTheme.mainBg.ignoresSafeArea()
                CosmosBackground().ignoresSafeArea()

                // Purple ambient glow
                RadialGradient(
                    colors: [FlowLineTheme.accent.opacity(0.25), .clear],
                    center: .init(x: 0.5, y: 0.25),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.9
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // ── Logo ─────────────────────────────────────────────
                    VStack(spacing: 6) {
                        Text("✦")
                            .font(.system(size: 36))
                            .foregroundColor(FlowLineTheme.accent)

                        Text("FLOWLINE")
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(8)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#c4b5fd"), FlowLineTheme.accentHi],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                    }
                    .opacity(showLogo ? 1 : 0)
                    .offset(y: showLogo ? 0 : 16)

                    Spacer().frame(height: 32)

                    // ── Headline ─────────────────────────────────────────
                    VStack(spacing: 10) {
                        Text("Plan your day\nwith AI.")
                            .font(.system(size: min(geo.size.width * 0.115, 44), weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [FlowLineTheme.mainTxt, Color(hex: "#c4b5fd")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)

                        Text("Tell Flowline what you need. Get a full\ntime-blocked day in seconds.")
                            .font(.system(size: 15))
                            .foregroundColor(FlowLineTheme.secondTxt)
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                    }
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 16)

                    Spacer().frame(height: 40)

                    // ── Value props ──────────────────────────────────────
                    VStack(spacing: 12) {
                        valueProp(
                            icon: "sparkles",
                            color: FlowLineTheme.accent,
                            title: "Chat to plan",
                            body: "Describe your day — AI builds a time-blocked schedule instantly"
                        )
                        valueProp(
                            icon: "calendar.badge.checkmark",
                            color: Color(hex: "#3b82f6"),
                            title: "Syncs to your calendar",
                            body: "Save your plan to Apple or Google Calendar with one tap"
                        )
                        valueProp(
                            icon: "flame.fill",
                            color: Color(hex: "#f97316"),
                            title: "Build a streak",
                            body: "Plan daily, track progress, and see your habits grow over time"
                        )
                    }
                    .padding(.horizontal, 28)
                    .opacity(showProps ? 1 : 0)
                    .offset(y: showProps ? 0 : 20)

                    Spacer()

                    // ── CTA ───────────────────────────────────────────────
                    Button {
                        withAnimation(.easeOut(duration: 0.35)) { hasSeenIntro = true }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Get Started")
                                .font(.system(size: 17, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(
                                colors: [FlowLineTheme.accent, Color(hex: "#8b6dff")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: FlowLineTheme.accent.opacity(0.5), radius: 18, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .opacity(showCTA ? 1 : 0)
                    .offset(y: showCTA ? 0 : 10)

                    Text("By continuing you agree to our Privacy Policy & Terms")
                        .font(.system(size: 11))
                        .foregroundColor(FlowLineTheme.dimTxt)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 20))
                        .opacity(showCTA ? 1 : 0)
                }
            }
        }
        .onAppear { startAnimations() }
    }

    // MARK: Value prop row

    private func valueProp(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(FlowLineTheme.mainTxt)
                Text(body)
                    .font(.system(size: 12))
                    .foregroundColor(FlowLineTheme.secondTxt)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(13)
        .background(FlowLineTheme.tertiaryBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FlowLineTheme.borderHi, lineWidth: 1)
        )
    }

    // MARK: Staggered entrance

    private func startAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { showLogo = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) { showHeadline = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.55)) { showProps = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.75)) { showCTA = true }
    }
}

// MARK: - Helper (clamp) — kept for any internal usage

private func clamp(_ value: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
    min(max(value, lo), hi)
}
