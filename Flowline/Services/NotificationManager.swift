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
///   • Morning planning reminder   (wake + 5 min, daily)
///   • Evening review reminder     (sleep − 30 min, daily)
///   • Block reminders             (configurable min before each block, one-time)
///   • Planning nudge              (9:00 am if no plan saved yet, daily)
///   • Tomorrow nudge              (9:00 pm — plan tomorrow before you sleep, daily)
///   • Streak protection           (8 pm if streak > 0, daily)
///   • Weekly summary              (Sunday 8 pm with stats)
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: - Stable IDs
    private let kMorningID   = "flowline.morning.planning"
    private let kEveningID   = "flowline.evening.review"
    private let kNudgeID     = "flowline.nudge.noplan"
    private let kTomorrowID  = "flowline.nudge.tomorrow"
    private let kStreakID    = "flowline.streak.protection"
    private let kWeeklyID    = "flowline.weekly.summary"
    private let kBlockPrefix = "flowline.block."   // + block start ISO string

    // MARK: - UserDefaults keys for user preferences
    static let blockReminderMinutesKey  = "blockReminderMinutes"
    static let tomorrowNudgeEnabledKey  = "tomorrowNudgeEnabled"
    static let weeklyNudgeEnabledKey    = "weeklyNudgeEnabled"
    static let streakAlertsEnabledKey   = "streakAlertsEnabled"
    static let morningReminderEnabledKey = "morningReminderEnabled"
    static let eveningReminderEnabledKey = "eveningReminderEnabled"

    /// Minutes before a block fires the reminder. Defaults to 10.
    var blockReminderMinutes: Int {
        let v = UserDefaults.standard.integer(forKey: Self.blockReminderMinutesKey)
        return v > 0 ? v : 10
    }

    /// Reads a boolean preference, defaulting to `true` when the key was never written.
    /// `UserDefaults.bool(forKey:)` returns `false` for absent keys regardless of
    /// the `@AppStorage` default declared in the view — this method closes that gap.
    private func isEnabled(_ key: String) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

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

    /// Request permission + schedule all daily reminders.
    /// Call after onboarding is complete.
    func requestAndSchedule(name: String, wakeTime: Date, sleepTime: Date) async {
        guard await requestAuthorization() else { return }
        scheduleMorning(name: name, wakeTime: wakeTime)
        scheduleEvening(sleepTime: sleepTime)
        schedulePlanningNudge()
        scheduleTomorrowNudge(sleepTime: sleepTime)
        scheduleStreakReminder(streakDays: 0, sleepTime: sleepTime)
    }

    /// Re-schedule daily reminders after wake/sleep update in Settings.
    func reschedule(name: String, wakeTime: Date, sleepTime: Date) {
        if UserDefaults.standard.bool(forKey: Self.morningReminderEnabledKey) {
            scheduleMorning(name: name, wakeTime: wakeTime)
        }
        if UserDefaults.standard.bool(forKey: Self.eveningReminderEnabledKey) {
            scheduleEvening(sleepTime: sleepTime)
        }
        if UserDefaults.standard.bool(forKey: Self.tomorrowNudgeEnabledKey) {
            scheduleTomorrowNudge(sleepTime: sleepTime)
        }
        scheduleStreakReminder(streakDays: 0, sleepTime: sleepTime)
    }

    /// Call every time a plan is saved.
    func onPlanSaved(blocks: [ScheduleBlock], streakDays: Int, sleepTime: Date) {
        scheduleBlockReminders(for: blocks)
        cancelPlanningNudge()
        scheduleStreakReminder(streakDays: streakDays, sleepTime: sleepTime)
    }

    /// Call when weekly stats are available (e.g. on Sunday or after plan save).
    func refreshWeeklySummary(completedDays: Int, streak: Int) {
        guard UserDefaults.standard.bool(forKey: Self.weeklyNudgeEnabledKey) else { return }
        scheduleWeeklySummary(completedDays: completedDays, streak: streak)
    }

    /// Cancel everything. Call on sign-out.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Morning

    func scheduleMorning(name: String, wakeTime: Date) {
        center.removePendingNotificationRequests(withIdentifiers: [kMorningID])
        guard isEnabled(Self.morningReminderEnabledKey) else { return }

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

    func scheduleEvening(sleepTime: Date) {
        center.removePendingNotificationRequests(withIdentifiers: [kEveningID])
        guard isEnabled(Self.eveningReminderEnabledKey) else { return }

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

    /// Schedules a one-time "starts in X min" notification for each future block today.
    /// Timing controlled by `blockReminderMinutes` from UserDefaults.
    func scheduleBlockReminders(for blocks: [ScheduleBlock]) {
        struct BlockSnap { let title: String; let start: Date; let end: Date }
        let snaps = blocks.map { BlockSnap(title: $0.title, start: $0.startTime, end: $0.endTime) }
        let minutesBefore = blockReminderMinutes

        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let oldIDs = pending.map(\.identifier).filter { $0.hasPrefix(self.kBlockPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: oldIDs)

            guard minutesBefore > 0 else { return }   // 0 = reminders disabled

            let now = Date()
            let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
            let isoFormatter = ISO8601DateFormatter()

            for snap in snaps {
                let fireAt = snap.start.addingTimeInterval(-Double(minutesBefore) * 60)
                guard fireAt > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "\(snap.title) starts in \(minutesBefore) min"
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

    // MARK: - Planning Nudge (9am — no plan yet today)

    /// Daily 9:00 am nudge — if no plan has been saved yet today.
    func schedulePlanningNudge() {
        center.removePendingNotificationRequests(withIdentifiers: [kNudgeID])

        let content = UNMutableNotificationContent()
        content.title = "No plan yet today 📋"
        content.body = "30 seconds is all it takes. Tap to plan your day."
        content.sound = .default
        content.userInfo = ["action": "openChat", "prompt": "Plan my day quickly"]

        var comps = DateComponents()
        comps.hour = 9; comps.minute = 0

        center.add(UNNotificationRequest(
            identifier: kNudgeID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        ))
    }

    func cancelPlanningNudge() {
        center.removePendingNotificationRequests(withIdentifiers: [kNudgeID])
    }

    // MARK: - Tomorrow Nudge (60–15 min before sleep)

    /// Daily nudge — plan tomorrow 30-60 minutes before bed.
    /// Fires 45 minutes before sleep time for a good buffer before wind-down.
    func scheduleTomorrowNudge(sleepTime: Date) {
        center.removePendingNotificationRequests(withIdentifiers: [kTomorrowID])
        guard isEnabled(Self.tomorrowNudgeEnabledKey) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Plan tomorrow before you sleep? 🌙"
        content.body = "Set yourself up for a great day — 30 seconds is all it takes."
        content.sound = .default
        content.userInfo = [
            "action": "openChat",
            "prompt": "Help me plan tomorrow"
        ]

        // Fire 45 minutes before sleep time (middle of 60-15 min window)
        var comps = Calendar.current.dateComponents([.hour, .minute], from: sleepTime)
        var h = comps.hour ?? 23
        var m = (comps.minute ?? 0) - 45
        if m < 0 { m += 60; h = max(h - 1, 0) }
        comps.hour = h; comps.minute = m

        center.add(UNNotificationRequest(
            identifier: kTomorrowID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        ))
    }

    func cancelTomorrowNudge() {
        center.removePendingNotificationRequests(withIdentifiers: [kTomorrowID])
    }

    // MARK: - Streak Protection (8pm)

    func scheduleStreakReminder(streakDays: Int, sleepTime: Date) {
        center.removePendingNotificationRequests(withIdentifiers: [kStreakID])
        guard isEnabled(Self.streakAlertsEnabledKey) else { return }

        let content = UNMutableNotificationContent()
        if streakDays >= 7 {
            content.title = "\(streakDays)-day streak 🔥 Don't break the chain"
            content.body = "Plan something for today — even 10 minutes keeps the streak alive."
        } else if streakDays >= 2 {
            content.title = "\(streakDays)-day streak at risk 🔥"
            content.body = "Plan today and keep your streak going."
        } else if streakDays == 0 {
            content.title = "Start a new streak today 🔁"
            content.body = "Yesterday's gone — today is day 1. Tap to plan."
        } else {
            content.title = "Build your streak ✦"
            content.body = "Plan today and start a streak. Day 1 is the hardest."
        }
        content.sound = .default
        content.userInfo = ["action": "openChat"]

        let sleepComps = Calendar.current.dateComponents([.hour], from: sleepTime)
        let sleepHour = sleepComps.hour ?? 23
        let fireHour = sleepHour < 21 ? max(sleepHour - 1, 18) : 20

        var comps = DateComponents()
        comps.hour = fireHour; comps.minute = 0

        center.add(UNNotificationRequest(
            identifier: kStreakID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        ))
    }

    // MARK: - Weekly Summary (Sunday 8pm)

    /// Sunday 8:00 pm — show weekly stats and nudge to keep going.
    func scheduleWeeklySummary(completedDays: Int, streak: Int) {
        center.removePendingNotificationRequests(withIdentifiers: [kWeeklyID])

        let content = UNMutableNotificationContent()
        content.title = "Your week in review 📊"
        if completedDays >= 5 {
            content.body = "\(completedDays) days planned this week 🔥 \(streak > 0 ? "\(streak)-day streak." : "Keep it up!")"
        } else if completedDays >= 3 {
            content.body = "\(completedDays)/7 days planned · \(streak > 0 ? "\(streak)-day streak" : "start your streak tomorrow")"
        } else {
            content.body = "Only \(completedDays) days planned this week. Let's do better next week 💪"
        }
        content.sound = .default
        content.userInfo = ["action": "openStats"]

        var comps = DateComponents()
        comps.weekday = 1  // Sunday
        comps.hour = 20; comps.minute = 0

        center.add(UNNotificationRequest(
            identifier: kWeeklyID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        ))
    }
}
