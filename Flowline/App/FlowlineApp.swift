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
    #elseif os(iOS)
    @UIApplicationDelegateAdaptor private var iosDelegate: IOSAppDelegate
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

    /// True while we are pulling server data after a login/account-switch.
    /// During this window we show a spinner so the user never sees the wrong screen.
    @State private var isSyncingAfterLogin = false

    var body: some Scene {
        // ── Main Window ───────────────────────────────────────────────────
        WindowGroup(id: "main") {
            ZStack {
                if !hasSeenIntro {
                    AppIntroView()
                } else if !authService.isLoggedIn {
                    AuthView()
                        .environmentObject(authService)
                } else if isSyncingAfterLogin {
                    // Pulling profile from server — wait before deciding which screen to show
                    ZStack {
                        Color(hex: "#080810").ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.2)
                    }
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
                    // Pull fresh data from server — show spinner until done so we
                    // never flash the wrong screen (e.g. onboarding for a returning user)
                    if let token = authService.token {
                        isSyncingAfterLogin = true
                        Task {
                            await SyncService.shared.pullAll(token: token, context: sharedModelContainer.mainContext)
                            isSyncingAfterLogin = false
                        }
                    }
                }
                subscriptionManager.startTrialIfNeeded()
            }
            .task {
                // Set up RevenueCat AFTER first frame so launch completes
                // before any file I/O happens on the main thread.
                await subscriptionManager.setup()

                // Pull server data on every launch if already logged in
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
        // NOTE: hasCompletedOnboarding is NOT reset here.
        // pullProfile() always writes the server's onboarding_done value,
        // so the correct state is set once the pull completes.
        StreakManager.shared.resetForAccountSwitch()
        // Reset weekly plan limit so the new account starts fresh
        UserDefaults.standard.removeObject(forKey: "plans_this_week")
        UserDefaults.standard.removeObject(forKey: "plans_week_num")
        UserDefaults.standard.removeObject(forKey: "plans_week_year")
        UserDefaults.standard.removeObject(forKey: "total_plan_saves")
        UserDefaults.standard.removeObject(forKey: "chats.lastSyncTimestamp")
    }

    private var appSetup: some View {
        Color.clear.onAppear { wireDelegate() }
    }
}

// MARK: - AppDelegate (iOS)

#if os(iOS)
final class IOSAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate,
                            @unchecked Sendable {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Called when the user taps a notification while the app is in background or closed
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let prompt = response.notification.request.content.userInfo["prompt"] as? String
        // Post to main thread so SwiftUI views can react
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .flowlineOpenChat, object: prompt)
        }
        completionHandler()
    }

    // Called when a notification arrives while the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
#endif

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
