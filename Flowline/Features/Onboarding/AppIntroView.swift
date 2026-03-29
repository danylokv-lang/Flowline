import SwiftUI

// MARK: - App Intro (3-page swipeable onboarding)

private struct IntroPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let features: [(icon: String, color: String, text: String)]
}

struct AppIntroView: View {
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false
    @State private var page = 0

    private let pages: [IntroPage] = [
        IntroPage(
            icon: "sparkles",
            iconColor: Color(hex: "#3b82f6"),
            title: "Plan your day\nwith AI.",
            subtitle: "Tell Flowline what you need. Get a full time-blocked schedule in seconds.",
            features: [
                ("message.fill",       "#3b82f6", "Chat with AI to build your day"),
                ("calendar.badge.checkmark", "#3b82f6", "Save plans to Flowline Calendar"),
                ("arrow.trianglehead.2.counterclockwise.rotate.90", "#2ecc71", "Replan anytime in seconds")
            ]
        ),
        IntroPage(
            icon: "timer",
            iconColor: Color(hex: "#ec4899"),
            title: "Stay focused\nand on track.",
            subtitle: "Use the built-in focus timer and track your sessions — know exactly where your time goes.",
            features: [
                ("timer",         "#ec4899", "Focus timer with break reminders"),
                ("flame.fill",    "#f97316", "Daily streaks to build habits"),
                ("chart.bar.fill","#f59e0b", "Weekly stats and insights")
            ]
        ),
        IntroPage(
            icon: "calendar",
            iconColor: Color(hex: "#3b82f6"),
            title: "Your schedule,\neverywhere.",
            subtitle: "Sync plans to Apple or Google Calendar. Add a widget to your home screen for instant access.",
            features: [
                ("calendar",        "#3b82f6", "Sync to Apple & Google Calendar"),
                ("square.grid.2x2", "#2ecc71", "Home & lock screen widgets"),
                ("lock.fill",       "#3b82f6", "3 free plans/week — upgrade for unlimited")
            ]
        )
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FlowLineTheme.mainBg.ignoresSafeArea()
                CosmosBackground().ignoresSafeArea()

                RadialGradient(
                    colors: [pages[page].iconColor.opacity(0.08), .clear],
                    center: .init(x: 0.5, y: 0.2),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.9
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: page)

                VStack(spacing: 0) {
                    // Page dots
                    HStack(spacing: 6) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            Capsule()
                                .fill(i == page ? pages[page].iconColor : Color.white.opacity(0.2))
                                .frame(width: i == page ? 20 : 6, height: 6)
                                .animation(.spring(response: 0.3), value: page)
                        }
                    }
                    .padding(.top, max(geo.safeAreaInsets.top, 20) + 12)
                    .padding(.bottom, 24)

                    // Swipeable pages
                    TabView(selection: $page) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, p in
                            pageContent(p, geo: geo)
                                .tag(index)
                        }
                    }
                    #if os(iOS)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    #endif
                    .animation(.easeInOut, value: page)

                    // CTA
                    VStack(spacing: 12) {
                        Button {
                            if page < pages.count - 1 {
                                withAnimation(.spring(response: 0.4)) { page += 1 }
                            } else {
                                withAnimation(.easeOut(duration: 0.35)) { hasSeenIntro = true }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(page < pages.count - 1 ? "Next" : "Get Started")
                                    .font(.system(size: 17, weight: .bold))
                                Image(systemName: page < pages.count - 1 ? "arrow.right" : "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(FlowLineTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        if page < pages.count - 1 {
                            Button {
                                withAnimation(.easeOut(duration: 0.35)) { hasSeenIntro = true }
                            } label: {
                                Text("Skip")
                                    .font(.system(size: 13))
                                    .foregroundColor(FlowLineTheme.dimTxt)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("By continuing you agree to our Privacy Policy & Terms")
                                .font(.system(size: 11))
                                .foregroundColor(FlowLineTheme.dimTxt)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 20) + 8)
                }
            }
        }
    }

    private func pageContent(_ p: IntroPage, geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Icon
            ZStack {
                Circle()
                    .fill(p.iconColor.opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: p.icon)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(p.iconColor)
            }
            .padding(.bottom, 24)

            // Title
            Text(p.title)
                .font(.system(size: min(geo.size.width * 0.105, 40), weight: .black))
                .foregroundColor(FlowLineTheme.mainTxt)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.bottom, 12)

            // Subtitle
            Text(p.subtitle)
                .font(.system(size: 15))
                .foregroundColor(FlowLineTheme.secondTxt)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
                .padding(.bottom, 28)

            // Feature rows
            VStack(spacing: 0) {
                ForEach(p.features, id: \.text) { f in
                    HStack(spacing: 14) {
                        Rectangle()
                            .fill(FlowLineTheme.accent)
                            .frame(width: 2, height: 28)
                            .clipShape(Capsule())
                        Image(systemName: f.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(FlowLineTheme.accent)
                            .frame(width: 18)
                        Text(f.text)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(FlowLineTheme.mainTxt)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .overlay(Rectangle().fill(FlowLineTheme.border).frame(height: 1), alignment: .bottom)
                }
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .padding(.top, 8)
    }
}
