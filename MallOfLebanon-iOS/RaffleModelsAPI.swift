import Foundation

// MARK: - Raffle Models (Matching Backend API)

struct RaffleProduct: Codable, Identifiable {
    let id: String
    let name: String
    let price: Double
    let images: [String]
    let raffleInfo: RaffleProductInfo?

    var mainImage: String {
        return images.first ?? ""
    }

    var formattedPrice: String {
        return String(format: "%.2f", price)
    }
}

struct RaffleProductInfo: Codable {
    let raffleId: String
    let ticketsPerPurchase: Int?
}

struct Raffle: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let prizeImage: String
    let prizeValue: Double
    let prizeCurrency: String
    let endDate: String
    let currentTickets: Int
    let maxTickets: Int
    let daysLeft: Int
    let percentageSold: Int
    let products: [RaffleProduct]
    let productCount: Int

    // Computed properties for UI
    var timeLeftText: String {
        if daysLeft <= 0 {
            return "Ending Soon!"
        } else if daysLeft == 1 {
            return "1 Day Left!"
        } else {
            return "\(daysLeft) Days Left!"
        }
    }

    var progressText: String {
        return "\(currentTickets) / \(maxTickets)"
    }

    var formattedPrizeValue: String {
        return String(format: "%.0f", prizeValue)
    }

    var isActive: Bool {
        return daysLeft > 0 && currentTickets < maxTickets
    }

    // For cart integration - get the first/cheapest ticket option
    var mainTicketProduct: RaffleProduct? {
        return products.first
    }
}

// MARK: - API Response Models

struct RaffleShowcaseResponse: Codable {
    let success: Bool
    let raffles: [Raffle]
    let count: Int
}

// MARK: - Error Types

enum RaffleError: Error, LocalizedError {
    case noActiveRaffles
    case apiError(String)
    case networkError

    var errorDescription: String? {
        switch self {
        case .noActiveRaffles:
            return "No active raffles available"
        case .apiError(let message):
            return message
        case .networkError:
            return "Network connection error"
        }
    }
}

// MARK: - Raffle Service

@MainActor
class RaffleService: ObservableObject {
    static let shared = RaffleService()

    @Published var raffles: [Raffle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    private init() {}

    // MARK: - Public Methods

    func loadActiveRaffles() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: RaffleShowcaseResponse = try await apiService.request(
                endpoint: "/raffles/showcase",
                method: "GET",
                body: nil as String?
            )

            if response.success {
                raffles = response.raffles
                print("✅ RaffleService: Loaded \(response.count) active raffles")
            } else {
                errorMessage = "No active raffles available"
                raffles = []
            }
        } catch {
            print("❌ RaffleService: Failed to load raffles - \(error.localizedDescription)")
            errorMessage = "Failed to load raffles"
            raffles = []
        }

        isLoading = false
    }

    func refreshRaffles() async {
        await loadActiveRaffles()
    }

    func getRaffleById(_ raffleId: String) -> Raffle? {
        return raffles.first { $0.id == raffleId }
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Raffle Section SwiftUI View

struct RaffleSection: View {
    @StateObject private var raffleService = RaffleService.shared
    @EnvironmentObject var cartManager: CartManager

    @State private var showingAllRaffles = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            sectionHeader

            // Content
            if raffleService.isLoading {
                loadingView
            } else if let errorMessage = raffleService.errorMessage {
                errorView(errorMessage)
            } else if raffleService.raffles.isEmpty {
                emptyStateView
            } else {
                rafflesContent
            }
        }
        .padding(.horizontal, 16)
        .task {
            if raffleService.raffles.isEmpty {
                await raffleService.loadActiveRaffles()
            }
        }
        .refreshable {
            await raffleService.refreshRaffles()
        }
        .sheet(isPresented: $showingAllRaffles) {
            AllRafflesView()
                .environmentObject(cartManager)
        }
    }

    // MARK: - View Components

    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    Text("Active Raffles")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                Text("Win amazing prizes with every purchase!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if raffleService.raffles.count > 1 {
                Button("View All") {
                    showingAllRaffles = true
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading amazing prizes...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Unable to load raffles")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await raffleService.refreshRaffles()
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("No Active Raffles")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Check back soon for exciting new raffles!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var rafflesContent: some View {
        VStack(spacing: 12) {
            // Featured raffle (first one)
            if let featuredRaffle = raffleService.raffles.first {
                RaffleCard(raffle: featuredRaffle) {
                    handleBuyTicket(for: featuredRaffle)
                }
            }

            // Additional raffles horizontally if more than 1
            if raffleService.raffles.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(raffleService.raffles.dropFirst()), id: \.id) { raffle in
                            RaffleCardCompact(raffle: raffle) {
                                handleBuyTicket(for: raffle)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16) // Offset section padding
            }
        }
    }

    private func handleBuyTicket(for raffle: Raffle) {
        guard raffle.isActive else {
            return
        }

        // Create raffle ticket product and add to cart
        if let ticketProduct = raffle.mainTicketProduct {
            // Create a product that's compatible with the cart system
            if let cartProduct = createCartCompatibleProduct(from: ticketProduct, raffle: raffle) {
                cartManager.addProduct(cartProduct, quantity: 1)

                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()

                print("🎫 Added raffle ticket '\(raffle.title)' to cart")
            }
        }
    }

    // Helper to create cart-compatible product
    private func createCartCompatibleProduct(from raffleProduct: RaffleProduct, raffle: Raffle) -> Product? {
        // Note: This creates a simplified Product for cart integration
        // In a real implementation, you might want to fetch the full product details
        return Product(
            id: raffleProduct.id,
            name: "\(raffleProduct.name) - \(raffle.title)",
            description: "Raffle entry for \(raffle.title). Win \(raffle.prizeCurrency)\(raffle.formattedPrizeValue)!",
            price: raffleProduct.price,
            originalPrice: nil,
            sellerId: "mall-of-lebanon",
            sellerName: "Mall of Lebanon",
            category: "raffle",
            subcategory: "tickets",
            brand: "Mall of Lebanon",
            sku: "RAFFLE-\(raffle.id)",
            inStock: raffle.isActive,
            quantity: max(0, raffle.maxTickets - raffle.currentTickets),
            status: raffle.isActive ? .active : .inactive,
            images: [raffle.prizeImage],
            rating: 5.0,
            reviewCount: 0,
            tags: ["raffle", "giveaway", raffle.title],
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
            title: raffleProduct.name,
            shortDescription: "Enter raffle to win \(raffle.title)!",
            comparePrice: nil,
            costPrice: nil,
            stock: max(0, raffle.maxTickets - raffle.currentTickets),
            isActive: raffle.isActive,
            isApproved: true,
            isFeatured: true,
            ratings: nil,
            metaKeywords: ["raffle", "giveaway", raffle.title],
            views: 0,
            soldCount: raffle.currentTickets,
            variants: nil,
            reviews: nil,
            hasInstallmentPlans: false,
            installmentSettings: nil,
            isRaffleTicket: true,
            raffleInfo: ProductRaffleInfo(
                raffleId: raffle.id,
                raffleTitle: raffle.title,
                ticketsPerPurchase: raffleProduct.raffleInfo?.ticketsPerPurchase ?? 1,
                drawDate: raffle.endDate
            )
        )
    }
}

