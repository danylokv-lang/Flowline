import SwiftUI

// MARK: - Widget Education Card

/// Shown once after the user's first successful plan.
/// Teaches them about home/lock screen widgets and gives a step-by-step CTA.
struct WidgetEducationCard: View {
    @AppStorage("hasSeenWidgetPromo") private var hasSeen = false
    @ObservedObject private var streak = StreakManager.shared
    @State private var showHowTo = false

    private var shouldShow: Bool {
        !hasSeen && streak.totalPlansCreated >= 1
    }

    var body: some View {
        if shouldShow {
            cardContent
                .transition(.move(edge: .top).combined(with: .opacity))
                .sheet(isPresented: $showHowTo) {
                    WidgetHowToSheet()
                }
        }
    }

    // MARK: Card

    private var cardContent: some View {
        HStack(alignment: .top, spacing: 14) {
            // Mini widget preview
            widgetPreview

            // Text + actions
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("HOME SCREEN WIDGET")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(FlowLineTheme.accent)
                        .tracking(0.6)
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { hasSeen = true }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(FlowLineTheme.secondTxt.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }

                Text("See your schedule without opening the app")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FlowLineTheme.mainTxt)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Your plan is ready — put it on your home or lock screen so you always know what's next.")
                    .font(.system(size: 12))
                    .foregroundColor(FlowLineTheme.secondTxt)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        showHowTo = true
                    } label: {
                        HStack(spacing: 5) {
                            Text("Show me how")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(FlowLineTheme.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { hasSeen = true }
                    } label: {
                        Text("Not now")
                            .font(.system(size: 12))
                            .foregroundColor(FlowLineTheme.secondTxt)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(FlowLineTheme.tertiaryBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [FlowLineTheme.accent.opacity(0.5), FlowLineTheme.accent.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: Mini widget preview illustration

    private var widgetPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: "#1a1a2e"))
                .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 3) {
                // "NOW" badge
                HStack(spacing: 3) {
                    Circle()
                        .fill(FlowLineTheme.accent)
                        .frame(width: 5, height: 5)
                    Text("NOW")
                        .font(.system(size: 6, weight: .heavy))
                        .foregroundColor(FlowLineTheme.accent)
                        .tracking(0.5)
                }

                // Fake block title
                Text("Deep Work")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Fake time range
                Text("09:00 – 11:00")
                    .font(.system(size: 6))
                    .foregroundColor(.white.opacity(0.5))

                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 2)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(FlowLineTheme.accent.opacity(0.8))
                            .frame(width: geo.size.width * 0.55, height: 2)
                    }
                }
                .frame(height: 2)
                .padding(.top, 2)
            }
            .padding(8)
            .frame(width: 62, height: 62, alignment: .topLeading)
        }
        .shadow(color: FlowLineTheme.accent.opacity(0.25), radius: 6, x: 0, y: 2)
    }
}

// MARK: - How-To Sheet

struct WidgetHowToSheet: View {
    @AppStorage("hasSeenWidgetPromo") private var hasSeen = false
    @Environment(\.dismiss) private var dismiss

    private let steps: [(icon: String, color: Color, title: String, body: String)] = [
        ("hand.tap",            Color(hex: "#7c3aed"), "Long-press the home screen",    "Touch and hold any empty area until the icons jiggle."),
        ("plus.circle.fill",    Color(hex: "#2563eb"), "Tap the + button",              "Look for the + in the top-left corner of the screen."),
        ("magnifyingglass",     Color(hex: "#0891b2"), "Search for Flowline",           "Type \"Flowline\" in the search bar at the top."),
        ("square.grid.2x2",     Color(hex: "#059669"), "Choose a size & tap Add Widget","Pick Small, Medium, or a Lock Screen widget.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                FlowLineTheme.mainBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Header illustration
                        headerIllustration
                            .padding(.top, 24)
                            .padding(.bottom, 28)

                        // Steps
                        VStack(spacing: 12) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                stepRow(number: index + 1, step: step)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Lock screen note
                        lockScreenNote
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        // Done button
                        Button {
                            hasSeen = true
                            dismiss()
                        } label: {
                            Text("Got it!")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(FlowLineTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Add a Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(FlowLineTheme.secondTxt)
                }
            }
        }
    }

    // MARK: Header illustration

    private var headerIllustration: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Home screen widget (medium)
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#1a1a2e"))
                    .frame(width: 160, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(FlowLineTheme.accent.opacity(0.3), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle().fill(FlowLineTheme.accent).frame(width: 6, height: 6)
                        Text("NOW · Deep Work")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    Text("09:00 – 11:00 · 45m left")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    HStack {
                        Text("NEXT  Team Standup")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        Text("11:30")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(12)
                .frame(width: 160, height: 80, alignment: .topLeading)
            }
            .shadow(color: FlowLineTheme.accent.opacity(0.2), radius: 10, x: 0, y: 4)

            VStack(spacing: 10) {
                // Lock screen pill
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: "#1a1a2e"))
                        .frame(width: 130, height: 24)
                    HStack(spacing: 5) {
                        Circle().fill(FlowLineTheme.accent).frame(width: 5, height: 5)
                        Text("Deep Work · 45m left")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                // Small home screen widget
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "#1a1a2e"))
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                    VStack(spacing: 2) {
                        Text("NOW")
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundColor(FlowLineTheme.accent)
                        Text("Deep\nWork")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("45m left")
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Step row

    private func stepRow(number: Int, step: (icon: String, color: Color, title: String, body: String)) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Number circle
            ZStack {
                Circle()
                    .fill(step.color.opacity(0.15))
                    .frame(width: 38, height: 38)
                Text("\(number)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(step.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(FlowLineTheme.mainTxt)
                Text(step.body)
                    .font(.system(size: 13))
                    .foregroundColor(FlowLineTheme.secondTxt)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)

            Spacer()
        }
        .padding(12)
        .background(FlowLineTheme.tertiaryBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Lock screen note

    private var lockScreenNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#7c3aed"))
            Text("Lock screen widgets are also available — choose Inline, Rectangular, or Circular after searching for Flowline.")
                .font(.system(size: 12))
                .foregroundColor(FlowLineTheme.secondTxt)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(hex: "#7c3aed").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
