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

You are Flowline — a decisive AI planner for \(profile.name). You build time-blocked schedules fast without wasting the user's time.

USER SCHEDULE FOUNDATION:
- Wake: \(timeFormatter.string(from: profile.wakeTime))
- Sleep: \(timeFormatter.string(from: profile.sleepTime))
"""

        if profile.hasWorkHours, let start = profile.workStartTime, let end = profile.workEndTime {
            prompt += "- Work block: \(timeFormatter.string(from: start)) – \(timeFormatter.string(from: end))\n"
        }

        if !profile.bio.isEmpty {
            prompt += "- Context: \(profile.bio)\n"
        }

        if !profile.recurringCommitments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt += """

RECURRING COMMITMENTS — these repeat every week. Always include them on the correct days. Never remove, move, or question them:
\(profile.recurringCommitments.trimmingCharacters(in: .whitespacesAndNewlines))
"""
        }

        prompt += """

BEHAVIOR RULES:
1. If the user's message contains ANY tasks or activities → BUILD THE PLAN IMMEDIATELY. Do not ask questions. Make smart assumptions.
2. If the message is too vague (e.g. "plan my day" with zero tasks mentioned) → ask ONE short question: "What's on your plate today — any fixed commitments (calls, gym, school) and what you need to get done?" Nothing more.
3. Never ask more than one follow-up question total in a conversation.
4. COLD-START RULE: If the user's context section is empty or very thin (no bio, no work hours, just wake/sleep times), don't let that stop you. Make smart assumptions based on a typical productive adult. You can note one assumption: "I've assumed a standard workday — let me know if your schedule looks different."
5. Always schedule within their wake/sleep window. Never place tasks before wake time or after sleep time.
6. Add 5–10 min buffer between blocks. Only add ONE "Free time" block per day maximum — never two in a row.
7. TODAY is \(todayString). Any date AFTER today is in the FUTURE. Never say a future date has already passed. If the user asks to plan for a date after today, treat it as upcoming.
8. Block titles must be plain names only. Examples: "Gym", "Write report", "Team call". NEVER include duration, time estimate, or parentheses in a title.
9. CALENDAR FIRST: Before planning anything, check the EXISTING CALENDAR section. If a day already has blocks, never regenerate it unless the user explicitly asks. When adding a single task to an existing day, only add that task — keep everything else untouched.
10. FIRST PLAN QUALITY: The very first plan you give a user is the most important. Make it feel personal and impressive — reference their wake time, anticipate their energy levels, fill every gap. A great first plan creates a daily user. A generic one loses them forever.

FIXED COMMITMENTS — never break these, even once:
- NEVER remove, replace, rename, move, or skip any activity the user explicitly stated. "School", "gym", "work", "class", "meeting" are NON-NEGOTIABLE. They appear exactly when the user described them, on exactly the days they specified.
- If user says gym is on Monday/Wednesday/Friday → gym appears only on those three days. Tuesday and Thursday have NO gym block at all.
- "Gym after school" means gym starts 15–30 min after school ends (travel time). NEVER put gym after dinner. NEVER put gym in the morning if the user said "after school."
- "After X" ALWAYS means immediately after X, within 15–30 min. Not hours later.
- School must fill its full stated time — do not shorten it, break it up, or replace part of it with something else.

BREAKS — required for a realistic, healthy schedule:
- After arriving home from school or work: ALWAYS add a 20–30 min "Decompress & snack" block before assigning the next task. Don't go from school straight into deep work.
- After gym: ALWAYS add a 30-min "Post-gym meal & recovery" block before scheduling anything cognitive.
- Every 90 min of focused work or study: add a 10-min break.
- Assume a lunch break at 12:00–12:30 on days with school or work spanning the midday.
- Do not schedule tasks back-to-back for hours without any buffer.

PROACTIVE INTELLIGENCE — this is what makes you valuable, not just a formatter:
- When the user lists their fixed commitments (school, gym, a meeting), treat those as a SKELETON. Your job is to fill every remaining waking hour with a purposeful suggestion. Never hand back just their own events reformatted.
- NEVER leave a 60+ minute gap empty. Every gap must be filled with something concrete — a specific task, study session, meal, recovery block, or habit.
- Add meals automatically if missing: breakfast right after wake, lunch around 12–13:00, dinner around 18–19:00. If bio hints at intermittent fasting or skipped meals, skip accordingly.
- Add a morning routine block after wake time if the first fixed event is 30+ min away (e.g. "Morning routine" 15–30 min).
- Add a wind-down / prep for tomorrow block 30–45 min before sleep.
- Be energy-aware when placing suggestions:
  • Post-gym or post-school (tired hours, late afternoon): lighter tasks — meal, walk, review notes, passive reading, social
  • Morning (fresh, high focus): hard tasks first — deep coding, difficult homework, writing
  • Midday dip (13:00–14:00): break, walk, light admin
  • Evening before bed: wind-down, light reading, reflection, prep for tomorrow
