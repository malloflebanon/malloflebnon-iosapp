import Foundation

// Helper struct for handling dynamic JSON fields
struct AnyCodable: Codable {
    let value: Any

    init<T>(_ value: T?) {
        self.value = value ?? ()
    }
}

extension AnyCodable: ExpressibleByNilLiteral {
    init(nilLiteral: ()) {
        self.init(())
    }
}

extension AnyCodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.init(())
        } else if let bool = try? container.decode(Bool.self) {
            self.init(bool)
        } else if let int = try? container.decode(Int.self) {
            self.init(int)
        } else if let double = try? container.decode(Double.self) {
            self.init(double)
        } else if let string = try? container.decode(String.self) {
            self.init(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self.init(array.map { $0.value })
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.init(dictionary.mapValues { $0.value })
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            let codableArray = array.map { AnyCodable($0) }
            try container.encode(codableArray)
        case let dictionary as [String: Any]:
            let codableDictionary = dictionary.mapValues { AnyCodable($0) }
            try container.encode(codableDictionary)
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

struct Product: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let price: Double
    let originalPrice: Double?
    let sellerId: String
    let sellerName: String
    let category: String
    let subcategory: String?
    let brand: String?
    let sku: String
    let inStock: Bool
    let quantity: Int
    let status: ProductStatus
    let images: [String]
    let rating: Double
    let reviewCount: Int
    let tags: [String]
    let specifications: [String: AnyCodable]?
    let featured: Bool
    let slug: String?
    let customizationOptions: [ProductCustomization]?
    let createdAt: Date
    let updatedAt: Date

    // MongoDB specific fields (all optional)
    let outOfStockSince: Date?
    let baseQuantity: Int?
    let hasCustomizations: Bool?
    let stockManagement: String?
    let categoryTemplate: String?
    let categoryFields: [String: String]?
    let hasComparison: Bool?
    let matchingData: [String: AnyCodable]?
    let comparisonGroup: [String: AnyCodable]?

    private enum CodingKeys: String, CodingKey {
        case id, name, description, price, originalPrice, sellerId, sellerName
        case category, subcategory, brand, sku, inStock, quantity, status
        case images, rating, reviewCount, tags, specifications, featured
        case slug, customizationOptions, createdAt, updatedAt
        case outOfStockSince, baseQuantity, hasCustomizations, stockManagement
        case categoryTemplate, categoryFields, hasComparison
        case matchingData, comparisonGroup
    }

    // Computed properties for backward compatibility and enhanced functionality
    var effectiveBrand: String? {
        return brand ?? (specifications?["brand"]?.value as? String)
    }
    var mainImage: String {
        return images.first ?? ""
    }

    var stock: Int {
        return quantity
    }

    var isActive: Bool {
        return status == .active
    }

    var isFeatured: Bool {
        return featured
    }

    var discountPercentage: Int {
        guard let original = originalPrice, original > price else { return 0 }
        return Int(((original - price) / original) * 100)
    }

    var hasDiscount: Bool {
        return discountPercentage > 0
    }

    var formattedPrice: String {
        return String(format: "%.2f", price)
    }

    var formattedOriginalPrice: String? {
        guard let originalPrice = originalPrice else { return nil }
        return String(format: "%.2f", originalPrice)
    }
}

enum ProductStatus: String, Codable {
    case active = "active"
    case inactive = "inactive"
    case draft = "draft"
    case archived = "archived"
    case outOfStock = "out_of_stock"
}

struct ProductVariation: Codable, Identifiable {
    let id: String
    let name: String
    let value: String
    let price: Double?
    let image: String?
}

struct ProductCustomization: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let options: [CustomizationOption]
    let required: Bool
}

struct CustomizationOption: Codable, Identifiable {
    let id: String
    let label: String
    let value: String
    let priceModifier: Double
    let stockQuantity: Int?
    let isDefault: Bool

    // For backward compatibility
    var name: String {
        return label
    }
}

struct Category: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let image: String?
    let parentId: String?
    let isActive: Bool?
    let sortOrder: Int?
    let productCount: Int?
    let subcategories: [Category]?
    let createdAt: Date?
    let updatedAt: Date?

    // MongoDB specific fields
    let displayOrder: Int?
    let isCustom: Bool?
    let viewCount: Int?
    let clickCount: Int?
    let featured: Bool?
    let createdBy: String?
    let slug: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, description, image, isActive, subcategories
        case createdAt, updatedAt, displayOrder, isCustom, viewCount
        case clickCount, featured
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        parentId = nil
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder)
        productCount = nil
        subcategories = try container.decodeIfPresent([Category].self, forKey: .subcategories)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder)
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom)
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount)
        clickCount = try container.decodeIfPresent(Int.self, forKey: .clickCount)
        featured = try container.decodeIfPresent(Bool.self, forKey: .featured)
        createdBy = nil
        slug = nil
    }

    var hasSubcategories: Bool {
        return subcategories?.isEmpty == false
    }
}

