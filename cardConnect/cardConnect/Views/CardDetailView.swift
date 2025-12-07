import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Bindable var card: BusinessCard
    @State private var geminiService = GeminiService()
    @State private var isEnriching = false
    
    var body: some View {
        Form {
            Section(header: Text("Personal Info")) {
                TextField("Name", text: $card.name)
                TextField("Title", text: $card.title)
                TextField("Phone", text: $card.phone)
                TextField("Email", text: $card.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            Section(header: Text("Company Info")) {
                TextField("Company Name", text: $card.companyName)
                TextField("Department", text: $card.department)
                TextField("Address", text: $card.address)
            }
            
            Section(header: Text("AI Enrichment")) {
                if isEnriching {
                    HStack {
                        Text("Enriching data...")
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Button("Enrich with AI") {
                        enrichCard()
                    }
                    .disabled(card.companyName.isEmpty && card.title.isEmpty)
                }
                
                if !card.industry.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Industry").font(.caption).foregroundColor(.secondary)
                        Text(card.industry)
                    }
                }
                
                if !card.companyDescription.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Company Description").font(.caption).foregroundColor(.secondary)
                        Text(card.companyDescription)
                    }
                }
                
                if !card.personRoleDescription.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Role Description").font(.caption).foregroundColor(.secondary)
                        Text(card.personRoleDescription)
                    }
                }
            }
            
            Section {
                Button(action: {
                    searchLinkedIn()
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search on LinkedIn")
                    }
                    .foregroundColor(.blue)
                }
            }
            
            if let imageData = card.imageData, let uiImage = UIImage(data: imageData) {
                Section(header: Text("Card Image")) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                }
            }
        }
        .navigationTitle(card.name.isEmpty ? "New Card" : card.name)
    }
    
    private func searchLinkedIn() {
        let query = "\(card.name) \(card.companyName)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.linkedin.com/search/results/all/?keywords=\(query)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func enrichCard() {
        isEnriching = true
        Task {
            // Create a draft from current data to send to Gemini
            let draft = BusinessCardDraft(
                name: card.name,
                title: card.title,
                phone: card.phone,
                email: card.email,
                companyName: card.companyName,
                department: card.department,
                address: card.address
            )
            
            do {
                let (companyDesc, roleDesc, industry) = try await geminiService.enrichCardInfo(card: draft)
                card.companyDescription = companyDesc
                card.personRoleDescription = roleDesc
                card.industry = industry
            } catch {
                print("Error enriching card: \(error)")
            }
            isEnriching = false
        }
    }
}
