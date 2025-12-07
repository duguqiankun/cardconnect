import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
    
    init(text: String, isUser: Bool) {
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
    }
}
