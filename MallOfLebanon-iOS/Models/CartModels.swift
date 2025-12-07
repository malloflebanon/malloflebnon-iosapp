import Foundation

struct CartItem: Codable, Identifiable {
    let id: String
    let productId: String
    let sellerId: String
    let name: String
    let price: Double
    let originalPrice: Double?
    let image: String
    var quantity: Int
    let sku: String
    let sellerName: String
    let customizations: [ProductCustomization]?
    let maxStock: Int

    var total: Double {
        return price * Double(quantity)
    }

    var originalTotal: Double? {
        guard let originalPrice = originalPrice else { return nil }
        return originalPrice * Double(quantity)
    }

    var savings: Double {
        guard let originalTotal = originalTotal else { return 0 }
        return originalTotal - total
    }

    var hasDiscount: Bool {
        return originalPrice != nil && originalPrice! > price
    }

    var discountPercentage: Int {
        guard let original = originalPrice, original > price else { return 0 }
        return Int(((original - price) / original) * 100)
    }

    mutating func increaseQuantity() {
        if quantity < maxStock {
            quantity += 1
        }
    }

    mutating func decreaseQuantity() {
        if quantity > 1 {
            quantity -= 1
        }
    }

    mutating func updateQuantity(_ newQuantity: Int) {
        quantity = max(1, min(newQuantity, maxStock))
    }
}

struct Cart: Codable {
    var items: [CartItem]
    let lastUpdated: Date

    var totalItems: Int {
        return items.reduce(0) { $0 + $1.quantity }
    }

    var subtotal: Double {
        return items.reduce(0) { $0 + $1.total }
    }

    var totalSavings: Double {
        return items.reduce(0) { $0 + $1.savings }
    }

    var originalSubtotal: Double {
        return items.reduce(0) { total, item in
            total + (item.originalTotal ?? item.total)
        }
    }

    var isEmpty: Bool {
        return items.isEmpty
    }

    var hasSavings: Bool {
        return totalSavings > 0
    }

    init() {
        self.items = []
        self.lastUpdated = Date()
    }

    init(items: [CartItem]) {
        self.items = items
        self.lastUpdated = Date()
    }

    mutating func addItem(_ item: CartItem) {
        if let existingIndex = items.firstIndex(where: { $0.productId == item.productId && $0.sellerId == item.sellerId }) {
            items[existingIndex].quantity += item.quantity
            if items[existingIndex].quantity > items[existingIndex].maxStock {
                items[existingIndex].quantity = items[existingIndex].maxStock
            }
        } else {
            items.append(item)
        }
    }

    mutating func removeItem(withId id: String) {
        items.removeAll { $0.id == id }
    }

    mutating func updateItemQuantity(itemId: String, quantity: Int) {
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].updateQuantity(quantity)
        }
    }

    mutating func clearCart() {
        items.removeAll()
    }

    func getItemsBySeller() -> [String: [CartItem]] {
        return Dictionary(grouping: items) { $0.sellerId }
    }

    func getSellerNames() -> [String] {
        let sellerNames = Set(items.map { $0.sellerName })
        return Array(sellerNames).sorted()
    }
}

struct CheckoutRequest: Codable {
    let items: [CheckoutItem]
    let shippingAddress: ShippingAddress
    let paymentMethod: String
    let notes: String?
}

struct CheckoutItem: Codable {
    let productId: String
    let sellerId: String
    let quantity: Int
    let price: Double
    let customizations: [ProductCustomization]?
}

struct CheckoutResponse: Codable {
    let success: Bool
    let message: String
    let data: CheckoutData?
}

struct CheckoutData: Codable {
    let orderId: String
    let totalAmount: Double
    let estimatedDelivery: String?
    let paymentUrl: String?
}

struct AddToCartRequest {
    let product: Product
    let quantity: Int
    let customizations: [ProductCustomization]?

    init(product: Product, quantity: Int = 1, customizations: [ProductCustomization]? = nil) {
        self.product = product
        self.quantity = quantity
        self.customizations = customizations
    }

    func generateCartItem() -> CartItem {
        return CartItem.fromProduct(product, quantity: quantity, customizations: customizations)
    }
}

extension CartItem {
    static func fromProduct(_ product: Product, quantity: Int = 1, customizations: [ProductCustomization]? = nil) -> CartItem {
        return CartItem(
            id: UUID().uuidString,
            productId: product.id,
            sellerId: product.sellerId,
            name: product.name,
            price: product.price,
            originalPrice: product.originalPrice,
            image: product.mainImage,
            quantity: quantity,
            sku: product.sku,
            sellerName: product.sellerName,
            customizations: customizations,
            maxStock: product.stock
        )
    }
}

struct CartSummary {
    let items: [CartItem]

    var itemCount: Int {
        return items.reduce(0) { $0 + $1.quantity }
    }

    var subtotal: Double {
        return items.reduce(0) { $0 + $1.total }
    }

    var total: Double {
        return subtotal
    }

    var totalSavings: Double {
        return items.reduce(0) { $0 + $1.savings }
    }

    var isEmpty: Bool {
        return items.isEmpty
    }
}

struct CartStorage: Codable {
    let items: [CartItem]
    let lastUpdated: Date

    init(items: [CartItem]) {
        self.items = items
        self.lastUpdated = Date()
    }
}