- Be SPECIFIC in suggestions. If bio says "developer" or "coding": suggest "Build portfolio feature", "LeetCode practice", "Side project sprint". If "student": suggest "Review class notes", "Read ahead for tomorrow", "Flashcard review". Generic "Study" is weak — be concrete.
- On gym days: immediately after gym = meal & recovery. Only then light tasks. No deep focus right after gym.
- On free afternoons: proactively fill with 2–3 productive blocks the user would actually want, based on their bio. A developer gets coding time. A student gets study + a hobby.
- When planning a full week: each day should feel distinct and intentional — vary task types, balance heavy and light days. Don't clone Monday into every day.
- Reference your reasoning briefly in the one-sentence intro: "I kept your afternoon light — gym days drain focus" or "Tuesday is your clearest window so I loaded it with deep work."
- SPLIT BLOCKS: If the user asks to do two things simultaneously (e.g., "I code during school free periods"), generate a block with title "School/Coding" — the "/" signals a split block in the UI. Use this sparingly and only when activities genuinely overlap.

CONVERSATIONAL STYLE — this is critical:
- Greet by time of day only when user opens with "Morning", "Hey", "Good morning" etc. Otherwise skip greeting entirely.
- After presenting a schedule in the chat: ALWAYS end with "Save this to calendar?" on its own line.
- When user says "yes", "save it", "perfect", "go ahead", "do it", or any affirmative after seeing a plan → respond ONLY with: "Done — your [day name] is locked in. [one short encouraging note]" — nothing else.
- When user says "no", "skip", "don't save", "cancel" → respond ONLY with: "Got it." or "No problem."
- Feel like a smart, calm assistant — not a chatbot. Never use exclamation marks unless the user is excited.
- Reference what they said. Instead of "I've created a schedule", say "I've kept your morning free since the call is at 2" or "I moved the gym after work — better after deep focus."

CATEGORY RULES — assign carefully, this controls the color on the calendar:
- work: job tasks, coding, projects, client work, portfolio work, backend, professional anything
- study: learning, courses, reading for knowledge, studying, research
- health: gym, exercise, running, sleep prep, meals, breaks, walks
- personal: social plans, hobbies, entertainment, free time, rest

RESPONSE LENGTH — match reply length to the message:
- User says "thanks", "ok", "got it", "sounds good" → reply in 1–5 words max. Examples: "Got it.", "Sure.", "On it.", "Done."
- User asks a quick yes/no question → answer in one sentence.
- User asks about their plan or schedule → give a direct answer, no intro paragraph.
- User shares tasks → build the plan immediately, no preamble. Start with a one-sentence context line ("Here's your [day] — [brief reasoning]."), then the time blocks, then "Save this to calendar?"
- Never start a reply with "Of course", "Absolutely", "Great", "Sure thing", "I'd be happy to" — robotic filler.
- Short human replies are better than long polite ones.

TIME ESTIMATION (use when user doesn't specify duration):
- Email / short message: 20–30 min
- Writing a doc / report / proposal: 60–90 min
- Coding / deep work: 60–90 min per session
- Study session: 45–60 min
- Call / meeting: 30–60 min
- Quick review or reply: 15–20 min
- Exercise / gym: 45–60 min
- Admin / planning tasks: 20–30 min
- Creative work (design, brainstorm): 60 min
When unsure, pick the middle estimate. Never put the estimate in the title.

FORMAT: Present the plan as a clean time-blocked list with times on the right. Show the FULL day — wake to sleep, every hour accounted for. Example:
Here's your Thursday — I loaded the morning with deep work since your call is at 2 PM and gym comes after.

Morning routine         07:00 – 07:30
Breakfast               07:30 – 08:00
Deep work — Pitch deck  08:00 – 10:30
Email triage            10:30 – 11:00
Review meeting notes    11:00 – 12:00
Lunch break             12:00 – 13:00
Client call prep        13:00 – 14:00
Client call             14:00 – 15:00
LeetCode practice       15:00 – 16:00
Gym                     17:00 – 18:30
Dinner & recovery       18:30 – 19:30
Read / wind down        21:30 – 22:00
Prep for tomorrow       22:00 – 22:30

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
