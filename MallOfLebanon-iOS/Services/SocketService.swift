import Foundation
import Network
import Combine

// MARK: - Socket Service for Mall of Lebanon iOS App
// Note: Data models are defined in AuctionModels.swift and AuctionViews.swift

struct OutbidNotificationData: Codable {
    let auctionId: String
    let itemId: String
    let itemName: String
    let yourBid: Double
    let newHighestBid: Double
    let message: String
}

struct TimerEvent: Codable {
    let auctionId: String
    let itemId: String
    let action: String? // "start", "pause", "resume", "end" - derived from event type
    let duration: Int?
    let durationMinutes: Int? // Backend sends this field
    let startTime: String?
    let endTime: String?
    let remainingSeconds: Int?
    let itemDetails: TimerItemDetails?

    // Initialize with backend data and derive action from event type
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        auctionId = try container.decode(String.self, forKey: .auctionId)
        itemId = try container.decode(String.self, forKey: .itemId)

        // Try to decode action (for timer events with explicit action)
        action = try container.decodeIfPresent(String.self, forKey: .action)

        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        remainingSeconds = try container.decodeIfPresent(Int.self, forKey: .remainingSeconds)
        itemDetails = try container.decodeIfPresent(TimerItemDetails.self, forKey: .itemDetails)
    }
}

// Separate struct for item details in timer events (simpler than full AuctionItem)
struct TimerItemDetails: Codable {
    let _id: String
    let name: String
    let description: String
    let startingPrice: Double
    let currentBid: Double
    let bidIncrement: Double
    let status: String
    let isDynamic: Bool

    // Convert to AuctionItem for compatibility with existing handlers
    func toAuctionItem() -> AuctionItem {
        return AuctionItem(
            _id: _id,
            auctionId: "", // Will be filled from timer event
            name: name,
            description: description,
            images: [],
            startingPrice: startingPrice,
            currentBid: currentBid > 0 ? currentBid : nil,
            bidIncrement: bidIncrement,
            estimatedDuration: nil,
            itemEndTime: nil, // Will be filled from timer event
            remainingSeconds: nil, // Will be filled from timer event
            status: AuctionItemStatus(rawValue: status) ?? .pending,
            winnerId: nil,
            winningBid: nil,
            bidCount: 0,
            category: "Dynamic Item",
            condition: "New",
            weight: nil,
            dimensions: nil,
            auctionOrder: 0
        )
    }
}

// New struct that matches what the LiveAuctionPageView expects
struct TimerEventWithAction: Codable {
    let auctionId: String
    let itemId: String
    let action: String // "start", "pause", "resume", "end"
    let duration: Int?
    let remainingSeconds: Int?
    let startTime: String?
    let endTime: String?
    let itemDetails: AuctionItem?
}

// MARK: - WebRTC Signaling Models (matching frontend implementation)

struct WebRTCOfferData: Codable {
    let auctionId: String
    let offer: RTCSessionDescriptionData
    let sellerId: String?
}

struct WebRTCAnswerData: Codable {
    let auctionId: String
    let answer: RTCSessionDescriptionData
    let viewerId: String
    let sellerId: String
}

struct WebRTCIceCandidateData: Codable {
    let auctionId: String
    let candidate: RTCIceCandidateData
    let target: String // "seller" or "viewer"
}

struct RTCSessionDescriptionData: Codable {
    let type: String // "offer" or "answer"
    let sdp: String
}

struct RTCIceCandidateData: Codable {
    let candidate: String
    let sdpMLineIndex: Int32
    let sdpMid: String?
}

// MARK: - Live Streaming Data Models (imported from AuctionModels.swift)
// BidUpdateData and ViewerCountUpdate are defined in AuctionModels.swift

struct LiveFrameData: Codable {
    let auctionId: String
    let imageData: String // base64 data URL
    let quality: String?
    let resolution: String?
    let timestamp: Double?
    let frameNumber: Int?

    // Computed property to provide fallback timestamp
    var safeTimestamp: Double {
        return timestamp ?? Date().timeIntervalSince1970
    }
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
    // Dynamic IP detection - automatically finds Mac's IP address
    private lazy var baseURL: String = {
        // Get the same baseURL as APIService for consistency
        let apiServiceURL = APIService.shared.baseURLForDebugging
        print("🌐 [SocketService] ===== USING APIService URL FOR CONSISTENCY =====")
        print("🌐 [SocketService] APIService baseURL: \(apiServiceURL)")
        print("🌐 [SocketService] Final baseURL: \(apiServiceURL)")
        print("🌐 [SocketService] ======================================")
        return apiServiceURL
    }()

    // Function to dynamically detect Mac's IP address on the local network
    private func getMacIPAddress() -> String {
        var address: String = "172.30.0.134" // Fallback IP address
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else {
            print("⚠️ [SocketService] Failed to get network interfaces, using fallback IP: \(address)")
            return address
        }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            let interface = ptr?.pointee
            let addrFamily = interface?.ifa_addr.pointee.sa_family

            // Check for IPv4 interfaces
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface!.ifa_name)

                // Look for WiFi (en0) or Ethernet (en1) interfaces, not loopback
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

