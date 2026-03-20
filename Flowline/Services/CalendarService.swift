import Combine
import EventKit
import Foundation

/// Reads Apple Calendar events and formats them for the AI system prompt.
@MainActor
final class CalendarService: ObservableObject {
    static let shared = CalendarService()

    private let store = EKEventStore()
    @Published private(set) var isAuthorized = false

    private init() {
        if #available(macOS 14.0, iOS 17.0, *) {
            isAuthorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        } else {
            isAuthorized = EKEventStore.authorizationStatus(for: .event) == .authorized
        }
    }

    // MARK: - Permission

    func requestAccess() async {
        do {
            if #available(macOS 14.0, iOS 17.0, *) {
                isAuthorized = try await store.requestFullAccessToEvents()
            } else {
                isAuthorized = try await store.requestAccess(to: .event)
            }
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Fetch

    /// Returns events from `start` to `end`.
    func events(from start: Date, to end: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { !($0.title?.isEmpty ?? true) }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Format for AI

    /// Returns a compact, human-readable string of Apple Calendar events
    /// covering today + the next `weeks` weeks, for use in the Claude system prompt.
    /// Returns nil if no events or not authorized.
    func formattedForAI(date: Date, weeks: Int = 3) -> String? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .weekOfYear, value: weeks, to: start)!
        let evts  = events(from: start, to: end)
        guard !evts.isEmpty else { return nil }

        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEEE, MMM d"

        let timeFmt = DateFormatter()
        timeFmt.timeStyle = .short
        timeFmt.dateStyle = .none

        // Group by day
        var dayMap: [(key: String, date: Date, events: [EKEvent])] = []
        for evt in evts {
            let key = dayFmt.string(from: evt.startDate)
            if let idx = dayMap.firstIndex(where: { $0.key == key }) {
                dayMap[idx].events.append(evt)
            } else {
                dayMap.append((key: key, date: evt.startDate, events: [evt]))
            }
        }
        dayMap.sort { $0.date < $1.date }

        let lines = dayMap.map { entry -> String in
            let eventStrings = entry.events.map { evt -> String in
                if evt.isAllDay {
                    return "\(evt.title!) (all day)"
                }
                let start = timeFmt.string(from: evt.startDate)
                let end   = timeFmt.string(from: evt.endDate)
                return "\(start)–\(end) \(evt.title!)"
            }
            return "\(entry.key): \(eventStrings.joined(separator: " · "))"
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Write to Apple Calendar

    /// Returns the dedicated "Flowline" calendar, creating it if needed.
    private func flowlineCalendar() -> EKCalendar? {
        if let existing = store.calendars(for: .event).first(where: { $0.title == "Flowline" }) {
            return existing
        }
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = "Flowline"
        cal.source = store.defaultCalendarForNewEvents?.source ?? store.sources.first(where: { $0.sourceType == .local })
        do {
            try store.saveCalendar(cal, commit: true)
            return cal
        } catch {
            return nil
        }
    }

    /// Saves plan blocks to a "Flowline" calendar in Apple Calendar.
    /// Deletes any existing Flowline events on the affected dates first to avoid duplicates.
    func savePlan(_ plan: GeneratedPlan) throws {
        guard isAuthorized else { return }
        guard let flCal = flowlineCalendar() else { return }

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let cal = Calendar.current

        // Collect all dates affected by this plan
        let affectedDates = Set(plan.blocks.compactMap { $0.date })

        // Delete existing Flowline events on those dates
        for dateStr in affectedDates {
            guard let day = dateFmt.date(from: dateStr) else { continue }
            let start = cal.startOfDay(for: day)
            let end   = cal.date(byAdding: .day, value: 1, to: start)!
            let pred  = store.predicateForEvents(withStart: start, end: end, calendars: [flCal])
            store.events(matching: pred)
                .forEach { try? store.remove($0, span: .thisEvent, commit: false) }
        }

        // Create new events
        for block in plan.blocks {
            guard let dateStr = block.date,
                  let day     = dateFmt.date(from: dateStr),
                  let startT  = timeFmt.date(from: block.startTime),
                  let endT    = timeFmt.date(from: block.endTime) else { continue }

            let dayComps   = cal.dateComponents([.year, .month, .day], from: day)
            let startComps = cal.dateComponents([.hour, .minute], from: startT)
            let endComps   = cal.dateComponents([.hour, .minute], from: endT)

            var sf = dayComps; sf.hour = startComps.hour; sf.minute = startComps.minute
            var ef = dayComps; ef.hour = endComps.hour;   ef.minute = endComps.minute

            guard let startDate = cal.date(from: sf),
                  let endDate   = cal.date(from: ef) else { continue }

            let event        = EKEvent(eventStore: store)
            event.title      = block.title
            event.startDate  = startDate
            event.endDate    = endDate
            event.calendar   = flCal
            event.notes      = "Added by Flowline"
            try store.save(event, span: .thisEvent, commit: false)
        }

        try store.commit()
    }
}
