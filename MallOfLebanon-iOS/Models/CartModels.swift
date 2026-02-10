import Foundation

// MARK: - Raffle Info
struct RaffleInfo: Codable, Equatable {
    let raffleId: String?
    let raffleTitle: String?
    let ticketsPerPurchase: Int
    let drawDate: String?

    init(raffleId: String?, raffleTitle: String? = nil, ticketsPerPurchase: Int = 1, drawDate: String? = nil) {
        self.raffleId = raffleId
        self.raffleTitle = raffleTitle
        self.ticketsPerPurchase = ticketsPerPurchase
        self.drawDate = drawDate
    }
}

// MARK: - Installment Plan Selection
struct InstallmentPlanSelection: Codable, Equatable {
    let planId: String
    let planName: String
    let duration: Int
    let downPaymentPercentage: Double
    let interestRate: Double
    let minimumOrderAmount: Double
    let downPayment: Double
    let monthlyPayment: Double
    let totalAmount: Double
    let totalInterest: Double
    let processingFee: Double
    let description: String?

    var displayName: String {
        return "\(planName) - \(duration) months"
    }

}

// MARK: - Cart Type
enum CartType {
    case empty
    case regular
    case installment

    var displayName: String {
        switch self {
        case .empty: return "Empty"
        case .regular: return "Regular"
        case .installment: return "Installment"
        }
    }
}

// MARK: - Cart Conflict Info
struct CartConflictInfo {
    let hasConflict: Bool
    let cartType: CartType
    let conflictingItem: CartItem?
    let message: String

    static let noConflict = CartConflictInfo(
        hasConflict: false,
        cartType: .empty,
        conflictingItem: nil,
        message: ""
    )
}

// MARK: - Cart Conflict Actions
enum CartConflictAction {
    case clearCartAndAdd
    case clearCartAndBuyNow
    case continueToCheckout
    case cancel
}

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
    let customizations: [CustomizationSelection]?
    let maxStock: Int
    let taxRate: Double? // Tax rate for this product (e.g. 11.0 for 11%)

    // Installment support
    let installmentPlan: InstallmentPlanSelection?
    let hasInstallmentPlan: Bool

    // Raffle support
    let isRaffleTicket: Bool
    let raffleInfo: RaffleInfo?

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

    // Raffle-related computed properties
    var displayName: String {
        if isRaffleTicket {
            return "\(name) (Raffle Entry)"
        }
        return name
    }

    var ticketCount: Int {
        if isRaffleTicket {
            let ticketsPerPurchase = raffleInfo?.ticketsPerPurchase ?? 1
            return quantity * ticketsPerPurchase
        }
        return 0
    }

    var raffleDisplayText: String {
        if isRaffleTicket {
            let tickets = ticketCount
            return tickets == 1 ? "1 Raffle Ticket" : "\(tickets) Raffle Tickets"
        }
        return ""
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
        // For installment items, need to check both product and installment plan for uniqueness
        let matchingItem = items.first { existingItem in
            existingItem.productId == item.productId &&
            existingItem.sellerId == item.sellerId
        }

        if let existingIndex = items.firstIndex(where: { $0.id == matchingItem?.id }) {
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

    // MARK: - Installment Support
    var cartType: CartType {
        if items.isEmpty {
            return .empty
        }

        let hasInstallmentItems = items.contains { $0.hasInstallmentPlan }
        return hasInstallmentItems ? .installment : .regular
    }

    func checkCartConflict(hasInstallmentPlan: Bool) -> CartConflictInfo {
        let currentCartType = cartType
        let attemptingToAdd: CartType = hasInstallmentPlan ? .installment : .regular

        // No conflict if cart is empty
        if currentCartType == .empty {
            return CartConflictInfo(
                hasConflict: false,
                cartType: .empty,
                conflictingItem: nil,
                message: "No conflict"
            )
        }

        // Conflict exists if trying to add different payment type to non-empty cart
        let hasConflict = currentCartType != attemptingToAdd

        return CartConflictInfo(
            hasConflict: hasConflict,
            cartType: currentCartType,
            conflictingItem: items.first,
            message: hasConflict ? "Cannot mix regular and installment items in cart" : "No conflict"
        )
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
    let customizations: [CustomizationSelection]?
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
    let customizations: [CustomizationSelection]?

    init(product: Product, quantity: Int = 1, customizations: [CustomizationSelection]? = nil) {
        self.product = product
        self.quantity = quantity
        self.customizations = customizations
    }

    func generateCartItem() -> CartItem {
        return CartItem.fromProduct(product, quantity: quantity, customizations: customizations)
    }
}

extension CartItem {
    static func fromProduct(
        _ product: Product,
        quantity: Int = 1,
        customizations: [CustomizationSelection]? = nil,
        installmentPlan: InstallmentPlanSelection? = nil
    ) -> CartItem {
        // Generate unique ID based on product, customizations, and installment plan
        let customizationHash = customizations?.map { "\($0.customizationId)_\($0.optionId)" }.joined(separator: "|") ?? "no_customizations"
        let installmentHash = installmentPlan?.planId ?? "no_installment"
        let itemId = "\(product.id)_\(product.sellerId)_\(customizationHash)_\(installmentHash)"

        // Calculate base price including customization modifiers
        let basePrice = product.price
        let customizationPrice = customizations?.reduce(0) { total, customization in
            total + customization.priceModifier
        } ?? 0
        let totalProductPrice = basePrice + customizationPrice

        // For installment plans, show down payment as the cart price
        let displayPrice = installmentPlan?.downPayment ?? totalProductPrice

        return CartItem(
            id: itemId,
            productId: product.id,
            sellerId: product.sellerId,
            name: product.name,
            price: displayPrice,
            originalPrice: product.originalPrice,
            image: product.mainImage,
            quantity: quantity,
            sku: product.sku,
            sellerName: product.sellerName,
            customizations: customizations,
            maxStock: product.stockCount,
            taxRate: product.taxRate,
            installmentPlan: installmentPlan,
            hasInstallmentPlan: installmentPlan != nil,
            isRaffleTicket: product.isRaffleTicket ?? false,
            raffleInfo: product.raffleInfo.map { info in
                RaffleInfo(
                    raffleId: info.raffleId,
                    raffleTitle: info.raffleTitle,
                    ticketsPerPurchase: info.ticketsPerPurchase,
                    drawDate: info.drawDate
                )
            }
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