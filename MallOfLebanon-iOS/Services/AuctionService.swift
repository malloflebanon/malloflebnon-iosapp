import Foundation
import Combine

class AuctionService: ObservableObject {
    static let shared = AuctionService()

    private let apiService = APIService.shared

    private init() {}

    // MARK: - Core Auction APIs (matching frontend exactly)

    /// GET /api/auction/live
    /// Fetch all live auctions - matches frontend getLiveAuctions()
    func getLiveAuctions() -> AnyPublisher<[LiveAuction], APIError> {
        print("🔍 [AuctionService] Starting getLiveAuctions() request...")
        print("🔗 [AuctionService] API Base URL: \(apiService.baseURLForDebugging)")
        print("🛣️ [AuctionService] Full endpoint: \(apiService.baseURLForDebugging)/auction/live")

        return apiService.performRequest(
            endpoint: "/auction/live",
            method: .GET,
            responseType: LiveAuctionsResponse.self
        )
        .tryMap { response in
            print("✅ [AuctionService] Received live auctions response:")
            print("📊 [AuctionService] Success: \(response.success)")
            print("📋 [AuctionService] Message: \(response.message ?? "nil")")
            print("🔢 [AuctionService] Count: \(response.count)")
            print("📦 [AuctionService] Auctions array count: \(response.auctions.count)")

            for (index, auction) in response.auctions.enumerated() {
                print("🎯 [AuctionService] Auction \(index + 1): \(auction.title) (Status: \(auction.status.displayName))")
            }

            guard response.success else {
                let errorMsg = response.message ?? "Failed to fetch live auctions"
                print("❌ [AuctionService] API returned success=false: \(errorMsg)")
                throw APIError.serverError(errorMsg)
            }

            print("📡 [AuctionService] Successfully fetched \(response.auctions.count) live auctions")
            return response.auctions
        }
        .mapError { error in
            print("💥 [AuctionService] Error in getLiveAuctions():")
            print("🚨 [AuctionService] Error type: \(type(of: error))")
            print("📝 [AuctionService] Error description: \(error.localizedDescription)")

            if let apiError = error as? APIError {
                print("🔧 [AuctionService] APIError details: \(apiError)")
                return apiError
            }

            let finalError = APIError.serverError(error.localizedDescription)
            print("🔄 [AuctionService] Converted to APIError: \(finalError)")
            return finalError
        }
        .eraseToAnyPublisher()
    }

    /// GET /api/auction/upcoming
    /// Fetch upcoming scheduled auctions - matches frontend getUpcomingAuctions()
    func getUpcomingAuctions() -> AnyPublisher<[LiveAuction], APIError> {
        return apiService.performRequest(
            endpoint: "/auction/upcoming",
            method: .GET,
            responseType: UpcomingAuctionsResponse.self
        )
        .tryMap { response in
            guard response.success else {
                throw APIError.serverError(response.message ?? "Failed to fetch upcoming auctions")
            }
            print("📡 [AuctionService] Fetched \(response.auctions.count) upcoming auctions")
            return response.auctions
        }
        .mapError { error in
            if let apiError = error as? APIError {
                return apiError
            }
            return APIError.serverError(error.localizedDescription)
        }
        .eraseToAnyPublisher()
    }

    /// GET /api/auction/{auctionId}
    /// Fetch auction details with items - matches frontend getAuctionDetails()
    func getAuctionDetails(auctionId: String) -> AnyPublisher<(LiveAuction, [AuctionItem]), APIError> {
        print("🔍 [AuctionService] Starting getAuctionDetails() for auction ID: \(auctionId)")
        print("🔗 [AuctionService] API Base URL: \(apiService.baseURLForDebugging)")
        print("🛣️ [AuctionService] Full endpoint: \(apiService.baseURLForDebugging)/auction/\(auctionId)")

        return apiService.performRequest(
            endpoint: "/auction/\(auctionId)",
            method: .GET,
            responseType: AuctionDetailsResponse.self
        )
        .tryMap { response in
            print("✅ [AuctionService] Received auction details response:")
            print("📊 [AuctionService] Success: \(response.success)")
            print("📋 [AuctionService] Message: \(response.message ?? "nil")")
            print("🎯 [AuctionService] Auction Title: \(response.auction.title)")
            print("📈 [AuctionService] Auction Status: \(response.auction.status.displayName)")
            print("👥 [AuctionService] Current Viewers: \(response.auction.currentViewers)")
            print("📦 [AuctionService] Items count: \(response.items.count)")

            if response.items.isEmpty {
                print("⚠️ [AuctionService] No items found in auction!")
            } else {
                for (index, item) in response.items.enumerated() {
                    print("🎯 [AuctionService] Item \(index + 1): \(item.name) - Status: \(item.status.displayName)")
                    print("💰 [AuctionService] Current Bid: \(item.currentBid ?? 0)")
                }
            }

            guard response.success else {
                let errorMsg = response.message ?? "Failed to fetch auction details"
                print("❌ [AuctionService] API returned success=false: \(errorMsg)")
                throw APIError.serverError(errorMsg)
            }

            print("📡 [AuctionService] Successfully fetched auction '\(response.auction.title)' with \(response.items.count) items")
            return (response.auction, response.items)
        }
        .mapError { error in
            print("💥 [AuctionService] Error in getAuctionDetails() for auction \(auctionId):")
            print("🚨 [AuctionService] Error type: \(type(of: error))")
            print("📝 [AuctionService] Error description: \(error.localizedDescription)")

            if let apiError = error as? APIError {
                print("🔧 [AuctionService] APIError details: \(apiError)")
                return apiError
            }

            let finalError = APIError.serverError(error.localizedDescription)
            print("🔄 [AuctionService] Converted to APIError: \(finalError)")
            return finalError
        }
        .eraseToAnyPublisher()
    }

