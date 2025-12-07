import Foundation
import Combine

class ProductListViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var categories: [Category] = []
    @Published var collections: [ProductCollection] = []
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

    init() {
        setupSearchDebouncing()
        loadInitialData()
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

        apiService.getProducts(parameters: currentSearchParams)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("API Error: \(error.localizedDescription)")
                        self?.errorMessage = "Failed to load products: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self = self else { return }

                    if resetResults {
                        self.products = response.products
                    } else {
                        self.products.append(contentsOf: response.products)
                    }

                    self.currentPage = response.pagination.currentPage
                    self.hasMorePages = response.pagination.hasNextPage
                    self.totalProducts = response.pagination.totalProducts
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
        loadProducts(resetResults: true)
    }

    func performSearch(query: String) {
        currentSearchParams.search = query.isEmpty ? nil : query
        loadProducts(resetResults: true)
    }

    func filterByCategory(_ category: Category?) {
        selectedCategory = category
        currentSearchParams.category = category?.id
        currentSearchParams.subcategory = nil
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
        return products.filter { $0.isFeatured }
    }

    func getDiscountedProducts() -> [Product] {
        return products.filter { $0.hasDiscount }
    }

    func getCategoryProducts(categoryId: String) -> [Product] {
        return products.filter { $0.category == categoryId }
    }

}