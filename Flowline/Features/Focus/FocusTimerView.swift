import SwiftUI
import SwiftData
import UserNotifications

struct FocusTimerView: View {
    @Query private var dayPlans: [DayPlan]
    @State private var selectedBlock: ScheduleBlock? = nil
    @State private var timeRemaining: TimeInterval = 0
    @State private var totalTime: TimeInterval = 0
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var timerRef: Timer? = nil
    @State private var notificationGranted = false

    private let calendar = Calendar.current

    // MARK: - Body

    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text("FOCUS")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(4)
                        .foregroundColor(FlowLineTheme.secondTxt)
                    Text("Deep work mode")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(FlowLineTheme.mainTxt)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Rectangle()
                    .fill(FlowLineTheme.secondBg.opacity(0.3))
                    .frame(height: 0.5)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // ── Timer Ring ────────────────────────────────────
                        timerRing
                            .padding(.top, 28)

                        // ── Controls ──────────────────────────────────────
                        controls

                        // ── Today's Blocks ────────────────────────────────
                        if !todayBlocks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("TODAY'S BLOCKS")
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(3)
                                    .foregroundColor(FlowLineTheme.secondTxt.opacity(0.6))
                                    .padding(.horizontal, 20)

                                ForEach(todayBlocks, id: \.persistentModelID) { block in
                                    blockRow(block)
                                }
                            }
                        } else {
                            Text("No blocks scheduled for today.\nAsk the AI to plan your day first.")
                                .font(.system(size: 14))
                                .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            requestNotificationPermission()
            if selectedBlock == nil, let first = todayBlocks.first {
                loadBlock(first)
            }
        }
        .onChange(of: todayBlocks.count) {
            if selectedBlock == nil, let first = todayBlocks.first {
                loadBlock(first)
            }
        }
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        let progress: CGFloat = totalTime > 0 ? CGFloat((totalTime - timeRemaining) / totalTime) : 0
        let blockColor = colorForBlock(selectedBlock)

        return VStack(spacing: 16) {
            ZStack {
                // Track
                Circle()
                    .stroke(FlowLineTheme.secondBg.opacity(0.3), lineWidth: 10)
                    .frame(width: 215, height: 215)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        blockColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Center content
                VStack(spacing: 4) {
                    Text(timeString(timeRemaining))
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundColor(FlowLineTheme.mainTxt)

                    if let block = selectedBlock {
                        Text(block.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(FlowLineTheme.secondTxt)
                            .lineLimit(1)
                    } else {
                        Text("Pick a block")
                            .font(.system(size: 12))
                            .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                    }
                }
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 16) {
            // Stop
            if isRunning || isPaused {
                Button {
                    stopTimer()
                } label: {
                    ZStack {
                        Circle()
                            .fill(FlowLineTheme.secondBg.opacity(0.3))
                            .frame(width: 52, height: 52)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 18))
                            .foregroundColor(FlowLineTheme.secondTxt)
                    }
                }
                .buttonStyle(.plain)
            }

            // Start / Pause
            Button {
                if isRunning {
                    pauseTimer()
                } else {
                    startTimer()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(selectedBlock != nil ? FlowLineTheme.accent : FlowLineTheme.secondBg.opacity(0.2))
                        .frame(width: 68, height: 68)
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(selectedBlock != nil ? FlowLineTheme.mainBg : FlowLineTheme.secondTxt.opacity(0.3))
                }
            }
            .buttonStyle(.plain)
            .disabled(selectedBlock == nil)

            // Skip — resets to full time
            if isRunning || isPaused {
                Button {
                    resetTimer()
                } label: {
                    ZStack {
                        Circle()
                            .fill(FlowLineTheme.secondBg.opacity(0.3))
                            .frame(width: 52, height: 52)
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 18))
                            .foregroundColor(FlowLineTheme.secondTxt)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Block Row

    private func blockRow(_ block: ScheduleBlock) -> some View {
        let isSelected = selectedBlock?.persistentModelID == block.persistentModelID
        let color = colorForBlock(block)
        let duration = block.endTime.timeIntervalSince(block.startTime)

        return Button {
            if !isRunning {
                loadBlock(block)
            }
        } label: {
            HStack(spacing: 14) {
                // Color bar
                Capsule()
                    .fill(color)
                    .frame(width: 3, height: 36)

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(block.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(FlowLineTheme.mainTxt)
                    Text(durationString(duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(FlowLineTheme.secondTxt.opacity(0.6))
                }

                Spacer()

                // Time range
                Text(timeRangeString(start: block.startTime, end: block.endTime))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(FlowLineTheme.accent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected
                          ? FlowLineTheme.secondBg.opacity(0.25)
                          : FlowLineTheme.secondBg.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
        .opacity(isRunning && !isSelected ? 0.4 : 1)
    }

    // MARK: - Timer Logic

    private func loadBlock(_ block: ScheduleBlock) {
        stopTimer()
        selectedBlock = block
        let duration = block.endTime.timeIntervalSince(block.startTime)
        totalTime = duration > 0 ? duration : 3600
        timeRemaining = totalTime
    }

    private func startTimer() {
        guard selectedBlock != nil else { return }
        if timeRemaining <= 0 { timeRemaining = totalTime }
        isRunning = true
        isPaused = false

        timerRef = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timerFinished()
            }
        }
    }

    private func pauseTimer() {
        timerRef?.invalidate()
        timerRef = nil
        isRunning = false
        isPaused = true
    }

    private func stopTimer() {
        timerRef?.invalidate()
        timerRef = nil
        isRunning = false
        isPaused = false
        if let block = selectedBlock {
            let duration = block.endTime.timeIntervalSince(block.startTime)
            totalTime = duration > 0 ? duration : 3600
            timeRemaining = totalTime
        }
    }

    private func resetTimer() {
        timerRef?.invalidate()
        timerRef = nil
        isRunning = false
        isPaused = false
        timeRemaining = totalTime
    }

    private func timerFinished() {
        timerRef?.invalidate()
        timerRef = nil
        isRunning = false
        isPaused = false
        timeRemaining = 0
        sendNotification()
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { notificationGranted = granted }
        }
    }

    private func sendNotification() {
        guard notificationGranted else { return }
        let content = UNMutableNotificationContent()
        content.title = "Block complete ✓"
        content.body = "\(selectedBlock?.title ?? "Your session") is done. Take a short break."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    private var todayBlocks: [ScheduleBlock] {
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return dayPlans
            .filter {
                let d = calendar.startOfDay(for: $0.date)
                return d >= today && d < tomorrow
            }
            .flatMap { $0.blocks }
            .sorted { $0.startTime < $1.startTime }
    }

    private func colorForBlock(_ block: ScheduleBlock?) -> Color {
        switch block?.category {
        case .study:    return Color(red: 0.4, green: 0.7, blue: 0.9)
        case .work:     return FlowLineTheme.accent
        case .health:   return FlowLineTheme.secondTxt
        case .personal: return Color(red: 0.8, green: 0.6, blue: 0.9)
        case nil:       return FlowLineTheme.accent
        }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func durationString(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        if m >= 60 {
            let h = m / 60
            let rem = m % 60
            return rem > 0 ? "\(h)h \(rem)m" : "\(h)h"
        }
        return "\(m)m"
    }

    private func timeRangeString(start: Date, end: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: start))–\(fmt.string(from: end))"
    }
}

#Preview {
    FocusTimerView()
}
