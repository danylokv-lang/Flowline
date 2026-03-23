import SwiftUI
import Combine
import SwiftData
import EventKit
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
    @State private var lastFailedMessage: String? = nil
    @State private var editorHeight: CGFloat = 17
    @State private var emptyGlow = false
    @AppStorage("currentSessionID") private var currentSessionID: String = UUID().uuidString
    @AppStorage("lastUsedCalendarID") private var lastUsedCalendarID: String = ""
    @StateObject private var aiService = ClaudePlanningService(apiKey: "")
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
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            (streak.currentStreak > 1 ? Color.orange : FlowLineTheme.accent)
                                .opacity(0.12)
                        )
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Session dot indicator
                    Circle()
                        .fill(isLoading ? FlowLineTheme.accent : FlowLineTheme.secondTxt.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(FlowLineTheme.mainBg)

                Rectangle()
                    .fill(FlowLineTheme.border)
                    .frame(height: 0.5)

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

                // ── Input bar ────────────────────────────────────────────
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(FlowLineTheme.border)
                        .frame(height: 0.5)

                    // ── Upgrade banner (trial ended or limit hit) ─────────
                    if subscriptionManager.isAtLimit {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(subscriptionManager.trialExpired ? "Your free trial has ended" : "Daily limit reached")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(FlowLineTheme.mainTxt)
                                Text("Upgrade to Flowline Pro to keep planning")
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

                    // ── Messages remaining counter ────────────────────────
                    if !subscriptionManager.isPro && !subscriptionManager.isAtLimit && subscriptionManager.isInTrial {
                        HStack {
                            Spacer()
                            Text("\(subscriptionManager.remainingMessages) messages left today · \(subscriptionManager.trialDaysRemaining)d trial remaining")
                                .font(.system(size: 10))
                                .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    }

                    if hasPlanInChat && !isLoading && !isSaving {
                        HStack {
                            Spacer()
                            Button {
                                _Concurrency.Task { @MainActor in
                                    await calendarService.requestAccess()
                                    var cals = calendarService.writableCalendars()
                                    // EKEventStore can return empty on first access right after launch
                                    // — wait briefly and retry once so the store has time to warm up
                                    if cals.isEmpty {
                                        try? await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 400_000_000)
                                        cals = calendarService.writableCalendars()
                                    }
                                    calendarPickerItems = cals
                                    // Restore last-used calendar, fall back to first
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
                                    Text("Save to Calendar")
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
                    refreshSystemPrompt() // re-run after calendar access granted
                }
            }
            .onChange(of: profiles.first?.name) { refreshSystemPrompt() }
            .onChange(of: profiles.first?.bio) { refreshSystemPrompt() }
            .onChange(of: profiles.first?.wakeTime) { refreshSystemPrompt() }
            .onChange(of: profiles.first?.sleepTime) { refreshSystemPrompt() }
            .onChange(of: profiles.first?.hasWorkHours) { refreshSystemPrompt() }
            .flowlinePaywall(isPresented: $showPaywall, subscriptionManager: subscriptionManager)

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
    }

    // MARK: - Empty State

    // ── Smart time-aware empty state ──────────────────────────────────────────
    private var emptyState: some View {
        VStack(spacing: 24) {

            // ── Icon + streak badge ───────────────────────────────────────────
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    // Outer pulsing glow ring
                    Circle()
                        .fill(FlowLineTheme.accent.opacity(emptyGlow ? 0.12 : 0.04))
                        .frame(width: emptyGlow ? 96 : 80, height: emptyGlow ? 96 : 80)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: emptyGlow)
                    // Mid ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [FlowLineTheme.accent.opacity(0.35), Color(hex: "#8b6dff").opacity(0.15)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 72, height: 72)
                    // Inner fill
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

            // ── Profile quality nudge (shown only when bio is empty) ─────────
            if profiles.first?.bio.isEmpty ?? true {
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

            // ── Quick-start chips ─────────────────────────────────────────────
            VStack(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button {
                        inputText = prompt
                        sendMessage()
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
                    .disabled(isLoading || isSaving)
                }
            }
            .frame(maxWidth: 320)
        }
        .padding(.horizontal, 32)
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
                "Plan my whole day",
                "Deep work morning + meetings afternoon",
                "Light day — just the essentials"
            ]
        } else if hour < 17 {
            return [
                "Structure the rest of my day",
                "I have 3 hours left — what should I do?",
                "Plan tomorrow"
            ]
        } else {
            return [
                "Plan tomorrow",
                "Evening wind-down + tomorrow prep",
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
            aiCard {
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(FlowLineTheme.secondTxt)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
        aiService.updateSystemPrompt(from: profile, calendarContext: combined)
    }

    // MARK: - Send

    private func sendMessage(_ overrideText: String? = nil) {
        let text = overrideText ?? inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isLoading, !isSaving else { return }

        // ── Subscription check ─────────────────────────────────────────────
        guard subscriptionManager.consumeMessage() else {
            showPaywall = true
            return
        }

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
            do {
                let response = try await aiService.sendMessage(history: history, newMessage: text)
                if let jsonData = response.data(using: .utf8),
                   let plan = try? JSONDecoder().decode(GeneratedPlan.self, from: jsonData) {
                    try? planSaver.save(plan: plan, for: Date(), context: modelContext)
                    if let token = authService.token {
                        _Concurrency.Task { await SyncService.shared.pushWeek(for: Date(), token: token, context: modelContext) }
                    }
                    if let index = messages.lastIndex(where: { $0.isThinking }) {
                        messages[index] = Message(role: .assistant, content: plan.summary, isSavedPlan: true)
                    }
                    persistMessage(role: "assistant", content: response)
                    showCalendarBanner = true
                    _Concurrency.Task {
                        try? await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 3_000_000_000)
                        showCalendarBanner = false
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
                // Store for retry
                if claudeError.isRetryable { lastFailedMessage = text }
                messages.append(Message(
                    role: .assistant,
                    content: claudeError.errorDescription ?? "Something went wrong.",
                    isError: true,
                    isRetryable: claudeError.isRetryable
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

    // MARK: - Save Plan

    private var hasPlanInChat: Bool {
        messages.contains { !$0.isThinking && !$0.isSavedPlan && $0.role == .assistant && $0.content.count > 200 }
    }

    private func savePlanToCalendar(toCalendarID calendarID: String? = nil) {
        guard !isSaving else { return }
        isSaving = true
        messages.append(Message(role: .assistant, content: "Saving to calendar...", isThinking: true))

        let history = messages
            .filter { !$0.isThinking && !$0.isSavedPlan }
            .map { msg in (role: msg.role == .user ? "user" : "assistant", content: msg.content) }

        _Concurrency.Task {
            do {
                let plan = try await aiService.generatePlan(for: Date(), history: history)
                try planSaver.save(plan: plan, for: Date(), context: modelContext)
                if let token = authService.token {
                    await SyncService.shared.pushWeek(for: Date(), token: token, context: modelContext)
                }
                try calendarService.savePlan(plan, toCalendarID: calendarID)
                // Remember the calendar the user picked
                if let id = calendarID, !id.isEmpty {
                    lastUsedCalendarID = id
                }
                StreakManager.shared.recordPlan()
                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages[index] = Message(
                        role: .assistant,
                        content: "Plan saved \u{2713}\n\n\(plan.summary)",
                        isSavedPlan: true
                    )
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
