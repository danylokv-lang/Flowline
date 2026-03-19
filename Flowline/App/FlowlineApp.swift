/*
    Flowline
    Created by Danylo Kov: 15/03/26
*/

import SwiftUI
import SwiftData
import UserNotifications

@main
struct FlowlineApp: App {
    @StateObject private var timerManager = FocusTimerManager()
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FlowTask.self,
            ScheduleBlock.self,
            DayPlan.self,
            UserProfile.self,
            ChatMessage.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        // ── Main Window ───────────────────────────────────────────────────
        WindowGroup(id: "main") {
            if hasCompletedOnboarding {
                MainTabView()
                    .environmentObject(timerManager)
            } else {
                OnboardingView()
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: timerManager.isRunning) { wireDelegate() }

        // ── Menu Bar Extra ────────────────────────────────────────────────
        MenuBarExtra {
            MenuBarFlowlineView()
                .environmentObject(timerManager)
                .modelContainer(sharedModelContainer)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: timerManager.isRunning || timerManager.isOnBreak
                      ? "timer" : "sparkles")
                if timerManager.isRunning || timerManager.isOnBreak {
                    Text(timerManager.timeString())
                        .font(.system(size: 11, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    init() {}

    // Called after @StateObject is ready
    private func wireDelegate() {
        appDelegate.timerManager = timerManager
    }
}

// MARK: - AppDelegate for notification actions

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate,
                         @unchecked Sendable {
    static var shared: AppDelegate?
    var timerManager: FocusTimerManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    // Called when user taps a notification action
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            self.timerManager?.handleBreakAction(response.actionIdentifier)
            completionHandler()
        }
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
