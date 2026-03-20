import SwiftUI
import SwiftData

private enum MenuBarTab { case timer, chat }

struct MenuBarFlowlineView: View {
    @EnvironmentObject var timerManager: FocusTimerManager
    @Query private var dayPlans: [DayPlan]
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var activeTab: MenuBarTab = .timer

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────────
            HStack {
                Text(todayString)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(FlowLineTheme.mainTxt)
                Spacer()
                Button { openSettings() } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button { openWindow(id: "main") } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                        .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Open Flowline")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)

            // ── Tab Switcher ──────────────────────────────────────────────
            HStack(spacing: 0) {
                tabButton("Timer", tab: .timer, icon: "timer")
                tabButton("Quick Chat", tab: .chat, icon: "bubble.left")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Rectangle()
                .fill(FlowLineTheme.borderHi)
                .frame(height: 0.5)

            // ── Content ───────────────────────────────────────────────────
            switch activeTab {
            case .timer: timerContent
            case .chat:  MiniChatView()
            }
        }
        .frame(width: 300)
        .background(FlowLineTheme.mainBg)
    }

    // MARK: - Tab Button

    private func tabButton(_ label: String, tab: MenuBarTab, icon: String) -> some View {
        let selected = activeTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { activeTab = tab }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(selected ? FlowLineTheme.mainBg : FlowLineTheme.secondTxt)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? FlowLineTheme.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timer Content

    private var timerContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                if timerManager.isOnBreak {
                    breakIndicator
                } else if let block = timerManager.selectedBlock {
                    activeBlockRow(block)
                } else {
                    Text("No block selected")
                        .font(.system(size: 13))
                        .foregroundColor(FlowLineTheme.secondTxt.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !todayBlocks.isEmpty {
                Rectangle().fill(FlowLineTheme.borderHi).frame(height: 0.5)
                VStack(spacing: 2) {
                    Text("TODAY")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(3)
                        .foregroundColor(FlowLineTheme.secondTxt.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    ForEach(todayBlocks.prefix(5), id: \.persistentModelID) { block in
                        menuBlockRow(block)
                    }
                }
                .padding(.bottom, 10)
            }
        }
    }

    // MARK: - Break Indicator

    private var breakIndicator: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(FlowLineTheme.borderHi, lineWidth: 4)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: timerManager.progress)
                    .stroke(Color(red: 0.4, green: 0.8, blue: 0.6),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerManager.progress)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Break").font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FlowLineTheme.mainTxt)
                Text(timerManager.timeString())
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }
            Spacer()
            Button { timerManager.endBreak() } label: {
                Text("Skip").font(.system(size: 11, weight: .semibold))
                    .foregroundColor(FlowLineTheme.secondTxt)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(FlowLineTheme.borderHi)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Active Block Row

    private func activeBlockRow(_ block: ScheduleBlock) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(FlowLineTheme.borderHi, lineWidth: 4)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: timerManager.progress)
                    .stroke(colorForBlock(block),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerManager.progress)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title).font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FlowLineTheme.mainTxt).lineLimit(1)
                Text(timerManager.timeString())
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }
            Spacer()
            Button {
                if timerManager.isRunning { timerManager.pause() }
                else { timerManager.start() }
            } label: {
                Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 13)).foregroundColor(FlowLineTheme.mainBg)
                    .frame(width: 30, height: 30).background(colorForBlock(block))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            if timerManager.isRunning || timerManager.isPaused {
                Button { timerManager.stop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11)).foregroundColor(FlowLineTheme.secondTxt)
                        .frame(width: 28, height: 28)
                        .background(FlowLineTheme.borderHi).clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Block Row

    private func menuBlockRow(_ block: ScheduleBlock) -> some View {
        let isSelected = timerManager.selectedBlock?.persistentModelID == block.persistentModelID
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        return Button {
            if !timerManager.isRunning { timerManager.loadBlock(block) }
        } label: {
            HStack(spacing: 10) {
                Capsule().fill(colorForBlock(block)).frame(width: 2, height: 24)
                Text(block.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? FlowLineTheme.mainTxt : FlowLineTheme.secondTxt)
                    .lineLimit(1)
                Spacer()
                Text(fmt.string(from: block.startTime))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(FlowLineTheme.secondTxt.opacity(0.4))
                if isSelected { Circle().fill(FlowLineTheme.accent).frame(width: 5, height: 5) }
            }
            .padding(.horizontal, 16).padding(.vertical, 5).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(timerManager.isRunning && !isSelected ? 0.5 : 1)
    }

    // MARK: - Helpers

    private var todayBlocks: [ScheduleBlock] {
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return dayPlans
            .filter { let d = calendar.startOfDay(for: $0.date); return d >= today && d < tomorrow }
            .flatMap { $0.blocks }.sorted { $0.startTime < $1.startTime }
    }

    private var todayString: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f.string(from: Date())
    }

    private func colorForBlock(_ block: ScheduleBlock) -> Color {
        switch block.category {
        case .study:    return Color(red: 0.4, green: 0.7, blue: 0.9)
        case .work:     return FlowLineTheme.accent
        case .health:   return FlowLineTheme.secondTxt
        case .personal: return Color(red: 0.8, green: 0.6, blue: 0.9)
        case nil:       return FlowLineTheme.accent
        }
    }
}

