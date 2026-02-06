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

                        // Installment Plans
                        if viewModel.hasInstallmentPlans {
                            InstallmentPlansSection(
                                product: viewModel.product!,
                                calculatedPrice: viewModel.calculatedPrice,
                                selectedInstallmentPlan: $viewModel.selectedInstallmentPlan,
                                showInstallmentPlans: $viewModel.showInstallmentPlans
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
        .overlay(
            // Cart Conflict Modal
            Group {
                if viewModel.showCartConflictModal, let conflictInfo = viewModel.cartConflictInfo {
                    CartConflictModalView(
                        conflictInfo: conflictInfo,
                        onClearCartAndAdd: {
                            viewModel.handleCartConflictAction(.clearCartAndAdd)
                        },
                        onContinueToCheckout: {
                            viewModel.handleCartConflictAction(.continueToCheckout)
                        },
                        onCancel: {
                            viewModel.handleCartConflictAction(.cancel)
                        }
                    )
                }
            }
        )
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
        NSLog("🛒 [MallOfLebanon] Adding product to cart with installment support")

        guard let product = viewModel.product else {
            NSLog("❌ [MallOfLebanon] Cannot add to cart - product is nil")
            return
        }

        // Validate that product can be added to cart
        guard viewModel.canAddToCart() else {
            NSLog("❌ [MallOfLebanon] Cannot add to cart - validation failed")
            return
        }

        // Use the new installment-aware add to cart method
        viewModel.addToCartWithInstallment()

        // Show success feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Reset quantity after adding to cart
        viewModel.quantity = 1
    }

    private func buyNow() {
        NSLog("🛒 [MallOfLebanon] Buy now with installment support")

        guard let product = viewModel.product else {
            NSLog("❌ [MallOfLebanon] Cannot buy now - product is nil")
            return
        }

        // Validate that product can be added to cart
        guard viewModel.canAddToCart() else {
            NSLog("❌ [MallOfLebanon] Cannot buy now - validation failed")
            return
        }

        // Use the new installment-aware buy now method
        viewModel.buyNowWithInstallment()

        // Show success feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Navigate to checkout (for now just dismiss)
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

// MARK: - Inline Installment Components

// Simple InstallmentPlan struct for UI purposes
struct SimpleInstallmentPlan: Identifiable {
    let id: String
    let planName: String
    let duration: Int
    let downPaymentPercentage: Double
    let interestRate: Double
    let minimumOrderAmount: Double
    let processingFeePercentage: Double
    let processingFeeFixed: Double?
    let description: String?

    func calculatePayments(orderAmount: Double) -> InstallmentCalculation {
        let downPayment = (orderAmount * downPaymentPercentage) / 100
        let remainingAmount = orderAmount - downPayment

        // Calculate processing fee - use fixed fee if available, otherwise percentage
        var processingFee = orderAmount * (processingFeePercentage / 100)
        if let fixedFee = processingFeeFixed {
            processingFee += fixedFee
        }

        // Calculate interest using frontend logic: annual rate / 12 months * duration
        var totalWithInterest = remainingAmount
        var totalInterest: Double = 0
        if interestRate > 0 {
            let monthlyRate = interestRate / 100 / 12
            totalInterest = remainingAmount * monthlyRate * Double(duration)
            totalWithInterest = remainingAmount + totalInterest
        }

        let monthlyPayment = totalWithInterest / Double(duration)
        let totalAmount = downPayment + totalWithInterest + processingFee

        return InstallmentCalculation(
            downPayment: round(downPayment * 100) / 100,
            monthlyPayment: round(monthlyPayment * 100) / 100,
            totalAmount: round(totalAmount * 100) / 100,
            totalInterest: round(totalInterest * 100) / 100,
            processingFee: round(processingFee * 100) / 100
        )
    }
}

struct InstallmentCalculation {
    let downPayment: Double
    let monthlyPayment: Double
    let totalAmount: Double
    let totalInterest: Double
    let processingFee: Double
}

struct InstallmentPlansSection: View {
    let product: Product
    let calculatedPrice: Double
    @Binding var selectedInstallmentPlan: InstallmentPlanSelection?
    @Binding var showInstallmentPlans: Bool

    private var eligiblePlans: [SimpleInstallmentPlan] {
        // Get installment plans from product API data instead of hardcoded values
        guard let apiPlans = product.installmentPlans else {
            return []
        }

        return apiPlans.compactMap { planDict -> SimpleInstallmentPlan? in
            // Extract values from the dictionary
            guard let id = planDict["id"] as? String,
                  let planName = planDict["planName"] as? String,
                  let duration = planDict["duration"] as? Int,
                  let isActive = planDict["isActive"] as? Bool else {
                return nil
            }

            // Handle numeric fields that could be Int or Double
            let downPaymentPercentage: Double = {
                if let doubleValue = planDict["downPaymentPercentage"] as? Double {
                    return doubleValue
                } else if let intValue = planDict["downPaymentPercentage"] as? Int {
                    return Double(intValue)
                }
                return 0.0
            }()

            let interestRate: Double = {
                if let doubleValue = planDict["interestRate"] as? Double {
                    return doubleValue
                } else if let intValue = planDict["interestRate"] as? Int {
                    return Double(intValue)
                }
                return 0.0
            }()

            let minimumOrderAmount: Double = {
                if let doubleValue = planDict["minimumOrderAmount"] as? Double {
                    return doubleValue
                } else if let intValue = planDict["minimumOrderAmount"] as? Int {
                    return Double(intValue)
                }
                return 0.0
            }()

            // Only show plans that are active and meet minimum order requirements
            guard isActive && calculatedPrice >= minimumOrderAmount else {
                return nil
            }

            // Also check maximum order amount if it exists - handle Int or Double
            if let maxAmountDouble = planDict["maximumOrderAmount"] as? Double, calculatedPrice > maxAmountDouble {
                return nil
            } else if let maxAmountInt = planDict["maximumOrderAmount"] as? Int, calculatedPrice > Double(maxAmountInt) {
                return nil
            }

            // Handle processing fee fields that could be Int or Double
            let processingFeePercentage: Double = {
                if let doubleValue = planDict["processingFeePercentage"] as? Double {
                    return doubleValue
                } else if let intValue = planDict["processingFeePercentage"] as? Int {
                    return Double(intValue)
                }
                return 0.0
            }()

            let processingFeeFixed: Double? = {
                if let doubleValue = planDict["processingFee"] as? Double {
                    return doubleValue
                } else if let intValue = planDict["processingFee"] as? Int {
                    return Double(intValue)
                }
                // Also try processingFeeFixed field for compatibility
                if let doubleValue = planDict["processingFeeFixed"] as? Double {
                    return doubleValue
                } else if let intValue = planDict["processingFeeFixed"] as? Int {
                    return Double(intValue)
                }
                return nil
            }()

            return SimpleInstallmentPlan(
                id: id,
                planName: planName,
                duration: duration,
                downPaymentPercentage: downPaymentPercentage,
                interestRate: interestRate,
                minimumOrderAmount: minimumOrderAmount,
                processingFeePercentage: processingFeePercentage,
                processingFeeFixed: processingFeeFixed,
                description: planDict["description"] as? String
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.blue)
                Text("Installment Plans Available")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()

                Button(action: {
                    showInstallmentPlans.toggle()
                }) {
                    Image(systemName: showInstallmentPlans ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture {
                showInstallmentPlans.toggle()
            }

            if showInstallmentPlans {
                VStack(spacing: 12) {
                    ForEach(eligiblePlans) { plan in
                        InstallmentPlanRowView(
                            plan: plan,
                            calculatedPrice: calculatedPrice,
                            isSelected: selectedInstallmentPlan?.planId == plan.id,
                            onSelect: {
                                selectPlan(plan)
                            }
                        )
                    }

                    if eligiblePlans.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.title2)
                            Text("No installment plans available for this amount")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Text("Minimum order amount: $200.00")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func selectPlan(_ plan: SimpleInstallmentPlan) {
        let calculation = plan.calculatePayments(orderAmount: calculatedPrice)

        selectedInstallmentPlan = InstallmentPlanSelection(
            planId: plan.id,
            planName: plan.planName,
            duration: plan.duration,
            downPaymentPercentage: plan.downPaymentPercentage,
            interestRate: plan.interestRate,
            minimumOrderAmount: plan.minimumOrderAmount,
            downPayment: calculation.downPayment,
            monthlyPayment: calculation.monthlyPayment,
            totalAmount: calculation.totalAmount,
            totalInterest: calculation.totalInterest,
            processingFee: calculation.processingFee,
            description: plan.description
        )
    }
}

struct InstallmentPlanRowView: View {
    let plan: SimpleInstallmentPlan
    let calculatedPrice: Double
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        let calculation = plan.calculatePayments(orderAmount: calculatedPrice)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.planName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("\(plan.duration) months • \(plan.interestRate, specifier: "%.1f")% interest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(calculation.monthlyPayment, specifier: "%.2f")")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)

                    Text("per month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Down Payment: $\(calculation.downPayment, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("(\(plan.downPaymentPercentage, specifier: "%.0f")%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Total Amount: $\(calculation.totalAmount, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("includes $\(calculation.totalInterest, specifier: "%.2f") interest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 8)

            if let description = plan.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }

            Button(action: onSelect) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)

                    Text(isSelected ? "Selected" : "Select Plan")
                        .fontWeight(isSelected ? .semibold : .medium)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.05) : Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct CartConflictModalView: View {
    let conflictInfo: CartConflictInfo
    let onClearCartAndAdd: () -> Void
    let onContinueToCheckout: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)

                    Text("Cart Conflict")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(conflictInfo.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Button("Clear Cart & Add Item") {
                        onClearCartAndAdd()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    Button("Continue to Checkout") {
                        onContinueToCheckout()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    Button("Cancel") {
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 24)
        }
    }
}