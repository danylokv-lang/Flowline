import SwiftUI
import Combine
import SwiftData

struct Message: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    var isThinking: Bool = false
    var isSavedPlan: Bool = false

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
                        colors: [
                            .clear,
                            FlowLineTheme.mainTxt.opacity(0.25),
                            .clear
                        ],
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
                withAnimation(.linear(duration: 1.5)) {
                    phase = 1
                }
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
    @State private var isLoading: Bool = false
    @State private var isSaving: Bool = false
    @State private var didLoadHistory = false
    @State private var showCalendarBanner = false
    private let aiService = ClaudePlanningService(apiKey: Config.claudeAPIKey)
    private let planSaver = PlanSavingService()

    var body: some View {
        VStack(spacing: 0) {
            // Chat area or welcome screen
            if messages.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text("Flowline")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(FlowLineTheme.mainTxt)
                    Text("Plan your day with AI")
                        .font(.title3)
                        .foregroundColor(FlowLineTheme.secondTxt)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                chatBubble(message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Input bar
            HStack(spacing: 12) {
                TextField("Dump your tasks here...", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(.regularMaterial)
                    .cornerRadius(12)
                    .foregroundColor(FlowLineTheme.mainTxt)
                    .onSubmit { sendMessage() }

                if hasPlanInChat && !isLoading && !isSaving {
                    Button {
                        savePlanToCalendar()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.plus")
                            Text("Save")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(FlowLineTheme.mainBg)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(FlowLineTheme.accent)
                        .cornerRadius(10)
                    }
                }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .font(.system(size: 24))
                        .foregroundColor(FlowLineTheme.accent)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading || isSaving)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(FlowLineTheme.mainBg)
        }
        .background(FlowLineTheme.mainBg)
        .animation(.easeOut(duration: 0.3), value: messages.isEmpty)
        .overlay(alignment: .top) {
            if showCalendarBanner {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Calendar updated \u{2713}")
                }
                .font(.subheadline.bold())
                .foregroundColor(FlowLineTheme.mainBg)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(FlowLineTheme.accent)
                .cornerRadius(12)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCalendarBanner)
        .onAppear {
            if let profile = profiles.first {
                let ctx = try? planSaver.calendarContext(forWeekOf: Date(), context: modelContext)
                aiService.updateSystemPrompt(from: profile, calendarContext: ctx)
            }
            loadHistory()
        }
        .onChange(of: profiles.count) {
            if let profile = profiles.first {
                let ctx = try? planSaver.calendarContext(forWeekOf: Date(), context: modelContext)
                aiService.updateSystemPrompt(from: profile, calendarContext: ctx)
            }
        }
    }

    // MARK: - Chat Bubble
    @ViewBuilder
    private func chatBubble(_ message: Message) -> some View {
        HStack {
            if message.role == .user { Spacer() }

            Group {
                if message.isThinking {
                    Text(message.content)
                        .padding(12)
                        .foregroundColor(FlowLineTheme.secondTxt)
                        .background(FlowLineTheme.secondBg.opacity(0.3))
                        .cornerRadius(16)
                        .modifier(ShimmerModifier())
                } else if message.isSavedPlan {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(message.content)
                            .foregroundColor(FlowLineTheme.secondTxt)

                        Button {
                            selectedTab = 1
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text("View Calendar")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(FlowLineTheme.mainBg)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(FlowLineTheme.accent)
                            .cornerRadius(10)
                        }
                    }
                    .padding(12)
                    .background(FlowLineTheme.secondBg.opacity(0.3))
                    .cornerRadius(16)
                } else {
                    Text(message.content)
                        .padding(12)
                        .foregroundColor(
                            message.role == .user
                                ? FlowLineTheme.mainTxt
                                : FlowLineTheme.secondTxt
                        )
                        .background(
                            message.role == .user
                                ? FlowLineTheme.secondBg
                                : FlowLineTheme.secondBg.opacity(0.3)
                        )
                        .cornerRadius(16)
                }
            }

            if message.role == .assistant { Spacer() }
        }
    }

    // MARK: - Send
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isLoading else { return }

        // Build history from ALL saved messages for AI context
        let history = savedMessages.map { msg in
            (role: msg.role, content: msg.content)
        }

        messages.append(Message(role: .user, content: text))
        persistMessage(role: "user", content: text)
        inputText = ""
        isLoading = true

        // Show thinking indicator
        messages.append(Message(role: .assistant, content: "Thinking...", isThinking: true))

        _Concurrency.Task {
            // Refresh calendar context before each request
            if let profile = profiles.first {
                let ctx = try? planSaver.calendarContext(forWeekOf: Date(), context: modelContext)
                aiService.updateSystemPrompt(from: profile, calendarContext: ctx)
            }

            do {
                let response = try await aiService.sendMessage(history: history, newMessage: text)

                // Try to decode as a plan
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
            } catch {
                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages[index] = Message(role: .assistant, content: "Something went wrong: \(error.localizedDescription)")
                }
            }
            isLoading = false
        }
    }

    // MARK: - Persistence

    private func loadHistory() {
        guard !didLoadHistory else { return }
        didLoadHistory = true
        let recent = savedMessages.suffix(50)
        messages = recent.map { msg in
            Message(role: msg.role == "user" ? .user : .assistant, content: msg.content)
        }
    }

    private func persistMessage(role: String, content: String) {
        let chatMsg = ChatMessage(
            role: role,
            content: content,
            sessionDate: Calendar.current.startOfDay(for: Date())
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
            .map { msg in
                (role: msg.role == .user ? "user" : "assistant", content: msg.content)
            }

        _Concurrency.Task {
            do {
                let plan = try await aiService.generatePlan(for: Date(), history: history)
                try planSaver.save(plan: plan, for: Date(), context: modelContext)
                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages[index] = Message(role: .assistant, content: "Plan saved to calendar \u{2713}\n\n\(plan.summary)", isSavedPlan: true)
                }
            } catch {
                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages[index] = Message(role: .assistant, content: "Failed to save plan: \(error.localizedDescription)")
                }
            }
            isSaving = false
        }
    }
}

#Preview {
    PlanningChatView(selectedTab: .constant(0))
}