struct ProductsResponse: Codable {
    let success: Bool
    let products: [Product]
    let pagination: PaginationInfo
}

struct PaginationInfo: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let pages: Int
    let hasNext: Bool
    let hasPrev: Bool

    // Computed properties for backward compatibility
    var currentPage: Int { page }
    var totalProducts: Int { total }
    var totalPages: Int { pages }
    var hasNextPage: Bool { hasNext }
    var hasPrevPage: Bool { hasPrev }
}

struct ProductResponse: Codable {
    let success: Bool
    let product: Product
}

struct CategoriesResponse: Codable {
    let success: Bool
    let categories: [Category]
}

struct CollectionsResponse: Codable {
    let success: Bool
    let collections: [ProductCollection]
}

struct ProductCollection: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let categoryIdentifier: String?
    let displayOrder: Int?
    let productCount: Int?

    // Optional fields that may not always be present
    let image: String?
    let productIds: [String]?
    let products: [Product]?
    let isActive: Bool?
    let createdAt: Date?
    let updatedAt: Date?

    // MongoDB ID field
    let mongoId: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, description, categoryIdentifier, displayOrder, productCount
        case image, productIds, products, isActive, createdAt, updatedAt
        case mongoId = "_id"
    }
}

struct ProductSearchParams {
    var category: String?
    var subcategory: String?
    var sellerId: String?
    var minPrice: Double?
    var maxPrice: Double?
    var search: String?
    var sortBy: ProductSortOption
    var page: Int
    var limit: Int
    var tags: [String]?
    var inStock: Bool?
    var featured: Bool?

    init(category: String? = nil,
         subcategory: String? = nil,
         sellerId: String? = nil,
         minPrice: Double? = nil,
         maxPrice: Double? = nil,
         search: String? = nil,
         sortBy: ProductSortOption = .newest,
         page: Int = 1,
         limit: Int = 20,
         tags: [String]? = nil,
         inStock: Bool? = nil,
         featured: Bool? = nil) {
        self.category = category
        self.subcategory = subcategory
        self.sellerId = sellerId
        self.minPrice = minPrice
        self.maxPrice = maxPrice
        self.search = search
        self.sortBy = sortBy
        self.page = page
        self.limit = limit
        self.tags = tags
        self.inStock = inStock
        self.featured = featured
    }

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        if let category = category {
            items.append(URLQueryItem(name: "category", value: category))
        }
        if let subcategory = subcategory {
            items.append(URLQueryItem(name: "subcategory", value: subcategory))
        }
        if let sellerId = sellerId {
            items.append(URLQueryItem(name: "sellerId", value: sellerId))
        }
        if let minPrice = minPrice {
            items.append(URLQueryItem(name: "minPrice", value: String(minPrice)))
        }
        if let maxPrice = maxPrice {
            items.append(URLQueryItem(name: "maxPrice", value: String(maxPrice)))
        }
        if let search = search {
            items.append(URLQueryItem(name: "search", value: search))
        }

        items.append(URLQueryItem(name: "sortBy", value: sortBy.rawValue))
        items.append(URLQueryItem(name: "page", value: String(page)))
        items.append(URLQueryItem(name: "limit", value: String(limit)))

        if let tags = tags {
            items.append(URLQueryItem(name: "tags", value: tags.joined(separator: ",")))
        }
        if let inStock = inStock {
            items.append(URLQueryItem(name: "inStock", value: String(inStock)))
        }
        if let featured = featured {
            items.append(URLQueryItem(name: "featured", value: String(featured)))
        }

        return items
    }
}

enum ProductSortOption: String, CaseIterable {
    case newest = "newest"
    case oldest = "oldest"
    case priceLowToHigh = "price_asc"
    case priceHighToLow = "price_desc"
    case nameAToZ = "name_asc"
    case nameZToA = "name_desc"
    case rating = "rating"
    case popular = "popular"

    var displayName: String {
        switch self {
        case .newest: return "Newest First"
        case .oldest: return "Oldest First"
        case .priceLowToHigh: return "Price: Low to High"
        case .priceHighToLow: return "Price: High to Low"
        case .nameAToZ: return "Name: A to Z"
        case .nameZToA: return "Name: Z to A"
        case .rating: return "Highest Rated"
        case .popular: return "Most Popular"
        }
    }
}