import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if message.isUser {
                    Text(message.text)
                        .padding(12)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    MarkdownView(text: message.text)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ChatBubbleView(message: ChatMessage(text: "Who works in Finance?", isUser: true))
        ChatBubbleView(message: ChatMessage(text: "Based on your contacts, **John Smith** works in Finance at ABC Corp.", isUser: false))
    }
    .padding()
}
