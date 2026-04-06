import Foundation
import SwiftUI

// MARK: - API Response Models
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String
    let data: T?
    let error: String?
}

// MARK: - Orders Specific Response Model
struct OrdersResponse: Codable {
    let success: Bool
    let orders: [Order]
    let pagination: Pagination?
    let userRole: String?
    let permissions: Permissions?
}

struct Pagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let pages: Int
}

struct Permissions: Codable {
    let canViewAllOrders: Bool
    let canViewFinancials: Bool
    let canManageUsers: Bool
}

// MARK: - Authentication Models
struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    let role: String

    init(email: String, password: String, firstName: String, lastName: String, role: UserRole = .buyer) {
        self.email = email
        self.password = password
        self.firstName = firstName
        self.lastName = lastName
        self.role = role.rawValue
    }
}

struct AuthResponse: Codable {
    let success: Bool
    let message: String
    let user: User
    let token: String?
}

// Note: Category models moved to ProductModels.swift

// Note: Product models moved to ProductModels.swift

// Note: Cart models moved to CartModels.swift

// MARK: - Branch Models
struct Branch: Codable, Identifiable {
    let id: String
    let sellerId: String
    let sellerName: String?
    let name: String
    let location: BranchLocation
    let contact: BranchContact
    let operatingHours: BranchOperatingHoursContainer?
    let managerId: String?
    let managerName: String?
    let isActive: Bool
    let features: BranchFeatures

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case sellerId, sellerName, name, location, contact, operatingHours, managerId, managerName, isActive, features
    }

    var displayName: String {
        return name
    }

    var fullAddress: String {
        var addressParts: [String] = []
        if !location.address.isEmpty { addressParts.append(location.address) }
        if !location.city.isEmpty { addressParts.append(location.city) }
        if !location.country.isEmpty { addressParts.append(location.country) }
        return addressParts.joined(separator: ", ")
    }

    var phoneNumber: String {
        return contact.phone ?? "Phone not available"
    }

    var isAvailableForPickup: Bool {
        return isActive && features.hasPickup
    }

    // Convert operating hours container to array for UI compatibility
    var operatingHoursArray: [BranchOperatingHours] {
        guard let hours = operatingHours else { return [] }
        var hoursArray: [BranchOperatingHours] = []

        if let monday = hours.monday {
            hoursArray.append(BranchOperatingHours(day: "Monday", open: monday.open, close: monday.close, isOpen: monday.isOpenComputed))
        }
        if let tuesday = hours.tuesday {
            hoursArray.append(BranchOperatingHours(day: "Tuesday", open: tuesday.open, close: tuesday.close, isOpen: tuesday.isOpenComputed))
        }
        if let wednesday = hours.wednesday {
            hoursArray.append(BranchOperatingHours(day: "Wednesday", open: wednesday.open, close: wednesday.close, isOpen: wednesday.isOpenComputed))
        }
        if let thursday = hours.thursday {
            hoursArray.append(BranchOperatingHours(day: "Thursday", open: thursday.open, close: thursday.close, isOpen: thursday.isOpenComputed))
        }
        if let friday = hours.friday {
            hoursArray.append(BranchOperatingHours(day: "Friday", open: friday.open, close: friday.close, isOpen: friday.isOpenComputed))
        }
        if let saturday = hours.saturday {
            hoursArray.append(BranchOperatingHours(day: "Saturday", open: saturday.open, close: saturday.close, isOpen: saturday.isOpenComputed))
        }
        if let sunday = hours.sunday {
            hoursArray.append(BranchOperatingHours(day: "Sunday", open: sunday.open, close: sunday.close, isOpen: sunday.isOpenComputed))
        }

        return hoursArray
    }
}

struct BranchLocation: Codable {
    let address: String
    let city: String
    let country: String
    let coordinates: BranchCoordinates?

    // Computed property for backward compatibility
    var street: String {
        return address
    }
}

struct BranchCoordinates: Codable {
    let latitude: Double
    let longitude: Double
}