// MARK: - Mini Chat View

private struct MiniChatView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("currentSessionID") private var currentSessionID: String = UUID().uuidString
    @State private var inputText = ""
    @State private var isSending = false
    @State private var state: ChatState = .idle

    private let aiService = ClaudePlanningService(apiKey: "")

    private enum ChatState { case idle, sending, done, error }

    var body: some View {
        VStack(spacing: 16) {
            switch state {
            case .idle, .sending:
                idleView
            case .done:
                doneView
            case .error:
                errorView
            }
        }
        .padding(16)
        .frame(minHeight: 80)
    }

    // ── Idle / Sending ────────────────────────────────────────────────────

    private var idleView: some View {
        VStack(spacing: 10) {
            Text("Ask AI anything")
                .font(.system(size: 11, weight: .heavy))
                .tracking(2)
                .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                MiniTextField(text: $inputText, placeholder: "Plan my evening…", onSubmit: send)
                    .frame(height: 32)

                Button { send() } label: {
                    ZStack {
                        Circle()
                            .fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isSending
                                  ? FlowLineTheme.borderHi
                                  : FlowLineTheme.accent)
                            .frame(width: 30, height: 30)
                        if isSending {
                            ProgressView()
                                .scaleEffect(0.55)
                                .tint(FlowLineTheme.secondTxt)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(
                                    inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? FlowLineTheme.secondTxt.opacity(0.3)
                                    : FlowLineTheme.mainBg
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            }

            if isSending {
                HStack(spacing: 6) {
                    Circle().fill(FlowLineTheme.accent).frame(width: 4, height: 4)
                        .opacity(0.8)
                    Text("AI is thinking…")
                        .font(.system(size: 11))
                        .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // ── Done ──────────────────────────────────────────────────────────────

    private var doneView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(FlowLineTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Response ready")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(FlowLineTheme.mainTxt)
                    Text("Open Flowline to see it")
                        .font(.system(size: 11))
                        .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                }
                Spacer()
            }
            Button {
                state = .idle
                inputText = ""
            } label: {
                Text("Send another")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FlowLineTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(FlowLineTheme.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // ── Error ─────────────────────────────────────────────────────────────

    private var errorView: some View {
        VStack(spacing: 8) {
            Text("Something went wrong")
                .font(.system(size: 13))
                .foregroundColor(FlowLineTheme.mainTxt)
            Button {
                state = .idle
            } label: {
                Text("Try again")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FlowLineTheme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    // ── Send ──────────────────────────────────────────────────────────────

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isSending else { return }

        let sessionID   = UUID().uuidString
        let sessionDate = Date()

        // Save user message + set as current session so app opens to it
        let userMsg = ChatMessage(role: "user", content: text,
                                  sessionDate: sessionDate, sessionID: sessionID)
        context.insert(userMsg)
        currentSessionID = sessionID
        isSending = true
        state = .sending

        Task {
            do {
                let response = try await aiService.sendMessage(history: [], newMessage: text)
                let aiMsg = ChatMessage(role: "assistant", content: response,
                                        sessionDate: sessionDate, sessionID: sessionID)
                context.insert(aiMsg)
                isSending = false
                state = .done
            } catch {
                isSending = false
                state = .error
            }
        }
    }
}

// MARK: - Mini NSTextField wrapper

private struct MiniTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let f = NSTextField()
        f.placeholderString = placeholder
        f.font = .systemFont(ofSize: 13)
        f.textColor = NSColor(FlowLineTheme.mainTxt)
        f.backgroundColor = NSColor(FlowLineTheme.border)
        f.isBordered = false
        f.focusRingType = .none
        f.bezelStyle = .roundedBezel
        f.delegate = context.coordinator
        return f
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: MiniTextField
        init(_ parent: MiniTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                parent.text = field.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit(); return true
            }
            return false
        }
    }
}
