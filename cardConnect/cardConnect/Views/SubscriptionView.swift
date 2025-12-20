import SwiftUI

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
                    
                    // Action Button
                    if subscriptionService.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        Button(action: {
                            Task {
                                await subscriptionService.purchase()
                                if subscriptionService.hasActiveSubscription {
                                    dismiss()
                                }
                            }
                        }) {
                            Text("Unlock Pro (Free)")
                                .font(.headline)
                                .fontWeight(.bold)
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
