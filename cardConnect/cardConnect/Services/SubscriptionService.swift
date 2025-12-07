import Foundation
import StoreKit

@Observable
class SubscriptionService {
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoading: Bool = false
    var errorMessage: String?
    var subscriptionExpirationDate: Date?
    var isInTrialPeriod: Bool = false
    
    // Product ID must match App Store Connect exactly
    // Format: com.{teamId or bundleId prefix}.{appname}.{productname}
    private let productIDs = ["qianliu.cardConnect.monthly.pro"]
    
    var hasActiveSubscription: Bool {
        !purchasedProductIDs.isEmpty
    }
    
    init() {
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
        
        // Listen for transaction updates
        Task {
            for await result in Transaction.updates {
                await handleTransaction(result)
            }
        }
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                await handleTransaction(verification)
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending approval"
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        isLoading = true
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - Handle Transaction
    
    private func handleTransaction(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            return
        }
        
        if transaction.revocationDate == nil {
            purchasedProductIDs.insert(transaction.productID)
            subscriptionExpirationDate = transaction.expirationDate
            
            // Check if user is in trial period
            if let offerType = transaction.offerType {
                isInTrialPeriod = (offerType == .introductory)
            }
        } else {
            purchasedProductIDs.remove(transaction.productID)
            subscriptionExpirationDate = nil
            isInTrialPeriod = false
        }
        
        await transaction.finish()
    }
    
    // MARK: - Update Purchased Products
    
    private func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.revocationDate == nil {
                purchasedProductIDs.insert(transaction.productID)
                subscriptionExpirationDate = transaction.expirationDate
                
                // Check if user is in trial period
                if let offerType = transaction.offerType {
                    isInTrialPeriod = (offerType == .introductory)
                }
            } else {
                purchasedProductIDs.remove(transaction.productID)
            }
        }
    }
}
