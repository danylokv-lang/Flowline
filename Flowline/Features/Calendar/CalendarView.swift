import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var dayPlans: [DayPlan]
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var colorManager: CategoryColorManager
    @State private var currentWeekStart: Date = CalendarView.mondayOfCurrentWeek()
    @State private var confirmDeleteDay: Date? = nil
    @State private var confirmDeleteWeek = false

    // iOS-only: which single day is currently displayed
    #if os(iOS)
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    #endif

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60
    private let startHour = 0
    private let endHour = 24
    private let dayLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private let timeColumnWidth: CGFloat = 40

    // MARK: - Body

    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()
            CosmosBackground()
                .ignoresSafeArea()

            #if os(iOS)
            iOSContent
            #else
            macOSContent
            #endif
        }
    }

    // MARK: - iOS Layout

    #if os(iOS)
    private var iOSContent: some View {
        VStack(spacing: 0) {
            iOSHeader
            Rectangle().fill(FlowLineTheme.borderHi).frame(height: 0.5)
            iOSDayStrip
            Rectangle().fill(FlowLineTheme.borderHi).frame(height: 0.5)
            iOSTimeGrid
        }
        // Swipe left/right to change day
        .gesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if value.translation.width < 0 {
                            moveDay(by: 1)
                        } else {
                            moveDay(by: -1)
                        }
                    }
                }
        )
    }

    // Top header: month/year + day title + today/prev/next
    private var iOSHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(monthYearStringFor(selectedDay))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3)
                    .foregroundColor(FlowLineTheme.secondTxt)
                Text(dayTitleString)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FlowLineTheme.mainTxt, Color(hex: "#c4b5fd").opacity(0.85)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { moveDay(by: -1) }
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
                        selectedDay = calendar.startOfDay(for: Date())
                        currentWeekStart = CalendarView.mondayOfCurrentWeek()
                    }
                } label: {
                    Text("Today")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [FlowLineTheme.accent, Color(hex: "#8b6dff")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: FlowLineTheme.accent.opacity(0.4), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { moveDay(by: 1) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(FlowLineTheme.accent)
                        .frame(width: 32, height: 32)
                        .background(FlowLineTheme.borderHi)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Delete day button — only when day has blocks
                if !blocksForDay(selectedDay).isEmpty {
                    Button { confirmDeleteDay = selectedDay } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.red.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog(
                        "Delete all blocks for this day?",
                        isPresented: Binding(
                            get: { confirmDeleteDay == selectedDay },
                            set: { if !$0 { confirmDeleteDay = nil } }
                        ),
                        titleVisibility: .visible
                    ) {
                        Button("Delete Day", role: .destructive) {
                            deleteDay(selectedDay)
                            confirmDeleteDay = nil
                        }
                        Button("Cancel", role: .cancel) { confirmDeleteDay = nil }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // 7-day strip — tapping a circle selects that day
    private var iOSDayStrip: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                let day        = calendar.date(byAdding: .day, value: i, to: currentWeekStart)!
                let dayNum     = calendar.component(.day, from: day)
                let isToday    = calendar.isDateInToday(day)
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
                let hasBlocks  = !blocksForDay(day).isEmpty

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedDay = calendar.startOfDay(for: day)
                    }
                } label: {
                    VStack(spacing: 5) {
                        Text(dayLabels[i])
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundColor(
                                isSelected ? FlowLineTheme.accent
                                : isToday  ? FlowLineTheme.accentHi
                                           : FlowLineTheme.secondTxt.opacity(0.6)
                            )

                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(FlowLineTheme.accent)
                                    .frame(width: 28, height: 28)
                            } else if isToday {
                                Circle()
                                    .stroke(FlowLineTheme.accent, lineWidth: 1.5)
                                    .frame(width: 28, height: 28)
                            }
                            Text("\(dayNum)")
                                .font(.system(size: 14, weight: isSelected || isToday ? .black : .semibold))
                                .foregroundColor(
                                    isSelected ? .white
                                    : isToday  ? FlowLineTheme.accent
                                               : FlowLineTheme.mainTxt
                                )
                        }

                        // Dot indicator when day has blocks
                        Circle()
                            .fill(hasBlocks ? FlowLineTheme.accent.opacity(0.7) : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        // Slide the week strip when selectedDay moves outside it
        .onChange(of: selectedDay) { _, newDay in
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
            if newDay < currentWeekStart {
                currentWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
            } else if newDay >= weekEnd {
                currentWeekStart = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
            }
        }
    }

    // Full-width time grid for the selected day only
    private var iOSTimeGrid: some View {
        let totalHours = endHour - startHour
        let gridHeight = CGFloat(totalHours) * hourHeight

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    // Time labels column
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

                    // Single day column
                    let isToday = calendar.isDateInToday(selectedDay)
                    let blocks  = blocksForDay(selectedDay)

                    ZStack(alignment: .topLeading) {
                        if isToday {
                            LinearGradient(
                                colors: [FlowLineTheme.accent.opacity(0.10), FlowLineTheme.accent.opacity(0.04)],
                                startPoint: .top, endPoint: .bottom
                            )
                        }

                        ForEach(0...totalHours, id: \.self) { i in
                            Rectangle()
                                .fill(i % 6 == 0
                                      ? FlowLineTheme.secondTxt.opacity(0.15)
                                      : FlowLineTheme.secondTxt.opacity(0.06))
                                .frame(height: 0.5)
                                .offset(y: CGFloat(i) * hourHeight)
                        }

                        if isToday {
                            let comps = calendar.dateComponents([.hour, .minute], from: Date())
                            let yNow  = (CGFloat(comps.hour ?? 0) + CGFloat(comps.minute ?? 0) / 60.0) * hourHeight
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(LinearGradient(
                                        colors: [FlowLineTheme.accentHi, FlowLineTheme.accent.opacity(0.4)],
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(height: 1.5)
                                    .shadow(color: FlowLineTheme.accent.opacity(0.7), radius: 4)
                                Circle()
                                    .fill(FlowLineTheme.accentHi)
                                    .frame(width: 7, height: 7)
                                    .shadow(color: FlowLineTheme.accent.opacity(0.9), radius: 5)
                                    .offset(x: -3.5)
                            }
                            .offset(y: yNow)
                        }

                        ForEach(blocks, id: \.persistentModelID) { block in
                            let top    = yPosition(for: block.startTime)
                            let height = blockHeight(start: block.startTime, end: block.endTime)

                            blockView(for: block, height: height)
                                .frame(height: max(height, 14))
                                .padding(.horizontal, 4)
                                .offset(y: top)
                                .contextMenu {
                                    Button(role: .destructive) { deleteBlock(block) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: gridHeight, alignment: .topLeading)
                    .clipped()
                }
                .frame(height: gridHeight, alignment: .topLeading)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .onAppear {
                let h = calendar.component(.hour, from: Date())
                proxy.scrollTo(max(h - 1, 0), anchor: .top)
            }
            .onChange(of: selectedDay) { _, _ in
                let h = calendar.component(.hour, from: Date())
                proxy.scrollTo(max(h - 1, 0), anchor: .top)
            }
        }
    }

    private var dayTitleString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, d"
        return fmt.string(from: selectedDay)
    }

    private func monthYearStringFor(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: date).uppercased()
    }

    private func moveDay(by offset: Int) {
        selectedDay = calendar.date(byAdding: .day, value: offset, to: selectedDay)!
    }
    #endif

    // MARK: - macOS Layout

    #if !os(iOS)
    private var macOSContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(monthYearString)
                            .font(.system(size: 11, weight: .bold))
                            .tracking(3)
                            .foregroundColor(FlowLineTheme.secondTxt)
                        Text(weekRangeString)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [FlowLineTheme.mainTxt, Color(hex: "#c4b5fd").opacity(0.85)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
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
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    LinearGradient(
                                        colors: [FlowLineTheme.accent, Color(hex: "#8b6dff")],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: FlowLineTheme.accent.opacity(0.4), radius: 6, x: 0, y: 2)
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

                HStack(spacing: 0) {
                    Spacer().frame(width: timeColumnWidth)
                    ForEach(0..<7, id: \.self) { i in
                        let day       = calendar.date(byAdding: .day, value: i, to: currentWeekStart)!
                        let dayNum    = calendar.component(.day, from: day)
                        let isToday   = calendar.isDateInToday(day)
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

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    macOSTimeGrid
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
                .onAppear {
                    let h = calendar.component(.hour, from: Date())
                    if h >= startHour && h <= endHour { proxy.scrollTo(h, anchor: .center) }
                }
            }
        }
    }

    private var macOSTimeGrid: some View {
        let totalHours = endHour - startHour
        let gridHeight = CGFloat(totalHours) * hourHeight

        return HStack(alignment: .top, spacing: 0) {
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

            ForEach(Array(0..<7), id: \.self) { (dayIndex: Int) in
                let day     = calendar.date(byAdding: .day, value: dayIndex, to: currentWeekStart)!
                let isToday = calendar.isDateInToday(day)
                let blocks  = blocksForDay(day)

                ZStack(alignment: .topLeading) {
                    if isToday {
                        LinearGradient(
                            colors: [FlowLineTheme.accent.opacity(0.10), FlowLineTheme.accent.opacity(0.04)],
                            startPoint: .top, endPoint: .bottom
                        )
                    }

                    ForEach(0...totalHours, id: \.self) { i in
                        Rectangle()
                            .fill(i % 6 == 0
                                  ? FlowLineTheme.secondTxt.opacity(0.15)
                                  : FlowLineTheme.secondTxt.opacity(0.06))
                            .frame(height: 0.5)
                            .offset(y: CGFloat(i) * hourHeight)
                    }

                    if isToday {
                        let comps = calendar.dateComponents([.hour, .minute], from: Date())
                        let yNow  = (CGFloat(comps.hour ?? 0) + CGFloat(comps.minute ?? 0) / 60.0) * hourHeight
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [FlowLineTheme.accentHi, FlowLineTheme.accent.opacity(0.4)],
                                    startPoint: .leading, endPoint: .trailing))
                                .frame(height: 1.5)
                                .shadow(color: FlowLineTheme.accent.opacity(0.7), radius: 4, x: 0, y: 0)
                            Circle()
                                .fill(FlowLineTheme.accentHi)
                                .frame(width: 7, height: 7)
                                .shadow(color: FlowLineTheme.accent.opacity(0.9), radius: 5, x: 0, y: 0)
                                .offset(x: -3.5)
                        }
                        .offset(y: yNow)
                    }

                    ForEach(blocks, id: \.persistentModelID) { block in
                        let top    = yPosition(for: block.startTime)
                        let height = blockHeight(start: block.startTime, end: block.endTime)
                        blockView(for: block, height: height)
                            .frame(height: max(height, 14))
                            .padding(.horizontal, 2)
                            .offset(y: top)
                            .contextMenu {
                                Button(role: .destructive) { deleteBlock(block) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: gridHeight, alignment: .topLeading)
                .clipped()
            }
        }
        .frame(height: gridHeight, alignment: .topLeading)
    }

    private var monthYearString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: currentWeekStart).uppercased()
    }

    private var weekRangeString: String {
        let end = calendar.date(byAdding: .day, value: 6, to: currentWeekStart)!
        return "\(calendar.component(.day, from: currentWeekStart)) – \(calendar.component(.day, from: end))"
    }
    #endif

    // MARK: - Block rendering (shared)

    @ViewBuilder
    private func blockView(for block: ScheduleBlock, height: CGFloat) -> some View {
        let isSplit = block.title.contains("/")

        if isSplit {
            let parts  = block.title.split(separator: "/", maxSplits: 1)
                                    .map { String($0).trimmingCharacters(in: .whitespaces) }
            let title1 = parts[0]
            let title2 = parts.count > 1 ? parts[1] : ""
            let color1 = colorForCategory(block.category)
            let color2 = colorForCategory(guessCategory(from: title2))

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    Rectangle().fill(color1.opacity(0.18))
                    Rectangle().fill(color2.opacity(0.18))
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [color1.opacity(0.9), color2.opacity(0.9)],
                                       startPoint: .leading, endPoint: .trailing),
                        lineWidth: 1.5
                    )

                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous).fill(color1).frame(width: 3)
                    Spacer()
                }

                GeometryReader { geo in
                    Rectangle()
                        .fill(LinearGradient(colors: [color1.opacity(0.35), color2.opacity(0.35)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 1)
                        .offset(x: geo.size.width / 2)
                }

                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title1)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(color1)
                            .lineLimit(height > 40 ? 2 : 1)
                        if height > 36 {
                            Text(timeRangeString(start: block.startTime, end: block.endTime))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(color1.opacity(0.75))
                        }
                    }
                    .padding(.leading, 7).padding(.trailing, 3).padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title2)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(color2)
                            .lineLimit(height > 40 ? 2 : 1)
                    }
                    .padding(.horizontal, 5).padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            let color = colorForCategory(block.category)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(LinearGradient(colors: [color.opacity(0.22), color.opacity(0.10)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(LinearGradient(colors: [color.opacity(1.0), color.opacity(0.55)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1.5)
                    )
                    .shadow(color: color.opacity(0.30), radius: 6, x: 0, y: 2)

                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous).fill(color).frame(width: 3)
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
                .padding(.leading, 7).padding(.trailing, 5).padding(.vertical, 3)
            }
        }
    }

    // MARK: - Shared helpers

    private func guessCategory(from title: String) -> Category {
        let t = title.lowercased()
        if t.contains("gym") || t.contains("run") || t.contains("workout") ||
           t.contains("walk") || t.contains("exercise") || t.contains("yoga") ||
           t.contains("swim") || t.contains("meal") || t.contains("lunch") ||
           t.contains("dinner") || t.contains("breakfast") || t.contains("break") ||
           t.contains("sleep") || t.contains("nap") || t.contains("recovery") { return .health }
        if t.contains("school") || t.contains("class") || t.contains("study") ||
           t.contains("lecture") || t.contains("read") || t.contains("homework") ||
           t.contains("course") || t.contains("learn") || t.contains("review") ||
           t.contains("flashcard") || t.contains("exam") || t.contains("notes") { return .study }
        if t.contains("code") || t.contains("coding") || t.contains("work") ||
           t.contains("project") || t.contains("build") || t.contains("design") ||
           t.contains("meeting") || t.contains("call") || t.contains("sprint") ||
           t.contains("portfolio") || t.contains("leetcode") || t.contains("dev") ||
           t.contains("app") || t.contains("feature") { return .work }
        return .personal
    }

    private func timeRangeString(start: Date, end: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: start))–\(fmt.string(from: end))"
    }

    private func blocksForDay(_ day: Date) -> [ScheduleBlock] {
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay   = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return dayPlans
            .filter {
                let d = calendar.startOfDay(for: $0.date)
                return d >= startOfDay && d < endOfDay
            }
            .flatMap { $0.blocks }
    }

    private func yPosition(for date: Date) -> CGFloat {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (CGFloat(c.hour ?? startHour) + CGFloat(c.minute ?? 0) / 60.0 - CGFloat(startHour)) * hourHeight
    }

    private func blockHeight(start: Date, end: Date) -> CGFloat {
        CGFloat(end.timeIntervalSince(start) / 3600.0) * hourHeight
    }

    private func colorForCategory(_ category: Category?) -> Color {
        colorManager.color(for: category)
    }

    // MARK: - Delete

    private func deleteDay(_ day: Date) {
        let s = calendar.startOfDay(for: day)
        let e = calendar.date(byAdding: .day, value: 1, to: s)!
        dayPlans.filter { let d = calendar.startOfDay(for: $0.date); return d >= s && d < e }
                .forEach { context.delete($0) }
    }

    private func deleteWeek() {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
        dayPlans.filter { let d = calendar.startOfDay(for: $0.date); return d >= currentWeekStart && d < weekEnd }
                .forEach { context.delete($0) }
    }

    private func deleteBlock(_ block: ScheduleBlock) {
        for plan in dayPlans {
            if let idx = plan.blocks.firstIndex(where: { $0.persistentModelID == block.persistentModelID }) {
                plan.blocks.remove(at: idx)
                context.delete(block)
                break
            }
        }
    }

    static func mondayOfCurrentWeek() -> Date {
        let cal     = Calendar.current
        let today   = Date()
        let weekday = cal.component(.weekday, from: today)
        let delta   = (weekday == 1) ? -6 : -(weekday - 2)
        return cal.startOfDay(for: cal.date(byAdding: .day, value: delta, to: today)!)
    }
}

#Preview {
    CalendarView()
}
