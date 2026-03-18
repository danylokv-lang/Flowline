import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var isInitialOnboarding: Bool = true
    @State private var currentStep = 0

    @State private var name: String = ""
    @State private var wakeTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0))!
    @State private var sleepTime = Calendar.current.date(from: DateComponents(hour: 23, minute: 0))!
    @State private var hasWorkHours = false
    @State private var workStart = Calendar.current.date(from: DateComponents(hour: 9, minute: 0))!
    @State private var workEnd = Calendar.current.date(from: DateComponents(hour: 17, minute: 0))!
    @State private var bio: String = ""

    private let totalSteps = 4

    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()

            // Watermark step number
            Text(String(format: "%02d", currentStep + 1))
                .font(.system(size: 180, weight: .black))
                .foregroundColor(FlowLineTheme.secondBg.opacity(0.18))
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
                            .fill(i <= currentStep ? FlowLineTheme.accent : FlowLineTheme.secondBg.opacity(0.3))
                            .frame(height: 3)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()

                // Step content
                Group {
                    switch currentStep {
                    case 0: nameStep
                    case 1: scheduleStep
                    case 2: workHoursStep
                    case 3: bioStep
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

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
                        if currentStep < totalSteps - 1 {
                            withAnimation(.easeInOut(duration: 0.25)) { currentStep += 1 }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentStep == totalSteps - 1 ? "Get Started" : "Continue")
                                .font(.system(size: 14, weight: .bold))
                            if currentStep < totalSteps - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                        .foregroundColor(FlowLineTheme.mainBg)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            currentStep == 0 && name.trimmingCharacters(in: .whitespaces).isEmpty
                                ? FlowLineTheme.accent.opacity(0.3)
                                : FlowLineTheme.accent
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(currentStep == 0 && name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Step 1: Name

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What should\nwe call you?")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(FlowLineTheme.mainTxt)
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
                    .placeholder(when: name.isEmpty) {
                        Text("Alex")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(FlowLineTheme.secondTxt.opacity(0.3))
                    }

                Rectangle()
                    .fill(
                        name.isEmpty
                            ? FlowLineTheme.secondBg.opacity(0.5)
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
                    .foregroundColor(FlowLineTheme.mainTxt)
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
                    .foregroundColor(FlowLineTheme.mainTxt)
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
                    .foregroundColor(FlowLineTheme.mainTxt)
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
                            ? FlowLineTheme.secondBg.opacity(0.5)
                            : FlowLineTheme.accent.opacity(0.7)
                    )
                    .frame(height: 1.5)
                    .animation(.easeInOut(duration: 0.2), value: bio.isEmpty)
            }
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
                .fill(FlowLineTheme.secondBg.opacity(0.3))
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
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        } else {
            dismiss()
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
