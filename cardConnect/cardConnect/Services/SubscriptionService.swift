import Foundation
import SwiftUI

@Observable
class SubscriptionService {
    var isLoading: Bool = false
    var errorMessage: String?
    var isPro: Bool = false
    
    private let proKey = "is_pro_user"
    
    var hasActiveSubscription: Bool {
        isPro
    }
    
    init() {
        // Load status from UserDefaults
        self.isPro = UserDefaults.standard.bool(forKey: proKey)
    }
    
    // MARK: - Mock Purchase
    
    func purchase() async {
        isLoading = true
        errorMessage = nil
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        
        // Success
        isPro = true
        UserDefaults.standard.set(true, forKey: proKey)
        
        isLoading = false
    }
    
    // MARK: - Mock Restore
    
    func restorePurchases() async {
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        
        // Just check local storage again
        self.isPro = UserDefaults.standard.bool(forKey: proKey)
        
        isLoading = false
    }
}
