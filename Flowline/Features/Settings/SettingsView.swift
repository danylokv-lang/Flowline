import SwiftUI
import SwiftData
import UserNotifications
import EventKit

struct SettingsView: View {
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
        }
        .frame(width: 480, height: 500)
    }
}

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

                if profile.hasWorkHours {
                    DatePicker("Work starts", selection: $workStart, displayedComponents: .hourAndMinute)
                        .onChange(of: workStart) { profile.workStartTime = workStart }
                    DatePicker("Work ends", selection: $workEnd, displayedComponents: .hourAndMinute)
                        .onChange(of: workEnd) { profile.workEndTime = workEnd }
                }
            }

            Section("About you — AI uses this to plan smarter") {
                TextEditor(text: $profile.bio)
                    .font(.system(size: 13))
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
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
    @AppStorage("breakRemindersEnabled") private var breakRemindersEnabled = true
    @AppStorage("breakReminderInterval") private var breakReminderIntervalHours = 1
    @AppStorage("notificationSound") private var notificationSound = true
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined

    private let intervalOptions = [1: "Every hour", 2: "Every 2 hours", 3: "Every 3 hours"]

    var body: some View {
        Form {
            Section("Break Reminders") {
                Toggle("Hourly break notifications", isOn: $breakRemindersEnabled)
                    .onChange(of: breakRemindersEnabled) { updateNotifications() }

                if breakRemindersEnabled {
                    Picker("Remind me", selection: $breakReminderIntervalHours) {
                        ForEach([1, 2, 3], id: \.self) { h in
                            Text(intervalOptions[h] ?? "").tag(h)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: breakReminderIntervalHours) { updateNotifications() }

                    Toggle("Sound", isOn: $notificationSound)
                }
            }

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
                        Button("Open System Settings") {
                            NSWorkspace.shared.open(
                                URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .onAppear { checkPermission() }
    }

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
        case .denied:        return "Notifications blocked — enable in System Settings"
        case .notDetermined: return "Permission not requested yet"
        default:             return "Unknown status"
        }
    }

    private func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { permissionStatus = settings.authorizationStatus }
        }
    }

    private func updateNotifications() {
        guard breakRemindersEnabled else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }
        // Reschedule with new interval — FocusTimerManager handles the actual scheduling
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

            Section("Menu Bar") {
                Toggle("Show countdown in menu bar", isOn: $showTimerInMenuBar)
                    .help("Displays live timer in the menu bar while a session is active")
            }
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

private struct CalendarGroup: Identifiable {
    let id = UUID()
    let sourceName: String
    let isGoogle: Bool
    let isApple: Bool
    let calendars: [(name: String, color: Color)]
}

private struct CalendarSettingsTab: View {
    @AppStorage("saveCalendarSourceTitle") private var saveSourceTitle: String = ""
    @State private var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var calendarGroups: [CalendarGroup] = []
    @State private var availableSources: [String] = []

    private var isAuthorized: Bool {
        authStatus == .fullAccess || authStatus == .authorized
    }

    var body: some View {
        Form {
            // ── Access status ─────────────────────────────────────────────
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calendar Access")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Flowline reads your events so the AI can plan around them.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    accessBadge
                }
                .padding(.vertical, 2)

                if authStatus == .denied || authStatus == .restricted {
                    Button("Open Privacy Settings") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } header: {
                Text("Permissions")
            }

            // ── Live calendar list ────────────────────────────────────────
            if isAuthorized {
                if calendarGroups.isEmpty {
                    Section("Calendars Being Read") {
                        Text("No calendars found on this device.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(calendarGroups) { group in
                        Section {
                            ForEach(group.calendars, id: \.name) { cal in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(cal.color)
                                        .frame(width: 10, height: 10)
                                    Text(cal.name)
                                        .font(.system(size: 13))
                                    Spacer()
                                }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                if group.isGoogle {
                                    Text("G")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundStyle(
                                            LinearGradient(colors: [.blue, .red],
                                                           startPoint: .topLeading,
                                                           endPoint: .bottomTrailing)
                                        )
                                        .frame(width: 14, height: 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color(nsColor: .windowBackgroundColor))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
                                                )
                                        )
                                } else if group.isApple {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Text(group.sourceName)
                            }
                        }
                    }
                }
            }

            // ── Save destination ──────────────────────────────────────────
            if isAuthorized && !availableSources.isEmpty {
                Section {
                    Picker("Account", selection: $saveSourceTitle) {
                        Text("System default").tag("")
                        ForEach(availableSources, id: \.self) { src in
                            Text(src).tag(src)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Flowline creates a \"Flowline\" calendar inside the chosen account and saves all planned blocks there.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } header: {
                    Text("Save Plans To")
                }
            }

            // ── Add Google Calendar ───────────────────────────────────────
            Section {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .frame(width: 30, height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                        Text("G")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .red],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing)
                            )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google Calendar")
                            .font(.system(size: 13, weight: .semibold))
                        Text(googleConnected
                             ? "Connected — events are being read by AI."
                             : "Connect via macOS Internet Accounts.")
                            .font(.system(size: 11))
                            .foregroundColor(googleConnected ? .green : .secondary)
                    }

                    Spacer()

                    if googleConnected {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                            .labelStyle(.titleAndIcon)
                    } else {
                        Button("Connect") {
                            NSWorkspace.shared.open(
                                URL(string: "x-apple.systempreferences:com.apple.preferences.internetaccounts")!
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 2)

                if !googleConnected {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.top, 1)
                        Text("Tap **Connect** → add your Google account → enable Calendars. Flowline reads it the same way as Apple Calendar — no extra setup.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }
            } header: {
                Text("Add More Calendars")
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .onAppear { refresh() }
    }

    // MARK: - Helpers

    private var googleConnected: Bool {
        calendarGroups.contains(where: \.isGoogle)
    }

    @ViewBuilder
    private var accessBadge: some View {
        switch authStatus {
        case .fullAccess, .authorized:
            Label("Allowed", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.green)
                .labelStyle(.titleAndIcon)
        case .denied, .restricted:
            Label("Blocked", systemImage: "xmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.red)
                .labelStyle(.titleAndIcon)
        default:
            Label("Not set up", systemImage: "circle.dashed")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .labelStyle(.titleAndIcon)
        }
    }

    private func refresh() {
        authStatus = EKEventStore.authorizationStatus(for: .event)
        guard isAuthorized else { calendarGroups = []; availableSources = []; return }

        let store = EKEventStore()
        let all = store.calendars(for: .event)

        // Group by source
        var sourceMap: [String: (isGoogle: Bool, isApple: Bool, cals: [(name: String, color: Color)])] = [:]

        for cal in all.sorted(by: { $0.title < $1.title }) {
            let src = cal.source
            let srcTitle = src?.title ?? "On My Mac"
            let srcType  = src?.sourceType ?? .local

            let isGoogle = srcType == .calDAV &&
                (srcTitle.lowercased().contains("google") ||
                 srcTitle.lowercased().contains("gmail") ||
                 srcTitle.contains("@gmail") ||
                 srcTitle.contains("@googlemail"))
            let isApple  = srcType == .local || srcType == .calDAV && !isGoogle
                          || srcType == .mobileMe

            let cgColor = cal.cgColor.map { Color(cgColor: $0) } ?? Color.accentColor

            if sourceMap[srcTitle] == nil {
                sourceMap[srcTitle] = (isGoogle: isGoogle, isApple: !isGoogle, cals: [])
            }
            sourceMap[srcTitle]?.cals.append((name: cal.title, color: cgColor))
        }

        // Sort: Apple first, then Google, then others
        calendarGroups = sourceMap.map { key, val in
            CalendarGroup(sourceName: key,
                          isGoogle: val.isGoogle,
                          isApple: val.isApple,
                          calendars: val.cals)
        }
        .sorted {
            if $0.isApple != $1.isApple { return $0.isApple }
            if $0.isGoogle != $1.isGoogle { return $0.isGoogle }
            return $0.sourceName < $1.sourceName
        }

        // Sources available for saving — only writable ones (local, calDAV, exchange, mobileMe)
        availableSources = store.sources
            .filter { [.local, .calDAV, .exchange, .mobileMe].contains($0.sourceType) }
            .map(\.title)
            .sorted()
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
            // Preview swatch
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
