import SwiftUI
import UIKit
import Combine

// MARK: - Image Caching Implementation
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        cache.countLimit = 500  // Limit cache to 500 images
        cache.totalCostLimit = 100 * 1024 * 1024  // 100MB memory limit
    }

    func image(for url: URL) -> AnyPublisher<UIImage?, Never> {
        let key = NSString(string: url.absoluteString)

        // Check cache first
        if let cachedImage = cache.object(forKey: key) {
            return Just(cachedImage)
                .eraseToAnyPublisher()
        }

        // Download if not in cache with timeout
        return session.dataTaskPublisher(for: url)
            .timeout(.seconds(30), scheduler: DispatchQueue.global(qos: .userInitiated))
            .retry(2)
            .map(\.data)
            .compactMap { data in
                if let image = UIImage(data: data) {
                    self.cache.setObject(image, forKey: key)
                    return image
                }
                return nil
            }
            .catch { error in
                print("📷 Image loading failed for \(url): \(error.localizedDescription)")
                return Just(nil as UIImage?)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func preloadImage(url: URL) {
        image(for: url)
            .sink { _ in }
            .store(in: &cancellables)
    }
}

struct CachedImageView: View {
    let url: URL?
    let placeholder: AnyView
    let failureView: AnyView

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var cancellable: AnyCancellable?
    @State private var loadedURL: URL?

    init(
        url: URL?,
        @ViewBuilder placeholder: () -> some View = { Color.gray.opacity(0.3) },
        @ViewBuilder failureView: () -> some View = {
            Image(systemName: "photo")
                .foregroundColor(.gray)
        }
    ) {
        self.url = url
        self.placeholder = AnyView(placeholder())
        self.failureView = AnyView(failureView())
    }

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else if isLoading {
                placeholder
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            } else {
                failureView
            }
        }
        .onAppear {
            loadImage()
        }
        .onDisappear {
            cancellable?.cancel()
        }
        .onChange(of: url) { newURL in
            if newURL != loadedURL {
                image = nil
                loadedURL = newURL
                loadImage()
            }
        }
    }

    private func loadImage() {
        guard let url = url, image == nil else { return }

        isLoading = true
        cancellable = ImageCache.shared.image(for: url)
            .sink { loadedImage in
                self.isLoading = false
                self.image = loadedImage
            }
    }
}

