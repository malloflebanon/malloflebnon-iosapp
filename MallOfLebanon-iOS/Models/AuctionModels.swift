import Foundation

// MARK: - Live Auction Models
// These match exactly with frontend TypeScript interfaces

struct LiveAuction: Codable, Identifiable {
    let _id: String
    let title: String
    let description: String
    let sellerId: String?
    let storeId: String?
    let status: AuctionStatus
    let currentViewers: Int
    let scheduledStartTime: String?
    let actualStartTime: String?
    let currency: String
    let streamUrl: String?
    let streamPlatform: StreamPlatform?
    let currentItem: AuctionItem?
    let currentBid: Double?
    let itemCount: Int?
    let region: String?
    let thumbnailImage: String?
    let createdAt: String?

    var id: String { _id }

    enum CodingKeys: String, CodingKey {
        case _id, title, description, sellerId, storeId, status
        case currentViewers, scheduledStartTime, actualStartTime, currency
        case streamUrl, streamPlatform, currentItem, currentBid, itemCount
        case region, thumbnailImage, createdAt
    }
}

struct AuctionSeller: Codable {
    let firstName: String?
    let lastName: String?
    let _id: String?

    var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        return "\(first) \(last)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct AuctionStore: Codable {
    let name: String?
    let slug: String?
}

enum AuctionStatus: String, Codable, CaseIterable {
    case scheduled = "scheduled"
    case live = "live"
    case ended = "ended"
    case cancelled = "cancelled"
    case paused = "paused"

    var displayName: String {
        switch self {
        case .scheduled: return "Upcoming"
        case .live: return "Live Now"
        case .ended: return "Ended"
        case .cancelled: return "Cancelled"
        case .paused: return "Paused"
        }
    }

    var badgeColor: String {
        switch self {
        case .scheduled: return "blue"
        case .live: return "red"
        case .ended: return "gray"
        case .cancelled: return "gray"
        case .paused: return "orange"
        }
    }
}

enum StreamPlatform: String, Codable {
    case webrtc = "webrtc"
    case youtube = "youtube"
    case facebook = "facebook"
}

// MARK: - Auction Item Models

struct AuctionItem: Codable, Identifiable {
    let _id: String
    let auctionId: String
    let name: String
    let description: String
    let images: [String]
    let startingPrice: Double
    let currentBid: Double?
    let bidIncrement: Double
    let estimatedDuration: Int?
    let itemEndTime: String?
    let remainingSeconds: Int?
    let status: AuctionItemStatus
    let winnerId: String?
    let winningBid: Double?
    let bidCount: Int?
    let category: String?
    let condition: String?
    let weight: Double?
    let dimensions: String?
    let auctionOrder: Int?

    var id: String { _id }

    var nextMinimumBid: Double {
        return (currentBid ?? startingPrice) + bidIncrement
    }

    var formattedCurrentBid: String {
        return String(format: "%.2f", currentBid ?? startingPrice)
    }

    var formattedNextBid: String {
        return String(format: "%.2f", nextMinimumBid)
    }

    enum CodingKeys: String, CodingKey {
        case _id, auctionId, name, description, images, startingPrice
        case currentBid, bidIncrement, estimatedDuration, itemEndTime, remainingSeconds
        case status, winnerId, winningBid, bidCount, category, condition
        case weight, dimensions, auctionOrder
    }
}

enum AuctionItemStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case active = "active"
    case sold = "sold"
    case unsold = "unsold"

    var displayName: String {
        switch self {
        case .pending: return "Coming Up"
        case .active: return "Live Bidding"
        case .sold: return "Sold"
        case .unsold: return "Unsold"
        }
    }
}

// MARK: - Live Bid Models

struct LiveBid: Codable, Identifiable {
    let _id: String
    let bidderId: String?
    let amount: Double
    let timestamp: String
    let status: BidStatus
    let bidType: BidType
    let auctionId: String?
    let itemId: String?
    let walletBalance: Double?
    let frozenAmount: Double?
    let ipAddress: String?
    let userAgent: String?
    let region: String?

    var id: String { _id }

    var formattedAmount: String {
        return String(format: "%.2f", amount)
    }

    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: timestamp) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return timestamp
    }

    enum CodingKeys: String, CodingKey {
        case _id, bidderId, amount, timestamp, status, bidType
        case auctionId, itemId, walletBalance, frozenAmount
        case ipAddress, userAgent, region
    }
}

struct AuctionBidder: Codable {
    let firstName: String?
    let lastName: String?
    let _id: String?

    var displayName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        let fullName = "\(first) \(last)".trimmingCharacters(in: .whitespacesAndNewlines)
        return fullName.isEmpty ? "Anonymous Bidder" : fullName
    }
}

enum BidStatus: String, Codable, CaseIterable {
    case active = "active"
    case outbid = "outbid"
    case winning = "winning"
    case won = "won"
    case lost = "lost"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .outbid: return "Outbid"
        case .winning: return "Winning"
        case .won: return "Won"
        case .lost: return "Lost"
        case .cancelled: return "Cancelled"
        }
    }

    var statusColor: String {
        switch self {
        case .active: return "blue"
        case .outbid: return "red"
        case .winning: return "green"
        case .won: return "green"
        case .lost: return "gray"
        case .cancelled: return "gray"
        }
    }
}

