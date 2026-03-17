import Foundation
import SwiftData

enum CheckInResult: String, Codable {
    case done, partly, skipped
}

@Model
final class ScheduleBlock {
    var title: String
    var category: Category?
    var startTime: Date
    var endTime: Date
    var isCompleted: Bool
    var checkInResult: CheckInResult?
    var createdAt: Date
    @Relationship var task: FlowTask?

    init(title: String, category: Category? = nil, startTime: Date, endTime: Date) {
        self.title = title
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.isCompleted = false
        self.createdAt = Date()
    }
}