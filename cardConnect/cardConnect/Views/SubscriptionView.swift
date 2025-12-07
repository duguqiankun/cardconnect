import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Upgrade to Pro")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Unlock all premium features")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "infinity", title: "Unlimited Cards", description: "Store unlimited business cards")
                        FeatureRow(icon: "cloud.fill", title: "Cloud Sync", description: "Sync across all your devices")
                        FeatureRow(icon: "sparkles", title: "Advanced AI", description: "Priority AI processing")
                        FeatureRow(icon: "crown.fill", title: "Premium Support", description: "24/7 priority support")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Products
                    if subscriptionService.isLoading {
                        ProgressView()
                    } else if let product = subscriptionService.products.first {
                        VStack(spacing: 16) {
                            // Free trial banner
                            if let subscription = product.subscription,
                               let introOffer = subscription.introductoryOffer {
                                HStack {
                                    Image(systemName: "gift.fill")
                                        .foregroundColor(.green)
                                    Text("1 Month Free Trial")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(20)
                            }
                            
                            // Subscribe button
                            Button(action: {
                                Task {
                                    await subscriptionService.purchase(product)
                                    if subscriptionService.hasActiveSubscription {
                                        dismiss()
                                    }
                                }
                            }) {
                                VStack(spacing: 6) {
                                    if let subscription = product.subscription,
                                       let introOffer = subscription.introductoryOffer {
                                        Text("Start Free Trial")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                        Text("Then \(product.displayPrice)/month")
                                            .font(.subheadline)
                                            .opacity(0.9)
                                    } else {
                                        Text("Subscribe for \(product.displayPrice)/month")
                                            .fontWeight(.semibold)
                                    }
                                    Text("Cancel anytime")
                                        .font(.caption)
                                        .opacity(0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            .padding(.horizontal)
                            
                            // Trial terms
                            Text("After your free trial, you'll be charged \(product.displayPrice) per month. Cancel anytime in Settings.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    } else {
                        Text("No products available")
                            .foregroundColor(.secondary)
                    }
                    
                    // Restore
                    Button("Restore Purchases") {
                        Task {
                            await subscriptionService.restorePurchases()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                    if let error = subscriptionService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 32)
            
            VStack(alignment: .leading) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SubscriptionView()
        .environment(SubscriptionService())
}
