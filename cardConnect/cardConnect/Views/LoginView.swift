import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    
                    Text("CardConnect")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Organize your business cards with AI")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                // Sign In Buttons
                VStack(spacing: 16) {
                    // Apple Sign In
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { _ in
                        Task {
                            await authService.signInWithApple()
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(25)
                    
                    // Google Sign In
                    Button(action: {
                        Task {
                            await authService.signInWithGoogle()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text("Sign in with Google")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(25)
                    }
                    
                    if authService.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    
                    if let error = authService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                    .frame(height: 60)
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthService())
}
