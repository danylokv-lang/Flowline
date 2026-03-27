import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String
    var wakeTime: Date
    var sleepTime: Date
    var hasWorkHours: Bool
    var workStartTime: Date?
    var workEndTime: Date?
    var bio: String
    /// One commitment per line, e.g. "Standup 9:00–9:30 Mon–Fri\nGym 6pm Mon/Wed/Fri"
    var recurringCommitments: String = ""
    /// JSON-encoded WeeklySchedule. Non-empty means per-day schedule is active.
    /// Stored as a string so SwiftData auto-migrates with no manual schema version bump.
    var weeklySchedule: String = ""
    var createdAt: Date

    init(name: String, wakeTime: Date, sleepTime: Date, hasWorkHours: Bool,
         workStartTime: Date?, workEndTime: Date?, bio: String,
         recurringCommitments: String = "", weeklySchedule: String = "") {
        self.name = name
        self.wakeTime = wakeTime
        self.sleepTime = sleepTime
        self.hasWorkHours = hasWorkHours
        self.workStartTime = workStartTime
        self.workEndTime = workEndTime
        self.bio = bio
        self.recurringCommitments = recurringCommitments
        self.weeklySchedule = weeklySchedule
        self.createdAt = Date()
    }
}
