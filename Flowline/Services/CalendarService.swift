import Combine
import EventKit
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Writable calendar info (used by the in-chat picker)

struct WritableCalendarInfo: Identifiable {
    let id: String          // EKCalendar.calendarIdentifier
    let title: String
    let sourceName: String
    let isGoogle: Bool
    let calColor: CGColor?
}

/// Reads Apple Calendar events and formats them for the AI system prompt.
@MainActor
final class CalendarService: ObservableObject {
    static let shared = CalendarService()

    private let store = EKEventStore()
    @Published private(set) var isAuthorized = false

    private init() {
        refreshAuthStatus()
        // Re-check whenever the app becomes active (user may have changed
        // permission in System Preferences while the app was in the background)
        #if os(macOS)
        let activeNotification = NSApplication.didBecomeActiveNotification
        #else
        let activeNotification = UIApplication.didBecomeActiveNotification
        #endif
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshAuthStatus),
            name: activeNotification,
            object: nil
        )
    }

    @objc private func refreshAuthStatus() {
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

    /// Returns a compact, human-readable string of all connected calendar events
    /// (Apple iCloud, Google Calendar, Exchange, etc.) covering today + the next `weeks` weeks,
    /// for use in the Claude system prompt. Returns nil if no events or not authorized.
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
                // Determine source tag (Google, iCloud, Exchange, etc.)
                let srcTitle  = evt.calendar?.source?.title ?? ""
                let srcType   = evt.calendar?.source?.sourceType
                let isGoogle  = srcType == .calDAV &&
                    (srcTitle.lowercased().contains("google") ||
                     srcTitle.lowercased().contains("gmail") ||
                     srcTitle.contains("@gmail"))
                let tag = isGoogle ? " [Google]" : ""

                if evt.isAllDay {
                    return "\(evt.title!) (all day)\(tag)"
                }
                let start = timeFmt.string(from: evt.startDate)
                let end   = timeFmt.string(from: evt.endDate)
                return "\(start)–\(end) \(evt.title!)\(tag)"
            }
            return "\(entry.key): \(eventStrings.joined(separator: " · "))"
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Calendar discovery

    /// Sorted list of source account titles (iCloud, Google, Exchange, etc.)
    func availableSourceTitles() -> [String] {
        guard isAuthorized else { return [] }
        return store.sources
            .filter { [.local, .calDAV, .exchange, .mobileMe].contains($0.sourceType) }
            .map(\.title)
            .sorted()
    }

    /// True if a Google / Gmail CalDAV source is connected.
    func isGoogleCalendarConnected() -> Bool {
        guard isAuthorized else { return false }
        return store.sources.contains {
            $0.sourceType == .calDAV &&
            ($0.title.lowercased().contains("google") ||
             $0.title.lowercased().contains("gmail") ||
             $0.title.contains("@gmail"))
        }
    }

    /// All calendars the user can write events to, sorted by source name.
    func writableCalendars() -> [WritableCalendarInfo] {
        store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .map { cal in
                let srcTitle = cal.source?.title ?? "On My Mac"
                let srcType  = cal.source?.sourceType ?? .local
                let isGoogle = srcType == .calDAV &&
                    (srcTitle.lowercased().contains("google") ||
                     srcTitle.lowercased().contains("gmail") ||
                     srcTitle.contains("@gmail"))
                return WritableCalendarInfo(
                    id:         cal.calendarIdentifier,
                    title:      cal.title,
                    sourceName: srcTitle,
                    isGoogle:   isGoogle,
                    calColor:   cal.cgColor
                )
            }
            .sorted { $0.sourceName < $1.sourceName }
    }

    // MARK: - Write to Calendar

    /// Returns the dedicated "Flowline" calendar on the user's preferred source,
    /// creating it if it doesn't already exist there.
    private func flowlineCalendar() -> EKCalendar? {
        let preferredTitle = UserDefaults.standard.string(forKey: "saveCalendarSourceTitle") ?? ""

        // Resolve target source
        let targetSource: EKSource?
        if preferredTitle.isEmpty {
            targetSource = store.defaultCalendarForNewEvents?.source
        } else {
            targetSource = store.sources.first(where: { $0.title == preferredTitle })
        }

        // Re-use existing "Flowline" calendar only if it's on the right source
        if let existing = store.calendars(for: .event).first(where: {
            $0.title == "Flowline" &&
            (targetSource == nil || $0.source?.sourceIdentifier == targetSource?.sourceIdentifier)
        }) {
            return existing
        }

        // Create a new "Flowline" calendar on the target source
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = "Flowline"
        cal.source = targetSource
            ?? store.defaultCalendarForNewEvents?.source
            ?? store.sources.first(where: { $0.sourceType == .local })
        do {
            try store.saveCalendar(cal, commit: true)
            return cal
        } catch {
            return nil
        }
    }

    /// Saves plan blocks to the chosen calendar (by identifier) or falls back to the
    /// dedicated "Flowline" calendar. Deletes all previously Flowline-tagged events on
    /// affected dates across ALL writable calendars before writing the new ones.
    func savePlan(_ plan: GeneratedPlan, toCalendarID calendarID: String? = nil) throws {
        guard isAuthorized else { return }

        // Resolve target calendar
        let flCal: EKCalendar
        if let id = calendarID,
           let picked = store.calendar(withIdentifier: id),
           picked.allowsContentModifications {
            flCal = picked
        } else {
            guard let fallback = flowlineCalendar() else { return }
            flCal = fallback
        }

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let cal = Calendar.current

        // All dates this plan touches
        let affectedDates = Set(plan.blocks.compactMap { $0.date })

        // All writable calendars — so we can delete old Flowline events regardless of
        // which calendar they were saved to last time (e.g. user switched Google → iCloud).
        let allWritable = store.calendars(for: .event).filter { $0.allowsContentModifications }

        // Delete every Flowline-tagged event on affected dates across all calendars.
        // We check the notes tag so we never accidentally delete the user's own events.
        for dateStr in affectedDates {
            guard let day = dateFmt.date(from: dateStr) else { continue }
            let start = cal.startOfDay(for: day)
            let end   = cal.date(byAdding: .day, value: 1, to: start)!
            let pred  = store.predicateForEvents(withStart: start, end: end, calendars: allWritable)
            store.events(matching: pred)
                .filter { $0.notes?.contains("Added by Flowline") == true }
                .forEach { try? store.remove($0, span: .thisEvent, commit: false) }
        }

        // Write new events to the chosen calendar
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

        // Single commit — deletes and inserts land together
        try store.commit()
    }
}
