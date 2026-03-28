import SwiftUI
import Combine
import SwiftData
import EventKit
import StoreKit
#if os(iOS)
import UIKit
#endif

private func openSystemURL(_ url: URL) {
    #if os(macOS)
    NSWorkspace.shared.open(url)
    #else
    UIApplication.shared.open(url)
    #endif
}

struct Message: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    var isThinking: Bool = false
    var isSavedPlan: Bool = false
    var isError: Bool = false
    var isRetryable: Bool = false

    enum Role {
        case user, assistant
    }
}

struct PlanValidationResult {
    let isValid: Bool
    let warnings: [String]
    let canProceedAnyway: Bool = true
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, FlowLineTheme.mainTxt.opacity(0.25), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.4)
                    .offset(x: -geo.size.width * 0.4 + phase * (geo.size.width * 1.4))
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .onReceive(timer) { _ in
                phase = 0
                withAnimation(.linear(duration: 1.5)) { phase = 1 }
            }
    }
}

struct PlanningChatView: View {
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif
    @Query(sort: \ChatMessage.timestamp) private var savedMessages: [ChatMessage]
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<CapturedTask> { !$0.isScheduled }, sort: \CapturedTask.createdAt)
    private var inboxTasks: [CapturedTask]
    @Binding var selectedTab: Int
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var authService: AuthService
    @State private var isLoading: Bool = false
    @State private var isSaving: Bool = false
    @State private var didLoadHistory = false
    @State private var showCalendarBanner = false
    @State private var showCalendarPicker = false
    @State private var calendarPickerItems: [WritableCalendarInfo] = []
    @State private var selectedCalendarID: String = ""
    @State private var showSidebar = false
    @State private var showPaywall = false
    @State private var planValidationWarnings: [String] = []
    @State private var showValidationWarnings = false
    @State private var skipValidationOnNextSave = false
    @State private var lastFailedMessage: String? = nil
    @State private var canRetrySave = false
    @State private var showCalendarDeniedAlert = false
    @State private var editorHeight: CGFloat = 17
    @State private var emptyGlow = false
    @State private var selectedTemplate: DayTemplate? = nil
    @State private var streakPulse: Bool = false
    @State private var showSettings = false
    @AppStorage("currentSessionID") private var currentSessionID: String = UUID().uuidString
    @AppStorage("lastUsedCalendarID") private var lastUsedCalendarID: String = ""
    @AppStorage("lastPlanDate") private var lastPlanDate: String = ""
    // End-of-day review
    @AppStorage("lastReviewDate")   private var lastReviewDate: String = ""
    @AppStorage("lastReviewRating") private var lastReviewRating: Int = 0
    @State private var showReviewCard = false
    // Paywall timing (shown once, after the very first plan save)
    @AppStorage("paywallShownAfterFirstPlan") private var paywallShownAfterFirstPlan = false
    // Auto-send first plan prompt after onboarding
    @AppStorage("shouldAutoSendFirstPlan") private var shouldAutoSendFirstPlan = false
    @StateObject private var aiService = GeminiPlanningService()
    @StateObject private var streak = StreakManager.shared
    private let planSaver = PlanSavingService()
    private let calendarService = CalendarService.shared

    var body: some View {
        ZStack(alignment: .leading) {
            // ── Cosmos background ─────────────────────────────────────────
            FlowLineTheme.mainBg.ignoresSafeArea()
            CosmosBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────────
                HStack(alignment: .center) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSidebar.toggle()
                        }
                    } label: {
                        VStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Capsule()
                                    .fill(FlowLineTheme.secondTxt)
                                    .frame(width: i == 1 ? 14 : 20, height: 1.5)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("FLOWLINE")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(6)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#c4b5fd"), FlowLineTheme.accentHi],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )

                    Spacer()

                    // Streak pill (hidden when loading)
                    if streak.currentStreak > 0 && !isLoading {
                        HStack(spacing: 4) {
                            Text(streak.currentStreak > 1 ? "🔥" : "✦")
                                .font(.system(size: 11))
                            Text(streak.currentStreak > 1
                                 ? "\(streak.currentStreak) days"
                                 : "Day 1")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(streak.currentStreak > 1 ? .orange : FlowLineTheme.accent)
                                .contentTransition(.numericText(value: Double(streak.currentStreak)))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            (streak.currentStreak > 1 ? Color.orange : FlowLineTheme.accent)
                                .opacity(0.12)
                        )
                        .clipShape(Capsule())
                        .scaleEffect(streakPulse ? 1.18 : 1.0)
                        .transition(.scale.combined(with: .opacity))
                        .onChange(of: streak.currentStreak) { _, _ in
                            guard streak.currentStreak > 1 else { return }
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                                streakPulse = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    streakPulse = false
                                }
                            }
                        }
                    }

                    // Session dot indicator
                    Circle()
                        .fill(isLoading ? FlowLineTheme.accent : FlowLineTheme.secondTxt.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: isLoading)

                    // Settings gear
                    Button {
                        #if os(macOS)
                        openSettings()
                        #else
                        showSettings = true
                        #endif
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(FlowLineTheme.secondTxt)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(FlowLineTheme.mainBg)

                Rectangle()
                    .fill(FlowLineTheme.border)
                    .frame(height: 0.5)

                // ── Day 1 Checklist (new users only) ─────────────────────
                if streak.totalPlansCreated <= 5 {
                    Day1ChecklistView()
                }

                // ── Widget education (shown once after first plan) ─────────
                WidgetEducationCard()

                // ── Chat area ────────────────────────────────────────────
                if messages.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(messages) { message in
                                    chatBubble(message)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .onChange(of: messages.count) {
                            if let last = messages.last {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                // ── End-of-day review card ───────────────────────────────
                if showReviewCard {
                    reviewCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // ── Input bar ────────────────────────────────────────────
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(FlowLineTheme.border)
                        .frame(height: 0.5)

                    // ── Upgrade banner (limit hit) ─────────
                    if subscriptionManager.isAtLimit {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Weekly plan limit reached")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(FlowLineTheme.mainTxt)
                                Text("Upgrade for unlimited AI planning")
                                    .font(.system(size: 11))
                                    .foregroundColor(FlowLineTheme.secondTxt)
                            }
                            Spacer()
                            Button {
                                showPaywall = true
                            } label: {
                                Text("Upgrade")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(FlowLineTheme.accent)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(FlowLineTheme.accent.opacity(0.07))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // ── Plans saved counter ────────────────────────
                    if !subscriptionManager.isPro {
                        HStack {
                            Spacer()
                            if subscriptionManager.isAtLimit {
                                Button { showPaywall = true } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 9, weight: .bold))
                                        Text("Weekly limit reached — Upgrade for more")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(FlowLineTheme.accent)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            } else if subscriptionManager.isInTrial {
                                let days = subscriptionManager.trialDaysRemaining
                                Text("Free trial — unlimited saves · \(days == 0 ? "Ends today" : "\(days)d remaining")")
                                    #if os(macOS)
                                    .font(.system(size: 11))
                                    .foregroundColor(FlowLineTheme.accent.opacity(0.85))
                                    #else
                                    .font(.system(size: 10))
                                    .foregroundColor(FlowLineTheme.accent.opacity(0.7))
                                    #endif
                            } else if subscriptionManager.plansThisWeek == 0 {
                                Text("0/\(SubscriptionManager.weeklyFreeLimit) plans saved this week")
                                    #if os(macOS)
                                    .font(.system(size: 11))
                                    .foregroundColor(FlowLineTheme.secondTxt.opacity(0.7))
                                    #else
                                    .font(.system(size: 10))
                                    .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                                    #endif
                            } else {
                                Text("\(subscriptionManager.plansThisWeek)/\(SubscriptionManager.weeklyFreeLimit) plans saved this week")
                                    #if os(macOS)
                                    .font(.system(size: 11))
                                    .foregroundColor(FlowLineTheme.secondTxt.opacity(0.7))
                                    #else
                                    .font(.system(size: 10))
                                    .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                                    #endif
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    }

                    if hasPlanInChat && !isLoading && !isSaving {
                        HStack(spacing: 8) {
                            Spacer()
                            if subscriptionManager.isAtLimit {
                                // Limit reached — save buttons replaced with Upgrade prompt
                                Button { showPaywall = true } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("Upgrade to Save")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(FlowLineTheme.accent)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            } else {
                                // Save Plan button — saves to SwiftData
                                Button {
                                    savePlan()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle")
                                            .font(.system(size: 12, weight: .bold))
                                        Text("Save Plan")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        LinearGradient(
                                            colors: [FlowLineTheme.accent, Color(hex: "#8b6dff")],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: FlowLineTheme.accent.opacity(0.45), radius: 10, x: 0, y: 4)
                                }
                                .buttonStyle(.plain)

                                // Calendar button — optional export
                                Button {
                                    _Concurrency.Task { @MainActor in
                                        await calendarService.requestAccess()
                                        guard calendarService.isAuthorized else {
                                            showCalendarDeniedAlert = true
                                            return
                                        }
                                        var cals = calendarService.writableCalendars()
                                        if cals.isEmpty {
                                            try? await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 400_000_000)
                                            cals = calendarService.writableCalendars()
                                        }
                                        calendarPickerItems = cals
                                        if !lastUsedCalendarID.isEmpty, cals.contains(where: { $0.id == lastUsedCalendarID }) {
                                            selectedCalendarID = lastUsedCalendarID
                                        } else {
                                            selectedCalendarID = cals.first?.id ?? ""
                                        }
                                        showCalendarPicker = true
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar.badge.plus")
                                            .font(.system(size: 12, weight: .bold))
                                        Text("Add to Calendar")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        LinearGradient(
                                            colors: [FlowLineTheme.accent.opacity(0.75), Color(hex: "#8b6dff").opacity(0.75)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: FlowLineTheme.accent.opacity(0.3), radius: 6, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    HStack(alignment: .bottom, spacing: 10) {
                        ZStack(alignment: .topLeading) {
                            if inputText.isEmpty {
                                Text("What's on your plate today...")
                                    .font(.system(size: 14))
                                    .foregroundColor(FlowLineTheme.secondTxt.opacity(0.4))
                                    .allowsHitTesting(false)
                            }
                            GrowingTextEditor(
                                text: $inputText,
                                height: $editorHeight,
                                maxHeight: 110
                            ) {
                                let trimmed = inputText.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty, !isLoading, !isSaving, !subscriptionManager.isAtLimit else { return }
                                sendMessage()
                            }
                            .frame(height: editorHeight)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(FlowLineTheme.tertiaryBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(FlowLineTheme.borderHi, lineWidth: 1)
                        )

                        Button { sendMessage() } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading || isSaving || subscriptionManager.isAtLimit
                                            ? FlowLineTheme.tertiaryBg
                                            : FlowLineTheme.accent
                                    )
                                    .frame(width: 36, height: 36)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(
                                        inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading || isSaving || subscriptionManager.isAtLimit
                                            ? FlowLineTheme.secondTxt.opacity(0.3)
                                            : FlowLineTheme.mainBg
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading || isSaving || subscriptionManager.isAtLimit)
                        .padding(.bottom, 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .background(FlowLineTheme.mainBg)
            }
            // No background on outer VStack — cosmos shows through chat area
            .animation(.easeOut(duration: 0.25), value: messages.isEmpty)
            .overlay(alignment: .top) {
                if showCalendarBanner {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Saved to Calendar")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(FlowLineTheme.accent)
                    .clipShape(Capsule())
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showCalendarBanner)
            .onAppear {
                refreshSystemPrompt()
                loadHistory()
                Task {
                    await calendarService.requestAccess()
                    refreshSystemPrompt()
                    // Auto-send personalized first plan prompt after onboarding
                    if shouldAutoSendFirstPlan {
                        shouldAutoSendFirstPlan = false
                        // Small delay so the view is fully ready
                        try? await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 800_000_000)
                        let profile = profiles.first
                        let focusLine = profile?.bio.components(separatedBy: "\n").first ?? ""
                        let wakeStr = profile.map {
                            let f = DateFormatter(); f.timeStyle = .short; return f.string(from: $0.wakeTime)
                        } ?? "7:00 AM"
                        let prompt = "Plan my day. \(focusLine.isEmpty ? "" : "\(focusLine). ")I wake at \(wakeStr). Make it realistic and actionable."
                        await MainActor.run { sendMessage(prompt) }
                    }
                }
                checkReviewPrompt()
            }
            .onChange(of: profiles.first?.name) { refreshSystemPrompt() }
            .onChange(of: profiles.first?.bio) { refreshSystemPrompt() }
            .onChange(of: profiles.first?.wakeTime) { refreshSystemPrompt() }
            .onChange(of: profiles.first?.sleepTime) { refreshSystemPrompt() }
            .onChange(of: profiles.first?.hasWorkHours) { refreshSystemPrompt() }
            .onChange(of: profiles.first?.recurringCommitments) { refreshSystemPrompt() }
            .flowlinePaywall(isPresented: $showPaywall, subscriptionManager: subscriptionManager)
            // Handle notification deep-link (morning / evening tap)
            .onReceive(NotificationCenter.default.publisher(for: .flowlineOpenChat)) { note in
                if let prompt = note.object as? String, !prompt.isEmpty {
                    sendMessage(prompt)
                }
            }

            // ── Sidebar ──────────────────────────────────────────────
            if showSidebar {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSidebar = false
                        }
                    }
                sidebarView
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showSidebar)
        .hideKeyboardOnTap()
        .alert("Calendar Access Required", isPresented: $showCalendarDeniedAlert) {
            Button("Open Settings") {
                #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #elseif os(macOS)
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
                #endif
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To add your plan to Calendar, allow Flowline access in Settings → Privacy → Calendars.")
        }
        .sheet(isPresented: $showCalendarPicker) {
            CalendarPickerSheet(
                initialCalendars: calendarPickerItems,
                selectedID: $selectedCalendarID,
                onSave: {
                    showCalendarPicker = false
                    savePlanToCalendar(toCalendarID: selectedCalendarID)
                },
                onCancel: { showCalendarPicker = false }
            )
        }
        .sheet(isPresented: $showValidationWarnings) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Plan Review")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(FlowLineTheme.mainTxt)

                    Text("This plan has some potential issues:")
                        .font(.system(size: 13))
                        .foregroundColor(FlowLineTheme.secondTxt)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(planValidationWarnings, id: \.self) { warning in
                            HStack(alignment: .top, spacing: 8) {
                                Text(warning)
                                    .font(.system(size: 12))
                                    .foregroundColor(FlowLineTheme.mainTxt)
                                Spacer()
                            }
                        }
                    }
                    .padding(10)
                    .background(FlowLineTheme.tertiaryBg)
                    .cornerRadius(6)
                }
                .padding(16)
                .background(FlowLineTheme.secondBg)
                .cornerRadius(12)

                HStack(spacing: 12) {
                    Button {
                        showValidationWarnings = false
                    } label: {
                        Text("Edit Plan")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(FlowLineTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(FlowLineTheme.tertiaryBg)
                            .cornerRadius(6)
                    }

                    Button {
                        showValidationWarnings = false
                        // Skip validation on this save attempt
                        skipValidationOnNextSave = true
                        savePlan()
                    } label: {
                        Text("Save Anyway")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(FlowLineTheme.accent)
                            .cornerRadius(6)
                    }
                }
                .padding(16)

                Spacer()
            }
            .background(FlowLineTheme.mainBg)
        }
        #if !os(macOS)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        #endif
    }

    // MARK: - End-of-Day Review

    private var reviewCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("How did today's plan go?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(FlowLineTheme.mainTxt)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showReviewCard = false }
                    lastReviewDate = todayKey   // dismiss without rating = skip
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(FlowLineTheme.dimTxt)
                        .padding(6)
                        .background(FlowLineTheme.tertiaryBg)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        submitReview(rating: rating)
                    } label: {
                        VStack(spacing: 4) {
                            Text(reviewEmoji(rating))
                                .font(.system(size: 26))
                            Text("\(rating)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(FlowLineTheme.secondTxt)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            lastReviewRating == rating && lastReviewDate == todayKey
                                ? FlowLineTheme.accent.opacity(0.18)
                                : FlowLineTheme.tertiaryBg
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    lastReviewRating == rating && lastReviewDate == todayKey
                                        ? FlowLineTheme.accent.opacity(0.5)
                                        : FlowLineTheme.borderHi,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(FlowLineTheme.secondBg)
        .overlay(alignment: .top) {
            Rectangle().fill(FlowLineTheme.border).frame(height: 0.5)
        }
    }

    private func reviewEmoji(_ rating: Int) -> String {
        switch rating {
        case 1: return "😩"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "😊"
        default: return "🎯"
        }
    }

    private func checkReviewPrompt() {
        let hour = Calendar.current.component(.hour, from: Date())
        // Show after 5pm, if today was planned, and not yet reviewed today
        guard hour >= 17,
              lastPlanDate == todayKey,
              lastReviewDate != todayKey else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.25)) { showReviewCard = true }
        }
    }

    private func submitReview(rating: Int) {
        lastReviewRating = rating
        lastReviewDate = todayKey
        withAnimation(.easeOut(duration: 0.2)) { showReviewCard = false }
        // Feed rating back into next prompt so AI improves
        refreshSystemPrompt()
        // Send to server so you can track ratings across all users
        if let token = authService.token {
            Task { await SyncService.shared.pushReview(rating: rating, planDate: Date(), token: token) }
        }
        // If rating is low, prompt user to refine
        if rating <= 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                sendMessage("My plan today was rated \(rating)/5 — it didn't work well. What could we do differently tomorrow?")
            }
        }
    }

    // MARK: - Empty State

    // ── Today's date string for new-day detection ─────────────────────────────
    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var isNewDay: Bool { lastPlanDate != todayKey }

    // ── Smart time-aware empty state ──────────────────────────────────────────
    private var emptyState: some View {
        VStack(spacing: 24) {

            // ── Icon + streak badge ───────────────────────────────────────────
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(FlowLineTheme.accent.opacity(emptyGlow ? 0.12 : 0.04))
                        .frame(width: emptyGlow ? 96 : 80, height: emptyGlow ? 96 : 80)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: emptyGlow)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [FlowLineTheme.accent.opacity(0.35), Color(hex: "#8b6dff").opacity(0.15)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [FlowLineTheme.accent.opacity(0.18), Color(hex: "#8b6dff").opacity(0.08)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                    Text("✦")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#c4b5fd"), FlowLineTheme.accentHi],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: FlowLineTheme.accent.opacity(0.6), radius: 8, x: 0, y: 0)
                }
                .onAppear { emptyGlow = true }
                if streak.currentStreak > 1 {
                    HStack(spacing: 3) {
                        Text("🔥")
                            .font(.system(size: 11))
                        Text("\(streak.currentStreak)")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange)
                    .clipShape(Capsule())
                    .offset(x: 8, y: 4)
                }
            }

            // ── Greeting + subtitle ───────────────────────────────────────────
            VStack(spacing: 6) {
                Text(timeGreeting)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FlowLineTheme.mainTxt, Color(hex: "#c4b5fd").opacity(0.9)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Text(timeSubtitle)
                    .font(.system(size: 13))
                    .foregroundColor(FlowLineTheme.secondTxt)
                    .multilineTextAlignment(.center)
            }

            // ── Day template selector ─────────────────────────────────────────
            if isNewDay {
                templateSelector
            }

            // ── Hero "Plan my day" button (new day) / profile nudge ──────────
            if isNewDay {
                // Prominent one-tap hero button shown when it's a fresh day
                Button {
                    lastPlanDate = todayKey
                    sendMessage(heroPlanPrompt)
                    selectedTemplate = nil
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Plan my whole day")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("Full time-blocked schedule, built now →")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [FlowLineTheme.accent, Color(hex: "#8b6dff")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: FlowLineTheme.accent.opacity(0.45), radius: 16, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 340)
                .disabled(isLoading || isSaving)
            } else if profiles.first?.bio.isEmpty ?? true {
                // Profile nudge when bio is empty and today already planned
                Button {
                    #if os(macOS)
                    openSettings()
                    #endif
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(FlowLineTheme.accentHi)
                        Text("Add your context in Settings for better plans")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(FlowLineTheme.secondTxt)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(FlowLineTheme.dimTxt)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(FlowLineTheme.tertiaryBg.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(FlowLineTheme.accent.opacity(0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 320)
            }

            // ── Secondary quick-start chips ───────────────────────────────────
            VStack(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button {
                        sendMessage(prompt)
                    } label: {

                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [FlowLineTheme.accentHi, Color(hex: "#c4b5fd")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                            Text(prompt)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(FlowLineTheme.mainTxt)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [FlowLineTheme.tertiaryBg, FlowLineTheme.secondBg.opacity(0.80)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            FlowLineTheme.accent.opacity(0.30),
                                            Color(hex: "#8b6dff").opacity(0.12)
                                        ],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: FlowLineTheme.accent.opacity(0.08), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading || isSaving || subscriptionManager.isAtLimit)
                    .opacity(subscriptionManager.isAtLimit ? 0.4 : 1)
                }
            }
            .frame(maxWidth: 320)
        }
        .padding(.horizontal, 32)
    }

    // ── Hero prompt: rich enough that the AI builds a plan without asking ─────
    private var heroPlanPrompt: String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMMM d"
        let dateStr = df.string(from: Date())
        let tf = DateFormatter()
        tf.timeStyle = .short
        let timeStr = tf.string(from: Date())

        var extras = ""
        if !inboxTasks.isEmpty {
            let list = inboxTasks.prefix(5).map { "• \($0.text)" }.joined(separator: "\n")
            extras = "\n\nI have these tasks in my inbox to slot in:\n\(list)"
        }

        var templateExtra = ""
        if let t = selectedTemplate {
            templateExtra = "\n\n---\nTEMPLATE SELECTED: \(t.name)\n\(t.promptConstraints)"
        }

        return "Plan my whole day for \(dateStr). Current time is \(timeStr). Build a complete, realistic time-blocked schedule.\(extras)\(templateExtra)"
    }

    // ── Template selector ─────────────────────────────────────────────────────
    private var templateSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT KIND OF DAY?")
                .font(.system(size: 9, weight: .bold))
                .tracking(2)
                .foregroundColor(FlowLineTheme.dimTxt)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DayTemplate.all) { template in
                        templateChip(template)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: 340)
    }

    private func templateChip(_ template: DayTemplate) -> some View {
        let isSelected = selectedTemplate?.id == template.id

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedTemplate = isSelected ? nil : template
            }
        } label: {
            HStack(spacing: 5) {
                Text(template.emoji)
                    .font(.system(size: 14))
                Text(template.name)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : FlowLineTheme.secondTxt)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected
                          ? template.accent
                          : FlowLineTheme.secondBg.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isSelected
                                    ? template.accent.opacity(0.0)
                                    : FlowLineTheme.borderHi.opacity(0.4),
                                    lineWidth: 1)
                    )
            )
            .shadow(color: isSelected ? template.accent.opacity(0.4) : .clear,
                    radius: 8, x: 0, y: 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning ☀️"
        case 12..<17: return "Good afternoon 👋"
        case 17..<21: return "Good evening 🌆"
        default:      return "Planning late? 🌙"
        }
    }

    private var timeSubtitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if streak.currentStreak > 1 {
            return "\(streak.currentStreak)-day streak — keep it going!"
        }
        switch hour {
        case 5..<12:  return "Start strong — tell me what you need to get done today."
        case 12..<17: return "Still time to structure your afternoon."
        case 17..<21: return "Plan tomorrow now so you start tomorrow relaxed."
        default:      return "Tell me what's on your plate."
        }
    }

    private var quickPrompts: [String] {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return [
                "Deep work morning + meetings afternoon",
                "Light day — just the essentials"
            ]
        } else if hour < 17 {
            return [
                "Structure the rest of my day",
                "Plan tomorrow"
            ]
        } else {
            return [
                "Plan tomorrow",
                "Quick end-of-day review"
            ]
        }
    }

    // MARK: - Chat Bubble

    @ViewBuilder
    private func chatBubble(_ message: Message) -> some View {
        if message.role == .user {
            // User: right-aligned, gradient purple bubble
            HStack {
                Spacer(minLength: 60)
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(FlowLineTheme.mainTxt)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [
                                FlowLineTheme.accent.opacity(0.28),
                                Color(hex: "#8b6dff").opacity(0.16)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [FlowLineTheme.accent.opacity(0.50), Color(hex: "#8b6dff").opacity(0.30)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: FlowLineTheme.accent.opacity(0.20), radius: 8, x: 0, y: 4)
                    .textSelection(.enabled)
            }
        } else if message.isThinking {
            aiCard {
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(FlowLineTheme.secondTxt)
                    .modifier(ShimmerModifier())
            }
        } else if message.isSavedPlan {
            aiCard(accent: true) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundColor(FlowLineTheme.secondTxt)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        selectedTab = 1
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11, weight: .bold))
                            Text("View Calendar")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(FlowLineTheme.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if message.isError {
            aiCard(isError: true) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.red.opacity(0.7))
                        Text(message.content)
                            .font(.system(size: 13))
                            .foregroundColor(FlowLineTheme.secondTxt)
                    }
                    if message.isRetryable, let failed = lastFailedMessage {
                        Button {
                            sendMessage(failed)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Retry")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.55))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            // Normal AI message card
            VStack(alignment: .leading, spacing: 12) {
                aiCard {
                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundColor(FlowLineTheme.secondTxt)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Refinement suggestions for plan messages
                if hasPlanInMessage(message) {
                    refinementSuggestions
                }
            }
        }
    }

    private func hasPlanInMessage(_ message: Message) -> Bool {
        guard let timePattern = try? NSRegularExpression(pattern: "\\d{2}:\\d{2}") else { return false }
        return timePattern.firstMatch(in: message.content, range: NSRange(message.content.startIndex..., in: message.content)) != nil
    }

    private var refinementSuggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Adjust this plan:")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(FlowLineTheme.secondTxt)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    refinementButton("+ Break", "Add a 20-30 min break")
                    refinementButton("📱 Evening", "Move to evening")
                    Spacer()
                }
                HStack(spacing: 8) {
                    refinementButton("⚡ Morning", "Move hard tasks here")
                    refinementButton("🎯 Shorter", "Reduce durations")
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(FlowLineTheme.tertiaryBg.opacity(0.5))
        .cornerRadius(8)
    }

    private func refinementButton(_ label: String, _ instruction: String) -> some View {
        Button {
            sendMessage(instruction)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(FlowLineTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(FlowLineTheme.accent.opacity(0.12))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    /// Branded AI card — "✦ FLOWLINE" tag + dark bubble, matching website style.
    @ViewBuilder
    private func aiCard<Content: View>(
        accent: Bool = false,
        isError: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 9) {
                // ✦ Flowline label — matches website .ai-tag
                Text("✦ Flowline")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(
                        isError ? Color.red.opacity(0.7) : FlowLineTheme.accent
                    )
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                if isError {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red.opacity(0.07))
                } else if accent {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(
                            colors: [FlowLineTheme.accent.opacity(0.14), Color(hex: "#8b6dff").opacity(0.07)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(
                            colors: [FlowLineTheme.tertiaryBg, FlowLineTheme.secondBg.opacity(0.9)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isError
                            ? AnyShapeStyle(Color.red.opacity(0.22))
                            : accent
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [FlowLineTheme.accent.opacity(0.50), Color(hex: "#8b6dff").opacity(0.25)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [Color.white.opacity(0.14), Color.white.opacity(0.06)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isError
                    ? Color.red.opacity(0.08)
                    : accent
                        ? FlowLineTheme.accent.opacity(0.18)
                        : Color.black.opacity(0.25),
                radius: accent ? 12 : 6,
                x: 0, y: 3
            )
            Spacer(minLength: 40)
        }
    }

    // MARK: - Helpers

    private func refreshSystemPrompt() {
        guard let profile = profiles.first else { return }

        var sections: [String] = []

        // Section 1: blocks already saved inside Flowline
        if let flowlineCtx = try? planSaver.calendarContext(forWeekOf: Date(), context: modelContext),
           !flowlineCtx.isEmpty {
            sections.append("FLOWLINE SAVED BLOCKS (already planned by user):\n\(flowlineCtx)")
        }

        // Section 2: All connected calendar events (Apple iCloud, Google, Exchange, etc.) — today + 3 weeks
        if let calCtx = calendarService.formattedForAI(date: Date(), weeks: 3) {
            sections.append("ALL CONNECTED CALENDARS (real appointments from Apple, Google, and other synced accounts, next 3 weeks — events tagged [Google] are from Google Calendar):\n\(calCtx)")
        }

        // Section 3: Task inbox — unscheduled items the AI should plan around
        if !inboxTasks.isEmpty {
            let formatted = inboxTasks.map { "• \($0.text) [\($0.category)]" }.joined(separator: "\n")
            sections.append("""
TASK INBOX (unscheduled tasks — when the user asks to plan a day, slot these in where they fit. \
After planning, tell the user which inbox tasks you included):
\(formatted)
""")
        }

        let combined = sections.isEmpty ? nil : sections.joined(separator: "\n\n")

        // Section 4: recent review rating feedback
        var reviewCtx: String? = nil
        if lastReviewRating > 0 {
            let label: String
            switch lastReviewRating {
            case 1: label = "very poorly (1/5) — the plan was unrealistic or too packed"
            case 2: label = "poorly (2/5) — they fell behind and couldn't keep up"
            case 3: label = "okay (3/5) — followed it partially"
            case 4: label = "well (4/5) — mostly stuck to it with minor deviations"
            default: label = "perfectly (5/5) — nailed every block"
            }
            let wasToday = lastReviewDate == todayKey
            reviewCtx = "RECENT FEEDBACK: The user rated their \(wasToday ? "today's" : "last") plan \(label). Adjust your next plan accordingly — \(lastReviewRating <= 2 ? "fewer tasks, more breathing room, be realistic" : lastReviewRating == 3 ? "slightly lighter load and clearer priorities" : "keep the same style, it's working")."
        }

        aiService.token = authService.token ?? ""
        aiService.updateSystemPrompt(from: profile, calendarContext: combined, reviewContext: reviewCtx)
    }

    // MARK: - Send

    private func sendMessage(_ overrideText: String? = nil) {
        let text = overrideText ?? inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isLoading, !isSaving else { return }

        // Clear template after it's been baked into the outgoing prompt
        if overrideText == nil { selectedTemplate = nil }

        refreshSystemPrompt()

        let history = savedMessages
            .filter { $0.sessionID == currentSessionID }
            .sorted { $0.timestamp < $1.timestamp }
            .map { msg in (role: msg.role, content: msg.content) }

        messages.append(Message(role: .user, content: text))
        persistMessage(role: "user", content: text)
        inputText = ""
        editorHeight = 17
        lastFailedMessage = nil
        isLoading = true
        messages.append(Message(role: .assistant, content: "Thinking...", isThinking: true))

        _Concurrency.Task {
            aiService.token = authService.token ?? ""
            do {
                let response = try await aiService.sendMessage(history: history, newMessage: text)
                if let jsonData = response.data(using: .utf8),
                   let plan = try? JSONDecoder().decode(GeneratedPlan.self, from: jsonData) {
                    try? planSaver.save(plan: plan, for: Date(), context: modelContext)
                    WidgetDataWriter.shared.refresh(context: modelContext)
                    scheduleNotificationsAfterSave()
                    if let token = authService.token {
                        _Concurrency.Task { await SyncService.shared.pushWeek(for: Date(), token: token, context: modelContext) }
                    }
                    if let index = messages.lastIndex(where: { $0.isThinking }) {
                        messages[index] = Message(role: .assistant, content: plan.summary, isSavedPlan: true)
                    }
                    persistMessage(role: "assistant", content: response)

                    // Auto-show calendar picker if user has saves remaining
                    if subscriptionManager.canSavePlan {
                        _Concurrency.Task { @MainActor in
                            try? await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 500_000_000) // 0.5s delay
                            await calendarService.requestAccess()
                            var cals = calendarService.writableCalendars()
                            if cals.isEmpty {
                                try? await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 400_000_000)
                                cals = calendarService.writableCalendars()
                            }
                            calendarPickerItems = cals
                            if !lastUsedCalendarID.isEmpty, cals.contains(where: { $0.id == lastUsedCalendarID }) {
                                selectedCalendarID = lastUsedCalendarID
                            } else {
                                selectedCalendarID = cals.first?.id ?? ""
                            }
                            showCalendarPicker = true
                        }
                    } else {
                        showCalendarBanner = true
                        _Concurrency.Task {
                            try? await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 3_000_000_000)
                            showCalendarBanner = false
                        }
                    }
                } else {
                    if let index = messages.lastIndex(where: { $0.isThinking }) {
                        messages[index] = Message(role: .assistant, content: response)
                    }
                    persistMessage(role: "assistant", content: response)
                }
            } catch let claudeError as ClaudeError {
                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages.remove(at: index)
                }
                if claudeError.isRetryable { lastFailedMessage = text }
                messages.append(Message(
                    role: .assistant,
                    content: claudeError.errorDescription ?? "Something went wrong.",
                    isError: true,
                    isRetryable: claudeError.isRetryable
                ))
            } catch let geminiError as GeminiError {
                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages.remove(at: index)
                }
                lastFailedMessage = text
                messages.append(Message(
                    role: .assistant,
                    content: geminiError.errorDescription ?? "Something went wrong.",
                    isError: true,
                    isRetryable: true
                ))
            } catch {
                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages.remove(at: index)
                }
                lastFailedMessage = text
                messages.append(Message(
                    role: .assistant,
                    content: "Something went wrong. Try again.",
                    isError: true,
                    isRetryable: true
                ))
            }
            isLoading = false
        }
    }

    // MARK: - Persistence

    private func loadHistory() {
        guard !didLoadHistory else { return }
        didLoadHistory = true
        let sessionMsgs = savedMessages.filter { $0.sessionID == currentSessionID }
        messages = sessionMsgs.suffix(50).map { msg in
            Message(role: msg.role == "user" ? .user : .assistant, content: msg.content)
        }
    }

    private func persistMessage(role: String, content: String) {
        let chatMsg = ChatMessage(
            role: role,
            content: content,
            sessionDate: Calendar.current.startOfDay(for: Date()),
            sessionID: currentSessionID
        )
        modelContext.insert(chatMsg)
        // Push to server so the same chat appears on other devices
        if let token = authService.token {
            _Concurrency.Task { await SyncService.shared.pushMessages([chatMsg], token: token) }
        }
    }

    // MARK: - Plan Validation

    private func validatePlan(_ plan: GeneratedPlan) -> PlanValidationResult {
        var warnings: [String] = []

        let wakeTime = profiles.first?.wakeTime ?? Date(timeIntervalSince1970: TimeInterval(7 * 3600))
        let sleepTime = profiles.first?.sleepTime ?? Date(timeIntervalSince1970: TimeInterval(23 * 3600))

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let wakeTimeStr = formatter.string(from: wakeTime)
        let sleepTimeStr = formatter.string(from: sleepTime)

        // Check for blocks before wake or after sleep
        for block in plan.blocks {
            if block.startTime < wakeTimeStr {
                warnings.append("⚠️ '\(block.title)' starts at \(block.startTime) — before your \(wakeTimeStr) wake time")
            }
            if block.endTime > sleepTimeStr {
                warnings.append("⚠️ '\(block.title)' ends at \(block.endTime) — after your \(sleepTimeStr) sleep time")
            }

            // Check for blocks longer than 4 hours (should have break)
            if let start = timeComponents(block.startTime), let end = timeComponents(block.endTime) {
                let minutes = (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute)
                if minutes > 240 { // 4 hours
                    warnings.append("⚠️ '\(block.title)' is \(minutes / 60)h \(minutes % 60)m — consider adding a break")
                }
            }
        }

        return PlanValidationResult(isValid: warnings.isEmpty, warnings: warnings)
    }

    private func timeComponents(_ timeStr: String) -> (hour: Int, minute: Int)? {
        let parts = timeStr.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return (hour: parts[0], minute: parts[1])
    }

    // MARK: - Save Plan

    private var hasPlanInChat: Bool {
        messages.contains { message in
            guard !message.isThinking && !message.isSavedPlan && message.role == .assistant else { return false }
            guard message.content.count > 200 else { return false }

            // Check if content has schedule blocks (HH:mm pattern like "07:00", "14:30")
            guard let timePattern = try? NSRegularExpression(pattern: "\\d{2}:\\d{2}") else { return false }
            let hasTimeBlocks = timePattern.firstMatch(in: message.content, range: NSRange(message.content.startIndex..., in: message.content)) != nil

            return hasTimeBlocks
        }
    }

    /// Fetch today's saved blocks and schedule block-reminder notifications.
    private func scheduleNotificationsAfterSave() {
        let today    = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let descriptor = FetchDescriptor<ScheduleBlock>(
            predicate: #Predicate { $0.startTime >= today && $0.startTime < tomorrow },
            sortBy: [SortDescriptor(\.startTime)]
        )
        guard let blocks = try? modelContext.fetch(descriptor) else { return }
        let sleepTime  = profiles.first?.sleepTime ?? Calendar.current.date(from: DateComponents(hour: 23))!
        let streakDays = StreakManager.shared.currentStreak
        NotificationManager.shared.onPlanSaved(blocks: blocks, streakDays: streakDays, sleepTime: sleepTime)
    }

    private func savePlan() {
        guard !isSaving, subscriptionManager.canSavePlan else { return }
        isSaving = true
        messages.append(Message(role: .assistant, content: "Saving plan...", isThinking: true))

        let history = messages
            .filter { !$0.isThinking && !$0.isSavedPlan }
            .map { msg in (role: msg.role == .user ? "user" : "assistant", content: msg.content) }

        let planDate = Date()

        _Concurrency.Task {
            aiService.token = authService.token ?? ""
            do {
                let plan = try await aiService.generatePlan(for: planDate, history: history)

                // Validate plan and show warnings if needed (unless user chose "Save Anyway")
                if !skipValidationOnNextSave {
                    let validation = validatePlan(plan)
                    if !validation.isValid {
                        await MainActor.run {
                            planValidationWarnings = validation.warnings
                            showValidationWarnings = true
                        }
                        if let index = messages.lastIndex(where: { $0.isThinking }) {
                            messages.remove(at: index)
                        }
                        isSaving = false
                        return
                    }
                } else {
                    // Reset flag after use
                    skipValidationOnNextSave = false
                }

                let isFirstPlan = StreakManager.shared.totalPlansCreated == 0
                try planSaver.save(plan: plan, for: planDate, context: modelContext)
                await MainActor.run { CelebrationManager.shared.triggerConfetti() }
                WidgetDataWriter.shared.refresh(context: modelContext)
                scheduleNotificationsAfterSave()
                if let token = authService.token {
                    await SyncService.shared.pushWeek(for: planDate, token: token, context: modelContext)
                }
                StreakManager.shared.recordPlan()
                subscriptionManager.recordPlanSave(token: authService.token)

                // C.2 — show paywall after the very first plan save
                if isFirstPlan && !paywallShownAfterFirstPlan {
                    paywallShownAfterFirstPlan = true
                    try? await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 1_500_000_000)
                    await MainActor.run { showPaywall = true }
                }

                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages[index] = Message(
                        role: .assistant,
                        content: "Plan saved \u{2713}\n\n\(plan.summary)",
                        isSavedPlan: true
                    )
                }

                // Rate Us on 2nd save
                let totalSaves = subscriptionManager.totalPlanSaves
                if totalSaves == 2 {
                    try? await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 1_000_000_000)
                    #if os(iOS)
                    if let scene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                    #endif
                }
            } catch {
                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages[index] = Message(role: .assistant, content: "Save failed: \(error.localizedDescription)", isError: true, isRetryable: true)
                }
            }
            isSaving = false
        }
    }

    private func savePlanToCalendar(toCalendarID calendarID: String? = nil) {
        guard !isSaving, subscriptionManager.canSavePlan else { return }
        isSaving = true
        messages.append(Message(role: .assistant, content: "Saving to calendar...", isThinking: true))

        let history = messages
            .filter { !$0.isThinking && !$0.isSavedPlan }
            .map { msg in (role: msg.role == .user ? "user" : "assistant", content: msg.content) }

        _Concurrency.Task {
            aiService.token = authService.token ?? ""
            do {
                let plan = try await aiService.generatePlan(for: Date(), history: history)

                // Validate plan and show warnings if needed
                let validation = validatePlan(plan)
                if !validation.isValid {
                    await MainActor.run {
                        planValidationWarnings = validation.warnings
                        showValidationWarnings = true
                    }
                    if let index = messages.lastIndex(where: { $0.isThinking }) {
                        messages.remove(at: index)
                    }
                    isSaving = false
                    return
                }

                try planSaver.save(plan: plan, for: Date(), context: modelContext)
                await MainActor.run { CelebrationManager.shared.triggerConfetti() }
                WidgetDataWriter.shared.refresh(context: modelContext)
                scheduleNotificationsAfterSave()
                if let token = authService.token {
                    await SyncService.shared.pushWeek(for: Date(), token: token, context: modelContext)
                }
                try calendarService.savePlan(plan, toCalendarID: calendarID)
                // Remember the calendar the user picked
                if let id = calendarID, !id.isEmpty {
                    lastUsedCalendarID = id
                }
                StreakManager.shared.recordPlan()
                subscriptionManager.recordPlanSave(token: authService.token)

                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages[index] = Message(
                        role: .assistant,
                        content: "Plan saved \u{2713}\n\n\(plan.summary)",
                        isSavedPlan: true
                    )
                }

                // Rate Us on 2nd save
                let totalSaves = subscriptionManager.totalPlanSaves
                if totalSaves == 2 {
                    try? await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 1_000_000_000)
                    #if os(iOS)
                    if let scene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                    #endif
                }
            } catch {
                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    let errMsg: String
                    if error.localizedDescription.lowercased().contains("caldav") ||
                       error.localizedDescription.lowercased().contains("google") {
                        errMsg = "Couldn't save to Google Calendar. Try a different calendar or check your connection."
                    } else {
                        errMsg = "Calendar save failed: \(error.localizedDescription)"
                    }
                    messages[index] = Message(role: .assistant, content: errMsg, isError: true, isRetryable: true)
                }
            }
            isSaving = false
        }
    }

    // MARK: - Sidebar

    private var sessions: [(id: String, date: Date, preview: String)] {
        let grouped = Dictionary(grouping: savedMessages) { $0.sessionID }
        return grouped.keys.compactMap { id in
            let msgs = (grouped[id] ?? []).sorted { $0.timestamp < $1.timestamp }
            guard let first = msgs.first else { return nil }
            let preview = msgs.first(where: { $0.role == "user" })?.content ?? "New conversation"
            return (id: id, date: first.timestamp, preview: preview)
        }.sorted { $0.date > $1.date }
    }

    private func loadSession(id: String) {
        let sessionMsgs = savedMessages
            .filter { $0.sessionID == id }
            .sorted { $0.timestamp < $1.timestamp }
        messages = sessionMsgs.map { msg in
            Message(role: msg.role == "user" ? .user : .assistant, content: msg.content)
        }
    }

    private func deleteSession(id: String) {
        let toDelete = savedMessages.filter { $0.sessionID == id }
        toDelete.forEach { modelContext.delete($0) }
        if id == currentSessionID {
            currentSessionID = UUID().uuidString
            messages = []
            didLoadHistory = false
        }
    }

    @ViewBuilder
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("CHATS")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(3)
                    .foregroundColor(FlowLineTheme.secondTxt)
                Spacer()
                Button {
                    currentSessionID = UUID().uuidString
                    messages = []
                    didLoadHistory = false
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showSidebar = false
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(FlowLineTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Rectangle()
                .fill(FlowLineTheme.border)
                .frame(height: 0.5)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(sessions, id: \.id) { session in
                        HStack(spacing: 0) {
                            Button {
                                currentSessionID = session.id
                                didLoadHistory = false
                                loadSession(id: session.id)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showSidebar = false
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.date, style: .date)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(
                                            session.id == currentSessionID
                                                ? FlowLineTheme.accent
                                                : FlowLineTheme.mainTxt
                                        )
                                    Text(session.preview)
                                        .font(.system(size: 13))
                                        .foregroundColor(FlowLineTheme.secondTxt)
                                        .lineLimit(2)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            Button { deleteSession(id: session.id) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(FlowLineTheme.secondTxt.opacity(0.4))
                                    .padding(.trailing, 16)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(
                            session.id == currentSessionID
                                ? FlowLineTheme.accentBg
                                : Color.clear
                        )
                    }
                }
                .padding(.top, 6)
            }
        }
        .frame(width: 260)
        .background(FlowLineTheme.secondBg)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(FlowLineTheme.borderHi)
                .frame(width: 0.5)
        }
    }

    // MARK: - Plan Tomorrow

}

