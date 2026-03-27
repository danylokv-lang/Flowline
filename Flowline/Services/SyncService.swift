import Foundation
import SwiftData

/// Syncs profile and calendar plans between SwiftData (local) and the Cloudflare Worker (remote).
///
/// Call `pullAll` after login or app launch.
/// Call `pushDay` after a DayPlan is created or modified.
/// Call `pushProfile` after the user updates their profile or name.
@MainActor
final class SyncService {

    static let shared = SyncService()
    private init() {}

    private let base      = Config.proxyURL
    private let hhmmFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()
    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Public API

    /// Pull profile + last 30 days + next 30 days + chats + inbox from the server.
    func pullAll(token: String, context: ModelContext, subscriptionManager: SubscriptionManager? = nil) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.pullProfile(token: token, context: context, subscriptionManager: subscriptionManager) }
            group.addTask { await self.pullCalendar(token: token, context: context) }
            group.addTask { await self.pullChats(token: token, context: context) }
            group.addTask { await self.pullInbox(token: token, context: context) }
        }
    }

    /// Push new chat messages to the server (call after every AI response).
    func pushMessages(_ messages: [ChatMessage], token: String) async {
        guard !token.isEmpty, !messages.isEmpty else { return }
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        dateFmt.locale = Locale(identifier: "en_US_POSIX")

        let payload: [[String: Any]] = messages.map { m in [
            "id":          m.messageID,
            "sessionId":   m.sessionID,
            "sessionDate": dateFmt.string(from: m.sessionDate),
            "role":        m.role,
            "content":     m.content,
            "timestamp":   Int(m.timestamp.timeIntervalSince1970),
        ]}
        _ = try? await request("POST", "/chats/sync", body: ["messages": payload], token: token)

        // Remember the most recent timestamp so we only pull new messages next time
        if let maxTs = messages.map({ $0.timestamp.timeIntervalSince1970 }).max() {
            UserDefaults.standard.set(Int(maxTs), forKey: "chats.lastSyncTimestamp")
        }
    }

    /// Push all plans for the week containing `date` (use after AI generates a plan).
    func pushWeek(for date: Date, token: String, context: ModelContext) async {
        guard !token.isEmpty else { return }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let daysToMonday = (weekday == 1) ? -6 : -(weekday - 2)
        let monday    = cal.startOfDay(for: cal.date(byAdding: .day, value: daysToMonday, to: date)!)
        let nextWeek  = cal.date(byAdding: .day, value: 7, to: monday)!
        guard let plans = try? context.fetch(FetchDescriptor<DayPlan>()) else { return }
        let weekPlans = plans.filter { $0.date >= monday && $0.date < nextWeek }
        guard !weekPlans.isEmpty else { return }
        let body: [String: Any] = ["days": weekPlans.map { planToJSON($0) }]
        _ = try? await request("POST", "/calendar/sync", body: body, token: token)
    }

    /// Push a single DayPlan (and its blocks) to the server after it changes.
    func pushDay(_ plan: DayPlan, token: String) async {
        guard !token.isEmpty else { return }
        let body: [String: Any] = ["days": [planToJSON(plan)]]
        _ = try? await request("POST", "/calendar/sync", body: body, token: token)
    }

    /// Mark onboarding as completed on the server so other devices can skip it.
    /// Send an end-of-day plan review rating to the server.
    func pushReview(rating: Int, planDate: Date, token: String) async {
        guard !token.isEmpty else { return }
        let body: [String: Any] = [
            "rating": rating,
            "planDate": dateFmt.string(from: planDate)
        ]
        _ = try? await request("POST", "/reviews", body: body, token: token)
    }

    func markOnboardingDone(token: String) async {
        guard !token.isEmpty else { return }
        let body: [String: Any] = ["profile": ["onboardingDone": 1]]
        _ = try? await request("PUT", "/user/profile", body: body, token: token)
    }

    /// Push profile changes (call after the user saves profile edits).
    func pushProfile(_ profile: UserProfile, name: String, token: String) async {
        guard !token.isEmpty else { return }
        var profileDict: [String: Any] = [
            "wakeTime":              hhmmFmt.string(from: profile.wakeTime),
            "sleepTime":             hhmmFmt.string(from: profile.sleepTime),
            "hasWorkHours":          profile.hasWorkHours ? 1 : 0,
            "bio":                   profile.bio,
            "recurringCommitments":  profile.recurringCommitments,
            "weeklySchedule":        profile.weeklySchedule,
        ]
        if profile.hasWorkHours {
            if let ws = profile.workStartTime { profileDict["workStart"] = hhmmFmt.string(from: ws) }
            if let we = profile.workEndTime   { profileDict["workEnd"]   = hhmmFmt.string(from: we) }
        }
        let body: [String: Any] = ["name": name, "profile": profileDict]
        _ = try? await request("PUT", "/user/profile", body: body, token: token)
    }

    /// Increment the server-side weekly save counter (server-enforced limit).
    /// Returns (count, monday) from the server, or nil on error.
    /// The server resets the count automatically when the ISO week changes.
    func incrementPlanSave(token: String) async -> (count: Int, monday: String)? {
        guard !token.isEmpty else { return nil }
        guard let data  = try? await request("POST", "/plan-saves/increment", body: [:], token: token),
              let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let count = json["weeklySaves"]      as? Int,
              let monday = json["weeklySavesMonday"] as? String else { return nil }
        return (count, monday)
    }

    /// Push captured inbox tasks to the server.
    func pushInbox(_ tasks: [CapturedTask], token: String) async {
        guard !token.isEmpty, !tasks.isEmpty else { return }
        let payload: [[String: Any]] = tasks.map { t in [
            "id":          t.taskID,
            "text":        t.text,
            "category":    t.category,
            "isScheduled": t.isScheduled,
            "createdAt":   Int(t.createdAt.timeIntervalSince1970),
        ]}
        _ = try? await request("POST", "/inbox/sync", body: ["tasks": payload], token: token)
    }

    // MARK: - Pull profile

    private func pullProfile(token: String, context: ModelContext, subscriptionManager: SubscriptionManager? = nil) async {
        guard let data = try? await request("GET", "/user/profile", body: nil, token: token),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let p    = json["profile"] as? [String: Any] else { return }

        let cal     = Calendar.current
        let refDate = cal.startOfDay(for: Date())

        func toDate(_ val: Any?) -> Date? {
            guard let s = val as? String,
                  let t = hhmmFmt.date(from: s) else { return nil }
            return cal.date(bySettingHour:   cal.component(.hour,   from: t),
                            minute: cal.component(.minute, from: t),
                            second: 0, of: refDate)
        }

        let name                  = json["name"]                      as? String ?? ""
        let wakeTime              = toDate(p["wake_time"])             ?? refDate
        let sleepTime             = toDate(p["sleep_time"])            ?? refDate
        let workStart             = toDate(p["work_start"])
        let workEnd               = toDate(p["work_end"])
        let hasWork               = (p["has_work_hours"]               as? Int ?? 0) == 1
        let bio                   = p["bio"]                           as? String ?? ""
        let recurringCommitments  = p["recurring_commitments"]         as? String ?? ""
        let weeklySchedule        = p["weekly_schedule"]               as? String ?? ""
        let onboardingDone        = (p["onboarding_done"]              as? Int ?? 0) == 1
        let weeklySaves           = p["weekly_saves"]                  as? Int    ?? 0
        let weeklySavesMonday     = p["weekly_saves_monday"]           as? String ?? ""

        if let existing = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first {
            existing.name                 = name
            existing.wakeTime             = wakeTime
            existing.sleepTime            = sleepTime
            existing.hasWorkHours         = hasWork
            existing.workStartTime        = workStart
            existing.workEndTime          = workEnd
            existing.bio                  = bio
            existing.recurringCommitments = recurringCommitments
            existing.weeklySchedule       = weeklySchedule
        } else {
            context.insert(UserProfile(name: name, wakeTime: wakeTime, sleepTime: sleepTime,
                                       hasWorkHours: hasWork, workStartTime: workStart,
                                       workEndTime: workEnd, bio: bio,
                                       recurringCommitments: recurringCommitments,
                                       weeklySchedule: weeklySchedule))
        }
        try? context.save()

        // Only skip onboarding if the user has explicitly completed it on another device
        if onboardingDone {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        } else {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }

        // Restore server-authoritative weekly save count (survives reinstalls + device switches)
        subscriptionManager?.refreshFromServer(count: weeklySaves, monday: weeklySavesMonday)

        // Cache work hours for break notification scheduling
        let ud = UserDefaults.standard
        ud.set(hasWork, forKey: "profile.hasWorkHours")
        if hasWork {
            let cal = Calendar.current
            if let ws = workStart { ud.set(cal.component(.hour, from: ws), forKey: "profile.workStartHour") }
            if let we = workEnd   { ud.set(cal.component(.hour, from: we), forKey: "profile.workEndHour") }
        }
    }

    // MARK: - Pull chats

    private func pullChats(token: String, context: ModelContext) async {
        let since = UserDefaults.standard.integer(forKey: "chats.lastSyncTimestamp")
        guard let data = try? await request("GET", "/chats?since=\(since)", body: nil, token: token),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let msgs = json["messages"] as? [[String: Any]],
              !msgs.isEmpty else { return }

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        dateFmt.locale = Locale(identifier: "en_US_POSIX")

        // Fetch existing messageIDs to avoid duplicates
        let existing = (try? context.fetch(FetchDescriptor<ChatMessage>()))?.map { $0.messageID } ?? []
        let existingSet = Set(existing)

        var maxTs = since
        for m in msgs {
            guard let id      = m["id"]          as? String,
                  let sid     = m["session_id"]  as? String,
                  let role    = m["role"]        as? String,
                  let content = m["content"]     as? String,
                  let ts      = m["timestamp"]   as? Int,
                  !existingSet.contains(id) else { continue }

            let sDateStr = m["session_date"] as? String ?? ""
            let sDate    = dateFmt.date(from: sDateStr) ?? Date()
            let tsDate   = Date(timeIntervalSince1970: TimeInterval(ts))

            let msg = ChatMessage(role: role, content: content,
                                  sessionDate: sDate, sessionID: sid)
            msg.messageID = id
            msg.timestamp = tsDate
            context.insert(msg)
            if ts > maxTs { maxTs = ts }
        }
        try? context.save()

        if maxTs > since {
            UserDefaults.standard.set(maxTs, forKey: "chats.lastSyncTimestamp")
        }
    }

    // MARK: - Pull calendar

    private func pullCalendar(token: String, context: ModelContext) async {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let from = cal.date(byAdding: .day, value: -30, to: today),
              let to   = cal.date(byAdding: .day, value:  30, to: today) else { return }

        let path = "/calendar?weekStart=\(dateFmt.string(from: from))&weekEnd=\(dateFmt.string(from: to))"
        guard let data = try? await request("GET", path, body: nil, token: token),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let days = json["days"] as? [[String: Any]] else { return }

        for dayJSON in days {
            guard let dateStr = dayJSON["date"] as? String,
                  let dayDate = dateFmt.date(from: dateStr) else { continue }

            let dayStart   = cal.startOfDay(for: dayDate)
            let nextDay    = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let aiNotes    = dayJSON["ai_notes"]               as? String
            let blocksJSON = dayJSON["blocks"] as? [[String: Any]] ?? []

            // Find or create DayPlan
            let descriptor = FetchDescriptor<DayPlan>(
                predicate: #Predicate<DayPlan> { $0.date >= dayStart && $0.date < nextDay }
            )
            let plan: DayPlan

            // Snapshot check-in results keyed by "HH:mm|title" before wiping blocks.
            // The server never stores check-in state, so we preserve it locally.
            var checkInCache: [String: (CheckInResult?, Bool)] = [:]

            if let existing = (try? context.fetch(descriptor))?.first {
                plan = existing
                plan.aiNotes = aiNotes
                for block in plan.blocks {
                    let key = "\(hhmmFmt.string(from: block.startTime))|\(block.title)"
                    checkInCache[key] = (block.checkInResult, block.isCompleted)
                }
                plan.blocks.forEach { context.delete($0) }
                plan.blocks = []
            } else {
                plan = DayPlan(date: dayStart)
                plan.aiNotes = aiNotes
                context.insert(plan)
            }

            for b in blocksJSON {
                guard let title    = b["title"]     as? String,
                      let startStr = b["startTime"] as? String,
                      let endStr   = b["endTime"]   as? String else { continue }

                let category = Category(rawValue: b["category"] as? String ?? "")

                func timeDate(_ s: String) -> Date {
                    guard let t = hhmmFmt.date(from: s) else { return dayStart }
                    return cal.date(bySettingHour:   cal.component(.hour,   from: t),
                                    minute: cal.component(.minute, from: t),
                                    second: 0, of: dayStart) ?? dayStart
                }

                let block = ScheduleBlock(title: title, category: category,
                                          startTime: timeDate(startStr),
                                          endTime:   timeDate(endStr))

                // Restore check-in result from local cache.
                // If the server ever starts returning checkInResult, it takes precedence.
                let serverResult = (b["checkInResult"] as? String).flatMap { CheckInResult(rawValue: $0) }
                let cacheKey = "\(startStr)|\(title)"
                if let sr = serverResult {
                    block.checkInResult = sr
                    block.isCompleted   = (sr == .done)
                } else if let cached = checkInCache[cacheKey] {
                    block.checkInResult = cached.0
                    block.isCompleted   = cached.1
                }

                context.insert(block)
                plan.blocks.append(block)
            }
        }
        try? context.save()
    }

    // MARK: - Pull inbox

    private func pullInbox(token: String, context: ModelContext) async {
        guard let data = try? await request("GET", "/inbox", body: nil, token: token),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tasks = json["tasks"] as? [[String: Any]],
              !tasks.isEmpty else { return }

        let existing = Set((try? context.fetch(FetchDescriptor<CapturedTask>()))?.map { $0.taskID } ?? [])

        for t in tasks {
            guard let id       = t["id"]          as? String,
                  let text     = t["text"]        as? String,
                  !existing.contains(id) else { continue }

            let category    = t["category"]     as? String ?? "work"
            let isScheduled = (t["is_scheduled"] as? Int ?? 0) == 1
            let createdAt   = Date(timeIntervalSince1970: TimeInterval(t["created_at"] as? Int ?? 0))

            let task = CapturedTask(text: text, category: category)
            task.taskID      = id
            task.isScheduled = isScheduled
            task.createdAt   = createdAt
            context.insert(task)
        }
        try? context.save()
    }

    // MARK: - Helpers

    private func planToJSON(_ plan: DayPlan) -> [String: Any] {
        let blocks: [[String: Any]] = plan.blocks.map { b in
            var dict: [String: Any] = [
                "title":       b.title,
                "category":    b.category?.rawValue ?? "personal",
                "startTime":   hhmmFmt.string(from: b.startTime),
                "endTime":     hhmmFmt.string(from: b.endTime),
                "isCompleted": b.isCompleted,
            ]
            if let r = b.checkInResult { dict["checkInResult"] = r.rawValue }
            return dict
        }
        var day: [String: Any] = ["date": dateFmt.string(from: plan.date), "blocks": blocks]
        if let notes = plan.aiNotes { day["aiNotes"] = notes }
        return day
    }

    private func request(_ method: String, _ path: String,
                         body: [String: Any]?, token: String) async throws -> Data {
        guard let url = URL(string: base + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(Config.appSecret, forHTTPHeaderField: "x-app-secret")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
}
