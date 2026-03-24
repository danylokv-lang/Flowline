import Foundation
import SwiftData

@Model final class CapturedTask {
    var taskID: String     // stable UUID for cross-device deduplication
    var text: String
    var category: String   // "work" | "study" | "health" | "personal"
    var createdAt: Date
    var isScheduled: Bool

    init(text: String, category: String = "work") {
        self.taskID      = UUID().uuidString
        self.text        = text
        self.category    = category
        self.createdAt   = Date()
        self.isScheduled = false
    }
}
