import Foundation

// MARK: - API Response Models
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String
    let data: T?
    let error: String?
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
    let token: String
}

// Note: Category models moved to ProductModels.swift

// Note: Product models moved to ProductModels.swift

// Note: Cart models moved to CartModels.swift

// MARK: - Order Models
struct Order: Codable, Identifiable {
    let id: String
    let customerId: String
    let items: [OrderItem]
    let status: OrderStatus
    let totalAmount: Double
    let shippingAddress: ShippingAddress?
    let paymentMethod: String?
    let orderDate: String
    let deliveryDate: String?
    let trackingNumber: String?
}

struct OrderItem: Codable, Identifiable {
    let id: String
    let productId: String
    let productName: String
    let sku: String
    let sellerId: String
    let sellerName: String
    let quantity: Int
    let price: Double
    let originalPrice: Double?
    let total: Double
    let image: String
}

enum OrderStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case confirmed = "confirmed"
    case processing = "processing"
    case shipped = "shipped"
    case delivered = "delivered"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .processing: return "Processing"
        case .shipped: return "Shipped"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
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
        }
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
struct APIError: Error, LocalizedError, Codable {
    let message: String
    let code: String?

    init(message: String, code: String? = nil) {
        self.message = message
        self.code = code
    }

    // Conform to LocalizedError protocol
    var errorDescription: String? {
        return message
    }

    var failureReason: String? {
        return message
    }

    var localizedDescription: String {
        return message
    }
}

// Note: ProductSearchParams moved to ProductModels.swift
// Note: ProductSortOption moved to ProductModels.swift