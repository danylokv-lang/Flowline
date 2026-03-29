import SwiftUI
import Combine

// MARK: - Guide Step

struct GuideStep {
    let icon: String
    let color: Color
    let title: String
    let description: String
}

// MARK: - Guide Overlay View

struct GuideOverlayView: View {
    @ObservedObject var manager: GuideOverlayManager

    private let steps: [GuideStep] = [
        GuideStep(icon: "sparkles",            color: Color(hex: "#3b82f6"), title: "Chat with AI",     description: "Tell AI about your day — it builds a full time-blocked plan instantly"),
        GuideStep(icon: "calendar.badge.plus", color: Color(hex: "#3b82f6"), title: "Save Plans",       description: "Tap to save plans to Flowline Calendar"),
        GuideStep(icon: "calendar",            color: Color(hex: "#2ecc71"), title: "Other Calendars",  description: "Add plans to Apple or Google Calendar with one tap"),
        GuideStep(icon: "chart.bar.fill",      color: Color(hex: "#f59e0b"), title: "Track Progress",   description: "View your streaks, stats and weekly completion"),
        GuideStep(icon: "timer",               color: Color(hex: "#ec4899"), title: "Focus Timer",      description: "Work distraction-free — timer tracks your focus sessions")
    ]

    var currentStep: GuideStep { steps[manager.currentStep] }
    var isLast: Bool { manager.currentStep == steps.count - 1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { manager.nextStep() }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    // Step dots
                    HStack(spacing: 6) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Capsule()
                                .fill(i == manager.currentStep ? Color(hex: "#3b82f6") : Color.white.opacity(0.2))
                                .frame(width: i == manager.currentStep ? 20 : 6, height: 6)
                                .animation(.spring(response: 0.3), value: manager.currentStep)
                        }
                    }

                    // Icon
                    ZStack {
                        Circle()
                            .fill(currentStep.color.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: currentStep.icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(currentStep.color)
                    }

                    // Text
                    VStack(spacing: 8) {
                        Text(currentStep.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text(currentStep.description)
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    // Buttons
                    HStack(spacing: 12) {
                        Button(action: { manager.finish() }) {
                            Text("Skip")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button(action: { manager.nextStep() }) {
                            Text(isLast ? "Done ✓" : "Next →")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#3b82f6"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Manager

@MainActor
final class GuideOverlayManager: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var isShowing: Bool = false

    func start() {
        guard shouldShow() else { return }
        currentStep = 0
        isShowing = true
    }

    func nextStep() {
        if currentStep < 4 {
            withAnimation(.spring(response: 0.35)) { currentStep += 1 }
        } else {
            finish()
        }
    }

    func finish() {
        withAnimation(.easeOut(duration: 0.2)) { isShowing = false }
        UserDefaults.standard.set(true, forKey: "hasSeenGuide")
    }

    func shouldShow() -> Bool {
        !UserDefaults.standard.bool(forKey: "hasSeenGuide")
    }
}
