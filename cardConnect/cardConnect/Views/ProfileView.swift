import SwiftUI

struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(CardSyncService.self) private var cardSyncService
    @Environment(\.modelContext) private var modelContext
    @State private var showSubscription = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false


    
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
                
                // Danger Zone
                Section {
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        if isDeleting {
                            HStack {
                                Text("Deleting Account...")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Account")
                            }
                        }
                    }
                    .disabled(isDeleting)
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action is permanent and will delete all your synced business cards. This cannot be undone.")
            }

        }
    }
    
    private func deleteAccount() {
        isDeleting = true
        
        Task {
            do {
                // 1. Delete data from Firestore
                try await cardSyncService.deleteAllUserData()
                
                // 2. Delete Auth Account
                try await authService.deleteAccount()
                
                // 3. Clear local data (SwiftData)
                try? modelContext.delete(model: BusinessCard.self)
                
                // 4. Reset UI state (handled by auth state listener, but good to be explicit)
                isDeleting = false
            } catch {
                print("Error deleting account: \(error)")
                isDeleting = false
                // Ideally show an error alert here
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthService())

        .environment(SubscriptionService())
}
