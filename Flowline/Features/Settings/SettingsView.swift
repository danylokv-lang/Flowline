import SwiftUI
import SwiftData
import UserNotifications
import EventKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// Shared helper — wraps .navigationBarTitleDisplayMode(.inline) which is iOS-only
private extension View {
    func inlineNavTitle() -> some View {
        #if os(iOS)
        return self.navigationBarTitleDisplayMode(.inline)
        #else
        return self
        #endif
    }
}

// Shared helper — opens a URL on any platform
private func openSystemURL(_ url: URL) {
    #if os(macOS)
    NSWorkspace.shared.open(url)
    #else
    UIApplication.shared.open(url)
    #endif
}

// ── Settings entry point ─────────────────────────────────────────────────────

struct SettingsView: View {
    var body: some View {
        #if os(macOS)
        macOSSettingsRoot()
        #else
        iOSSettingsRoot()
        #endif
    }
}

// MARK: - macOS Settings (native TabView)

#if os(macOS)
private struct macOSSettingsRoot: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.modelContext) private var context
    @Query private var messages: [ChatMessage]
    @Query private var dayPlans: [DayPlan]
    @Query private var capturedTasks: [CapturedTask]
    @Query private var profiles: [UserProfile]
    @AppStorage("hasSeenIntro")           private var hasSeenIntro = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("lastLoggedInUserId")     private var lastLoggedInUserId: String = ""
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false

    var body: some View {
        TabView {
            ProfileSettingsTab()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }

            AppearanceSettingsTab()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }

            CalendarSettingsTab()
                .tabItem { Label("Calendars", systemImage: "calendar") }

            NotificationSettingsTab()
                .tabItem { Label("Notifications", systemImage: "bell") }

            FocusSettingsTab()
                .tabItem { Label("Focus", systemImage: "timer") }

            DataSettingsTab()
                .tabItem { Label("Data", systemImage: "externaldrive") }

            accountTab
                .tabItem { Label("Account", systemImage: "person.crop.circle.badge.checkmark") }
        }
        .frame(width: 500, height: 440)
        .confirmationDialog("Log out of Flowline?",
                            isPresented: $showLogoutConfirm,
                            titleVisibility: .visible) {
            Button("Log Out", role: .destructive) { authService.logout() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete your account?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete Everything & Sign Out", role: .destructive) { deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All data — chats, calendar blocks, and your profile — will be permanently erased.")
        }
    }

    private var accountTab: some View {
        Form {
            if let user = authService.currentUser {
                Section("Signed In As") {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Text(String(user.name.prefix(1)).uppercased())
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.purple)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(user.name)
                                    .font(.system(size: 13, weight: .semibold))
                                if user.isPro {
                                    Text("PRO")
                                        .font(.system(size: 9, weight: .heavy))
                                        .tracking(1)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.18))
                                        .foregroundColor(.purple)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(user.email)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section {
                Button("Log Out") { showLogoutConfirm = true }
                    .foregroundColor(.red)
                Button("Delete Account…") { showDeleteConfirm = true }
                    .foregroundColor(.red)
            } footer: {
                Text("Deleting your account removes all local data and signs you out.")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            Section("About") {
                infoRow("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                infoRow("Build",   value: Bundle.main.infoDictionary?["CFBundleVersion"]            as? String ?? "1")
            }
        }
        .formStyle(.grouped)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundColor(.secondary) }
    }

    private func deleteAll() {
        messages.forEach { context.delete($0) }
        dayPlans.forEach { context.delete($0) }
        capturedTasks.forEach { context.delete($0) }
        profiles.forEach { context.delete($0) }
        hasSeenIntro = false
        hasCompletedOnboarding = false
        lastLoggedInUserId = ""
        authService.logout()
    }
}
#endif

// MARK: - iOS Settings (navigation list)

