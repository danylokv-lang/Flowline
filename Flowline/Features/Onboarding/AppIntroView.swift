import SwiftUI

// MARK: - Root View

struct AppIntroView: View {
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false
    @State private var page = 0

    private let accents: [Color] = [
        Color(hex: "#6d4cfa"),  // 0 Welcome
        Color(hex: "#8b6dff"),  // 1 Chat
        Color(hex: "#a78bfa"),  // 2 Calendar blocks
        Color(hex: "#3b82f6"),  // 3 Calendar sync
        Color(hex: "#f97316"),  // 4 Focus
        Color(hex: "#22c55e"),  // 5 Task inbox
        Color(hex: "#6d4cfa"),  // 6 Ready
    ]

    private var accent: Color { accents[page] }
    private var total: Int { accents.count }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Base background ────────────────────────────────────
                FlowLineTheme.mainBg.ignoresSafeArea()

                // ── Ambient glow that shifts with the page accent ──────
                RadialGradient(
                    colors: [accent.opacity(0.14), .clear],
                    center: .init(x: 0.5, y: 0.3),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.7
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.7), value: page)

                // ── Floating particle layer ────────────────────────────
                IntroParticles(accent: accent)
                    .ignoresSafeArea()

                // ── Page content ───────────────────────────────────────
                VStack(spacing: 0) {

                    // Dots
                    HStack(spacing: 8) {
                        ForEach(0..<total, id: \.self) { i in
                            Capsule()
                                .fill(i == page ? accent : FlowLineTheme.borderHi)
                                .frame(width: i == page ? 26 : 7, height: 7)
                                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: page)
                        }
                    }
                    .padding(.top, 32)

                    Spacer(minLength: 20)

                    // Visual card
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .fill(FlowLineTheme.secondBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 26)
                                    .stroke(
                                        LinearGradient(
                                            colors: [accent.opacity(0.3), accent.opacity(0.08)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: accent.opacity(0.15), radius: 40, y: 12)

                        pageVisual(for: page, geo: geo)
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                    }
                    .frame(height: geo.size.height * 0.40)
                    .padding(.horizontal, geo.size.width * 0.065)
                    .id("vis-\(page)")
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                    Spacer(minLength: 20)

                    // Text block
                    VStack(spacing: 10) {
                        Text(title(for: page))
                            .font(.system(size: clamp(geo.size.width * 0.058, lo: 24, hi: 36), weight: .black))
                            .foregroundColor(FlowLineTheme.mainTxt)
                            .multilineTextAlignment(.center)
                            .lineSpacing(1)

                        Text(subtitle(for: page))
                            .font(.system(size: clamp(geo.size.width * 0.026, lo: 13, hi: 16)))
                            .foregroundColor(FlowLineTheme.secondTxt)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: geo.size.width * 0.76)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, geo.size.width * 0.07)
                    .id("txt-\(page)")
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                    Spacer(minLength: 16)

                    // Nav
                    HStack(alignment: .center) {
                        if page > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.28)) { page -= 1 }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Back")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(FlowLineTheme.secondTxt)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button("Skip") {
                                withAnimation(.easeInOut(duration: 0.3)) { hasSeenIntro = true }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundColor(FlowLineTheme.dimTxt)
                        }

                        Spacer()

                        Button {
                            if page < total - 1 {
                                withAnimation(.easeInOut(duration: 0.28)) { page += 1 }
                            } else {
                                withAnimation(.easeInOut(duration: 0.3)) { hasSeenIntro = true }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(page == total - 1 ? "Get Started" : "Next")
                                    .font(.system(size: 15, weight: .bold))
                                Image(systemName: page == total - 1
                                      ? "arrow.right.circle.fill"
                                      : "chevron.right")
                                    .font(.system(size: page == total - 1 ? 16 : 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 26)
                            .padding(.vertical, 13)
                            .background(accent)
                            .clipShape(Capsule())
                            .shadow(color: accent.opacity(0.45), radius: 14, y: 5)
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.3), value: page)
                        .keyboardShortcut(.return, modifiers: [])
                    }
                    .padding(.horizontal, geo.size.width * 0.07)
                    .padding(.bottom, 36)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 560)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func pageVisual(for p: Int, geo: GeometryProxy) -> some View {
        switch p {
        case 0: IntroWelcomePage(accent: accent)
        case 1: IntroChatPage(accent: accent)
        case 2: IntroCalendarPage(accent: accent)
        case 3: IntroSyncPage(accent: accent)
        case 4: IntroFocusPage(accent: accent)
        case 5: IntroInboxPage(accent: accent)
        case 6: IntroReadyPage(accent: accent)
        default: EmptyView()
        }
    }

    private func title(for p: Int) -> String {
        switch p {
        case 0: return "Meet Flowline."
        case 1: return "Plan your day in seconds."
        case 2: return "See your whole day."
        case 3: return "Knows your full schedule."
        case 4: return "Focus. One block at a time."
        case 5: return "Capture. Never forget."
        case 6: return "You're ready."
        default: return ""
        }
    }

    private func subtitle(for p: Int) -> String {
        switch p {
        case 0: return "The AI-powered day planner that builds your entire schedule around your energy, goals, and real commitments — not just a to-do list."
        case 1: return "Describe your day to the AI in plain English. It knows your wake time, work hours, and calendar — and creates a full, realistic plan in one message."
        case 2: return "Every block is color-coded by category: Work, Health, Study, Personal. Tap any block to edit it, reorder it, or start a focus session right away."
        case 3: return "Flowline reads your Apple Calendar and Google Calendar automatically. Meetings, classes, and appointments are all visible to the AI — it plans around them without you lifting a finger."
        case 4: return "Tap any scheduled block to start a live countdown. The timer lives in your menu bar so it's always visible. Break reminders are built in to keep you sharp."
        case 5: return "Got a quick task or idea? Drop it in the inbox in one tap. When you ask the AI to plan your day, it pulls from your inbox and finds the right slot for everything."
        case 6: return "Create your account, tell the AI a bit about your routine, and your first smart plan is one message away. Takes under two minutes."
        default: return ""
        }
    }

    private func clamp(_ val: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
        min(hi, max(lo, val))
    }
}

