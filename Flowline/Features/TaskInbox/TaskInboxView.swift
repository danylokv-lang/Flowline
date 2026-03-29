import SwiftUI
import SwiftData

// MARK: - Helpers

private extension String {
    var categoryColor: Color {
        switch self {
        case "work":     return Color(hex: "#3b82f6")
        case "study":    return Color(hex: "#3b82f6")
        case "health":   return Color(hex: "#22c55e")
        case "personal": return Color(hex: "#f97316")
        default:         return Color(hex: "#3b82f6")
        }
    }

    var categoryIcon: String {
        switch self {
        case "work":     return "briefcase.fill"
        case "study":    return "book.closed.fill"
        case "health":   return "figure.run"
        case "personal": return "person.fill"
        default:         return "briefcase.fill"
        }
    }

    var categoryLabel: String {
        self.prefix(1).uppercased() + self.dropFirst()
    }

    static let allCategories = ["work", "study", "health", "personal"]

    func nextCategory() -> String {
        let cats = String.allCategories
        let idx  = cats.firstIndex(of: self) ?? 0
        return cats[(idx + 1) % cats.count]
    }
}

private func relativeTime(_ date: Date) -> String {
    let s = Int(-date.timeIntervalSinceNow)
    if s < 60  { return "Just now" }
    if s < 3600 { return "\(s / 60)m ago" }
    if s < 86400 { return "\(s / 3600)h ago" }
    return "\(s / 86400)d ago"
}

// MARK: - Filter enum

private enum InboxFilter: String, CaseIterable {
    case all      = "All"
    case pending  = "Pending"
    case done     = "Done"
}

// MARK: - Main View

