import Foundation
import SwiftData

@Model
class BusinessCard {
    var id: UUID
    var name: String
    var title: String
    var phone: String
    var email: String
    var website: String
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
         website: String = "",
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
        self.website = website
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
    var website: String?
    var companyName: String?
    var department: String?
    var address: String?
    
    enum CodingKeys: String, CodingKey {
        case name, title, phone, email, website, companyName, department, address
    }
    
    init(name: String? = nil, title: String? = nil, phone: String? = nil, email: String? = nil, website: String? = nil, companyName: String? = nil, department: String? = nil, address: String? = nil) {
        self.name = name
        self.title = title
        self.phone = phone
        self.email = email
        self.website = website
        self.companyName = companyName
        self.department = department
        self.address = address
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decodeIfPresent(String.self, forKey: .name)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        
        // Custom decoding for phone: try String, then [String]
        if let phoneString = try? container.decode(String.self, forKey: .phone) {
            phone = phoneString
        } else if let phoneArray = try? container.decode([String].self, forKey: .phone) {
            phone = phoneArray.first
        } else {
            phone = nil
        }
        
        // Custom decoding for email: try String, then [String]
        if let emailString = try? container.decode(String.self, forKey: .email) {
            email = emailString
        } else if let emailArray = try? container.decode([String].self, forKey: .email) {
            email = emailArray.first
        } else {
            email = nil
        }
        
        website = try container.decodeIfPresent(String.self, forKey: .website)
        companyName = try container.decodeIfPresent(String.self, forKey: .companyName)
        department = try container.decodeIfPresent(String.self, forKey: .department)
        address = try container.decodeIfPresent(String.self, forKey: .address)
    }
}
