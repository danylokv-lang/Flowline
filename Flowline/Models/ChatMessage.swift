import Foundation
import SwiftData

@Model
final class ChatMessage {
    var role: String
    var content: String
    var timestamp: Date
    var sessionDate: Date

    init(role: String, content: String, sessionDate: Date) {
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.sessionDate = sessionDate
    }
}
