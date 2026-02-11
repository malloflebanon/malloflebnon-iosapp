import Foundation

// MARK: - Vendor Data Models

struct VendorStats: Codable {
    let totalProducts: Int
    let totalOrders: Int
    let totalSales: Double
    let averageRating: Double
    let totalReviews: Int

    enum CodingKeys: String, CodingKey {
        case totalProducts, totalOrders, totalSales, averageRating, totalReviews
    }
}

struct VendorVerification: Codable {
    let documentsSubmitted: Bool
    let verified: Bool
    let verifiedAt: String?
    let verifiedBy: String?
}

struct VendorContactInfo: Codable {
    let email: String
    let phone: String?
    let website: String?
}

struct Vendor: Codable, Identifiable {
    let id: String
    let businessName: String
    let slug: String
    let description: String?
    let shortDescription: String?
    let logo: String?
    let banner: String?
    let contactInfo: VendorContactInfo
    let categories: [String]
    let status: String
    let verification: VendorVerification
    let stats: VendorStats
    let joinedAt: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case businessName, slug, description, shortDescription
        case logo, banner, contactInfo, categories, status
        case verification, stats, joinedAt, createdAt, updatedAt
    }

    // Computed properties for display
    var displayName: String {
        return businessName.isEmpty ? "Unknown Seller" : businessName
    }

    var displayRating: Double {
        return max(0, min(5, stats.averageRating))
    }

    var hasReviews: Bool {
        return stats.totalReviews > 0
    }

    var isVerified: Bool {
        return verification.verified
    }
}

struct VendorResponse: Codable {
    let success: Bool
    let data: Vendor
    let message: String?
}

struct VendorListResponse: Codable {
    let success: Bool
    let data: [Vendor]
    let pagination: PaginationInfo?
    let message: String?
}

struct PaginationInfo: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let pages: Int
}