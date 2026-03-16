import Foundation
import SwiftData

enum CheckInResult: String, Codable {
    case done, partly, skipped
}

@Model
final class ScheduleBlock {
    @Relationship var task: FlowTask
    var startTime: Date
    var endTime: Date
    var isProtected: Bool
    var isCompleted: Bool
    var checkInResult: CheckInResult?
    var createdAt: Date

    init(task: FlowTask, startTime: Date, endTime: Date) {
        self.task = task
        self.startTime = startTime
        self.endTime = endTime
        self.isProtected = false
        self.isCompleted = false
        self.createdAt = Date()
    }
}