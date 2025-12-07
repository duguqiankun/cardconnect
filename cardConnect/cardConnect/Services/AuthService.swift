import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@Observable
class AuthService: NSObject {
    var currentUser: User?
    var isLoggedIn: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    
    // For Apple Sign In
    private var currentNonce: String?
    
    override init() {
        super.init()
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            self?.isLoggedIn = user != nil
        }
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            self.errorMessage = "Firebase not configured"
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            self.errorMessage = "No root view controller"
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                self.errorMessage = "No ID token"
                self.isLoading = false
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            try await Auth.auth().signIn(with: credential)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isLoading = false
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple() async {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.performRequests()
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Helper Functions
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

// MARK: - Apple Sign In Delegate

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }
        
        guard let nonce = currentNonce else {
            errorMessage = "Invalid state: nonce not set"
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            errorMessage = "Unable to fetch identity token"
            return
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            errorMessage = "Unable to serialize token"
            return
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        Task {
            do {
                try await Auth.auth().signIn(with: credential)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}