struct BranchContact: Codable {
    let phone: String?
    let email: String?
}

struct BranchFeatures: Codable {
    let hasPickup: Bool
    let hasDelivery: Bool
    let deliveryRadius: Double?
}

// Container for the API response format with day objects
struct BranchOperatingHoursContainer: Codable {
    let monday: BranchDayHours?
    let tuesday: BranchDayHours?
    let wednesday: BranchDayHours?
    let thursday: BranchDayHours?
    let friday: BranchDayHours?
    let saturday: BranchDayHours?
    let sunday: BranchDayHours?
}

// Individual day hours as returned by API
struct BranchDayHours: Codable {
    let open: String
    let close: String
    let isOpen: Bool?

    // Computed property to determine if open based on available data
    var isOpenComputed: Bool {
        // If isOpen is provided, use it; otherwise assume open if we have open/close times
        return isOpen ?? (!open.isEmpty && !close.isEmpty && open != "closed" && close != "closed")
    }
}

// UI-friendly operating hours model
struct BranchOperatingHours: Codable {
    let day: String
    let open: String
    let close: String
    let isOpen: Bool

    var displayText: String {
        if !isOpen {
            return "\(day): Closed"
        }
        return "\(day): \(open) - \(close)"
    }
}


struct BranchesResponse: Codable {
    let success: Bool
    let branches: [Branch]
    let message: String?
    let pagination: Pagination?
}

// MARK: - Order Models
struct Order: Codable, Identifiable {
    let id: String
    let customerId: String?
    let customerInfo: CustomerInfo?
    let items: [OrderItem]?
    let status: OrderStatus?
    let totalAmount: Double?
    let subtotal: Double?
    let deliveryFee: Double?
    let giftCardDiscount: Double?
    let deliveryMethod: DeliveryMethod?
    let paymentMethod: PaymentMethod?
    let appliedGiftCard: AppliedGiftCard?
    let shippingAddress: ShippingAddress?
    let orderDate: String?
    let deliveryDate: String?
    let trackingNumber: String?
    let orderNumber: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case customerId, customerInfo, items, status, totalAmount
        case subtotal, deliveryFee, giftCardDiscount
        case deliveryMethod, paymentMethod, appliedGiftCard
        case shippingAddress, orderDate, deliveryDate
        case trackingNumber, orderNumber, notes
    }
}

struct OrderItem: Codable, Identifiable {
    let id: String
    let productId: String?
    let productName: String?
    let sku: String?
    let sellerId: String?
    let sellerName: String?
    let quantity: Int?
    let price: Double?
    let originalPrice: Double?
    let total: Double?
    let image: String?

    // Custom coding keys to handle optional backend id
    private enum CodingKeys: String, CodingKey {
        case id, productId, productName, sku, sellerId, sellerName
        case quantity, price, originalPrice, total, image
    }

    // Custom initializer from decoder to handle missing id
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Generate id if not provided by backend
        if let backendId = try container.decodeIfPresent(String.self, forKey: .id), !backendId.isEmpty {
            self.id = backendId
        } else {
            let productId = try container.decodeIfPresent(String.self, forKey: .productId) ?? "unknown"
            let sku = try container.decodeIfPresent(String.self, forKey: .sku) ?? "unknown"
            self.id = "\(productId)-\(sku)-\(UUID().uuidString.prefix(8))"
        }

        self.productId = try container.decodeIfPresent(String.self, forKey: .productId)
        self.productName = try container.decodeIfPresent(String.self, forKey: .productName)
        self.sku = try container.decodeIfPresent(String.self, forKey: .sku)
        self.sellerId = try container.decodeIfPresent(String.self, forKey: .sellerId)
        self.sellerName = try container.decodeIfPresent(String.self, forKey: .sellerName)
        self.quantity = try container.decodeIfPresent(Int.self, forKey: .quantity)
        self.price = try container.decodeIfPresent(Double.self, forKey: .price)
        self.originalPrice = try container.decodeIfPresent(Double.self, forKey: .originalPrice)
        self.total = try container.decodeIfPresent(Double.self, forKey: .total)
        self.image = try container.decodeIfPresent(String.self, forKey: .image)
    }
}

