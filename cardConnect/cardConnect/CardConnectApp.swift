import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Firebase is configured in CardConnectApp.init()
        return true
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct CardConnectApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @State private var authService: AuthService
    @State private var subscriptionService: SubscriptionService
    @State private var cardSyncService: CardSyncService
    
    init() {
        // Configure Firebase before initializing any Firebase-dependent services
        FirebaseApp.configure()
        
        // Now it's safe to initialize AuthService and SubscriptionService
        _authService = State(initialValue: AuthService())
        _subscriptionService = State(initialValue: SubscriptionService())
        _cardSyncService = State(initialValue: CardSyncService())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(subscriptionService)
                .environment(cardSyncService)
        }
        .modelContainer(for: BusinessCard.self)
    }
}