// MARK: - Calendar Picker Sheet

private struct CalendarPickerSheet: View {
    let initialCalendars: [WritableCalendarInfo]
    @Binding var selectedID: String
    let onSave: () -> Void
    let onCancel: () -> Void

    @ObservedObject private var calService = CalendarService.shared
    @State private var liveCalendars: [WritableCalendarInfo] = []
    @State private var authStatus: EKAuthorizationStatus = .notDetermined
    @State private var isRequestingAccess = false

    // Group calendars by source name
    private var grouped: [(sourceName: String, isGoogle: Bool, items: [WritableCalendarInfo])] {
        var map: [String: (isGoogle: Bool, items: [WritableCalendarInfo])] = [:]
        for cal in liveCalendars {
            if map[cal.sourceName] == nil {
                map[cal.sourceName] = (isGoogle: cal.isGoogle, items: [])
            }
            map[cal.sourceName]?.items.append(cal)
        }
        return map.map { (sourceName: $0.key, isGoogle: $0.value.isGoogle, items: $0.value.items) }
            .sorted { $0.sourceName < $1.sourceName }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ───────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save to Calendar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FlowLineTheme.mainTxt)
                    Text("Choose where your plan blocks are added")
                        .font(.system(size: 11))
                        .foregroundColor(FlowLineTheme.secondTxt)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }
            .padding(18)

            Divider()
                .background(FlowLineTheme.border)

            // ── Calendar list ─────────────────────────────────────────────
            if liveCalendars.isEmpty {
                VStack(spacing: 16) {
                    if isRequestingAccess {
                        ProgressView()
                            .controlSize(.large)
                    } else {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundColor(FlowLineTheme.secondTxt)
                        Text("No calendar access")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(FlowLineTheme.mainTxt)
                        Text(authStatus == .denied
                             ? "Calendar access was denied. Open Settings and enable Calendars for Flowline."
                             : "Flowline needs calendar access to save your plan blocks.")
                            .font(.system(size: 12))
                            .foregroundColor(FlowLineTheme.secondTxt)
                            .multilineTextAlignment(.center)
                        Button {
                            #if os(iOS)
                            if authStatus == .notDetermined {
                                isRequestingAccess = true
                                Task {
                                    await calService.requestAccess()
                                    authStatus = EKEventStore.authorizationStatus(for: .event)
                                    reloadCalendars()
                                    isRequestingAccess = false
                                }
                            } else {
                                openSystemURL(URL(string: UIApplication.openSettingsURLString)!)
                            }
                            #else
                            openSystemURL(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                            #endif
                        } label: {
                            Text(authStatus == .notDetermined ? "Allow Access" : "Open Settings")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 9)
                                .background(FlowLineTheme.accent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(28)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(grouped, id: \.sourceName) { group in
                            // Source header
                            HStack(spacing: 5) {
                                if group.isGoogle {
                                    Text("G")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundStyle(
                                            LinearGradient(colors: [.blue, .red],
                                                           startPoint: .topLeading,
                                                           endPoint: .bottomTrailing)
                                        )
                                        .frame(width: 12, height: 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(FlowLineTheme.secondBg)
                                                .overlay(RoundedRectangle(cornerRadius: 2)
                                                    .stroke(FlowLineTheme.border, lineWidth: 0.5))
                                        )
                                } else {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 9))
                                        .foregroundColor(FlowLineTheme.secondTxt)
                                }
                                Text(group.sourceName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(FlowLineTheme.secondTxt)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 5)

                            ForEach(group.items) { cal in
                                Button {
                                    selectedID = cal.id
                                } label: {
                                    HStack(spacing: 10) {
                                        // Calendar color dot
                                        Circle()
                                            .fill(cal.calColor.map { Color(cgColor: $0) } ?? Color.accentColor)
                                            .frame(width: 10, height: 10)

                                        Text(cal.title)
                                            .font(.system(size: 13))
                                            .foregroundColor(FlowLineTheme.mainTxt)

                                        Spacer()

                                        if selectedID == cal.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(FlowLineTheme.accent)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                                    .background(
                                        selectedID == cal.id
                                            ? FlowLineTheme.accent.opacity(0.08)
                                            : Color.clear
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }

            Divider()
                .background(FlowLineTheme.border)

            // ── Save button ───────────────────────────────────────────────
            Button(action: onSave) {
                HStack(spacing: 7) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Save Plan Here")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(selectedID.isEmpty ? FlowLineTheme.accent.opacity(0.4) : FlowLineTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .disabled(selectedID.isEmpty)
            .padding(16)
        }
        #if os(macOS)
        .frame(width: 320, height: 420)
        #else
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
        .background(FlowLineTheme.mainBg)
        .onAppear {
            authStatus = EKEventStore.authorizationStatus(for: .event)
            liveCalendars = initialCalendars
            // If calendars are empty but service says authorized, reload (handles race on first open)
            if liveCalendars.isEmpty && calService.isAuthorized {
                reloadCalendars()
            }
        }
        .onChange(of: calService.isAuthorized) { _, authorized in
            authStatus = EKEventStore.authorizationStatus(for: .event)
            if authorized { reloadCalendars() }
        }
    }

    private func reloadCalendars() {
        let cals = calService.writableCalendars()
        liveCalendars = cals
        if selectedID.isEmpty || !cals.contains(where: { $0.id == selectedID }) {
            selectedID = cals.first?.id ?? ""
        }
    }
}

// MARK: - Cosmos Background

/// Three-layer star field rendered with a Canvas for zero-overhead animation.
/// Layer 1: 55 distant white micro-stars (almost stationary, barely visible)
/// Layer 2: 18 mid-field accent-purple drifters
/// Layer 3: 7 bright foreground stars (slow drift, gentle twinkle)
#Preview {
    PlanningChatView(selectedTab: .constant(0))
}
