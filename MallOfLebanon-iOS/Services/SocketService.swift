import Foundation
import Network
import Combine

// MARK: - Socket Event Models (matching frontend exactly)

struct BidUpdateData: Codable {
    let auctionId: String
    let itemId: String
    let bidAmount: Double
    let bidderId: String
    let bidderName: String
    let timestamp: String
    let isNewHighest: Bool
}

// MARK: - Real Video Streaming Models (matching frontend Canvas-based streaming)

struct LiveFrameData: Codable {
    let auctionId: String
    let imageData: String // base64 data URL
    let quality: String?
    let resolution: String?
    let timestamp: Double?
    let frameNumber: Int?
}

struct QualityRequest: Codable {
    let auctionId: String
    let quality: String // "low", "medium", "high", "ultra"
    let timestamp: String
}

struct OutbidNotificationData: Codable {
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


struct TimerEvent: Codable {
    let auctionId: String
    let itemId: String
    let action: String // "start", "pause", "resume", "end"
    let duration: Int?
    let startTime: String?
    let endTime: String?
    let itemDetails: AuctionItem?
}

// MARK: - WebSocket-based Socket Service
// This provides real-time functionality similar to Socket.IO
// TODO: Replace with actual Socket.IO-Client-Swift when CocoaPods is working

class SocketService: ObservableObject {
    static let shared = SocketService()

    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var lastError: String?

    // MARK: - Private Properties
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let baseURL = APIService.shared.baseURL
    private var currentAuctionId: String?
    private let networkMonitor = NWPathMonitor()

    // MARK: - Combine Publishers
    private let bidUpdateSubject = PassthroughSubject<BidUpdateData, Never>()
    private let outbidSubject = PassthroughSubject<OutbidNotificationData, Never>()
    private let viewerCountSubject = PassthroughSubject<ViewerCountUpdate, Never>()
    private let liveFrameSubject = PassthroughSubject<LiveFrameData, Never>()
    private let timerEventSubject = PassthroughSubject<TimerEvent, Never>()
    private let chatMessageSubject = PassthroughSubject<ChatMessage, Never>()

    // Additional notification events
    private let auctionStartSubject = PassthroughSubject<AuctionStartData, Never>()
    private let auctionEndSubject = PassthroughSubject<AuctionEndData, Never>()
    private let bidWonSubject = PassthroughSubject<BidWonData, Never>()
    private let newItemSubject = PassthroughSubject<NewItemData, Never>()

    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Publishers (Public)
    var bidUpdates: AnyPublisher<BidUpdateData, Never> {
        bidUpdateSubject.eraseToAnyPublisher()
    }

    var outbidNotifications: AnyPublisher<OutbidNotificationData, Never> {
        outbidSubject.eraseToAnyPublisher()
    }

    var viewerCountUpdates: AnyPublisher<ViewerCountUpdate, Never> {
        viewerCountSubject.eraseToAnyPublisher()
    }

    var liveFrames: AnyPublisher<LiveFrameData, Never> {
        liveFrameSubject.eraseToAnyPublisher()
    }

    var timerEvents: AnyPublisher<TimerEvent, Never> {
        timerEventSubject.eraseToAnyPublisher()
    }

    var chatMessages: AnyPublisher<ChatMessage, Never> {
        chatMessageSubject.eraseToAnyPublisher()
    }

    var auctionStarts: AnyPublisher<AuctionStartData, Never> {
        auctionStartSubject.eraseToAnyPublisher()
    }

    var auctionEnds: AnyPublisher<AuctionEndData, Never> {
        auctionEndSubject.eraseToAnyPublisher()
    }

    var bidWins: AnyPublisher<BidWonData, Never> {
        bidWonSubject.eraseToAnyPublisher()
    }

    var newItems: AnyPublisher<NewItemData, Never> {
        newItemSubject.eraseToAnyPublisher()
    }

    private init() {
        urlSession = URLSession(configuration: .default)
        setupNetworkMonitoring()
    }

    deinit {
        disconnect()
        networkMonitor.cancel()
    }

    // MARK: - Public Methods

