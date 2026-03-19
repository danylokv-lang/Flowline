import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var dayPlans: [DayPlan]
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var colorManager: CategoryColorManager
    @State private var currentWeekStart: Date = CalendarView.mondayOfCurrentWeek()
    @State private var confirmDeleteDay: Date? = nil
    @State private var confirmDeleteWeek = false

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60
    private let startHour = 0
    private let endHour = 24
    private let dayLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private let timeColumnWidth: CGFloat = 40

    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────────────
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(monthYearString)
                                .font(.system(size: 11, weight: .bold))
                                .tracking(3)
                                .foregroundColor(FlowLineTheme.secondTxt)
                            Text(weekRangeString)
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(FlowLineTheme.mainTxt)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(FlowLineTheme.accent)
                                    .frame(width: 32, height: 32)
                                    .background(FlowLineTheme.borderHi)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentWeekStart = CalendarView.mondayOfCurrentWeek()
                                }
                            } label: {
                                Text("Today")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FlowLineTheme.mainBg)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(FlowLineTheme.accent)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentWeekStart = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(FlowLineTheme.accent)
                                    .frame(width: 32, height: 32)
                                    .background(FlowLineTheme.borderHi)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)

                            // Delete week button
                            Button { confirmDeleteWeek = true } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.red.opacity(0.7))
                                    .frame(width: 32, height: 32)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Clear entire week")
                            .confirmationDialog("Delete all blocks for this week?",
                                                isPresented: $confirmDeleteWeek,
                                                titleVisibility: .visible) {
                                Button("Delete Week", role: .destructive) { deleteWeek() }
                                Button("Cancel", role: .cancel) {}
                            }
                        }
                    }

                    // Day columns header
                    HStack(spacing: 0) {
                        Spacer().frame(width: timeColumnWidth)
                        ForEach(0..<7, id: \.self) { i in
                            let day = calendar.date(byAdding: .day, value: i, to: currentWeekStart)!
                            let dayNum = calendar.component(.day, from: day)
                            let isToday = calendar.isDateInToday(day)
                            let hasBlocks = !blocksForDay(day).isEmpty

                            VStack(spacing: 4) {
                                Text(dayLabels[i])
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(isToday ? FlowLineTheme.accent : FlowLineTheme.secondTxt.opacity(0.6))

                                ZStack {
                                    if isToday {
                                        Circle()
                                            .fill(FlowLineTheme.accent)
                                            .frame(width: 24, height: 24)
                                    }
                                    Text("\(dayNum)")
                                        .font(.system(size: 13, weight: isToday ? .black : .semibold))
                                        .foregroundColor(isToday ? FlowLineTheme.mainBg : FlowLineTheme.mainTxt)
                                }

                                // Trash icon — only shown when day has blocks
                                if hasBlocks {
                                    Button { confirmDeleteDay = day } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(Color.red.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Clear \(dayLabels[i])")
                                    .confirmationDialog(
                                        "Delete all blocks for \(dayLabels[i]) \(dayNum)?",
                                        isPresented: Binding(
                                            get: { confirmDeleteDay == day },
                                            set: { if !$0 { confirmDeleteDay = nil } }
                                        ),
                                        titleVisibility: .visible
                                    ) {
                                        Button("Delete Day", role: .destructive) {
                                            deleteDay(day)
                                            confirmDeleteDay = nil
                                        }
                                        Button("Cancel", role: .cancel) { confirmDeleteDay = nil }
                                    }
                                } else {
                                    // Placeholder to keep column height stable
                                    Color.clear.frame(height: 12)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                Rectangle()
                    .fill(FlowLineTheme.borderHi)
                    .frame(height: 0.5)

                // ── Time Grid ────────────────────────────────────────────
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        timeGrid
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                    }
                    .onAppear {
                        let currentHour = calendar.component(.hour, from: Date())
                        if currentHour >= startHour && currentHour <= endHour {
                            proxy.scrollTo(currentHour, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Time Grid

    private var timeGrid: some View {
        let totalHours = endHour - startHour
        let gridHeight = CGFloat(totalHours) * hourHeight

        return HStack(alignment: .top, spacing: 0) {
            // Time labels
            ZStack(alignment: .topLeading) {
                ForEach(0...totalHours, id: \.self) { i in
                    Text(String(format: "%02d", startHour + i))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(FlowLineTheme.secondTxt.opacity(0.4))
                        .offset(y: CGFloat(i) * hourHeight - 7)
                        .id(startHour + i)
                }
            }
            .frame(width: timeColumnWidth, height: gridHeight, alignment: .topLeading)

            // Day columns
            ForEach(Array(0..<7), id: \.self) { (dayIndex: Int) in
                let day = calendar.date(byAdding: .day, value: dayIndex, to: currentWeekStart)!
                let isToday = calendar.isDateInToday(day)
                let blocks = blocksForDay(day)

                ZStack(alignment: .topLeading) {
                    // Today column tint
                    if isToday {
                        Rectangle()
                            .fill(FlowLineTheme.accent.opacity(0.03))
                    }

                    // Hour lines
                    ForEach(0...totalHours, id: \.self) { i in
                        Rectangle()
                            .fill(
                                i % 6 == 0
                                    ? FlowLineTheme.secondTxt.opacity(0.15)
                                    : FlowLineTheme.secondTxt.opacity(0.06)
                            )
                            .frame(height: 0.5)
                            .offset(y: CGFloat(i) * hourHeight)
                    }

                    // Current time line
                    if isToday {
                        let now = Date()
                        let comps = calendar.dateComponents([.hour, .minute], from: now)
                        let yNow = (CGFloat(comps.hour ?? 0) + CGFloat(comps.minute ?? 0) / 60.0) * hourHeight

                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(FlowLineTheme.accent.opacity(0.6))
                                .frame(height: 1)
                            Circle()
                                .fill(FlowLineTheme.accent)
                                .frame(width: 6, height: 6)
                                .offset(x: -3)
                        }
                        .offset(y: yNow)
                    }

                    // Schedule blocks
                    ForEach(blocks, id: \.persistentModelID) { block in
                        let top = yPosition(for: block.startTime)
                        let height = blockHeight(start: block.startTime, end: block.endTime)
                        let color = colorForCategory(block.category)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(color.opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .stroke(color.opacity(0.90), lineWidth: 1.5)
                                )

                            // Left accent bar
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(color)
                                    .frame(width: 3)
                                Spacer()
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(block.title)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(color)
                                    .lineLimit(height > 40 ? 2 : 1)

                                if height > 36 {
                                    Text(timeRangeString(start: block.startTime, end: block.endTime))
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(color.opacity(0.75))
                                }
                            }
                            .padding(.leading, 7)
                            .padding(.trailing, 5)
                            .padding(.vertical, 3)
                        }
                        .frame(height: max(height, 14))
                        .padding(.horizontal, 2)
                        .offset(y: top)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: gridHeight, alignment: .topLeading)
                .clipped()
            }
        }
        .frame(height: gridHeight, alignment: .topLeading)
    }

    // MARK: - Helpers

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentWeekStart).uppercased()
    }

    private var weekRangeString: String {
        let endDate = calendar.date(byAdding: .day, value: 6, to: currentWeekStart)!
        let startDay = calendar.component(.day, from: currentWeekStart)
        let endDay = calendar.component(.day, from: endDate)
        return "\(startDay) – \(endDay)"
    }

    private func timeRangeString(start: Date, end: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: start))–\(fmt.string(from: end))"
    }

    private func blocksForDay(_ day: Date) -> [ScheduleBlock] {
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return dayPlans
            .filter {
                let planDay = calendar.startOfDay(for: $0.date)
                return planDay >= startOfDay && planDay < endOfDay
            }
            .flatMap { $0.blocks }
    }

    private func yPosition(for date: Date) -> CGFloat {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let hour = CGFloat(comps.hour ?? startHour)
        let minute = CGFloat(comps.minute ?? 0)
        return (hour - CGFloat(startHour) + minute / 60.0) * hourHeight
    }

    private func blockHeight(start: Date, end: Date) -> CGFloat {
        CGFloat(end.timeIntervalSince(start) / 3600.0) * hourHeight
    }

    private func colorForCategory(_ category: Category?) -> Color {
        colorManager.color(for: category)
    }

    // MARK: - Delete

    private func deleteDay(_ day: Date) {
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let plans = dayPlans.filter {
            let d = calendar.startOfDay(for: $0.date)
            return d >= startOfDay && d < endOfDay
        }
        plans.forEach { context.delete($0) }
    }

    private func deleteWeek() {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
        let plans = dayPlans.filter {
            let d = calendar.startOfDay(for: $0.date)
            return d >= currentWeekStart && d < weekEnd
        }
        plans.forEach { context.delete($0) }
    }

    static func mondayOfCurrentWeek() -> Date {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let daysToSubtract = (weekday == 1) ? 6 : (weekday - 2)
        return cal.startOfDay(for: cal.date(byAdding: .day, value: -daysToSubtract, to: today)!)
    }
}

#Preview {
    CalendarView()
}