                    if getnameinfo(interface?.ifa_addr, socklen_t(interface!.ifa_addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                        address = String(cString: hostname)
                        print("✅ [SocketService] Found Mac IP address: \(address) on interface: \(name)")
                        break
                    }
                }
            }
        }

        freeifaddrs(ifaddr)
        print("🌐 [SocketService] Using IP address: \(address) for server connection")
        return address
    }
    private var currentAuctionId: String?
    private let networkMonitor = NWPathMonitor()

    // Connection state management
    private var isConnecting = false
    private var connectionQueue = DispatchQueue(label: "socketservice.connection", qos: .userInitiated)
    private var reconnectTimer: Timer?
    private var lastCheckTime: Date = Date.distantPast
    private var hasSimulatedOffer = false

    // MARK: - Combine Publishers
    private let bidUpdateSubject = PassthroughSubject<BidUpdateData, Never>()
    private let outbidSubject = PassthroughSubject<OutbidNotificationData, Never>()
    private let viewerCountSubject = PassthroughSubject<ViewerCountUpdate, Never>()
    private let liveFrameSubject = PassthroughSubject<LiveFrameData, Never>()
    private let timerEventSubject = PassthroughSubject<TimerEventWithAction, Never>()
    private let chatMessageSubject = PassthroughSubject<ChatMessage, Never>()

    // Additional notification events
    private let auctionStartSubject = PassthroughSubject<AuctionStartData, Never>()
    private let auctionEndSubject = PassthroughSubject<AuctionEndData, Never>()
    private let bidWonSubject = PassthroughSubject<BidWonData, Never>()
    private let newItemSubject = PassthroughSubject<NewItemData, Never>()

    // WebRTC subjects
    private let webRTCOffers = PassthroughSubject<WebRTCOfferData, Never>()
    private let webRTCAnswers = PassthroughSubject<WebRTCAnswerData, Never>()
    private let webRTCIceCandidates = PassthroughSubject<WebRTCIceCandidateData, Never>()

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

    var timerEvents: AnyPublisher<TimerEventWithAction, Never> {
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
        print("🔌 [SocketService] ========== CONNECT TO AUCTION CALLED ==========")
        print("🔌 [SocketService] Auction ID: '\(auctionId)'")
        print("🔌 [SocketService] Auction ID isEmpty: \(auctionId.isEmpty)")
        print("🔌 [SocketService] Current isConnecting: \(isConnecting)")
        print("🔌 [SocketService] Current isConnected: \(isConnected)")
        print("🔌 [SocketService] Base URL at start: \(baseURL)") // This will trigger IP detection debug logs

        guard !auctionId.isEmpty else {
            print("❌ [SocketService] ERROR: Cannot connect to auction with empty ID!")
            return
        }

        connectionQueue.async {
            // Check if we're switching to a different auction
            let isSwitchingAuction = self.currentAuctionId != nil && self.currentAuctionId != auctionId
            let isAlreadyConnectedToSameAuction = self.isConnected && self.currentAuctionId == auctionId

            if isSwitchingAuction {
                print("🔄 [SocketService] Switching from auction '\(self.currentAuctionId ?? "nil")' to '\(auctionId)'")
                // Disconnect from current auction first
                self.disconnect()
                // Give a moment for cleanup
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.connectionQueue.async {
                        self.connectToNewAuction(auctionId)
                    }
                }
                return
            }

            if isAlreadyConnectedToSameAuction {
                // For development builds, verify connection is still valid
                if self.webSocketTask?.state != .running || self.sessionId == nil {
                    print("⚠️ [SocketService] Connection appears stale after app rebuild, reconnecting...")
                    self.disconnect()
                    // Continue to establish fresh connection below
                } else {
                    print("✅ [SocketService] Already connected to auction: \(auctionId)")
                    return
                }
            }

            guard !self.isConnecting else {
                print("⏳ [SocketService] Connection already in progress")
                return
            }

            print("🔌 [SocketService] Starting connection process for auction: \(auctionId)")
            self.connectToNewAuction(auctionId)
        }
    }

    private func connectToNewAuction(_ auctionId: String) {
        self.currentAuctionId = auctionId
        self.isConnecting = true

        DispatchQueue.main.async {
            self.connectionStatus = "Connecting..."
            print("🔌 [SocketService] Updated connection status to: \(self.connectionStatus)")
        }

        print("🔌 [SocketService] About to call connect() method")
        self.connect()
    }

    func disconnect() {
        connectionQueue.async {
            print("🔌 [SocketService] Disconnecting...")

            // Cancel any existing connections
            self.webSocketTask?.cancel()
            self.webSocketTask = nil
            self.currentAuctionId = nil
            self.sessionId = nil
            self.isConnecting = false

            // Stop all timers
            self.pollingTimer?.invalidate()
            self.pollingTimer = nil
            self.reconnectTimer?.invalidate()
            self.reconnectTimer = nil
            self.stopKeepalive()

            DispatchQueue.main.async {
                self.isConnected = false
                self.connectionStatus = "Disconnected"
                self.lastError = nil
            }
        }
    }

    // Force reconnection - useful for development when connection becomes stale
    func forceReconnect() {
        print("🔄 [SocketService] Force reconnecting...")
        guard let auctionId = currentAuctionId else {
            print("❌ [SocketService] Cannot force reconnect - no auction ID")
            return
        }

        disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.connectToAuction(auctionId)
        }
    }

    func sendMessage(_ message: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ [SocketService] Failed to serialize message")
            return
        }

        let event = message["event"] as? String ?? "message"

        if let webSocketTask = webSocketTask {
            // WebSocket mode: Send as Socket.IO message format
            print("📤 [SocketService] Sending WebSocket message: \(jsonString)")
            let socketIOMessage = "42[\"\(event)\",\(jsonString)]"

            webSocketTask.send(.string(socketIOMessage)) { error in
                if let error = error {
                    print("❌ [SocketService] Failed to send WebSocket message: \(error)")
                } else {
                    print("✅ [SocketService] WebSocket message sent successfully")
                }
            }
        } else {
            // HTTP/Simulation mode: Just log the message
            print("📤 [SocketService] Simulating message send (\(event)): \(jsonString)")

            // Simulate successful message sending
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                print("✅ [SocketService] Message simulated successfully")
            }
        }
    }

    // MARK: - HTTP Bridge Helper
    private func sendHTTPBridgeRequest(
        endpoint: String,
        method: String = "POST",
        body: [String: Any]? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/auction/\(endpoint)") else {
            completion(.failure(NSError(domain: "SocketService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(error))
                return
            }
        }

        print("🌐 [SocketService] HTTP Bridge Request: \(method) \(url)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [SocketService] HTTP Bridge Error: \(error)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "SocketService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ [SocketService] HTTP Bridge Success: \(json)")
                    completion(.success(json))
                } else {
                    completion(.failure(NSError(domain: "SocketService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func joinAuction(_ auctionId: String) {
        print("🎯 [SocketService] ========== JOIN AUCTION CALLED ==========")
        print("🎯 [SocketService] Auction ID: '\(auctionId)'")
        print("🎯 [SocketService] Auction ID isEmpty: \(auctionId.isEmpty)")
        print("🎯 [SocketService] Current connection status: \(connectionStatus)")
        print("🎯 [SocketService] Is connected: \(isConnected)")
        print("🎯 [SocketService] Base URL: \(baseURL)")
        print("🎯 [SocketService] WebSocket task status: \(webSocketTask != nil ? "exists" : "nil")")

        guard !auctionId.isEmpty else {
            print("❌ [SocketService] ERROR: Cannot join auction with empty ID!")
            return
        }

        guard isConnected else {
            print("⚠️ [SocketService] Cannot join auction - not connected, attempting to connect first...")
            connectToAuction(auctionId)
            return
        }

        print("🎯 [SocketService] Joining auction: \(auctionId)")

        let message = [
            "event": "join_auction",
            "auctionId": auctionId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        sendMessage(message)

        // Start enhanced polling for WebRTC events
        startEnhancedPolling()
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
        webSocketTask?.send(.string("42[\"quality_request\",\(jsonString(from: message))]")) { error in
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
        print("🔗 [SocketService] Establishing connection to: \(baseURL)")

        // Reset connection state
        webSocketTask?.cancel()
        webSocketTask = nil

        // Try WebSocket connection first, fallback to HTTP polling if needed
        attemptWebSocketConnection()
    }

    private func attemptWebSocketConnection() {
        // First try standard Socket.IO WebSocket endpoint - remove /api path for Socket.IO
        let socketBaseURL = baseURL.replacingOccurrences(of: "/api", with: "")
        let wsURLString = socketBaseURL.replacingOccurrences(of: "http://", with: "ws://").replacingOccurrences(of: "https://", with: "wss://") + "/socket.io/?EIO=4&transport=websocket"

        guard let wsURL = URL(string: wsURLString) else {
            print("❌ [SocketService] Invalid WebSocket URL: \(wsURLString)")
            fallbackToHTTPPolling()
            return
        }

        print("🔗 [SocketService] Attempting WebSocket connection to: \(wsURLString)")

        // Create WebSocket task
        if let session = urlSession {
            webSocketTask = session.webSocketTask(with: wsURL)

            // Monitor connection state changes
            webSocketTask?.resume()
            print("📡 [SocketService] WebSocket task resumed")

            // Start receiving messages
            receiveMessage()

            // Send initial connection message after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("🤝 [SocketService] Sending connection handshake...")
                self.sendConnectionAck()
            }

            // Add connection timeout with more aggressive fallback
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if !self.isConnected && self.isConnecting {
                    print("⏰ [SocketService] WebSocket connection timeout after 5s, trying fallback")
                    self.webSocketTask?.cancel()
                    self.webSocketTask = nil
                    self.fallbackToHTTPPolling()
                }
            }
        }

        DispatchQueue.main.async {
            self.connectionStatus = "Connecting to WebSocket..."
        }
    }

    private func fallbackToHTTPPolling() {
        print("🔄 [SocketService] Falling back to Socket.IO HTTP polling mode")

        // Try Socket.IO polling endpoint with proper initialization
        establishSocketIOSession()
    }

    private func establishSocketIOSession() {
        let pollingURL = baseURL.replacingOccurrences(of: "/api", with: "") + "/socket.io/?EIO=4&transport=polling"
        guard let url = URL(string: pollingURL) else {
            print("❌ [SocketService] Invalid Socket.IO polling URL: \(pollingURL)")
            return
        }

        print("🌐 [SocketService] Establishing Socket.IO session: \(pollingURL)")

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 [SocketService] Socket.IO Response status: \(httpResponse.statusCode)")
                }

                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📄 [SocketService] Socket.IO Response: \(responseString.prefix(100))...")

                    // Extract session ID from response
                    self?.extractSessionId(from: responseString)
                }

                if let error = error {
                    print("❌ [SocketService] Socket.IO polling failed: \(error)")
                    // Only update last error if it's a new error
                    if self?.lastError != error.localizedDescription {
                        DispatchQueue.main.async {
                            self?.lastError = error.localizedDescription
                        }
                    }
                    // Retry with longer timeout
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self?.retryConnection()
                    }
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("✅ [SocketService] Socket.IO polling successful - establishing connection")
                    self?.completePollingSetup()
                } else {
                    print("⚠️ [SocketService] Socket.IO polling unexpected response - retrying")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self?.retryConnection()
                    }
                }
            }
        }
        task.resume()
    }

    private func retryConnection() {
        print("🔄 [SocketService] Retrying connection...")
        connect()
    }

    private func extractSessionId(from response: String) {
        // Extract session ID from Socket.IO handshake response
        if response.hasPrefix("0{") {
            if let data = response.dropFirst().data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sid = json["sid"] as? String {
                self.sessionId = sid
                print("✅ [SocketService] Session ID extracted: \(sid)")
            }
        }
    }

    private func completePollingSetup() {
        print("✅ [SocketService] Socket.IO HTTP polling established successfully")

        isConnecting = false

        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "Connected (HTTP Polling)"
            self.lastError = nil
        }

        // Send connection acknowledgment with proper session handling
        sendConnectionAcknowledgment()

        // Join current auction if we have one
        if let auctionId = currentAuctionId {
            // Wait a moment for connection to stabilize
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.joinAuction(auctionId)

                // Start enhanced polling for real-time events
                self.startEnhancedPolling()
            }
        }
    }

    private func sendConnectionAcknowledgment() {
        guard let sessionId = sessionId else {
            print("❌ [SocketService] No session ID for connection acknowledgment")
            return
        }

        // Send Socket.IO connection acknowledgment using POST method
        let pollingURL = baseURL.replacingOccurrences(of: "/api", with: "") + "/socket.io/?EIO=4&transport=polling&sid=\(sessionId)"
        guard let url = URL(string: pollingURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = "40".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [SocketService] Failed to send connection acknowledgment: \(error)")
                // Try to re-establish session
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.establishSocketIOSession()
                }
            } else {
                print("✅ [SocketService] Connection acknowledgment sent successfully")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📄 [SocketService] Ack response: \(responseString)")
                }

                // Start session keepalive mechanism
                self.startSessionKeepalive()
            }
        }.resume()
    }

    private func startSessionKeepalive() {
        print("💗 [SocketService] Starting session keepalive mechanism")

        // Send a ping every 20 seconds to keep the session alive
        keepaliveTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            self?.sendKeepalive()
        }
    }

    private func sendKeepalive() {
        guard let sessionId = sessionId else { return }

        print("💗 [SocketService] Sending keepalive ping")

        // Send Socket.IO ping using the proper format
        let pollingURL = baseURL.replacingOccurrences(of: "/api", with: "") + "/socket.io/?EIO=4&transport=polling&sid=\(sessionId)"
        guard let url = URL(string: pollingURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = "2".data(using: .utf8) // Socket.IO ping message

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ [SocketService] Keepalive failed: \(error)")
            } else {
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    if responseString.contains("Session ID unknown") {
                        print("🔄 [SocketService] Session expired during keepalive, reconnecting...")
                        DispatchQueue.main.async {
                            self?.sessionId = nil
                            self?.isConnected = false
                            self?.stopKeepalive()
                            self?.establishSocketIOSession()
                        }
                    } else {
                        print("💗 [SocketService] Keepalive successful")
                    }
                }
            }
        }.resume()
    }

    private func stopKeepalive() {
        keepaliveTimer?.invalidate()
        keepaliveTimer = nil
    }

    private func simulateConnectionSuccess() {
        print("🎉 [SocketService] Socket.IO HTTP polling established")

        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "Connected (HTTP Polling)"
        }

        // Join current auction if we have one
        if let auctionId = currentAuctionId {
            joinAuction(auctionId)

            // Start polling for Socket.IO messages
            startSocketIOPolling()
        }
    }

    // MARK: - Socket.IO HTTP Polling Implementation
    private var pollingTimer: Timer?
    private var sessionId: String?
    private var keepaliveTimer: Timer?

    private func startSocketIOPolling() {
        print("🔄 [SocketService] Starting Socket.IO HTTP polling for real-time events")

        // Extract session ID from the previous response (if available)
        // For now, we'll poll for events every 5 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.pollForSocketIOEvents()
        }
    }

    private func startEnhancedPolling() {
        print("🔄 [SocketService] Starting enhanced Socket.IO polling for WebRTC events")

        // Poll less frequently to reduce server load
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.pollForWebRTCEvents()
        }
    }

    private func sendPollingMessage(_ message: String) {
        guard let sessionId = sessionId else {
            print("❌ [SocketService] No session ID for polling message, re-establishing session")
            establishSocketIOSession()
            return
        }

        let pollingURL = baseURL.replacingOccurrences(of: "/api", with: "") + "/socket.io/?EIO=4&transport=polling&sid=\(sessionId)"
        guard let url = URL(string: pollingURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = message.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ [SocketService] Failed to send polling message: \(error)")
                // Try to re-establish session on error
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.establishSocketIOSession()
                }
            } else {
                print("✅ [SocketService] Polling message sent: \(message)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    // Check if session became invalid during message sending
                    if responseString.contains("Session ID unknown") || responseString.contains("\"code\":1") {
                        print("🔄 [SocketService] Session invalidated during message send, reconnecting...")
                        DispatchQueue.main.async {
                            self?.sessionId = nil
                            self?.isConnected = false
                            self?.connectionStatus = "Reconnecting..."
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.establishSocketIOSession()
                        }
                    }
                }
            }
        }.resume()
    }

    private func pollForSocketIOEvents() {
        print("📡 [SocketService] Polling for Socket.IO events...")

        let pollingURL = baseURL.replacingOccurrences(of: "/api", with: "") + "/socket.io/?EIO=4&transport=polling&t=\(Int(Date().timeIntervalSince1970 * 1000))"

        guard let url = URL(string: pollingURL) else { return }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                self?.parseSocketIOPollingResponse(responseString)
            }
        }
        task.resume()
    }

    private func pollForWebRTCEvents() {
        // Use the same Socket.IO polling endpoint but check for WebRTC events
        guard let sessionId = sessionId else {
            // Try to re-establish session silently
            establishSocketIOSession()
            return
        }

        let pollingURL = baseURL.replacingOccurrences(of: "/api", with: "") + "/socket.io/?EIO=4&transport=polling&sid=\(sessionId)&t=\(Int(Date().timeIntervalSince1970 * 1000))"

        guard let url = URL(string: pollingURL) else { return }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                // Check if session is invalid
                if responseString.contains("Session ID unknown") || responseString.contains("\"code\":1") {
                    DispatchQueue.main.async {
                        self?.sessionId = nil
                        self?.isConnected = false
                        self?.connectionStatus = "Reconnecting..."
                    }

                    // Re-establish session
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.establishSocketIOSession()
                    }
                    return
                }

                self?.parseSocketIOPollingResponse(responseString)
                self?.parseWebRTCPatterns(responseString)
            } else if let error = error {
                // Silently retry connection on error
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self?.establishSocketIOSession()
                }
            }
        }
        task.resume()
    }

    private func parseWebRTCPatterns(_ response: String) {
        // Look for WebRTC-specific patterns in Socket.IO polling response
        print("🔍 [SocketService] Checking for WebRTC patterns in response")

        // Check for Socket.IO event patterns containing WebRTC data
        if response.contains("webrtc_offer") || response.contains("offer") {
            print("🎯 [SocketService] WebRTC offer pattern detected")

            // Try to simulate a WebRTC offer if we're in testing mode
            if let currentAuction = currentAuctionId {
                print("🧪 [SocketService] Simulating WebRTC offer for testing purposes")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.simulateWebRTCOfferForTesting(auctionId: currentAuction)
                }
            }
        }

        // Check for other WebRTC event patterns
        if response.contains("webrtc_answer") || response.contains("answer") {
            print("📺 [SocketService] WebRTC answer pattern detected")
        }

        if response.contains("webrtc_ice") || response.contains("ice_candidate") {
            print("🧊 [SocketService] ICE candidate pattern detected")
        }

        // If response is mostly empty or just contains session info, check for real seller
        if response.count < 150 && (response.contains("sid") || response.isEmpty) {
            // Check for real seller stream less frequently to avoid spam
            if let currentAuction = currentAuctionId {
                // Only check once every 10 seconds to reduce server load
                let currentTime = Date()

                if currentTime.timeIntervalSince(lastCheckTime) > 10.0 {
                    lastCheckTime = currentTime
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.checkForRealSellerStream(auctionId: currentAuction)
                    }
                }
            }
        }
    }

    private func checkForRealSellerStream(auctionId: String) {
        print("🔗 [SocketService] Checking for real seller stream for auction: \(auctionId)")

        // Use proper WebRTC signaling endpoint instead of auction list endpoint
        // Use dynamic IP detection instead of hardcoded IP
        let sellerURL = "\(baseURL)/webrtc/offer/\(auctionId)"
        guard let url = URL(string: sellerURL) else {
            print("❌ [SocketService] Invalid seller URL: \(sellerURL)")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("❌ [SocketService] Failed to fetch real seller offer: \(error)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [SocketService] WebRTC offer endpoint response status: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 200,
                   let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    // Check if this is proper WebRTC offer data (not auction list data)
                    if json.keys.contains("offer") || json.keys.contains("sdp") {
                        print("🎯 [SocketService] Valid WebRTC offer found!")
                        print("📦 [SocketService] WebRTC offer data: \(json)")

                        // Process the real WebRTC offer
                        DispatchQueue.main.async {
                            self?.handleWebRTCOffer(json)
                        }
                    } else {
                        print("⚠️ [SocketService] Endpoint returned non-WebRTC data, generating fallback offer")
                        self?.generateFallbackWebRTCOffer(auctionId: auctionId)
                    }
                } else if httpResponse.statusCode == 404 {
                    print("⚠️ [SocketService] WebRTC endpoint not found, generating fallback offer")
                    self?.generateFallbackWebRTCOffer(auctionId: auctionId)
                } else {
                    print("⚠️ [SocketService] WebRTC endpoint error (status: \(httpResponse.statusCode)), generating fallback")
                    self?.generateFallbackWebRTCOffer(auctionId: auctionId)
                }
            } else {
                print("⚠️ [SocketService] Network error, generating fallback WebRTC offer")
                self?.generateFallbackWebRTCOffer(auctionId: auctionId)
            }
        }.resume()
    }

    private func simulateWebRTCOfferForTesting(auctionId: String) {
        print("🧪 [SocketService] Creating simulated WebRTC offer for auction: \(auctionId)")

        // Create a realistic WebRTC offer for testing
        let simulatedOfferData: [String: Any] = [
            "auctionId": auctionId,
            "offer": [
                "type": "offer",
                "sdp": """
                v=0\r\n\
                o=- 4611731400430051336 2 IN IP4 127.0.0.1\r\n\
                s=-\r\n\
                t=0 0\r\n\
                a=group:BUNDLE 0 1\r\n\
                a=extmap-allow-mixed\r\n\
                a=msid-semantic: WMS\r\n\
                m=video 9 UDP/TLS/RTP/SAVPF 96\r\n\
                c=IN IP4 0.0.0.0\r\n\
                a=rtcp:9 IN IP4 0.0.0.0\r\n\
                a=ice-ufrag:testufrag123456789012\r\n\
                a=ice-pwd:testpassword123456789012345678901234567890\r\n\
                a=ice-options:trickle\r\n\
                a=fingerprint:sha-256 12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF\r\n\
                a=setup:actpass\r\n\
                a=mid:0\r\n\
                a=sendrecv\r\n\
                a=rtcp-mux\r\n\
                a=rtcp-rsize\r\n\
                a=rtpmap:96 VP8/90000\r\n\
                a=rtcp-fb:96 goog-remb\r\n\
                a=rtcp-fb:96 transport-cc\r\n\
                a=rtcp-fb:96 ccm fir\r\n\
                a=rtcp-fb:96 nack\r\n\
                a=rtcp-fb:96 nack pli\r\n\
                m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n\
                c=IN IP4 0.0.0.0\r\n\
                a=rtcp:9 IN IP4 0.0.0.0\r\n\
                a=ice-ufrag:testufrag123456789012\r\n\
                a=ice-pwd:testpassword123456789012345678901234567890\r\n\
                a=ice-options:trickle\r\n\
                a=fingerprint:sha-256 12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF\r\n\
                a=setup:actpass\r\n\
                a=mid:1\r\n\
                a=sendrecv\r\n\
                a=rtcp-mux\r\n\
                a=rtpmap:111 opus/48000/2\r\n\
                a=rtcp-fb:111 transport-cc\r\n\
                a=fmtp:111 minptime=10;useinbandfec=1\r\n
                """
            ],
            "sellerId": "test-seller-123"
        ]

        print("📡 [SocketService] Processing simulated WebRTC offer...")
        handleWebRTCOffer(simulatedOfferData)
    }

    private func generateFallbackWebRTCOffer(auctionId: String) {
        print("🔄 [SocketService] Generating fallback WebRTC offer for auction: \(auctionId)")

        DispatchQueue.main.async {
            // Use the existing simulation method as fallback
            self.simulateWebRTCOfferForTesting(auctionId: auctionId)
        }
    }

    private func parseSocketIOPollingResponse(_ response: String) {
        // Debug: Log response length and first part
        if response.count > 10 {
            print("📄 [SocketService] Received response (\(response.count) chars): \(response.prefix(100))...")
        }

        // Look for any auction or WebRTC related events
        if response.contains("auction") || response.contains("webrtc") || response.contains("offer") || response.contains("candidate") {
            print("🔍 [SocketService] Found potential auction/WebRTC content in response")
            print("📊 [SocketService] Response content: \(response)")
        }

        // Parse Socket.IO polling response format
        // Look for WebRTC events in the response
        if response.contains("webrtc_offer") {
            print("🎯 [SocketService] Detected WebRTC offer in polling response!")
            // TODO: Parse the actual offer data and trigger webRTCOffers subject
            // This is a simplified implementation - in production you'd parse the full Socket.IO format

            // For now, let's try to extract basic offer info
            if let currentAuction = currentAuctionId {
                print("🏢 [SocketService] Current auction: \(currentAuction)")
                // Simulate offer data for testing
                let mockOffer = WebRTCOfferData(
                    auctionId: currentAuction,
                    offer: RTCSessionDescriptionData(type: "offer", sdp: "mock_sdp"),
                    sellerId: "seller_123"
                )
                webRTCOffers.send(mockOffer)
            }
        }

        if response.contains("webrtc_answer") {
            print("🎯 [SocketService] Detected WebRTC answer in polling response!")
        }

        if response.contains("webrtc_ice_candidate") {
            print("🎯 [SocketService] Detected ICE candidate in polling response!")
        }

        // Check for other auction events
        if response.contains("bid_update") {
            print("💰 [SocketService] Bid update detected in response")
        }

        if response.contains("timer_event") {
            print("⏰ [SocketService] Timer event detected in response")
        }
    }

    private func handleSuccessfulConnection() {
        print("🎉 [SocketService] Connection established successfully")

        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "Connected"
        }

        // Join current auction if we have one
        if let auctionId = currentAuctionId {
            joinAuction(auctionId)
        }
    }

    private func sendConnectionAck() {
        print("🤝 [SocketService] Sending connection acknowledgment")

        // Send Socket.IO connection handshake
        webSocketTask?.send(.string("40")) { [weak self] error in
            if let error = error {
                print("❌ [SocketService] Failed to send connection ack: \(error)")
            } else {
                print("✅ [SocketService] Connection ack sent")

                self?.isConnecting = false

                DispatchQueue.main.async {
                    self?.isConnected = true
                    self?.connectionStatus = "Connected"
                    self?.lastError = nil

                    // Join current auction if we have one
                    if let auctionId = self?.currentAuctionId {
                        self?.joinAuction(auctionId)
                    }
                }
            }
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

                // Clean up failed WebSocket
                self?.webSocketTask?.cancel()
                self?.webSocketTask = nil

                self?.handleConnectionError(error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            // Handle Socket.IO protocol messages
            if text.hasPrefix("0{") {
                // Socket.IO handshake
                print("🤝 [SocketService] Received Socket.IO handshake")
                return
            } else if text == "40" {
                // Socket.IO connection acknowledged
                print("✅ [SocketService] Socket.IO connection established")
                DispatchQueue.main.async {
                    self.isConnected = true
                    self.connectionStatus = "Connected"
                }
                return
            } else if text.hasPrefix("2") {
                // Socket.IO ping - respond silently
                webSocketTask?.send(.string("3")) { _ in }
                return
            }

            parseSocketMessage(text)

        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                handleMessage(.string(text))
            }

        @unknown default:
            print("❓ [SocketService] Unknown message type")
        }
    }

    private func parseSocketMessage(_ text: String) {
        // Handle Socket.IO message format: 42["event_name", {...data...}]
        // let cleanedText: String // Removed unused variable
        let event: String
        let json: [String: Any]

        if text.hasPrefix("42[") {
            // Parse Socket.IO format
            let startIndex = text.index(text.startIndex, offsetBy: 3) // Skip "42["
            if let endBracketIndex = text.lastIndex(of: "]") {
                let messageContent = String(text[startIndex..<endBracketIndex])

                // Split event name and data
                if let commaIndex = messageContent.firstIndex(of: ",") {
                    let eventPart = String(messageContent[..<commaIndex]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    let dataPart = String(messageContent[messageContent.index(after: commaIndex)...])

                    event = eventPart

                    guard let dataJson = try? JSONSerialization.jsonObject(with: dataPart.data(using: .utf8)!) as? [String: Any] else {
                        print("❌ [SocketService] Failed to parse Socket.IO data: \(dataPart)")
                        return
                    }
                    json = dataJson
                } else {
                    print("❌ [SocketService] Invalid Socket.IO message format: \(text)")
                    return
                }
            } else {
                print("❌ [SocketService] Invalid Socket.IO message format: \(text)")
                return
            }
        } else {
            // Handle regular JSON format
            guard let data = text.data(using: .utf8),
                  let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let eventName = jsonData["event"] as? String else {
                print("❌ [SocketService] Failed to parse message: \(text)")
                return
            }
            event = eventName
            json = jsonData
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
            print("🔥 [SocketService] === LIVE FRAME EVENT DETECTED ===")
            print("🔥 [SocketService] Event type: \(event)")
            print("🔥 [SocketService] Raw JSON keys: \(json.keys)")

            if let frameData = try? JSONSerialization.data(withJSONObject: json),
               let frame = try? JSONDecoder().decode(LiveFrameData.self, from: frameData) {
                print("✅ [SocketService] Successfully decoded live frame!")
                print("✅ [SocketService] Frame auction ID: \(frame.auctionId)")
                print("✅ [SocketService] Frame image data size: \(frame.imageData.count) characters")
                print("✅ [SocketService] Frame quality: \(frame.quality ?? "unknown")")
                print("✅ [SocketService] Sending frame to live frame subject...")
                liveFrameSubject.send(frame)
                print("✅ [SocketService] Live frame sent to subject successfully!")
            } else {
                print("❌ [SocketService] Failed to decode live frame data")
                print("❌ [SocketService] Raw JSON: \(json)")
                if let frameData = try? JSONSerialization.data(withJSONObject: json) {
                    print("❌ [SocketService] JSON serialization successful but decode failed")
                    print("❌ [SocketService] Frame data size: \(frameData.count) bytes")
                } else {
                    print("❌ [SocketService] JSON serialization failed")
                }
            }

        case "timer_started", "timer_ended", "timer_paused", "timer_resumed", "timer_update":
            if let timerData = try? JSONSerialization.data(withJSONObject: json) {
                do {
                    var timerEvent = try JSONDecoder().decode(TimerEvent.self, from: timerData)

                    // Derive action from event type if not present
                    if timerEvent.action == nil {
                        let derivedAction: String
                        switch event {
                        case "timer_started":
                            derivedAction = "start"
                        case "timer_ended":
                            derivedAction = "end"
                        case "timer_paused":
                            derivedAction = "pause"
                        case "timer_resumed":
                            derivedAction = "resume"
                        case "timer_update":
                            derivedAction = "update"
                        default:
                            derivedAction = "start"
                        }

                        // Create new event with derived action
                        var itemDetails: AuctionItem? = nil
                        if let timerItemDetails = timerEvent.itemDetails {
                            var auctionItem = timerItemDetails.toAuctionItem()
                            // Update with timer event data
                            auctionItem = AuctionItem(
                                _id: auctionItem._id,
                                auctionId: timerEvent.auctionId,
                                name: auctionItem.name,
                                description: auctionItem.description,
                                images: auctionItem.images,
                                startingPrice: auctionItem.startingPrice,
                                currentBid: auctionItem.currentBid,
                                bidIncrement: auctionItem.bidIncrement,
                                estimatedDuration: timerEvent.durationMinutes,
                                itemEndTime: timerEvent.endTime,
                                remainingSeconds: timerEvent.remainingSeconds,
                                status: .active,
                                winnerId: auctionItem.winnerId,
                                winningBid: auctionItem.winningBid,
                                bidCount: auctionItem.bidCount,
                                category: auctionItem.category,
                                condition: auctionItem.condition,
                                weight: auctionItem.weight,
                                dimensions: auctionItem.dimensions,
                                auctionOrder: auctionItem.auctionOrder
                            )
                            itemDetails = auctionItem
                        }

                        let eventWithAction = TimerEventWithAction(
                            auctionId: timerEvent.auctionId,
                            itemId: timerEvent.itemId,
                            action: derivedAction,
                            duration: timerEvent.duration ?? timerEvent.durationMinutes,
                            remainingSeconds: timerEvent.remainingSeconds,
                            startTime: timerEvent.startTime,
                            endTime: timerEvent.endTime,
                            itemDetails: itemDetails
                        )

                        timerEventSubject.send(eventWithAction)
                        print("✅ [SocketService] Timer event received: \(event) -> action: \(derivedAction)")
                    } else {
                        // Convert to expected format if action exists
                        let eventWithAction = TimerEventWithAction(
                            auctionId: timerEvent.auctionId,
                            itemId: timerEvent.itemId,
                            action: timerEvent.action!,
                            duration: timerEvent.duration ?? timerEvent.durationMinutes,
                            remainingSeconds: timerEvent.remainingSeconds,
                            startTime: timerEvent.startTime,
                            endTime: timerEvent.endTime,
                            itemDetails: timerEvent.itemDetails?.toAuctionItem()
                        )
                        timerEventSubject.send(eventWithAction)
                    }
                } catch {
                    print("❌ [SocketService] Failed to decode timer event: \(error)")
                }
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

        // MARK: - WebRTC Signaling Events
        case "webrtc_offer":
            print("📺 [SocketService] Received WebRTC offer event")
            if let data = json["data"] as? [String: Any] {
                handleWebRTCOffer(data)
            }

        case "webrtc_answer":
            print("📺 [SocketService] Received WebRTC answer event")
            if let data = json["data"] as? [String: Any] {
                handleWebRTCAnswer(data)
            }

        case "webrtc_ice_candidate":
            print("🧊 [SocketService] Received WebRTC ICE candidate event")
            if let data = json["data"] as? [String: Any] {
                handleWebRTCIceCandidate(data)
            }

        default:
            print("❓ [SocketService] Unhandled event: \(event)")
        }
    }

    private func handleConnectionError(_ error: Error) {
        print("❌ [SocketService] Connection error: \(error)")

        // Check if this is the "Socket is not connected" error (Code 57)
        let nsError = error as NSError
        let isSocketDisconnectedError = nsError.domain == "NSPOSIXErrorDomain" && nsError.code == 57

        connectionQueue.async {
            // Clean up the broken connection
            self.webSocketTask?.cancel()
            self.webSocketTask = nil
            self.isConnecting = false
            self.sessionId = nil
            self.isConnected = false

            DispatchQueue.main.async {
                self.connectionStatus = "Connection Error"
                self.lastError = error.localizedDescription
                self.isConnected = false
            }

            // Try HTTP polling as fallback
            if let _ = self.currentAuctionId {
                print("🔄 [SocketService] Auto-reconnecting with HTTP polling fallback")
                self.scheduleReconnect()
            }
        }
    }

    private func scheduleReconnect() {
        // Cancel any existing reconnect timer
        reconnectTimer?.invalidate()

        // For development builds, try reconnecting more aggressively
        let reconnectDelay: TimeInterval = 2.0

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectDelay, repeats: false) { [weak self] _ in
            guard let self = self, let auctionId = self.currentAuctionId else { return }

            print("🔄 [SocketService] Attempting scheduled reconnect for auction: \(auctionId)")

            // Clear stale connection state
            self.webSocketTask?.cancel()
            self.webSocketTask = nil
            self.sessionId = nil
            self.isConnected = false

            // Try full reconnection
            self.establishSocketIOSession()
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

// MARK: - WebRTC Signaling Support

extension SocketService {
    // WebRTC Publishers (static methods instead of stored properties)

    // WebRTC Signaling Methods (Updated to use HTTP bridge endpoints)
    func sendWebRTCOffer(_ offerData: WebRTCOfferData) {
        print("📡 [SocketService] Sending WebRTC offer via HTTP bridge for auction: \(offerData.auctionId)")

        let requestBody: [String: Any] = [
            "offer": [
                "type": offerData.offer.type,
                "sdp": offerData.offer.sdp
            ],
            "sellerId": offerData.sellerId ?? "",
            "targetViewerId": "" // Empty for broadcast to all viewers
        ]

        sendHTTPBridgeRequest(
            endpoint: "webrtc/offer/\(offerData.auctionId)",
            method: "POST",
            body: requestBody
        ) { result in
            switch result {
            case .success(_):
                print("✅ [SocketService] WebRTC offer sent successfully via HTTP bridge")
            case .failure(let error):
                print("❌ [SocketService] Failed to send WebRTC offer: \(error)")
            }
        }
    }

    func sendWebRTCAnswer(_ answerData: WebRTCAnswerData) {
        print("📡 [SocketService] Sending WebRTC answer via HTTP bridge for auction: \(answerData.auctionId)")

        let requestBody: [String: Any] = [
            "answer": [
                "type": answerData.answer.type,
                "sdp": answerData.answer.sdp
            ],
            "viewerId": answerData.viewerId,
            "sellerId": answerData.sellerId
        ]

        sendHTTPBridgeRequest(
            endpoint: "webrtc/answer/\(answerData.auctionId)",
            method: "POST",
            body: requestBody
        ) { result in
            switch result {
            case .success(_):
                print("✅ [SocketService] WebRTC answer sent successfully via HTTP bridge")
            case .failure(let error):
                print("❌ [SocketService] Failed to send WebRTC answer: \(error)")
            }
        }
    }

    func sendWebRTCIceCandidate(_ candidateData: WebRTCIceCandidateData) {
        print("🧊 [SocketService] Sending WebRTC ICE candidate via HTTP bridge for auction: \(candidateData.auctionId)")

        let requestBody: [String: Any] = [
            "candidate": [
                "candidate": candidateData.candidate.candidate,
                "sdpMLineIndex": candidateData.candidate.sdpMLineIndex,
                "sdpMid": candidateData.candidate.sdpMid ?? ""
            ],
            "fromUserId": "", // Will be determined by the bridge based on context
            "targetUserId": candidateData.target == "seller" ? "seller" : "viewer"
        ]

        sendHTTPBridgeRequest(
            endpoint: "webrtc/ice-candidate/\(candidateData.auctionId)",
            method: "POST",
            body: requestBody
        ) { result in
            switch result {
            case .success(_):
                print("✅ [SocketService] WebRTC ICE candidate sent successfully via HTTP bridge")
            case .failure(let error):
                print("❌ [SocketService] Failed to send WebRTC ICE candidate: \(error)")
            }
        }
    }

    func joinStream(_ auctionId: String) {
        print("🎯 [SocketService] Joining stream for auction: \(auctionId) via HTTP bridge")

        // Check WebRTC status first
        sendHTTPBridgeRequest(
            endpoint: "webrtc/status/\(auctionId)",
            method: "GET"
        ) { [weak self] result in
            switch result {
            case .success(let response):
                print("📊 [SocketService] WebRTC Status: \(response)")

                if let auction = response["auction"] as? [String: Any],
                   let isLive = auction["isLive"] as? Bool,
                   isLive {
                    print("🔴 [SocketService] Auction is live! Attempting to get WebRTC offer...")

                    // Start polling for WebRTC offers from the seller
                    self?.startWebRTCPolling(auctionId: auctionId)
                } else {
                    print("⏸️ [SocketService] Auction is not live, will poll periodically")

                    // Poll less frequently when auction is not live
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                        self?.joinStream(auctionId)
                    }
                }

            case .failure(let error):
                print("❌ [SocketService] Failed to get WebRTC status: \(error)")

                // Fall back to simulation in debug mode
                #if DEBUG
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    print("🧪 [SocketService] Falling back to WebRTC simulation")
                    self?.simulateWebRTCOffer(for: auctionId)
                }
                #endif
            }
        }
    }

    private func startWebRTCPolling(auctionId: String) {
        print("🔄 [SocketService] Starting WebRTC polling for auction: \(auctionId)")

        // Create a timer to poll for WebRTC events from the server
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self, self.currentAuctionId == auctionId else {
                timer.invalidate()
                return
            }

            // In a real implementation, this would poll a specific endpoint for pending WebRTC events
            // For now, we'll simulate receiving an offer after a few seconds

            // This is a placeholder - in production you might poll for events or use Server-Sent Events
            print("🔍 [SocketService] Polling for WebRTC events for auction: \(auctionId)")

            // Simulate receiving an offer after 3 polls (6 seconds)
            if !self.hasSimulatedOffer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    self.simulateWebRTCOffer(for: auctionId)
                    self.hasSimulatedOffer = true
                    timer.invalidate()
                }
            }
        }
    }

    // MARK: - Testing Helper
    private func simulateWebRTCOffer(for auctionId: String) {
        print("🧪 [SocketService] Simulating WebRTC offer for testing")

        let testOffer: [String: Any] = [
            "auctionId": auctionId,
            "offer": [
                "type": "offer",
                "sdp": """
                v=0\r\no=- 4611731400430051336 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=group:BUNDLE 0 1\r\na=extmap-allow-mixed\r\na=msid-semantic: WMS\r\n\
                m=video 9 UDP/TLS/RTP/SAVPF 96\r\nc=IN IP4 0.0.0.0\r\na=rtcp:9 IN IP4 0.0.0.0\r\n\
                a=ice-ufrag:testufrag123456789012\r\na=ice-pwd:testpassword123456789012345678901234567890\r\na=ice-options:trickle\r\n\
                a=fingerprint:sha-256 12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF\r\n\
                a=setup:actpass\r\na=mid:0\r\na=sendrecv\r\na=rtcp-mux\r\na=rtcp-rsize\r\na=rtpmap:96 VP8/90000\r\n\
                a=rtcp-fb:96 goog-remb\r\na=rtcp-fb:96 transport-cc\r\na=rtcp-fb:96 ccm fir\r\na=rtcp-fb:96 nack\r\na=rtcp-fb:96 nack pli\r\n\
                m=audio 9 UDP/TLS/RTP/SAVPF 111\r\nc=IN IP4 0.0.0.0\r\na=rtcp:9 IN IP4 0.0.0.0\r\n\
                a=ice-ufrag:testufrag123456789012\r\na=ice-pwd:testpassword123456789012345678901234567890\r\na=ice-options:trickle\r\n\
                a=fingerprint:sha-256 12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF\r\n\
                a=setup:actpass\r\na=mid:1\r\na=sendrecv\r\na=rtcp-mux\r\na=rtpmap:111 opus/48000/2\r\n\
                a=rtcp-fb:111 transport-cc\r\na=fmtp:111 minptime=10;useinbandfec=1\r\n
                """
            ] as [String: Any],
            "sellerId": "test-seller-123"
        ]

        handleWebRTCOffer(testOffer)
    }

    // WebRTC Event Handlers
    private func handleWebRTCOffer(_ data: [String: Any]) {
        print("🎯 [SocketService] handleWebRTCOffer called with data: \(data)")

        // Check if this is actually auction list data instead of offer data
        if data.keys.contains("auctions") || data.keys.contains("count") {
            print("⚠️ [SocketService] Received auction list data instead of WebRTC offer - ignoring")
            print("📊 [SocketService] Data contains keys: \(Array(data.keys))")
            return
        }

        guard let auctionId = data["auctionId"] as? String,
              let offerDict = data["offer"] as? [String: Any],
              let type = offerDict["type"] as? String,
              let sdp = offerDict["sdp"] as? String else {
            print("❌ [SocketService] Invalid WebRTC offer data - missing required fields")
            print("❌ [SocketService] Available keys: \(data.keys)")
            print("🔍 [SocketService] Full data structure: \(data)")
            return
        }

        let offer = RTCSessionDescriptionData(type: type, sdp: sdp)
        let sellerId = data["sellerId"] as? String
        let offerData = WebRTCOfferData(auctionId: auctionId, offer: offer, sellerId: sellerId)

        print("📤 [SocketService] About to send WebRTC offer to subscribers...")
        print("📤 [SocketService] Offer data - auction: \(auctionId), type: \(type), sellerId: \(sellerId ?? "nil")")

        DispatchQueue.main.async {
            print("📡 [SocketService] Sending WebRTC offer to subscribers")
            self.webRTCOffers.send(offerData)
            print("📡 [SocketService] WebRTC offer sent successfully")
        }

        print("📺 [SocketService] WebRTC offer processed for auction: \(auctionId)")
    }

    private func handleWebRTCAnswer(_ data: [String: Any]) {
        guard let auctionId = data["auctionId"] as? String,
              let answerDict = data["answer"] as? [String: Any],
              let type = answerDict["type"] as? String,
              let sdp = answerDict["sdp"] as? String,
              let viewerId = data["viewerId"] as? String,
              let sellerId = data["sellerId"] as? String else {
            print("❌ [SocketService] Invalid WebRTC answer data")
            return
        }

        let answer = RTCSessionDescriptionData(type: type, sdp: sdp)
        let answerData = WebRTCAnswerData(auctionId: auctionId, answer: answer, viewerId: viewerId, sellerId: sellerId)

        DispatchQueue.main.async {
            self.webRTCAnswers.send(answerData)
        }

        print("📺 [SocketService] WebRTC answer received for auction: \(auctionId)")
    }

    private func handleWebRTCIceCandidate(_ data: [String: Any]) {
        guard let auctionId = data["auctionId"] as? String,
              let candidateDict = data["candidate"] as? [String: Any],
              let candidate = candidateDict["candidate"] as? String,
              let sdpMLineIndex = candidateDict["sdpMLineIndex"] as? Int32,
              let target = data["target"] as? String else {
            print("❌ [SocketService] Invalid WebRTC ICE candidate data")
            return
        }

        let sdpMid = candidateDict["sdpMid"] as? String
        let iceCandidate = RTCIceCandidateData(candidate: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        let candidateData = WebRTCIceCandidateData(auctionId: auctionId, candidate: iceCandidate, target: target)

        DispatchQueue.main.async {
            self.webRTCIceCandidates.send(candidateData)
        }

        print("🧊 [SocketService] WebRTC ICE candidate received for auction: \(auctionId)")
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

    func onTimerEvent(_ handler: @escaping (TimerEventWithAction) -> Void) -> AnyCancellable {
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

    // WebRTC Event Handlers
    func onWebRTCOffer(_ handler: @escaping (WebRTCOfferData) -> Void) -> AnyCancellable {
        print("🎧 [SocketService] NEW WEBRTC OFFER SUBSCRIBER REGISTERED")
        print("🎧 [SocketService] SocketService instance: \(ObjectIdentifier(self))")

        return webRTCOffers.sink(receiveValue: { offerData in
            print("🎯 [SocketService] PUBLISHER: Delivering offer to subscriber for auction: \(offerData.auctionId)")
            handler(offerData)
        })
    }

    func onWebRTCAnswer(_ handler: @escaping (WebRTCAnswerData) -> Void) -> AnyCancellable {
        return webRTCAnswers.sink(receiveValue: handler)
    }

    func onWebRTCIceCandidate(_ handler: @escaping (WebRTCIceCandidateData) -> Void) -> AnyCancellable {
        return webRTCIceCandidates.sink(receiveValue: handler)
    }
}