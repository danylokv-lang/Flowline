import Foundation
import UserNotifications

// MARK: - Notification name (shared between FlowlineApp & MainTabView)

extension Notification.Name {
    /// Posted when the user taps a Flowline push notification.
    /// object is an optional String prompt to auto-send, or nil to just open chat.
    static let flowlineOpenChat = Notification.Name("flowline.openChat")
}

// MARK: - NotificationManager

/// Manages all local notifications for Flowline:
///   • Morning planning reminder  (wake + 5 min, daily)
///   • Evening review reminder    (sleep − 30 min, daily)
///   • Block reminders            (10 min before each saved block, one-time)
///   • Planning nudge             (9:00 am if no plan saved yet, daily)
///   • Streak protection          (8 pm if streak > 0, daily — cancelled on save)
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // Stable IDs
    private let kMorningID  = "flowline.morning.planning"
    private let kEveningID  = "flowline.evening.review"
    private let kNudgeID    = "flowline.nudge.noplan"
    private let kStreakID   = "flowline.streak.protection"
    private let kBlockPrefix = "flowline.block."   // + block start ISO string

    // MARK: - Permission

    func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        default:
            return false
        }
    }

    // MARK: - Public API

    /// Request permission + schedule morning, evening, nudge, streak reminders.
    /// Call after onboarding is complete.
    func requestAndSchedule(name: String, wakeTime: Date, sleepTime: Date) async {
        guard await requestAuthorization() else { return }
        scheduleMorning(name: name, wakeTime: wakeTime)
        scheduleEvening(sleepTime: sleepTime)
        schedulePlanningNudge()
        scheduleStreakReminder(streakDays: 0, sleepTime: sleepTime)
    }

    /// Re-schedule daily reminders after wake/sleep update in Settings.
    func reschedule(name: String, wakeTime: Date, sleepTime: Date) {
        scheduleMorning(name: name, wakeTime: wakeTime)
        scheduleEvening(sleepTime: sleepTime)
        scheduleStreakReminder(streakDays: 0, sleepTime: sleepTime)
    }

    /// Call every time a plan is saved.
    /// - Schedules 10-min-before reminders for each block.
    /// - Cancels today's planning nudge (plan exists → no longer needed).
    /// - Updates streak protection text.
    func onPlanSaved(blocks: [ScheduleBlock], streakDays: Int, sleepTime: Date) {
        scheduleBlockReminders(for: blocks)
        cancelPlanningNudge()
        scheduleStreakReminder(streakDays: streakDays, sleepTime: sleepTime)
    }

    /// Cancel everything. Call on sign-out.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Morning

    private func scheduleMorning(name: String, wakeTime: Date) {
        center.removePendingNotificationRequests(withIdentifiers: [kMorningID])

        let content = UNMutableNotificationContent()
        content.title = "Good morning, \(name)! ☀️"
        content.body = "Ready to plan your day? Tap to build your schedule."
        content.sound = .default
        content.userInfo = ["action": "openChat"]

        var comps = Calendar.current.dateComponents([.hour, .minute], from: wakeTime)
        var h = comps.hour ?? 7
        var m = (comps.minute ?? 0) + 5
        if m >= 60 { m -= 60; h = min(h + 1, 23) }
        comps.hour = h; comps.minute = m

        center.add(UNNotificationRequest(
            identifier: kMorningID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        ))
    }

    // MARK: - Evening

    private func scheduleEvening(sleepTime: Date) {
        center.removePendingNotificationRequests(withIdentifiers: [kEveningID])

        let content = UNMutableNotificationContent()
        content.title = "How did today go? 🌙"
        content.body = "Quick review — tap to reflect and improve tomorrow's plan."
        content.sound = .default
        content.userInfo = [
            "action": "openChat",
            "prompt": "Quick end-of-day review — how did my plan go today?"
        ]

        var comps = Calendar.current.dateComponents([.hour, .minute], from: sleepTime)
        var h = comps.hour ?? 23
        var m = (comps.minute ?? 0) - 30
        if m < 0 { m += 60; h = max(h - 1, 0) }
        comps.hour = h; comps.minute = m

        center.add(UNNotificationRequest(
            identifier: kEveningID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        ))
    }

    // MARK: - Block Reminders

    /// Schedules a one-time "starts in 10 min" notification for each future block today.
    func scheduleBlockReminders(for blocks: [ScheduleBlock]) {
        // Snapshot needed data from @Model objects on the calling thread before
        // entering the callback (which runs on an arbitrary thread).
        struct BlockSnap { let title: String; let start: Date; let end: Date }
        let snaps = blocks.map { BlockSnap(title: $0.title, start: $0.startTime, end: $0.endTime) }

        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let oldIDs = pending.map(\.identifier).filter { $0.hasPrefix(self.kBlockPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: oldIDs)

            let now = Date()
            let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
            let isoFormatter = ISO8601DateFormatter()

            for snap in snaps {
                let fireAt = snap.start.addingTimeInterval(-10 * 60)
                guard fireAt > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "\(snap.title) starts in 10 min"
                content.body = "\(fmt.string(from: snap.start)) – \(fmt.string(from: snap.end))"
                content.sound = .default
                content.userInfo = ["action": "openChat"]

                let comps = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireAt
                )
                let id = self.kBlockPrefix + isoFormatter.string(from: snap.start)
                self.center.add(UNNotificationRequest(
                    identifier: id,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                ))
            }
        }
    }

    // MARK: - Planning Nudge

    /// Daily 9:00 am nudge — if no plan has been saved yet today.
    /// Cancelled automatically via `cancelPlanningNudge()` when a plan is saved.
    func schedulePlanningNudge() {
        center.removePendingNotificationRequests(withIdentifiers: [kNudgeID])

        let content = UNMutableNotificationContent()
        content.title = "No plan yet today 📋"
        content.body = "30 seconds is all it takes. Tap to plan your day."
        content.sound = .default
        content.userInfo = [
            "action": "openChat",
            "prompt": "Plan my day quickly"
        ]

        var comps = DateComponents()
        comps.hour = 9
        comps.minute = 0

        center.add(UNNotificationRequest(
            identifier: kNudgeID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        ))
    }

    func cancelPlanningNudge() {
        center.removePendingNotificationRequests(withIdentifiers: [kNudgeID])
    }

    // MARK: - Streak Protection

    /// Daily 8 pm reminder to protect a streak.
    /// If streak is 0 or unknown, shows generic "build your streak" copy.
    func scheduleStreakReminder(streakDays: Int, sleepTime: Date) {
        center.removePendingNotificationRequests(withIdentifiers: [kStreakID])

        let content = UNMutableNotificationContent()
        if streakDays >= 2 {
            content.title = "\(streakDays)-day streak at risk 🔥"
            content.body = "Plan something — even 10 minutes — to keep your streak alive."
        } else {
            content.title = "Build your streak ✦"
            content.body = "Plan today and start a streak. Day 1 is the hardest."
        }
        content.sound = .default
        content.userInfo = ["action": "openChat"]

        // Fire at 20:00 or 1h before sleep if sleep is earlier than 21:00
        let sleepComps = Calendar.current.dateComponents([.hour], from: sleepTime)
        let sleepHour = sleepComps.hour ?? 23
        let fireHour = sleepHour < 21 ? max(sleepHour - 1, 18) : 20

        var comps = DateComponents()
        comps.hour = fireHour
        comps.minute = 0

        center.add(UNNotificationRequest(
            identifier: kStreakID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        ))
    }
}