#if os(iOS)
private struct iOSSettingsRoot: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.modelContext) private var context
    @Query private var messages: [ChatMessage]
    @Query private var dayPlans: [DayPlan]
    @Query private var capturedTasks: [CapturedTask]
    @Query private var profiles: [UserProfile]
    @AppStorage("hasSeenIntro")           private var hasSeenIntro = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("lastLoggedInUserId")     private var lastLoggedInUserId: String = ""

    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                // ── Personalisation ──────────────────────────────────────────
                Section {
                    NavigationLink {
                        ProfileSettingsTab()
                            .navigationTitle("Profile")
                            .inlineNavTitle()
                    } label: {
                        settingsRow(icon: "person.crop.circle", color: .blue, title: "Profile")
                    }

                    NavigationLink {
                        AppearanceSettingsTab()
                            .navigationTitle("Appearance")
                            .inlineNavTitle()
                    } label: {
                        settingsRow(icon: "paintpalette", color: .purple, title: "Appearance")
                    }
                }

                // ── App features ─────────────────────────────────────────────
                Section {
                    NavigationLink {
                        NotificationSettingsTab()
                            .navigationTitle("Notifications")
                            .inlineNavTitle()
                    } label: {
                        settingsRow(icon: "bell.badge", color: .red, title: "Notifications")
                    }

                    NavigationLink {
                        FocusSettingsTab()
                            .navigationTitle("Focus Timer")
                            .inlineNavTitle()
                    } label: {
                        settingsRow(icon: "timer", color: .orange, title: "Focus Timer")
                    }

                    NavigationLink {
                        CalendarSettingsTab()
                            .navigationTitle("Calendars")
                            .inlineNavTitle()
                    } label: {
                        settingsRow(icon: "calendar", color: .red, title: "Calendars")
                    }
                }

                // ── Data & Storage ───────────────────────────────────────────
                Section {
                    NavigationLink {
                        DataSettingsTab()
                            .navigationTitle("Data & Storage")
                            .inlineNavTitle()
                    } label: {
                        settingsRow(icon: "externaldrive", color: .gray, title: "Data & Storage")
                    }
                }

                // ── Account ──────────────────────────────────────────────────
                Section {
                    if let user = authService.currentUser {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.18))
                                    .frame(width: 36, height: 36)
                                Text(String(user.name.prefix(1)).uppercased())
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(user.email)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if user.isPro {
                                Text("PRO")
                                    .font(.system(size: 9, weight: .heavy))
                                    .tracking(1)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.purple.opacity(0.18))
                                    .foregroundColor(.purple)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Button {
                        showLogoutConfirm = true
                    } label: {
                        Label("Log Out", systemImage: "arrow.right.square")
                            .foregroundColor(.red)
                    }

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Deleting your account removes all local data and signs you out.")
                        .font(.system(size: 11))
                }

                // ── About ────────────────────────────────────────────────────
                Section("About") {
                    HStack {
                        Text("Version")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
        .confirmationDialog("Log out of Flowline?",
                            isPresented: $showLogoutConfirm,
                            titleVisibility: .visible) {
            Button("Log Out", role: .destructive) { authService.logout() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete your account?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete Everything & Sign Out", role: .destructive) { deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All data — chats, calendar blocks, and your profile — will be permanently erased.")
        }
    }

    // ── Row helper ────────────────────────────────────────────────────────────
    private func settingsRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(title)
                .foregroundColor(.primary)
        }
    }

    // ── Delete all local data + sign out ──────────────────────────────────────
    private func deleteAll() {
        messages.forEach { context.delete($0) }
        dayPlans.forEach { context.delete($0) }
        capturedTasks.forEach { context.delete($0) }
        profiles.forEach { context.delete($0) }
        hasSeenIntro = false
        hasCompletedOnboarding = false
        lastLoggedInUserId = ""
        authService.logout()
    }
}
#endif

// MARK: - Profile Tab