// MARK: - Particle Background

private struct IntroParticles: View {
    let accent: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for i in 0..<28 {
                    let fi = Double(i)
                    let x = (sin(fi * 1.23 + t * 0.18) * 0.5 + 0.5) * size.width
                    let y = (cos(fi * 0.87 + t * 0.13) * 0.5 + 0.5) * size.height
                    let r  = 1.5 + sin(fi * 2.1 + t * 0.6) * 1.2
                    let op = 0.12 + sin(fi * 1.7 + t * 0.4) * 0.10
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: .color(accent.opacity(max(0, op)))
                    )
                }
            }
        }
    }
}

// MARK: - Page 0: Welcome

private struct IntroWelcomePage: View {
    let accent: Color
    @State private var pulse  = false
    @State private var appear = false

    var body: some View {
        ZStack {
            // Rings
            ForEach([80, 120, 160] as [CGFloat], id: \.self) { r in
                Circle()
                    .stroke(accent.opacity(pulse ? 0.08 : 0.04), lineWidth: 1)
                    .frame(width: r, height: r)
                    .scaleEffect(pulse ? 1.05 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(r) / 300),
                        value: pulse
                    )
            }

            VStack(spacing: 18) {
                // Logo
                ZStack {
                    Circle()
                        .fill(accent.opacity(pulse ? 0.18 : 0.10))
                        .frame(width: 88, height: 88)
                        .blur(radius: 12)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)

                    RoundedRectangle(cornerRadius: 22)
                        .fill(LinearGradient(
                            colors: [accent.opacity(0.3), accent.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(accent.opacity(0.4), lineWidth: 1)
                        )
                        .frame(width: 70, height: 70)

                    // Hex star
                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#c4b5fd"), accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(appear ? 1 : 0.7)
                .opacity(appear ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1), value: appear)

                VStack(spacing: 6) {
                    Text("Flowline")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(FlowLineTheme.mainTxt)

                    HStack(spacing: 8) {
                        Circle().fill(Color.green).frame(width: 7, height: 7)
                            .shadow(color: .green.opacity(0.6), radius: 4)
                        Text("AI Day Planner for Mac")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(FlowLineTheme.secondTxt)
                    }
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 10)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: appear)

                // Feature pills
                HStack(spacing: 8) {
                    ForEach(["AI Planning", "Focus Mode", "Calendar Sync"], id: \.self) { label in
                        Text(label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(accent.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(accent.opacity(0.25), lineWidth: 1))
                    }
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 14)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: appear)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { pulse = true; appear = true }
    }
}

// MARK: - Page 1: Chat

private struct IntroChatPage: View {
    let accent: Color
    @State private var shown = 0

