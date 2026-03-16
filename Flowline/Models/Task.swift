/*
Name of task (Must)
Bullet Points of Task(Must)
Description (Optional)
Deadline(Optional)
Category of Taks(Optional)
Priority of Taks(Optional)

we need id for task to call tasks by their id and also saving.


*/
import Foundation
import SwiftData

@Model
final class FlowTask {
    var name: String 
    var category: Category?
    var priority: Priority?
    var bulletPoints: [String]
    var taskDescription: String?
    var deadline: Date?
    var estimatedDuration: TimeInterval?
    var isCompleted: Bool
    var createdAt: Date

    init(name: String) {
        self.name = name
        self.bulletPoints = []
        self.isCompleted = false
        self.createdAt = Date()
    }
}

enum Category: String, Codable {
    case study, work, health, personal
}

enum Priority: String, Codable {
    case high, medium, low
}
