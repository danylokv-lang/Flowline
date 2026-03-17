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
    @State private var showSidebar = false
    @AppStorage("currentSessionID") private var currentSessionID: String = UUID().uuidString
    private var currentSessionDate: Date { Date() }
    private let aiService = ClaudePlanningService(apiKey: Config.claudeAPIKey)
    private let planSaver = PlanSavingService()

    var body: some View {
        ZStack(alignment: .leading) {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSidebar.toggle()
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(FlowLineTheme.mainTxt)
                }
                Spacer()
                Text("Flowline")
                    .font(.headline)
                    .foregroundColor(FlowLineTheme.mainTxt)
                Spacer()
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .opacity(0)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(FlowLineTheme.mainBg)

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

            // Sidebar overlay
            if showSidebar {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSidebar = false
                        }
                    }

                sidebarView
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showSidebar)
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
            Button {
                currentSessionID = UUID().uuidString
                messages = []
                didLoadHistory = false
                withAnimation(.easeInOut(duration: 0.25)) {
                    showSidebar = false
                }
            } label: {
                HStack {
                    Image(systemName: "plus.bubble")
                    Text("New Chat")
                }
                .font(.headline)
                .foregroundColor(FlowLineTheme.mainTxt)
                .padding()
            }

            Divider().background(FlowLineTheme.mainTxt.opacity(0.2))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sessions, id: \.id) { session in
                        HStack(spacing: 0) {
                            Button {
                                currentSessionID = session.id
                                didLoadHistory = false
                                loadSession(id: session.id)
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showSidebar = false
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.date, style: .date)
                                        .font(.subheadline.bold())
                                        .foregroundColor(FlowLineTheme.mainTxt)
                                    Text(session.preview)
                                        .font(.caption)
                                        .foregroundColor(FlowLineTheme.secondTxt)
                                        .lineLimit(2)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                deleteSession(id: session.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(FlowLineTheme.secondTxt.opacity(0.6))
                                    .padding(.trailing, 12)
                            }
                        }
                        .background(
                            session.id == currentSessionID
                                ? FlowLineTheme.mainBg.opacity(0.3)
                                : Color.clear
                        )
                    }
                }
            }
        }
        .frame(width: 280)
        .background(FlowLineTheme.secondBg)
    }
}

#Preview {
    PlanningChatView(selectedTab: .constant(0))
}