    func connectToAuction(_ auctionId: String) {
        print("🔌 [SocketService] Connecting to auction: \(auctionId)")

        currentAuctionId = auctionId
        connect()
    }

    func disconnect() {
        print("🔌 [SocketService] Disconnecting...")
        webSocketTask?.cancel()
        webSocketTask = nil
        currentAuctionId = nil

        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Disconnected"
        }
    }

    func sendMessage(_ message: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ [SocketService] Failed to serialize message")
            return
        }

        webSocketTask?.send(.string(jsonString)) { error in
            if let error = error {
                print("❌ [SocketService] Failed to send message: \(error)")
            } else {
                print("📤 [SocketService] Message sent successfully")
            }
        }
    }

    func joinAuction(_ auctionId: String) {
        let message = [
            "event": "join_auction",
            "auctionId": auctionId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        sendMessage(message)
        print("🎯 [SocketService] Joined auction: \(auctionId)")
    }

    func sendChatMessage(_ text: String, auctionId: String) {
        let message = [
            "event": "chat_message",
            "auctionId": auctionId,
            "message": text,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        sendMessage(message)
    }

    func requestStreamQuality(_ quality: String, auctionId: String) {
        print("📡 [SocketService] Requesting stream quality: \(quality) for auction: \(auctionId)")
        let message = [
            "auctionId": auctionId,
            "quality": quality,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        // Send as a direct socket event, matching frontend implementation
        webSocketTask?.send(.string("42[\"request_quality_stream\",\(jsonString(from: message))]")) { error in
            if let error = error {
                print("❌ [SocketService] Failed to send quality request: \(error)")
            } else {
                print("📤 [SocketService] Quality request sent: \(quality)")
            }
        }
    }

    private func jsonString(from dictionary: [String: Any]) -> String {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    // MARK: - Private Methods

    private func connect() {
        // Construct WebSocket URL (convert HTTP to WS)
        let wsURLString = baseURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")

        guard let wsURL = URL(string: "\(wsURLString)/socket.io/") else {
            print("❌ [SocketService] Invalid WebSocket URL")
            return
        }

        print("🔗 [SocketService] Connecting to: \(wsURL)")

        webSocketTask = urlSession?.webSocketTask(with: wsURL)
        webSocketTask?.resume()

        DispatchQueue.main.async {
            self.connectionStatus = "Connecting..."
        }

        // Start listening for messages
        receiveMessage()

        // Send connection acknowledgment after a brief delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            self.sendConnectionAck()
        }
    }

    private func sendConnectionAck() {
        let message = [
            "event": "connection",
            "client": "ios",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        sendMessage(message)

        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "Connected"
        }

        // Join current auction if we have one
        if let auctionId = currentAuctionId {
            joinAuction(auctionId)
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage() // Continue listening

            case .failure(let error):
                print("❌ [SocketService] WebSocket receive error: \(error)")
                self?.handleConnectionError(error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            print("📨 [SocketService] Received message: \(text.prefix(200))...")
            parseSocketMessage(text)

        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseSocketMessage(text)
            }

        @unknown default:
            print("❓ [SocketService] Unknown message type")
        }
    }

    private func parseSocketMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else {
            return
        }

        print("🎯 [SocketService] Received event: \(event)")

        switch event {
        case "bid_update":
            if let bidData = try? JSONSerialization.data(withJSONObject: json),
               let bidUpdate = try? JSONDecoder().decode(BidUpdateData.self, from: bidData) {
                bidUpdateSubject.send(bidUpdate)
            }

        case "outbid_notification":
            if let outbidData = try? JSONSerialization.data(withJSONObject: json),
               let outbidNotification = try? JSONDecoder().decode(OutbidNotificationData.self, from: outbidData) {
                outbidSubject.send(outbidNotification)
            }

        case "viewer_count_update":
            if let viewerData = try? JSONSerialization.data(withJSONObject: json),
               let viewerUpdate = try? JSONDecoder().decode(ViewerCountUpdate.self, from: viewerData) {
                viewerCountSubject.send(viewerUpdate)
            }

        case "live_frame", "video_frame":
            if let frameData = try? JSONSerialization.data(withJSONObject: json),
               let frame = try? JSONDecoder().decode(LiveFrameData.self, from: frameData) {
                print("📹 [SocketService] Received live frame: \(frame.auctionId)")
                liveFrameSubject.send(frame)
            }

        case "timer_started", "timer_ended", "timer_paused", "timer_resumed":
            if let timerData = try? JSONSerialization.data(withJSONObject: json),
               let timerEvent = try? JSONDecoder().decode(TimerEvent.self, from: timerData) {
                timerEventSubject.send(timerEvent)
            }

        case "chat_message":
            if let chatData = try? JSONSerialization.data(withJSONObject: json),
               let chatMessage = try? JSONDecoder().decode(ChatMessage.self, from: chatData) {
                chatMessageSubject.send(chatMessage)
            }

        case "auction_start":
            if let auctionData = try? JSONSerialization.data(withJSONObject: json),
               let auctionStart = try? JSONDecoder().decode(AuctionStartData.self, from: auctionData) {
                auctionStartSubject.send(auctionStart)
            }

        case "auction_end":
            if let auctionData = try? JSONSerialization.data(withJSONObject: json),
               let auctionEnd = try? JSONDecoder().decode(AuctionEndData.self, from: auctionData) {
                auctionEndSubject.send(auctionEnd)
            }

        case "bid_won":
            if let bidData = try? JSONSerialization.data(withJSONObject: json),
               let bidWon = try? JSONDecoder().decode(BidWonData.self, from: bidData) {
                bidWonSubject.send(bidWon)
            }

        case "new_item":
            if let itemData = try? JSONSerialization.data(withJSONObject: json),
               let newItem = try? JSONDecoder().decode(NewItemData.self, from: itemData) {
                newItemSubject.send(newItem)
            }

        default:
            print("❓ [SocketService] Unhandled event: \(event)")
        }
    }

    private func handleConnectionError(_ error: Error) {
        print("❌ [SocketService] Connection error: \(error)")

        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Connection Error"
            self.lastError = error.localizedDescription
        }

        // Attempt reconnection after delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
            if self.currentAuctionId != nil {
                self.connect()
            }
        }
    }

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                print("🌐 [SocketService] Network available")
                if self?.currentAuctionId != nil && self?.webSocketTask == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self?.connect()
                    }
                }
            } else {
                print("🌐 [SocketService] Network unavailable")
            }
        }

        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
}

