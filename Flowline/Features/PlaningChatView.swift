import SwiftUI
import Combine
import SwiftData

struct Message: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    var isThinking: Bool = false

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
    @Query private var profiles: [UserProfile]
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    private let aiService = GeminiPlanningService(apiKey: Config.geminiAPIKey)

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

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .font(.system(size: 24))
                        .foregroundColor(FlowLineTheme.accent)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(FlowLineTheme.mainBg)
        }
        .background(FlowLineTheme.mainBg)
        .animation(.easeOut(duration: 0.3), value: messages.isEmpty)
        .onAppear {
            if let profile = profiles.first {
                aiService.updateSystemPrompt(from: profile)
            }
        }
        .onChange(of: profiles.count) {
            if let profile = profiles.first {
                aiService.updateSystemPrompt(from: profile)
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

        // Build history from existing messages BEFORE adding the new one
        let history = messages
            .filter { !$0.isThinking }
            .map { msg in
                (role: msg.role == .user ? "user" : "assistant", content: msg.content)
            }

        messages.append(Message(role: .user, content: text))
        inputText = ""
        isLoading = true

        // Show thinking indicator
        messages.append(Message(role: .assistant, content: "Thinking...", isThinking: true))

        Task {
            do {
                let response = try await aiService.sendMessage(history: history, newMessage: text)
                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages[index] = Message(role: .assistant, content: response)
                }
            } catch {
                // Replace thinking message with error
                if let index = messages.lastIndex(where: { $0.isThinking }) {
                    messages[index] = Message(role: .assistant, content: "Something went wrong: \(error.localizedDescription)")
                }
            }
            isLoading = false
        }
    }
}

#Preview {
    PlanningChatView()
}