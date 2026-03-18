import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var dayPlans: [DayPlan]
    @State private var currentWeekStart: Date = CalendarView.mondayOfCurrentWeek()

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60
    private let startHour = 0
    private let endHour = 24
    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let timeColumnWidth: CGFloat = 44

    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()

            VStack(spacing: 0) {
                weekHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // Day header aligned with grid columns
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: timeColumnWidth)

                    ForEach(0..<7, id: \.self) { i in
                        let day = calendar.date(byAdding: .day, value: i, to: currentWeekStart)!
                        let dayNum = calendar.component(.day, from: day)
                        let isToday = calendar.isDateInToday(day)

                        VStack(spacing: 2) {
                            Text(dayLabels[i])
                                .font(.system(size: 10))
                                .foregroundColor(FlowLineTheme.secondTxt)
                            Text("\(dayNum)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isToday ? FlowLineTheme.accent : FlowLineTheme.mainTxt)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                Divider().background(FlowLineTheme.secondTxt.opacity(0.3))

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        timeGrid
                            .padding(.horizontal, 16)
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

    // MARK: - Week Header

    private var weekHeader: some View {
        HStack {
            Button {
                currentWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.bold())
                    .foregroundColor(FlowLineTheme.accent)
            }

            Spacer()

            Text(weekRangeString)
                .font(.headline)
                .foregroundColor(FlowLineTheme.mainTxt)

            Spacer()

            Button {
                currentWeekStart = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.bold())
                    .foregroundColor(FlowLineTheme.accent)
            }
        }
    }

    // MARK: - Time Grid with blocks

    private var timeGrid: some View {
        let totalHours = endHour - startHour
        let gridHeight = CGFloat(totalHours) * hourHeight

        return HStack(alignment: .top, spacing: 0) {
            // Time labels column
            ZStack(alignment: .topLeading) {
                ForEach(0...totalHours, id: \.self) { i in
                    Text(String(format: "%02d:00", startHour + i))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(FlowLineTheme.secondTxt)
                        .offset(y: CGFloat(i) * hourHeight - 6)
                        .id(startHour + i)
                }
            }
            .frame(width: timeColumnWidth, height: gridHeight, alignment: .topLeading)

            // Day columns
            ForEach(Array(0..<7), id: \.self) { (dayIndex: Int) in
                let day = calendar.date(byAdding: .day, value: dayIndex, to: currentWeekStart)!
                let blocks = blocksForDay(day)

                ZStack(alignment: .topLeading) {
                    // Hour lines
                    ForEach(0...totalHours, id: \.self) { i in
                        Rectangle()
                            .fill(FlowLineTheme.secondTxt.opacity(0.2))
                            .frame(height: 0.5)
                            .offset(y: CGFloat(i) * hourHeight)
                    }

                    // Schedule blocks
                    ForEach(blocks, id: \.persistentModelID) { block in
                        let top = yPosition(for: block.startTime)
                        let height = blockHeight(start: block.startTime, end: block.endTime)
                        let color = colorForCategory(block.category)

                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 6)
                                .fill(color.opacity(0.25))

                            // Left accent strip
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(color.opacity(0.8))
                                    .frame(width: 3)
                                Spacer()
                            }

                            // Content
                            VStack(alignment: .leading, spacing: 2) {
                                Text(block.title)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(FlowLineTheme.mainTxt)
                                    .lineLimit(height > 40 ? 3 : 1)

                                if height > 40 {
                                    Text(timeRangeString(start: block.startTime, end: block.endTime))
                                        .font(.system(size: 8))
                                        .foregroundColor(FlowLineTheme.secondTxt)
                                }
                            }
                            .padding(.leading, 6)
                            .padding(.trailing, 2)
                            .padding(.vertical, 2)
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

    private var weekRangeString: String {
        let endDate = calendar.date(byAdding: .day, value: 6, to: currentWeekStart)!
        let startDay = calendar.component(.day, from: currentWeekStart)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let month = formatter.string(from: endDate)
        let endDay = calendar.component(.day, from: endDate)
        return "\(startDay)–\(endDay) \(month)"
    }

    private func timeRangeString(start: Date, end: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

    private func blocksForDay(_ day: Date) -> [ScheduleBlock] {
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return dayPlans
            .filter { plan in
                let planDay = calendar.startOfDay(for: plan.date)
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
        let interval = end.timeIntervalSince(start)
        return CGFloat(interval / 3600.0) * hourHeight
    }

    private func colorForCategory(_ category: Category?) -> Color {
        switch category {
        case .study:    return FlowLineTheme.secondBg
        case .work:     return FlowLineTheme.accent
        case .health:   return FlowLineTheme.secondTxt
        case .personal: return FlowLineTheme.mainTxt.opacity(0.5)
        case nil:       return FlowLineTheme.secondBg.opacity(0.6)
        }
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
