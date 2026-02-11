import SwiftUI
import Combine

// MARK: - WebRTC Live Stream View for iOS Auctions

struct WebRTCLiveStreamView: View {
    let auctionId: String
    let auctionTitle: String

    @State private var isJoined = false
    @State private var isSellerMode = false
    @State private var connectionStatus = "Ready to connect"
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var cancellables = Set<AnyCancellable>()
    @StateObject private var webRTCService = WebRTCService.shared
    @StateObject private var socketService = SocketService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Full-screen video background
            WebRTCVideoView(
                auctionId: auctionId,
                isSellerMode: isSellerMode,
                isJoined: $isJoined,
                onJoin: joinAuction
            )
            .ignoresSafeArea(.all)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)

            // Floating overlay controls (only show when needed)
            if !isJoined {
                // Join overlay (center)
                joinOverlayView
                    .transition(.opacity)
            } else {
                // All overlays removed - clean interface
                EmptyView()
            }
        }
        .background(Color.black)
        .ignoresSafeArea(.all)
        .clipped()
        .onAppear {
            print("🚀 [WebRTCLiveStreamView] Starting for auction: '\(auctionId)'")
            print("🚀 [WebRTCLiveStreamView] Auction ID length: \(auctionId.count)")
            print("🚀 [WebRTCLiveStreamView] Auction ID isEmpty: \(auctionId.isEmpty)")

            if auctionId.isEmpty {
                print("❌ [WebRTCLiveStreamView] CRITICAL: Auction ID is empty!")
            } else {
                print("✅ [WebRTCLiveStreamView] Auction ID is valid")
            }

            setupConnections()
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Overlay Views

    private var joinOverlayView: some View {
        VStack(spacing: 24) {
            // Dimmed background
            Rectangle()
                .fill(Color.black.opacity(0.7))
                .ignoresSafeArea(.all)

            VStack(spacing: 20) {
                // Live stream indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                    Text("LIVE")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                // Auction title
                Text(auctionTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Join prompt
                VStack(spacing: 12) {
                    Image(systemName: "video.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)

                    Text("Tap to join live auction")
                        .font(.headline)
                        .foregroundColor(.white)

                    // Mode selector
                    Picker("Mode", selection: $isSellerMode) {
                        Text("Viewer").tag(false)
                        Text("Seller").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 200)
                    .disabled(isJoined)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.8))
                    .blur(radius: 20)
            )
            .padding()
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                joinAuction()
            }
        }
    }

    private var connectionStatusOverlay: some View {
        HStack(spacing: 12) {
            // Connection indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(connectionStatusColor)
                    .frame(width: 8, height: 8)

                Text(connectionStatus)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }

            Spacer()

            // Live indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("LIVE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .blur(radius: 8)
        )
        .padding(.horizontal)
    }

    // MARK: - Setup Functions

    private func setupConnections() {
        print("🎬 [WebRTCLiveStreamView] Setting up connections for auction: \(auctionId)")
        setupConnectionMonitoring()
    }

    // MARK: - Computed Properties

    private var connectionStatusColor: Color {
        if webRTCService.isConnected {
            return .green
        } else if socketService.isConnected {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Actions

    private func setupConnectionMonitoring() {
        print("📡 [WebRTCLiveStreamView] Setting up connection monitoring")

        // Monitor socket connection status
        socketService.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { status in
                if !isJoined {
                    connectionStatus = status
                }
            }
            .store(in: &cancellables)

        // Monitor WebRTC connection state
        webRTCService.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { state in
                if isJoined {
                    switch state {
                    case .new:
                        connectionStatus = "Initializing WebRTC..."
                    case .connecting:
                        connectionStatus = "Establishing peer connection..."
                    case .connected:
                        connectionStatus = "Connected and streaming"
                    case .failed:
                        connectionStatus = "Connection failed"
                        showError("WebRTC connection failed. Please try again or check your network connection.")
                    case .disconnected:
                        connectionStatus = "Connection lost"
                    case .closed:
                        connectionStatus = "Connection closed"
                    @unknown default:
                        connectionStatus = "Unknown state"
                    }
                }
            }
            .store(in: &cancellables)

        // Monitor socket errors with debouncing
        socketService.$lastError
            .compactMap { $0 }
            .removeDuplicates()
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { error in
                // Only show error if we're not already retrying
                if !self.showingError || !self.errorMessage.contains(error) {
                    self.showError("Socket connection error: \(error)")
                }
            }
            .store(in: &cancellables)
    }

    private func joinAuction() {
        print("🎯 [WebRTCLiveStreamView] ========== JOIN AUCTION TRIGGERED ==========")
        print("🎯 [WebRTCLiveStreamView] Joining auction as \(isSellerMode ? "seller" : "viewer")")
        print("🎯 [WebRTCLiveStreamView] Auction ID: \(auctionId)")
        print("🎯 [WebRTCLiveStreamView] Current isJoined: \(isJoined)")

        // Ensure clean state transition by first setting to false if already true
        if isJoined {
            print("🎯 [WebRTCLiveStreamView] Resetting isJoined state for clean transition")
            isJoined = false

            // Small delay to ensure the state change is processed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.performJoin()
            }
        } else {
            performJoin()
        }
    }

    private func performJoin() {
        print("🎯 [WebRTCLiveStreamView] Performing join with clean state")
        print("🎯 [WebRTCLiveStreamView] Using auction ID: '\(auctionId)'")
        print("🎯 [WebRTCLiveStreamView] Auction ID isEmpty check: \(auctionId.isEmpty)")

        withAnimation {
            isJoined = true
            connectionStatus = "Connecting to auction..."
        }

        print("🎯 [WebRTCLiveStreamView] isJoined set to: \(isJoined)")

        // EMERGENCY FIX: Directly start WebRTC service to ensure it starts
        print("🚨 [WebRTCLiveStreamView] EMERGENCY: Directly starting WebRTC service...")
        print("🚨 [WebRTCLiveStreamView] About to call startWebRTC with auctionId: '\(auctionId)'")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("🚨 [WebRTCLiveStreamView] Calling WebRTC service directly...")
            print("🚨 [WebRTCLiveStreamView] Final auction ID check before service call: '\(self.auctionId)'")

            // DYNAMIC FIX: Fetch live auctions if original ID is empty
            if self.auctionId.isEmpty {
                print("🚨 [WebRTCLiveStreamView] Empty auction ID, fetching live auctions...")
                self.fetchAndConnectToLiveAuction()
            } else {
                print("🚨 [WebRTCLiveStreamView] Using provided auction ID: '\(self.auctionId)'")
                print("🚨 [WebRTCLiveStreamView] About to call WebRTCService.shared.startWebRTC")
                print("🚨 [WebRTCLiveStreamView] Current thread: \(Thread.current)")
                print("🚨 [WebRTCLiveStreamView] isSellerMode: \(self.isSellerMode)")
                WebRTCService.shared.startWebRTC(auctionId: self.auctionId, isSellerMode: self.isSellerMode)
                print("🚨 [WebRTCLiveStreamView] WebRTC service call completed")
            }
        }

        print("🎯 [WebRTCLiveStreamView] ========== JOIN AUCTION COMPLETE ==========")
    }

    private func leaveAuction() {
        print("🚪 [WebRTCLiveStreamView] Leaving auction")

        withAnimation {
            isJoined = false
            connectionStatus = "Disconnected"
        }

        // Cleanup WebRTC connection
        WebRTCService.shared.stopWebRTC()
    }

    private func retryConnection() {
        print("🔄 [WebRTCLiveStreamView] Retrying connection")
        print("🔄 [WebRTCLiveStreamView] Current state - isJoined: \(isJoined), WebRTC connected: \(webRTCService.isConnected)")

        // Reset error state
        showingError = false
        errorMessage = ""
        connectionStatus = "Retrying connection..."

        // Only stop WebRTC if we're actually joined and it's been running for a while
        if isJoined {
            print("🔄 [WebRTCLiveStreamView] Stopping current WebRTC connection for retry")
            WebRTCService.shared.stopWebRTC()

            // Wait a moment before restarting
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("🔄 [WebRTCLiveStreamView] Attempting to restart WebRTC after retry")
                self.connectionStatus = "Reconnecting..."

                // Trigger the join flow again to restart WebRTC
                self.joinAuction()
            }
        } else {
            print("🔄 [WebRTCLiveStreamView] Not joined yet, skipping retry")
            connectionStatus = "Ready to connect"
        }
    }

    private func showError(_ message: String) {
        // Prevent duplicate error messages
        if showingError && errorMessage == message {
            print("⚠️ [WebRTCLiveStreamView] Duplicate error prevented: \(message)")
            return
        }

        errorMessage = message
        print("❌ [WebRTCLiveStreamView] Error: \(message) - Auto-retrying in background...")

        // Update connection status to show retry in progress
        connectionStatus = "Connection failed, retrying..."

        // Automatically retry in background after a short delay (3 seconds for faster response)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("🔄 [WebRTCLiveStreamView] Auto-retry triggered for error: \(message)")
            self.retryConnection()
        }
    }

    private func fetchAndConnectToLiveAuction() {
        print("📡 [WebRTCLiveStreamView] Fetching live auctions dynamically...")

        // Check for live auctions on localhost:3005
        guard let url = URL(string: "http://localhost:3005/api/auctions") else {
            print("❌ [WebRTCLiveStreamView] Invalid auction API URL")
            // Fallback to test auction
            connectToFallbackAuction()
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in

            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [WebRTCLiveStreamView] Error fetching auctions: \(error.localizedDescription)")
                    connectToFallbackAuction()
                    return
                }

                guard let data = data else {
                    print("❌ [WebRTCLiveStreamView] No data received from auction API")
                    connectToFallbackAuction()
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let auctions = json["auctions"] as? [[String: Any]] {

                        print("🎯 [WebRTCLiveStreamView] Found \(auctions.count) auctions from API")

                        // Sort auctions to prioritize those most likely to have active streams
                        let sortedAuctions = auctions.sorted { auction1, auction2 in
                            let viewers1 = auction1["currentViewers"] as? Int ?? 0
                            let viewers2 = auction2["currentViewers"] as? Int ?? 0
                            let startTime1 = auction1["actualStartTime"] as? String ?? ""
                            let startTime2 = auction2["actualStartTime"] as? String ?? ""

                            // Prioritize auctions with more viewers or more recent start times
                            if viewers1 != viewers2 {
                                return viewers1 > viewers2
                            }
                            return startTime1 > startTime2
                        }

                        // Find the best live auction
                        for auction in sortedAuctions {
                            if let status = auction["status"] as? String,
                               let auctionId = auction["_id"] as? String,
                               let title = auction["title"] as? String,
                               status == "live" {

                                let viewers = auction["currentViewers"] as? Int ?? 0
                                let startTime = auction["actualStartTime"] as? String ?? "unknown"
                                print("✅ [WebRTCLiveStreamView] Using live auction: '\(title)' (ID: \(auctionId))")
                                print("✅ [WebRTCLiveStreamView] Auction details - Viewers: \(viewers), Start: \(startTime)")
                                print("✅ [WebRTCLiveStreamView] About to call WebRTCService.shared.startWebRTC")
                                print("✅ [WebRTCLiveStreamView] Current thread: \(Thread.current)")
                                print("✅ [WebRTCLiveStreamView] isSellerMode: \(isSellerMode)")
                                WebRTCService.shared.startWebRTC(auctionId: auctionId, isSellerMode: isSellerMode)
                                print("✅ [WebRTCLiveStreamView] WebRTC service call completed")
                                return
                            }
                        }

                        // No live auctions found
                        print("⚠️ [WebRTCLiveStreamView] No live auctions found, using fallback")
                        connectToFallbackAuction()
                    } else {
                        print("❌ [WebRTCLiveStreamView] Invalid JSON response format")
                        connectToFallbackAuction()
                    }

                } catch {
                    print("❌ [WebRTCLiveStreamView] JSON parsing error: \(error.localizedDescription)")
                    connectToFallbackAuction()
                }
            }
        }.resume()
    }

    private func connectToFallbackAuction() {
        let fallbackId = "698a15910410e12793db7cf2" // "we are opening auction"
        print("🔄 [WebRTCLiveStreamView] Using fallback auction ID: \(fallbackId)")
        print("🔄 [WebRTCLiveStreamView] About to call WebRTCService.shared.startWebRTC")
        print("🔄 [WebRTCLiveStreamView] Current thread: \(Thread.current)")
        print("🔄 [WebRTCLiveStreamView] isSellerMode: \(isSellerMode)")

        // Ensure this runs on main thread
        DispatchQueue.main.async {
            print("🔄 [WebRTCLiveStreamView] On main thread, calling WebRTC service...")
            WebRTCService.shared.startWebRTC(auctionId: fallbackId, isSellerMode: self.isSellerMode)
            print("🔄 [WebRTCLiveStreamView] WebRTC service call completed")
        }
    }

    private func cleanup() {
        print("🧹 [WebRTCLiveStreamView] Cleaning up")

        // Stop WebRTC service
        WebRTCService.shared.stopWebRTC()

        // Cancel any active publishers
        cancellables.removeAll()

        // Reset state
        isJoined = false
        connectionStatus = "Ready to connect"
    }
}

// MARK: - Preview

struct WebRTCLiveStreamView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WebRTCLiveStreamView(
                auctionId: "test-auction-id",
                auctionTitle: "Test Auction - Luxury Items"
            )
        }
        .previewDisplayName("WebRTC Live Stream")
    }
}