import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Bindable var card: BusinessCard
    @State private var geminiService = GeminiService()
    @State private var isEnriching = false
    @State private var isEditing = false
    @State private var showEmailOptions = false
    
    var body: some View {
        Form {
            Section(header: Text("Personal Info")) {
                if isEditing {
                    TextField("Name", text: $card.name)
                    TextField("Title", text: $card.title)
                    TextField("Phone", text: $card.phone)
                    TextField("Email", text: $card.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                } else {
                    LabeledContent("Name", value: card.name)
                    LabeledContent("Title", value: card.title)
                    if !card.phone.isEmpty {
                        LabeledContent("Phone", value: card.phone)
                    }
                    if !card.email.isEmpty {
                        Button(action: { showEmailOptions = true }) {
                            LabeledContent("Email", value: card.email)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Section(header: Text("Company Info")) {
                if isEditing {
                    TextField("Company Name", text: $card.companyName)
                    TextField("Department", text: $card.department)
                    TextField("Address", text: $card.address)
                    TextField("Website", text: $card.website)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                } else {
                    LabeledContent("Company", value: card.companyName)
                    LabeledContent("Department", value: card.department)
                    if !card.address.isEmpty {
                        LabeledContent("Address", value: card.address)
                    }
                    if !card.website.isEmpty, let url = URL(string: card.website.hasPrefix("http") ? card.website : "https://\(card.website)") {
                        Link(destination: url) {
                            LabeledContent("Website", value: card.website)
                        }
                    } else if !card.website.isEmpty {
                         LabeledContent("Website", value: card.website)
                    }
                }
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
                        if isEditing {
                            TextField("Industry", text: $card.industry)
                        } else {
                            Text(card.industry)
                        }
                    }
                }
                
                if !card.companyDescription.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Company Description").font(.caption).foregroundColor(.secondary)
                        if isEditing {
                            TextEditor(text: $card.companyDescription).frame(height: 100)
                        } else {
                            Text(card.companyDescription)
                        }
                    }
                }
                
                if !card.personRoleDescription.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Sales Analysis").font(.caption).foregroundColor(.secondary)
                        if isEditing {
                             TextEditor(text: $card.personRoleDescription).frame(height: 200)
                        } else {
                            MarkdownView(text: card.personRoleDescription)
                        }
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
            }
        }
        .confirmationDialog("Send Email", isPresented: $showEmailOptions, titleVisibility: .visible) {
            Button("Mail App") {
                openMailApp(scheme: "mailto:")
            }
            Button("Gmail") {
                openMailApp(scheme: "googlegmail://")
            }
            Button("Outlook") {
                openMailApp(scheme: "ms-outlook://")
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private func openMailApp(scheme: String) {
        let email = card.email
        let urlString: String
        if scheme == "mailto:" {
            urlString = "mailto:\(email)"
        } else if scheme == "googlegmail://" {
            urlString = "googlegmail://co?to=\(email)"
        } else if scheme == "ms-outlook://" {
            urlString = "ms-outlook://compose?to=\(email)"
        } else {
            return
        }
        
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if scheme != "mailto:" {
            // Fallback to default mail if specific app not found, or alert execution
            if let mailtoUrl = URL(string: "mailto:\(email)") {
                UIApplication.shared.open(mailtoUrl)
            }
        }
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
                website: card.website,
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
