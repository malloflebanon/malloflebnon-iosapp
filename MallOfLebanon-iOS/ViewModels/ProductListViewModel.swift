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
        if resetResults {
            products = []
            currentPage = 1
            hasMorePages = false
        }

        isLoading = true
        errorMessage = nil

        currentSearchParams.page = currentPage
        currentSearchParams.sortBy = selectedSortOption

        // Debug: Log the search parameters being used
        print("🔍 Loading products with parameters:")
        print("   - Category: \(currentSearchParams.category ?? "None")")
        print("   - Subcategory: \(currentSearchParams.subcategory ?? "None")")
        print("   - Search: \(currentSearchParams.search ?? "None")")
        print("   - Page: \(currentSearchParams.page)")
        print("   - Reset: \(resetResults)")

        apiService.getProducts(parameters: currentSearchParams)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("API Error: \(error.localizedDescription)")
                        let errorDescription = error.localizedDescription
                        if errorDescription.contains("Access token required") || errorDescription.contains("token") {
                            self?.errorMessage = "Products require login. Please log in to browse the full catalog."
                        } else if errorDescription.contains("timeout") || errorDescription.contains("network") {
                            self?.errorMessage = "Network timeout. Please check your connection and try again."
                        } else {
                            self?.errorMessage = "Failed to load products. Please try again later."
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self = self else { return }

                    // Debug: Log the response
                    print("📦 API Response received:")
                    print("   - Products count: \(response.products.count)")
                    print("   - Total products: \(response.pagination.totalProducts)")
                    print("   - Current page: \(response.pagination.currentPage)")
                    print("   - Has next page: \(response.pagination.hasNextPage)")

                    if resetResults {
                        self.products = response.products
                        print("✅ Products reset to \(response.products.count) items")
                    } else {
                        self.products.append(contentsOf: response.products)
                        print("➕ Added \(response.products.count) products, total now: \(self.products.count)")
                    }

                    self.currentPage = response.pagination.currentPage
                    self.hasMorePages = response.pagination.hasNextPage
                    self.totalProducts = response.pagination.totalProducts

                    // Debug: Final state
                    print("🎯 Final state - Products: \(self.products.count), Total: \(self.totalProducts)")
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