import SwiftUI
import SwiftData

// MARK: - Period

enum StatsPeriod: String, CaseIterable {
    case today = "Today"
    case week  = "Week"
    case month = "Month"
}

// MARK: - StatsView

struct StatsView: View {
    @Query private var dayPlans: [DayPlan]
    /// Direct block query — avoids SwiftData lazy-loading relationships on iOS
    @Query private var allBlocks: [ScheduleBlock]
    @EnvironmentObject private var colorManager: CategoryColorManager
    @ObservedObject private var streak = StreakManager.shared

    @State private var period: StatsPeriod = .week

    private let cal = Calendar.current

    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()
            CosmosBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerRow
                    periodPicker
                    outcomeSection
                    streakRow
                    hoursSection
                    if let peak = peakFocusHour { peakSection(hour: peak) }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
    }

    // ── Header ───────────────────────────────────────────────────────────────

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("INSIGHTS")
                .font(.system(size: 11, weight: .bold))
                .tracking(4)
                .foregroundColor(FlowLineTheme.secondTxt.opacity(0.55))
            Text("Your stats")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FlowLineTheme.mainTxt, Color(hex: "#93c5fd").opacity(0.9)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
        }
    }

    // ── Period Picker ─────────────────────────────────────────────────────────

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(StatsPeriod.allCases, id: \.self) { p in
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(period == p ? FlowLineTheme.accent : Color.clear)
                        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: period)

                    Text(p.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(period == p ? .white : FlowLineTheme.secondTxt)
                        .padding(.vertical, 9)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { period = p }
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(FlowLineTheme.secondBg.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(FlowLineTheme.borderHi.opacity(0.4), lineWidth: 1)
                )
        )
    }

    // ── Task Outcome Section ──────────────────────────────────────────────────

    private var outcomeSection: some View {
        let (done, partly, skipped, noData) = completionStats
        let total     = done + partly + skipped + noData
        let rated     = done + partly + skipped
        let rate      = rated > 0 ? Double(done + partly) / Double(rated) : nil
        let periodLabel = period == .today ? "today" : period == .week ? "this week" : "this month"

        return VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack {
                chipLabel("OUTCOMES")
                Spacer()
                if let r = rate {
                    Text(String(format: "%.0f%% done", r * 100))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(FlowLineTheme.accent)
                }
            }

            if filteredBlocks.isEmpty {
                emptyHint("No blocks \(periodLabel) — start by planning your day.")
            } else {
                // 2 × 2 cards
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        outcomeCard(sfSymbol: "checkmark.circle.fill",
                                    label: "Done",        count: done,   total: total,
                                    color: Color(hex: "#22c55e"))
                        outcomeCard(sfSymbol: "circle.lefthalf.filled",
                                    label: "Partly",      count: partly, total: total,
                                    color: Color(hex: "#f97316"))
                    }
                    HStack(spacing: 8) {
                        outcomeCard(sfSymbol: "minus.circle.fill",
                                    label: "Skipped",     count: skipped, total: total,
                                    color: Color(hex: "#ef4444"))
                        outcomeCard(sfSymbol: "circle.dashed",
                                    label: "No check-in", count: noData,  total: total,
                                    color: FlowLineTheme.dimTxt)
                    }
                }

                // Stacked proportion bar
                stackedBar(done: done, partly: partly, skipped: skipped, noData: noData, total: total)
            }
        }
        .padding(16)
        .background(cardBg)
    }

    private func outcomeCard(sfSymbol: String, label: String,
                              count: Int, total: Int, color: Color) -> some View {
        let pct = total > 0 ? Double(count) / Double(total) : 0
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
                Text(String(format: "%.0f%%", pct * 100))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(color.opacity(0.75))
            }
            Text("\(count)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(FlowLineTheme.mainTxt)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(FlowLineTheme.secondTxt)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(color.opacity(count > 0 ? 0.25 : 0.1), lineWidth: 1)
                )
        )
    }

    private func stackedBar(done: Int, partly: Int, skipped: Int, noData: Int, total: Int) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let gap: CGFloat = 2
            let dW  = CGFloat(done)   / CGFloat(total) * w
            let pW  = CGFloat(partly) / CGFloat(total) * w
            let sW  = CGFloat(skipped) / CGFloat(total) * w

            HStack(spacing: gap) {
                if done > 0 {
                    Capsule().fill(Color(hex: "#22c55e")).frame(width: max(dW - gap, 2))
                }
                if partly > 0 {
                    Capsule().fill(Color(hex: "#f97316")).frame(width: max(pW - gap, 2))
                }
                if skipped > 0 {
                    Capsule().fill(Color(hex: "#ef4444")).frame(width: max(sW - gap, 2))
                }
                if noData > 0 {
                    Capsule().fill(FlowLineTheme.dimTxt.opacity(0.25)).frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 7)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: done + partly + skipped)
    }

    // ── Streak Row ────────────────────────────────────────────────────────────

    private var streakRow: some View {
        HStack(spacing: 10) {
            miniStatCard(emoji: "🔥", value: "\(streak.currentStreak)", label: "Streak",  accent: .orange)
            miniStatCard(emoji: "🏆", value: "\(streak.longestStreak)", label: "Best",    accent: Color(hex: "#f59e0b"))
            miniStatCard(emoji: "📅", value: "\(totalDaysPlanned)",     label: "Planned", accent: FlowLineTheme.accent)
        }
    }

    private func miniStatCard(emoji: String, value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 5) {
            Text(emoji).font(.system(size: 20))
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(accent)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(FlowLineTheme.secondTxt)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(cardBg)
    }

    // ── Hours Section ─────────────────────────────────────────────────────────

    private var hoursSection: some View {
        let stats = hoursBreakdown
        let total = stats.values.reduce(0, +)
        let title = period == .today ? "TODAY'S HOURS" : period == .week ? "THIS WEEK" : "THIS MONTH"

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                chipLabel(title)
                Spacer()
                Text(String(format: "%.1f h", total))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(FlowLineTheme.accent)
            }

            if total == 0 {
                emptyHint("No time blocks in this period yet.")
            } else {
                VStack(spacing: 9) {
                    ForEach([Category.work, .study, .health, .personal], id: \.self) { cat in
                        if let hours = stats[cat], hours > 0 {
                            categoryBar(cat: cat, hours: hours, maxHours: stats.values.max() ?? 1)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(cardBg)
    }

    private func categoryBar(cat: Category, hours: Double, maxHours: Double) -> some View {
        let color = colorManager.color(for: cat)
        let pct   = maxHours > 0 ? hours / maxHours : 0

        return HStack(spacing: 10) {
            Text(cat.rawValue.capitalized)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(FlowLineTheme.secondTxt)
                .frame(width: 56, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.1))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [color, color.opacity(0.55)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(pct), height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pct)
                }
            }
            .frame(height: 8)

            Text(String(format: "%.1fh", hours))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 32, alignment: .trailing)
        }
    }

    // ── Peak Focus Time ───────────────────────────────────────────────────────

    private func peakSection(hour: Int) -> some View {
        let label = hour < 12 ? "morning" : hour < 17 ? "afternoon" : "evening"
        let emoji = hour < 12 ? "☀️" : hour < 17 ? "🌤" : "🌙"
        let range = "\(String(format: "%02d", hour)):00–\(String(format: "%02d", (hour + 1) % 24)):00"

        return VStack(alignment: .leading, spacing: 14) {
            chipLabel("PEAK FOCUS TIME")
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your \(label) — \(range)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(FlowLineTheme.mainTxt)
                    Text("Most of your Done blocks fall in this slot.")
                        .font(.system(size: 11))
                        .foregroundColor(FlowLineTheme.secondTxt)
                }
            }
        }
        .padding(16)
        .background(cardBg)
    }

    // ── Shared UI ─────────────────────────────────────────────────────────────

    private func chipLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(2)
            .foregroundColor(FlowLineTheme.dimTxt)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(FlowLineTheme.dimTxt)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(FlowLineTheme.secondBg.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FlowLineTheme.borderHi.opacity(0.45), lineWidth: 1)
            )
    }

    // ── Data ──────────────────────────────────────────────────────────────────

    private var periodRange: (start: Date, end: Date) {
        let today = cal.startOfDay(for: Date())
        switch period {
        case .today:
            return (today, cal.date(byAdding: .day, value: 1, to: today)!)
        case .week:
            let weekday = cal.component(.weekday, from: today)
            let delta   = weekday == 1 ? -6 : -(weekday - 2)
            let start   = cal.date(byAdding: .day, value: delta, to: today)!
            return (start, cal.date(byAdding: .day, value: 7, to: start)!)
        case .month:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: today))!
            return (start, cal.date(byAdding: .month, value: 1, to: start)!)
        }
    }

    /// Blocks whose startTime falls within the selected period.
    /// Uses the direct @Query instead of DayPlan.blocks to avoid SwiftData
    /// lazy-relationship loading returning empty arrays on iOS.
    private var filteredBlocks: [ScheduleBlock] {
        let (start, end) = periodRange
        return allBlocks.filter { $0.startTime >= start && $0.startTime < end }
    }

    /// (done, partly, skipped, noCheckIn) for blocks in the selected period.
    /// Done/Partly/Skipped: all blocks regardless of time (check-in can be set any time).
    /// No check-in: only past blocks (endTime <= now) that were never rated.
    private var completionStats: (Int, Int, Int, Int) {
        var done = 0, partly = 0, skipped = 0, noData = 0
        let now = Date()
        for block in filteredBlocks {
            switch block.checkInResult {
            case .done:    done    += 1
            case .partly:  partly  += 1
            case .skipped: skipped += 1
            case .none:    if block.endTime <= now { noData += 1 }
            }
        }
        return (done, partly, skipped, noData)
    }

    /// Hours per category for the selected period (all blocks, not just past ones).
    private var hoursBreakdown: [Category: Double] {
        var result: [Category: Double] = [:]
        for block in filteredBlocks {
            let hours = block.endTime.timeIntervalSince(block.startTime) / 3600.0
            result[block.category ?? .personal, default: 0] += hours
        }
        return result
    }

    /// Hour of day (0-23) with the most Done check-ins in the selected period.
    private var peakFocusHour: Int? {
        var counts = [Int: Int]()
        for block in filteredBlocks where block.checkInResult == .done {
            counts[cal.component(.hour, from: block.startTime), default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Total number of day plans ever created (not filtered — used for streak card).
    private var totalDaysPlanned: Int { dayPlans.count }
}

#Preview {
    StatsView()
        .environmentObject(CategoryColorManager())
}
