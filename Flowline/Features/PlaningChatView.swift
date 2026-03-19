import SwiftUI
import Combine
import SwiftData

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
    @Query(sort: \ChatMessage.timestamp) private var savedMessages: [ChatMessage]
    @Query private var profiles: [UserProfile]
    @Binding var selectedTab: Int
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var isLoading: Bool = false
    @State private var isSaving: Bool = false
    @State private var didLoadHistory = false
    @State private var showCalendarBanner = false
    @State private var showSidebar = false
    @State private var showPaywall = false
    @State private var lastFailedMessage: String? = nil
    @State private var editorHeight: CGFloat = 17
    @AppStorage("currentSessionID") private var currentSessionID: String = UUID().uuidString
    @StateObject private var aiService = ClaudePlanningService(apiKey: Config.claudeAPIKey)
    private let planSaver = PlanSavingService()

    var body: some View {
        ZStack(alignment: .leading) {
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
                        .foregroundColor(FlowLineTheme.mainTxt)

                    Spacer()

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

                    if hasPlanInChat && !isLoading && !isSaving {
                        HStack {
                            Spacer()
                            Button { savePlanToCalendar() } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("Save to Calendar")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(FlowLineTheme.accent)
                                .clipShape(Capsule())
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
                                guard !trimmed.isEmpty, !isLoading, !isSaving else { return }
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
                                        inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading || isSaving
                                            ? FlowLineTheme.tertiaryBg
                                            : FlowLineTheme.accent
                                    )
                                    .frame(width: 36, height: 36)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(
                                        inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading || isSaving
                                            ? FlowLineTheme.secondTxt.opacity(0.3)
                                            : FlowLineTheme.mainBg
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading || isSaving)
                        .padding(.bottom, 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .background(FlowLineTheme.mainBg)
            }
            .background(FlowLineTheme.mainBg)
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
            }
            .onChange(of: profiles.first?.name) { refreshSystemPrompt() }
            .onChange(of: profiles.first?.bio) { refreshSystemPrompt() }
            .onChange(of: profiles.first?.wakeTime) { refreshSystemPrompt() }
            .onChange(of: profiles.first?.sleepTime) { refreshSystemPrompt() }
            .onChange(of: profiles.first?.hasWorkHours) { refreshSystemPrompt() }
            .sheet(isPresented: $showPaywall) {
                PaywallView { showPaywall = false }
                    .environmentObject(subscriptionManager)
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
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("FL")
                .font(.system(size: 72, weight: .black))
                .foregroundColor(FlowLineTheme.tertiaryBg.opacity(0.8))
                .tracking(-2)

            VStack(spacing: 4) {
                Text("What's on your mind?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(FlowLineTheme.mainTxt)
                Text("Dump your tasks — I'll plan it.")
                    .font(.system(size: 14))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }
        }
    }

    // MARK: - Chat Bubble

    @ViewBuilder
    private func chatBubble(_ message: Message) -> some View {
        if message.role == .user {
            // User: right-aligned pill
            HStack {
                Spacer(minLength: 64)
                Text(message.content)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundColor(FlowLineTheme.mainTxt)
                    .background(FlowLineTheme.tertiaryBg)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .textSelection(.enabled)
            }
        } else if message.isThinking {
            // Thinking: left border + shimmer
            HStack(alignment: .top, spacing: 12) {
                Capsule()
                    .fill(FlowLineTheme.accent.opacity(0.4))
                    .frame(width: 2)
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(FlowLineTheme.secondTxt)
                    .modifier(ShimmerModifier())
                Spacer(minLength: 40)
            }
        } else if message.isSavedPlan {
            // Saved plan: solid accent border + view calendar button
            HStack(alignment: .top, spacing: 12) {
                Capsule()
                    .fill(FlowLineTheme.accent)
                    .frame(width: 2)
                VStack(alignment: .leading, spacing: 10) {
                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundColor(FlowLineTheme.secondTxt)
                        .textSelection(.enabled)
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
                Spacer(minLength: 40)
            }
        } else if message.isError {
            // Error bubble with optional retry
            HStack(alignment: .top, spacing: 12) {
                Capsule()
                    .fill(Color.red.opacity(0.5))
                    .frame(width: 2)
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
                            .background(Color.red.opacity(0.6))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 40)
            }
        } else {
            // AI: editorial left-border, no background
            HStack(alignment: .top, spacing: 12) {
                Capsule()
                    .fill(FlowLineTheme.borderHi)
                    .frame(width: 2)
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(FlowLineTheme.secondTxt)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Helpers

    private func refreshSystemPrompt() {
        guard let profile = profiles.first else { return }
        let ctx = try? planSaver.calendarContext(forWeekOf: Date(), context: modelContext)
        aiService.updateSystemPrompt(from: profile, calendarContext: ctx)
    }

    // MARK: - Send

    private func sendMessage(_ overrideText: String? = nil) {
        let text = overrideText ?? inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isLoading else { return }

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
    }

    // MARK: - Save Plan

    private var hasPlanInChat: Bool {
        messages.contains { !$0.isThinking && !$0.isSavedPlan && $0.role == .assistant && $0.content.count > 200 }
    }

    private func savePlanToCalendar() {
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
                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages[index] = Message(
                        role: .assistant,
                        content: "Plan saved \u{2713}\n\n\(plan.summary)",
                        isSavedPlan: true
                    )
                }
            } catch {
                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages[index] = Message(role: .assistant, content: "Failed: \(error.localizedDescription)")
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
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(4)
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
                        .font(.system(size: 15, weight: .medium))
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
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(
                                            session.id == currentSessionID
                                                ? FlowLineTheme.accent
                                                : FlowLineTheme.mainTxt
                                        )
                                    Text(session.preview)
                                        .font(.system(size: 12))
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
                                    .font(.system(size: 10, weight: .medium))
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

#Preview {
    PlanningChatView(selectedTab: .constant(0))
}