// Convenience extension for Product images
extension CachedImageView {
    static func productImage(url: String?) -> CachedImageView {
        CachedImageView(
            url: URL(string: url ?? ""),
            placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
            },
            failureView: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
        )
    }
}

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
    @StateObject private var viewModel = ProductListViewModel()
    @EnvironmentObject var cartManager: CartManager

    @State private var showingSortOptions = false
    @State private var showingFilters = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {

                    // Auction Section - positioned above raffles
                    AuctionSection()

                    // Raffle Section - positioned at the top
                    RaffleSection()

                    // Homepage Sections Grid
                    if !viewModel.homepageSections.isEmpty {
                        homepageSectionsView
                    }


                    // Categories Horizontal Scroll
                    if !viewModel.categories.isEmpty {
                        categoriesSection
                    }

                    // Products Grid
                    productsSection

                    // Loading indicator at bottom for infinite scroll
                    if viewModel.isLoading && viewModel.hasMorePages && !viewModel.products.isEmpty {
                        ProgressView("Loading more products...")
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Mall Of Lebanon")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: filterButton,
                trailing: sortButton
            )
            .refreshable {
                viewModel.refreshProducts()
            }
        }
        .onAppear {
            print("🚀 HomeView onAppear - Loading initial data without clearing filters")
            // Only load initial data if we don't have categories or products yet
            // This preserves any existing category filters
            if viewModel.categories.isEmpty {
                viewModel.loadCategories()
                viewModel.loadHomepageSections()
            }
            if viewModel.products.isEmpty {
                viewModel.loadProducts(resetResults: true)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil && viewModel.products.isEmpty && !viewModel.isLoading)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showingSortOptions) {
            sortOptionsSheet
        }
        .sheet(isPresented: $showingFilters) {
            filtersSheet
        }
    }

    private var welcomeSection: some View {
        VStack(spacing: 12) {
            Text("Welcome to Mall Of Lebanon!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("🛍️ Your shopping destination")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search products...", text: $viewModel.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.vertical, 8)
    }


    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Categories")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    // "All" category button
                    CategoryCard(
                        category: nil,
                        isSelected: viewModel.selectedCategory == nil
                    ) {
                        print("🏷️ HomeView: 'All' category tapped")
                        viewModel.filterByCategory(nil)
                    }
                    ForEach(viewModel.categories.prefix(9)) { category in
                        CategoryCard(
                            category: category,
                            isSelected: viewModel.selectedCategory?.id == category.id
                        ) {
                            print("🏷️ HomeView: '\(category.name)' category tapped (ID: \(category.id))")
                            viewModel.filterByCategory(category)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var homepageSectionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Shop by Category")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)

            // Grid of Section Cards
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(viewModel.homepageSections) { section in
                    if let category = viewModel.categories.first(where: { $0.id == section.categoryIdentifier }) {
                        NavigationLink(
                            destination: CategoryProductsScreen(
                                category: category,
                                sectionTitle: section.title,
                                cartManager: cartManager
                            )
                        ) {
                            SectionCardViewForNav(section: section)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Button(action: {
                            print("⚠️ No category found for: \(section.categoryIdentifier)")
                            // Handle sections without matching categories
                        }) {
                            SectionCardView(section: section) {
                                print("🏷️ Section tapped but no category: \(section.title)")
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding([.top, .bottom], 8)
    }

    // MARK: - Section Card Views
    private struct SectionCardViewForNav: View {
        let section: HomepageSection

        private let columns = [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Section Title
                Text(section.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)

                // Product Preview Grid
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(section.previewImages.enumerated()), id: \.offset) { index, imageUrl in
                        CachedImageView(
                            url: URL(string: imageUrl),
                            placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    )
                            },
                            failureView: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    )
                            }
                        )
                        .frame(height: 60)
                        .cornerRadius(6)
                        .clipped()
                    }

                    // Fill remaining slots if less than 4 images
                    ForEach(section.previewImages.count..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 60)
                            .cornerRadius(6)
                    }
                }
                .frame(height: 124) // 2 rows * 60px + 4px spacing

                Spacer()

                // Shop Now Link
                HStack {
                    Text("Shop now")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.blue)

                    Spacer()
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }

    private struct SectionCardView: View {
        let section: HomepageSection
        let onTap: () -> Void

        private let columns = [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                    // Section Title
                    Text(section.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)

                    // Product Preview Grid
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(Array(section.previewImages.enumerated()), id: \.offset) { index, imageUrl in
                            CachedImageView(
                                url: URL(string: imageUrl),
                                placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            ProgressView()
                                                .scaleEffect(0.6)
                                        )
                                },
                                failureView: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                        )
                                }
                            )
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 60)
                            .cornerRadius(6)
                            .clipped()
                        }

                        // Fill remaining slots if less than 4 images
                        ForEach(section.previewImages.count..<4, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 60)
                                .cornerRadius(6)
                        }
                    }
                    .frame(height: 124) // 2 rows * 60px + 4px spacing

                    Spacer()

                    // Shop Now Link
                    HStack {
                        Text("Shop now")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.blue)

                        Spacer()
                    }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .onTapGesture {
                onTap()
            }
        }
    }

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Featured Collections")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(viewModel.collections.prefix(5)) { collection in
                        CollectionCard(collection: collection)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Products")
                        .font(.headline)
                        .fontWeight(.semibold)

                    // Show current filter status
                    if let selectedCategory = viewModel.selectedCategory {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Filtered by: \(selectedCategory.name)")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Button("Clear") {
                                viewModel.clearFilters()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    } else if !viewModel.searchText.isEmpty {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Search: \"\(viewModel.searchText)\"")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }

                Spacer()

                if viewModel.totalProducts > 0 {
                    Text("(\(viewModel.totalProducts))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.isLoading && viewModel.products.isEmpty {
                ProgressView("Loading products...")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if viewModel.products.isEmpty {
                emptyStateView
            } else {
                StaggeredProductGrid(products: viewModel.products) { product in
                    ProductCardWithNavigation(
                        product: product,
                        productId: product.id,
                        onAddToCart: {
                            addToCart(product)
                        }
                    )
                    .environmentObject(cartManager)
                    .buttonStyle(PlainButtonStyle())
                    .onAppear {
                        print("🎯 ProductCard displayed - ID: \(product.id), Name: \(product.name)")
                        // Load more when approaching the end
                        if isLastItem(product) && viewModel.hasMorePages && !viewModel.isLoading {
                            viewModel.loadMoreProducts()
                        }
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No products found")
                .font(.headline)
                .foregroundColor(.secondary)

            if viewModel.searchText.isEmpty {
                Text("Try refreshing or check back later")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Try adjusting your search or filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }


    private var filterButton: some View {
        Button(action: {
            showingFilters = true
        }) {
            Image(systemName: "line.horizontal.3.decrease.circle")
        }
    }

    private var sortButton: some View {
        Button(action: {
            showingSortOptions = true
        }) {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
    }

    private var sortOptionsSheet: some View {
        NavigationView {
            List {
                ForEach(ProductSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        viewModel.updateSortOption(option)
                        showingSortOptions = false
                    }) {
                        HStack {
                            Text(option.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if option == viewModel.selectedSortOption {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sort By")
            .navigationBarItems(trailing: Button("Done") {
                showingSortOptions = false
            })
        }
    }

    private var filtersSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Filters")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Category Filter
                        categoryFilterSection

                        Divider()

                        // Price Range (placeholder for future implementation)
                        priceFilterSection
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Clear Filters Button
                Button(action: {
                    viewModel.clearFilters()
                    showingFilters = false
                }) {
                    Text("Clear All Filters")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .navigationBarItems(trailing: Button("Done") {
                showingFilters = false
            })
        }
    }

    private var categoryFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(viewModel.categories) { category in
                    Button(action: {
                        viewModel.filterByCategory(category)
                    }) {
                        Text(category.name)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedCategory?.id == category.id ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(viewModel.selectedCategory?.id == category.id ? .white : .primary)
                            .cornerRadius(16)
                    }
                }
            }
        }
    }

    private var priceFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Price Range")
                .font(.headline)

            Text("Price filtering coming soon...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func addToCart(_ product: Product) {
        cartManager.addProduct(product)
    }

    private func isLastItem(_ product: Product) -> Bool {
        guard let lastProduct = viewModel.products.last else { return false }
        return product.id == lastProduct.id
    }
}


// MARK: - Account View
struct AccountView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingOrdersView = false
    @State private var showingEmailSettings = false

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
                    AccountMenuRow(icon: "bag", title: "My Orders", action: {
                        showingOrdersView = true
                    })
                    AccountMenuRow(icon: "heart", title: "Wishlist", action: {})
                    AccountMenuRow(icon: "person", title: "Profile Settings", action: {})
                    AccountMenuRow(icon: "bell", title: "Email Notifications", action: {
                        showingEmailSettings = true
                    })
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
        .sheet(isPresented: $showingOrdersView) {
            OrdersView()
        }
        .sheet(isPresented: $showingEmailSettings) {
            EmailNotificationSettingsView()
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

// MARK: - Staggered Product Grid
struct StaggeredProductGrid<Content: View>: View {
    let products: [Product]
    let content: (Product) -> Content

    private let columnSpacing: CGFloat = 16
    private let verticalSpacing: CGFloat = 20

    var body: some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            // First Column - Starts immediately
            LazyVStack(spacing: verticalSpacing) {
                ForEach(Array(products.enumerated()), id: \.offset) { index, product in
                    if index % 2 == 0 {
                        content(product)
                            .padding(.horizontal, 4)
                    }
                }
            }

            // Second Column - Starts with offset (staggered)
            LazyVStack(spacing: verticalSpacing) {
                // Add spacer to create staggered effect
                Spacer(minLength: 3)

                ForEach(Array(products.enumerated()), id: \.offset) { index, product in
                    if index % 2 == 1 {
                        content(product)
                            .padding(.horizontal, 4)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct CategoryCard: View {
    let category: Category?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                CachedImageView(
                    url: URL(string: category?.image ?? ""),
                    placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                            )
                    },
                    failureView: {
                        if category == nil {
                            // Custom design for "All" category
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue.opacity(0.8),
                                            Color.purple.opacity(0.9),
                                            Color.indigo.opacity(0.7)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    ZStack {
                                        // Background pattern
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
                                            .frame(width: 40, height: 40)
                                            .offset(x: -10, y: -10)

                                        Circle()
                                            .fill(Color.white.opacity(0.08))
                                            .frame(width: 25, height: 25)
                                            .offset(x: 15, y: 15)

                                        // Main icon
                                        Image(systemName: "square.grid.3x3")
                                            .font(.title2.weight(.semibold))
                                            .foregroundColor(.white)
                                    }
                                )
                                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        } else {
                            // Default for other categories
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "tag")
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .cornerRadius(8)

                Text(category?.name ?? "All")
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .blue : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80)
        }
    }
}

struct CollectionCard: View {
    let collection: ProductCollection

    var body: some View {
        VStack(alignment: .leading) {
            CachedImageView(
                url: URL(string: collection.image ?? ""),
                placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                },
                failureView: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
            )
            .aspectRatio(contentMode: .fill)
            .frame(width: 140, height: 80)
            .cornerRadius(12)

            Text(collection.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
        }
        .frame(width: 140)
    }
}

struct ProductCard: View {
    let product: Product
    let addToCartAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image - Using cached image view
            CachedImageView.productImage(url: product.mainImage)
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: 140)
                .clipped()
                .cornerRadius(12)
            .overlay(alignment: .topTrailing) {
                if product.hasDiscount {
                    Text("-\(product.discountPercentage)%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                // Product Name
                Text(product.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                // Seller Name
                Text("by \(product.sellerName)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Rating
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(String(format: "%.1f", product.rating))
                        .font(.caption)
                    Text("(\(product.reviewCount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                // Price
                HStack {
                    Text("$\(product.formattedPrice)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    if let originalPrice = product.formattedOriginalPrice {
                        Text("$\(originalPrice)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .strikethrough()
                    }

                    Spacer()

                    Button(action: addToCartAction) {
                        Image(systemName: "cart.badge.plus")
                            .foregroundColor(.blue)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            print("🎯 ProductCard displayed - ID: \(product.id), Name: \(product.name)")
        }
    }
}

// MARK: - Category Products Screen
struct CategoryProductsScreen: View {
    let category: Category
    let sectionTitle: String?
    let cartManager: CartManager

    @StateObject private var viewModel = ProductListViewModel(loadInitialDataOnInit: false)

    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Header Section
                headerSection

                // Products Grid
                if viewModel.isLoading && viewModel.products.isEmpty {
                    loadingView
                } else if viewModel.products.isEmpty {
                    emptyStateView
                } else {
                    productsGrid
                }

                // Loading indicator at bottom for infinite scroll
                if viewModel.isLoading && viewModel.hasMorePages && !viewModel.products.isEmpty {
                    ProgressView("Loading more products...")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle(sectionTitle ?? category.name)
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            viewModel.refreshProducts()
        }
        .onAppear {
            setupCategoryFilter()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil && viewModel.products.isEmpty && !viewModel.isLoading)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let sectionTitle = sectionTitle {
                Text(sectionTitle)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            Text("Browse \(category.name)")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if viewModel.totalProducts > 0 {
                Text("\(viewModel.totalProducts) products available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading \(category.name.lowercased()) products...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.box")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No Products Found")
                .font(.headline)
                .foregroundColor(.primary)

            Text("We couldn't find any products in \(category.name) at the moment.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Refresh") {
                viewModel.refreshProducts()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }

    private var productsGrid: some View {
        StaggeredProductGrid(products: viewModel.products) { product in
            NavigationLink(destination: ProductDetailView(productId: product.id).environmentObject(cartManager)) {
                ProductCard(product: product) {
                    addToCart(product)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear {
                print("🎯 CategoryProducts ProductCard displayed - ID: \(product.id), Name: \(product.name)")
                // Load more when approaching the end
                if isLastItem(product) && viewModel.hasMorePages && !viewModel.isLoading {
                    viewModel.loadMoreProducts()
                }
            }
        }
    }


    private func setupCategoryFilter() {
        print("🎯 CategoryProductsScreen setup for: \(category.name) (ID: \(category.id))")
        // Load only essential data for category screen
        viewModel.loadCategories()
        viewModel.clearFilters()
        viewModel.filterByCategory(category)
    }

    private func addToCart(_ product: Product) {
        cartManager.addProduct(product, quantity: 1)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    private func isLastItem(_ product: Product) -> Bool {
        guard let lastProduct = viewModel.products.last else { return false }
        return product.id == lastProduct.id
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(CartManager.shared)
    }
}

// MARK: - Email Notification Settings
struct EmailNotificationSettingsView: View {
    @State private var orderConfirmationEmails = true
    @State private var orderStatusUpdates = true
    @State private var promotionalEmails = false
    @State private var weeklyNewsletters = false
    @State private var securityNotifications = true
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Order Notifications")) {
                    NotificationToggleRow(
                        title: "Order Confirmations",
                        subtitle: "Email when orders are placed",
                        isOn: $orderConfirmationEmails
                    )

                    NotificationToggleRow(
                        title: "Order Status Updates",
                        subtitle: "Email when order status changes",
                        isOn: $orderStatusUpdates
                    )
                }

                Section(header: Text("Marketing")) {
                    NotificationToggleRow(
                        title: "Promotional Offers",
                        subtitle: "Special deals and discounts",
                        isOn: $promotionalEmails
                    )

                    NotificationToggleRow(
                        title: "Weekly Newsletter",
                        subtitle: "New products and updates",
                        isOn: $weeklyNewsletters
                    )
                }

                Section(header: Text("Security")) {
                    NotificationToggleRow(
                        title: "Security Alerts",
                        subtitle: "Account security notifications",
                        isOn: $securityNotifications
                    )
                }

                Section {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)

                            Text("Email Preferences")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Text("Your email preferences are automatically synced with our system. You'll receive notifications based on these settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Email Notifications")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    savePreferences()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    private func savePreferences() {
        // TODO: Save preferences to backend/UserDefaults
        print("📧 Saving email preferences:")
        print("  Order Confirmations: \(orderConfirmationEmails)")
        print("  Order Status Updates: \(orderStatusUpdates)")
        print("  Promotional Emails: \(promotionalEmails)")
        print("  Weekly Newsletter: \(weeklyNewsletters)")
        print("  Security Notifications: \(securityNotifications)")
    }
}

struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - RaffleSection View
struct RaffleSection: View {
    @State private var raffles: [APIRaffle] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    @EnvironmentObject var cartManager: CartManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "gift.fill")
                            .foregroundColor(.purple)
                            .font(.title3)
                        Text("Active Raffles")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    Text("Win amazing prizes with every purchase!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Content
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if raffles.isEmpty {
                noRafflesView
            } else {
                raffleCardsView
            }
        }
        .onAppear {
            loadRaffles()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading raffles...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Failed to load raffles")
                .font(.headline)
                .foregroundColor(.primary)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                loadRaffles()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var noRafflesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("No Active Raffles")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Check back soon for amazing prize opportunities!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var raffleCardsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(raffles) { raffle in
                    RaffleCard(raffle: raffle) {
                        handleBuyTicket(raffle: raffle)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func loadRaffles() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await APIService.shared.fetchRafflesAsync()

                await MainActor.run {
                    self.raffles = response.raffles
                    self.isLoading = false
                }

                print("🎫 Successfully loaded \(response.raffles.count) raffles")
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
                print("❌ Failed to load raffles: \(error)")
            }
        }
    }

    private func handleBuyTicket(raffle: APIRaffle) {
        print("\n🎯 ===== ENTER RAFFLE BUTTON CLICKED =====")
        print("🎫 Raffle Title: \(raffle.title)")
        print("🆔 Raffle ID: \(raffle.id)")
        print("🛒 Adding raffle ticket to cart...")

        // For now, use the fallback approach since we need proper API integration
        if let raffleProduct = createFallbackRaffleProduct(from: raffle) {
            print("✅ Created raffle product:")
            print("   - ID: \(raffleProduct.id)")
            print("   - Name: \(raffleProduct.name)")
            print("   - Price: $\(raffleProduct.price)")
            print("   - Is Raffle Ticket: \(raffleProduct.isRaffleTicket ?? false)")

            // Add to cart using CartManager
            cartManager.addProduct(raffleProduct, quantity: 1)

            print("🛒 Product added to cart!")
            print("🧮 Current cart count: \(cartManager.itemCount)")
            print("💰 Current cart total: $\(cartManager.total)")
        } else {
            print("❌ Failed to create raffle product from: \(raffle.title)")
        }

        print("===== END ENTER RAFFLE PROCESSING =====\n")
    }

    // MARK: - Helper Functions

    private func createFallbackRaffleProduct(from raffle: APIRaffle, ticketCount: Int = 1) -> Product? {
        // Use ACTUAL raffle product ID from the API response (not hardcoded)
        guard let raffleProduct = raffle.products?.first else {
            print("❌ No raffle products available for \(raffle.title)")
            return nil
        }

        let actualProductId = raffleProduct.id
        let productPrice = raffleProduct.price ?? 5.0
        let productName = raffleProduct.name

        print("✅ Using ACTUAL raffle ticket product from API")
        print("   - Using ACTUAL Product ID: \(actualProductId)")
        print("   - Product Name: \(productName)")
        print("   - Ticket Price: $\(productPrice)")
        print("   - Raffle ID: \(raffle.id)")

        // Create a Product object that matches the web frontend approach
        return Product(
            id: actualProductId, // Use ACTUAL product ID from API (same as web frontend)
            name: "🎫 \(raffle.title) - Entry Ticket",
            description: "Raffle entry for \(raffle.title). Each purchase gives you \(ticketCount) ticket(s) to win \(raffle.prizeCurrency ?? "$")\(raffle.prizeValue ?? 0)!",
            price: productPrice,
            originalPrice: productPrice,
            sellerId: "mall-of-lebanon",
            sellerName: "Mall of Lebanon",
            category: "raffle",
            subcategory: "tickets",
            brand: "Mall of Lebanon",
            sku: "RAFFLE-\(raffle.id)",
            inStock: true,
            quantity: 1000,
            status: (raffle.isActive ?? true) ? .active : .inactive,
            images: [raffle.prizeImage ?? ""],
            rating: 5.0,
            reviewCount: 0,
            tags: ["raffle", "giveaway", "prize"],
            specifications: nil,
            featured: true,
            slug: "raffle-\(raffle.id)",
            customizationOptions: nil,
            createdAt: Date(),
            updatedAt: Date(),
            outOfStockSince: nil,
            baseQuantity: nil,
            hasCustomizations: false,
            stockManagement: "auto",
            categoryTemplate: nil,
            categoryFields: nil,
            hasComparison: false,
            matchingData: nil,
            comparisonGroup: nil,
            seller: "Mall of Lebanon",
            store: "Mall of Lebanon",
            title: productName,
            shortDescription: "Win \(raffle.title)!",
            comparePrice: nil,
            costPrice: nil,
            stock: max(0, (raffle.maxTickets ?? 1000) - (raffle.currentTickets ?? 0)),
            isActive: raffle.isActive ?? true,
            isApproved: true,
            isFeatured: true,
            ratings: nil,
            metaKeywords: ["raffle", "giveaway", raffle.title],
            views: 0,
            soldCount: raffle.currentTickets ?? 0,
            variants: nil,
            taxRate: nil,
            reviews: nil,
            hasInstallmentPlans: false,
            installmentSettings: nil,
            installmentPlansRaw: nil,
            isRaffleTicket: true, // This flag is crucial for backend processing
            raffleInfo: ProductRaffleInfo(
                raffleId: raffle.id,
                raffleTitle: raffle.title,
                ticketsPerPurchase: ticketCount,
                drawDate: raffle.drawDate
            )
        )
    }
}

struct RaffleCard: View {
    let raffle: APIRaffle
    let onBuyTicket: () -> Void

    private func formatPrizeValue(_ raffle: APIRaffle) -> String {
        // First try to use the API's formatted value
        if let formatted = raffle.formattedPrizeValue, !formatted.isEmpty {
            return formatted
        }

        // Fallback to formatting the raw value
        if let value = raffle.prizeValue {
            if value >= 1000 {
                return String(format: "%.0fK", value / 1000)
            } else {
                return String(format: "%.0f", value)
            }
        }

        // Final fallback
        return "TBD"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Prize Image
            CachedImageView(
                url: raffle.prizeImage.flatMap { URL(string: $0) },
                placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(ProgressView().scaleEffect(0.6))
                },
                failureView: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            Image(systemName: "gift.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        )
                }
            )
            .aspectRatio(contentMode: .fill)
            .frame(width: 280, height: 140)
            .clipped()
            .cornerRadius(12)

            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text(raffle.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text(raffle.prizeCurrency ?? "USD")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatPrizeValue(raffle))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("VALUE")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Text(raffle.timeLeftText ?? "Time TBD")
                    .font(.caption)
                    .foregroundColor(.orange)

                // Progress
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(raffle.progressText ?? "Progress N/A")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Spacer()
                        Text("\(raffle.percentageSold ?? 0)% Sold")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: max(0, geometry.size.width * (CGFloat(raffle.percentageSold ?? 0) / 100.0)),
                                    height: 4
                                )
                        }
                    }
                    .frame(height: 4)
                }
            }

            // Entry Product Info
            if let products = raffle.products, let firstProduct = products.first {
                HStack {
                    Image(systemName: "ticket.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("\(firstProduct.name) - $\(firstProduct.formattedPrice ?? String(format: "%.2f", firstProduct.price ?? 0.0))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.bottom, 4)
            }

            // Button
            Button(action: onBuyTicket) {
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.subheadline)
                    Text("Enter Raffle")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let products = raffle.products, let product = products.first, let price = product.formattedPrice {
                        Spacer()
                        Text("$\(price)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

