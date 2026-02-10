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

// MARK: - Raffle Support
struct ProductRaffleInfo: Codable {
    let raffleId: String?
    let raffleTitle: String?
    let ticketsPerPurchase: Int
    let drawDate: String?
    let raffleStatus: String?
    let assignedAt: String?

    init(raffleId: String? = nil, raffleTitle: String? = nil, ticketsPerPurchase: Int = 1, drawDate: String? = nil, raffleStatus: String? = nil, assignedAt: String? = nil) {
        self.raffleId = raffleId
        self.raffleTitle = raffleTitle
        self.ticketsPerPurchase = ticketsPerPurchase
        self.drawDate = drawDate
        self.raffleStatus = raffleStatus
        self.assignedAt = assignedAt
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
    let createdAt: Date?
    let updatedAt: Date?

    // MongoDB specific fields (all optional)
    let outOfStockSince: Date?
    let baseQuantity: Int?
    let hasCustomizations: Bool?
    let stockManagement: String?
    let categoryTemplate: String?
    let categoryFields: [String: AnyCodable]?
    let hasComparison: Bool?
    let matchingData: AnyCodable?
    let comparisonGroup: AnyCodable?

    // New API response fields
    let seller: String?
    let store: String?
    let title: String?
    let shortDescription: String?
    let comparePrice: Double?
    let costPrice: Double?
    let stock: Int?
    let isActive: Bool?
    let isApproved: Bool?
    let isFeatured: Bool?
    let ratings: ProductRatings?
    let metaKeywords: [String]?
    let views: Int?
    let soldCount: Int?
    let variants: [String]?
    let taxRate: Double? // Tax rate for this product (e.g. 11.0 for 11%)
    let reviews: [String]?

    // INSTALLMENT FIELDS - using basic types to avoid circular dependencies
    let hasInstallmentPlans: Bool?
    let installmentSettings: InstallmentSettings?
    let installmentPlansRaw: [AnyCodable]?

    // RAFFLE FIELDS
    let isRaffleTicket: Bool?
    let raffleInfo: ProductRaffleInfo?

    // Handle custom init to provide compatibility between different API structures
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Use id field first, fallback to _id only if id is missing
        if let productId = try? container.decode(String.self, forKey: .id) {
            id = productId
        } else if let objectId = try? container.decode(String.self, forKey: ._id) {
            id = objectId
        } else {
            id = try container.decode(String.self, forKey: .id)
        }

        // Handle name/title field mapping - support both API structures
        if let nameValue = try? container.decode(String.self, forKey: .name) {
            // Individual product API uses "name" field
            name = nameValue
            title = nameValue
        } else if let titleValue = try? container.decode(String.self, forKey: .title) {
            // Products list API uses "title" field
            name = titleValue
            title = titleValue
        } else {
            // Fallback - try both
            name = try container.decode(String.self, forKey: .name)
            title = name
        }

        description = try container.decode(String.self, forKey: .description)
        price = try container.decode(Double.self, forKey: .price)

        // Handle originalPrice/comparePrice mapping
        if let compare = try? container.decode(Double.self, forKey: .comparePrice) {
            originalPrice = compare
            comparePrice = compare
        } else {
            originalPrice = try container.decodeIfPresent(Double.self, forKey: .originalPrice)
            comparePrice = originalPrice
        }

        // Handle seller mapping - support both API structures
        if let sellerIdValue = try? container.decode(String.self, forKey: .sellerId) {
            // Individual product API has sellerId and sellerName directly
            sellerId = sellerIdValue
            sellerName = try container.decodeIfPresent(String.self, forKey: .sellerName) ?? "Unknown Seller"
            seller = sellerId
        } else if let sellerValue = try? container.decode(String.self, forKey: .seller) {
            // Products list API uses "seller" field
            sellerId = sellerValue
            seller = sellerValue
            sellerName = "Unknown Seller" // List API doesn't provide sellerName
        } else {
            // Fallback
            sellerId = try container.decode(String.self, forKey: .sellerId)
            sellerName = try container.decodeIfPresent(String.self, forKey: .sellerName) ?? "Unknown Seller"
            seller = sellerId
        }

        category = try container.decode(String.self, forKey: .category)
        subcategory = try container.decodeIfPresent(String.self, forKey: .subcategory)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        sku = try container.decode(String.self, forKey: .sku)
        // Handle inStock as either Bool or Int (0/1)
        if let inStockBool = try? container.decode(Bool.self, forKey: .inStock) {
            inStock = inStockBool
        } else if let inStockInt = try? container.decode(Int.self, forKey: .inStock) {
            inStock = inStockInt != 0
        } else {
            inStock = false
        }

        // Handle quantity/stock mapping - support both API structures
        if let quantityValue = try? container.decode(Int.self, forKey: .quantity) {
            // Individual product API uses "quantity"
            quantity = quantityValue
            stock = quantityValue
        } else if let stockValue = try? container.decode(Int.self, forKey: .stock) {
            // Products list API uses "stock"
            quantity = stockValue
            stock = stockValue
        } else {
            // Fallback
            quantity = try container.decode(Int.self, forKey: .quantity)
            stock = quantity
        }

        // Handle status/isActive mapping - support both API structures
        if let statusString = try? container.decode(String.self, forKey: .status) {
            // Individual product API uses "status" as string
            status = ProductStatus(rawValue: statusString) ?? .active
            isActive = status == .active
        } else if let activeValue = try? container.decode(Bool.self, forKey: .isActive) {
            // Products list API uses "isActive" boolean
            status = activeValue ? .active : .inactive
            isActive = activeValue
        } else {
            // Fallback
            status = try container.decode(ProductStatus.self, forKey: .status)
            isActive = status == .active
        }

        images = try container.decodeIfPresent([String].self, forKey: .images) ?? []

        // Handle rating/ratings mapping - support both API structures
        if let ratingValue = try? container.decode(Double.self, forKey: .rating) {
            // Individual product API uses separate rating/reviewCount fields
            rating = ratingValue
            reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
            ratings = ProductRatings(average: rating, count: reviewCount)
        } else if let ratingsValue = try? container.decode(ProductRatings.self, forKey: .ratings) {
            // Products list API uses ratings object
            rating = ratingsValue.average
            reviewCount = ratingsValue.count
            ratings = ratingsValue
        } else {
            // Fallback
            rating = try container.decodeIfPresent(Double.self, forKey: .rating) ?? 0
            reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
            ratings = ProductRatings(average: rating, count: reviewCount)
        }

        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []

        // Handle specifications - API returns array, we need dictionary
        if let specificationsArray = try? container.decode([SpecificationItem].self, forKey: .specifications) {
            var specsDict: [String: AnyCodable] = [:]
            for spec in specificationsArray {
                specsDict[spec.name] = AnyCodable(spec.value)
            }
            specifications = specsDict
        } else {
            specifications = try container.decodeIfPresent([String: AnyCodable].self, forKey: .specifications)
        }

        // Handle featured/isFeatured mapping - support both API structures and integer/boolean conversion
        var featuredBool = false

        // Try decoding as Bool first, then as Int for .featured
        if let featuredValue = try? container.decode(Bool.self, forKey: .featured) {
            featuredBool = featuredValue
        } else if let featuredInt = try? container.decode(Int.self, forKey: .featured) {
            featuredBool = featuredInt != 0
        } else if let featuredValue = try? container.decode(Bool.self, forKey: .isFeatured) {
            featuredBool = featuredValue
        } else if let featuredInt = try? container.decode(Int.self, forKey: .isFeatured) {
            featuredBool = featuredInt != 0
        }

        featured = featuredBool
        isFeatured = featuredBool

        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        customizationOptions = try container.decodeIfPresent([ProductCustomization].self, forKey: .customizationOptions)
        // Handle missing date fields with defaults
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()

        // MongoDB specific fields (all optional)
        outOfStockSince = try container.decodeIfPresent(Date.self, forKey: .outOfStockSince)
        baseQuantity = try container.decodeIfPresent(Int.self, forKey: .baseQuantity)
        hasCustomizations = try container.decodeIfPresent(Bool.self, forKey: .hasCustomizations)
        stockManagement = try container.decodeIfPresent(String.self, forKey: .stockManagement)
        categoryTemplate = try container.decodeIfPresent(String.self, forKey: .categoryTemplate)
        categoryFields = try container.decodeIfPresent([String: AnyCodable].self, forKey: .categoryFields)
        hasComparison = try container.decodeIfPresent(Bool.self, forKey: .hasComparison)
        matchingData = try container.decodeIfPresent(AnyCodable.self, forKey: .matchingData)
        comparisonGroup = try container.decodeIfPresent(AnyCodable.self, forKey: .comparisonGroup)

        // New API response fields
        store = try container.decodeIfPresent(String.self, forKey: .store)
        shortDescription = try container.decodeIfPresent(String.self, forKey: .shortDescription)
        costPrice = try container.decodeIfPresent(Double.self, forKey: .costPrice)
        isApproved = try container.decodeIfPresent(Bool.self, forKey: .isApproved)
        metaKeywords = try container.decodeIfPresent([String].self, forKey: .metaKeywords)
        views = try container.decodeIfPresent(Int.self, forKey: .views)
        soldCount = try container.decodeIfPresent(Int.self, forKey: .soldCount)
        variants = try container.decodeIfPresent([String].self, forKey: .variants)
        taxRate = try container.decodeIfPresent(Double.self, forKey: .taxRate)
        reviews = try container.decodeIfPresent([String].self, forKey: .reviews)

        // Installment fields
        installmentPlansRaw = try container.decodeIfPresent([AnyCodable].self, forKey: .installmentPlansRaw)
        hasInstallmentPlans = try container.decodeIfPresent(Bool.self, forKey: .hasInstallmentPlans)
        installmentSettings = try container.decodeIfPresent(InstallmentSettings.self, forKey: .installmentSettings)

        // Raffle fields
        isRaffleTicket = try container.decodeIfPresent(Bool.self, forKey: .isRaffleTicket)
        raffleInfo = try container.decodeIfPresent(ProductRaffleInfo.self, forKey: .raffleInfo)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(price, forKey: .price)
        try container.encodeIfPresent(originalPrice, forKey: .originalPrice)
        try container.encode(sellerId, forKey: .sellerId)
        try container.encode(sellerName, forKey: .sellerName)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(subcategory, forKey: .subcategory)
        try container.encodeIfPresent(brand, forKey: .brand)
        try container.encode(sku, forKey: .sku)
        try container.encode(inStock, forKey: .inStock)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(status, forKey: .status)
        try container.encode(images, forKey: .images)
        try container.encode(rating, forKey: .rating)
        try container.encode(reviewCount, forKey: .reviewCount)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(specifications, forKey: .specifications)
        try container.encode(featured, forKey: .featured)
        try container.encodeIfPresent(slug, forKey: .slug)
        try container.encodeIfPresent(customizationOptions, forKey: .customizationOptions)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)

