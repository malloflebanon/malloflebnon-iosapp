import Foundation

// MARK: - User Model
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let role: UserRole
    let enabled: Bool?
    let verified: Bool?
    let store: UserStore?
    let customerSegment: String?
    let preferences: UserPreferences?
    let analytics: UserAnalytics?
    let lastActiveAt: String?
    let createdAt: String?

    var fullName: String {
        "\(firstName) \(lastName)"
    }

    var displayName: String {
        fullName.isEmpty ? email : fullName
    }
}

// MARK: - User Role
enum UserRole: String, Codable, CaseIterable {
    case buyer = "buyer"
    case seller = "seller"
    case admin = "admin"
    case manager = "manager"
    case support = "support"
    case superAdmin = "super_admin"

    var displayName: String {
        switch self {
        case .buyer: return "Customer"
        case .seller: return "Seller"
        case .admin: return "Admin"
        case .manager: return "Manager"
        case .support: return "Support"
        case .superAdmin: return "Super Admin"
        }
    }
}

// MARK: - User Store
struct UserStore: Codable {
    let id: String
    let name: String
    let slug: String
    let status: String
}

// MARK: - User Preferences
struct UserPreferences: Codable {
    let categories: [String]?
    let brands: [String]?
    let priceRange: PriceRange?
    let communicationPreferences: CommunicationPreferences?
}

struct PriceRange: Codable {
    let min: Double
    let max: Double
}

struct CommunicationPreferences: Codable {
    let email: Bool
    let sms: Bool
    let push: Bool
}

// MARK: - User Analytics
struct UserAnalytics: Codable {
    let totalSpent: Double?
    let totalOrders: Int?
    let averageOrderValue: Double?
    let firstOrderDate: String?
    let lastOrderDate: String?
    let loyaltyPoints: Int?
}