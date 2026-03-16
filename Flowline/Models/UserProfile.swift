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
    var createdAt: Date

    init(name: String, wakeTime: Date, sleepTime: Date, hasWorkHours: Bool, workStartTime: Date?, workEndTime: Date?, bio: String) {
        self.name = name
        self.wakeTime = wakeTime
        self.sleepTime = sleepTime
        self.hasWorkHours = hasWorkHours
        self.workStartTime = workStartTime
        self.workEndTime = workEndTime
        self.bio = bio
        self.createdAt = Date()
    }
}