        // MongoDB specific fields
        try container.encodeIfPresent(outOfStockSince, forKey: .outOfStockSince)
        try container.encodeIfPresent(baseQuantity, forKey: .baseQuantity)
        try container.encodeIfPresent(hasCustomizations, forKey: .hasCustomizations)
        try container.encodeIfPresent(stockManagement, forKey: .stockManagement)
        try container.encodeIfPresent(categoryTemplate, forKey: .categoryTemplate)
        try container.encodeIfPresent(categoryFields, forKey: .categoryFields)
        try container.encodeIfPresent(hasComparison, forKey: .hasComparison)
        try container.encodeIfPresent(matchingData, forKey: .matchingData)
        try container.encodeIfPresent(comparisonGroup, forKey: .comparisonGroup)

        // New API response fields
        try container.encodeIfPresent(seller, forKey: .seller)
        try container.encodeIfPresent(store, forKey: .store)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(shortDescription, forKey: .shortDescription)
        try container.encodeIfPresent(comparePrice, forKey: .comparePrice)
        try container.encodeIfPresent(costPrice, forKey: .costPrice)
        try container.encodeIfPresent(stock, forKey: .stock)
        try container.encodeIfPresent(isActive, forKey: .isActive)
        try container.encodeIfPresent(isApproved, forKey: .isApproved)
        try container.encodeIfPresent(isFeatured, forKey: .isFeatured)
        try container.encodeIfPresent(ratings, forKey: .ratings)
        try container.encodeIfPresent(metaKeywords, forKey: .metaKeywords)
        try container.encodeIfPresent(views, forKey: .views)
        try container.encodeIfPresent(soldCount, forKey: .soldCount)
        try container.encodeIfPresent(variants, forKey: .variants)
        try container.encodeIfPresent(reviews, forKey: .reviews)

