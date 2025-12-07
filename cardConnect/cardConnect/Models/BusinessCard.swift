import Foundation
import SwiftData

@Model
class BusinessCard {
    var id: UUID
    var name: String
    var title: String
    var phone: String
    var email: String
    var companyName: String
    var department: String
    var address: String
    var companyDescription: String
    var personRoleDescription: String
    var industry: String
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date
    var isSyncedToCloud: Bool
    
    init(id: UUID = UUID(), 
         name: String = "", 
         title: String = "", 
         phone: String = "", 
         email: String = "", 
         companyName: String = "", 
         department: String = "", 
         address: String = "", 
         companyDescription: String = "", 
         personRoleDescription: String = "", 
         industry: String = "",
         imageData: Data? = nil,
         createdAt: Date = Date(),
         isSyncedToCloud: Bool = false) {
        self.id = id
        self.name = name
        self.title = title
        self.phone = phone
        self.email = email
        self.companyName = companyName
        self.department = department
        self.address = address
        self.companyDescription = companyDescription
        self.personRoleDescription = personRoleDescription
        self.industry = industry
        self.imageData = imageData
        self.createdAt = createdAt
        self.isSyncedToCloud = isSyncedToCloud
    }
}

// Helper struct for Gemini parsing
struct BusinessCardDraft: Codable {
    var name: String?
    var title: String?
    var phone: String?
    var email: String?
    var companyName: String?
    var department: String?
    var address: String?
}
