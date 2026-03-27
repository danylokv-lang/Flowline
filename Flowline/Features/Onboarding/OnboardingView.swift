import SwiftUI
import SwiftData

// MARK: - Focus Type

enum FocusType: String, CaseIterable {
    case work  = "Work"
    case study = "Study"
    case mixed = "Mixed"

    var icon: String {
        switch self {
        case .work:  return "briefcase.fill"
        case .study: return "graduationcap.fill"
        case .mixed: return "shuffle"
        }
    }

    var description: String {
        switch self {
        case .work:  return "Meetings, deep work, projects"
        case .study: return "Classes, assignments, research"
        case .mixed: return "Work and study combined"
        }
    }

    var color: Color {
        switch self {
        case .work:  return Color(hex: "#818cf8")
        case .study: return Color(hex: "#34d399")
        case .mixed: return Color(hex: "#f59e0b")
        }
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    var isInitialOnboarding: Bool = true

    // Navigation
    @State private var currentStep = 0
    @State private var isGoingForward = true
    private let totalSteps = 4

    // Step 1 — Name
    @State private var name: String = ""

    // Step 2 — Schedule
    @State private var wakeTime  = Calendar.current.date(from: DateComponents(hour: 7, minute: 0))!
    @State private var sleepTime = Calendar.current.date(from: DateComponents(hour: 23, minute: 0))!
    @State private var hasFixedHours = false
    @State private var workStart = Calendar.current.date(from: DateComponents(hour: 9, minute: 0))!
    @State private var workEnd   = Calendar.current.date(from: DateComponents(hour: 17, minute: 0))!

    // Step 3 — You
    @State private var focusType: FocusType = .mixed
    @State private var bio: String = ""

    // Step 4 — Ready (notifications)
    @State private var notificationsEnabled = true

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

                // ── Progress bar ────────────────────────────────────────
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

                // ── Step content ────────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    Group {
                        switch currentStep {
                        case 0: nameStep
                        case 1: scheduleStep
                        case 2: youStep
                        case 3: readyStep
                        default: EmptyView()
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: isGoingForward ? .trailing : .leading).combined(with: .opacity),
                        removal:   .move(edge: isGoingForward ? .leading : .trailing).combined(with: .opacity)
                    ))
                    .id("step-\(currentStep)")
                }

                Spacer(minLength: 16)

                // ── Navigation ──────────────────────────────────────────
                HStack {
                    if currentStep > 0 {
                        Button {
                            isGoingForward = false
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
                    } else {
                        Spacer().frame(width: 60) // balance layout on step 0
                    }

                    Spacer()

                    Button {
                        isGoingForward = true
                        advance()
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentStep == totalSteps - 1 ? "Create my first plan" : "Continue")
                                .font(.system(size: 14, weight: .bold))
                            if currentStep < totalSteps - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: ctaDisabled
                                    ? [FlowLineTheme.accent.opacity(0.3), Color(hex: "#8b6dff").opacity(0.3)]
                                    : [FlowLineTheme.accent, Color(hex: "#8b6dff")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(
                            color: ctaDisabled ? .clear : FlowLineTheme.accent.opacity(0.55),
                            radius: 14, y: 5
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(ctaDisabled)
                    #if os(macOS)
                    .keyboardShortcut(.return, modifiers: [])
                    #endif
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: CTA state

    private var ctaDisabled: Bool {
        currentStep == 0 && name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: Navigation

    private func advance() {
        if currentStep < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.25)) { currentStep += 1 }
        } else {
            completeOnboarding()
        }
    }

    // MARK: ─── Step 1: Name ────────────────────────────────────────────────

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            stepHeader(
                title: "What should\nwe call you?",
                subtitle: "We'll personalise your experience"
            )

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
                            .foregroundColor(FlowLineTheme.secondTxt.opacity(0.28))
                    }

                Rectangle()
                    .fill(name.isEmpty ? FlowLineTheme.borderHi : FlowLineTheme.accent.opacity(0.7))
                    .frame(height: 1.5)
                    .animation(.easeInOut(duration: 0.2), value: name.isEmpty)
            }

            // Quick reassurance
            infoNote("This is just your display name — you can change it in Settings anytime.")
        }
        .padding(.horizontal, 28)
    }

    // MARK: ─── Step 2: Schedule ───────────────────────────────────────────

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                title: "Your daily\nrhythm",
                subtitle: "Flowline plans inside your available hours"
            )

            // Wake / Sleep pickers
            VStack(spacing: 0) {
                timePickerRow(label: "Wake up", icon: "sun.horizon.fill",
                              color: Color(hex: "#f59e0b"), binding: $wakeTime)
                Divider().background(FlowLineTheme.border).padding(.leading, 54)
                timePickerRow(label: "Bedtime", icon: "moon.stars.fill",
                              color: Color(hex: "#818cf8"), binding: $sleepTime)
            }
            .background(FlowLineTheme.tertiaryBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FlowLineTheme.borderHi, lineWidth: 1)
            )

            // Fixed hours toggle (optional)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(hex: "#3b82f6").opacity(0.14))
                            .frame(width: 36, height: 36)
                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#3b82f6"))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fixed work / school hours")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(FlowLineTheme.mainTxt)
                        Text("Optional — AI won't schedule over these blocks")
                            .font(.system(size: 12))
                            .foregroundColor(FlowLineTheme.secondTxt)
                    }

                    Spacer()

                    Toggle("", isOn: $hasFixedHours)
                        .toggleStyle(.switch)
                        .tint(FlowLineTheme.accent)
                        .labelsHidden()
                }
                .padding(14)

                if hasFixedHours {
                    Divider().background(FlowLineTheme.border).padding(.leading, 54)

                    VStack(spacing: 0) {
                        timePickerRow(label: "Start", icon: "play.fill",
                                      color: Color(hex: "#34d399"), binding: $workStart)
                        Divider().background(FlowLineTheme.border).padding(.leading, 54)
                        timePickerRow(label: "End", icon: "stop.fill",
                                      color: Color(hex: "#f87171"), binding: $workEnd)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: hasFixedHours)
            .background(FlowLineTheme.tertiaryBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FlowLineTheme.borderHi, lineWidth: 1)
            )
        }
        .padding(.horizontal, 28)
    }

    // MARK: ─── Step 3: You ────────────────────────────────────────────────

    private var youStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                title: "A bit about\nyou",
                subtitle: "Helps the AI make smarter plans for you"
            )

            // Focus type
            VStack(spacing: 8) {
                Text("MAIN FOCUS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(FlowLineTheme.secondTxt)
                    .tracking(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    ForEach(FocusType.allCases, id: \.self) { type in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { focusType = type }
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(type.color.opacity(focusType == type ? 0.2 : 0.07))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: type.icon)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(type.color.opacity(focusType == type ? 1 : 0.5))
                                }
                                Text(type.rawValue)
                                    .font(.system(size: 11, weight: focusType == type ? .bold : .regular))
                                    .foregroundColor(focusType == type ? FlowLineTheme.mainTxt : FlowLineTheme.secondTxt)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(FlowLineTheme.tertiaryBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        focusType == type ? type.color.opacity(0.6) : FlowLineTheme.borderHi,
                                        lineWidth: focusType == type ? 1.5 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Bio
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ANYTHING ELSE?")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(FlowLineTheme.secondTxt)
                        .tracking(0.8)
                    Text("optional")
                        .font(.system(size: 10))
                        .foregroundColor(FlowLineTheme.dimTxt)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(FlowLineTheme.borderHi.opacity(0.6))
                        .clipShape(Capsule())
                }

                ZStack(alignment: .topLeading) {
                    if bio.isEmpty {
                        Text("e.g. I work best in the mornings. Gym on Mon/Wed/Fri. Prefer no meetings after 4 pm…")
                            .font(.system(size: 13))
                            .foregroundColor(FlowLineTheme.secondTxt.opacity(0.3))
                            .allowsHitTesting(false)
                            .padding(.top, 1)
                    }
                    TextEditor(text: $bio)
                        .scrollContentBackground(.hidden)
                        .foregroundColor(FlowLineTheme.mainTxt)
                        .font(.system(size: 13))
                        .frame(minHeight: 90)
                        .background(.clear)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(bio.isEmpty ? FlowLineTheme.borderHi : FlowLineTheme.accent.opacity(0.6))
                        .frame(height: 1.5)
                        .animation(.easeInOut(duration: 0.2), value: bio.isEmpty)
                }

                infoNote("The more context, the smarter your first plan — but even nothing works great.")
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: ─── Step 4: Ready ──────────────────────────────────────────────

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                title: "You're all\nset, \(firstName)!",
                subtitle: "Here's what happens when you tap the button below"
            )

            // "What happens next" cards
            VStack(spacing: 10) {
                nextCard(
                    step: "1",
                    icon: "sparkles",
                    color: FlowLineTheme.accent,
                    title: "AI builds your first plan",
                    body: "Just describe your day — Flowline generates a full time-blocked schedule."
                )
                nextCard(
                    step: "2",
                    icon: "calendar.badge.checkmark",
                    color: Color(hex: "#3b82f6"),
                    title: "Save it to your calendar",
                    body: "Tap Save and your blocks land in Apple or Google Calendar automatically."
                )
                nextCard(
                    step: "3",
                    icon: "flame.fill",
                    color: Color(hex: "#f97316"),
                    title: "Build your streak",
                    body: "Plan every day to grow your streak and track your planning habits."
                )
            }

            // Notification toggle
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#7c3aed").opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(hex: "#7c3aed"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Morning & evening reminders")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(FlowLineTheme.mainTxt)
                    Text("Nudges to plan in the morning and review at night")
                        .font(.system(size: 12))
                        .foregroundColor(FlowLineTheme.secondTxt)
                }

                Spacer()

                Toggle("", isOn: $notificationsEnabled)
                    .toggleStyle(.switch)
                    .tint(FlowLineTheme.accent)
                    .labelsHidden()
            }
            .padding(14)
            .background(FlowLineTheme.tertiaryBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FlowLineTheme.borderHi, lineWidth: 1)
            )
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Shared components

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(LinearGradient(
                    colors: [FlowLineTheme.mainTxt, Color(hex: "#c4b5fd")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .lineSpacing(2)

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(FlowLineTheme.secondTxt)
        }
    }

    private func timePickerRow(label: String, icon: String, color: Color, binding: Binding<Date>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(color)
            }

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(FlowLineTheme.mainTxt)

            Spacer()

            DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func nextCard(step: String, icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.13))
                    .frame(width: 36, height: 36)
                Text(step)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(color)
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(FlowLineTheme.mainTxt)
                }
                Text(body)
                    .font(.system(size: 12))
                    .foregroundColor(FlowLineTheme.secondTxt)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(12)
        .background(FlowLineTheme.tertiaryBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FlowLineTheme.borderHi, lineWidth: 1)
        )
    }

    private func infoNote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundColor(FlowLineTheme.secondTxt.opacity(0.4))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(FlowLineTheme.secondTxt.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Helpers

    private var firstName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.components(separatedBy: " ").first ?? trimmed
    }

    // MARK: - Save & Complete

    private func completeOnboarding() {
        var fullBio = "My main focus: \(focusType.rawValue)"
        let trimmedBio = bio.trimmingCharacters(in: .whitespaces)
        if !trimmedBio.isEmpty { fullBio += "\n\n\(trimmedBio)" }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // UPSERT: always update existing record, never insert a duplicate
        if let existing = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first {
            existing.name          = trimmedName
            existing.wakeTime      = wakeTime
            existing.sleepTime     = sleepTime
            existing.hasWorkHours  = hasFixedHours
            existing.workStartTime = hasFixedHours ? workStart : nil
            existing.workEndTime   = hasFixedHours ? workEnd   : nil
            existing.bio           = fullBio
        } else {
            modelContext.insert(UserProfile(
                name: trimmedName,
                wakeTime: wakeTime,
                sleepTime: sleepTime,
                hasWorkHours: hasFixedHours,
                workStartTime: hasFixedHours ? workStart : nil,
                workEndTime:   hasFixedHours ? workEnd   : nil,
                bio: fullBio
            ))
        }
        try? modelContext.save()

        finishOnboarding(name: trimmedName)

        if isInitialOnboarding {
            UserDefaults.standard.set(true, forKey: "shouldAutoSendFirstPlan")
        } else {
            dismiss()
        }
    }

    private func finishOnboarding(name: String) {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        let wake  = wakeTime
        let sleep = sleepTime
        let requestNotifications = notificationsEnabled

        if let token = authService.token {
            Task {
                await SyncService.shared.markOnboardingDone(token: token)
                if let profile = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first {
                    await SyncService.shared.pushProfile(profile, name: name, token: token)
                }
            }
        }

        Task {
            if requestNotifications {
                await NotificationManager.shared.requestAndSchedule(
                    name: name.isEmpty ? "there" : name,
                    wakeTime: wake,
                    sleepTime: sleep
                )
            }
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
        .environmentObject(AuthService())
}
