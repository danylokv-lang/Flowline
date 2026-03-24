//
//  FlowlineWidget.swift
//  FlowlineWidget
//

import WidgetKit
import SwiftUI

// MARK: - Shared Data Models

struct WidgetBlock: Codable, Identifiable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let category: String

    var isActive: Bool {
        startTime <= Date() && Date() < endTime
    }

    /// 0.0 → 1.0 — how far through the block we currently are
    var progress: Double {
        let total = endTime.timeIntervalSince(startTime)
        guard total > 0 else { return 1 }
        let elapsed = Date().timeIntervalSince(startTime)
        return min(max(elapsed / total, 0), 1)
    }

    var timeRemainingText: String {
        let remaining = endTime.timeIntervalSince(Date())
        guard remaining > 0 else { return "Done" }
        let hours   = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m left"
    }

    var timeRangeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: startTime))–\(fmt.string(from: endTime))"
    }

    var blockColor: Color {
        switch category {
        case "work":    return Color(red: 0.427, green: 0.298, blue: 0.980)
        case "study":   return Color(red: 0.231, green: 0.510, blue: 0.965)
        case "health":  return Color(red: 0.133, green: 0.773, blue: 0.369)
        default:        return Color(red: 0.976, green: 0.451, blue: 0.086)
        }
    }

    var categoryIcon: String {
        switch category {
        case "work":    return "laptopcomputer"
        case "study":   return "book.fill"
        case "health":  return "figure.run"
        default:        return "person.fill"
        }
    }
}

struct WidgetDayData: Codable {
    let blocks: [WidgetBlock]
    let updatedAt: Date

    static let appGroupID  = "group.com.flowline"
    static let defaultsKey = "flowline_widget_day"

    static func load() -> WidgetDayData? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let raw     = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(WidgetDayData.self, from: raw)
        else { return nil }
        return decoded
    }

    var currentBlock: WidgetBlock? { blocks.first { $0.isActive } }
    var nextBlock: WidgetBlock?    { blocks.first { $0.startTime > Date() } }
    var completedCount: Int        { blocks.filter { $0.endTime < Date() }.count }
}

// MARK: - Timeline Entry

struct FlowlineEntry: TimelineEntry {
    let date: Date
    let data: WidgetDayData?
}

// MARK: - Preview helper

private func makePreviewData() -> WidgetDayData {
    let now = Date()
    return WidgetDayData(blocks: [
        WidgetBlock(id: "1", title: "Deep Work",     startTime: now.addingTimeInterval(-1800), endTime: now.addingTimeInterval(3600),  category: "work"),
        WidgetBlock(id: "2", title: "Gym",           startTime: now.addingTimeInterval(5400),  endTime: now.addingTimeInterval(9000),  category: "health"),
        WidgetBlock(id: "3", title: "Wind Down",     startTime: now.addingTimeInterval(10800), endTime: now.addingTimeInterval(12600), category: "personal")
    ], updatedAt: now)
}

// MARK: - Timeline Provider

