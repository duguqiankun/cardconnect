import SwiftUI

struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var showSubscription = false
    
    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                Section {
                    if let user = authService.currentUser {
                        HStack(spacing: 16) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 60, height: 60)
                                
                                Text(user.displayName?.prefix(1).uppercased() ?? user.email?.prefix(1).uppercased() ?? "?")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if let name = user.displayName {
                                    Text(name)
                                        .font(.headline)
                                }
                                if let email = user.email {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Subscription Section
                Section(header: Text("Subscription")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(subscriptionService.hasActiveSubscription ? "Pro" : "Free")
                                .font(.headline)
                            Text(subscriptionService.hasActiveSubscription ? "All features unlocked" : "Basic features")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if subscriptionService.hasActiveSubscription {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    if !subscriptionService.hasActiveSubscription {
                        Button(action: {
                            showSubscription = true
                        }) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("Upgrade to Pro")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                
                // Account Actions
                Section {
                    Button(role: .destructive, action: {
                        authService.signOut()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthService())
        .environment(SubscriptionService())
}
