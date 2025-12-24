import Foundation
import SwiftUI

@MainActor
class ProductDetailViewModel: ObservableObject {
    @Published var product: Product?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedImageIndex = 0
    @Published var quantity = 1
    @Published var selectedCustomizations: [String: Any] = [:]
    @Published var calculatedPrice: Double = 0.0
    @Published var isInWishlist = false
    @Published var reviews: [ProductReview] = []
    @Published var isLoadingReviews = false
    @Published var showingImageViewer = false
    @Published var activeTab: DetailTab = .specifications
    @Published var currentImages: [String] = []

    private let apiService = APIService.shared

    enum DetailTab: CaseIterable {
        case specifications
        case reviews

        var title: String {
            switch self {
            case .specifications: return "Specifications"
            case .reviews: return "Reviews"
            }
        }
    }

    // MARK: - Product Loading

    func loadProduct(productId: String) {
        NSLog("🔧 [MallOfLebanon] DEBUG: Loading product with ID: \(productId)")
        Task {
            isLoading = true
            errorMessage = nil

            do {
                let response = try await apiService.fetchProduct(id: productId)

                await MainActor.run {
                    if response.success {
                        product = response.product
                        calculatedPrice = response.product.price
                        initializeCustomizations()
                    } else {
                        errorMessage = "Failed to load product details"
                    }
                    isLoading = false
                }
            } catch {
                NSLog("🔧 [MallOfLebanon] DEBUG: Error loading product \(productId): \(error)")
                await MainActor.run {
                    // Check if this might be an authentication error
                    let errorMessage = error.localizedDescription
                    if errorMessage.contains("Product not found") {
                        self.errorMessage = "This product is no longer available. Please try refreshing the product list."
                    } else if errorMessage.contains("Access token required") || errorMessage.contains("token") {
                        self.errorMessage = "Product details require login. Please log in or contact support for access."
                    } else if errorMessage.contains("timeout") || errorMessage.contains("network") {
                        self.errorMessage = "Network timeout. Please check your connection and try again."
                    } else {
                        self.errorMessage = "Unable to load product details. Please try again or contact support."
                    }
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Customization Management

    private func initializeCustomizations() {
        guard let product = product else { return }

        selectedCustomizations.removeAll()

        // Initialize currentImages with product.images first
        currentImages = product.images

        for customization in product.customizationOptions ?? [] {
            switch customization.type {
            case "single":
                // Select first default option or first available option
                if let defaultOption = customization.options.first(where: { $0.isDefault }) {
                    selectedCustomizations[customization.id] = defaultOption.id
                } else if let firstOption = customization.options.first {
                    selectedCustomizations[customization.id] = firstOption.id
                }
            case "multiple":
                // Select all default options
                let defaultOptions = customization.options.filter { $0.isDefault }.map { $0.id }
                if !defaultOptions.isEmpty {
                    selectedCustomizations[customization.id] = defaultOptions
                }
            default:
                break
            }
        }

        updateCurrentImages()
        updateCalculatedPrice()
    }

    func updateCustomization(customizationId: String, optionId: String, isSelected: Bool) {
        guard let product = product,
              let customization = product.customizationOptions?.first(where: { $0.id == customizationId }) else {
            return
        }

        switch customization.type {
        case "single":
            if isSelected {
                selectedCustomizations[customizationId] = optionId
            } else {
                selectedCustomizations.removeValue(forKey: customizationId)
            }

        case "multiple":
            var selectedOptions = selectedCustomizations[customizationId] as? [String] ?? []

            if isSelected {
                if !selectedOptions.contains(optionId) {
                    selectedOptions.append(optionId)
                }
            } else {
                selectedOptions.removeAll { $0 == optionId }
            }

            if selectedOptions.isEmpty {
                selectedCustomizations.removeValue(forKey: customizationId)
            } else {
                selectedCustomizations[customizationId] = selectedOptions
            }

        default:
            break
        }

        updateCurrentImages()
        updateCalculatedPrice()
    }

    private func updateCalculatedPrice() {
        guard let product = product else { return }

        var price = product.price

        for customization in product.customizationOptions ?? [] {
            switch customization.type {
            case "single":
                if let selectedOptionId = selectedCustomizations[customization.id] as? String,
                   let option = customization.options.first(where: { $0.id == selectedOptionId }) {
                    price += option.priceModifier
                }

            case "multiple":
                if let selectedOptionIds = selectedCustomizations[customization.id] as? [String] {
                    for optionId in selectedOptionIds {
                        if let option = customization.options.first(where: { $0.id == optionId }) {
                            price += option.priceModifier
                        }
                    }
                }

            default:
                break
            }
        }

        calculatedPrice = max(0, price)
    }

    // Get current images based on color selection for Clothing & Fashion products
    private func getCurrentImages() -> [String] {
        guard let product = product else { return [] }

        // For non-Clothing & Fashion products, return main images
        if product.category != "Clothing & Fashion" {
            return product.images
        }

        // Find color customization
        guard let colorCustomization = product.customizationOptions?.first(where: { $0.name == "Color" }) else {
            return product.images
        }

        // Get selected color
        guard let selectedColorId = selectedCustomizations[colorCustomization.id] as? String else {
            return product.images
        }

        // Find selected color option
        guard let selectedColorOption = colorCustomization.options.first(where: { $0.id == selectedColorId }) else {
            return product.images
        }

        // Return color-specific images if available, otherwise use main images
        if let colorImages = selectedColorOption.images, !colorImages.isEmpty {
            return colorImages.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }

        return product.images
    }

    private func updateCurrentImages() {
        let newImages = getCurrentImages()
        let previousImages = currentImages

        NSLog("🔄 [MallOfLebanon] updateCurrentImages - previous count: \(previousImages.count), new count: \(newImages.count)")
        NSLog("🔄 [MallOfLebanon] updateCurrentImages - selectedIndex: \(selectedImageIndex)")
        NSLog("🔄 [MallOfLebanon] updateCurrentImages - first new image: \(newImages.first ?? "none")")

        currentImages = newImages

        // Only reset selected image index if current index is out of bounds
        // This preserves user's image selection when switching between color variations
        if !newImages.isEmpty {
            if selectedImageIndex >= newImages.count {
                NSLog("🔄 [MallOfLebanon] updateCurrentImages - resetting selectedIndex from \(selectedImageIndex) to 0 (out of bounds)")
                selectedImageIndex = 0
            }
        } else {
            NSLog("🔄 [MallOfLebanon] updateCurrentImages - resetting selectedIndex to 0 (no images)")
            selectedImageIndex = 0
        }
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Wishlist Management

    func toggleWishlist() {
        // TODO: Implement wishlist functionality
        isInWishlist.toggle()
    }

    // MARK: - Reviews

    func loadReviews() {
        guard product != nil else { return }

        Task {
            isLoadingReviews = true

            // TODO: Implement reviews loading
            // For now, simulate loading
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            await MainActor.run {
                reviews = []
                isLoadingReviews = false
            }
        }
    }

    // MARK: - Validation

    func canAddToCart() -> Bool {
        guard let product = product else { return false }

        // Check if product is in stock
        guard product.inStock && product.quantity > 0 else { return false }

        // Check if required customizations are selected
        for customization in product.customizationOptions ?? [] where customization.required {
            switch customization.type {
            case "single":
                if selectedCustomizations[customization.id] as? String == nil {
                    return false
                }
            case "multiple":
                let selectedOptions = selectedCustomizations[customization.id] as? [String] ?? []
                if selectedOptions.isEmpty {
                    return false
                }
            default:
                break
            }
        }

        return true
    }

    var validationMessage: String? {
        guard let product = product else { return nil }

        if !product.inStock {
            return "This product is currently out of stock"
        }

        if product.quantity <= 0 {
            return "This product is not available"
        }

        // Check for missing required customizations
        for customization in product.customizationOptions ?? [] where customization.required {
            switch customization.type {
            case "single":
                if selectedCustomizations[customization.id] as? String == nil {
                    return "Please select \(customization.name)"
                }
            case "multiple":
                let selectedOptions = selectedCustomizations[customization.id] as? [String] ?? []
                if selectedOptions.isEmpty {
                    return "Please select at least one option for \(customization.name)"
                }
            default:
                break
            }
        }

        return nil
    }

    // MARK: - Additional Helper Methods

    func getAvailableStock() -> Int {
        guard let product = product else { return 0 }
        return product.quantity
    }

    func getValidationError() -> String? {
        return validationMessage
    }

    func areRequiredCustomizationsSelected() -> Bool {
        guard let product = product else { return false }

        for customization in product.customizationOptions ?? [] where customization.required {
            switch customization.type {
            case "single":
                if selectedCustomizations[customization.id] as? String == nil {
                    return false
                }
            case "multiple":
                let selectedOptions = selectedCustomizations[customization.id] as? [String] ?? []
                if selectedOptions.isEmpty {
                    return false
                }
            default:
                break
            }
        }

        return true
    }

    func increaseQuantity() {
        guard let product = product else { return }
        if quantity < product.quantity {
            quantity += 1
        }
    }

    func decreaseQuantity() {
        if quantity > 1 {
            quantity -= 1
        }
    }

    // MARK: - Debug Test Methods
    func testLoadKnownValidProduct() {
        NSLog("🧪 [MallOfLebanon] TEST: Loading known valid product: prod_1766228431645_n38gftzcx")
        loadProduct(productId: "prod_1766228431645_n38gftzcx")
    }
}

// MARK: - Supporting Models

struct ProductReview: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let rating: Int
    let comment: String
    let createdAt: Date
    let isVerified: Bool
    let isVerifiedPurchase: Bool
    let helpful: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        userName = try container.decode(String.self, forKey: .userName)
        rating = try container.decode(Int.self, forKey: .rating)
        comment = try container.decode(String.self, forKey: .comment)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        isVerifiedPurchase = try container.decodeIfPresent(Bool.self, forKey: .isVerifiedPurchase) ?? isVerified
        helpful = try container.decodeIfPresent(Int.self, forKey: .helpful) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, userId, userName, rating, comment, createdAt, isVerified, isVerifiedPurchase, helpful
    }
}