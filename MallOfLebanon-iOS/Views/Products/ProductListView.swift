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

                    // Products Grid
                    productsSection

                    // Load More Button
                    if viewModel.hasMorePages && !viewModel.products.isEmpty {
                        loadMoreButton
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("All Products")
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
                    ForEach(viewModel.products, id: \.id) { product in
                        ProductCardWithNavigation(
                            product: product,
                            productId: product.id,
                            onAddToCart: {
                                addToCart(product)
                            }
                        )
                        .environmentObject(cartManager)
                        .id(product.id) // Stable identifier for SwiftUI optimization
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


// MARK: - ProductCardWithNavigation
struct ProductCardWithNavigation: View {
    let product: Product
    let productId: String
    let onAddToCart: () -> Void
    @EnvironmentObject var cartManager: CartManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image - Tappable area for navigation
            NavigationLink(destination: ProductDetailView(productId: productId).environmentObject(cartManager)) {
                VStack(alignment: .leading, spacing: 8) {
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
                                    .cornerRadius(8)
                                    .padding(8)
                            }
                        }

                    // Product Details - Also tappable for navigation
                    Text(product.name)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    Text("by \(product.sellerName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Price and Cart Button Row - NOT part of navigation
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    if let originalPrice = product.originalPrice, originalPrice > product.price {
                        Text("$\(originalPrice, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .strikethrough()
                    }

                    Text("$\(product.price, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                // Add to Cart Button - Separate from navigation
                Button(action: onAddToCart) {
                    Image(systemName: "cart.badge.plus")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 32, height: 32)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
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