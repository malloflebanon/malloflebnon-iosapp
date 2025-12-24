import SwiftUI

// MARK: - Product Customization Section
struct ProductCustomizationSection: View {
    let customizations: [ProductCustomization]
    @Binding var selectedCustomizations: [String: Any]
    let onCustomizationChanged: (String, String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Customize Your Product")
                .font(.headline)
                .fontWeight(.semibold)

            ForEach(customizations) { customization in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(customization.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if customization.required {
                            Text("*")
                                .foregroundColor(.red)
                                .fontWeight(.bold)
                        }

                        Spacer()
                    }

                    if customization.type == "single" {
                        SingleSelectionOptions(
                            customization: customization,
                            selectedValue: selectedCustomizations[customization.id] as? String,
                            onSelectionChanged: { optionId in
                                onCustomizationChanged(customization.id, optionId, true)
                            }
                        )
                    } else {
                        MultipleSelectionOptions(
                            customization: customization,
                            selectedValues: selectedCustomizations[customization.id] as? [String] ?? [],
                            onSelectionChanged: { optionId in
                                onCustomizationChanged(customization.id, optionId, true)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct SingleSelectionOptions: View {
    let customization: ProductCustomization
    let selectedValue: String?
    let onSelectionChanged: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(customization.options) { option in
                OptionButton(
                    option: option,
                    isSelected: selectedValue == option.id,
                    isDisabled: (option.stockQuantity ?? 0) == 0
                ) {
                    onSelectionChanged(option.id)
                }
            }
        }
    }
}

struct MultipleSelectionOptions: View {
    let customization: ProductCustomization
    let selectedValues: [String]
    let onSelectionChanged: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(customization.options) { option in
                OptionButton(
                    option: option,
                    isSelected: selectedValues.contains(option.id),
                    isDisabled: (option.stockQuantity ?? 0) == 0
                ) {
                    onSelectionChanged(option.id)
                }
            }
        }
    }
}

struct OptionButton: View {
    let option: CustomizationOption
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(option.label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if option.priceModifier != 0 {
                    Text(option.priceModifier > 0 ? "+$\(option.priceModifier, specifier: "%.2f")" : "-$\(abs(option.priceModifier), specifier: "%.2f")")
                        .font(.caption2)
                        .foregroundColor(option.priceModifier > 0 ? .red : .green)
                }

                if let stock = option.stockQuantity, stock <= 5 && stock > 0 {
                    Text("Only \(stock) left")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .frame(minHeight: 60)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                isSelected ?
                Color.blue.opacity(0.1) :
                Color.gray.opacity(0.1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.blue : Color.clear,
                        lineWidth: 2
                    )
            )
            .cornerRadius(8)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isDisabled)
    }
}

// MARK: - Product Purchase Section
struct ProductPurchaseSection: View {
    let product: Product
    @ObservedObject var viewModel: ProductDetailViewModel
    let onAddToCart: () -> Void
    let onBuyNow: () -> Void

    private var availableStock: Int {
        viewModel.getAvailableStock()
    }

    private var canPurchase: Bool {
        viewModel.canAddToCart()
    }