    /// POST /api/auction/{auctionId}/bid
    /// Place a bid on auction item - matches frontend placeBid()
    func placeBid(auctionId: String, itemId: String, amount: Double) -> AnyPublisher<BidResponse, APIError> {
        let bidRequest = PlaceBidRequest(itemId: itemId, amount: amount)

        guard let requestData = try? JSONEncoder().encode(bidRequest) else {
            return Fail(error: APIError.serverError("Failed to encode bid request"))
                .eraseToAnyPublisher()
        }

        return apiService.performRequest(
            endpoint: "/auction/\(auctionId)/bid",
            method: .POST,
            body: requestData,
            responseType: BidResponse.self
        )
        .map { response in
            print("📡 [AuctionService] Bid placed: \(response.success ? "Success" : "Failed") - \(response.message)")
            return response
        }
        .eraseToAnyPublisher()
    }

    /// GET /api/auction/user/bids
    /// Get user's bid history - matches frontend getUserBids()
    func getUserBids(page: Int = 1, limit: Int = 20, status: String? = nil) -> AnyPublisher<([LiveBid], PaginationInfo), APIError> {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let status = status, status != "all" {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }

        var components = URLComponents()
        components.queryItems = queryItems
        let queryString = components.query ?? ""

        return apiService.performRequest(
            endpoint: "/auction/user/bids?\(queryString)",
            method: .GET,
            responseType: UserBidsResponse.self
        )
        .tryMap { response in
            guard response.success else {
                throw APIError.serverError(response.message ?? "Failed to fetch bid history")
            }
            print("📡 [AuctionService] Fetched \(response.bids.count) user bids")
            return (response.bids, response.pagination)
        }
        .mapError { error in
            if let apiError = error as? APIError {
                return apiError
            }
            return APIError.serverError(error.localizedDescription)
        }
        .eraseToAnyPublisher()
    }

    /// GET /api/auction/user/wallet
    /// Get auction wallet summary - matches frontend getAuctionWallet()
    func getAuctionWallet() -> AnyPublisher<AuctionWallet, APIError> {
        return apiService.performRequest(
            endpoint: "/auction/user/wallet",
            method: .GET,
            responseType: AuctionWalletResponse.self
        )
        .tryMap { response in
            guard response.success else {
                throw APIError.serverError(response.message ?? "Failed to fetch auction wallet")
            }
            print("📡 [AuctionService] Fetched wallet - Available: \(response.wallet.availableBalance) \(response.wallet.currency)")
            return response.wallet
        }
        .mapError { error in
            if let apiError = error as? APIError {
                return apiError
            }
            return APIError.serverError(error.localizedDescription)
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Convenience Methods

    /// Validate if user can place a bid amount
    func validateBidAmount(_ amount: Double) -> AnyPublisher<(isValid: Bool, availableBalance: Double, message: String?), APIError> {
        return getAuctionWallet()
            .map { wallet in
                let isValid = wallet.availableBalance >= amount
                let message = isValid ? nil : "Insufficient balance. Available: \(wallet.availableBalance) \(wallet.currency)"

                return (
                    isValid: isValid,
                    availableBalance: wallet.availableBalance,
                    message: message
                )
            }
            .catch { error in
                Just((
                    isValid: false,
                    availableBalance: 0.0,
                    message: "Unable to validate balance: \(error.localizedDescription)"
                ))
                .setFailureType(to: APIError.self)
            }
            .eraseToAnyPublisher()
    }

    /// Get combined live and upcoming auctions for homepage
    func getHomeAuctions() -> AnyPublisher<(live: [LiveAuction], upcoming: [LiveAuction]), APIError> {
        let livePublisher = getLiveAuctions()
        let upcomingPublisher = getUpcomingAuctions()

        return Publishers.Zip(livePublisher, upcomingPublisher)
            .map { (live, upcoming) in
                print("📡 [AuctionService] Home auctions: \(live.count) live, \(upcoming.count) upcoming")
                return (live: live, upcoming: upcoming)
            }
            .eraseToAnyPublisher()
    }

    /// Get current bid status for specific item
    func getCurrentBidForItem(itemId: String) -> AnyPublisher<LiveBid?, APIError> {
        return getUserBids(limit: 50)
            .map { (bids, _) in
                // Find the latest bid for this item
                return bids
                    .filter { $0.itemId == itemId }
                    .sorted { bid1, bid2 in
                        let formatter = ISO8601DateFormatter()
                        let date1 = formatter.date(from: bid1.timestamp) ?? Date.distantPast
                        let date2 = formatter.date(from: bid2.timestamp) ?? Date.distantPast
                        return date1 > date2
                    }
                    .first
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Helper Response Type

struct EmptyResponse: Codable {
    // For endpoints that don't return specific data
}