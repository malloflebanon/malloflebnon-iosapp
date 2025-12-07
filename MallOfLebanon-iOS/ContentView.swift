import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager()

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainAppView()
                    .environmentObject(authManager)
            } else {
                WelcomeView()
                    .environmentObject(authManager)
            }
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingLogin = false
    @State private var showingRegister = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    VStack(spacing: 8) {
                        Text("Mall Of Lebanon")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("Your shopping destination")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 16) {
                    Button(action: {
                        showingLogin = true
                    }) {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        showingRegister = true
                    }) {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                    }

                    Button(action: {
                        // Demo mode - skip authentication for testing UI
                        authManager.isAuthenticated = true
                    }) {
                        Text("Continue as Guest (Demo)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color.blue.opacity(0.05)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .sheet(isPresented: $showingLogin) {
            LoginView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showingRegister) {
            RegisterView()
                .environmentObject(authManager)
        }
    }
}

// MARK: - Main App View (after authentication)
struct MainAppView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var cartManager: CartManager

    var body: some View {
        TabView {
            HomeView()
                .environmentObject(cartManager)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

            ProductListView()
                .environmentObject(cartManager)
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Products")
                }

            Text("Search")
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }

            CartView()
                .environmentObject(cartManager)
                .tabItem {
                    ZStack {
                        Image(systemName: "cart.fill")
                        if cartManager.itemCount > 0 {
                            Text("\(cartManager.itemCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                    Text("Cart")
                }

            AccountView()
                .environmentObject(authManager)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Account")
                }
        }
        .accentColor(.blue)
    }
}

// MARK: - Home View
struct HomeView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack {
                    Text("Welcome to Mall Of Lebanon!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding()

                    Text("🛍️ Your shopping destination")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding()

                    VStack(spacing: 16) {
                        Text("Featured Categories")
                            .font(.headline)
                            .padding(.top)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            SimpleCategoryCard(title: "Electronics", icon: "laptopcomputer")
                            SimpleCategoryCard(title: "Fashion", icon: "tshirt")
                            SimpleCategoryCard(title: "Home & Garden", icon: "house")
                            SimpleCategoryCard(title: "Sports", icon: "sportscourt")
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Mall Of Lebanon")
        }
    }
}


// MARK: - Account View
struct AccountView: View {
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    if let user = authManager.currentUser {
                        Text("\(user.firstName) \(user.lastName)")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Guest User")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("guest@malloflebanon.com")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 40)

                VStack(spacing: 12) {
                    AccountMenuRow(icon: "bag", title: "My Orders", action: {})
                    AccountMenuRow(icon: "heart", title: "Wishlist", action: {})
                    AccountMenuRow(icon: "person", title: "Profile Settings", action: {})
                    AccountMenuRow(icon: "bell", title: "Notifications", action: {})
                    AccountMenuRow(icon: "questionmark.circle", title: "Help & Support", action: {})
                }
                .padding(.horizontal)

                Spacer()

                Button(action: {
                    authManager.logout()
                }) {
                    Text("Sign Out")
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red, lineWidth: 2)
                        )
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationTitle("Account")
        }
    }
}

struct AccountMenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct SimpleCategoryCard: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.blue)

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}