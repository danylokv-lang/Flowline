import Foundation

final class GeminiPlanningService: AIPlanning {
    private let apiKey: String
    private let session: URLSession
    private let model: String
    private(set) var systemPrompt: String

    init(
        apiKey: String,
        model: String = "gemini-2.5-flash",
        systemPrompt: String = "You are Flowline, an AI daily planning assistant. Help users organize their day by asking about their tasks, priorities, and available time. Be concise, friendly, and practical. When you have enough information, create a clear time-blocked schedule. Also add time for small breaks",
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.systemPrompt = systemPrompt
        self.session = session
    }

    func updateSystemPrompt(from profile: UserProfile, calendarContext: String? = nil) {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        var prompt = """
You are Flowline, an AI daily planning assistant. Help users organize their day by asking about their tasks, 
    priorities, and available time. Be concise, friendly, and practical. When you have enough information, create a 
    clear time-blocked schedule. Also add time for small breaks.

User profile:
- Name: \(profile.name)
- Wakes up at \(formatter.string(from: profile.wakeTime))
- Goes to sleep at \(formatter.string(from: profile.sleepTime))
"""

        if profile.hasWorkHours, let start = profile.workStartTime, let end = profile.workEndTime {
            prompt += "- Has fixed hours from \(formatter.string(from: start)) to \(formatter.string(from: end))\n"
        }

        if !profile.bio.isEmpty {
            prompt += "- About them: \(profile.bio)\n"
        }

        prompt += "\nUse this information to create personalized schedules."

        if let calendarContext {
            prompt += "\n\nCurrent calendar:\n\(calendarContext)\nYou can suggest changes to existing events or add new ones."
        }

        self.systemPrompt = prompt
    }

    func sendMessage(
        history: [(role: String, content: String)],
        newMessage: String
    ) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build contents array from history + new message
        var contents: [[String: Any]] = history.map { message in
            [
                "role": message.role == "assistant" ? "model" : "user",
                "parts": [["text": message.content]]
            ]
        }
        contents.append([
            "role": "user",
            "parts": [["text": newMessage]]
        ])

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": systemPrompt]]],
            "contents": contents
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        // Retry once after delay if rate limited
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
            try await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 5_000_000_000) // wait 5 seconds
            let (retryData, retryResponse) = try await session.data(for: request)
            guard let retryHttp = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHttp.statusCode) else {
                let code = (retryResponse as? HTTPURLResponse)?.statusCode ?? -1
                print("API Error body:", String(data: retryData, encoding: .utf8) ?? "no body")
                throw GeminiError.requestFailed(statusCode: code)
            }
            return try parseResponse(retryData)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("API Error body:", String(data: data, encoding: .utf8) ?? "no body")
            throw GeminiError.requestFailed(statusCode: statusCode)
        }

        return try parseResponse(data)
    }

    func generatePlan(
        for date: Date,
        history: [(role: String, content: String)]
    ) async throws -> GeneratedPlan {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        let dateString = dateFormatter.string(from: date)

        let contents: [[String: Any]] = history.map { message in
            [
                "role": message.role == "assistant" ? "model" : "user",
                "parts": [["text": message.content]]
            ]
        }

        let responseSchema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "blocks": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "title": ["type": "STRING"],
                            "startTime": ["type": "STRING", "description": "HH:mm format"],
                            "endTime": ["type": "STRING", "description": "HH:mm format"],
                            "category": ["type": "STRING", "enum": ["study", "work", "health", "personal"]],
                            "date": ["type": "STRING", "description": "yyyy-MM-dd format, required for multi-day plans"]
                        ],
                        "required": ["title", "startTime", "endTime", "category"]
                    ]
                ],
                "summary": ["type": "STRING"],
                "replaceWeek": ["type": "BOOLEAN", "description": "true if this plan replaces the entire week"]
            ],
            "required": ["blocks", "summary"]
        ]

        let planPrompt = systemPrompt + "\nWhen creating a plan return valid JSON matching the schema. For conversation return normal text.\nCreate a plan for: \(dateString)."

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": planPrompt]]],
            "contents": contents,
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": responseSchema
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
            try await _Concurrency.Task<Never, Never>.sleep(nanoseconds: 5_000_000_000)
            let (retryData, retryResponse) = try await session.data(for: request)
            guard let retryHttp = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHttp.statusCode) else {
                let code = (retryResponse as? HTTPURLResponse)?.statusCode ?? -1
                print("API Error body:", String(data: retryData, encoding: .utf8) ?? "no body")
                throw GeminiError.requestFailed(statusCode: code)
            }
            return try parsePlanResponse(retryData)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("API Error body:", String(data: data, encoding: .utf8) ?? "no body")
            throw GeminiError.requestFailed(statusCode: statusCode)
        }

        return try parsePlanResponse(data)
    }

    private func parsePlanResponse(_ data: Data) throws -> GeneratedPlan {
        let text = try parseResponse(data)
        guard let jsonData = text.data(using: .utf8) else {
            throw GeminiError.invalidResponse
        }
        return try JSONDecoder().decode(GeneratedPlan.self, from: jsonData)
    }

    private func parseResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw GeminiError.invalidResponse
        }
        return text
    }
}

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
}

enum GeminiError: LocalizedError {
    case requestFailed(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .requestFailed(let code):
            return "Gemini API request failed with status \(code)"
        case .invalidResponse:
            return "Could not parse Gemini response"
        }
    }
}
