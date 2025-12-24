import SwiftUI

struct ProductDetailView: View {
    let productId: String
    @StateObject private var viewModel = ProductDetailViewModel()
    @EnvironmentObject var cartManager: CartManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else if let product = viewModel.product {
                    // Product Images
                    ProductImageGallery(
                        images: viewModel.currentImages,
                        selectedIndex: $viewModel.selectedImageIndex,
                        showingImageViewer: $viewModel.showingImageViewer,
                        discountPercentage: product.hasDiscount ? product.discountPercentage : nil
                    )
                    .id(viewModel.currentImages.first ?? "")

                    VStack(alignment: .leading, spacing: 20) {
                        // Product Information
                        ProductInformationSection(
                            product: product,
                            calculatedPrice: viewModel.calculatedPrice
                        )

                        Divider()

                        // Customization Options
                        if let customizations = product.customizationOptions, !customizations.isEmpty {
                            ProductCustomizationSection(
                                customizations: customizations,
                                selectedCustomizations: $viewModel.selectedCustomizations,
                                onCustomizationChanged: viewModel.updateCustomization
                            )

                            Divider()
                        }

                        // Stock and Purchase Section
                        ProductPurchaseSection(
                            product: product,
                            viewModel: viewModel,
                            onAddToCart: addToCart,
                            onBuyNow: buyNow
                        )

                        Divider()

                        // Details Tabs
                        ProductDetailsTabSection(
                            product: product,
                            viewModel: viewModel
                        )
                    }
                    .padding(.horizontal, 16)
                } else if viewModel.errorMessage != nil {
                    errorView
                }
            }
        }
        .refreshable {
            await refreshProduct()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .navigationBarItems(
            trailing: HStack {
                Button(action: {
                    viewModel.testLoadKnownValidProduct()
                }) {
                    Image(systemName: "testtube.2")
                        .foregroundColor(.orange)
                }
                .disabled(viewModel.isLoading)

                Button(action: {
                    viewModel.loadProduct(productId: productId)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                .disabled(viewModel.isLoading)
            }
        )
        .onAppear {
            NSLog("🔍 [MallOfLebanon] ProductDetailView onAppear with productId: \(productId)")
            NSLog("🔍 [MallOfLebanon] ProductDetailView productId type: \(productId.count == 24 ? "MongoDB ObjectId" : "Likely Slug/Custom ID")")
            viewModel.loadProduct(productId: productId)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(isPresented: $viewModel.showingImageViewer) {
            if let product = viewModel.product {
                ProductImageViewer(
                    images: viewModel.currentImages,
                    selectedIndex: $viewModel.selectedImageIndex,
                    isPresented: $viewModel.showingImageViewer
                )
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            if let errorMessage = viewModel.errorMessage, errorMessage.contains("retrying") {
                Text(errorMessage)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            } else {
                Text("Loading product...")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .frame(maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Failed to load product")
                .font(.headline)

            Text(viewModel.errorMessage ?? "Please try again")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                viewModel.loadProduct(productId: productId)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func addToCart() {
        guard let product = viewModel.product else { return }

        // Create cart item with customizations
        let selectedCustomizations = getSelectedCustomizationDetails()

        // Debug logging
        print("🛒 [DEBUG] Adding to cart - customizations: \(selectedCustomizations)")
        for customization in selectedCustomizations {
            print("🛒 [DEBUG] Customization: \(customization.customizationName), Option: \(customization.optionLabel), Value: \(customization.optionValue)")
        }

        let cartProduct = CartProductItem(
            product: product,
            selectedCustomizations: selectedCustomizations,
            calculatedPrice: viewModel.calculatedPrice
        )

        cartManager.addProduct(cartProduct, quantity: viewModel.quantity)

        // Show success feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    private func buyNow() {
        addToCart()
        // Navigate directly to checkout
        // This would typically be handled by the navigation coordinator
        // For now, we'll just add to cart and let user navigate manually
        presentationMode.wrappedValue.dismiss()
    }

    private func getSelectedCustomizationDetails() -> [CustomizationSelection] {
        guard let product = viewModel.product,
              let customizations = product.customizationOptions else { return [] }

        var selections: [CustomizationSelection] = []

        for customization in customizations {
            if customization.type == "single",
               let selectedId = viewModel.selectedCustomizations[customization.id] as? String,
               let option = customization.options.first(where: { $0.id == selectedId }) {
                selections.append(
                    CustomizationSelection(
                        customizationId: customization.id,
                        customizationName: customization.name,
                        optionId: option.id,
                        optionLabel: option.label,
                        optionValue: option.value,
                        priceModifier: option.priceModifier
                    )
                )
            } else if customization.type == "multiple",
                      let selectedIds = viewModel.selectedCustomizations[customization.id] as? [String] {
                for selectedId in selectedIds {
                    if let option = customization.options.first(where: { $0.id == selectedId }) {
                        selections.append(
                            CustomizationSelection(
                                customizationId: customization.id,
                                customizationName: customization.name,
                                optionId: option.id,
                                optionLabel: option.label,
                                optionValue: option.value,
                                priceModifier: option.priceModifier
                            )
                        )
                    }
                }
            }
        }

        return selections
    }

    private func refreshProduct() async {
        viewModel.loadProduct(productId: productId)
    }
}

// MARK: - Product Image Gallery
struct ProductImageGallery: View {
    let images: [String]
    @Binding var selectedIndex: Int
    @Binding var showingImageViewer: Bool
    let discountPercentage: Int?

    @State private var displayedImageUrl: String = ""

    // Safe index to prevent array out-of-bounds crashes
    private var safeSelectedIndex: Int {
        guard !images.isEmpty else { return 0 }
        return max(0, min(selectedIndex, images.count - 1))
    }

    private var currentImageUrl: String {
        guard !images.isEmpty else { return "" }
        return images[safeSelectedIndex]
    }

    var body: some View {
        VStack(spacing: 12) {
            // Main Image
            ZStack {
                CachedImageView(
                    url: URL(string: currentImageUrl),
                    placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(1.5)
                            )
                    },
                    failureView: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 40))
                            )
                    }
                )
                .id(currentImageUrl)
                .aspectRatio(contentMode: .fit)
                .frame(height: 300)
                .background(Color.white)
                .cornerRadius(12)
                .onTapGesture {
                    showingImageViewer = true
                }

                // Discount Badge
                if let discount = discountPercentage, discount > 0 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("-\(discount)%")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        Spacer()
                    }
                    .padding()
                }
            }

            // Thumbnail Images
            if images.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, imageUrl in
                            CachedImageView(
                                url: URL(string: imageUrl),
                                placeholder: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            ProgressView()
                                                .scaleEffect(0.6)
                                        )
                                },
                                failureView: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                        )
                                }
                            )
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        safeSelectedIndex == index ? Color.blue : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .onTapGesture {
                                if index >= 0 && index < images.count {
                                    selectedIndex = index
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 16)
        .onAppear {
            displayedImageUrl = currentImageUrl
            NSLog("🖼️ [MallOfLebanon] ProductImageGallery onAppear - images count: \(images.count), selectedIndex: \(selectedIndex), currentImageUrl: \(currentImageUrl)")
        }
        .onChange(of: selectedIndex) { newIndex in
            NSLog("🖼️ [MallOfLebanon] ProductImageGallery selectedIndex changed from ? to \(newIndex), currentImageUrl: \(currentImageUrl)")
            displayedImageUrl = currentImageUrl
        }
        .onChange(of: images) { newImages in
            NSLog("🖼️ [MallOfLebanon] ProductImageGallery images changed - new count: \(newImages.count), selectedIndex: \(selectedIndex)")
            displayedImageUrl = currentImageUrl
        }
    }
}

// MARK: - Product Information Section
struct ProductInformationSection: View {
    let product: Product
    let calculatedPrice: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Product Name
            Text(product.name)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(3)

            // Seller
            Text("Sold by \(product.sellerName)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Rating
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= Int(product.rating) ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }

                Text("\(product.rating, specifier: "%.1f")")
                    .font(.caption)
                    .fontWeight(.medium)

                Text("(\(product.reviewCount) reviews)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            // Price Section
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text("$\(calculatedPrice, specifier: "%.2f")")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    if let originalPrice = product.originalPrice, originalPrice > product.price {
                        Text("$\(originalPrice, specifier: "%.2f")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .strikethrough()
                    }

                    Spacer()
                }

                if calculatedPrice != product.price {
                    Text("Base price: $\(product.price, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Description
            Text(product.description)
                .font(.body)
                .lineLimit(nil)
                .padding(.top, 8)

            // Tags
            if !product.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(product.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
            }
        }
    }
}

// MARK: - Supporting Models are in CartProductModels.swift

struct ProductDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProductDetailView(productId: "sample-product-id")
                .environmentObject(CartManager.shared)
        }
    }
}