struct TaskInboxView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @Query(sort: \CapturedTask.createdAt, order: .reverse)
    private var allTasks: [CapturedTask]

    @State private var filter: InboxFilter = .pending
    @State private var inputText  = ""
    @State private var inputCat   = "work"
    @State private var addFocused = false
    @State private var appeared   = false

    private var filtered: [CapturedTask] {
        switch filter {
        case .all:     return allTasks
        case .pending: return allTasks.filter { !$0.isScheduled }
        case .done:    return allTasks.filter {  $0.isScheduled }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            FlowLineTheme.mainBg.ignoresSafeArea()
            CosmosBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ─────────────────────────────────────────────
                header

                Divider().background(FlowLineTheme.border)

                // ── Task list ──────────────────────────────────────────
                if filtered.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 6) {
                            ForEach(filtered) { task in
                                TaskCard(task: task, appeared: appeared) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        task.isScheduled.toggle()
                                    }
                                    if let token = authService.token {
                                        Task { await SyncService.shared.pushInbox([task], token: token) }
                                    }
                                } onDelete: {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        modelContext.delete(task)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 80) // room for input bar
                    }
                }
            }

            // ── Add bar pinned to bottom ───────────────────────────────
            addBar
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Inbox")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(FlowLineTheme.mainTxt)

                let pending = allTasks.filter { !$0.isScheduled }.count
                Text(pending == 0
                     ? "Nothing pending"
                     : "\(pending) task\(pending == 1 ? "" : "s") waiting to be scheduled")
                    .font(.system(size: 12))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }

            Spacer()

            // Filter pills
            HStack(spacing: 6) {
                ForEach(InboxFilter.allCases, id: \.self) { f in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { filter = f }
                    } label: {
                        Text(f.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(filter == f
                                             ? FlowLineTheme.mainTxt
                                             : FlowLineTheme.secondTxt)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                filter == f
                                    ? FlowLineTheme.tertiaryBg
                                    : Color.clear
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    filter == f
                                        ? FlowLineTheme.borderHi
                                        : Color.clear,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(FlowLineTheme.tertiaryBg)
                    .frame(width: 64, height: 64)
                Image(systemName: filter == .done ? "checkmark.circle" : "tray")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(FlowLineTheme.dimTxt)
            }
            Text(filter == .done ? "No completed tasks yet" : "Inbox is empty")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FlowLineTheme.secondTxt)
            Text(filter == .pending
                 ? "Add tasks below — the AI will slot them into your plan when you ask."
                 : "Mark tasks as done to see them here.")
                .font(.system(size: 13))
                .foregroundColor(FlowLineTheme.dimTxt)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Add bar

    private var addBar: some View {
        VStack(spacing: 0) {
            Divider().background(FlowLineTheme.border)

            HStack(spacing: 10) {
                // Category cycle button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        inputCat = inputCat.nextCategory()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: inputCat.categoryIcon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(inputCat.categoryLabel)
                            .font(.system(size: 11, weight: .bold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(inputCat.categoryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(inputCat.categoryColor.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(inputCat.categoryColor.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: inputCat)

                // Text input
                TextField("What needs to get done?", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(FlowLineTheme.mainTxt)
                    .onSubmit { addTask() }

                // Add button
                Button { addTask() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(
                            inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? FlowLineTheme.dimTxt
                                : inputCat.categoryColor
                        )
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                .animation(.easeInOut(duration: 0.2), value: inputText.isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(FlowLineTheme.secondBg)
        }
    }

    // MARK: - Add

    private func addTask() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let task = CapturedTask(text: trimmed, category: inputCat)
        modelContext.insert(task)

        if let token = authService.token {
            Task { await SyncService.shared.pushInbox([task], token: token) }
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            inputText = ""
            if filter == .done { filter = .pending }
        }
    }
}

// MARK: - Task Card

private struct TaskCard: View {
    @Bindable var task: CapturedTask
    let appeared: Bool
    let onComplete: () -> Void
    let onDelete:   () -> Void

    @State private var hovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Color bar
            RoundedRectangle(cornerRadius: 3)
                .fill(task.category.categoryColor)
                .frame(width: 4)
                .padding(.vertical, 4)

            HStack(spacing: 12) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(task.category.categoryColor.opacity(0.14))
                        .frame(width: 34, height: 34)
                    Image(systemName: task.category.categoryIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(task.category.categoryColor)
                }

                // Text + meta
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.text)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(
                            task.isScheduled
                                ? FlowLineTheme.dimTxt
                                : FlowLineTheme.mainTxt
                        )
                        .strikethrough(task.isScheduled, color: FlowLineTheme.dimTxt)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(task.category.categoryLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(task.category.categoryColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(task.category.categoryColor.opacity(0.12))
                            .clipShape(Capsule())

                        Text("·")
                            .foregroundColor(FlowLineTheme.dimTxt)
                            .font(.system(size: 10))

                        Text(relativeTime(task.createdAt))
                            .font(.system(size: 10))
                            .foregroundColor(FlowLineTheme.dimTxt)

                        if task.isScheduled {
                            Text("· Scheduled")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: "#22c55e"))
                        }
                    }
                }

                Spacer()

                // Action buttons (visible on hover)
                HStack(spacing: 6) {
                    // Complete / unschedule
                    Button(action: onComplete) {
                        Image(systemName: task.isScheduled
                              ? "arrow.uturn.left.circle"
                              : "checkmark.circle")
                            .font(.system(size: 16))
                            .foregroundColor(task.isScheduled
                                             ? FlowLineTheme.secondTxt
                                             : Color(hex: "#22c55e"))
                    }
                    .buttonStyle(.plain)
                    .help(task.isScheduled ? "Move back to pending" : "Mark as done")

                    // Delete
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(Color.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Delete task")
                }
                .opacity(hovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: hovered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(hovered
                      ? FlowLineTheme.tertiaryBg
                      : task.category.categoryColor.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            hovered
                                ? task.category.categoryColor.opacity(0.2)
                                : task.category.categoryColor.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .contextMenu {
            Button(task.isScheduled ? "Move back to pending" : "Mark as done") { onComplete() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: appeared)
    }
}

// MARK: - Preview

#Preview {
    TaskInboxView()
        .modelContainer(for: CapturedTask.self, inMemory: true)
        .frame(width: 480, height: 560)
}
