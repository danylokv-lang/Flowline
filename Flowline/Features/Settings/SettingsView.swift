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
                    .onChange(of: wakeTime) { profile.wakeTime = wakeTime }

                DatePicker("Bedtime", selection: $sleepTime, displayedComponents: .hourAndMinute)
                    .onChange(of: sleepTime) { profile.sleepTime = sleepTime }

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
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

// MARK: - Notifications Tab

private struct NotificationSettingsTab: View {
    @AppStorage("breakRemindersEnabled")  private var breakRemindersEnabled = true
    @AppStorage("breakReminderInterval")  private var breakReminderIntervalHours = 1
    @AppStorage("notificationSound")      private var notificationSound = true
    @AppStorage("dailyReminderEnabled")   private var dailyReminderEnabled = false
    @AppStorage("dailyReminderHour")      private var dailyReminderHour = 8
    @AppStorage("dailyReminderMinute")    private var dailyReminderMinute = 0
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var reminderTime = Date()

    private let intervalOptions = [1: "Every hour", 2: "Every 2 hours", 3: "Every 3 hours"]

    var body: some View {
        Form {
            // ── Daily planning reminder ───────────────────────────────────────
            Section {
                Toggle("Daily planning reminder", isOn: $dailyReminderEnabled)
                    .onChange(of: dailyReminderEnabled) { _, enabled in
                        if enabled {
                            requestPermissionThenSchedule()
                        } else {
                            cancelDailyReminder()
                        }
                    }

                if dailyReminderEnabled {
                    DatePicker(
                        "Remind me at",
                        selection: $reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: reminderTime) { _, t in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: t)
                        dailyReminderHour   = comps.hour   ?? 8
                        dailyReminderMinute = comps.minute ?? 0
                        scheduleDailyReminder()
                    }
                }
            } header: {
                Label("Morning Reminder", systemImage: "sun.horizon")
            } footer: {
                Text("A daily nudge to plan your day with Flowline. Sent once at your chosen time.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // ── Break reminders ───────────────────────────────────────────────
            Section("Break Reminders") {
                Toggle("Hourly break notifications", isOn: $breakRemindersEnabled)
                    .onChange(of: breakRemindersEnabled) { updateBreakNotifications() }

                if breakRemindersEnabled {
                    Picker("Remind me", selection: $breakReminderIntervalHours) {
                        ForEach([1, 2, 3], id: \.self) { h in
                            Text(intervalOptions[h] ?? "").tag(h)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: breakReminderIntervalHours) { updateBreakNotifications() }

                    Toggle("Sound", isOn: $notificationSound)
                }
            }

            // ── Permission status ─────────────────────────────────────────────
            Section("Permission") {
                HStack {
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
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .onAppear {
            checkPermission()
            var comps        = DateComponents()
            comps.hour       = dailyReminderHour
            comps.minute     = dailyReminderMinute
            reminderTime     = Calendar.current.date(from: comps) ?? Date()
        }
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
        case .authorized:    return "Notifications allowed"
        case .denied:        return "Notifications blocked — enable in Settings"
        case .notDetermined: return "Permission not requested yet"
        default:             return "Unknown status"
        }
    }

    private func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { permissionStatus = settings.authorizationStatus }
        }
    }

    private func requestPermissionThenSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                permissionStatus = granted ? .authorized : .denied
                if granted { scheduleDailyReminder() }
                else { dailyReminderEnabled = false }
            }
        }
    }

    private func scheduleDailyReminder() {
        cancelDailyReminder()
        var comps    = DateComponents()
        comps.hour   = dailyReminderHour
        comps.minute = dailyReminderMinute

        let content       = UNMutableNotificationContent()
        content.title     = "Time to plan your day ✦"
        content.body      = "Open Flowline and tell AI what's on your plate — takes 60 seconds."
        content.sound     = .default
        content.categoryIdentifier = "DAILY_PLAN"

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: "flowline.dailyReminder",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelDailyReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["flowline.dailyReminder"])
    }

    private func updateBreakNotifications() {
        guard breakRemindersEnabled else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            if dailyReminderEnabled { scheduleDailyReminder() }
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

    var body: some View {
        Form {
            // ── Access + connected accounts ───────────────────────────────────
            Section("Accounts") {
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
                        Button("Allow Access") {
                            #if os(macOS)
                            // macOS: always go to System Settings
                            openSystemURL(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                            #else
                            // iOS: show system dialog if not determined yet, else open Settings
                            let status = EKEventStore.authorizationStatus(for: .event)
                            if status == .notDetermined {
                                Task {
                                    await calService.requestAccess()
                                    await MainActor.run { refresh() }
                                }
                            } else {
                                openSystemURL(URL(string: UIApplication.openSettingsURLString)!)
                            }
                            #endif
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
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
                        Button("Connect") {
                            #if os(macOS)
                            openSystemURL(URL(string: "x-apple.systempreferences:com.apple.preferences.internetaccounts")!)
                            #else
                            openSystemURL(URL(string: UIApplication.openSettingsURLString)!)
                            #endif
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            #if os(iOS)
            Section {
                Text("To add Google Calendar on iPhone, go to **Settings → Calendar → Accounts → Add Account → Google**.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
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
            // Small delay so EKEventStore finishes loading sources
            // before we read them (avoids the "nothing connected" flash)
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                await MainActor.run { refresh() }
            }
        }
        .onChange(of: calService.isAuthorized) { _, authorized in
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
