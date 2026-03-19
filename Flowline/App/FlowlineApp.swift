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
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var colorManager = CategoryColorManager()
    @StateObject private var authService = AuthService()
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FlowTask.self,
            ScheduleBlock.self,
            DayPlan.self,
            UserProfile.self,
            ChatMessage.self,
            CapturedTask.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("lastLoggedInUserId")     private var lastLoggedInUserId: String = ""

    var body: some Scene {
        // ── Main Window ───────────────────────────────────────────────────
        WindowGroup(id: "main") {
            ZStack {
                if !authService.isLoggedIn {
                    AuthView()
                        .environmentObject(authService)
                } else if hasCompletedOnboarding {
                    MainTabView()
                        .environmentObject(timerManager)
                        .environmentObject(subscriptionManager)
                        .environmentObject(colorManager)
                        .environmentObject(authService)
                } else {
                    OnboardingView()
                        .environmentObject(authService)
                }
                // Wire delegate on first render, not on state change
                appSetup
            }
            // When the logged-in user changes, wipe local profile data
            // so the new account starts with a clean slate
            .onChange(of: authService.currentUser?.userId) { _, newUserId in
                guard let newUserId else { return }
                if newUserId != lastLoggedInUserId {
                    clearLocalUserData()
                    lastLoggedInUserId = newUserId
                }
            }
        }
        .modelContainer(sharedModelContainer)

        // ── Settings (Cmd+,) ──────────────────────────────────────────────
        Settings {
            SettingsView()
                .modelContainer(sharedModelContainer)
                .environmentObject(colorManager)
                .environmentObject(authService)
        }

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

    // Wire delegate immediately — not dependent on any state change
    private func wireDelegate() {
        appDelegate.timerManager = timerManager
    }

    /// Wipe ALL local SwiftData when a different account logs in.
    /// This ensures no data leaks between accounts on the same device.
    private func clearLocalUserData() {
        let ctx = sharedModelContainer.mainContext
        if let items = try? ctx.fetch(FetchDescriptor<UserProfile>())    { items.forEach { ctx.delete($0) } }
        if let items = try? ctx.fetch(FetchDescriptor<ChatMessage>())    { items.forEach { ctx.delete($0) } }
        if let items = try? ctx.fetch(FetchDescriptor<DayPlan>())        { items.forEach { ctx.delete($0) } }
        if let items = try? ctx.fetch(FetchDescriptor<CapturedTask>())   { items.forEach { ctx.delete($0) } }
        if let items = try? ctx.fetch(FetchDescriptor<FlowTask>())       { items.forEach { ctx.delete($0) } }
        try? ctx.save()
        // Reset onboarding so the new user sets up their profile
        hasCompletedOnboarding = false
    }

    private var appSetup: some View {
        Color.clear
            .onAppear { wireDelegate() }
    }
}

// MARK: - AppDelegate for notification actions

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate,
                         @unchecked Sendable {
    static var shared: AppDelegate?
    var timerManager: FocusTimerManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        // timerManager is wired immediately after launch via AppDelegate.shared
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up pending hourly notifications on quit so they reschedule fresh on next launch
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
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
