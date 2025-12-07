import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var authService
    
    var body: some View {
        Group {
            if authService.isLoggedIn {
                TabView {
                    CardListView()
                        .tabItem {
                            Label("Cards", systemImage: "person.text.rectangle")
                        }
                    
                    AnalysisView()
                        .tabItem {
                            Label("Analysis", systemImage: "sparkles.rectangle.stack")
                        }
                    
                    ProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "person.circle")
                        }
                }
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthService())
        .environment(SubscriptionService())
}
