import Foundation
import FirebaseAILogic
import FirebaseCore
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
        // Use Firebase AI Logic
        // Initialize the service using the FirebaseAI entry point
        // and the .vertexAI() backend (or .googleAI() if using that)
        let service = FirebaseAI.firebaseAI(backend: .vertexAI())
        
        // We use gemini-3.0-flash as requested.
        self.model = service.generativeModel(modelName: "gemini-2.5-flash")
    }

    func sendMessage(_ message: String) async {
        guard let model = model else {
            self.errorMessage = "Model not initialized."
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
        - Website
        - Company Name
        - Department
        - Address
        
        Return the result as a JSON array of objects. Keys should be: name, title, phone, email, website, companyName, department, address.
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
            
            let cleanText = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            guard let data = cleanText.data(using: String.Encoding.utf8) else {
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
        
        // Use Google Search Grounding tool
        let tools: [Tool] = [.googleSearch()]
        
        let service = FirebaseAI.firebaseAI(backend: .vertexAI())
        let enrichmentModel = service.generativeModel(
            modelName: "gemini-2.5-flash",
            tools: tools
        )
        
        let prompt = """
        Act as an expert Sales Agent connecting industry supply and demand.
        Use Google Search to find up-to-date information about the following company and person.
        
        Business Card Info:
        Company: \(card.companyName ?? "Unknown")
        Title: \(card.title ?? "Unknown")
        Department: \(card.department ?? "Unknown")
        Address: \(card.address ?? "")
        Website: \(card.website ?? "")
        
        Generate a concise Sales Analysis:
        1. **Industry**: A short industry tag.
        2. **Company Summary**: A concise description of what the company does.
        3. **Sales Analysis Report** (formatted in Markdown):
           - **Supply & Demand**: What does this company likely sell (Supply) and what do they likely need/buy (Demand)?
           - **Why Connect**: Why does this candidate/company stand out? What is the specific opportunity?
           - **Top Recommended Contacts**: Who are the specific top contacts (roles or real names if found) that the user should reach out to at this company to initiate a business relationship?
        
        Return the result as a strictly valid JSON object with keys:
        - "companyDescription": (String) The company summary.
        - "roleDescription": (String) The 'Sales Analysis Report' in Markdown.
        - "industry": (String) The industry tag.
        
        Do not include markdown formatting for the JSON itself (no ```json code blocks). Just return the raw JSON string.
        """
        
        do {
            let response = try await enrichmentModel.generateContent(prompt)
            guard let text = response.text else {
                print("GeminiService: No text in response")
                return ("Could not generate description.", "Could not generate description.", "Unknown")
            }
            
             // Debug print to see if search was used
             print("Enrichment Response: \(text)")
             if let groundingMetadata = response.candidates.first?.groundingMetadata {
                 print("Grounding Metadata: \(groundingMetadata)")
             }
            
            let cleanText = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            guard let data = cleanText.data(using: String.Encoding.utf8) else {
                 return (cleanText, "", "Unknown")
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
