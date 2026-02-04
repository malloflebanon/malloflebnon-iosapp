import Foundation
import Combine

class CartManager: ObservableObject {
    static let shared = CartManager()

    @Published var items: [CartItem] = []
    @Published var cartSummary: CartSummary = CartSummary(items: [])
    @Published var shippingCost: Double = 0.0
    @Published var isCalculatingShipping: Bool = false

    private let userDefaults = UserDefaults.standard
    private let apiService = APIService.shared
    private let cartStorageKey = "my_ecom_cart_v1"
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Force clear cart on startup to ensure we start with fresh structure
        print("🛒 [DEBUG] CartManager init - clearing cart to ensure fresh structure")
        items.removeAll()
        userDefaults.removeObject(forKey: cartStorageKey)
        loadCart()

        // Update summary whenever items change
        $items
            .map { CartSummary(items: $0) }
            .sink { [weak self] summary in
                self?.cartSummary = summary
            }
            .store(in: &cancellables)

        // Save cart whenever items change
        $items
            .sink { [weak self] items in
                self?.saveCart()
            }
            .store(in: &cancellables)

        // Calculate shipping whenever items change
        $items
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.calculateShipping()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func addItem(_ request: AddToCartRequest) {
        let newItem = request.generateCartItem()

        // Check if item with same configuration already exists
        if let existingIndex = items.firstIndex(where: { $0.id == newItem.id }) {
            // Update quantity of existing item
            items[existingIndex].quantity += newItem.quantity
        } else {
            // Add new item
            items.append(newItem)
        }

        print("Cart: Added \(newItem.name) (Qty: \(newItem.quantity)) to cart")
        print("Cart: Total items in cart: \(cartSummary.itemCount)")
    }

    // MARK: - Installment Support
    func addProductWithInstallment(
        _ product: Product,
        quantity: Int = 1,
        customizations: [CustomizationSelection]? = nil,
        installmentPlan: InstallmentPlanSelection? = nil
    ) {
        let newItem = CartItem.fromProduct(
            product,
            quantity: quantity,
            customizations: customizations,
            installmentPlan: installmentPlan
        )

        // Check if item with same configuration already exists
        if let existingIndex = items.firstIndex(where: { $0.id == newItem.id }) {
            // Update quantity of existing item
            items[existingIndex].quantity += newItem.quantity
        } else {
            // Add new item
            items.append(newItem)
        }

        let installmentText = installmentPlan != nil ? " with \(installmentPlan!.planName)" : ""
        print("Cart: Added \(newItem.name) (Qty: \(newItem.quantity))\(installmentText) to cart")
        print("Cart: Total items in cart: \(cartSummary.itemCount)")
    }

    func checkCartConflict(hasInstallmentPlan: Bool) -> CartConflictInfo {
        return cart.checkCartConflict(hasInstallmentPlan: hasInstallmentPlan)
    }

    var cartType: CartType {
        return cart.cartType
    }

