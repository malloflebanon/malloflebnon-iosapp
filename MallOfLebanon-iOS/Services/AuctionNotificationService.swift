import Foundation
import UserNotifications
import Combine

// MARK: - Auction Notification Service
// Manages push notifications and in-app alerts for auction events (matching frontend NotificationService)

class AuctionNotificationService: NSObject, ObservableObject {
    static let shared = AuctionNotificationService()

    @Published var notificationPermissionGranted = false
    @Published var inAppAlerts: [AuctionAlert] = []

    private var cancellables = Set<AnyCancellable>()
    private let socketService = SocketService.shared

    override init() {
        super.init()
        setupNotifications()
        listenForAuctionEvents()
    }

    // MARK: - Setup

    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermissions()
    }

    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = granted
                if granted {
                    print("📱 [AuctionNotificationService] Notification permissions granted")
                } else {
                    print("❌ [AuctionNotificationService] Notification permissions denied")
                }
            }
        }
    }

    // MARK: - Event Listeners

    private func listenForAuctionEvents() {
        // Listen for outbid notifications
        socketService.onOutbid { [weak self] outbidData in
            DispatchQueue.main.async {
                self?.handleOutbidNotification(outbidData)
            }
        }
        .store(in: &cancellables)

        // Listen for auction start notifications
        socketService.onAuctionStart { [weak self] auctionData in
            DispatchQueue.main.async {
                self?.handleAuctionStartNotification(auctionData)
            }
        }
        .store(in: &cancellables)

        // Listen for auction end notifications
        socketService.onAuctionEnd { [weak self] auctionData in
            DispatchQueue.main.async {
                self?.handleAuctionEndNotification(auctionData)
            }
        }
        .store(in: &cancellables)

        // Listen for winning notifications
        socketService.onBidWon { [weak self] winData in
            DispatchQueue.main.async {
                self?.handleBidWonNotification(winData)
            }
        }
        .store(in: &cancellables)

        // Listen for new item notifications
        socketService.onNewItem { [weak self] itemData in
            DispatchQueue.main.async {
                self?.handleNewItemNotification(itemData)
            }
        }
        .store(in: &cancellables)
    }

    // MARK: - Notification Handlers

    private func handleOutbidNotification(_ data: OutbidData) {
        let alert = AuctionAlert(
            id: UUID().uuidString,
            type: .outbid,
            title: "You've Been Outbid!",
            message: "Your bid on \"\(data.itemName)\" has been exceeded. New highest bid: $\(String(format: "%.0f", data.newHighestBid))",
            timestamp: Date(),
            auctionId: data.auctionId,
            itemId: data.itemId,
            priority: .high
        )

        addInAppAlert(alert)
        sendPushNotification(alert)

        print("⚠️ [AuctionNotificationService] Outbid notification: \(data.itemName)")
    }

    private func handleAuctionStartNotification(_ data: AuctionStartData) {
        let alert = AuctionAlert(
            id: UUID().uuidString,
            type: .auctionStart,
            title: "Auction Started",
            message: "\"\(data.auctionTitle)\" is now live! Join now to start bidding.",
            timestamp: Date(),
            auctionId: data.auctionId,
            itemId: nil,
            priority: .medium
        )

        addInAppAlert(alert)
        sendPushNotification(alert)

        print("🔴 [AuctionNotificationService] Auction started: \(data.auctionTitle)")
    }

    private func handleAuctionEndNotification(_ data: AuctionEndData) {
        let alert = AuctionAlert(
            id: UUID().uuidString,
            type: .auctionEnd,
            title: "Auction Ended",
            message: "\"\(data.auctionTitle)\" has ended. Check your results!",
            timestamp: Date(),
            auctionId: data.auctionId,
            itemId: nil,
            priority: .medium
        )

        addInAppAlert(alert)
        sendPushNotification(alert)

        print("🏁 [AuctionNotificationService] Auction ended: \(data.auctionTitle)")
    }

    private func handleBidWonNotification(_ data: BidWonData) {
        let alert = AuctionAlert(
            id: UUID().uuidString,
            type: .bidWon,
            title: "Congratulations! 🎉",
            message: "You won \"\(data.itemName)\" for $\(String(format: "%.0f", data.winningAmount))!",
            timestamp: Date(),
            auctionId: data.auctionId,
            itemId: data.itemId,
            priority: .high
        )

        addInAppAlert(alert)
        sendPushNotification(alert)

        print("🏆 [AuctionNotificationService] Bid won: \(data.itemName)")
    }

    private func handleNewItemNotification(_ data: NewItemData) {
        let alert = AuctionAlert(
            id: UUID().uuidString,
            type: .newItem,
            title: "New Item Up for Auction",
            message: "\"\(data.itemName)\" is now available for bidding. Starting at $\(String(format: "%.0f", data.startingPrice))",
            timestamp: Date(),
            auctionId: data.auctionId,
            itemId: data.itemId,
            priority: .low
        )

        addInAppAlert(alert)
        // Don't send push notification for new items (too frequent)

        print("🆕 [AuctionNotificationService] New item: \(data.itemName)")
    }

    // MARK: - In-App Alerts

    private func addInAppAlert(_ alert: AuctionAlert) {
        inAppAlerts.insert(alert, at: 0) // Add to beginning for newest first

        // Limit to last 50 alerts
        if inAppAlerts.count > 50 {
            inAppAlerts = Array(inAppAlerts.prefix(50))
        }

        // Auto-remove after 30 seconds for non-critical alerts
        if alert.priority != .high {
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                self?.removeAlert(alert.id)
            }
        }
    }

    func removeAlert(_ alertId: String) {
        inAppAlerts.removeAll { $0.id == alertId }
    }

    func markAlertAsRead(_ alertId: String) {
        if let index = inAppAlerts.firstIndex(where: { $0.id == alertId }) {
            inAppAlerts[index].isRead = true
        }
    }

    func clearAllAlerts() {
        inAppAlerts.removeAll()
    }

    // MARK: - Push Notifications

    private func sendPushNotification(_ alert: AuctionAlert) {
        guard notificationPermissionGranted else {
            print("⚠️ [AuctionNotificationService] Cannot send notification - permissions not granted")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.message
        content.sound = .default
        content.badge = NSNumber(value: getUnreadAlertsCount() + 1)

        // Add custom data
        content.userInfo = [
            "auctionId": alert.auctionId ?? "",
            "itemId": alert.itemId ?? "",
            "alertType": alert.type.rawValue,
            "timestamp": alert.timestamp.timeIntervalSince1970
        ]

        // Set category for interactive notifications
        content.categoryIdentifier = alert.type.notificationCategory

        // Create request
        let request = UNNotificationRequest(
            identifier: alert.id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [AuctionNotificationService] Failed to send notification: \(error)")
            } else {
                print("📱 [AuctionNotificationService] Notification sent: \(alert.title)")
            }
        }
    }

    // MARK: - Utility Methods

    func getUnreadAlertsCount() -> Int {
        return inAppAlerts.filter { !$0.isRead }.count
    }

    func getAlertsForAuction(_ auctionId: String) -> [AuctionAlert] {
        return inAppAlerts.filter { $0.auctionId == auctionId }
    }

    func testNotification() {
        let testAlert = AuctionAlert(
            id: UUID().uuidString,
            type: .outbid,
            title: "Test Notification",
            message: "This is a test notification to verify the system is working.",
            timestamp: Date(),
            auctionId: "test-auction",
            itemId: "test-item",
            priority: .medium
        )

        addInAppAlert(testAlert)
        sendPushNotification(testAlert)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AuctionNotificationService: UNUserNotificationCenterDelegate {

    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        // Show notification even when app is in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

        let userInfo = response.notification.request.content.userInfo

        if let auctionId = userInfo["auctionId"] as? String,
           let alertType = userInfo["alertType"] as? String {

            // Navigate to appropriate screen based on notification type
            handleNotificationTap(auctionId: auctionId, alertType: alertType)
        }

        completionHandler()
    }

    private func handleNotificationTap(auctionId: String, alertType: String) {
        print("🔔 [AuctionNotificationService] Notification tapped - Auction: \(auctionId), Type: \(alertType)")

        // Post notification for app to handle navigation
        NotificationCenter.default.post(
            name: NSNotification.Name("AuctionNotificationTapped"),
            object: nil,
            userInfo: [
                "auctionId": auctionId,
                "alertType": alertType
            ]
        )
    }
}

