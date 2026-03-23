import SwiftUI
import SwiftData

// MARK: - StatsView

struct StatsView: View {
    @Query private var dayPlans: [DayPlan]
    @EnvironmentObject private var colorManager: CategoryColorManager
    @ObservedObject private var streak = StreakManager.shared

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()
            CosmosBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Header ──────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 4) {
                        Text("INSIGHTS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(4)
                            .foregroundColor(FlowLineTheme.secondTxt.opacity(0.6))
                        Text("Your stats")
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [FlowLineTheme.mainTxt, Color(hex: "#c4b5fd").opacity(0.85)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                    }
                    .padding(.top, 20)

                    // ── Streak row ───────────────────────────────────────────
                    streakSection

                    // ── This-week hours ──────────────────────────────────────
                    weekHoursSection

                    // ── Completion rate ──────────────────────────────────────
                    completionSection

                    // ── Best focus time ──────────────────────────────────────
                    if let peak = peakFocusHour {
                        bestFocusSection(peak: peak)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "🔥",
                value: "\(streak.currentStreak)",
                label: "Current\nStreak",
                accent: .orange
            )
            statCard(
                icon: "🏆",
                value: "\(streak.longestStreak)",
                label: "Best\nStreak",
                accent: Color(hex: "#f59e0b")
            )
            statCard(
                icon: "📅",
                value: "\(totalDaysPlanned)",
                label: "Days\nPlanned",
                accent: FlowLineTheme.accent
            )
        }
    }

    // MARK: - Week Hours Section

    private var weekHoursSection: some View {
        let stats = weekHoursBreakdown
        let total = stats.values.reduce(0, +)

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader("THIS WEEK", value: String(format: "%.1f h total", total))

            if total == 0 {
                emptyHint("No blocks this week yet — plan your first day!")
            } else {
                VStack(spacing: 8) {
                    ForEach([Category.work, .study, .health, .personal], id: \.self) { cat in
                        let hours = stats[cat] ?? 0
                        if hours > 0 {
                            categoryBar(category: cat, hours: hours, maxHours: stats.values.max() ?? 1)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func categoryBar(category: Category, hours: Double, maxHours: Double) -> some View {
        let color = colorManager.color(for: category)
        let pct   = maxHours > 0 ? hours / maxHours : 0

        return HStack(spacing: 10) {
            Text(categoryLabel(category))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(FlowLineTheme.secondTxt)
                .frame(width: 58, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.12))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(colors: [color, color.opacity(0.6)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * pct, height: 8)
                }
            }
            .frame(height: 8)

            Text(String(format: "%.1fh", hours))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 34, alignment: .trailing)
        }
    }

    // MARK: - Completion Section

    private var completionSection: some View {
        let (done, partly, skipped, noData) = completionStats
        let total = done + partly + skipped + noData
        let ratedTotal = done + partly + skipped
        let rate = ratedTotal > 0 ? Double(done + partly) / Double(ratedTotal) : nil

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader("COMPLETION", value: rate.map { String(format: "%.0f%%", $0 * 100) } ?? "—")

            if total == 0 {
                emptyHint("Tap a past block to log how it went.")
            } else {
                // Donut-style summary
                HStack(spacing: 20) {
                    donutChart(done: done, partly: partly, skipped: skipped, noData: noData)
                        .frame(width: 80, height: 80)

                    VStack(alignment: .leading, spacing: 8) {
                        legendRow("✓ Done",     count: done,   color: .green)
                        legendRow("⚡ Partly",  count: partly, color: .orange)
                        legendRow("✗ Skipped",  count: skipped, color: Color(hex: "#ef4444"))
                        legendRow("• No check-in", count: noData, color: FlowLineTheme.dimTxt)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func donutChart(done: Int, partly: Int, skipped: Int, noData: Int) -> some View {
        let total  = Double(done + partly + skipped + noData)
        guard total > 0 else { return AnyView(Circle().fill(FlowLineTheme.borderHi).frame(width: 70, height: 70)) }

        let dPct = Double(done)   / total
        let pPct = Double(partly) / total
        let sPct = Double(skipped) / total

        return AnyView(
            ZStack {
                Circle().fill(FlowLineTheme.tertiaryBg).frame(width: 80, height: 80)

                // Segments via trim
                Circle()
                    .trim(from: 0, to: dPct)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .butt))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: dPct, to: dPct + pPct)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 10, lineCap: .butt))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: dPct + pPct, to: dPct + pPct + sPct)
                    .stroke(Color(hex: "#ef4444"), style: StrokeStyle(lineWidth: 10, lineCap: .butt))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))

                let ratedTotal = done + partly + skipped
                let rate = ratedTotal > 0 ? Int(Double(done + partly) / Double(ratedTotal) * 100) : 0
                VStack(spacing: 0) {
                    Text("\(rate)%")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(FlowLineTheme.mainTxt)
                    Text("done")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(FlowLineTheme.dimTxt)
                }
            }
        )
    }

    private func legendRow(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(FlowLineTheme.secondTxt)
            Spacer()
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(FlowLineTheme.mainTxt)
        }
    }

    // MARK: - Best Focus Section

    private func bestFocusSection(peak: Int) -> some View {
        let label = peak < 12 ? "morning" : peak < 17 ? "afternoon" : "evening"
        let icon  = peak < 12 ? "☀️" : peak < 17 ? "🌤" : "🌙"
        let range = "\(String(format: "%02d", peak)):00–\(String(format: "%02d", peak + 1)):00"

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader("PEAK FOCUS TIME", value: nil)

            HStack(spacing: 14) {
                Text(icon).font(.system(size: 32))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your \(label) — \(range)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(FlowLineTheme.mainTxt)
                    Text("Most of your 'Done' blocks fall in this hour.")
                        .font(.system(size: 11))
                        .foregroundColor(FlowLineTheme.secondTxt)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    // MARK: - Shared UI Helpers

    private func statCard(icon: String, value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 6) {
            Text(icon).font(.system(size: 22))
            Text(value)
                .font(.system(size: 24, weight: .black))
                .foregroundColor(accent)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(FlowLineTheme.secondTxt)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(cardBackground)
    }

    private func sectionHeader(_ title: String, value: String?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(2)
                .foregroundColor(FlowLineTheme.dimTxt)
            Spacer()
            if let v = value {
                Text(v)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(FlowLineTheme.accent)
            }
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(FlowLineTheme.dimTxt)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(FlowLineTheme.secondBg.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FlowLineTheme.borderHi.opacity(0.5), lineWidth: 1)
            )
    }

    // MARK: - Data computations

    private var totalDaysPlanned: Int { dayPlans.count }

    private var weekStart: Date {
        let today   = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let delta   = weekday == 1 ? -6 : -(weekday - 2)
        return calendar.date(byAdding: .day, value: delta, to: today)!
    }

    private var weekHoursBreakdown: [Category: Double] {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        var result: [Category: Double] = [:]
        for plan in dayPlans {
            let d = calendar.startOfDay(for: plan.date)
            guard d >= weekStart && d < weekEnd else { continue }
            for block in plan.blocks {
                let hours = block.endTime.timeIntervalSince(block.startTime) / 3600.0
                let cat   = block.category ?? .personal
                result[cat, default: 0] += hours
            }
        }
        return result
    }

    /// (done, partly, skipped, noCheckIn) counts for ALL past blocks
    private var completionStats: (Int, Int, Int, Int) {
        var done = 0, partly = 0, skipped = 0, noData = 0
        for plan in dayPlans {
            for block in plan.blocks where block.endTime <= Date() {
                switch block.checkInResult {
                case .done:    done    += 1
                case .partly:  partly  += 1
                case .skipped: skipped += 1
                case .none:    noData  += 1
                }
            }
        }
        return (done, partly, skipped, noData)
    }

    /// Hour of day (0-23) with the most "done" check-ins
    private var peakFocusHour: Int? {
        var counts = [Int: Int]()
        for plan in dayPlans {
            for block in plan.blocks where block.checkInResult == .done {
                let h = calendar.component(.hour, from: block.startTime)
                counts[h, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func categoryLabel(_ cat: Category) -> String {
        switch cat {
        case .work:     return "Work"
        case .study:    return "Study"
        case .health:   return "Health"
        case .personal: return "Personal"
        }
    }
}

#Preview {
    StatsView()
        .environmentObject(CategoryColorManager())
}
