import Foundation
import GoogleGenerativeAI
import UIKit

@Observable
class GeminiService {
    private var model: GenerativeModel?
    var responseText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    init() {
        // Initialize the model
        setupModel()
    }
    
    func setupModel() {
        // Read API Key from Info.plist
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String, !apiKey.isEmpty else {
            self.errorMessage = "Gemini API Key not found in Info.plist"
            return
        }
        
        // Try the latest model
        self.model = GenerativeModel(name: "gemini-2.0-flash", apiKey: apiKey)
    }

    func sendMessage(_ message: String) async {
        guard let model = model else {
            self.errorMessage = "Model not initialized. Check API Key."
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        self.responseText = ""
        
        do {
            let response = try await model.generateContent(message)
            if let text = response.text {
                self.responseText = text
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isLoading = false
    }
    
    func extractCardInfo(from image: UIImage) async throws -> [BusinessCardDraft] {
        guard let model = model else {
            throw NSError(domain: "GeminiService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not initialized"])
        }
        
        self.isLoading = true
        defer { self.isLoading = false }
        
        let prompt = """
        Analyze this image. It may contain one or more business cards.
        For each business card found, extract the following information:
        - Name
        - Title
        - Phone
        - Email
        - Company Name
        - Department
        - Address
        
        Return the result as a JSON array of objects. Keys should be: name, title, phone, email, companyName, department, address.
        If a field is missing, omit it or use null.
        Do not include markdown formatting like ```json ... ```. Just return the raw JSON string.
        """
        
        do {
            let response = try await model.generateContent(prompt, image)
            guard let text = response.text else {
                print("GeminiService: No text in response")
                throw NSError(domain: "GeminiService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No text in response"])
            }
            
            print("GeminiService Raw Response: \(text)")
            
            // Clean up potential markdown formatting if Gemini adds it despite instructions
            let cleanText = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let data = cleanText.data(using: .utf8) else {
                print("GeminiService: Failed to convert response to data")
                throw NSError(domain: "GeminiService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response to data"])
            }
            
            let decoder = JSONDecoder()
            let drafts = try decoder.decode([BusinessCardDraft].self, from: data)
            print("GeminiService: Successfully decoded \(drafts.count) drafts")
            return drafts
            
        } catch {
            print("GeminiService Error: \(error)")
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func enrichCardInfo(card: BusinessCardDraft) async throws -> (companyDesc: String, roleDesc: String, industry: String) {
        guard let model = model else {
            throw NSError(domain: "GeminiService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not initialized"])
        }
        
        // Don't set global isLoading here to avoid blocking UI if we want to run this in background
        // Or we can set it if we want to show progress. Let's keep it simple for now.
        
        let prompt = """
        Based on the following business card information, provide:
        1. A brief description of what the company does.
        2. A brief description of what this person's role likely entails.
        3. The general Industry this company belongs to (e.g., Technology, Finance, Healthcare, Real Estate, Retail, etc.). Keep it to one word or a short phrase.
        
        Company: \(card.companyName ?? "Unknown")
        Title: \(card.title ?? "Unknown")
        Department: \(card.department ?? "Unknown")
        
        Return the result as a JSON object with keys: "companyDescription", "roleDescription", "industry".
        Do not include markdown formatting.
        """
        
        do {
            let response = try await model.generateContent(prompt)
            guard let text = response.text else {
                return ("Could not generate description.", "Could not generate description.", "Unknown")
            }
            
            let cleanText = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let data = cleanText.data(using: .utf8) else {
                 return (cleanText, "", "Unknown") // Fallback to raw text if not JSON
            }
            
            struct EnrichmentResult: Codable {
                var companyDescription: String?
                var roleDescription: String?
                var industry: String?
            }
            
            let result = try JSONDecoder().decode(EnrichmentResult.self, from: data)
            return (result.companyDescription ?? "", result.roleDescription ?? "", result.industry ?? "Unknown")
            
        } catch {
            print("Enrichment failed: \(error)")
            return ("Failed to enrich data.", "Failed to enrich data.", "Unknown")
        }
    }
}
