import Foundation
import UIKit
import FirebaseFirestore
import FirebaseAuth

/// Service to sync business cards with Firebase Firestore
/// Cards are stored under: /users/{userId}/cards/{cardId}
@Observable
class CardSyncService {
    private let db = Firestore.firestore()
    
    var isSyncing: Bool = false
    var lastSyncDate: Date?
    var errorMessage: String?
    
    // MARK: - Firestore Document Structure
    
    private struct FirestoreCard: Codable {
        let id: String
        let name: String
        let title: String
        let phone: String
        let email: String
        let companyName: String
        let department: String
        let address: String
        let companyDescription: String
        let personRoleDescription: String
        let industry: String
        let imageDataBase64: String?
        let createdAt: Date
        let updatedAt: Date
    }
    
    // MARK: - Get Current User ID
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private func cardsCollection() -> CollectionReference? {
        guard let userId = currentUserId else { return nil }
        return db.collection("users").document(userId).collection("cards")
    }
    
    // MARK: - Image Compression Helper
    
    /// Compress image data to fit within Firestore's 1MB limit per field
    /// Base64 encoding increases size by ~33%, so we target ~700KB max
    private func compressImageForFirestore(_ imageData: Data?) -> String? {
        guard let data = imageData else { return nil }
        
        // If already small enough, use it directly
        let maxSize = 700_000 // 700KB leaves room for base64 overhead
        if data.count <= maxSize {
            return data.base64EncodedString()
        }
        
        // Try to compress the image with decreasing quality
        guard let uiImage = UIImage(data: data) else { return nil }
        
        var quality: CGFloat = 0.5
        var compressedData = uiImage.jpegData(compressionQuality: quality)
        
        while let compressed = compressedData, compressed.count > maxSize && quality > 0.1 {
            quality -= 0.1
            compressedData = uiImage.jpegData(compressionQuality: quality)
        }
        
        // If still too large after compression, resize the image
        if let compressed = compressedData, compressed.count > maxSize {
            let scale = sqrt(Double(maxSize) / Double(compressed.count))
            let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let resized = resizedImage, let resizedData = resized.jpegData(compressionQuality: 0.5) {
                return resizedData.base64EncodedString()
            }
        }
        
        return compressedData?.base64EncodedString()
    }
    
    // MARK: - Upload Card to Firestore
    
    func uploadCard(_ card: BusinessCard) async throws {
        guard let collection = cardsCollection() else {
            throw SyncError.notAuthenticated
        }
        
        // Compress image to fit Firestore limits
        let imageBase64: String? = compressImageForFirestore(card.imageData)
        
        let firestoreCard = FirestoreCard(
            id: card.id.uuidString,
            name: card.name,
            title: card.title,
            phone: card.phone,
            email: card.email,
            companyName: card.companyName,
            department: card.department,
            address: card.address,
            companyDescription: card.companyDescription,
            personRoleDescription: card.personRoleDescription,
            industry: card.industry,
            imageDataBase64: imageBase64,
            createdAt: card.createdAt,
            updatedAt: Date()
        )
        
        try collection.document(card.id.uuidString).setData(from: firestoreCard)
        print("Card uploaded to Firestore: \(card.name)")
    }
    
    // MARK: - Delete Card from Firestore
    
    func deleteCard(_ cardId: UUID) async throws {
        guard let collection = cardsCollection() else {
            throw SyncError.notAuthenticated
        }
        
        try await collection.document(cardId.uuidString).delete()
        print("Card deleted from Firestore: \(cardId)")
    }
    
    // MARK: - Fetch All Cards from Firestore
    
    func fetchAllCards() async throws -> [BusinessCard] {
        guard let collection = cardsCollection() else {
            throw SyncError.notAuthenticated
        }
        
        let snapshot = try await collection.getDocuments()
        var cards: [BusinessCard] = []
        
        for document in snapshot.documents {
            do {
                let firestoreCard = try document.data(as: FirestoreCard.self)
                let card = BusinessCard(
                    id: UUID(uuidString: firestoreCard.id) ?? UUID(),
                    name: firestoreCard.name,
                    title: firestoreCard.title,
                    phone: firestoreCard.phone,
                    email: firestoreCard.email,
                    companyName: firestoreCard.companyName,
                    department: firestoreCard.department,
                    address: firestoreCard.address,
                    companyDescription: firestoreCard.companyDescription,
                    personRoleDescription: firestoreCard.personRoleDescription,
                    industry: firestoreCard.industry,
                    imageData: firestoreCard.imageDataBase64.flatMap { Data(base64Encoded: $0) },
                    createdAt: firestoreCard.createdAt
                )
                cards.append(card)
            } catch {
                print("Error decoding card from Firestore: \(error)")
            }
        }
        
        print("Fetched \(cards.count) cards from Firestore")
        return cards
    }
    
    // MARK: - Sync Local Cards to Cloud
    
    /// Upload all local cards to Firestore (for backup/initial sync)
    func syncLocalToCloud(cards: [BusinessCard]) async {
        guard currentUserId != nil else {
            errorMessage = "Not logged in"
            return
        }
        
        isSyncing = true
        errorMessage = nil
        
        do {
            for card in cards {
                try await uploadCard(card)
            }
            lastSyncDate = Date()
            print("All cards synced to cloud")
        } catch {
            errorMessage = error.localizedDescription
            print("Error syncing to cloud: \(error)")
        }
        
        isSyncing = false
    }
    
    // MARK: - Sync Cloud Cards to Local
    
    /// Fetch cards from Firestore and merge with local (used on app launch after login)
    func syncCloudToLocal(modelContext: Any, existingCards: [BusinessCard]) async {
        guard currentUserId != nil else {
            errorMessage = "Not logged in"
            return
        }
        
        isSyncing = true
        errorMessage = nil
        
        do {
            let cloudCards = try await fetchAllCards()
            let existingIds = Set(existingCards.map { $0.id })
            
            // Import cards from cloud that don't exist locally
            // Note: We need to use SwiftData's ModelContext, but we can't import SwiftData here
            // This will be handled in the view layer
            
            lastSyncDate = Date()
            print("Cloud sync completed. Found \(cloudCards.count) cards in cloud, \(existingCards.count) cards locally")
        } catch {
            errorMessage = error.localizedDescription
            print("Error syncing from cloud: \(error)")
        }
        
        isSyncing = false
    }
    
    // MARK: - Errors
    
    enum SyncError: LocalizedError {
        case notAuthenticated
        case uploadFailed
        case fetchFailed
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "User is not authenticated. Please sign in to sync cards."
            case .uploadFailed:
                return "Failed to upload card to cloud."
            case .fetchFailed:
                return "Failed to fetch cards from cloud."
            }
        }
    }
}