    private let msgs: [(Bool, String)] = [
        (true,  "Plan my Tuesday — gym at 6pm, meetings until noon"),
        (false, "Got it! Here's your Tuesday:"),
        (false, "9:00 – 12:00 · Deep work sessions 💻"),
        (false, "12:30 – 1:00 · Lunch break 🥗"),
        (false, "2:00 – 4:00 · Admin & emails 📋"),
        (false, "6:00 – 7:00 · Gym 💪"),
        (false, "8:30 – 9:00 · Wind down 🌙"),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<min(shown, msgs.count), id: \.self) { i in
                    let (isUser, text) = msgs[i]
                    if isUser {
                        HStack {
                            Spacer()
                            Text(text)
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(accent)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: accent.opacity(0.3), radius: 6, y: 3)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 8) {
                            ZStack {
                                Circle().fill(accent.opacity(0.15)).frame(width: 26, height: 26)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(accent)
                            }
                            Text(text)
                                .font(.system(size: 12))
                                .foregroundColor(i == 1 ? FlowLineTheme.secondTxt : FlowLineTheme.mainTxt)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(FlowLineTheme.tertiaryBg)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            Spacer()
                        }
                    }
                }

                // Typing indicator
                if shown < msgs.count {
                    HStack(alignment: .top, spacing: 8) {
                        ZStack {
                            Circle().fill(accent.opacity(0.15)).frame(width: 26, height: 26)
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(accent)
                        }
                        TypingDots(accent: accent)
                        Spacer()
                    }
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { scheduleMessages() }
    }

    private func scheduleMessages() {
        shown = 0
        for i in 0..<msgs.count {
            let delay = Double(i) * 0.55 + 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { shown = i + 1 }
            }
        }
    }
}

