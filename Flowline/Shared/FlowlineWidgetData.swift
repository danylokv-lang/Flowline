import Foundation
import SwiftUI

// MARK: - Shared widget data model
// Lives in BOTH the main app target AND the widget extension target.
// The main app writes to App Group UserDefaults; the widget reads from there.

struct WidgetBlock: Codable, Identifiable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let category: String // "work" | "study" | "health" | "personal"

    var isActive: Bool {
        let now = Date()
        return startTime <= now && now < endTime
    }

    var timeRemainingText: String {
        let remaining = endTime.timeIntervalSince(Date())
        guard remaining > 0 else { return "Done" }
        let hours   = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m left" }
        return "\(minutes)m left"
    }

    var color: Color {
        switch category {
        case "work":    return Color(hex: "#6d4cfa")
        case "study":   return Color(hex: "#3b82f6")
        case "health":  return Color(hex: "#22c55e")
        default:        return Color(hex: "#f97316")
        }
    }

    var timeRangeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: startTime)) – \(fmt.string(from: endTime))"
    }
}

struct WidgetDayData: Codable {
    let blocks: [WidgetBlock]
    let updatedAt: Date

    static let appGroupID = "group.com.flowline"
    static let defaultsKey = "flowline_widget_day"

    static func save(_ data: WidgetDayData) {
        guard let encoded = try? JSONEncoder().encode(data),
              let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(encoded, forKey: defaultsKey)
    }

    static func load() -> WidgetDayData? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let raw = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(WidgetDayData.self, from: raw)
        else { return nil }
        return decoded
    }

    var currentBlock: WidgetBlock? {
        blocks.first { $0.isActive }
    }

    var upcomingBlocks: [WidgetBlock] {
        let now = Date()
        return blocks.filter { $0.startTime > now }
    }

    var nextBlock: WidgetBlock? {
        upcomingBlocks.first
    }
}

