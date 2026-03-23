/*
    Flowline
    Created by Danylo Kov: 15/03/26
*/

import SwiftUI
import SwiftData
import UserNotifications
import RevenueCat

@main
struct FlowlineApp: App {
    @StateObject private var timerManager = FocusTimerManager()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var colorManager = CategoryColorManager()
    @StateObject private var authService = AuthService()

    #if os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    #endif

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

    @AppStorage("hasSeenIntro")           private var hasSeenIntro = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("lastLoggedInUserId")     private var lastLoggedInUserId: String = ""

    var body: some Scene {
        // ── Main Window ───────────────────────────────────────────────────
        WindowGroup(id: "main") {
            ZStack {
                if !hasSeenIntro {
                    AppIntroView()
                } else if !authService.isLoggedIn {
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
                        .environmentObject(subscriptionManager)
                }
                appSetup
            }
            .onChange(of: authService.currentUser?.userId) { _, newUserId in
                guard let newUserId else { return }
                // Scope streak data to this user — must happen before clearLocalUserData
                StreakManager.shared.configure(userId: newUserId)
                if newUserId != lastLoggedInUserId {
                    clearLocalUserData()
                    lastLoggedInUserId = newUserId
                    // Pull fresh data from server after switching accounts
                    if let token = authService.token {
                        Task { await SyncService.shared.pullAll(token: token, context: sharedModelContainer.mainContext) }
                    }
                }
                subscriptionManager.startTrialIfNeeded()
            }
            .task {
                // Pull on every app launch if already logged in
                if authService.isLoggedIn, let token = authService.token {
                    await SyncService.shared.pullAll(token: token, context: sharedModelContainer.mainContext)
                }
            }
        }
        .modelContainer(sharedModelContainer)

        #if os(macOS)
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
        #endif
    }

    private func wireDelegate() {
        #if os(macOS)
        appDelegate.timerManager = timerManager
        #endif
    }

    private func clearLocalUserData() {
        let ctx = sharedModelContainer.mainContext
        if let items = try? ctx.fetch(FetchDescriptor<UserProfile>())    { items.forEach { ctx.delete($0) } }
        if let items = try? ctx.fetch(FetchDescriptor<ChatMessage>())    { items.forEach { ctx.delete($0) } }
        if let items = try? ctx.fetch(FetchDescriptor<DayPlan>())        { items.forEach { ctx.delete($0) } }
        if let items = try? ctx.fetch(FetchDescriptor<CapturedTask>())   { items.forEach { ctx.delete($0) } }
        if let items = try? ctx.fetch(FetchDescriptor<FlowTask>())       { items.forEach { ctx.delete($0) } }
        try? ctx.save()
        hasCompletedOnboarding = false
        StreakManager.shared.resetForAccountSwitch()
        // Reset daily AI usage so the new account starts fresh
        UserDefaults.standard.removeObject(forKey: "usage_count")
        UserDefaults.standard.removeObject(forKey: "usage_date")
        UserDefaults.standard.removeObject(forKey: "chats.lastSyncTimestamp")
    }

    private var appSetup: some View {
        Color.clear.onAppear { wireDelegate() }
    }
}

// MARK: - AppDelegate (macOS only)

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate,
                         @unchecked Sendable {
    static var shared: AppDelegate?
    var timerManager: FocusTimerManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationWillTerminate(_ notification: Notification) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            self.timerManager?.handleBreakAction(response.actionIdentifier)
            completionHandler()
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
#endif
