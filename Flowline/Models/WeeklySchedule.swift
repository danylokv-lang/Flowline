import Foundation

// MARK: - DayTimeBlock

/// A single start–end time block within one weekday.
struct DayTimeBlock: Codable, Equatable {
    /// "HH:mm" 24-hour format, e.g. "08:20"
    var start: String
    var end: String
}

// MARK: - WeekdaySchedule

/// The user's fixed schedule for one specific weekday.
struct WeekdaySchedule: Codable, Equatable, Identifiable {
    var id: Int { weekday }
    /// 1 = Monday … 7 = Sunday
    var weekday: Int
    var isEnabled: Bool
    var block: DayTimeBlock

    var shortName: String {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][max(0, min(weekday - 1, 6))]
    }

    var fullName: String {
        ["Monday", "Tuesday", "Wednesday", "Thursday",
         "Friday", "Saturday", "Sunday"][max(0, min(weekday - 1, 6))]
    }

    /// Human-readable summary, e.g. "08:20 – 13:00" or "Off"
    var displayText: String {
        isEnabled ? "\(block.start) – \(block.end)" : "Off"
    }
}

// MARK: - WeeklySchedule

/// The user's full per-day fixed schedule, stored as JSON in UserProfile.weeklySchedule.
struct WeeklySchedule: Codable, Equatable {
    var days: [WeekdaySchedule]

    // MARK: Default

    /// Mon–Fri 09:00–17:00 enabled, weekends off.
    static let `default` = WeeklySchedule(
        days: (1...7).map { wd in
            WeekdaySchedule(
                weekday: wd,
                isEnabled: wd <= 5,
                block: DayTimeBlock(start: "09:00", end: "17:00")
            )
        }
    )

    // MARK: Serialisation

    static func from(_ json: String) -> WeeklySchedule? {
        guard !json.isEmpty,
              let data = json.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(WeeklySchedule.self, from: data)
    }

    func toJSON() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let str  = String(data: data, encoding: .utf8)
        else { return "" }
        return str
    }

    // MARK: AI Prompt Text

    /// Multiline string the AI can directly read.
    /// Returns empty string if no days are enabled.
    var promptText: String {
        let enabled = days.filter { $0.isEnabled }
        guard !enabled.isEmpty else { return "" }
        return enabled
            .map { "  \($0.shortName): \($0.block.start)–\($0.block.end)" }
            .joined(separator: "\n")
    }

    // MARK: Migration from legacy single-block work hours

    /// Build a WeeklySchedule from the old single start/end times (Mon–Fri enabled).
    static func fromLegacy(start: Date?, end: Date?) -> WeeklySchedule {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let s = start.map { fmt.string(from: $0) } ?? "09:00"
        let e = end.map   { fmt.string(from: $0) } ?? "17:00"
        return WeeklySchedule(days: (1...7).map { wd in
            WeekdaySchedule(weekday: wd, isEnabled: wd <= 5,
                            block: DayTimeBlock(start: s, end: e))
        })
    }

    // MARK: Helpers

    /// Weekday index (1=Mon…7=Sun) for the given Calendar weekday (1=Sun…7=Sat).
    static func ourIndex(fromCalendarWeekday cwd: Int) -> Int {
        cwd == 1 ? 7 : cwd - 1   // Sun=7, Mon=1, Tue=2 …
    }

    /// Returns the enabled block for today, or nil.
    var todayBlock: DayTimeBlock? {
        let cwd = Calendar.current.component(.weekday, from: Date())
        let idx = Self.ourIndex(fromCalendarWeekday: cwd)
        return days.first(where: { $0.weekday == idx && $0.isEnabled })?.block
    }
}