struct FlowlineTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlowlineEntry {
        FlowlineEntry(date: Date(), data: makePreviewData())
    }

    func getSnapshot(in context: Context, completion: @escaping (FlowlineEntry) -> Void) {
        completion(FlowlineEntry(date: Date(), data: WidgetDayData.load() ?? makePreviewData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlowlineEntry>) -> Void) {
        let data           = WidgetDayData.load()
        let entry          = FlowlineEntry(date: Date(), data: data)
        let nextBlockStart = data?.nextBlock?.startTime
        let fifteenMin     = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let refreshDate    = nextBlockStart.map { min($0, fifteenMin) } ?? fifteenMin
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

// MARK: - Design tokens

private let bgTop    = Color(red: 0.06, green: 0.05, blue: 0.14)
private let bgBottom = Color(red: 0.02, green: 0.02, blue: 0.06)
private let purple   = Color(red: 0.427, green: 0.298, blue: 0.980)

// MARK: - Small Widget (2×2)

struct SmallWidgetView: View {
    let entry: FlowlineEntry

    var body: some View {
        ZStack {
            LinearGradient(colors: [bgTop, bgBottom], startPoint: .topLeading, endPoint: .bottomTrailing)

            if let block = entry.data?.currentBlock {
                activeContent(block)
            } else if let next = entry.data?.nextBlock {
                nextContent(next)
            } else {
                emptyContent
            }
        }
    }

    // Active block — ring + title + time
    private func activeContent(_ block: WidgetBlock) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack {
                // Category icon in coloured rounded square
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(block.blockColor.opacity(0.22))
                        .frame(width: 28, height: 28)
                    Image(systemName: block.categoryIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(block.blockColor)
                }

                Spacer()

                // NOW pill
                Text("NOW")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(block.blockColor)
                    .clipShape(Capsule())
            }

            Spacer()

            // Title
            Text(block.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .padding(.bottom, 6)

            // Progress bar + time remaining
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 3)
                        Capsule()
                            .fill(block.blockColor)
                            .frame(width: geo.size.width * block.progress, height: 3)
                    }
                }
                .frame(height: 3)

                Text(block.timeRemainingText)
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.45))
            }
        }
        .padding(14)
    }

    // Next block — icon + title + time range
    private func nextContent(_ block: WidgetBlock) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(block.blockColor.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: block.categoryIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(block.blockColor.opacity(0.85))
                }
                Spacer()
                Text("NEXT")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(Color.white.opacity(0.35))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Capsule())
            }

            Spacer()

            Text(block.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .padding(.bottom, 4)

            Text(block.timeRangeText)
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.40))
        }
        .padding(14)
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(purple.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(purple)
            }
            Spacer()
            Text("No plan\ntoday")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.white.opacity(0.55))
                .lineSpacing(2)
                .padding(.bottom, 4)
            Text("Tap to plan →")
                .font(.system(size: 11))
                .foregroundColor(purple.opacity(0.8))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium Widget (4×2)

struct MediumWidgetView: View {
    let entry: FlowlineEntry

    var body: some View {
        ZStack {
            LinearGradient(colors: [bgTop, bgBottom], startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Text("✦ FLOWLINE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(purple)
                    Spacer()
                    Text(todayLabel)
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.30))
                }

                Divider().overlay(Color.white.opacity(0.07))

                if let data = entry.data, !data.blocks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(visibleBlocks(data)) { block in
                            blockRow(block)
                        }
                    }
                } else {
                    Spacer()
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(purple.opacity(0.6))
                        Text("No plan for today")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.30))
                    }
                    Spacer()
                }
            }
            .padding(14)
        }
    }

    private func visibleBlocks(_ data: WidgetDayData) -> [WidgetBlock] {
        // Show active + upcoming, max 3
        let active   = data.blocks.filter { $0.isActive }
        let upcoming = data.blocks.filter { $0.startTime > Date() }.prefix(3 - active.count)
        return Array(active + upcoming)
    }

    private func blockRow(_ block: WidgetBlock) -> some View {
        HStack(spacing: 10) {
            // Coloured bar indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(block.isActive ? block.blockColor : block.blockColor.opacity(0.35))
                .frame(width: 3, height: 28)

            // Icon
            Image(systemName: block.categoryIcon)
                .font(.system(size: 11))
                .foregroundColor(block.isActive ? block.blockColor : Color.white.opacity(0.35))
                .frame(width: 16)

            // Title + time
            VStack(alignment: .leading, spacing: 1) {
                Text(block.title)
                    .font(.system(size: 12, weight: block.isActive ? .semibold : .regular))
                    .foregroundColor(block.isActive ? .white : Color.white.opacity(0.55))
                    .lineLimit(1)
                Text(block.isActive ? block.timeRemainingText : block.timeRangeText)
                    .font(.system(size: 10))
                    .foregroundColor(block.isActive ? block.blockColor : Color.white.opacity(0.30))
            }

            Spacer()

            if block.isActive {
                Text("NOW")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(block.blockColor)
                    .clipShape(Capsule())
            }
        }
    }

    private var todayLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d"
        return fmt.string(from: Date())
    }
}

// MARK: - Lock Screen Inline

struct LockScreenInlineView: View {
    let entry: FlowlineEntry
    var body: some View {
        if let block = entry.data?.currentBlock {
            Label("\(block.title) · \(block.timeRemainingText)", systemImage: "bolt.fill")
        } else if let next = entry.data?.nextBlock {
            Label("\(next.title) · \(next.timeRangeText)", systemImage: "clock")
        } else {
            Label("Tap to plan your day", systemImage: "plus.circle")
        }
    }
}

