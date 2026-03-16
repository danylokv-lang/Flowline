import Foundation

protocol AIPlanning {
    func sendMessage(
        history: [(role: String, content: String)],
        newMessage: String
    ) async throws -> String
}