        // Installment fields
        try container.encodeIfPresent(installmentPlansRaw, forKey: .installmentPlansRaw)
        try container.encodeIfPresent(hasInstallmentPlans, forKey: .hasInstallmentPlans)
        try container.encodeIfPresent(installmentSettings, forKey: .installmentSettings)

        // Raffle fields
        try container.encodeIfPresent(isRaffleTicket, forKey: .isRaffleTicket)
        try container.encodeIfPresent(raffleInfo, forKey: .raffleInfo)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, description, price, originalPrice, sellerId, sellerName
        case category, subcategory, brand, sku, inStock, quantity, status
        case images, rating, reviewCount, tags, specifications, featured
        case slug, customizationOptions, createdAt, updatedAt
        case outOfStockSince, baseQuantity, hasCustomizations, stockManagement
        case categoryTemplate, categoryFields, hasComparison, matchingData, comparisonGroup

        // New API fields
        case _id, seller, store, title, shortDescription, comparePrice, costPrice, stock
        case isActive, isApproved, isFeatured, ratings, metaKeywords, views, soldCount
        case variants, taxRate, reviews

        // Installment fields
        case hasInstallmentPlans, installmentSettings
        case installmentPlansRaw = "installmentPlans"

        // Raffle fields
        case isRaffleTicket, raffleInfo
    }

    // Computed properties for backward compatibility and enhanced functionality
    var effectiveBrand: String? {
        return brand ?? (specifications?["brand"]?.value as? String)
    }
    var mainImage: String {
        return images.first ?? ""
    }

    var stockCount: Int {
        return stock ?? quantity
    }

    var isProductActive: Bool {
        return isActive ?? (status == .active)
    }

    var isProductFeatured: Bool {
        return isFeatured ?? featured
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

    // MARK: - Installment Helper Methods
    var hasInstallments: Bool {
        return hasInstallmentPlans == true
    }

    // Simple computed property to access raw installment plans data
    var installmentPlans: [[String: Any]]? {
        let plans = installmentPlansRaw?.compactMap { $0.value as? [String: Any] }

        // Debug logging for raw installment data
        if let plans = plans {
            print("📋 [Product] Raw Installment Plans Data:")
            for (index, plan) in plans.enumerated() {
                print("  Plan \(index + 1):")
                for (key, value) in plan {
                    print("    \(key): \(value)")
                }
                print("  ---")
            }
        } else {
            print("📋 [Product] No installment plans found in raw data")
            print("📋 [Product] installmentPlansRaw: \(installmentPlansRaw?.description ?? "nil")")
        }

        return plans
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
    let images: [String]?

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
        case clickCount, featured, parentId, createdBy, slug, sortOrder, productCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)
        productCount = try container.decodeIfPresent(Int.self, forKey: .productCount)
        subcategories = try container.decodeIfPresent([Category].self, forKey: .subcategories)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder)
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom)
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount)
        clickCount = try container.decodeIfPresent(Int.self, forKey: .clickCount)
        featured = try container.decodeIfPresent(Bool.self, forKey: .featured)
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
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

    // Custom initializer to handle integer/boolean conversion
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        page = try container.decode(Int.self, forKey: .page)
        limit = try container.decode(Int.self, forKey: .limit)
        total = try container.decode(Int.self, forKey: .total)
        pages = try container.decode(Int.self, forKey: .pages)

        // Handle hasNext as either Bool or Int (0/1)
        if let nextBool = try? container.decode(Bool.self, forKey: .hasNext) {
            hasNext = nextBool
        } else if let nextInt = try? container.decode(Int.self, forKey: .hasNext) {
            hasNext = nextInt != 0
        } else {
            hasNext = false
        }

        // Handle hasPrev as either Bool or Int (0/1)
        if let prevBool = try? container.decode(Bool.self, forKey: .hasPrev) {
            hasPrev = prevBool
        } else if let prevInt = try? container.decode(Int.self, forKey: .hasPrev) {
            hasPrev = prevInt != 0
        } else {
            hasPrev = false
        }
    }

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
        print("\n🔧 ===== BUILDING QUERY ITEMS =====\n")
        print("📋 Input parameters for toQueryItems():")
        print("   - category: \(category ?? "nil")")
        print("   - subcategory: \(subcategory ?? "nil")")
        print("   - sellerId: \(sellerId ?? "nil")")
        print("   - minPrice: \(minPrice?.description ?? "nil")")
        print("   - maxPrice: \(maxPrice?.description ?? "nil")")
        print("   - search: \(search ?? "nil")")
        print("   - sortBy: \(sortBy.rawValue)")
        print("   - page: \(page)")
        print("   - limit: \(limit)")

        var items: [URLQueryItem] = []

        if let category = category {
            print("➕ Adding category: \(category)")
            items.append(URLQueryItem(name: "category", value: category))
        } else {
            print("➖ No category specified")
        }

        if let subcategory = subcategory {
            print("➕ Adding subcategory: \(subcategory)")
            items.append(URLQueryItem(name: "subcategory", value: subcategory))
        } else {
            print("➖ No subcategory specified")
        }

        if let sellerId = sellerId {
            print("➕ Adding sellerId: \(sellerId)")
            items.append(URLQueryItem(name: "sellerId", value: sellerId))
        }

        if let minPrice = minPrice {
            print("➕ Adding minPrice: \(minPrice)")
            items.append(URLQueryItem(name: "minPrice", value: String(minPrice)))
        }

        if let maxPrice = maxPrice {
            print("➕ Adding maxPrice: \(maxPrice)")
            items.append(URLQueryItem(name: "maxPrice", value: String(maxPrice)))
        }

        if let search = search {
            print("➕ Adding search: \(search)")
            items.append(URLQueryItem(name: "search", value: search))
        }

        print("➕ Adding sortBy: \(sortBy.rawValue)")
        items.append(URLQueryItem(name: "sortBy", value: sortBy.rawValue))

        print("➕ Adding page: \(page)")
        items.append(URLQueryItem(name: "page", value: String(page)))

        print("➕ Adding limit: \(limit)")
        items.append(URLQueryItem(name: "limit", value: String(limit)))

        if let tags = tags {
            print("➕ Adding tags: \(tags.joined(separator: ","))")
            items.append(URLQueryItem(name: "tags", value: tags.joined(separator: ",")))
        }

        if let inStock = inStock {
            print("➕ Adding inStock: \(inStock)")
            items.append(URLQueryItem(name: "inStock", value: String(inStock)))
        }

        if let featured = featured {
            print("➕ Adding featured: \(featured)")
            items.append(URLQueryItem(name: "featured", value: String(featured)))
        }

        print("\n🏁 FINAL QUERY ITEMS (\(items.count) total):")
        for (index, item) in items.enumerated() {
            print("   [\(index + 1)] \(item.name) = \(item.value ?? "nil")")
        }
        print("\n===== END QUERY ITEMS BUILDING =====\n")

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

