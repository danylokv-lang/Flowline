//
//  FlowlineWidget.swift
//  FlowlineWidget
//

import WidgetKit
import SwiftUI

// MARK: - Shared Data Models (mirrors FlowlineWidgetData.swift in main app)

struct WidgetBlock: Codable, Identifiable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let category: String

    var isActive: Bool {
        startTime <= Date() && Date() < endTime
    }

    var timeRemainingText: String {
        let remaining = endTime.timeIntervalSince(Date())
        guard remaining > 0 else { return "Done" }
        let hours   = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m left" }
        return "\(minutes)m left"
    }

    var timeRangeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: startTime)) – \(fmt.string(from: endTime))"
    }

    var blockColor: Color {
        switch category {
        case "work":    return Color(red: 0.427, green: 0.298, blue: 0.980)
        case "study":   return Color(red: 0.231, green: 0.510, blue: 0.965)
        case "health":  return Color(red: 0.133, green: 0.773, blue: 0.369)
        default:        return Color(red: 0.976, green: 0.451, blue: 0.086)
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
        WidgetBlock(id: "1", title: "Deep Work",  startTime: now.addingTimeInterval(-1800), endTime: now.addingTimeInterval(3600),  category: "work"),
        WidgetBlock(id: "2", title: "Gym",        startTime: now.addingTimeInterval(5400),  endTime: now.addingTimeInterval(9000),  category: "health"),
        WidgetBlock(id: "3", title: "Dinner",     startTime: now.addingTimeInterval(10800), endTime: now.addingTimeInterval(12600), category: "personal")
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
        let entry = FlowlineEntry(date: Date(), data: WidgetDayData.load())
        let nextBlockStart = WidgetDayData.load()?.nextBlock?.startTime
        let fifteenMin     = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let refreshDate    = nextBlockStart.map { min($0, fifteenMin) } ?? fifteenMin
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

// MARK: - Small Widget (2×2)

struct SmallWidgetView: View {
    let entry: FlowlineEntry

    var body: some View {
        ZStack {
            Color(red: 0.031, green: 0.031, blue: 0.063)
            VStack(alignment: .leading, spacing: 6) {
                Text("✦ FLOWLINE")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Color(red: 0.427, green: 0.298, blue: 0.980))
                Spacer()
                if let block = entry.data?.currentBlock {
                    activeView(block)
                } else if let next = entry.data?.nextBlock {
                    nextView(next)
                } else {
                    emptyView
                }
            }
            .padding(14)
        }
    }

    private func activeView(_ block: WidgetBlock) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(block.blockColor).frame(width: 6, height: 6)
                Text("NOW")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(block.blockColor)
            }
            Text(block.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
            Text(block.timeRemainingText)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func nextView(_ block: WidgetBlock) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NEXT")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
            Text(block.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
            Text(block.timeRangeText)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No plan today")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            Text("Tap to plan")
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.427, green: 0.298, blue: 0.980).opacity(0.8))
        }
    }
}

// MARK: - Medium Widget (4×2)

struct MediumWidgetView: View {
    let entry: FlowlineEntry

    var body: some View {
        ZStack {
            Color(red: 0.031, green: 0.031, blue: 0.063)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("✦ FLOWLINE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Color(red: 0.427, green: 0.298, blue: 0.980))
                    Spacer()
                    Text(todayLabel)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.35))
                }
                Divider().background(Color.white.opacity(0.08))

                if let data = entry.data, !data.blocks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(upcomingBlocks(data)) { block in
                            blockRow(block)
                        }
                    }
                } else {
                    Spacer()
                    Text("No plan for today")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.35))
                    Spacer()
                }
            }
            .padding(14)
        }
    }

    private func upcomingBlocks(_ data: WidgetDayData) -> [WidgetBlock] {
        Array(data.blocks.filter { $0.endTime > Date() }.prefix(3))
    }

    private func blockRow(_ block: WidgetBlock) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(block.isActive ? block.blockColor : block.blockColor.opacity(0.4))
                .frame(width: 7, height: 7)
            Text(block.title)
                .font(.system(size: 12, weight: block.isActive ? .semibold : .regular))
                .foregroundColor(block.isActive ? .white : .white.opacity(0.6))
                .lineLimit(1)
            Spacer()
            Text(block.isActive ? block.timeRemainingText : block.timeRangeText)
                .font(.system(size: 11))
                .foregroundColor(block.isActive ? block.blockColor : .white.opacity(0.35))
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
            VStack(alignment: .leading, spacing: 2) {
                Text("NOW").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
                Text(block.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(block.timeRemainingText).font(.system(size: 10)).foregroundColor(.secondary)
            }
        } else if let next = entry.data?.nextBlock {
            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
                Text(next.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(next.timeRangeText).font(.system(size: 10)).foregroundColor(.secondary)
            }
        } else {
            Text("No plan · Tap to plan").font(.system(size: 12))
        }
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
                .containerBackground(Color(red: 0.031, green: 0.031, blue: 0.063), for: .widget)
        }
        .configurationDisplayName("Flowline")
        .description("See your current and upcoming schedule blocks.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    FlowlineWidget()
} timeline: {
    FlowlineEntry(date: Date(), data: makePreviewData())
    FlowlineEntry(date: Date(), data: nil)
}

#Preview("Medium", as: .systemMedium) {
    FlowlineWidget()
} timeline: {
    FlowlineEntry(date: Date(), data: makePreviewData())
}