// MARK: - Helper Extensions

extension SocketService {
    func onBidUpdate(_ handler: @escaping (BidUpdateData) -> Void) -> AnyCancellable {
        return bidUpdates.sink(receiveValue: handler)
    }

    func onOutbid(_ handler: @escaping (OutbidNotificationData) -> Void) -> AnyCancellable {
        return outbidNotifications.sink(receiveValue: handler)
    }

    func onViewerCountUpdate(_ handler: @escaping (ViewerCountUpdate) -> Void) -> AnyCancellable {
        return viewerCountUpdates.sink(receiveValue: handler)
    }

    func onLiveFrame(_ handler: @escaping (LiveFrameData) -> Void) -> AnyCancellable {
        return liveFrames.sink(receiveValue: handler)
    }

    func onTimerEvent(_ handler: @escaping (TimerEvent) -> Void) -> AnyCancellable {
        return timerEvents.sink(receiveValue: handler)
    }

    func onChatMessage(_ handler: @escaping (ChatMessage) -> Void) -> AnyCancellable {
        return chatMessages.sink(receiveValue: handler)
    }

    func onAuctionStart(_ handler: @escaping (AuctionStartData) -> Void) -> AnyCancellable {
        return auctionStarts.sink(receiveValue: handler)
    }

    func onAuctionEnd(_ handler: @escaping (AuctionEndData) -> Void) -> AnyCancellable {
        return auctionEnds.sink(receiveValue: handler)
    }

    func onBidWon(_ handler: @escaping (BidWonData) -> Void) -> AnyCancellable {
        return bidWins.sink(receiveValue: handler)
    }

    func onNewItem(_ handler: @escaping (NewItemData) -> Void) -> AnyCancellable {
        return newItems.sink(receiveValue: handler)
    }
}