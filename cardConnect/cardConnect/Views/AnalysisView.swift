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
        You are an expert Business Development Consultant.
        Your goal is to help the user grow their network and find business opportunities using their contact list and external knowledge (Google Search).
        
        User's Contact List:
        \(context)
        
        User Question: \(userMessage)
        
        Instructions:
        1. Use Google Search to find current news, company needs, or professional background if relevant to the question.
        2. Suggest specific contacts from the list who might be good targets or connectors.
        3. Recommend companies that might be good targets based on the user's intent.
        4. Be professional, strategic, and concise.
        """
        
        Task {
            await geminiService.sendAnalysisMessage(fullPrompt)
            
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
