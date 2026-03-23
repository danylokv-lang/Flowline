import Foundation
import Combine
import UserNotifications

// Notification identifiers
private let kBreakCategory   = "BREAK_REMINDER"
private let kBreak5Action    = "BREAK_5"
private let kBreak10Action   = "BREAK_10"
private let kBreakSkipAction = "BREAK_SKIP"
private let kHourlyBreakID   = "hourly_break_reminder"

@MainActor
final class FocusTimerManager: ObservableObject {

    // ── Focus state ───────────────────────────────────────────────────────
    @Published var selectedBlock: ScheduleBlock? = nil
    @Published var timeRemaining: TimeInterval = 0
    @Published var totalTime: TimeInterval = 0
    @Published var isRunning = false
    @Published var isPaused  = false

    // ── Break state ───────────────────────────────────────────────────────
    @Published var isOnBreak        = false
    @Published var breakTimeRemaining: TimeInterval = 0
    private var breakTotalTime: TimeInterval = 0

    private var timerRef: Timer? = nil

    // ── Load Block ────────────────────────────────────────────────────────

    func loadBlock(_ block: ScheduleBlock) {
        stop()
        selectedBlock  = block
        let duration   = block.endTime.timeIntervalSince(block.startTime)
        totalTime      = duration > 0 ? duration : 3600
        timeRemaining  = totalTime
    }

    // ── Focus Controls ────────────────────────────────────────────────────

    func start() {
        guard selectedBlock != nil else { return }
        if timeRemaining <= 0 { timeRemaining = totalTime }
        isRunning = true
        isPaused  = false
        isOnBreak = false
        tick()
    }

    func pause() {
        timerRef?.invalidate(); timerRef = nil
        isRunning = false; isPaused = true
    }

    func stop() {
        timerRef?.invalidate(); timerRef = nil
        isRunning = false; isPaused = false; isOnBreak = false
        if let block = selectedBlock {
            let duration = block.endTime.timeIntervalSince(block.startTime)
            totalTime     = duration > 0 ? duration : 3600
            timeRemaining = totalTime
        }
    }

    func reset() {
        timerRef?.invalidate(); timerRef = nil
        isRunning = false; isPaused = false
        timeRemaining = totalTime
    }

    // ── Break Controls ────────────────────────────────────────────────────

    func startBreak(minutes: Int) {
        timerRef?.invalidate(); timerRef = nil
        isRunning         = false
        isOnBreak         = true
        breakTotalTime    = TimeInterval(minutes * 60)
        breakTimeRemaining = breakTotalTime
        tickBreak()
    }

    func endBreak() {
        timerRef?.invalidate(); timerRef = nil
        isOnBreak          = false
        breakTimeRemaining = 0
    }

    // ── Internal Ticks ───────────────────────────────────────────────────

    private func tick() {
        timerRef = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let manager = self else { return }
            Task { @MainActor in
                if manager.timeRemaining > 0 {
                    manager.timeRemaining -= 1
                } else {
                    manager.finishSession()
                }
            }
        }
    }

    private func tickBreak() {
        timerRef = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let manager = self else { return }
            Task { @MainActor in
                if manager.breakTimeRemaining > 0 {
                    manager.breakTimeRemaining -= 1
                } else {
                    manager.endBreak()
                }
            }
        }
    }

    private func finishSession() {
        timerRef?.invalidate(); timerRef = nil
        isRunning = false; isPaused = false
        timeRemaining = 0
        sendBlockCompleteNotification()
    }

    // ── Hourly Notifications ──────────────────────────────────────────────

    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }
                Task { @MainActor in
                    self.registerBreakCategory()
                    self.scheduleHourlyBreaks()
                }
            }
    }

    private func registerBreakCategory() {
        let take5  = UNNotificationAction(identifier: kBreak5Action,
                                          title: "Take 5 min 🧘", options: [.foreground])
        let take10 = UNNotificationAction(identifier: kBreak10Action,
                                          title: "Take 10 min ☕️", options: [.foreground])
        let skip   = UNNotificationAction(identifier: kBreakSkipAction,
                                          title: "Skip", options: [])
        let category = UNNotificationCategory(identifier: kBreakCategory,
                                              actions: [take5, take10, skip],
                                              intentIdentifiers: [],
                                              options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func scheduleHourlyBreaks() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: (0..<8).map { "\(kHourlyBreakID)_\($0)" }
        )

        // Read work hours from UserDefaults (written by SyncService / ProfileForm)
        let ud = UserDefaults.standard
        let hasWorkHours = ud.bool(forKey: "profile.hasWorkHours")
        let startHour    = hasWorkHours ? ud.integer(forKey: "profile.workStartHour") : 9
        let rawEndHour   = hasWorkHours ? ud.integer(forKey: "profile.workEndHour") : 18
        let endHour      = max(rawEndHour, startHour + 1)

        let bodies = [
            "Coffee break? ☕️",
            "Quick stretch? 🧘",
            "Small break? Step away for a bit.",
            "5 min reset? Your focus will thank you.",
            "Time to breathe. Take a moment."
        ]

        let cal = Calendar.current
        let now = Date()
        var scheduled = 0

        // Look ahead up to 16 hours; only schedule within the work window
        for hoursAhead in 1...16 {
            guard scheduled < 8 else { break }
            guard let fireDate = cal.date(byAdding: .hour, value: hoursAhead, to: now) else { continue }
            let hour = cal.component(.hour, from: fireDate)
            guard hour >= startHour && hour < endHour else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Break time 🌿"
            content.body  = bodies[scheduled % bodies.count]
            content.sound = .default
            content.categoryIdentifier = kBreakCategory

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(hoursAhead * 3600),
                repeats: false
            )
            center.add(UNNotificationRequest(
                identifier: "\(kHourlyBreakID)_\(scheduled)",
                content: content,
                trigger: trigger
            ))
            scheduled += 1
        }
    }

    // Reschedule after app launch so reminders stay fresh
    func rescheduleIfNeeded() {
        scheduleHourlyBreaks()
    }

    // Called by app delegate / FlowlineApp when notification action fires
    func handleBreakAction(_ actionIdentifier: String) {
        switch actionIdentifier {
        case kBreak5Action:  startBreak(minutes: 5)
        case kBreak10Action: startBreak(minutes: 10)
        default: break
        }
    }

    // ── Notifications ─────────────────────────────────────────────────────

    private func sendBlockCompleteNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Block complete ✓"
        content.body  = "\(selectedBlock?.title ?? "Your session") is done. Take a break?"
        content.sound = .default
        content.categoryIdentifier = kBreakCategory
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    var progress: CGFloat {
        if isOnBreak {
            return breakTotalTime > 0
                ? CGFloat((breakTotalTime - breakTimeRemaining) / breakTotalTime)
                : 0
        }
        return totalTime > 0 ? CGFloat((totalTime - timeRemaining) / totalTime) : 0
    }

    func timeString() -> String {
        let t = Int(isOnBreak ? breakTimeRemaining : timeRemaining)
        let h = t / 3600
        let m = (t % 3600) / 60
        let s = t % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
