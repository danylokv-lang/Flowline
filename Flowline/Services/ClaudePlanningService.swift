import Foundation

final class ClaudePlanningService: AIPlanning {
    private let apiKey: String
    private let session: URLSession
    private let model: String
    private(set) var systemPrompt: String

    init(
        apiKey: String,
        model: String = "claude-haiku-4-5-20251001",
        systemPrompt: String = "You are Flowline, an AI daily planning assistant. Help users organize their day by asking about their tasks, priorities, and available time. Be concise, friendly, and practical. When you have enough information, create a clear time-blocked schedule. Also add time for small breaks.",
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.systemPrompt = systemPrompt
        self.session = session
    }

    func updateSystemPrompt(from profile: UserProfile, calendarContext: String? = nil) {
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

        prompt += """

BEHAVIOR RULES:
1. If the user's message contains ANY tasks or activities → BUILD THE PLAN IMMEDIATELY. Do not ask questions. Make smart assumptions.
2. If the message is too vague (e.g. "plan my day" with zero tasks mentioned) → ask for tasks in exactly ONE short message, nothing more.
3. Never ask more than one follow-up question total in a conversation.
4. Always schedule within their wake/sleep window. Never place tasks before wake time or after sleep time.
5. Add 5–10 min buffer between blocks.

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
When unsure, pick the middle estimate and mention it briefly.

FORMAT: Present the plan as a clean time-blocked list. Be concise. No filler phrases.
"""

        if let calendarContext {
            prompt += "\nEXISTING CALENDAR THIS WEEK:\n\(calendarContext)\nSchedule around these. Don't move them unless asked.\n"
        }

        prompt += "\nALWAYS respond in the same language the user writes in."

        self.systemPrompt = prompt
    }

    // MARK: - Send Message

    func sendMessage(
        history: [(role: String, content: String)],
        newMessage: String
    ) async throws -> String {
        var messages = history.map { msg in
            ["role": msg.role, "content": msg.content]
        }
        messages.append(["role": "user", "content": newMessage])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": messages
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

        // Build the full week date list so Claude uses correct dates for each block
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

You are now in JSON-only mode. You MUST return ONLY a raw JSON object. No markdown. No code fences. No explanation. No text before or after. Just the JSON.

Exact structure required:
{"replaceWeek":false,"blocks":[{"title":"Task name","startTime":"07:00","endTime":"08:00","category":"health","date":"yyyy-MM-dd"}],"summary":"One sentence summary"}

Rules:
- Every block MUST have a "date" field in yyyy-MM-dd format
- Use the exact dates from the week list below — do NOT invent dates
- category must be one of: study, work, health, personal
- Set replaceWeek to true only if user asked to redo the whole week
- Return ONLY the JSON. If you add any other text, the app will crash.

This week's dates:
\(weekDateLines.trimmingCharacters(in: .whitespacesAndNewlines))
Today is \(dateString).
"""

        var messages = history.map { msg in
            ["role": msg.role, "content": msg.content]
        }

        // Ensure last message is from user (Claude API requires alternating roles)
        let triggerMessage = "Generate the JSON plan now. Use the correct date (yyyy-MM-dd) for each block from the week list. Return ONLY the JSON object, no markdown, no explanation."
        if let last = messages.last, last["role"] == "assistant" {
            messages.append(["role": "user", "content": triggerMessage])
        } else if messages.isEmpty {
            messages.append(["role": "user", "content": "Create a plan for \(dateString). Return ONLY the JSON object."])
        } else {
            // Last message is already user — replace it with trigger
            messages[messages.count - 1] = ["role": "user", "content": triggerMessage]
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": planSystemPrompt,
            "messages": messages
        ]

        let data = try await performRequest(body: body)
        var text = try parseText(from: data)

        // Strip markdown code fences if present
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```json") {
            text = String(text.dropFirst(7))
        } else if text.hasPrefix("```") {
            text = String(text.dropFirst(3))
        }
        if text.hasSuffix("```") {
            text = String(text.dropLast(3))
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = text.data(using: .utf8) else {
            throw ClaudeError.invalidResponse
        }
        return try JSONDecoder().decode(GeneratedPlan.self, from: jsonData)
    }

    // MARK: - Private

    private func performRequest(body: [String: Any]) async throws -> Data {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
            try await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 5_000_000_000)
            let (retryData, retryResponse) = try await session.data(for: request)
            guard let retryHttp = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHttp.statusCode) else {
                let code = (retryResponse as? HTTPURLResponse)?.statusCode ?? -1
                print("Claude API Error:", String(data: retryData, encoding: .utf8) ?? "no body")
                throw ClaudeError.requestFailed(statusCode: code)
            }
            return retryData
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("Claude API Error:", String(data: data, encoding: .utf8) ?? "no body")
            throw ClaudeError.requestFailed(statusCode: statusCode)
        }

        return data
    }

    private func parseText(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw ClaudeError.invalidResponse
        }
        return text
    }
}

enum ClaudeError: LocalizedError {
    case requestFailed(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .requestFailed(let code):
            return "Claude API request failed with status \(code)"
        case .invalidResponse:
            return "Could not parse Claude response"
        }
    }
}
