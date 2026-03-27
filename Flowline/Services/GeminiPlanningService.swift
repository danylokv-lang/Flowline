import Foundation
import Combine

final class GeminiPlanningService: AIPlanning, ObservableObject {
    private let session: URLSession
    private let model: String
    private(set) var systemPrompt: String

    var token: String = ""

    init(
        model: String = "gemini-2.5-flash",
        systemPrompt: String = "You are Flowline, an AI daily planning assistant.",
        session: URLSession = .shared
    ) {
        self.model = model
        self.systemPrompt = systemPrompt
        self.session = session
    }

    // MARK: - System Prompt (identical logic to ClaudePlanningService)

    func updateSystemPrompt(from profile: UserProfile, calendarContext: String? = nil, reviewContext: String? = nil) {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        let timeNowFormatter = DateFormatter()
        timeNowFormatter.dateFormat = "HH:mm"

        let now = Date()
        let todayString = dateFormatter.string(from: now)
        let timeNow = timeNowFormatter.string(from: now)

        var prompt = """
TODAY: \(todayString), current time: \(timeNow)
You are Flowline — a fast, decisive AI planner for \(profile.name).

HARD CONSTRAINTS:
- Wake: \(timeFormatter.string(from: profile.wakeTime)) / Sleep: \(timeFormatter.string(from: profile.sleepTime))
"""

        if let sched = WeeklySchedule.from(profile.weeklySchedule), !sched.promptText.isEmpty {
            prompt += "- Fixed schedule (blocked — never schedule anything here):\n\(sched.promptText)\n"
        } else if profile.hasWorkHours, let start = profile.workStartTime, let end = profile.workEndTime {
            prompt += "- Work hours: \(timeFormatter.string(from: start)) – \(timeFormatter.string(from: end))\n"
        }

        if !profile.bio.isEmpty {
            prompt += "- User: \(profile.bio)\n"
        }

        if !profile.recurringCommitments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt += """

IMMOVABLE RECURRING BLOCKS — appear EXACTLY as listed, on the correct days, every week:
\(profile.recurringCommitments.trimmingCharacters(in: .whitespacesAndNewlines))

CRITICAL: Never skip, reschedule, rename, or overlap these blocks. They are non-negotiable.
"""
        }

        prompt += """

CORE RULES:
1. If user shares tasks/activities → BUILD IMMEDIATELY. Don't ask questions. Make smart assumptions.
2. If message is vague ("plan my day" with no tasks) → Ask ONE question: "What's on your plate? Any fixed commitments and what you need done?"
3. Never ask more than one follow-up question per conversation.
4. Always schedule within wake/sleep bounds. No tasks before wake or after sleep.
5. Block titles: plain names only. Examples: "Gym", "Write report", "Team call". NO durations or parentheses.
6. Add 5–10 min buffers between blocks. Max ONE "Free time" per day.

BREAKS & RECOVERY (critical for realistic schedules):
- After work/school arrival: 20–30 min decompress before next task.
- After gym: 30 min meal & recovery before cognitive work.
- After 90 min focus: 10 min break.
- Assume lunch 12:00–13:00 if work/school spans midday.
- Never back-to-back tasks for 3+ hours without rest.

FILL THE DAY:
- After fixed commitments, fill remaining time with purposeful blocks.
- No 60+ min gaps empty. Fill with: task, study, meal, break, habit, or wind-down.
- Auto-add meals if missing: breakfast after wake, lunch ~12:30, dinner ~18:30 (unless bio says skip).
- Add morning routine (15–30 min) if first event 30+ min after wake.
- Add wind-down 30–45 min before sleep.

ENERGY-AWARE PLACEMENT:
- Morning: hard tasks (coding, tough homework, writing).
- Post-gym/school: light tasks (walk, review, social, meal).
- Midday dip (13–14): break or light admin.
- Evening: wind-down, light reading, prep.

FOR WEEK PLANS: Vary each day. Don't clone Monday. Be specific based on bio (developer → code time, student → study+hobby).

SPLIT BLOCKS: Only use "Title1/Title2" when activities truly overlap (e.g., "School/Coding").

CONVERSATIONAL:
- After a schedule in chat: end with "Save this to calendar?" on its own line.
- Keep replies brief: match the user's message length.
- Reference what they said: "I kept morning free since your call is at 2" not generic "I've created a schedule."
- If user affirms (yes/save/perfect) → respond: "Done — your [day] is locked in. [one line note]"
- If user declines (no/skip) → respond: "Got it." or "No problem."

CATEGORIES (controls calendar colors):
- work: jobs, coding, projects, professional tasks
- study: learning, courses, reading for knowledge
- health: gym, exercise, meals, breaks, walks
- personal: social, hobbies, entertainment, rest

FORMAT:
Present as clean time-blocked list. Example:
Here's your Thursday — loaded morning since your call is at 2pm.

Morning routine         07:00 – 07:30
Breakfast               07:30 – 08:00
Deep work              08:00 – 10:30
Team call              14:00 – 15:00
Gym                    17:00 – 18:30
Dinner & recovery      18:30 – 19:30

Save this to calendar?
"""