enum OrderStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case confirmed = "confirmed"
    case processing = "processing"
    case shipped = "shipped"
    case delivered = "delivered"
    case cancelled = "cancelled"
    case refunded = "refunded"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .processing: return "Processing"
        case .shipped: return "Shipped"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
        case .refunded: return "Refunded"
        }
    }

    func displayName(for deliveryMethod: DeliveryMethod?) -> String {
        guard let deliveryMethod = deliveryMethod else { return displayName }

        if deliveryMethod == .storePickup {
            switch self {
            case .pending: return "Pending Pickup"
            case .confirmed: return "Ready for Pickup"
            case .processing: return "Being Prepared"
            case .shipped: return "Ready for Pickup"
            case .delivered: return "Picked Up"
            case .cancelled: return "Cancelled"
            case .refunded: return "Refunded"
            }
        } else {
            return displayName
        }
    }

    var color: String {
        switch self {
        case .pending: return "orange"
        case .confirmed: return "blue"
        case .processing: return "purple"
        case .shipped: return "indigo"
        case .delivered: return "green"
        case .cancelled: return "red"
        case .refunded: return "gray"
        }
    }
}

// MARK: - Customer Info Models
struct CustomerInfo: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let phone: String

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

// Frontend-compatible customer info structure
struct FrontendCustomerInfo: Codable {
    let name: String
    let email: String
    let phone: String
}

// MARK: - Delivery Method Models
// MARK: - Seller Selection Models
enum RemainingItemsAction: String, CaseIterable {
    case delivery = "delivery"
    case remove = "remove"

    var title: String {
        switch self {
        case .delivery: return "Choose Home Delivery"
        case .remove: return "Remove from Cart"
        }
    }

    var description: String {
        switch self {
        case .delivery: return "Deliver these items to your address"
        case .remove: return "Remove these items (you can add them back later)"
        }
    }
}

struct SellerGroup {
    let sellerId: String
    let sellerName: String
    let items: [CartItem]

    var itemCount: Int {
        return items.count
    }

    var subtotal: Double {
        return items.reduce(0) { $0 + $1.total }
    }
}

enum DeliveryMethod: String, Codable, CaseIterable {
    case homeDelivery = "home_delivery"
    case storePickup = "store_pickup"

    // Custom decoder to handle backend's different values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value {
        case "delivery", "home_delivery":
            self = .homeDelivery
        case "pickup", "store_pickup":
            self = .storePickup
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath,
                                    debugDescription: "Cannot initialize DeliveryMethod from invalid String value \(value)")
            )
        }
    }

    var title: String {
        switch self {
        case .homeDelivery: return "Home Delivery"
        case .storePickup: return "Store Pickup"
        }
    }

    var description: String {
        switch self {
        case .homeDelivery: return "Delivered to your doorstep"
        case .storePickup: return "Pick up from our store"
        }
    }

    var fee: Double {
        switch self {
        case .homeDelivery: return 5.0
        case .storePickup: return 0.0
        }
    }

    var estimatedDays: Int {
        switch self {
        case .homeDelivery: return 3
        case .storePickup: return 1
        }
    }

    var icon: String {
        switch self {
        case .homeDelivery: return "car.fill"
        case .storePickup: return "storefront"
        }
    }
}

// MARK: - Payment Method Models
enum PaymentMethod: String, Codable, CaseIterable {
    case cashOnDelivery = "cod"
    case installment = "installment"

