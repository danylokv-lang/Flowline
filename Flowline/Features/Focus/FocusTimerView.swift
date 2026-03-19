import SwiftUI
import SwiftData

struct FocusTimerView: View {
    @EnvironmentObject var timerManager: FocusTimerManager
    @Query private var dayPlans: [DayPlan]

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
            timerManager.requestPermission()
            if timerManager.selectedBlock == nil, let first = todayBlocks.first {
                timerManager.loadBlock(first)
            }
        }
        .onChange(of: todayBlocks.count) {
            if timerManager.selectedBlock == nil, let first = todayBlocks.first {
                timerManager.loadBlock(first)
            }
        }
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        let blockColor = colorForBlock(timerManager.selectedBlock)

        return VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(FlowLineTheme.secondBg.opacity(0.3), lineWidth: 10)
                    .frame(width: 215, height: 215)

                Circle()
                    .trim(from: 0, to: timerManager.progress)
                    .stroke(blockColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerManager.progress)

                VStack(spacing: 4) {
                    Text(timerManager.timeString())
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundColor(FlowLineTheme.mainTxt)

                    if let block = timerManager.selectedBlock {
                        Text(block.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(FlowLineTheme.secondTxt)
                            .lineLimit(1)
                    } else {
                        Text("Pick a block below")
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
            if timerManager.isRunning || timerManager.isPaused {
                Button { timerManager.stop() } label: {
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

            Button {
                if timerManager.isRunning { timerManager.pause() }
                else { timerManager.start() }
            } label: {
                ZStack {
                    Circle()
                        .fill(timerManager.selectedBlock != nil
                              ? FlowLineTheme.accent
                              : FlowLineTheme.secondBg.opacity(0.2))
                        .frame(width: 68, height: 68)
                    Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(timerManager.selectedBlock != nil
                                         ? FlowLineTheme.mainBg
                                         : FlowLineTheme.secondTxt.opacity(0.3))
                }
            }
            .buttonStyle(.plain)
            .disabled(timerManager.selectedBlock == nil)

            if timerManager.isRunning || timerManager.isPaused {
                Button { timerManager.reset() } label: {
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
        let isSelected = timerManager.selectedBlock?.persistentModelID == block.persistentModelID
        let color = colorForBlock(block)
        let duration = block.endTime.timeIntervalSince(block.startTime)

        return Button {
            if !timerManager.isRunning { timerManager.loadBlock(block) }
        } label: {
            HStack(spacing: 14) {
                Capsule()
                    .fill(color)
                    .frame(width: 3, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(block.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(FlowLineTheme.mainTxt)
                    Text(durationString(duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(FlowLineTheme.secondTxt.opacity(0.6))
                }

                Spacer()

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
        .disabled(timerManager.isRunning)
        .opacity(timerManager.isRunning && !isSelected ? 0.4 : 1)
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

    private func durationString(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        if m >= 60 { let h = m / 60; let r = m % 60; return r > 0 ? "\(h)h \(r)m" : "\(h)h" }
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