// MARK: - Homepage Section Models
struct HomepageSection: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let categoryIdentifier: String
    let images: [String]
    let isActive: Bool
    let displayOrder: Int
    let createdAt: Date?
    let updatedAt: Date?

    // Optional MongoDB fields
    let mongoId: String?

    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, categoryIdentifier, images
        case isActive, displayOrder, createdAt, updatedAt
        case mongoId = "_id"
    }

    var mainImage: String {
        return images.first ?? ""
    }

    var previewImages: [String] {
        return Array(images.prefix(4)) // Take first 4 images for preview grid
    }
}

struct HomepageSectionsResponse: Codable {
    let success: Bool
    let sections: [HomepageSection]
    let message: String?
}

// MARK: - New API Models for Product Parsing

struct ProductRatings: Codable {
    let average: Double
    let count: Int
}

struct SpecificationItem: Codable {
    let id: String?
    let name: String
    let value: String

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, value
    }
}

// MARK: - Installment Settings
struct InstallmentSettings: Codable {
    let enabled: Bool
    let maxInstallmentAmount: Double?
    let eligibilityCriteria: EligibilityCriteria?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle enabled as either Bool or Int (0/1)
        if let enabledBool = try? container.decode(Bool.self, forKey: .enabled) {
            enabled = enabledBool
        } else if let enabledInt = try? container.decode(Int.self, forKey: .enabled) {
            enabled = enabledInt != 0
        } else {
            enabled = false
        }