private struct TypingDots: View {
    let accent: Color
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(accent.opacity(phase == i ? 0.8 : 0.25))
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == i ? 1.2 : 0.9)
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(FlowLineTheme.tertiaryBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Page 2: Calendar Blocks

private struct IntroCalendarPage: View {
    let accent: Color
    @State private var appeared = false

    private let blocks: [(String, String, String, Color)] = [
        ("sunrise",           "Morning Routine", "7:00 – 8:00",   Color(hex: "#f97316")),
        ("laptopcomputer",    "Deep Work",        "9:00 – 11:30",  Color(hex: "#6d4cfa")),
        ("fork.knife",        "Lunch",            "12:30 – 1:00",  Color(hex: "#22c55e")),
        ("book.closed",       "Study Block",      "2:00 – 3:30",   Color(hex: "#3b82f6")),
        ("figure.run",        "Gym",              "6:00 – 7:00",   Color(hex: "#22c55e")),
        ("moon.stars",        "Wind Down",        "9:00 – 9:30",   Color(hex: "#a78bfa")),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Day header
            HStack {
                Text("TUESDAY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(FlowLineTheme.dimTxt)
                    .kerning(1.5)
                Spacer()
                Text("6 blocks · 7.5h")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(FlowLineTheme.dimTxt)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Divider().background(FlowLineTheme.border)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 5) {
                    ForEach(blocks.indices, id: \.self) { i in
                        let b = blocks[i]
                        blockRow(icon: b.0, title: b.1, time: b.2, color: b.3)
                            .offset(x: appeared ? 0 : 50)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.72)
                                    .delay(Double(i) * 0.09),
                                value: appeared
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appeared = true }
    }

    private func blockRow(icon: String, title: String, time: String, color: Color) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 5)
                .padding(.vertical, 4)

            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FlowLineTheme.mainTxt)
                Text(time)
                    .font(.system(size: 11))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(color.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Page 3: Calendar Sync

private struct IntroSyncPage: View {
    let accent: Color
    @State private var appeared   = false
    @State private var flowPhase  = 0.0
    @State private var eventIn    = false

    var body: some View {
        VStack(spacing: 20) {
            // Main flow diagram
            HStack(spacing: 0) {
                // Sources
                VStack(spacing: 12) {
                    calSource(
                        icon: AnyView(Image(systemName: "calendar").font(.system(size: 22)).foregroundColor(.red)),
                        bg: Color.red.opacity(0.12), border: Color.red.opacity(0.3),
                        label: "Apple Calendar"
                    )
                    calSource(
                        icon: AnyView(Text("G").font(.system(size: 20, weight: .bold)).foregroundStyle(LinearGradient(colors: [.blue, .red], startPoint: .topLeading, endPoint: .bottomTrailing))),
                        bg: Color.blue.opacity(0.1), border: Color.blue.opacity(0.25),
                        label: "Google Calendar"
                    )
                }
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : -20)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)

                // Animated flow line
                FlowArrow(phase: flowPhase, accent: accent)
                    .frame(maxWidth: .infinity)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.4), value: appeared)

                // Flowline AI
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(appeared ? 0.18 : 0.08))
                            .frame(width: 70, height: 70)
                            .blur(radius: 8)
                            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: appeared)

                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(
                                colors: [accent.opacity(0.28), accent.opacity(0.12)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.4), lineWidth: 1))
                            .frame(width: 56, height: 56)

                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(accent)
                    }
                    Text("Flowline AI")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(FlowLineTheme.secondTxt)
                }
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: appeared)
            }
            .padding(.horizontal, 24)

            // Incoming events strip
            VStack(spacing: 6) {
                Text("Events AI can see")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(FlowLineTheme.dimTxt)
                    .kerning(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(["📅 Team standup · Mon 10:00", "📅 Doctor appt · Tue 3:00 PM", "📅 Birthday dinner · Fri 7 PM"].indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        Text(["📅 Team standup · Mon 10:00", "📅 Doctor appt · Tue 3:00 PM", "📅 Birthday dinner · Fri 7 PM"][i])
                            .font(.system(size: 12))
                            .foregroundColor(FlowLineTheme.mainTxt)
                        Spacer()
                        Text("Protected")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(FlowLineTheme.tertiaryBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .opacity(eventIn ? 1 : 0)
                    .offset(y: eventIn ? 0 : 12)
                    .animation(.spring(response: 0.5).delay(0.6 + Double(i) * 0.12), value: eventIn)
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            appeared = true
            eventIn  = true
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                flowPhase = 1
            }
        }
    }

    private func calSource(icon: AnyView, bg: Color, border: Color, label: String) -> some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(bg)
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(border, lineWidth: 1))
                    .frame(width: 48, height: 48)
                icon
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(FlowLineTheme.secondTxt)
                .multilineTextAlignment(.center)
                .frame(width: 60)
        }
    }
}

private struct FlowArrow: View {
    var phase: Double
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Dashed base line
                Path { p in
                    p.move(to: .init(x: 10, y: h / 2))
                    p.addLine(to: .init(x: w - 10, y: h / 2))
                }
                .stroke(
                    accent.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                )

                // Animated travelling dot
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: accent.opacity(0.6), radius: 4)
                    .position(x: 10 + (w - 20) * phase, y: h / 2)
                    .animation(.linear(duration: 1.6).repeatForever(autoreverses: false), value: phase)

                // Arrow head
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accent.opacity(0.6))
                    .position(x: w - 8, y: h / 2)
            }
        }
    }
}

// MARK: - Page 4: Focus

private struct IntroFocusPage: View {
    let accent: Color
    @State private var progress: CGFloat = 0
    @State private var pulse             = false
    @State private var appeared          = false

    var body: some View {
        VStack(spacing: 20) {
            // Timer ring
            ZStack {
                // Outer glow
                Circle()
                    .fill(accent.opacity(pulse ? 0.12 : 0.06))
                    .frame(width: 140, height: 140)
                    .blur(radius: 14)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)

                // Track
                Circle()
                    .stroke(FlowLineTheme.tertiaryBg, lineWidth: 12)
                    .frame(width: 116, height: 116)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [accent.opacity(0.5), accent, Color(hex: "#c4b5fd")],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 116, height: 116)
                    .animation(.easeOut(duration: 1.4).delay(0.2), value: progress)

                // Time display
                VStack(spacing: 3) {
                    Text("28:47")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(FlowLineTheme.mainTxt)
                    Text("DEEP WORK")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(accent)
                        .kerning(1.5)
                }
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)

