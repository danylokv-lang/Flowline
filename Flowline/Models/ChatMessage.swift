import Foundation
import SwiftData

@Model
final class ChatMessage {
    var role: String
    var content: String
    var timestamp: Date
    var sessionDate: Date
    var sessionID: String = UUID().uuidString

    init(role: String, content: String, sessionDate: Date, sessionID: String = UUID().uuidString) {
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.sessionDate = sessionDate
        self.sessionID = sessionID
    }
}
