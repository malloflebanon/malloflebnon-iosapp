import SwiftUI
import Combine

struct SearchView: View {
    @StateObject private var viewModel = ProductListViewModel(loadInitialDataOnInit: false)
    @EnvironmentObject var cartManager: CartManager

    @State private var searchQuery = ""
    @State private var selectedCategory: Category?
    @State private var showingSortOptions = false
    @State private var showingSuggestions = false
    @State private var searchSuggestions: [Product] = []
    @State private var isSearchingForSuggestions = false
    @State private var cancellables = Set<AnyCancellable>()
    @FocusState private var isSearchFieldFocused: Bool

    private let suggestionsLimit = 5

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Header
                searchHeaderSection

                // Search Results Content
                searchContentSection
                    .onTapGesture {
                        // Dismiss keyboard when tapping on results area
                        isSearchFieldFocused = false
                    }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: sortButton
            )
            .sheet(isPresented: $showingSortOptions) {
                sortOptionsSheet
            }
            .onAppear {
                setupInitialData()
                // Automatically focus search field when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isSearchFieldFocused = true
                }
            }
            .onChange(of: isSearchFieldFocused) { focused in
                // Hide suggestions when search field loses focus
                if !focused {
                    showingSuggestions = false
                }
            }
        }
    }

    // MARK: - Search Header Section
    private var searchHeaderSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            searchBarSection

            // Category Filter
            categoryFilterSection

            // Search Info
            if !viewModel.products.isEmpty || !searchQuery.isEmpty {
                searchInfoSection
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var searchBarSection: some View {
        HStack(spacing: 12) {
            // Search Input
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))

                TextField("Search Mall Of Lebanon", text: $searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        performSearch()
                        isSearchFieldFocused = false
                    }
                    .onChange(of: searchQuery) { newValue in
                        handleSearchQueryChange(newValue)
                    }
                    .onTapGesture {
                        isSearchFieldFocused = true
                        // Show suggestions if there's already text
                        if !searchQuery.isEmpty && searchQuery.count >= 2 {
                            showingSuggestions = true
                        }
                    }

                if !searchQuery.isEmpty {
                    Button(action: {
                        clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .overlay(
            // Search Suggestions Overlay
            searchSuggestionsOverlay,
            alignment: .top
        )
    }

    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "All Categories" Button
                CategoryFilterChip(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    action: {
                        selectedCategory = nil
                        performSearch()
                    }
                )

                // Category Chips
                ForEach(viewModel.categories) { category in
                    CategoryFilterChip(
                        title: category.name,
                        isSelected: selectedCategory?.id == category.id,
                        action: {
                            selectedCategory = category
                            performSearch()
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private var searchInfoSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if !searchQuery.isEmpty {
                    HStack {
                        Text("Results for")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\"\(searchQuery)\"")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }

                if let category = selectedCategory {
                    HStack {
                        Text("in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(category.name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
            }

            Spacer()

            if viewModel.totalProducts > 0 {
                Text("\(viewModel.totalProducts) results")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Search Suggestions
    private var searchSuggestionsOverlay: some View {
        VStack {
            if showingSuggestions && (!searchQuery.isEmpty || isSearchingForSuggestions) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                        .frame(height: 52) // Height of search bar

                    VStack(alignment: .leading, spacing: 0) {
                        if isSearchingForSuggestions {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Searching...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding()
                        } else if searchSuggestions.isEmpty && searchQuery.count >= 2 {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                Text("No suggestions for \"\(searchQuery)\"")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding()
                        } else {
                            ForEach(searchSuggestions.prefix(suggestionsLimit), id: \.id) { product in
                                SearchSuggestionRow(
                                    product: product,
                                    searchQuery: searchQuery,
                                    onTap: {
                                        selectSuggestion(product)
                                    }
                                )

                                if product.id != searchSuggestions.prefix(suggestionsLimit).last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }

                            if !searchSuggestions.isEmpty && !searchQuery.isEmpty {
                                Divider()

                                Button(action: {
                                    performSearch()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.right.circle")
                                            .foregroundColor(.blue)
                                        Text("View all results for \"\(searchQuery)\"")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                        Spacer()
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
            }

            Spacer()
        }
    }

    // MARK: - Search Content
    private var searchContentSection: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if searchQuery.isEmpty && viewModel.products.isEmpty {
                    // Initial State - Show popular searches or categories
                    initialSearchState
                } else if viewModel.isLoading && viewModel.products.isEmpty {
                    // Loading State
                    loadingState
                } else if viewModel.products.isEmpty && !searchQuery.isEmpty {
                    // No Results State
                    noResultsState
                } else {
                    // Results State
                    searchResultsGrid

                    // Load More Indicator
                    if viewModel.isLoading && viewModel.hasMorePages && !viewModel.products.isEmpty {
                        ProgressView("Loading more results...")
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                }
            }
            .padding(.horizontal)
        }
        .refreshable {
            performSearch()
        }
    }

    private var initialSearchState: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)

            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.6))

                VStack(spacing: 8) {
                    Text("Search Mall Of Lebanon")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Find products from thousands of sellers")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Popular Categories
            if !viewModel.categories.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Popular Categories")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(viewModel.categories.prefix(6)) { category in
                            PopularCategoryCard(category: category) {
                                selectedCategory = category
                                performSearch()
                            }
                        }
                    }
                }
                .padding(.top, 20)
            }

            Spacer()
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching for \"\(searchQuery)\"...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var noResultsState: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("No results found")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("We couldn't find any products matching \"\(searchQuery)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Search suggestions:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 4) {
                    Text("• Try different or more general keywords")
                    Text("• Check your spelling")
                    Text("• Try a different category")
                    if selectedCategory != nil {
                        Text("• Search in all categories")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)

            Button("Browse All Products") {
                clearSearch()
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .padding()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }

    private var searchResultsGrid: some View {
        StaggeredProductGrid(products: viewModel.products) { product in
            ProductCardWithNavigation(
                product: product,
                productId: product.id,
                onAddToCart: {
                    addToCart(product)
                }
            )
            .environmentObject(cartManager)
            .onAppear {
                // Load more when approaching the end
                if isLastItem(product) && viewModel.hasMorePages && !viewModel.isLoading {
                    viewModel.loadMoreProducts()
                }
            }
        }
    }

    // MARK: - Sort Options Sheet
    private var sortButton: some View {
        Button(action: {
            showingSortOptions = true
        }) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 16))
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

    // MARK: - Helper Methods

    private func setupInitialData() {
        if viewModel.categories.isEmpty {
            viewModel.loadCategories()
        }
    }

    private func handleSearchQueryChange(_ newValue: String) {
        // Hide suggestions if query is too short
        if newValue.count < 2 {
            showingSuggestions = false
            searchSuggestions = []
            return
        }

        // Show suggestions and start searching
        showingSuggestions = true
        loadSearchSuggestions(for: newValue)
    }

    private func loadSearchSuggestions(for query: String) {
        // Debounce suggestions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard query == searchQuery && !query.isEmpty else { return }

            isSearchingForSuggestions = true

            // Use the existing API to get suggestions
            var searchParams = ProductSearchParams()
            searchParams.search = query
            searchParams.limit = suggestionsLimit

            APIService.shared.getProducts(parameters: searchParams)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        self.isSearchingForSuggestions = false
                    },
                    receiveValue: { response in
                        self.searchSuggestions = response.products
                        self.isSearchingForSuggestions = false
                    }
                )
                .store(in: &cancellables)
        }
    }

    private func performSearch() {
        showingSuggestions = false
        viewModel.searchText = searchQuery

        if let category = selectedCategory {
            viewModel.filterByCategory(category)
        } else {
            viewModel.currentSearchParams.category = nil
            viewModel.loadProducts(resetResults: true)
        }
    }

    private func clearSearch() {
        searchQuery = ""
        selectedCategory = nil
        showingSuggestions = false
        searchSuggestions = []
        viewModel.searchText = ""
        viewModel.clearFilters()
        // Keep focus on search field after clearing
        isSearchFieldFocused = true
    }

    private func selectSuggestion(_ product: Product) {
        showingSuggestions = false
        searchQuery = ""
        // Navigate to product detail - this will be handled by the ProductCardWithNavigation
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

// MARK: - Supporting Views

struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct SearchSuggestionRow: View {
    let product: Product
    let searchQuery: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Product Image
                CachedImageView.productImage(url: product.mainImage)
                    .frame(width: 40, height: 40)
                    .cornerRadius(6)

                // Product Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("$\(product.price, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }

                Spacer()

                Image(systemName: "arrow.up.left")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }
}

struct PopularCategoryCard: View {
    let category: Category
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                CachedImageView(
                    url: URL(string: category.image ?? ""),
                    placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                Image(systemName: "tag")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            )
                    },
                    failureView: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                Image(systemName: "tag")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            )
                    }
                )
                .aspectRatio(contentMode: .fill)
                .frame(height: 60)
                .clipped()
                .cornerRadius(8)

                Text(category.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
            .environmentObject(CartManager.shared)
    }
}