// MARK: - Raffle Cards

struct RaffleCard: View {
    let raffle: Raffle
    let onBuyTicket: () -> Void

    @State private var showingDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Prize Image Section
            prizeImageSection

            // Content Section
            raffleInfoSection

            // Action Section
            actionSection
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var prizeImageSection: some View {
        ZStack {
            // Prize Image
            CachedImageView(
                url: URL(string: raffle.prizeImage),
                placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                },
                failureView: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            VStack {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                Text("Prize")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        )
                }
            )
            .aspectRatio(contentMode: .fill)
            .frame(height: 180)
            .clipped()
            .cornerRadius(12)

            // Prize Badge
            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("PRIZE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
                }
                Spacer()
            }
            .padding(8)
        }
    }

    private var raffleInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(raffle.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(2)

            // Prize Value
            HStack {
                Text(raffle.prizeCurrency)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Text(raffle.formattedPrizeValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text("VALUE")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Stats Row
            HStack {
                // Time Left
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(raffle.timeLeftText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                    Text("Time Left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Tickets Progress
                VStack(alignment: .trailing, spacing: 4) {
                    Text(raffle.progressText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text("\(raffle.percentageSold)% Sold")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue,
                                    Color.purple
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * (CGFloat(raffle.percentageSold) / 100.0),
                            height: 6
                        )
                        .animation(.easeInOut(duration: 0.3), value: raffle.percentageSold)
                }
            }
            .frame(height: 6)
        }
    }


    private var actionSection: some View {
        VStack(spacing: 8) {
            // Entry Products Info
            if raffle.productCount > 0 {
                HStack {
                    Image(systemName: "ticket.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("\(raffle.productCount) entry option\(raffle.productCount > 1 ? "s" : "") available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            // Buy Ticket Button
            Button(action: onBuyTicket) {
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("Enter Raffle")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                    if let product = raffle.mainTicketProduct {
                        Text("$\(product.formattedPrice)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue,
                            Color.purple
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
            .disabled(!raffle.isActive)
            .opacity(raffle.isActive ? 1.0 : 0.6)
        }
    }
}

struct RaffleCardCompact: View {
    let raffle: Raffle
    let onBuyTicket: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Prize Image
            CachedImageView(
                url: URL(string: raffle.prizeImage),
                placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(ProgressView().scaleEffect(0.6))
                },
                failureView: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            Image(systemName: "gift.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        )
                }
            )
            .aspectRatio(contentMode: .fill)
            .frame(height: 100)
            .clipped()
            .cornerRadius(8)

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(raffle.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Text("\(raffle.prizeCurrency)\(raffle.formattedPrizeValue)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)

                Text(raffle.timeLeftText)
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            // Button
            Button(action: onBuyTicket) {
                Text("Enter")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(6)
            }
            .disabled(!raffle.isActive)
            .opacity(raffle.isActive ? 1.0 : 0.6)
        }
        .padding(12)
        .frame(width: 140)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct AllRafflesView: View {
    @StateObject private var raffleService = RaffleService.shared
    @EnvironmentObject var cartManager: CartManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(raffleService.raffles, id: \.id) { raffle in
                        RaffleCard(raffle: raffle) {
                            handleBuyTicket(for: raffle)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("All Raffles")
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
            .refreshable {
                await raffleService.refreshRaffles()
            }
        }
    }

    private func handleBuyTicket(for raffle: Raffle) {
        // Same implementation as in RaffleSection
        guard raffle.isActive else { return }

        if let ticketProduct = raffle.mainTicketProduct {
            // Add to cart logic here
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            print("🎫 Added raffle ticket '\(raffle.title)' to cart from All Raffles view")
        }
    }
}