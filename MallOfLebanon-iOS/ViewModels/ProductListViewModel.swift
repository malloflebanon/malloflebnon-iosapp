import Foundation
import Combine

class ProductListViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var categories: [Category] = []
    @Published var collections: [ProductCollection] = []
    @Published var homepageSections: [HomepageSection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMorePages = false
    @Published var currentPage = 1
    @Published var totalProducts = 0

    @Published var searchText = ""
    @Published var selectedCategory: Category?
    @Published var selectedSortOption: ProductSortOption = .newest
    @Published var currentSearchParams = ProductSearchParams()

    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()

    init(loadInitialDataOnInit: Bool = true) {
        setupSearchDebouncing()
        if loadInitialDataOnInit {
            loadInitialData()
        }
    }

    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] searchText in
                self?.performSearch(query: searchText)
            }
            .store(in: &cancellables)
    }

    func loadInitialData() {
        loadCategories()
        loadCollections()
        loadHomepageSections()
        loadProducts()
    }

    func loadCategories() {
        apiService.getCategories()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Failed to load categories: \(error)")
                        self?.errorMessage = "Failed to load categories"
                    }
                },
                receiveValue: { [weak self] response in
                    self?.categories = response.categories
                }
            )
            .store(in: &cancellables)
    }

    func loadCollections() {
        apiService.getCollections()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Failed to load collections: \(error)")
                        self?.errorMessage = "Failed to load collections"
                    }
                },
                receiveValue: { [weak self] (response: CollectionsResponse) in
                    self?.collections = response.collections
                }
            )
            .store(in: &cancellables)
    }

    func loadHomepageSections() {
        apiService.getHomepageSections()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Failed to load homepage sections: \(error)")
                        self?.errorMessage = "Failed to load homepage sections"
                    }
                },
                receiveValue: { [weak self] (response: HomepageSectionsResponse) in
                    // Filter active sections and sort by display order
                    self?.homepageSections = response.sections
                        .filter { $0.isActive }
                        .sorted { $0.displayOrder < $1.displayOrder }
                }
            )
            .store(in: &cancellables)
    }

    func loadProducts(resetResults: Bool = false) {
        print("\n🚀 ===== LOAD PRODUCTS CALLED =====\n")
        print("🎯 loadProducts(resetResults: \(resetResults)) called")
        print("📊 Current state before loading:")
        print("   - Current products count: \(products.count)")
        print("   - Current page: \(currentPage)")
        print("   - Has more pages: \(hasMorePages)")
        print("   - Is loading: \(isLoading)")
        print("   - Error message: \(errorMessage ?? "None")")

        if resetResults {
            print("🔄 Resetting results...")
            products = []
            currentPage = 1
            hasMorePages = false
            print("✅ Reset complete - products cleared, page = 1")
        }

        print("🔄 Setting isLoading = true, errorMessage = nil")
        isLoading = true
        errorMessage = nil

        currentSearchParams.page = currentPage
        currentSearchParams.sortBy = selectedSortOption

        // Debug: Log the search parameters being used
        print("\n🔍 LOADING PRODUCTS WITH PARAMETERS:")
        print("   - Category: \(currentSearchParams.category ?? "None")")
        print("   - Subcategory: \(currentSearchParams.subcategory ?? "None")")
        print("   - Search: \(currentSearchParams.search ?? "None")")
        print("   - Page: \(currentSearchParams.page)")
        print("   - Limit: \(currentSearchParams.limit)")
        print("   - Sort By: \(currentSearchParams.sortBy)")
        print("   - Reset: \(resetResults)")
        print("\n📞 About to call apiService.getProducts()...")

        apiService.getProducts(parameters: currentSearchParams)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    print("\n🏁 ===== API REQUEST COMPLETION =====\n")

                    guard let self = self else {
                        print("❌ Self is nil in completion handler")
                        return
                    }

                    print("🔄 Setting isLoading = false")
                    self.isLoading = false

                    switch completion {
                    case .finished:
                        print("✅ API request completed successfully")
                        print("   - Final products count: \(self.products.count)")
                        print("   - Final error state: \(self.errorMessage ?? "None")")

                    case .failure(let error):
                        print("❌ ===== API REQUEST FAILED =====\n")
                        print("💥 API Error details:")
                        print("   - Error: \(error)")
                        print("   - Localized description: \(error.localizedDescription)")

                        let errorDescription = error.localizedDescription

                        if errorDescription.contains("Access token required") || errorDescription.contains("token") {
                            print("🔐 Setting auth-related error message")
                            self.errorMessage = "Products require login. Please log in to browse the full catalog."
                        } else if errorDescription.contains("timeout") || errorDescription.contains("network") {
                            print("🌐 Setting network-related error message")
                            self.errorMessage = "Network timeout. Please check your connection and try again."
                        } else {
                            print("❓ Setting generic error message")
                            self.errorMessage = "Failed to load products. Please try again later."
                        }

                        print("📝 Final error message set to: \(self.errorMessage ?? "None")")
                        print("\n===== END ERROR HANDLING =====\n")
                    }

                    print("===== END API REQUEST COMPLETION =====\n")
                },
                receiveValue: { [weak self] response in
                    guard let self = self else {
                        print("❌ Self is nil in receiveValue")
                        return
                    }

                    print("\n✅ ===== API RESPONSE RECEIVED =====\n")
                    print("📦 API Response details:")
                    print("   - Success: \(response.products.count > 0 || response.pagination.totalProducts >= 0)")
                    print("   - Products count: \(response.products.count)")
                    print("   - Total products: \(response.pagination.totalProducts)")
                    print("   - Current page: \(response.pagination.currentPage)")
                    print("   - Has next page: \(response.pagination.hasNextPage)")
                    print("   - Total pages: \(response.pagination.totalPages ?? 0)")

                    // Log first few products for debugging
                    if !response.products.isEmpty {
                        print("\n📝 First 3 products in response:")
                        for (index, product) in response.products.prefix(3).enumerated() {
                            print("   [\(index + 1)] ID: \(product.id), Name: \(product.name), Category: \(product.category)")
                        }
                    } else {
                        print("⚠️ No products in API response!")
                    }

                    if resetResults {
                        self.products = response.products
                        print("\n🔄 Products RESET to \(response.products.count) items")
                    } else {
                        let beforeCount = self.products.count
                        self.products.append(contentsOf: response.products)
                        print("\n➕ APPENDED \(response.products.count) products")
                        print("   - Before: \(beforeCount) products")
                        print("   - After: \(self.products.count) products")
                    }

                    self.currentPage = response.pagination.currentPage
                    self.hasMorePages = response.pagination.hasNextPage
                    self.totalProducts = response.pagination.totalProducts

                    print("\n🔄 Setting isLoading = false")
                    self.isLoading = false

                    print("\n🎯 FINAL STATE AFTER LOADING:")
                    print("   - Products count: \(self.products.count)")
                    print("   - Current page: \(self.currentPage)")
                    print("   - Has more pages: \(self.hasMorePages)")
                    print("   - Total products available: \(self.totalProducts)")
                    print("   - Is loading: \(self.isLoading)")
                    print("   - Error message: \(self.errorMessage ?? "None")")
                    print("\n===== END API RESPONSE PROCESSING =====\n")
                }
            )
            .store(in: &cancellables)
    }

    func loadMoreProducts() {
        guard hasMorePages && !isLoading else { return }
        currentPage += 1
        loadProducts()
    }

    func refreshProducts() {
        loadCategories()
        loadCollections()
        loadHomepageSections()
        loadProducts(resetResults: true)
    }

    func performSearch(query: String) {
        currentSearchParams.search = query.isEmpty ? nil : query
        loadProducts(resetResults: true)
    }

    func filterByCategory(_ category: Category?) {
        print("🎯 filterByCategory called with: \(category?.name ?? "nil")")
        print("📝 Setting selectedCategory to: \(category?.name ?? "nil")")

        selectedCategory = category
        currentSearchParams.category = category?.id
        currentSearchParams.subcategory = nil

        print("✅ Updated search params - category: \(currentSearchParams.category ?? "None")")
        print("🚀 Calling loadProducts(resetResults: true)")

        loadProducts(resetResults: true)
    }

    func filterBySubcategory(_ subcategory: Category) {
        currentSearchParams.subcategory = subcategory.id
        loadProducts(resetResults: true)
    }

    func updateSortOption(_ sortOption: ProductSortOption) {
        selectedSortOption = sortOption
        currentSearchParams.sortBy = sortOption
        loadProducts(resetResults: true)
    }

    func clearFilters() {
        selectedCategory = nil
        searchText = ""
        selectedSortOption = .newest
        currentSearchParams = ProductSearchParams()
        loadProducts(resetResults: true)
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Helper Methods

    func getProductsByCategory() -> [String: [Product]] {
        Dictionary(grouping: products) { $0.category }
    }

    func getFeaturedProducts() -> [Product] {
        return products.filter { $0.isProductFeatured }
    }

    func getDiscountedProducts() -> [Product] {
        return products.filter { $0.hasDiscount }
    }

    func getCategoryProducts(categoryId: String) -> [Product] {
        return products.filter { $0.category == categoryId }
    }

}