import Foundation
import Combine

class CartManager: ObservableObject {
    static let shared = CartManager()

    @Published var items: [CartItem] = []
    @Published var cartSummary: CartSummary = CartSummary(items: [])

    private let userDefaults = UserDefaults.standard
    private let cartStorageKey = "my_ecom_cart_v1"
    private var cancellables = Set<AnyCancellable>()

    private init() {
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

    func addProduct(_ product: Product, quantity: Int = 1, customizations: [ProductCustomization] = []) {
        let request = AddToCartRequest(product: product, quantity: quantity, customizations: customizations)
        addItem(request)
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
        print("Cart: Cleared all items")
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