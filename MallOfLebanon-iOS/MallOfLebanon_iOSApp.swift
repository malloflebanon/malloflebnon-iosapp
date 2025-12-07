import SwiftUI

@main
struct MallOfLebanon_iOSApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var cartManager = CartManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(cartManager)
        }
    }
}