enum BidType: String, Codable {
    case manual = "manual"
    case auto = "auto"
    case proxy = "proxy"
}

// MARK: - API Response Models

struct LiveAuctionsResponse: Codable {
    let success: Bool
    let auctions: [LiveAuction]
    let count: Int
    let message: String?
}

struct UpcomingAuctionsResponse: Codable {
    let success: Bool
    let auctions: [LiveAuction]
    let count: Int
    let message: String?
}

struct AuctionDetailsResponse: Codable {
    let success: Bool
    let auction: LiveAuction
    let items: [AuctionItem]
    let message: String?
}

struct AuctionDetailsArrayResponse: Codable {
    let success: Bool
    let auctions: [LiveAuction]?
    let auction: LiveAuction?
    let items: [AuctionItem]?
    let message: String?
}

struct BidResponse: Codable {
    let success: Bool
    let message: String
    let bid: BidInfo?
    let wallet: WalletInfo?
    let item: ItemInfo?
    let error: String?
}

struct BidInfo: Codable {
    let bidId: String
    let amount: Double
    let status: String
    let timestamp: String
}

struct WalletInfo: Codable {
    let newAvailableBalance: Double
    let frozenAmount: Double
    let currency: String
}

struct ItemInfo: Codable {
    let currentBid: Double
    let nextMinimumBid: Double
}

struct UserBidsResponse: Codable {
    let success: Bool
    let bids: [LiveBid]
    let pagination: PaginationInfo
    let message: String?
}

struct AuctionWalletResponse: Codable {
    let success: Bool
    let wallet: AuctionWallet
    let message: String?
}

struct AuctionWallet: Codable {
    let balance: Double
    let frozenAmount: Double
    let availableBalance: Double
    let currency: String
    let totalSpent: Double
    let userInfo: UserInfo
}

struct UserInfo: Codable {
    let name: String
    let userId: String
}


// MARK: - Request Models

struct PlaceBidRequest: Codable {
    let itemId: String
    let amount: Double
}

// MARK: - WebSocket Models (for real-time updates)

struct BidUpdateData: Codable {
    let auctionId: String
    let itemId: String
    let bidAmount: Double
    let bidderId: String
    let bidderName: String
    let timestamp: String
    let isNewHighest: Bool
}

struct OutbidNotification: Codable {
    let auctionId: String
    let itemId: String
    let itemName: String
    let yourBid: Double
    let newHighestBid: Double
    let message: String
}

struct ViewerCountUpdate: Codable {
    let auctionId: String
    let viewerCount: Int
}

struct ChatMessage: Codable {
    let id: String
    let userId: String
    let username: String
    let message: String
    let timestamp: String
    let type: String
}

// MARK: - Helper Extensions

extension LiveAuction {
    var isLive: Bool {
        return status == .live
    }

    var isUpcoming: Bool {
        return status == .scheduled
    }

    var hasStarted: Bool {
        return status != .scheduled
    }

    var displayStatus: String {
        return status.displayName
    }

    var primaryImageURL: String? {
        return currentItem?.images.first ?? thumbnailImage
    }

    var formattedViewerCount: String {
        if currentViewers == 0 {
            return "No viewers"
        } else if currentViewers == 1 {
            return "1 viewer"
        } else {
            return "\(currentViewers) viewers"
        }
    }
}

extension AuctionItem {
    var primaryImageURL: String? {
        return images.first
    }

    var hasImages: Bool {
        return !images.isEmpty
    }

    var isActive: Bool {
        return status == .active
    }

    var isSold: Bool {
        return status == .sold
    }

    var hasBids: Bool {
        return (bidCount ?? 0) > 0
    }

    // Display price that handles 0 currentBid properly
    var displayPrice: Double {
        print("🔍 [AuctionItem] displayPrice calculation for '\(name)':")
        print("🔍 [AuctionItem] - currentBid: \(currentBid ?? -999)")
        print("🔍 [AuctionItem] - startingPrice: \(startingPrice)")

        // If currentBid exists and is greater than 0, use it
        if let bid = currentBid, bid > 0 {
            print("🔍 [AuctionItem] Using currentBid: \(bid)")
            return bid
        }

        // Otherwise, use startingPrice (handles both nil currentBid and 0 currentBid)
        print("🔍 [AuctionItem] Using startingPrice: \(startingPrice)")
        return startingPrice
    }
}

extension LiveBid {
    var isWinning: Bool {
        return status == .winning || status == .won
    }

    var wasOutbid: Bool {
        return status == .outbid || status == .lost
    }
}

// MARK: - Socket Event Models (Additional)

struct AuctionStartData: Codable {
    let auctionId: String
    let auctionTitle: String
    let startTime: String
    let estimatedDuration: Int?
    let message: String?
}

struct AuctionEndData: Codable {
    let auctionId: String
    let auctionTitle: String
    let endTime: String
    let totalItemsSold: Int?
    let totalRevenue: Double?
    let message: String?
}

struct BidWonData: Codable {
    let auctionId: String
    let itemId: String
    let itemName: String
    let winningBid: Double
    let bidderId: String
    let message: String
    let timestamp: String
}

struct NewItemData: Codable {
    let auctionId: String
    let item: AuctionItem
    let previousItemId: String?
    let message: String?
    let timestamp: String
}