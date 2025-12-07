import SwiftUI

struct MarkdownView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseBlocks(from: text), id: \.id) { block in
                switch block.type {
                case .code(let code):
                    CodeBlockView(code: code)
                case .text(let content):
                    // Split by newlines to preserve line structure
                    ForEach(splitIntoParagraphs(content), id: \.self) { paragraph in
                        if paragraph.hasPrefix("- ") || paragraph.hasPrefix("* ") || paragraph.hasPrefix("• ") {
                            // Bullet point
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(parseMarkdownText(String(paragraph.dropFirst(2))))
                                    .textSelection(.enabled)
                            }
                        } else if let match = paragraph.firstMatch(of: /^(\d+)\.\s+(.*)/) {
                            // Numbered list
                            HStack(alignment: .top, spacing: 6) {
                                Text("\(match.1).")
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 20, alignment: .trailing)
                                Text(parseMarkdownText(String(match.2)))
                                    .textSelection(.enabled)
                            }
                        } else if paragraph.hasPrefix("# ") {
                            Text(parseMarkdownText(String(paragraph.dropFirst(2))))
                                .font(.title2)
                                .fontWeight(.bold)
                        } else if paragraph.hasPrefix("## ") {
                            Text(parseMarkdownText(String(paragraph.dropFirst(3))))
                                .font(.title3)
                                .fontWeight(.semibold)
                        } else if paragraph.hasPrefix("### ") {
                            Text(parseMarkdownText(String(paragraph.dropFirst(4))))
                                .font(.headline)
                        } else if !paragraph.isEmpty {
                            Text(parseMarkdownText(paragraph))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }
    
    private func parseMarkdownText(_ text: String) -> AttributedString {
        do {
            return try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        } catch {
            return AttributedString(text)
        }
    }
    
    private func splitIntoParagraphs(_ text: String) -> [String] {
        // Split by newlines but preserve structure
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    private struct Block: Identifiable {
        let id = UUID()
        let type: BlockType
    }
    
    private enum BlockType {
        case text(String)
        case code(String)
    }
    
    private func parseBlocks(from text: String) -> [Block] {
        var blocks: [Block] = []
        let components = text.components(separatedBy: "```")
        
        for (index, component) in components.enumerated() {
            if index % 2 == 0 {
                // Even indices are normal text
                let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    blocks.append(Block(type: .text(trimmed)))
                }
            } else {
                // Odd indices are code blocks - strip language identifier from first line
                var codeLines = component.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                if !codeLines.isEmpty {
                    // First line might be the language (e.g., "swift", "python")
                    let firstLine = codeLines[0].trimmingCharacters(in: .whitespaces)
                    if firstLine.allSatisfy({ $0.isLetter || $0.isNumber }) && firstLine.count < 20 {
                        codeLines.removeFirst()
                    }
                }
                let code = codeLines.joined(separator: "\n")
                blocks.append(Block(type: .code(code)))
            }
        }
        
        if blocks.isEmpty && !text.isEmpty {
            return [Block(type: .text(text))]
        }
        
        return blocks
    }
}

struct CodeBlockView: View {
    let code: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Text(code.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(.caption, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGray5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    ScrollView {
        MarkdownView(text: """
        # Heading 1
        ## Heading 2
        
        Here is some **bold** and *italic* text.
        
        A numbered list:
        1. First item
        2. Second item
        3. Third item
        
        A bullet list:
        - Apple
        - Banana
        - Cherry
        
        Some code:
        ```swift
        func hello() {
            print("Hello, World!")
        }
        ```
        
        And more text after the code.
        """)
        .padding()
    }
}