    private var validationError: String? {
        viewModel.getValidationError()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stock Status
            HStack {
                if availableStock > 0 {
                    if viewModel.areRequiredCustomizationsSelected() {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("In Stock (\(availableStock) available)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.orange)
                            Text("Select options to check availability")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Out of Stock")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                }

                Spacer()
            }

            // Validation Error
            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            // Quantity Selector
            if canPurchase {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quantity")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 12) {
                            Button(action: {
                                viewModel.decreaseQuantity()
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(width: 32, height: 32)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .disabled(viewModel.quantity <= 1)

                            Text("\(viewModel.quantity)")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(minWidth: 30)

                            Button(action: {
                                viewModel.increaseQuantity()
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(width: 32, height: 32)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .disabled(viewModel.quantity >= availableStock)
                        }
                    }

                    Spacer()
                }

                // Purchase Buttons
                VStack(spacing: 12) {
                    Button(action: onAddToCart) {
                        HStack {
                            Image(systemName: "cart.badge.plus")
                            Text("Add to Cart")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }
                    .disabled(!canPurchase)

                    Button(action: onBuyNow) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Buy Now")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(!canPurchase)
                }
            }
        }
    }
}

// MARK: - Product Details Tab Section
struct ProductDetailsTabSection: View {
    let product: Product
    @ObservedObject var viewModel: ProductDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Tab Headers
            HStack(spacing: 0) {
                ForEach(ProductDetailViewModel.DetailTab.allCases, id: \.self) { tab in
                    Button(action: {
                        viewModel.activeTab = tab
                        if tab == .reviews && viewModel.reviews.isEmpty {
                            viewModel.loadReviews()
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(tab.title)
                                .font(.subheadline)
                                .fontWeight(viewModel.activeTab == tab ? .semibold : .regular)
                                .foregroundColor(viewModel.activeTab == tab ? .blue : .secondary)

                            Rectangle()
                                .fill(viewModel.activeTab == tab ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 20)

            // Tab Content
            Group {
                if viewModel.activeTab == .specifications {
                    ProductSpecificationsView(product: product)
                } else {
                    ProductReviewsView(
                        product: product,
                        reviews: viewModel.reviews,
                        isLoading: viewModel.isLoadingReviews
                    )
                }
            }
        }
    }
}

// MARK: - Product Specifications View
struct ProductSpecificationsView: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category-specific fields from categoryFields
            if let categoryFields = product.categoryFields, !categoryFields.isEmpty {
                ForEach(Array(categoryFields.keys.sorted()), id: \.self) { key in
                    if let value = categoryFields[key]?.value as? String {
                        SpecificationRow(label: key.capitalized, value: value)
                    }
                }

                Divider()
                    .padding(.vertical, 4)
            }

            // Additional fields from matchingData
            if let matchingData = product.matchingData?.value as? [String: Any], !matchingData.isEmpty {
                ForEach(Array(matchingData.keys.sorted()), id: \.self) { key in
                    if let value = matchingData[key] as? String {
                        SpecificationRow(label: key.capitalized, value: value)
                    }
                }

                Divider()
                    .padding(.vertical, 4)
            }

            // General specifications
            if let specifications = product.specifications, !specifications.isEmpty {
                ForEach(Array(specifications.keys.sorted()), id: \.self) { key in
                    if let value = specifications[key]?.value as? String {
                        SpecificationRow(label: key.capitalized, value: value)
                    }
                }
            }

            // Basic product info
            Divider()
                .padding(.vertical, 8)

            Text("Product Information")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.bottom, 8)

            SpecificationRow(label: "SKU", value: product.sku)
            SpecificationRow(label: "Category", value: product.category + (product.subcategory != nil ? " - \(product.subcategory!)" : ""))
            SpecificationRow(label: "Brand", value: product.brand ?? "N/A")

            if product.specifications?.isEmpty ?? true &&
               product.categoryFields?.isEmpty ?? true &&
               (product.matchingData?.value as? [String: Any])?.isEmpty ?? true {
                Text("No detailed specifications available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct SpecificationRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(minWidth: 80, alignment: .leading)

            Text(value)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Product Reviews View
struct ProductReviewsView: View {
    let product: Product
    let reviews: [ProductReview]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading reviews...")
                    Spacer()
                }
                .padding()
            } else if reviews.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "star")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)

                    Text("No Reviews Yet")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Be the first to review this product!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Rating Summary
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(product.rating, specifier: "%.1f")")
                            .font(.title)
                            .fontWeight(.bold)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= Int(product.rating) ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                }
                            }

                            Text("Based on \(product.reviewCount) review\(product.reviewCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }
                .padding(.bottom, 16)

                Divider()

                // Reviews List
                ForEach(reviews) { review in
                    ReviewItemView(review: review)
                        .padding(.bottom, 12)
                }
            }
        }
    }
}

struct ReviewItemView: View {
    let review: ProductReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(review.userName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if review.isVerifiedPurchase {
                    Text("✓ Verified")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }

                Spacer()

                Text(formatDate(review.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= review.rating ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }

            Text(review.comment)
                .font(.subheadline)
                .lineLimit(nil)

            if review.helpful > 0 {
                Text("\(review.helpful) people found this helpful")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}