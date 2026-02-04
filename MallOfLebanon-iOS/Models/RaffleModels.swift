import Foundation

// MARK: - Raffle Models

struct Raffle: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let prizeImage: String
    let prizeValue: Double
    let prizeCurrency: String
    let startDate: String
    let endDate: String
    let drawDate: String
    let maxTickets: Int
    let currentTickets: Int
    let ticketPrice: Double
    let status: String
    let region: String
    let products: [RaffleProduct]
    let productCount: Int

    // Computed properties
    var daysLeft: Int {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let endDate = formatter.date(from: endDate) else { return 0 }
        let now = Date()
        let timeInterval = endDate.timeIntervalSince(now)
        return max(0, Int(timeInterval / (24 * 60 * 60)))
    }

    var percentageSold: Int {
        guard maxTickets > 0 else { return 0 }
        return Int((Double(currentTickets) / Double(maxTickets)) * 100)
    }

    var isActive: Bool {
        return status == "active"
    }

    var formattedPrizeValue: String {
        return String(format: "%.0f", prizeValue)
    }

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
}

struct RaffleProduct: Codable, Identifiable {
    let id: String
    let name: String
    let price: Double
    let images: [String]
    let isRaffleTicket: Bool?

    var mainImage: String {
        return images.first ?? ""
    }

    var formattedPrice: String {
        return String(format: "%.2f", price)
    }
}

// MARK: - Raffle API Response Models

struct RaffleShowcaseResponse: Codable {
    let success: Bool
    let raffles: [Raffle]?
    let message: String?
}

struct RaffleDetailResponse: Codable {
    let success: Bool
    let raffle: Raffle?
    let message: String?
}

// MARK: - Raffle Ticket Models

struct RaffleTicket: Codable, Identifiable {
    let id: String
    let raffleId: String
    let userId: String
    let userName: String
    let userEmail: String
    let orderId: String
    let productId: String
    let productName: String
    let quantity: Int
    let ticketNumbers: [String]
    let purchaseAmount: Double
    let purchaseDate: String
    let region: String
}

struct RaffleTicketResponse: Codable {
    let success: Bool
    let tickets: [RaffleTicket]?
    let message: String?
}

// MARK: - Raffle Status Enums

enum RaffleStatus: String, CaseIterable {
    case draft = "draft"
    case active = "active"
    case ended = "ended"
    case cancelled = "cancelled"
    case drawing = "drawing"
    case completed = "completed"

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .active: return "Active"
        case .ended: return "Ended"
        case .cancelled: return "Cancelled"
        case .drawing: return "Drawing"
        case .completed: return "Completed"
        }
    }

    var color: String {
        switch self {
        case .draft: return "orange"
        case .active: return "green"
        case .ended: return "red"
        case .cancelled: return "gray"
        case .drawing: return "blue"
        case .completed: return "purple"
        }
    }
}

// MARK: - Extensions for CartItem Support

extension CartItem {
    var isRaffleTicket: Bool {
        return sku.hasPrefix("RAFFLE-")
    }

    var raffleDisplayName: String {
        if isRaffleTicket {
            return "\(name) (Raffle Entry)"
        }
        return name
    }

    var raffleTicketCount: Int {
        if isRaffleTicket {
            return quantity
        }
        return 0
    }
}

// MARK: - Sample Data for Testing

extension Raffle {
    static let sampleRaffles: [Raffle] = [
        Raffle(
            id: "RAFFLE_1704312000000_ABC123DEF",
            title: "iPhone 15 Pro Max Giveaway",
            description: "Win the latest iPhone 15 Pro Max 256GB in Titanium Blue. Enter now for your chance to win this amazing prize!",
            prizeImage: "https://via.placeholder.com/400x400/007AFF/FFFFFF?text=iPhone+15+Pro",
            prizeValue: 1199.99,
            prizeCurrency: "USD",
            startDate: "2024-01-01T00:00:00.000Z",
            endDate: "2024-02-01T23:59:59.000Z",
            drawDate: "2024-02-02T12:00:00.000Z",
            maxTickets: 1000,
            currentTickets: 756,
            ticketPrice: 5.99,
            status: "active",
            region: "lebanon",
            products: [
                RaffleProduct(
                    id: "PROD_RAFFLE_001",
                    name: "Raffle Entry Ticket",
                    price: 5.99,
                    images: ["https://via.placeholder.com/200x200/FF6B6B/FFFFFF?text=Ticket"],
                    isRaffleTicket: true
                ),
                RaffleProduct(
                    id: "PROD_RAFFLE_002",
                    name: "5 Entry Bundle",
                    price: 24.99,
                    images: ["https://via.placeholder.com/200x200/4ECDC4/FFFFFF?text=5+Tickets"],
                    isRaffleTicket: true
                )
            ],
            productCount: 2
        ),
        Raffle(
            id: "RAFFLE_1704398400000_XYZ789GHI",
            title: "MacBook Pro 14\" Raffle",
            description: "Win a brand new MacBook Pro 14\" with M3 chip. Perfect for work, creativity, and everything in between.",
            prizeImage: "https://via.placeholder.com/400x400/6C757D/FFFFFF?text=MacBook+Pro",
            prizeValue: 1999.99,
            prizeCurrency: "USD",
            startDate: "2024-01-02T00:00:00.000Z",
            endDate: "2024-02-15T23:59:59.000Z",
            drawDate: "2024-02-16T15:00:00.000Z",
            maxTickets: 2000,
            currentTickets: 423,
            ticketPrice: 9.99,
            status: "active",
            region: "lebanon",
            products: [
                RaffleProduct(
                    id: "PROD_RAFFLE_003",
                    name: "MacBook Entry Ticket",
                    price: 9.99,
                    images: ["https://via.placeholder.com/200x200/FF6B6B/FFFFFF?text=Ticket"],
                    isRaffleTicket: true
                )
            ],
            productCount: 1
        )
    ]
}