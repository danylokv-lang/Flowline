import Foundation
import UserNotifications

// MARK: - Notification name (shared between FlowlineApp & MainTabView)

extension Notification.Name {
    /// Posted when the user taps a Flowline push notification.
    /// object is an optional String prompt to auto-send, or nil to just open chat.
    static let flowlineOpenChat = Notification.Name("flowline.openChat")
}

// MARK: - NotificationManager

/// Manages two daily local notifications:
///   • Morning planning reminder  (user's wake time + 5 min)
///   • Evening review reminder    (user's sleep time − 30 min)
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let kMorningID = "flowline.morning.planning"
    private let kEveningID = "flowline.evening.review"

    // MARK: - Public API

    /// Request permission then schedule both reminders. Call after onboarding.
    func requestAndSchedule(name: String, wakeTime: Date, sleepTime: Date) async {
        guard await requestAuthorization() else { return }
        scheduleMorning(name: name, wakeTime: wakeTime)
        scheduleEvening(sleepTime: sleepTime)
    }

    /// Re-schedule after the user updates wake/sleep times in Settings.
    func reschedule(name: String, wakeTime: Date, sleepTime: Date) {
        scheduleMorning(name: name, wakeTime: wakeTime)
        scheduleEvening(sleepTime: sleepTime)
    }

    func cancelAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [kMorningID, kEveningID])
    }

    // MARK: - Permission

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
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

    // MARK: - Private scheduling

    private func scheduleMorning(name: String, wakeTime: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [kMorningID])

        let content = UNMutableNotificationContent()
        content.title = "Good morning, \(name)! ☀️"
        content.body = "Ready to plan your day? Tap to build your schedule."
        content.sound = .default
        content.userInfo = ["action": "openChat"]

        // Wake time + 5 minutes
        var comps = Calendar.current.dateComponents([.hour, .minute], from: wakeTime)
        var h = comps.hour ?? 7
        var m = (comps.minute ?? 0) + 5
        if m >= 60 { m -= 60; h = min(h + 1, 23) }
        comps.hour = h
        comps.minute = m

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: kMorningID, content: content, trigger: trigger))
    }

    private func scheduleEvening(sleepTime: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [kEveningID])

        let content = UNMutableNotificationContent()
        content.title = "How did today go? 🌙"
        content.body = "Quick review — tap to reflect and improve tomorrow's plan."
        content.sound = .default
        // Pass a prompt so the chat auto-sends it on tap
        content.userInfo = [
            "action": "openChat",
            "prompt": "Quick end-of-day review — how did my plan go today?"
        ]

        // Sleep time − 30 minutes
        var comps = Calendar.current.dateComponents([.hour, .minute], from: sleepTime)
        var h = comps.hour ?? 23
        var m = (comps.minute ?? 0) - 30
        if m < 0 { m += 60; h = max(h - 1, 0) }
        comps.hour = h
        comps.minute = m

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: kEveningID, content: content, trigger: trigger))
    }
}
