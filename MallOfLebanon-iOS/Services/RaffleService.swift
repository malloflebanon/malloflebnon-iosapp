import Foundation
import Combine

class RaffleService: ObservableObject {
    static let shared = RaffleService()

    @Published var raffles: [Raffle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    private init() {}

    // MARK: - Public Methods

    func loadRaffles() {
        isLoading = true
        errorMessage = nil

        apiService.request(endpoint: "/raffles/showcase", method: "GET", body: nil as [String: String]?)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("❌ RaffleService: Failed to load raffles - \(error.localizedDescription)")
                        self?.errorMessage = "Failed to load raffles"
                        // Use sample data for development
                        self?.raffles = Raffle.sampleRaffles
                    }
                },
                receiveValue: { [weak self] (response: RaffleShowcaseResponse) in
                    if response.success, let raffles = response.raffles {
                        print("✅ RaffleService: Loaded \(raffles.count) raffles")
                        self?.raffles = raffles
                    } else {
                        print("⚠️ RaffleService: No raffles available")
                        self?.errorMessage = response.message ?? "No active raffles"
                        // Use sample data for development
                        self?.raffles = Raffle.sampleRaffles
                    }
                }
            )
            .store(in: &cancellables)
    }

    func getRaffleById(_ raffleId: String) -> Raffle? {
        return raffles.first { $0.id == raffleId }
    }

    func refreshRaffles() {
        loadRaffles()
    }

    // MARK: - Raffle Product Purchase

    func createRaffleProduct(from raffle: Raffle, ticketCount: Int = 1) -> Product? {
        guard let raffleProduct = raffle.products.first else {
            print("❌ RaffleService: No raffle products available for \(raffle.title)")
            return nil
        }

        // Create a Product object that's compatible with the cart system
        return Product(
            id: raffleProduct.id,
            name: raffleProduct.name,
            description: "Raffle entry for \(raffle.title). Each purchase gives you \(ticketCount) ticket(s) to win \(raffle.prizeCurrency)\(raffle.formattedPrizeValue)!",
            price: raffleProduct.price,
            originalPrice: nil,
            sellerId: "mall-of-lebanon",
            sellerName: "Mall of Lebanon",
            category: "raffle",
            subcategory: "tickets",
            brand: "Mall of Lebanon",
            sku: "RAFFLE-\(raffle.id)",
            inStock: raffle.currentTickets < raffle.maxTickets,
            quantity: max(0, raffle.maxTickets - raffle.currentTickets),
            status: raffle.isActive ? .active : .inactive,
            images: [raffle.prizeImage],
            rating: 5.0,
            reviewCount: 0,
            tags: ["raffle", "giveaway", "prize"],
            specifications: nil,
            featured: true,
            slug: "raffle-\(raffle.id)",
            customizationOptions: nil,

    // Create compatible raffle product from API raffle data
    func createRaffleProduct(from raffle: APIRaffle, ticketCount: Int = 1) -> Product? {
        // Get price from the first available product or use a default
        let ticketPrice = raffle.products?.first?.price ?? 5.0
        let productName = raffle.products?.first?.name ?? "Raffle Entry Ticket"

        // Create a local raffle product ID that won't conflict with backend products
        let productId = "LOCAL_RAFFLE_\(raffle.id)_\(UUID().uuidString)"

        print("🎫 RaffleService: Creating LOCAL product from API raffle")
        print("   - Using LOCAL Product ID: \(productId)")
        print("   - Product Name: \(productName)")
        print("   - Ticket Price: $\(ticketPrice)")
        print("   - Raffle ID: \(raffle.id)")

        // Create a Product object that's compatible with the cart system
        return Product(
            id: productId, // Use LOCAL product ID to avoid backend conflicts
            name: "🎫 \(raffle.title) - Entry Ticket",
            description: "Raffle entry for \(raffle.title). Each purchase gives you \(ticketCount) ticket(s) to win \(raffle.prizeCurrency ?? "$")\(raffle.prizeValue ?? 0)!",
            price: ticketPrice,
            originalPrice: ticketPrice,
            sellerId: "raffle_system",
            sellerName: "Mall of Lebanon Raffles",
            category: "raffle",
            subcategory: "tickets",
            brand: "Mall of Lebanon",
            sku: "RAFFLE_\(raffle.id)",
            inStock: true, // Always available for raffles
            quantity: 1000, // High quantity for raffle tickets
            status: (raffle.isActive ?? true) ? .active : .inactive,
            images: [raffle.prizeImage ?? ""],
            rating: 5.0,
            reviewCount: 0,
            tags: ["raffle", "giveaway", "prize"],
            specifications: nil,
            featured: true,
            slug: "raffle-\(raffle.id)",
            customizationOptions: nil,
            createdAt: Date(),
            updatedAt: Date(),
            outOfStockSince: nil,
            baseQuantity: nil,
            hasCustomizations: false,
            stockManagement: "auto",
            categoryTemplate: nil,
            categoryFields: nil,
            hasComparison: false,
            matchingData: nil,
            comparisonGroup: nil,
            seller: "Mall of Lebanon",
            store: "Mall of Lebanon",
            title: productName,
            shortDescription: "Win \(raffle.title)!",
            comparePrice: nil,
            costPrice: nil,
            stock: max(0, (raffle.maxTickets ?? 1000) - (raffle.currentTickets ?? 0)),
            isActive: raffle.isActive ?? true,
            isApproved: true,
            isFeatured: true,
            ratings: nil,
            metaKeywords: ["raffle", "giveaway", raffle.title],
            views: 0,
            soldCount: raffle.currentTickets ?? 0,
            variants: nil,
            reviews: nil,
            hasInstallmentPlans: false,
            installmentSettings: nil,
            isRaffleTicket: true,
            raffleInfo: ProductRaffleInfo(
                raffleId: raffle.id,
                raffleTitle: raffle.title,
                ticketsPerPurchase: ticketCount,
                drawDate: raffle.drawDate
            )
        )
    }

    // MARK: - Helper Methods

    func getActiveRaffles() -> [Raffle] {
        return raffles.filter { $0.isActive }
    }

    func getRafflesEndingSoon(days: Int = 3) -> [Raffle] {
        return raffles.filter { $0.isActive && $0.daysLeft <= days }
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Product Extension for Raffle Support

extension Product {
    // Convenience initializer for raffle products
    init(id: String, name: String, description: String, price: Double, originalPrice: Double?, sellerId: String, sellerName: String, category: String, subcategory: String?, brand: String?, sku: String, inStock: Bool, quantity: Int, status: ProductStatus, images: [String], rating: Double, reviewCount: Int, tags: [String], specifications: [String: AnyCodable]?, featured: Bool, slug: String?, customizationOptions: [ProductCustomization]?, createdAt: Date, updatedAt: Date, outOfStockSince: Date?, baseQuantity: Int?, hasCustomizations: Bool?, stockManagement: String?, categoryTemplate: String?, categoryFields: [String: AnyCodable]?, hasComparison: Bool?, matchingData: AnyCodable?, comparisonGroup: AnyCodable?, seller: String?, store: String?, title: String?, shortDescription: String?, comparePrice: Double?, costPrice: Double?, stock: Int?, isActive: Bool?, isApproved: Bool?, isFeatured: Bool?, ratings: ProductRatings?, metaKeywords: [String]?, views: Int?, soldCount: Int?, variants: [String]?, reviews: [String]?, hasInstallmentPlans: Bool?, installmentSettings: InstallmentSettings?, isRaffleTicket: Bool?, raffleInfo: ProductRaffleInfo?) {

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
        self.reviews = reviews
        self.hasInstallmentPlans = hasInstallmentPlans
        self.installmentSettings = installmentSettings
        self.isRaffleTicket = isRaffleTicket
        self.raffleInfo = raffleInfo
    }
}