import SwiftUI
import SwiftData

struct AnalysisView: View {
    @Query private var cards: [BusinessCard]
    @State private var prompt: String = ""
    @State private var geminiService = GeminiService()
    @State private var messages: [ChatMessage] = []
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Analysis")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("Ask questions about your contacts")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Examples:\n• \"Who works in Finance?\"\n• \"Draft an email to John\"\n• \"List all contacts from ABC Corp\"")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 80)
                        } else {
                            ForEach(messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                            
                            if geminiService.isLoading {
                                HStack {
                                    ProgressView()
                                        .padding(.horizontal, 8)
                                    Text("Thinking...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.leading, 12)
                                .id("loading")
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: geminiService.isLoading) { _, isLoading in
                    if isLoading {
                        withAnimation {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input Area
            HStack(spacing: 12) {
                TextField("Ask about your contacts...", text: $prompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .disabled(geminiService.isLoading)
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(prompt.isEmpty || geminiService.isLoading ? .gray : .purple)
                }
                .disabled(prompt.isEmpty || geminiService.isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
    }
    
    private func sendMessage() {
        let userMessage = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }
        
        // Add user message to chat
        messages.append(ChatMessage(text: userMessage, isUser: true))
        
        // Clear input
        prompt = ""
        isInputFocused = false
        
        // Build context and send to Gemini
        let context = cards.map { card in
            "Name: \(card.name), Company: \(card.companyName), Title: \(card.title), Email: \(card.email), Role: \(card.personRoleDescription)"
        }.joined(separator: "\n---\n")
        
        let fullPrompt = """
        You are an intelligent assistant analyzing a database of business cards.
        Here is the data:
        
        \(context)
        
        User Question: \(userMessage)
        
        Answer based ONLY on the provided data. If the answer is not in the data, say so.
        """
        
        Task {
            await geminiService.sendMessage(fullPrompt)
            
            // Add AI response to chat
            if let error = geminiService.errorMessage {
                messages.append(ChatMessage(text: "Error: \(error)", isUser: false))
            } else if !geminiService.responseText.isEmpty {
                messages.append(ChatMessage(text: geminiService.responseText, isUser: false))
            }
        }
    }
}

#Preview {
    AnalysisView()
}