// MARK: - Lock Screen Rectangular

struct LockScreenRectView: View {
    let entry: FlowlineEntry

    var body: some View {
        if let block = entry.data?.currentBlock {
            activeLayout(block)
        } else if let next = entry.data?.nextBlock {
            nextLayout(next)
        } else {
            emptyLayout
        }
    }

    private func activeLayout(_ block: WidgetBlock) -> some View {
        HStack(spacing: 9) {
            // Left: icon circle
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: block.categoryIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .widgetAccentable()
            }

            // Right: status + title + progress bar
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("NOW")
                        .font(.system(size: 9, weight: .bold))
                        .widgetAccentable()
                    Spacer()
                    Text(block.timeRemainingText)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Text(block.title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 2)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * block.progress, height: 2)
                            .widgetAccentable()
                    }
                }
                .frame(height: 2)
            }
        }
        .padding(.horizontal, 2)
    }

    private func nextLayout(_ block: WidgetBlock) -> some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 32, height: 32)
                Image(systemName: block.categoryIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("NEXT")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(block.title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)

                Text(block.timeRangeText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }

    private var emptyLayout: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 32, height: 32)
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .widgetAccentable()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("No plan yet")
                    .font(.system(size: 13, weight: .bold))
                Text("Tap to plan your day")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Lock Screen Circular (NEW)

struct LockScreenCircularView: View {
    let entry: FlowlineEntry

    var body: some View {
        if let block = entry.data?.currentBlock {
            Gauge(value: block.progress, in: 0...1) {
                EmptyView()
            } currentValueLabel: {
                Image(systemName: block.categoryIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .widgetAccentable()
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
        } else if let next = entry.data?.nextBlock {
            // Show next block start time
            Gauge(value: 0, in: 0...1) {
                EmptyView()
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .semibold))
                    Text(shortTime(next.startTime))
                        .font(.system(size: 8, weight: .bold))
                }
                .widgetAccentable()
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            // Day done or no plan
            Gauge(value: 1, in: 0...1) {
                EmptyView()
            } currentValueLabel: {
                Image(systemName: entry.data == nil ? "plus" : "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .widgetAccentable()
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
        }
    }

    private func shortTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - Entry View Router

struct FlowlineWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FlowlineEntry

    var body: some View {
        switch family {
        case .systemSmall:          SmallWidgetView(entry: entry)
        case .systemMedium:         MediumWidgetView(entry: entry)
        case .accessoryInline:      LockScreenInlineView(entry: entry)
        case .accessoryRectangular: LockScreenRectView(entry: entry)
        case .accessoryCircular:    LockScreenCircularView(entry: entry)
        default:                    SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget

struct FlowlineWidget: Widget {
    let kind: String = "FlowlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlowlineTimelineProvider()) { entry in
            FlowlineWidgetEntryView(entry: entry)
                .containerBackground(
                    LinearGradient(colors: [bgTop, bgBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    for: .widget
                )
        }
        .configurationDisplayName("Flowline")
        .description("See your current and upcoming schedule blocks.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryRectangular,
            .accessoryCircular
        ])
    }
}

// MARK: - Previews

#Preview("Small – Active", as: .systemSmall) {
    FlowlineWidget()
} timeline: {
    FlowlineEntry(date: Date(), data: makePreviewData())
}

#Preview("Small – Empty", as: .systemSmall) {
    FlowlineWidget()
} timeline: {
    FlowlineEntry(date: Date(), data: nil)
}

#Preview("Medium", as: .systemMedium) {
    FlowlineWidget()
} timeline: {
    FlowlineEntry(date: Date(), data: makePreviewData())
}

#Preview("Lock – Rect", as: .accessoryRectangular) {
    FlowlineWidget()
} timeline: {
    FlowlineEntry(date: Date(), data: makePreviewData())
}

#Preview("Lock – Circular", as: .accessoryCircular) {
    FlowlineWidget()
} timeline: {
    FlowlineEntry(date: Date(), data: makePreviewData())
}

#Preview("Lock – Inline", as: .accessoryInline) {
    FlowlineWidget()
} timeline: {
    FlowlineEntry(date: Date(), data: makePreviewData())
}
