import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 0

    // Step 1: Name
    @State private var name: String = ""

    // Step 2: Wake/Sleep
    @State private var wakeTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0))!
    @State private var sleepTime = Calendar.current.date(from: DateComponents(hour: 23, minute: 0))!

    // Step 3: Work hours
    @State private var hasWorkHours = false
    @State private var workStart = Calendar.current.date(from: DateComponents(hour: 9, minute: 0))!
    @State private var workEnd = Calendar.current.date(from: DateComponents(hour: 17, minute: 0))!

    // Step 4: Bio
    @State private var bio: String = ""

    private let totalSteps = 4

    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? FlowLineTheme.accent : FlowLineTheme.secondBg)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 20)

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

                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button {
                            withAnimation { currentStep -= 1 }
                        } label: {
                            Text("Back")
                                .foregroundColor(FlowLineTheme.secondTxt)
                        }
                    }

                    Spacer()

                    Button {
                        if currentStep < totalSteps - 1 {
                            withAnimation { currentStep += 1 }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        Text(currentStep == totalSteps - 1 ? "Get Started" : "Next")
                            .bold()
                            .foregroundColor(FlowLineTheme.mainBg)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(FlowLineTheme.accent)
                            .cornerRadius(12)
                    }
                    .disabled(currentStep == 0 && name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Step 1: Name
    private var nameStep: some View {
        VStack(spacing: 16) {
            Text("What's your name?")
                .font(.title)
                .bold()
                .foregroundColor(FlowLineTheme.mainTxt)

            Text("We'll use it to personalize your experience")
                .font(.body)
                .foregroundColor(FlowLineTheme.secondTxt)

            TextField("Your name", text: $name)
                .textFieldStyle(.plain)
                .padding(14)
                .background(.regularMaterial)
                .cornerRadius(12)
                .foregroundColor(FlowLineTheme.mainTxt)
                .padding(.horizontal, 40)
                .padding(.top, 12)
        }
    }

    // MARK: - Step 2: Wake/Sleep time
    private var scheduleStep: some View {
        VStack(spacing: 24) {
            Text("Your daily rhythm")
                .font(.title)
                .bold()
                .foregroundColor(FlowLineTheme.mainTxt)

            Text("When do you usually wake up and go to sleep?")
                .font(.body)
                .foregroundColor(FlowLineTheme.secondTxt)

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Wake up")
                        .font(.headline)
                        .foregroundColor(FlowLineTheme.secondTxt)
                    DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                }

                VStack(spacing: 8) {
                    Text("Go to sleep")
                        .font(.headline)
                        .foregroundColor(FlowLineTheme.secondTxt)
                    DatePicker("", selection: $sleepTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                }
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Step 3: Work hours
    private var workHoursStep: some View {
        VStack(spacing: 24) {
            Text("Do you have fixed hours?")
                .font(.title)
                .bold()
                .foregroundColor(FlowLineTheme.mainTxt)

            Text("School, work, or any regular commitments")
                .font(.body)
                .foregroundColor(FlowLineTheme.secondTxt)

            Toggle(isOn: $hasWorkHours) {
                Text("I have fixed hours")
                    .foregroundColor(FlowLineTheme.mainTxt)
            }
            .toggleStyle(.switch)
            .tint(FlowLineTheme.accent)
            .padding(.horizontal, 40)

            if hasWorkHours {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Start")
                            .font(.headline)
                            .foregroundColor(FlowLineTheme.secondTxt)
                        DatePicker("", selection: $workStart, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .colorScheme(.dark)
                    }

                    VStack(spacing: 8) {
                        Text("End")
                            .font(.headline)
                            .foregroundColor(FlowLineTheme.secondTxt)
                        DatePicker("", selection: $workEnd, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .colorScheme(.dark)
                    }
                }
                .padding(.horizontal, 40)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: hasWorkHours)
    }

    // MARK: - Step 4: Bio
    private var bioStep: some View {
        VStack(spacing: 16) {
            Text("Tell us about yourself")
                .font(.title)
                .bold()
                .foregroundColor(FlowLineTheme.mainTxt)

            Text("This helps AI plan your day better")
                .font(.body)
                .foregroundColor(FlowLineTheme.secondTxt)

            Text("Example: \"I'm a CS student, usually have classes until 2pm. I work best in the mornings. I go to gym 3x a week.\"")
                .font(.caption)
                .foregroundColor(FlowLineTheme.secondTxt.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            TextEditor(text: $bio)
                .scrollContentBackground(.hidden)
                .foregroundColor(FlowLineTheme.mainTxt)
                .padding(12)
                .frame(minHeight: 120)
                .background(.regularMaterial)
                .cornerRadius(12)
                .padding(.horizontal, 40)
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
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

#Preview {
    OnboardingView()
}
