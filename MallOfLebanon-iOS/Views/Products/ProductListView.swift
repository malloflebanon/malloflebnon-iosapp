import SwiftUI

struct ProductListView: View {
    @StateObject private var viewModel = ProductListViewModel()
    @EnvironmentObject var cartManager: CartManager

    @State private var showingSortOptions = false
    @State private var showingFilters = false

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Search Bar
                    searchSection

                    // Categories Horizontal Scroll
                    if !viewModel.categories.isEmpty {
                        categoriesSection
                    }

                    // Collections/Featured Section
                    if !viewModel.collections.isEmpty {
                        collectionsSection
                    }

                    // Products Grid
                    productsSection

                    // Load More Button
                    if viewModel.hasMorePages && !viewModel.products.isEmpty {
                        loadMoreButton
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Mall Of Lebanon")
            .navigationBarItems(
                leading: filterButton,
                trailing: sortButton
            )
            .refreshable {
                viewModel.refreshProducts()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
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
                        viewModel.filterByCategory(nil)
                    }

                    ForEach(viewModel.categories.prefix(8)) { category in
                        CategoryCard(
                            category: category,
                            isSelected: viewModel.selectedCategory?.id == category.id
                        ) {
                            viewModel.filterByCategory(category)
                        }
                    }
                }
                .padding(.horizontal)
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
                Text("Products")
                    .font(.headline)
                    .fontWeight(.semibold)

                if viewModel.totalProducts > 0 {
                    Text("(\(viewModel.totalProducts))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            if viewModel.isLoading && viewModel.products.isEmpty {
                ProgressView("Loading products...")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if viewModel.products.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.products) { product in
                        ProductCard(product: product) {
                            addToCart(product)
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

    private var loadMoreButton: some View {
        Button(action: {
            viewModel.loadMoreProducts()
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.down.circle")
                }
                Text("Load More")
            }
            .foregroundColor(.blue)
            .padding()
        }
        .disabled(viewModel.isLoading)
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
}

// MARK: - Supporting Views

struct CategoryCard: View {
    let category: Category?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                AsyncImage(url: URL(string: category?.image ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: category == nil ? "square.grid.2x2" : "tag")
                                .foregroundColor(.gray)
                        )
                }
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
            AsyncImage(url: URL(string: collection.image ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
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
            // Product Image
            AsyncImage(url: URL(string: product.mainImage)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(height: 140)
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
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ProductListView_Previews: PreviewProvider {
    static var previews: some View {
        ProductListView()
            .environmentObject(CartManager.shared)
    }
}