        if let calendarContext {
            prompt += """

CALENDAR CONTEXT:
\(calendarContext)

Rules for this context:
- ALL CONNECTED CALENDARS events (including those tagged [Google]) are real external commitments. They come from whatever calendar accounts the user has synced — Apple iCloud, Google Calendar, Exchange, etc. Never schedule over them. Mention them when relevant ("I see you have a Google Calendar meeting Tuesday at 2pm — I've kept that free").
- You CAN and SHOULD use Google Calendar events to answer questions like "what do I have planned?" or "build my week around my Google Calendar". Events tagged [Google] are from Google Calendar.
- FLOWLINE SAVED BLOCKS are what the user already planned in the app. Don't regenerate days that already have blocks unless the user asks.
- Use this context proactively: if asked "what do I have next week?" — answer from the calendar context. If asked to "plan around my busy week" — reference the real appointments from all sources.
"""
        }

        if let reviewContext {
            prompt += "\n\n\(reviewContext)"
        }

        prompt += "\nALWAYS respond in the same language the user writes in."

        self.systemPrompt = prompt
    }

    // MARK: - Send Message

    func sendMessage(
        history: [(role: String, content: String)],
        newMessage: String
    ) async throws -> String {
        var contents: [[String: Any]] = history.suffix(10).map { msg in
            [
                "role": msg.role == "assistant" ? "model" : "user",
                "parts": [["text": msg.content]]
            ]
        }
        contents.append(["role": "user", "parts": [["text": newMessage]]])

        let body: [String: Any] = [
            "model": model,
            "systemInstruction": ["parts": [["text": systemPrompt]]],
            "contents": contents,
            "generationConfig": ["maxOutputTokens": 8192]
        ]

        let data = try await performRequest(body: body)
        return try parseText(from: data)
    }

    // MARK: - Generate Plan

    func generatePlan(
        for date: Date,
        history: [(role: String, content: String)]
    ) async throws -> GeneratedPlan {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        let dateString = dateFormatter.string(from: date)

        // Build week date list (same logic as ClaudePlanningService)
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "EEEE, yyyy-MM-dd"
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let daysToMonday = (weekday == 1) ? -6 : -(weekday - 2)
        let monday = cal.startOfDay(for: cal.date(byAdding: .day, value: daysToMonday, to: date)!)
        var weekDateLines = ""
        for i in 0..<7 {
            if let d = cal.date(byAdding: .day, value: i, to: monday) {
                weekDateLines += "- \(shortFormatter.string(from: d)) (\(isoFormatter.string(from: d)))\n"
            }
        }

        let planSystemPrompt = systemPrompt + """

You are now in JSON-only mode. Return ONLY a raw JSON object matching the schema provided. No markdown, no code fences, no explanation.

Rules:
- Every block MUST have a "date" field in yyyy-MM-dd format
- Use exact dates from the week list below — do NOT invent dates
- category must be one of: study, work, health, personal
- Block titles must be plain names only. NO duration or parentheses. Write "Gym" not "Gym (1.5h)".
- Set replaceWeek to true ONLY if user explicitly says "redo", "replace", "delete and redo", or "start over my week". Default is ALWAYS false.
- Set mergeWithExisting to true when user says "add", "also add", "include", or wants ONE task added to an existing day without changing other blocks. Default is false.
- A "week plan" means ALL 7 days: Monday through Sunday. Never generate only 5 days for a week plan.
- Only add ONE "Free time" block per day maximum.

This week's dates:
\(weekDateLines.trimmingCharacters(in: .whitespacesAndNewlines))
Today is \(dateString).
"""

        var contents: [[String: Any]] = history.suffix(10).map { msg in
            [
                "role": msg.role == "assistant" ? "model" : "user",
                "parts": [["text": msg.content]]
            ]
        }

        // Ensure last content is a user trigger
        let triggerMessage = "Generate the JSON plan now. Use the correct date (yyyy-MM-dd) for each block from the week list."
        if contents.isEmpty {
            contents.append(["role": "user", "parts": [["text": "Create a plan for \(dateString)."]]])
        } else if let last = contents.last, (last["role"] as? String) == "model" {
            contents.append(["role": "user", "parts": [["text": triggerMessage]]])
        } else {
            contents[contents.count - 1] = ["role": "user", "parts": [["text": triggerMessage]]]
        }

        let responseSchema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "blocks": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "title":     ["type": "STRING"],
                            "startTime": ["type": "STRING", "description": "HH:mm format"],
                            "endTime":   ["type": "STRING", "description": "HH:mm format"],
                            "category":  ["type": "STRING", "enum": ["study", "work", "health", "personal"]],
                            "date":      ["type": "STRING", "description": "yyyy-MM-dd format, required"]
                        ],
                        "required": ["title", "startTime", "endTime", "category", "date"]
                    ]
                ],
                "summary":           ["type": "STRING"],
                "replaceWeek":       ["type": "BOOLEAN"],
                "mergeWithExisting": ["type": "BOOLEAN"]
            ],
            "required": ["blocks", "summary"]
        ]

        let body: [String: Any] = [
            "model": model,
            "systemInstruction": ["parts": [["text": planSystemPrompt]]],
            "contents": contents,
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema":   responseSchema,
                "maxOutputTokens":  8192
            ]
        ]

        let data = try await performRequest(body: body)
        var text = try parseText(from: data)

        // Strip markdown fences just in case
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```json") { text = String(text.dropFirst(7)) }
        else if text.hasPrefix("```") { text = String(text.dropFirst(3)) }
        if text.hasSuffix("```") { text = String(text.dropLast(3)) }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = text.data(using: .utf8) else {
            throw GeminiError.invalidResponse
        }
        return try JSONDecoder().decode(GeneratedPlan.self, from: jsonData)
    }

    // MARK: - Private

    private func performRequest(body: [String: Any]) async throws -> Data {
        guard let url = URL(string: Config.proxyURL + "/ai/gemini") else {
            throw GeminiError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(Config.appSecret, forHTTPHeaderField: "x-app-secret")
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw GeminiError.noInternet
            case .timedOut:
                throw GeminiError.timeout
            default:
                throw GeminiError.noInternet
            }
        }

        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 429:
            // Rate limited — wait 5s and retry once
            try await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 5_000_000_000)
            let (retryData, retryResponse) = try await session.data(for: request)
            guard let retryHttp = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHttp.statusCode) else {
                throw GeminiError.rateLimited
            }
            return retryData
        case 401, 403:
            throw GeminiError.unauthorized
        case 500...599:
            throw GeminiError.serverError
        default:
            print("Gemini Proxy Error \(http.statusCode):", String(data: data, encoding: .utf8) ?? "")
            throw GeminiError.requestFailed(statusCode: http.statusCode)
        }
    }

    private func parseText(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            print("Gemini parse error. Raw:", String(data: data, encoding: .utf8) ?? "")
            throw GeminiError.invalidResponse
        }
        return text
    }
}

// MARK: - Models (shared between services)

struct PlanBlock: Codable {
    let title: String
    let startTime: String
    let endTime: String
    let category: String
    let date: String?
}

struct GeneratedPlan: Codable {
    let blocks: [PlanBlock]
    let summary: String
    let replaceWeek: Bool?
    let mergeWithExisting: Bool?
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case requestFailed(statusCode: Int)
    case invalidResponse
    case noInternet
    case timeout
    case rateLimited
    case unauthorized
    case serverError

    var errorDescription: String? {
        switch self {
        case .noInternet:
            return "No internet connection. Check your network and try again."
        case .timeout:
            return "Request timed out. Try again in a moment."
        case .rateLimited:
            return "Too many requests. Wait a few seconds and try again."
        case .unauthorized:
            return "API key issue. Contact support."
        case .serverError:
            return "AI service is down. Try again in a minute."
        case .requestFailed(let code):
            return "Something went wrong (code \(code)). Try again."
        case .invalidResponse:
            return "Got an unexpected response. Try again."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .noInternet, .timeout, .rateLimited, .serverError, .requestFailed: return true
        case .unauthorized, .invalidResponse: return false
        }
    }
}