        maxInstallmentAmount = try container.decodeIfPresent(Double.self, forKey: .maxInstallmentAmount)
        eligibilityCriteria = try container.decodeIfPresent(EligibilityCriteria.self, forKey: .eligibilityCriteria)
    }
}

struct EligibilityCriteria: Codable {
    let minAge: Int
    let minIncome: Double
    let creditCheckRequired: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        minAge = try container.decode(Int.self, forKey: .minAge)
        minIncome = try container.decode(Double.self, forKey: .minIncome)

        // Handle creditCheckRequired as either Bool or Int (0/1)
        if let creditBool = try? container.decode(Bool.self, forKey: .creditCheckRequired) {
            creditCheckRequired = creditBool
        } else if let creditInt = try? container.decode(Int.self, forKey: .creditCheckRequired) {
            creditCheckRequired = creditInt != 0
        } else {
            creditCheckRequired = false
        }
    }
}

// MARK: - Product Extension for Raffle Support

extension Product {
    // Convenience initializer for raffle products
    init(id: String, name: String, description: String, price: Double, originalPrice: Double?, sellerId: String, sellerName: String, category: String, subcategory: String?, brand: String?, sku: String, inStock: Bool, quantity: Int, status: ProductStatus, images: [String], rating: Double, reviewCount: Int, tags: [String], specifications: [String: AnyCodable]?, featured: Bool, slug: String?, customizationOptions: [ProductCustomization]?, createdAt: Date?, updatedAt: Date?, outOfStockSince: Date?, baseQuantity: Int?, hasCustomizations: Bool?, stockManagement: String?, categoryTemplate: String?, categoryFields: [String: AnyCodable]?, hasComparison: Bool?, matchingData: AnyCodable?, comparisonGroup: AnyCodable?, seller: String?, store: String?, title: String?, shortDescription: String?, comparePrice: Double?, costPrice: Double?, stock: Int?, isActive: Bool?, isApproved: Bool?, isFeatured: Bool?, ratings: ProductRatings?, metaKeywords: [String]?, views: Int?, soldCount: Int?, variants: [String]?, taxRate: Double?, reviews: [String]?, hasInstallmentPlans: Bool?, installmentSettings: InstallmentSettings?, installmentPlansRaw: [AnyCodable]?, isRaffleTicket: Bool?, raffleInfo: ProductRaffleInfo?) {

        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.originalPrice = originalPrice
        self.sellerId = sellerId
        self.sellerName = sellerName
        self.category = category
        self.subcategory = subcategory
        self.brand = brand
        self.sku = sku
        self.inStock = inStock
        self.quantity = quantity
        self.status = status
        self.images = images
        self.rating = rating
        self.reviewCount = reviewCount
        self.tags = tags
        self.specifications = specifications
        self.featured = featured
        self.slug = slug
        self.customizationOptions = customizationOptions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.outOfStockSince = outOfStockSince
        self.baseQuantity = baseQuantity
        self.hasCustomizations = hasCustomizations
        self.stockManagement = stockManagement
        self.categoryTemplate = categoryTemplate
        self.categoryFields = categoryFields
        self.hasComparison = hasComparison
        self.matchingData = matchingData
        self.comparisonGroup = comparisonGroup
        self.seller = seller
        self.store = store
        self.title = title
        self.shortDescription = shortDescription
        self.comparePrice = comparePrice
        self.costPrice = costPrice
        self.stock = stock
        self.isActive = isActive
        self.isApproved = isApproved
        self.isFeatured = isFeatured
        self.ratings = ratings
        self.metaKeywords = metaKeywords
        self.views = views
        self.soldCount = soldCount
        self.variants = variants
        self.taxRate = taxRate
        self.reviews = reviews
        self.hasInstallmentPlans = hasInstallmentPlans
        self.installmentSettings = installmentSettings
        self.installmentPlansRaw = installmentPlansRaw
        self.isRaffleTicket = isRaffleTicket
        self.raffleInfo = raffleInfo
    }
}