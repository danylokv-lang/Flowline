import Foundation
import SwiftData

@Model final class CapturedTask {
    var text: String
    var createdAt: Date
    var isScheduled: Bool = false

    init(text: String) {
        self.text = text
        self.createdAt = Date()
    }
}