private struct ProfileSettingsTab: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if let profile = profiles.first {
            ProfileForm(profile: profile)
        } else {
            Text("No profile found. Complete onboarding first.")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ProfileForm: View {
    @Bindable var profile: UserProfile
    @State private var wakeTime: Date
    @State private var sleepTime: Date
    @State private var workStart: Date
    @State private var workEnd: Date

    init(profile: UserProfile) {
        self.profile = profile
        _wakeTime   = State(initialValue: profile.wakeTime)
        _sleepTime  = State(initialValue: profile.sleepTime)
        _workStart  = State(initialValue: profile.workStartTime ?? profile.wakeTime)
        _workEnd    = State(initialValue: profile.workEndTime ?? profile.sleepTime)
    }

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Your name", text: $profile.name)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Schedule") {
                DatePicker("Wake up", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    .onChange(of: wakeTime) {
                        profile.wakeTime = wakeTime
                        NotificationManager.shared.reschedule(
                            name: profile.name, wakeTime: wakeTime, sleepTime: sleepTime)
                    }

                DatePicker("Bedtime", selection: $sleepTime, displayedComponents: .hourAndMinute)
                    .onChange(of: sleepTime) {
                        profile.sleepTime = sleepTime
                        NotificationManager.shared.reschedule(
                            name: profile.name, wakeTime: wakeTime, sleepTime: sleepTime)
                    }

                Toggle("Fixed work hours", isOn: $profile.hasWorkHours)
                    .onChange(of: profile.hasWorkHours) {
                        UserDefaults.standard.set(profile.hasWorkHours, forKey: "profile.hasWorkHours")
                    }

                if profile.hasWorkHours {
                    DatePicker("Work starts", selection: $workStart, displayedComponents: .hourAndMinute)
                        .onChange(of: workStart) {
                            profile.workStartTime = workStart
                            let h = Calendar.current.component(.hour, from: workStart)
                            UserDefaults.standard.set(h, forKey: "profile.workStartHour")
                        }
                    DatePicker("Work ends", selection: $workEnd, displayedComponents: .hourAndMinute)
                        .onChange(of: workEnd) {
                            profile.workEndTime = workEnd
                            let h = Calendar.current.component(.hour, from: workEnd)
                            UserDefaults.standard.set(h, forKey: "profile.workEndHour")
                        }
                }
            }

            Section("About you — AI uses this to plan smarter") {
                TextEditor(text: $profile.bio)
                    .font(.system(size: 13))
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .background(FlowLineTheme.tertiaryBg)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("One commitment per line. The AI will always include these — no need to mention them every time.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    ZStack(alignment: .topLeading) {
                        if profile.recurringCommitments.isEmpty {
                            Text("Standup 9:00–9:30 Mon–Fri\nGym 6pm Mon/Wed/Fri\nClass 8am–2pm Tue/Thu")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.top, 1)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $profile.recurringCommitments)
                            .font(.system(size: 13))
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .background(FlowLineTheme.tertiaryBg)
                    }
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
            } header: {
                Text("Recurring commitments — AI always includes these")
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

// MARK: - Notifications Tab

private struct NotificationSettingsTab: View {

    // ── Planning
    @AppStorage(NotificationManager.morningReminderEnabledKey) private var morningEnabled  = false
    @AppStorage(NotificationManager.eveningReminderEnabledKey) private var eveningEnabled  = false
    @AppStorage(NotificationManager.tomorrowNudgeEnabledKey)   private var tomorrowEnabled = true
    @AppStorage(NotificationManager.weeklyNudgeEnabledKey)     private var weeklyEnabled   = true
    @AppStorage(NotificationManager.streakAlertsEnabledKey)    private var streakEnabled   = true

    // ── Block reminders (0 = off, 5/10/15 min)
    @AppStorage(NotificationManager.blockReminderMinutesKey)   private var blockMinutes    = 10

    // ── Break reminders (existing)
    @AppStorage("breakRemindersEnabled")  private var breakRemindersEnabled = true
    @AppStorage("breakReminderInterval")  private var breakReminderIntervalHours = 1

    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined

    // Snapshot of user profile for re-scheduling
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Form {

            // ── Block reminders ───────────────────────────────────────────────
            Section {
                Picker("Remind me before block", selection: $blockMinutes) {
                    Text("Off").tag(0)
                    Text("5 min").tag(5)
                    Text("10 min").tag(10)
                    Text("15 min").tag(15)
                }
                .pickerStyle(.segmented)
            } header: {
                Label("Block Reminders", systemImage: "timer")
            } footer: {
                Text(blockMinutes == 0
                     ? "You won't be notified before blocks start."
                     : "You'll get a heads-up \(blockMinutes) minutes before each scheduled block.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // ── Planning nudges ───────────────────────────────────────────────
            Section {
                Toggle(isOn: $morningEnabled) {
                    Label("Morning reminder", systemImage: "sun.horizon.fill")
                }
                .onChange(of: morningEnabled) { rescheduleMorningEvening() }

                Toggle(isOn: $eveningEnabled) {
                    Label("Evening review", systemImage: "moon.stars.fill")
                }
                .onChange(of: eveningEnabled) { rescheduleMorningEvening() }

                Toggle(isOn: $tomorrowEnabled) {
                    Label("Plan tomorrow (9 pm)", systemImage: "moon.fill")
                }
                .onChange(of: tomorrowEnabled) {
                    if tomorrowEnabled { NotificationManager.shared.scheduleTomorrowNudge() }
                    else               { NotificationManager.shared.cancelTomorrowNudge() }
                }
            } header: {
                Label("Planning Nudges", systemImage: "calendar.badge.clock")
            } footer: {
                Text("Morning = 5 min after your wake time. Evening = 30 min before sleep.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // ── Streak & weekly ───────────────────────────────────────────────
            Section {
                Toggle(isOn: $streakEnabled) {
                    Label("Streak alerts (8 pm)", systemImage: "flame.fill")
                }
                .onChange(of: streakEnabled) { rescheduleStreak() }

                Toggle(isOn: $weeklyEnabled) {
                    Label("Weekly summary (Sunday 8 pm)", systemImage: "chart.bar.fill")
                }
                .onChange(of: weeklyEnabled) { rescheduleWeekly() }
            } header: {
                Label("Motivation", systemImage: "sparkles")
            } footer: {
                Text("Streak alert fires if you haven't planned today. Weekly summary shows your stats every Sunday.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // ── Break reminders ───────────────────────────────────────────────
            Section {
                Toggle("Break notifications", isOn: $breakRemindersEnabled)
                    .onChange(of: breakRemindersEnabled) { updateBreakNotifications() }

                if breakRemindersEnabled {
                    Picker("Interval", selection: $breakReminderIntervalHours) {
                        Text("1h").tag(1)
                        Text("2h").tag(2)
                        Text("3h").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: breakReminderIntervalHours) { updateBreakNotifications() }
                }
            } header: {
                Label("Focus Breaks", systemImage: "cup.and.saucer.fill")
            }

            // ── Permission status ─────────────────────────────────────────────
            Section {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    Spacer()
                    if permissionStatus == .denied {
                        Button("Open Settings") {
                            #if os(iOS)
                            openSystemURL(URL(string: UIApplication.openSettingsURLString)!)
                            #else
                            openSystemURL(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                            #endif
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else if permissionStatus == .notDetermined {
                        Button("Allow") {
                            Task {
                                let granted = await NotificationManager.shared.requestAuthorization()
                                await MainActor.run {
                                    permissionStatus = granted ? .authorized : .denied
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            } header: {
                Label("Permission", systemImage: "bell.badge")
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .onAppear { checkPermission() }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private var statusColor: Color {
        switch permissionStatus {
        case .authorized: return .green
        case .denied:     return .red
        default:          return .orange
        }
    }

    private var statusText: String {
        switch permissionStatus {
        case .authorized:    return "Notifications allowed ✓"
        case .denied:        return "Notifications blocked — tap Open Settings"
        case .notDetermined: return "Tap Allow to enable notifications"
        default:             return "Unknown status"
        }
    }

    private func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { permissionStatus = settings.authorizationStatus }
        }
    }

    private func rescheduleMorningEvening() {
        guard let p = profile else { return }
        NotificationManager.shared.scheduleMorning(name: p.name, wakeTime: p.wakeTime)
        NotificationManager.shared.scheduleEvening(sleepTime: p.sleepTime)
    }

    private func rescheduleStreak() {
        guard let p = profile else { return }
        let streak = StreakManager.shared.currentStreak
        NotificationManager.shared.scheduleStreakReminder(streakDays: streak, sleepTime: p.sleepTime)
    }

    private func rescheduleWeekly() {
        guard weeklyEnabled else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["flowline.weekly.summary"])
            return
        }
        let streak = StreakManager.shared.currentStreak
        NotificationManager.shared.scheduleWeeklySummary(completedDays: 0, streak: streak)
    }

    private func updateBreakNotifications() {
        guard breakRemindersEnabled else {
            NotificationCenter.default.post(name: .rescheduleBreaks, object: 0)
            return
        }
        NotificationCenter.default.post(name: .rescheduleBreaks, object: breakReminderIntervalHours)
    }
}

extension Notification.Name {
    static let rescheduleBreaks = Notification.Name("flowline.rescheduleBreaks")
}

// MARK: - Focus Tab

private struct FocusSettingsTab: View {
    @AppStorage("defaultBreakMinutes") private var defaultBreakMinutes = 5
    @AppStorage("autoStartBreak") private var autoStartBreak = false
    @AppStorage("showTimerInMenuBar") private var showTimerInMenuBar = true

    var body: some View {
        Form {
            Section("Break Timer") {
                Picker("Default break duration", selection: $defaultBreakMinutes) {
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                }
                .pickerStyle(.segmented)

                Toggle("Auto-start break when session ends", isOn: $autoStartBreak)
                    .help("Automatically begins a break timer when your focus block finishes")
            }

            #if os(macOS)
            Section("Menu Bar") {
                Toggle("Show countdown in menu bar", isOn: $showTimerInMenuBar)
                    .help("Displays live timer in the menu bar while a session is active")
            }
            #endif
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

// MARK: - Data Tab

private struct DataSettingsTab: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var authService: AuthService
    @Query private var messages: [ChatMessage]
    @Query private var dayPlans: [DayPlan]
    @Query private var capturedTasks: [CapturedTask]
    @Query private var profiles: [UserProfile]
    @AppStorage("hasSeenIntro")           private var hasSeenIntro = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("lastLoggedInUserId")     private var lastLoggedInUserId: String = ""

    @State private var confirmClearChats = false
    @State private var confirmClearCalendar = false
    @State private var confirmResetAll = false

    var body: some View {
        Form {
            Section("Storage") {
                infoRow("Chat messages", value: "\(messages.count)")
                infoRow("Calendar blocks", value: "\(dayPlans.flatMap(\.blocks).count)")
                infoRow("Captured tasks", value: "\(capturedTasks.count)")
            }

            Section("Clear Data") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear chat history")
                            .font(.system(size: 13))
                        Text("Removes all conversations. Plans stay on calendar.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Clear", role: .destructive) { confirmClearChats = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .confirmationDialog("Delete all chat history?",
                                            isPresented: $confirmClearChats,
                                            titleVisibility: .visible) {
                            Button("Delete All Chats", role: .destructive) { clearChats() }
                            Button("Cancel", role: .cancel) {}
                        }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear calendar")
                            .font(.system(size: 13))
                        Text("Removes all scheduled blocks from all weeks.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Clear", role: .destructive) { confirmClearCalendar = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .confirmationDialog("Delete all calendar data?",
                                            isPresented: $confirmClearCalendar,
                                            titleVisibility: .visible) {
                            Button("Delete Calendar", role: .destructive) { clearCalendar() }
                            Button("Cancel", role: .cancel) {}
                        }
                }
            }

            Section("Reset") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset everything")
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                        Text("Deletes all data and returns to onboarding.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Reset App", role: .destructive) { confirmResetAll = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .confirmationDialog("Reset everything? This cannot be undone.",
                                            isPresented: $confirmResetAll,
                                            titleVisibility: .visible) {
                            Button("Reset Everything", role: .destructive) { resetAll() }
                            Button("Cancel", role: .cancel) {}
                        }
                }
            }

            Section("About") {
                infoRow("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                infoRow("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.primary)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }

    private func clearChats() {
        messages.forEach { context.delete($0) }
        capturedTasks.forEach { context.delete($0) }
    }

    private func clearCalendar() {
        dayPlans.forEach { context.delete($0) }
    }

    private func resetAll() {
        messages.forEach { context.delete($0) }
        dayPlans.forEach { context.delete($0) }
        capturedTasks.forEach { context.delete($0) }
        profiles.forEach { context.delete($0) }
        hasSeenIntro = false
        hasCompletedOnboarding = false
        lastLoggedInUserId = ""
        authService.logout()
    }
}

// MARK: - Calendars Tab

private struct CalendarSettingsTab: View {
    @AppStorage("saveCalendarSourceTitle") private var saveSourceTitle: String = ""
    @ObservedObject private var calService = CalendarService.shared
    @State private var googleConnected  = false
    @State private var availableSources: [String] = []
    @State private var isLoading        = true
    @State private var appleAuthStatus: EKAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            // ── Access + connected accounts ───────────────────────────────────
            Section {
                // Apple Calendar
                HStack {
                    Image(systemName: "apple.logo")
                        .frame(width: 18)
                        .foregroundColor(.primary)
                    Text("Apple Calendar")
                        .font(.system(size: 13))
                    Spacer()
                    if calService.isAuthorized {
                        HStack(spacing: 8) {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                                .labelStyle(.titleAndIcon)
                            Button("Revoke") {
                                #if os(macOS)
                                openSystemURL(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                                #else
                                openSystemURL(URL(string: UIApplication.openSettingsURLString)!)
                                #endif
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red)
                        }
                    } else {
                        #if os(macOS)
                        Button("Allow Access") {
                            openSystemURL(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        #else
                        Button(appleAuthStatus == .notDetermined ? "Allow Access" : "Open Settings") {
                            if appleAuthStatus == .notDetermined {
                                Task {
                                    await calService.requestAccess()
                                    appleAuthStatus = EKEventStore.authorizationStatus(for: .event)
                                    refresh()
                                }
                            } else {
                                openSystemURL(URL(string: UIApplication.openSettingsURLString)!)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        #endif
                    }
                }

                // Google Calendar
                HStack {
                    Text("G")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .red],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                        .frame(width: 18)
                    Text("Google Calendar")
                        .font(.system(size: 13))
                    Spacer()
                    if googleConnected {
                        HStack(spacing: 8) {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                                .labelStyle(.titleAndIcon)
                            Button("Manage") {
                                #if os(macOS)
                                openSystemURL(URL(string: "x-apple.systempreferences:com.apple.preferences.internetaccounts")!)
                                #else
                                openSystemURL(URL(string: UIApplication.openSettingsURLString)!)
                                #endif
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    } else {
                        #if os(macOS)
                        Button("Connect") {
                            openSystemURL(URL(string: "x-apple.systempreferences:com.apple.preferences.internetaccounts")!)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        #else
                        Button("How to Connect") {
                            openSystemURL(URL(string: UIApplication.openSettingsURLString)!)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        #endif
                    }
                }
            } header: {
                Text("Accounts")
            } footer: {
                #if os(iOS)
                if !calService.isAuthorized {
                    if appleAuthStatus == .denied {
                        Text("Calendar access was denied. Tap \"Open Settings\" → enable **Calendars** for Flowline.")
                            .font(.system(size: 11))
                    } else {
                        Text("Tap **Allow Access** to let Flowline read your calendar and plan around your existing events.")
                            .font(.system(size: 11))
                    }
                }
                #endif
            }

            #if os(iOS)
            if !googleConnected {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("How to add Google Calendar", systemImage: "info.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Go to **Calendar → Accounts → Add Account → Google** and sign in.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Button {
                            // Deep-link directly to Calendar settings (Settings → Calendar)
                            let calendarPrefs = URL(string: "App-prefs:root=CALENDAR")
                            let fallback = URL(string: UIApplication.openSettingsURLString)!
                            openSystemURL(calendarPrefs ?? fallback)
                        } label: {
                            Label("Open Calendar Settings", systemImage: "arrow.up.right.square")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }
            }
            #endif

            // ── Default save destination ──────────────────────────────────────
            if calService.isAuthorized {
                Section("Default Save Account") {
                    if isLoading {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading accounts…")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    } else if availableSources.isEmpty {
                        Text("No calendar accounts found.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Account", selection: $saveSourceTitle) {
                            Text("System default").tag("")
                            ForEach(availableSources, id: \.self) { src in
                                Text(src).tag(src)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .onAppear {
            appleAuthStatus = EKEventStore.authorizationStatus(for: .event)
            // Small delay so EKEventStore finishes loading sources
            // before we read them (avoids the "nothing connected" flash)
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                await MainActor.run { refresh() }
            }
        }
        .onChange(of: calService.isAuthorized) { _, authorized in
            appleAuthStatus = EKEventStore.authorizationStatus(for: .event)
            if authorized { refresh() }
        }
    }

    private func refresh() {
        guard calService.isAuthorized else {
            googleConnected  = false
            availableSources = []
            isLoading        = false
            return
        }
        let sources = calService.availableSourceTitles()
        googleConnected  = calService.isGoogleCalendarConnected()
        availableSources = sources
        isLoading        = false
    }
}

// MARK: - Appearance Tab

private struct AppearanceSettingsTab: View {
    @EnvironmentObject private var colorManager: CategoryColorManager

    var body: some View {
        Form {
            Section("Calendar Block Colors") {
                colorRow(label: "Work", description: "Coding, projects, professional tasks",
                         color: $colorManager.workColor)
                colorRow(label: "Study", description: "Learning, courses, research",
                         color: $colorManager.studyColor)
                colorRow(label: "Health", description: "Gym, meals, breaks, walks",
                         color: $colorManager.healthColor)
                colorRow(label: "Personal", description: "Social, hobbies, free time",
                         color: $colorManager.personalColor)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        colorManager.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }

    private func colorRow(label: String, description: String, color: Binding<Color>) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.wrappedValue)
                .frame(width: 22, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 28, height: 28)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SettingsView()
}