    // Custom decoder to handle backend's different values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value {
        case "cod", "cash_on_delivery", "COD":
            self = .cashOnDelivery
        case "installment", "installments":
            self = .installment
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath,
                                    debugDescription: "Cannot initialize PaymentMethod from invalid String value \(value)")
            )
        }
    }

    var title: String {
        switch self {
        case .cashOnDelivery: return "Cash on Delivery"
        case .installment: return "Installment Payment"
        }
    }

    func title(for deliveryMethod: DeliveryMethod) -> String {
        switch self {
        case .cashOnDelivery:
            return deliveryMethod == .storePickup ? "Cash on Pickup" : "Cash on Delivery"
        case .installment:
            return "Installment Payment"
        }
    }

    var description: String {
        switch self {
        case .cashOnDelivery: return "Pay when you receive your order"
        case .installment: return "Pay in monthly installments with down payment"
        }
    }

    func description(for deliveryMethod: DeliveryMethod) -> String {
        switch self {
        case .cashOnDelivery:
            return deliveryMethod == .storePickup ? "Pay when you pick up your order" : "Pay when you receive your order"
        case .installment:
            return "Pay in monthly installments with down payment"
        }
    }

    var icon: String {
        switch self {
        case .cashOnDelivery: return "banknote"
        case .installment: return "creditcard"
        }
    }
}

// MARK: - Gift Card Models
struct GiftCard: Codable, Identifiable {
    let id: String
    let code: String
    let balance: Double
    let originalAmount: Double
    let isActive: Bool
    let expiryDate: String?
    let createdAt: String

    var formattedCode: String {
        let cleanCode = code.replacingOccurrences(of: "-", with: "")
        if cleanCode.hasPrefix("Sanipa") {
            return code
        }
        let codeWithoutPrefix = cleanCode.replacingOccurrences(of: "Sanipa", with: "")
        let chunks = codeWithoutPrefix.chunked(into: 4)
        return "Sanipa-" + chunks.joined(separator: "-")
    }

    var isValid: Bool {
        return isActive && balance > 0
    }
}

struct AppliedGiftCard: Codable {
    let code: String
    let discountAmount: Double
    let remainingBalance: Double
}

struct GiftCardValidationRequest: Codable {
    let code: String
}

struct GiftCardValidationResponse: Codable {
    let success: Bool
    let message: String
    let giftCard: GiftCard?
}

// MARK: - Checkout Models
struct CreateOrderRequest: Codable {
    let clientOrderRef: String
    let userId: String?
    let customer: FrontendCustomerInfo
    let deliveryMethod: String
    let shippingAddress: ShippingAddressRequest?
    let pickupBranch: PickupBranchRequest?
    let items: [OrderItemRequest]
    let shippingCents: Int
    let taxCents: Int
    let totalCents: Int
    let paymentMethod: String
    let giftCard: GiftCardRequest?
}

struct OrderItemRequest: Codable {
    let productId: String
    let sku: String
    let title: String
    let vendorId: String
    let unitPriceCents: Int
    let quantity: Int
    let customizations: [CustomizationSelection]
}

struct ShippingAddressRequest: Codable {
    let country: String
    let city: String
    let street: String
    let postcode: String
    let notes: String?
}

struct PickupBranchRequest: Codable {
    let branchId: String?
    let branchName: String?
    let branchAddress: String?
}

struct GiftCardRequest: Codable {
    let code: String
    let amountUsed: Double
    let remainingBalance: Double
}

struct CreateOrderResponse: Codable {
    let success: Bool
    let message: String
    let order: Order?
    let orderNumber: String?
}

// MARK: - Installment Order Creation Models
struct CreateInstallmentOrderRequest: Codable {
    let customer: CustomerInfoRequest
    let productId: String
    let productName: String
    let productSku: String
    let sellerId: String
    let sellerName: String
    let planId: String
    let planName: String
    let quantity: Int
    let unitPrice: Double
    let totalPrice: Double
    let downPaymentAmount: Double
    let monthlyAmount: Double
    let totalAmount: Double
    let processingFee: Double
}

struct CustomerInfoRequest: Codable {
    let name: String
    let email: String
    let phone: String
}

struct ErrorResponse: Codable {
    let success: Bool
    let message: String
    let error: String?
}

// MARK: - Installment Response Models
struct InstallmentOrderResponse: Codable {
    let success: Bool
    let message: String
    let installmentOrderId: String?
    let orderNumber: String?
    let order: Order?
    // Note: order details handled separately to avoid circular dependencies
}

