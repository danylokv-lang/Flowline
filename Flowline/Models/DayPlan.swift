import Foundation
import SwiftData

enum DayPlanStatus: String, Codable {
    case planned, active, completed
}

@Model
final class DayPlan {
    var date: Date
    @Relationship(deleteRule: .cascade) var blocks: [ScheduleBlock]
    var status: DayPlanStatus
    var aiNotes: String?
    var createdAt: Date

    init(date: Date) {
        self.date = date
        self.blocks = []
        self.status = .planned
        self.createdAt = Date()
    }
}