            // Info strips
            VStack(spacing: 8) {
                infoRow(icon: "timer", label: "Menu bar countdown", detail: "Always visible")
                infoRow(icon: "bell.badge", label: "Break reminder", detail: "After 90 min")
                infoRow(icon: "checkmark.circle", label: "Auto-complete block", detail: "On timer end")
            }
            .padding(.horizontal, 20)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.easeOut(duration: 0.5).delay(0.45), value: appeared)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            pulse    = true
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                progress = 0.68
            }
        }
    }

    private func infoRow(icon: String, label: String, detail: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(accent.opacity(0.12)).frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(accent)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(FlowLineTheme.mainTxt)
            Spacer()
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(FlowLineTheme.secondTxt)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(FlowLineTheme.tertiaryBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Page 5: Task Inbox

private struct IntroInboxPage: View {
    let accent: Color
    @State private var appeared = false

    private let tasks: [(String, String, String)] = [
        ("doc.text",        "Write project proposal",  "Work"),
        ("figure.run",      "Book gym session",        "Health"),
        ("book.closed",     "Finish chapter 4",        "Study"),
        ("cart",            "Grocery run",             "Personal"),
        ("envelope",        "Reply to emails",         "Work"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Inbox", systemImage: "tray.full")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(FlowLineTheme.mainTxt)
                Spacer()
                Text("\(tasks.count) tasks")
                    .font(.system(size: 11))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Divider().background(FlowLineTheme.border)

            VStack(spacing: 5) {
                ForEach(tasks.indices, id: \.self) { i in
                    let t = tasks[i]
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(accent.opacity(0.12)).frame(width: 28, height: 28)
                            Image(systemName: t.0)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(accent)
                        }
                        Text(t.1)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(FlowLineTheme.mainTxt)
                        Spacer()
                        Text(t.2)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(accent.opacity(0.8))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(FlowLineTheme.tertiaryBg.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .offset(x: appeared ? 0 : 40)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.72)
                            .delay(Double(i) * 0.09),
                        value: appeared
                    )
                }
            }
            .padding(12)

            // Add task bar
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(accent)
                Text("Add to inbox...")
                    .font(.system(size: 12))
                    .foregroundColor(FlowLineTheme.dimTxt)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(FlowLineTheme.tertiaryBg)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.55), value: appeared)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appeared = true }
    }
}

// MARK: - Page 6: Ready

private struct IntroReadyPage: View {
    let accent: Color
    @State private var appeared   = false
    @State private var sparkPhase = false

    private let steps = [
        ("person.crop.circle.badge.plus", "Create your account"),
        ("text.badge.checkmark",          "Set up your profile — takes 1 min"),
        ("sparkles",                       "Ask AI to plan your first day"),
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Celebration icon
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    let angle = Double(i) * 60.0
                    let r: CGFloat = sparkPhase ? 52 : 20
                    Circle()
                        .fill(accent.opacity(sparkPhase ? 0 : 0.7))
                        .frame(width: 8, height: 8)
                        .offset(
                            x: r * cos(angle * .pi / 180),
                            y: r * sin(angle * .pi / 180)
                        )
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.5)
                                .delay(Double(i) * 0.06),
                            value: sparkPhase
                        )
                }

                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(accent)
                }
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.1), value: appeared)
            }

            // Steps
            VStack(spacing: 10) {
                ForEach(steps.indices, id: \.self) { i in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Text("\(i + 1)")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(accent)
                        }

                        Image(systemName: steps[i].0)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(accent.opacity(0.7))
                            .frame(width: 20)

                        Text(steps[i].1)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(FlowLineTheme.mainTxt)

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(accent.opacity(0.35))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(accent.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.12), lineWidth: 1))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.5).delay(0.2 + Double(i) * 0.12), value: appeared)
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { sparkPhase = true }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AppIntroView()
}