struct OrderResponse: Codable {
    let success: Bool
    let message: String
    let order: Order?
    let orderId: String?
    let walletPayment: WalletPayment?
    // Note: installmentOrders handled separately to avoid circular dependencies
}

struct WalletPayment: Codable {
    let amountUsed: Double?
    let newBalance: Double?
    // Add other wallet payment fields as needed
}

struct DocumentUploadResponse: Codable {
    let success: Bool
    let message: String
    // Note: document details handled separately to avoid circular dependencies
}

struct DocumentUploadRequest: Codable {
    let installmentOrderId: String
    let documents: [SimpleDocumentFile]

    enum CodingKeys: String, CodingKey {
        case installmentOrderId, documents
    }
}

struct SimpleDocumentFile: Codable {
    let fileName: String
    let mimeType: String
    let file: Data
    let documentType: String

    enum CodingKeys: String, CodingKey {
        case fileName, mimeType, file, documentType
    }
}

// MARK: - Checkout State Models
struct CheckoutState {
    var currentStep: CheckoutStep = .customerInfo
    var customerInfo: CustomerInfo?
    var deliveryMethod: DeliveryMethod = .homeDelivery
    var paymentMethod: PaymentMethod = .cashOnDelivery
    var appliedGiftCard: AppliedGiftCard?
    var notes: String = ""
    var isProcessing: Bool = false
    var errorMessage: String?

    // Installment-related properties
    var isInstallmentOrder: Bool = false
    var installmentOrderId: String?
    // Note: Document types handled separately to avoid circular dependencies
    var uploadedDocumentsCount: Int = 0
    var requiredDocumentsCount: Int = 0

    var canProceedToNextStep: Bool {
        switch currentStep {
        case .customerInfo:
            return customerInfo != nil
        case .delivery:
            return true
        case .documents:
            // For installment orders, all required documents must be uploaded
            return !isInstallmentOrder || (isInstallmentOrder && areAllDocumentsUploaded)
        case .payment:
            return true
        }
    }

    // Check if all required documents are uploaded
    var areAllDocumentsUploaded: Bool {
        guard isInstallmentOrder else { return true }

        // Simplified check using counts (detailed logic handled elsewhere)
        return uploadedDocumentsCount >= requiredDocumentsCount
    }

    var canPlaceOrder: Bool {
        return customerInfo != nil && !isProcessing
    }
}

enum CheckoutStep: Int, CaseIterable {
    case customerInfo = 0
    case delivery = 1
    case documents = 2
    case payment = 3

    var title: String {
        switch self {
        case .customerInfo: return "Customer Info"
        case .delivery: return "Delivery"
        case .documents: return "Documents"
        case .payment: return "Payment"
        }
    }

    var icon: String {
        switch self {
        case .customerInfo: return "person"
        case .delivery: return "truck"
        case .documents: return "doc.text"
        case .payment: return "creditcard"
        }
    }
}

// MARK: - Order Summary Model
struct OrderSummary: Codable {
    let subtotal: Double
    let deliveryFee: Double
    let giftCardDiscount: Double
    let total: Double
    let itemCount: Int

    init(items: [CartItem], deliveryMethod: DeliveryMethod, giftCardDiscount: Double = 0, dynamicShippingCost: Double? = nil) {
        self.subtotal = items.reduce(0) { $0 + $1.total }

        // Use dynamic shipping cost if provided, otherwise fall back to hardcoded fee
        if let dynamicCost = dynamicShippingCost {
            self.deliveryFee = deliveryMethod == .storePickup ? 0.0 : dynamicCost
        } else {
            self.deliveryFee = deliveryMethod.fee
        }

        self.giftCardDiscount = giftCardDiscount
        self.total = max(0, subtotal + deliveryFee - giftCardDiscount)
        self.itemCount = items.reduce(0) { $0 + $1.quantity }
    }
}

// MARK: - Address Models
struct ShippingAddress: Codable {
    let firstName: String
    let lastName: String
    let address: String
    let city: String
    let country: String
    let postalCode: String?
    let phone: String?
}

