import SwiftUI
import SwiftData
import Charts

struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CardSyncService.self) private var cardSyncService
    @Environment(AuthService.self) private var authService
    @Query(sort: \BusinessCard.createdAt, order: .reverse) private var cards: [BusinessCard]
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var inputImage: UIImage?
    @State private var isProcessingImage = false
    @State private var navigationPath = NavigationPath()
    @State private var geminiService = GeminiService()
    @State private var hasSyncedOnAppear = false
    
    @State private var searchText = ""
    
    var filteredCards: [BusinessCard] {
        if searchText.isEmpty {
            return cards
        } else {
            return cards.filter { card in
                card.name.localizedCaseInsensitiveContains(searchText) ||
                card.companyName.localizedCaseInsensitiveContains(searchText) ||
                card.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var industryData: [(industry: String, count: Int)] {
        let grouped = Dictionary(grouping: cards, by: { $0.industry.isEmpty ? "Unknown" : $0.industry })
        return grouped.map { (key, value) in
            (industry: key, count: value.count)
        }.sorted { $0.count > $1.count }
    }
    
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                List {
                    // Header Section (Chart or Empty State)
                    Section {
                        if !industryData.isEmpty {
                            Chart(industryData, id: \.industry) { item in
                                SectorMark(
                                    angle: .value("Count", item.count),
                                    innerRadius: .ratio(0.5)
                                )
                                .foregroundStyle(by: .value("Industry", item.industry))
                            }
                            .frame(height: 200)
                            .padding(.vertical)
                        } else {
                            Text("No cards yet. Tap the camera button to add one!")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    
                    // Cards List Section
                    Section("Your Cards") {
                        ForEach(filteredCards) { card in
                            NavigationLink(value: card) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(card.name.isEmpty ? "Unknown Name" : card.name)
                                            .font(.headline)
                                        Text(card.companyName.isEmpty ? "Unknown Company" : card.companyName)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        if !card.industry.isEmpty {
                                            Text(card.industry)
                                                .font(.caption)
                                                .padding(4)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Cloud sync indicator (only show when logged in)
                                    if authService.isLoggedIn {
                                        Image(systemName: card.isSyncedToCloud ? "checkmark.icloud.fill" : "icloud")
                                            .foregroundColor(card.isSyncedToCloud ? .green : .gray)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
                .searchable(text: $searchText, prompt: "Search cards")
                
                // Floating Action Button (Centered)
                VStack {
                    Spacer()
                    Menu {
                        Button(action: { showingCamera = true }) {
                            Label("Camera", systemImage: "camera")
                        }
                        Button(action: { showingImagePicker = true }) {
                            Label("Photo Library", systemImage: "photo")
                        }
                    } label: {
                        Image(systemName: "camera.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Business Cards")
            .navigationDestination(for: BusinessCard.self) { card in
                CardDetailView(card: card)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $inputImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(image: $inputImage, sourceType: .camera)
            }
            .onChange(of: inputImage) { oldValue, newValue in
                if let image = newValue {
                    processImage(image)
                }
            }
            .overlay {
                if isProcessingImage {
                    ZStack {
                        Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Analyzing Card...")
                                .foregroundColor(.white)
                                .padding(.top)
                        }
                    }
                }
            }
            .alert("Card Processing", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                // Sync from cloud when logged in and first appear
                if authService.isLoggedIn && !hasSyncedOnAppear {
                    hasSyncedOnAppear = true
                    Task {
                        await syncFromCloud()
                    }
                }
            }
            .onChange(of: authService.isLoggedIn) { _, isLoggedIn in
                // Sync when user logs in
                if isLoggedIn && !hasSyncedOnAppear {
                    hasSyncedOnAppear = true
                    Task {
                        await syncFromCloud()
                    }
                }
            }
            .toolbar {
                if authService.isLoggedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            Task {
                                await syncAllToCloud()
                            }
                        }) {
                            if cardSyncService.isSyncing {
                                ProgressView()
                                    .tint(.blue)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath.icloud")
                            }
                        }
                        .disabled(cardSyncService.isSyncing)
                    }
                }
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        // Capture card IDs before deletion for cloud sync
        let cardsToDelete = offsets.map { cards[$0] }
        
        withAnimation {
            for card in cardsToDelete {
                modelContext.delete(card)
            }
        }
        
        // Also delete from cloud if logged in
        if authService.isLoggedIn {
            Task {
                for card in cardsToDelete {
                    try? await cardSyncService.deleteCard(card.id)
                }
            }
        }
    }
    
    private func processImage(_ image: UIImage) {
        isProcessingImage = true
        Task {
            defer {
                Task { @MainActor in
                    isProcessingImage = false
                    inputImage = nil
                    print("Finished processing image. Reset state.")
                }
            }
            
            do {
                print("Starting OCR extraction...")
                let drafts = try await geminiService.extractCardInfo(from: image)
                print("OCR extracted \(drafts.count) drafts")
                
                await MainActor.run {
                    if drafts.isEmpty {
                        alertMessage = "No business cards found in the image."
                        showingAlert = true
                    }
                }
                
                for draft in drafts {
                    let name = draft.name ?? ""
                    let company = draft.companyName ?? ""
                    
                    // Check for duplicates on MainActor to ensure thread safety with @Query
                    let isDuplicate = await MainActor.run {
                        return cards.contains { card in
                            return card.name.localizedCaseInsensitiveContains(name) &&
                                   card.companyName.localizedCaseInsensitiveContains(company)
                        }
                    }
                    
                    if isDuplicate {
                        print("Duplicate card found for \(name) at \(company). Skipping.")
                        await MainActor.run {
                            alertMessage = "Duplicate card found for \(name). It was not added."
                            showingAlert = true
                        }
                        continue
                    }
                    
                    // AI Enrichment
                    print("Enriching card for \(name)...")
                    let (companyDesc, roleDesc, industry) = try await geminiService.enrichCardInfo(card: draft)
                    print("Enrichment complete.")
                    
                    await MainActor.run {
                        print("Inserting new card into context...")
                        let newCard = BusinessCard(
                            name: name,
                            title: draft.title ?? "",
                            phone: draft.phone ?? "",
                            email: draft.email ?? "",
                            website: draft.website ?? "", // Use draft info
                            companyName: company,
                            department: draft.department ?? "",
                            address: draft.address ?? "",
                            companyDescription: companyDesc,
                            personRoleDescription: roleDesc,
                            industry: industry,
                            imageData: image.jpegData(compressionQuality: 0.8)
                        )
                        modelContext.insert(newCard)
                        do {
                            try modelContext.save()
                            print("Context saved successfully.")
                            
                            // Upload to cloud if logged in
                            if authService.isLoggedIn {
                                Task {
                                    do {
                                        try await cardSyncService.uploadCard(newCard)
                                        await MainActor.run {
                                            newCard.isSyncedToCloud = true
                                            try? modelContext.save()
                                        }
                                    } catch {
                                        print("Failed to sync new card: \(error)")
                                    }
                                }
                            }
                        } catch {
                            print("Failed to save context: \(error)")
                        }
                    }
                }
                
            } catch {
                print("Error processing image: \(error)")
                await MainActor.run {
                    alertMessage = "Error processing card: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    // MARK: - Cloud Sync Functions
    
    private func syncFromCloud() async {
        do {
            let cloudCards = try await cardSyncService.fetchAllCards()
            let existingIds = Set(cards.map { $0.id })
            
            await MainActor.run {
                var importedCount = 0
                for cloudCard in cloudCards {
                    if !existingIds.contains(cloudCard.id) {
                        // Cards from cloud are already synced
                        cloudCard.isSyncedToCloud = true
                        modelContext.insert(cloudCard)
                        importedCount += 1
                    }
                }
                try? modelContext.save()
                print("Synced \(cloudCards.count) cards from cloud, imported \(importedCount) new cards")
                
                if importedCount > 0 {
                    alertMessage = "Imported \(importedCount) card(s) from cloud"
                    showingAlert = true
                }
            }
        } catch {
            print("Error syncing from cloud: \(error)")
            await MainActor.run {
                alertMessage = "Failed to sync from cloud: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func syncAllToCloud() async {
        var syncedCount = 0
        var failedCount = 0
        
        for card in cards {
            do {
                try await cardSyncService.uploadCard(card)
                await MainActor.run {
                    card.isSyncedToCloud = true
                }
                syncedCount += 1
            } catch {
                failedCount += 1
                print("Failed to sync card \(card.name): \(error)")
            }
        }
        
        await MainActor.run {
            try? modelContext.save()
            if failedCount == 0 {
                alertMessage = "Successfully synced \(syncedCount) card(s) to cloud"
            } else {
                alertMessage = "Synced \(syncedCount) card(s), \(failedCount) failed"
            }
            showingAlert = true
        }
        print("All cards synced to cloud: \(syncedCount) success, \(failedCount) failed")
    }
}
