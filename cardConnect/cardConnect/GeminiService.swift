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
        let service = FirebaseAI.firebaseAI(backend: .vertexAI())
        
        // General text model
        self.model = service.generativeModel(modelName: "gemini-2.5-flash")
    }

    func sendMessage(_ message: String) async {
        guard let model = model else {
            self.errorMessage = "Model not initialized."
            return
        }
        
        await generateResponse(using: model, prompt: message)
    }
    
    func sendAnalysisMessage(_ message: String) async {
        let service = FirebaseAI.firebaseAI(backend: .vertexAI())
        // Model with Google Search for Analysis
        let analysisModel = service.generativeModel(
            modelName: "gemini-2.5-flash",
            tools: [.googleSearch()]
        )
        
        await generateResponse(using: analysisModel, prompt: message)
    }

    private func generateResponse(using model: GenerativeModel, prompt: String) async {
        self.isLoading = true
        self.errorMessage = nil
        self.responseText = ""
        
        do {
            let response = try await model.generateContent(prompt)
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
        Business Card Info:
        Company: \(card.companyName ?? "Unknown")
        Title: \(card.title ?? "Unknown")
        Department: \(card.department ?? "Unknown")
        Address: \(card.address ?? "")
        Website: \(card.website ?? "")
        
        Provide a simple and accurate enrichment:
        1. **Company Description**: A brief, factual summary of what the company does.
        2. **Industry**: A specific industry tag.
        3. **Job Context**: A one-sentence explanation of what this role typically involves in this industry.
        
        Return a strictly valid JSON object:
        {
          "companyDescription": "...",
          "roleDescription": "...",
          "industry": "..."
        }
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