// MARK: - Review Models
struct Review: Codable, Identifiable {
    let id: String
    let productId: String
    let sellerId: String
    let customerId: String
    let customerName: String
    let rating: Int
    let comment: String
    let reviewDate: String
    let helpful: Int?
}

// MARK: - Error Models
enum APIError: Error, LocalizedError {
    case serverError(String)
    case networkError(String)
    case decodingError(String)
    case invalidResponse
    case missingData

    var errorDescription: String? {
        switch self {
        case .serverError(let message):
            return message
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Data parsing error: \(message)"
        case .invalidResponse:
            return "Invalid server response"
        case .missingData:
            return "Missing required data"
        }
    }
}

// Note: ProductSearchParams moved to ProductModels.swift
// Note: ProductSortOption moved to ProductModels.swift

// MARK: - Raffle API Models
struct RaffleShowcaseResponse: Codable {
    let success: Bool
    let raffles: [APIRaffle]
    let message: String?
    let count: Int?
}

struct APIRaffle: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let prizeImage: String?
    let prizeValue: Double?
    let prizeCurrency: String?
    let maxTickets: Int?
    let currentTickets: Int?
    let drawDate: String?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?
    let daysLeft: Int?
    let percentageSold: Int?
    private let _timeLeftText: String?
    private let _progressText: String?
    let formattedPrizeValue: String?
    let productCount: Int?
    let products: [APIRaffleProduct]?

    // Computed property to generate time left text from daysLeft
    var timeLeftText: String? {
        guard let daysLeft = daysLeft else {
            return nil
        }

        if daysLeft <= 0 {
            return "Ending Soon!"
        } else if daysLeft == 1 {
            return "1 Day Left!"
        } else {
            return "\(daysLeft) Days Left!"
        }
    }

    // Computed property to generate progress text from currentTickets and maxTickets
    var progressText: String? {
        guard let currentTickets = currentTickets, let maxTickets = maxTickets else {
            return nil
        }
        return "\(currentTickets) / \(maxTickets)"
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, description, prizeImage, prizeValue, prizeCurrency
        case maxTickets, currentTickets, drawDate, isActive
        case createdAt, updatedAt, daysLeft, percentageSold
        case _timeLeftText = "timeLeftText", _progressText = "progressText", formattedPrizeValue
        case productCount, products
    }
}

struct APIRaffleProduct: Codable, Identifiable {
    let id: String  // This will be the actual product ID (e.g., "prod_1767440715522_escriiqe3")
    let mongoId: String?  // This will be the MongoDB ObjectId (e.g., "6959014bb9da3c167cd98adb")
    let name: String
    let price: Double?
    let mainImage: String?
    let formattedPrice: String?

    enum CodingKeys: String, CodingKey {
        case id = "id"  // Use the actual product ID field
        case mongoId = "_id"  // MongoDB ObjectId
        case name, price, mainImage, formattedPrice
    }
}

// MARK: - Product Search Response
struct ProductSearchResponse: Codable {
    let success: Bool
    let products: [Product]?
    let message: String?
    let totalProducts: Int?
    let page: Int?
    let totalPages: Int?
}

// MARK: - Shipping Calculation Models
struct ShippingCalculationRequest: Codable {
    let items: [ShippingItem]
}

struct ShippingItem: Codable {
    let sellerId: String
    let sellerName: String
    let price: Double
    let quantity: Int
}

struct ShippingCalculationResponse: Codable {
    let success: Bool
    let message: String?
    let shippingBreakdown: [ShippingBreakdown]?
    let totalShipping: Double
}

struct ShippingBreakdown: Codable {
    let sellerId: String
    let sellerName: String
    let shippingCost: Double
    let freeShippingThreshold: Double?
    let orderTotal: Double
}

// MARK: - Extensions
extension String {
    func chunked(into size: Int) -> [String] {
        return stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: min(size, count - $0))
            return String(self[start..<end])
        }
    }
}
