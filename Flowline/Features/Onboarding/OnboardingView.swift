import SwiftUI
import SwiftData
import RevenueCatUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var authService: AuthService
    var isInitialOnboarding: Bool = true
    @State private var currentStep = 0
    @State private var showPaywall = false

    @State private var name: String = ""
    @State private var wakeTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0))!
    @State private var sleepTime = Calendar.current.date(from: DateComponents(hour: 23, minute: 0))!
    @State private var hasWorkHours = false
    @State private var workStart = Calendar.current.date(from: DateComponents(hour: 9, minute: 0))!
    @State private var workEnd = Calendar.current.date(from: DateComponents(hour: 17, minute: 0))!
    @State private var bio: String = ""

    private let totalSteps = 5

    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()
            CosmosBackground().ignoresSafeArea()

            // Watermark step number
            Text(String(format: "%02d", currentStep + 1))
                .font(.system(size: 180, weight: .black))
                .foregroundColor(FlowLineTheme.tertiaryBg.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, -20)
                .padding(.bottom, -30)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: currentStep)

            VStack(spacing: 0) {
                // Progress bar
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i <= currentStep
                                  ? AnyShapeStyle(LinearGradient(
                                        colors: [FlowLineTheme.accent, Color(hex: "#c4b5fd")],
                                        startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(FlowLineTheme.borderHi))
                            .frame(height: 3)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()

                // Step content — wrapped in ScrollView so it never clips on small screens
                ScrollView(showsIndicators: false) {
                    Group {
                        switch currentStep {
                        case 0: nameStep
                        case 1: scheduleStep
                        case 2: workHoursStep
                        case 3: bioStep
                        case 4: calendarStep
                        default: EmptyView()
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }

                Spacer(minLength: 16)

                // Navigation
                HStack {
                    if currentStep > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { currentStep -= 1 }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Back")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(FlowLineTheme.secondTxt)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button {
                        advance()
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentStep == totalSteps - 1 ? "Get Started" : "Continue")
                                .font(.system(size: 14, weight: .bold))
                            if currentStep < totalSteps - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                if currentStep == 0 && name.trimmingCharacters(in: .whitespaces).isEmpty {
                                    LinearGradient(
                                        colors: [FlowLineTheme.accent.opacity(0.3), Color(hex: "#8b6dff").opacity(0.3)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                } else {
                                    LinearGradient(
                                        colors: [FlowLineTheme.accent, Color(hex: "#8b6dff")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                }
                            }
                        )
                        .clipShape(Capsule())
                        .shadow(
                            color: (currentStep == 0 && name.trimmingCharacters(in: .whitespaces).isEmpty)
                                ? .clear
                                : FlowLineTheme.accent.opacity(0.55),
                            radius: 14, y: 5
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(currentStep == 0 && name.trimmingCharacters(in: .whitespaces).isEmpty)
                    #if os(macOS)
                    .keyboardShortcut(.return, modifiers: [])
                    #endif
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showPaywall) {
            FlowlinePaywallView { finishOnboarding() }
                .environmentObject(subscriptionManager)
                .interactiveDismissDisabled(false)
                .onDisappear { finishOnboarding() }
        }
    }

    // MARK: - Navigation helper

    private func advance() {
        if currentStep < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.25)) { currentStep += 1 }
        } else {
            completeOnboarding()
        }
    }

    // MARK: - Step 1: Name

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What should\nwe call you?")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(LinearGradient(
                        colors: [FlowLineTheme.mainTxt, Color(hex: "#c4b5fd")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .lineSpacing(2)

                Text("Your profile name")
                    .font(.system(size: 14))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }

            VStack(spacing: 0) {
                TextField("", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(FlowLineTheme.mainTxt)
                    .padding(.bottom, 10)
                    .onSubmit {
                        if !name.trimmingCharacters(in: .whitespaces).isEmpty { advance() }
                    }
                    .placeholder(when: name.isEmpty) {
                        Text("Alex")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(FlowLineTheme.secondTxt.opacity(0.3))
                    }

                Rectangle()
                    .fill(
                        name.isEmpty
                            ? FlowLineTheme.borderHi
                            : FlowLineTheme.accent.opacity(0.7)
                    )
                    .frame(height: 1.5)
                    .animation(.easeInOut(duration: 0.2), value: name.isEmpty)
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Step 2: Schedule

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your daily\nrhythm")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(LinearGradient(
                        colors: [FlowLineTheme.mainTxt, Color(hex: "#c4b5fd")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .lineSpacing(2)

                Text("When do you wake and sleep?")
                    .font(.system(size: 14))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }

            VStack(spacing: 20) {
                timePickerRow(label: "Wake up", binding: $wakeTime)
                timePickerRow(label: "Sleep", binding: $sleepTime)
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Step 3: Work Hours

    private var workHoursStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Fixed\ncommitments?")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(LinearGradient(
                        colors: [FlowLineTheme.mainTxt, Color(hex: "#c4b5fd")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .lineSpacing(2)

                Text("School, work, or regular blocks")
                    .font(.system(size: 14))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }

            HStack {
                Text("I have fixed hours")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(FlowLineTheme.mainTxt)
                Spacer()
                Toggle("", isOn: $hasWorkHours)
                    .toggleStyle(.switch)
                    .tint(FlowLineTheme.accent)
                    .labelsHidden()
            }

            if hasWorkHours {
                VStack(spacing: 20) {
                    timePickerRow(label: "Start", binding: $workStart)
                    timePickerRow(label: "End", binding: $workEnd)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hasWorkHours)
        .padding(.horizontal, 28)
    }

    // MARK: - Step 4: Bio

    private var bioStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tell the AI\nabout you")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(LinearGradient(
                        colors: [FlowLineTheme.mainTxt, Color(hex: "#c4b5fd")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .lineSpacing(2)

                Text("The more context, the smarter your plans")
                    .font(.system(size: 14))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }

            ZStack(alignment: .topLeading) {
                if bio.isEmpty {
                    Text("I'm a CS student, classes until 2pm. I work best in mornings. Gym 3x a week...")
                        .font(.system(size: 14))
                        .foregroundColor(FlowLineTheme.secondTxt.opacity(0.3))
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $bio)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(FlowLineTheme.mainTxt)
                    .font(.system(size: 14))
                    .frame(minHeight: 100)
                    .background(.clear)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(
                        bio.isEmpty
                            ? FlowLineTheme.borderHi
                            : FlowLineTheme.accent.opacity(0.7)
                    )
                    .frame(height: 1.5)
                    .animation(.easeInOut(duration: 0.2), value: bio.isEmpty)
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Step 5: Calendar Integration

    private var calendarStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your calendars,\nconnected.")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(LinearGradient(
                        colors: [FlowLineTheme.mainTxt, Color(hex: "#c4b5fd")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .lineSpacing(2)

                Text("AI reads your events before planning — never double-books you")
                    .font(.system(size: 14))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }

            VStack(spacing: 10) {
                // Apple Calendar
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "calendar")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Apple Calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(FlowLineTheme.mainTxt)
                        Text("iCloud, local calendars & Exchange")
                            .font(.system(size: 12))
                            .foregroundColor(FlowLineTheme.secondTxt)
                    }
                    Spacer()
                    Label("Automatic", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#2ecc71"))
                }
                .padding(14)
                .background(FlowLineTheme.tertiaryBg)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FlowLineTheme.borderHi, lineWidth: 1)
                )

                // Google Calendar
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(hex: "#4285f4").opacity(0.12))
                            .frame(width: 44, height: 44)
                        Text("G")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(Color(hex: "#4285f4"))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Google Calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(FlowLineTheme.mainTxt)
                        #if os(iOS)
                        Text("Settings → Calendar → Accounts → Add Account")
                            .font(.system(size: 12))
                            .foregroundColor(FlowLineTheme.secondTxt)
                        #else
                        Text("System Settings → Internet Accounts → Google")
                            .font(.system(size: 12))
                            .foregroundColor(FlowLineTheme.secondTxt)
                        #endif
                    }
                    Spacer()
                }
                .padding(14)
                .background(FlowLineTheme.tertiaryBg)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FlowLineTheme.borderHi, lineWidth: 1)
                )
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                    .padding(.top, 1)
                Text("Flowline also saves your AI-generated plans directly to any connected calendar — with one click.")
                    .font(.system(size: 12.5))
                    .foregroundColor(FlowLineTheme.secondTxt)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(FlowLineTheme.tertiaryBg.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Time Picker Row

    private func timePickerRow(label: String, binding: Binding<Date>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(FlowLineTheme.secondTxt)
            Spacer()
            DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FlowLineTheme.border)
                .frame(height: 0.5)
                .offset(y: 8)
        }
    }

    // MARK: - Save

    private func completeOnboarding() {
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            wakeTime: wakeTime,
            sleepTime: sleepTime,
            hasWorkHours: hasWorkHours,
            workStartTime: hasWorkHours ? workStart : nil,
            workEndTime: hasWorkHours ? workEnd : nil,
            bio: bio.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(profile)
        if isInitialOnboarding {
            // Show paywall — finishing it (buy or dismiss) marks onboarding complete
            showPaywall = true
        } else {
            dismiss()
        }
    }

    private func finishOnboarding() {
        subscriptionManager.startTrialIfNeeded()
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        // Tell the server onboarding is done so other devices skip it
        if let token = authService.token {
            Task { await SyncService.shared.markOnboardingDone(token: token) }
        }
    }
}

// MARK: - Placeholder helper

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    OnboardingView()
}