// MARK: - Supporting Models

struct AuctionAlert: Identifiable, Codable {
    let id: String
    let type: AlertType
    let title: String
    let message: String
    let timestamp: Date
    let auctionId: String?
    let itemId: String?
    let priority: AlertPriority
    var isRead: Bool = false

    enum AlertType: String, Codable, CaseIterable {
        case outbid = "outbid"
        case auctionStart = "auction_start"
        case auctionEnd = "auction_end"
        case bidWon = "bid_won"
        case newItem = "new_item"

        var icon: String {
            switch self {
            case .outbid: return "exclamationmark.triangle.fill"
            case .auctionStart: return "play.circle.fill"
            case .auctionEnd: return "stop.circle.fill"
            case .bidWon: return "trophy.fill"
            case .newItem: return "plus.circle.fill"
            }
        }

        var color: String {
            switch self {
            case .outbid: return "red"
            case .auctionStart: return "green"
            case .auctionEnd: return "blue"
            case .bidWon: return "gold"
            case .newItem: return "purple"
            }
        }

        var notificationCategory: String {
            switch self {
            case .outbid: return "OUTBID_CATEGORY"
            case .auctionStart: return "AUCTION_START_CATEGORY"
            case .auctionEnd: return "AUCTION_END_CATEGORY"
            case .bidWon: return "BID_WON_CATEGORY"
            case .newItem: return "NEW_ITEM_CATEGORY"
            }
        }
    }

    enum AlertPriority: String, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
    }
}

// Supporting Data Models for Socket Events
struct OutbidData: Codable {
    let auctionId: String
    let itemId: String
    let itemName: String
    let newHighestBid: Double
    let outbidUserId: String
}

struct AuctionStartData: Codable {
    let auctionId: String
    let auctionTitle: String
    let scheduledTime: String?
}

struct AuctionEndData: Codable {
    let auctionId: String
    let auctionTitle: String
    let endTime: String
}

struct BidWonData: Codable {
    let auctionId: String
    let itemId: String
    let itemName: String
    let winningAmount: Double
    let winnerId: String
}

struct NewItemData: Codable {
    let auctionId: String
    let itemId: String
    let itemName: String
    let startingPrice: Double
}