    func updateInstallmentPlan(itemId: String, installmentPlan: InstallmentPlanSelection?) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }

        let currentItem = items[index]

        // Create new item with updated installment plan
        let updatedItem = CartItem(
            id: currentItem.id,
            productId: currentItem.productId,
            sellerId: currentItem.sellerId,
            name: currentItem.name,
            price: installmentPlan?.downPayment ?? currentItem.originalPrice ?? currentItem.price,
            originalPrice: currentItem.originalPrice,
            image: currentItem.image,
            quantity: currentItem.quantity,
            sku: currentItem.sku,
            sellerName: currentItem.sellerName,
            customizations: currentItem.customizations,
            maxStock: currentItem.maxStock,
            taxRate: currentItem.taxRate,
            installmentPlan: installmentPlan,
            hasInstallmentPlan: installmentPlan != nil,
            isRaffleTicket: currentItem.isRaffleTicket,
            raffleInfo: currentItem.raffleInfo
        )

        items[index] = updatedItem

        let installmentText = installmentPlan != nil ? " with \(installmentPlan!.planName)" : " (removed installment)"
        print("Cart: Updated \(updatedItem.name)\(installmentText)")
    }

    func addProduct(_ product: Product, quantity: Int = 1, customizations: [CustomizationSelection] = []) {
        let request = AddToCartRequest(product: product, quantity: quantity, customizations: customizations)
        addItem(request)
    }

    // New method for adding products with customization details
    func addProduct(_ cartProduct: CartProductItem, quantity: Int = 1) {
        // Use customization selections directly
        let customizations = cartProduct.selectedCustomizations.isEmpty ? nil : cartProduct.selectedCustomizations

        let cartItem = CartItem(
            id: generateCartItemId(productId: cartProduct.product.id, customizations: cartProduct.selectedCustomizations),
            productId: cartProduct.product.id,
            sellerId: cartProduct.product.sellerId,
            name: cartProduct.product.name,
            price: cartProduct.calculatedPrice,
            originalPrice: cartProduct.product.originalPrice,
            image: cartProduct.product.mainImage,
            quantity: quantity,
            sku: cartProduct.product.sku,
            sellerName: cartProduct.product.sellerName,
            customizations: customizations,
            maxStock: cartProduct.product.stockCount,
            taxRate: cartProduct.product.taxRate,
            installmentPlan: nil,
            hasInstallmentPlan: false,
            isRaffleTicket: cartProduct.product.isRaffleTicket ?? false,
            raffleInfo: cartProduct.product.raffleInfo.map { info in
                RaffleInfo(
                    raffleId: info.raffleId,
                    raffleTitle: info.raffleTitle,
                    ticketsPerPurchase: info.ticketsPerPurchase,
                    drawDate: info.drawDate
                )
            }
        )

        // Check if item with same configuration already exists
        if let existingIndex = items.firstIndex(where: { $0.id == cartItem.id }) {
            // Update quantity of existing item
            items[existingIndex].quantity += cartItem.quantity
        } else {
            // Add new item
            items.append(cartItem)
        }

        print("Cart: Added \(cartItem.name) (Qty: \(cartItem.quantity)) to cart")
        print("Cart: Total items in cart: \(cartSummary.itemCount)")
    }


    private func generateCartItemId(productId: String, customizations: [CustomizationSelection]) -> String {
        let customizationIds = customizations.map { "\($0.customizationId):\($0.optionId)" }.sorted()
        let baseId = productId + customizationIds.joined(separator: "-")
        return String(baseId.hashValue)
    }

    func removeItem(_ itemId: String) {
        items.removeAll { $0.id == itemId }
        print("Cart: Removed item \(itemId) from cart")
    }

    func updateQuantity(_ itemId: String, quantity: Int) {
        if quantity <= 0 {
            removeItem(itemId)
            return
        }

        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].quantity = quantity
            print("Cart: Updated item \(itemId) quantity to \(quantity)")
        }
    }

    func updateItemQuantity(itemId: String, quantity: Int) {
        updateQuantity(itemId, quantity: quantity)
    }

    func clearCart() {
        items.removeAll()
        saveCart() // Save the empty cart to storage
        print("Cart: Cleared all items and saved to storage")
    }

    func getItem(by id: String) -> CartItem? {
        return items.first { $0.id == id }
    }

    func isProductInCart(_ productId: String) -> Bool {
        return items.contains { $0.productId == productId }
    }

    func getProductQuantityInCart(_ productId: String) -> Int {
        return items
            .filter { $0.productId == productId }
            .reduce(0) { $0 + $1.quantity }
    }

    // MARK: - Computed Properties

    var cart: Cart {
        return Cart(items: items)
    }

    var isEmpty: Bool {
        return items.isEmpty
    }

    var itemCount: Int {
        return cartSummary.itemCount
    }

    var subtotal: Double {
        return cartSummary.subtotal
    }

    var total: Double {
        return cartSummary.total
    }

    // MARK: - Persistence

    private func saveCart() {
        let cartStorage = CartStorage(items: items)
        if let encoded = try? JSONEncoder().encode(cartStorage) {
            userDefaults.set(encoded, forKey: cartStorageKey)
            print("Cart: Saved \(items.count) items to storage")
        } else {
            print("Cart: Failed to encode cart for storage")
        }
    }

    private func loadCart() {
        guard let data = userDefaults.data(forKey: cartStorageKey) else {
            print("Cart: No saved cart found")
            return
        }

        do {
            let cartStorage = try JSONDecoder().decode(CartStorage.self, from: data)
            self.items = cartStorage.items
            print("Cart: Loaded \(items.count) items from storage")

            // Check if cart is older than 30 days and clear if so
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            if cartStorage.lastUpdated < thirtyDaysAgo {
                clearCart()
                print("Cart: Cleared old cart (older than 30 days)")
            }
        } catch {
            print("Cart: Failed to decode saved cart: \(error)")
            // Clear corrupted cart data
            userDefaults.removeObject(forKey: cartStorageKey)
        }
    }

    // MARK: - Cart Validation

    func validateCart() {
        // Remove items that are no longer valid (e.g., out of stock, deleted products)
        // This would typically involve API calls to check product availability
        // For now, we'll just ensure all items have valid data

        items = items.filter { item in
            return !item.name.isEmpty && item.price > 0 && item.quantity > 0
        }
    }

    // MARK: - Shipping Calculation

    @MainActor
    func calculateShipping() async {
        guard !items.isEmpty else {
            shippingCost = 0.0
            return
        }

        isCalculatingShipping = true

        do {
            let shippingItems = items.map { item in
                ShippingItem(
                    sellerId: item.sellerId,
                    sellerName: item.sellerName,
                    price: item.price,
                    quantity: item.quantity
                )
            }

            let shippingRequest = ShippingCalculationRequest(items: shippingItems)
            let response = try await apiService.calculateShippingAsync(shippingRequest)

            if response.success {
                shippingCost = response.totalShipping
                print("📦 [DEBUG] Calculated shipping cost: $\(shippingCost)")
            } else {
                print("⚠️ [DEBUG] Shipping calculation failed, using fallback cost")
                shippingCost = 5.0 // Fallback to $5 if calculation fails
            }
        } catch {
            print("❌ [DEBUG] Error calculating shipping: \(error)")
            shippingCost = 5.0 // Fallback to $5 on error
        }

        isCalculatingShipping = false
    }

    func getShippingCost(for deliveryMethod: DeliveryMethod) -> Double {
        switch deliveryMethod {
        case .storePickup:
            return 0.0
        case .homeDelivery:
            return shippingCost
        }
    }

    var totalWithShipping: Double {
        return subtotal + shippingCost
    }

    // MARK: - Checkout Helpers

    func getItemsByVendor() -> [String: [CartItem]] {
        return Dictionary(grouping: items) { $0.sellerId }
    }

    func getTotalByVendor() -> [String: Double] {
        let itemsByVendor = getItemsByVendor()
        var totalsByVendor: [String: Double] = [:]

        for (vendorId, vendorItems) in itemsByVendor {
            let vendorTotal = vendorItems.reduce(0) { $0 + $1.total }
            totalsByVendor[vendorId] = vendorTotal
        }

        return totalsByVendor
    }

    func canProceedToCheckout() -> Bool {
        return !isEmpty && items.allSatisfy { $0.quantity > 0 }
    }
}