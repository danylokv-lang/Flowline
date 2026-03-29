import SwiftUI

// MARK: - DayTemplate

/// A lightweight planning template that injects extra constraints into the AI prompt.
/// Templates are code-defined — add a new `DayTemplate(...)` to `DayTemplate.all`
/// to expose it in the selector without touching any other file.
struct DayTemplate: Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let accent: Color
    /// Plain-English constraints appended to the hero plan prompt.
    /// Keep them concise — the AI reads these alongside the full system prompt.
    let promptConstraints: String

    // MARK: Built-in templates

    static let all: [DayTemplate] = [
        DayTemplate(
            id: "school",
            name: "School",
            emoji: "🏫",
            accent: Color(hex: "#3b82f6"),
            promptConstraints: """
            This is a SCHOOL DAY. Apply these constraints:
            • Block 8am–3pm as school/class time (mark as study category).
            • Schedule homework or revision blocks in the afternoon (3–6pm).
            • Keep the evening lighter — wind-down, personal time.
            • Do not schedule heavy personal errands during school hours.
            """
        ),
        DayTemplate(
            id: "workday",
            name: "Work",
            emoji: "💼",
            accent: Color(hex: "#3b82f6"),
            promptConstraints: """
            This is a standard WORK DAY. Apply these constraints:
            • Protect a 2–4h deep-focus block in the morning for complex tasks.
            • Leave mid-morning and mid-afternoon for meetings or calls.
            • Include a proper lunch break (30–60 min).
            • Wind down after work — avoid work blocks after 7pm.
            """
        ),
        DayTemplate(
            id: "exam",
            name: "Exam",
            emoji: "📝",
            accent: Color(hex: "#f59e0b"),
            promptConstraints: """
            This is an EXAM DAY. Apply these constraints:
            • Prioritise revision and focused study above everything else.
            • No intense social events, heavy exercise, or draining activities.
            • Include short breaks every 45–60 min to avoid burnout.
            • Schedule an early wind-down and proper sleep prep tonight.
            • Keep meals light and energising.
            """
        ),
        DayTemplate(
            id: "rest",
            name: "Rest",
            emoji: "🛋️",
            accent: Color(hex: "#10b981"),
            promptConstraints: """
            This is a REST & RECOVERY DAY. Apply these constraints:
            • No heavy work, study, or stressful tasks.
            • Prioritise rest, light leisure, and personal wellbeing.
            • A gentle walk or light stretch is fine, but no intense gym sessions.
            • Leave large unstructured blocks — this is intentional recovery time.
            """
        ),
        DayTemplate(
            id: "weekend",
            name: "Weekend",
            emoji: "🌅",
            accent: Color(hex: "#ec4899"),
            promptConstraints: """
            This is a WEEKEND DAY. Apply these constraints:
            • No rigid 9–5 work structure — keep the morning relaxed.
            • Prioritise personal activities, hobbies, social time, and errands.
            • Light study or personal projects are fine but keep them short.
            • Build in leisure, outdoor time, and fun blocks.
            """
        ),
        DayTemplate(
            id: "workout",
            name: "Workout",
            emoji: "💪",
            accent: Color(hex: "#ef4444"),
            promptConstraints: """
            This is a WORKOUT DAY. Apply these constraints:
            • Schedule a gym or training session (60–90 min, mark as health).
            • Add a post-workout recovery block (stretching, protein meal, shower).
            • Place mentally demanding tasks BEFORE the workout, not after.
            • Keep the evening easier — the body needs to recover.
            """
        ),
        DayTemplate(
            id: "deepwork",
            name: "Deep Work",
            emoji: "🎯",
            accent: Color(hex: "#8b5cf6"),
            promptConstraints: """
            This is a DEEP WORK DAY. Apply these constraints:
            • Maximise uninterrupted focus blocks (90–180 min each).
            • Minimise or batch all meetings/calls into a single short window.
            • No social media, errands, or low-value tasks until after 5pm.
            • Short 10–15 min breaks between deep blocks to recharge.
            """
        ),
        DayTemplate(
            id: "wellness",
            name: "Wellness",
            emoji: "🧘",
            accent: Color(hex: "#06b6d4"),
            promptConstraints: """
            This is a WELLNESS DAY. Apply these constraints:
            • Open with a mindfulness or meditation block (10–20 min).
            • Include a yoga, walk, or gentle movement session.
            • Plan healthy meals — no rushed eating.
            • Keep stress low: no urgent deadlines or heavy mental work.
            • End the day with a proper wind-down ritual.
            """
        ),
    ]
}
