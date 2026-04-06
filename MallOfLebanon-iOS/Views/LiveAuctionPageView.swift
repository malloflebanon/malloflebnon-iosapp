import SwiftUI
import Combine

// MARK: - Live Auction Page
// Full-screen live stream experience with floating overlays for items, chat, and bidding
// Optimized for immersive auction viewing

struct LiveAuctionPageView: View {
    let auctionId: String

    @StateObject private var auctionService = AuctionService.shared
    @StateObject private var socketService = SocketService.shared
    @Environment(\.presentationMode) var presentationMode

    // Data State
    @State private var auction: LiveAuction?
    @State private var items: [AuctionItem] = []
    @State private var currentItem: AuctionItem?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()

    // UI State - Overlays (items and chat removed)
    @State private var showingBiddingSheet = false
    @State private var showingItemDetails = false
    @State private var selectedDetailItem: AuctionItem?
    @State private var showingControls = true
    @State private var isMinimized = false

    // Right-side control sheet states
    @State private var showingMoreSheet = false
    @State private var showingShareSheet = false
    @State private var showingWalletSheet = false

    // Real-time Updates
    @State private var viewerCount = 0
    @State private var connectionStatus = "Connecting..."
    @State private var refreshTimer: Timer?

    // Wallet and Bidding State
    @State private var walletBalance: Double = 0.0
    @State private var walletCurrency: String = "USD"
    @State private var isLoadingWallet = false
    @State private var isBidding = false
    @State private var bidAmount: Double = 0.0
    @State private var showBidConfirmation = false
    @State private var bidButtonScale: CGFloat = 1.0

    // Computed property to always show an item (current or most recent)
    private var displayItem: AuctionItem? {
        // First priority: current active item
        if let current = currentItem {
            return current
        }

        // Second priority: most recently ended item (sold or unsold)
        return items.filter { $0.status == .sold || $0.status == .unsold }
                   .sorted { first, second in
                       // Sort by auction order descending to get most recent
                       (first.auctionOrder ?? 0) > (second.auctionOrder ?? 0)
                   }
                   .first
    }

    // MARK: - Wallet and Bidding Functions

    private func loadWalletBalance() {
        isLoadingWallet = true
        auctionService.getAuctionWallet()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isLoadingWallet = false
                    if case .failure(let error) = completion {
                        print("❌ [LiveAuctionPageView] Failed to load wallet: \(error)")
                    }
                },
                receiveValue: { wallet in
                    self.walletBalance = wallet.availableBalance
                    self.walletCurrency = wallet.currency
                    print("💰 [LiveAuctionPageView] Wallet loaded: \(wallet.availableBalance) \(wallet.currency)")
                }
            )
            .store(in: &cancellables)
    }

    private func attemptBid(on item: AuctionItem) {
        guard let auction = auction else { return }

        let nextBidAmount = item.nextMinimumBid
        bidAmount = nextBidAmount

        // Animation for bid button
        withAnimation(.easeInOut(duration: 0.1)) {
            bidButtonScale = 1.2
        }

        withAnimation(.easeInOut(duration: 0.1).delay(0.1)) {
            bidButtonScale = 1.0
        }

        // Check wallet balance first
        if walletBalance < nextBidAmount {
            print("❌ [LiveAuctionPageView] Insufficient wallet balance. Required: \(nextBidAmount), Available: \(walletBalance)")
            showBidConfirmation = true
            return
        }

        // Proceed with bid
        isBidding = true

        auctionService.placeBid(
            auctionId: auction._id,
            itemId: item._id,
            amount: nextBidAmount
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                self.isBidding = false
                if case .failure(let error) = completion {
                    print("❌ [LiveAuctionPageView] Bid failed: \(error)")
                }
            },
            receiveValue: { bidResponse in
                print("✅ [LiveAuctionPageView] Bid placed successfully: \(bidResponse.newBidAmount) \(bidResponse.currency)")
                // Reload wallet balance after successful bid
                self.loadWalletBalance()
            }
        )
        .store(in: &cancellables)
    }

    var body: some View {
        ZStack {
            // Full-screen background - white/system background
            Color(.systemBackground)
                .ignoresSafeArea(.all)
                .edgesIgnoringSafeArea(.all)

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let auction = auction {
                fullScreenAuctionView(auction)
            }
        }
        .ignoresSafeArea(.all)
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            loadAuctionData()
            setupRealTimeUpdates()
            loadWalletBalance()
            startPeriodicRefresh()
        }
        .onDisappear {
            cleanup()
            stopPeriodicRefresh()
        }
        .sheet(isPresented: $showingBiddingSheet) {
            if let auction = auction, let item = currentItem {
                EnhancedBiddingView(auction: auction, item: item)
            }
        }
        .sheet(isPresented: $showingItemDetails) {
            if let item = selectedDetailItem {
                ItemDetailSheet(item: item)
            }
        }
        .sheet(isPresented: $showingMoreSheet) {
            MoreOptionsSheet()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareOptionsSheet(auctionId: auctionId, auctionTitle: auction?.title ?? "Live Auction")
        }
        .sheet(isPresented: $showingWalletSheet) {
            WalletSheet()
        }
        .alert("Insufficient Balance", isPresented: $showBidConfirmation) {
            Button("OK") { }
            Button("Add Funds") {
                showingWalletSheet = true
            }
        } message: {
            Text("You need \(formatPrice(bidAmount, walletCurrency)) to place this bid, but only have \(formatPrice(walletBalance, walletCurrency)) available.")
        }
    }

    // MARK: - View Components

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            Text("Loading auction...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Failed to Load Auction")
                .font(.headline)
                .foregroundColor(.white)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                loadAuctionData()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fullScreenAuctionView(_ auction: LiveAuction) -> some View {
        ZStack {
            // Full-screen live stream (background layer)
            WebRTCLiveStreamView(
                auctionId: auctionId,
                auctionTitle: auction.title
            )
            .frame(width: UIScreen.main.bounds.width * 0.6, height: UIScreen.main.bounds.height * 0.6)
            .cornerRadius(20)
            .background(Color(.systemBackground))
            .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)

            // Floating overlays (foreground layer)
            if showingControls {
                floatingControlsOverlay(auction)
            }

            // Right-side controls (separate overlay for better visibility)
            if showingControls {
                rightSideControls()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailingCenter)
                    .allowsHitTesting(true)
                    .zIndex(999)  // Ensure controls appear on top
                    .padding(.trailing, 20)
                    .onAppear {
                        print("🎯 [DEBUG] Right-side controls overlay appeared in LiveAuctionPageView")
                    }
            }

            // Items and chat overlays removed as requested
        }
    }

    // MARK: - Floating Controls Overlay
    private func floatingControlsOverlay(_ auction: LiveAuction) -> some View {
        VStack {
            // Top controls - match seller header alignment
            topControlsBar(auction)
                .padding(.top, 32)

            Spacer()

            // Bottom controls
            bottomControlsBar(auction)
        }
        .padding()
    }

    private func topControlsBar(_ auction: LiveAuction) -> some View {
        HStack {
            // Close button removed as requested

            Spacer()

            // Viewer count and status
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(auction.status == .live ? Color.red : Color.blue)
                        .frame(width: 8, height: 8)
                    Text(auction.status.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .shadow(color: .primary.opacity(0.3), radius: 1, x: 0, y: 0)
                }

                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(.caption)
                        .shadow(color: .primary.opacity(0.3), radius: 1, x: 0, y: 0)
                    Text("\(viewerCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .shadow(color: .primary.opacity(0.3), radius: 1, x: 0, y: 0)

                    // Down arrow button - enhanced visibility
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMinimized.toggle()
                        }
                        print("📱 Down arrow tapped - isMinimized: \(isMinimized)")
                    }) {
                        Image(systemName: isMinimized ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color.primary.opacity(0.2))
                            )
                            .shadow(color: .primary.opacity(0.3), radius: 2, x: 0, y: 0)
                    }
                }
            }
            .foregroundColor(.white)

            Spacer()
        }
    }

    private func bottomControlsBar(_ auction: LiveAuction) -> some View {
        VStack(spacing: 0) {
            // Auction Item Display
            auctionItemDisplay(auction)
        }
    }

    // MARK: - Auction Item Display
    private func auctionItemDisplay(_ auction: LiveAuction) -> some View {
        VStack(spacing: 12) {
            // Always show an item - either current active item or most recent item
            if let item = displayItem {
                // Main item info row with real data
                HStack(spacing: 16) {
                    // Left side - Item image
                    if let imageUrl = item.primaryImageURL {
                        CachedImageView(
                            url: URL(string: imageUrl),
                            placeholder: { ProgressView().scaleEffect(0.5) },
                            failureView: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            }
                        )
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                        .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.yellow.opacity(0.9))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(String(item.name.prefix(2)).uppercased())
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                            )
                    }

                    // Middle - Item details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(item.condition ?? "Live Auction")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))

                        HStack(spacing: 4) {
                            Text("🇱🇧")
                            Text("Starting: \(formatPrice(item.startingPrice, auction.currency))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }

                    Spacer()

                    // Right side - Price and timer
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatPrice(33, auction.currency))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .onAppear {
                                print("💰 [FORCE TEST] Forcing price to show 33")
                                print("💰 [DEBUG] Item data: currentBid=\(item.currentBid ?? -999), startingPrice=\(item.startingPrice)")
                                print("💰 [DEBUG] Raw startingPrice type: \(type(of: item.startingPrice)), value: '\(item.startingPrice)'")
                            }

                        if let endTime = item.itemEndTime {
                            // Show timer for both active and ended items
                            print("⏰ [LiveAuctionPageView] Timer display - Item: \(item.name), EndTime: '\(endTime)' (Length: \(endTime.count)), Status: \(item.status)")
                            if item.status == .active {
                                HStack(spacing: 2) {
                                    Text("💀")
                                    AuctionTimerCompactView(endTime: endTime)
                                }
                            } else {
                                HStack(spacing: 2) {
                                    Text(item.status == .sold ? "✅" : "💀")
                                    AuctionTimerCompactView(endTime: endTime)
                                }
                            }
                        } else {
                            print("⚠️ [LiveAuctionPageView] NO TIMER - Item: \(item.name), EndTime: nil, Status: \(item.status), EstimatedDuration: \(item.estimatedDuration ?? -999)")

                            // No timer data - wait for backend to provide timer instead of hardcoded countdown
                            Text("--:--")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            .onAppear {
                                print("⏰ [NO TIMER] No timer data from backend yet, showing placeholder")
                                print("⏰ [DEBUG] Item status: \(item.status), itemEndTime: \(item.itemEndTime ?? "nil")")
                            }
                        }
                    }
                }

                // Bottom buttons row
                HStack(spacing: 12) {
                    // Custom button
                    Button(action: {
                        print("🎛️ Custom button tapped")
                    }) {
                        Text("Custom")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.1))
                            .cornerRadius(25)
                    }

                    // Enhanced Bid button with wallet integration and animation
                    Button(action: {
                        if item.status == .active {
                            attemptBid(on: item)
                            print("💰 Bid button tapped for item: \(item.name)")
                        } else {
                            print("📝 Cannot bid on ended item: \(item.name)")
                        }
                    }) {
                        HStack {
                            if isBidding {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.primary)
                                Text("Placing Bid...")
                            } else if item.status == .active {
                                HStack(spacing: 8) {
                                    Image(systemName: "dollarsign.circle.fill")
                                    let _ = print("🔍 [BID CALC DEBUG] ===== BID CALCULATION =====")
                                    let _ = print("🔍 [BID CALC DEBUG] Item: \(item.name)")
                                    let _ = print("🔍 [BID CALC DEBUG] currentBid: \(item.currentBid ?? -999)")
                                    let _ = print("🔍 [BID CALC DEBUG] startingPrice: \(item.startingPrice)")
                                    let _ = print("🔍 [BID CALC DEBUG] bidIncrement: \(item.bidIncrement)")
                                    let _ = print("🔍 [BID CALC DEBUG] Calculation: (\(item.currentBid ?? item.startingPrice)) + \(item.bidIncrement)")
                                    let _ = print("🔍 [BID CALC DEBUG] nextMinimumBid: \(item.nextMinimumBid)")
                                    let _ = print("🔍 [BID CALC DEBUG] ================================")
                                    Text("DEBUG: cb=\(item.currentBid ?? -999) sp=\(item.startingPrice) bi=\(item.bidIncrement) nmb=\(item.nextMinimumBid)")
                                        .font(.caption)
                                        .fixedSize()
                                    if walletBalance > 0 {
                                        Text("(Balance: \(formatPrice(walletBalance, walletCurrency)))")
                                            .font(.caption)
                                            .opacity(0.7)
                                    }
                                }
                            } else {
                                Text(item.status == .sold ? "SOLD" : "ENDED")
                            }
                            if item.status == .active && !isBidding {
                                Image(systemName: "chevron.right.2")
                            }
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(item.status == .active ? .primary : .white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            item.status == .active ?
                            (walletBalance >= item.nextMinimumBid ? Color.green.opacity(0.8) : Color.orange.opacity(0.8)) :
                            Color.gray.opacity(0.6)
                        )
                        .cornerRadius(25)
                        .scaleEffect(bidButtonScale)
                        .animation(.easeInOut(duration: 0.1), value: bidButtonScale)
                    }
                    .disabled(item.status != .active || isBidding)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func rightSideControls() -> some View {
        VStack(spacing: 16) {
            // More button
            Button(action: {
                print("📱 [DEBUG] More button tapped in LiveAuctionPageView")
                showingMoreSheet = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .primary.opacity(0.3), radius: 2, x: 0, y: 0)

                    Text("More")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .shadow(color: .primary.opacity(0.3), radius: 2, x: 0, y: 0)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
            }

            // Clip button
            Button(action: {
                print("📹 [DEBUG] Clip button tapped in LiveAuctionPageView")
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "video.badge.plus")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .primary.opacity(0.3), radius: 2, x: 0, y: 0)

                    Text("Clip")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .shadow(color: .primary.opacity(0.3), radius: 2, x: 0, y: 0)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
            }

            // Share button
            Button(action: {
                print("📤 [DEBUG] Share button tapped in LiveAuctionPageView")
                showingShareSheet = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.right")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .primary.opacity(0.3), radius: 2, x: 0, y: 0)

                    Text("Share")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .shadow(color: .primary.opacity(0.3), radius: 2, x: 0, y: 0)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
            }

            // Wallet button
            Button(action: {
                print("💳 [DEBUG] Wallet button tapped in LiveAuctionPageView")
                showingWalletSheet = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "wallet.pass")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .primary.opacity(0.3), radius: 2, x: 0, y: 0)

                    Text("Wallet")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .shadow(color: .primary.opacity(0.3), radius: 2, x: 0, y: 0)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
            }

            // Shop button
            Button(action: {
                print("🛒 [DEBUG] Shop button tapped in LiveAuctionPageView")
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "storefront")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .primary.opacity(0.3), radius: 2, x: 0, y: 0)

                    Text("Shop")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .shadow(color: .primary.opacity(0.3), radius: 2, x: 0, y: 0)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .background(Color.clear)  // Clean transparent background
        .cornerRadius(12)
        .onAppear {
            print("🎯 [DEBUG] Right-side controls appeared in LiveAuctionPageView with high-visibility styling")
        }
    }

    // Floating banner function removed as requested

    // MARK: - Overlay Views

    // Items and chat overlay views removed as requested

    // MARK: - Helper Components

    struct AuctionTimerCompactView: View {
        let endTime: String
        @State private var timeRemaining: String = ""
        @State private var timer: Timer?

        var body: some View {
            Text(timeRemaining)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(4)
                .onAppear {
                    startTimer()
                }
                .onDisappear {
                    timer?.invalidate()
                }
        }

        private func startTimer() {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateTimeRemaining()
            }
            updateTimeRemaining()
        }

        private func updateTimeRemaining() {
            // Try multiple date formats to parse the endTime
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            print("🕐 [AuctionTimerCompactView] Parsing endTime: '\(endTime)'")

            var endDate: Date?

            // Try with fractional seconds first (e.g., 2026-04-04T14:29:55.288Z)
            endDate = formatter.date(from: endTime)

            // If that fails, try without fractional seconds
            if endDate == nil {
                formatter.formatOptions = [.withInternetDateTime]
                endDate = formatter.date(from: endTime)
            }

            // If still nil, try a basic date formatter as fallback
            if endDate == nil {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                endDate = dateFormatter.date(from: endTime)
            }

            guard let finalEndDate = endDate else {
                print("❌ [AuctionTimerCompactView] Failed to parse endTime: '\(endTime)'")
                timeRemaining = "--:--"
                return
            }
            print("✅ [AuctionTimerCompactView] Successfully parsed endTime to: \(finalEndDate)")

            let now = Date()
            let interval = finalEndDate.timeIntervalSince(now)

            if interval <= 0 {
                timeRemaining = "ENDED"
                timer?.invalidate()
                return
            }

            let minutes = Int(interval) / 60
            let seconds = Int(interval) % 60
            timeRemaining = String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Helper Methods

    private func formatPrice(_ amount: Double, _ currency: String) -> String {
        print("🔍 [LIVE FORMAT PRICE] Input: amount=\(amount), currency='\(currency)'")

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_US")

        if let formattedString = formatter.string(from: NSNumber(value: amount)) {
            print("🔍 [LIVE FORMAT PRICE] NumberFormatter success: '\(formattedString)'")
            return formattedString
        } else {
            // More robust fallback - use proper string formatting
            let formattedAmount = String(format: "%.0f", amount)
            let fallback = "$\(formattedAmount)"
            print("🔍 [LIVE FORMAT PRICE] NumberFormatter failed, using robust fallback: '\(fallback)'")
            print("🔍 [LIVE FORMAT PRICE] - amount: \(amount) -> formatted: \(formattedAmount)")
            return fallback
        }
    }

    // MARK: - Private Methods

    private func loadAuctionData() {
        print("🔍 [LiveAuctionPageView] Loading auction data for: \(auctionId)")

        isLoading = true
        errorMessage = nil

        auctionService.getAuctionDetails(auctionId: auctionId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        self.errorMessage = error.localizedDescription
                        print("❌ [LiveAuctionPageView] Error: \(error)")
                    }
                },
                receiveValue: { (auctionData, itemsData) in
                    print("✅ [LiveAuctionPageView] Loaded auction: \(auctionData.title)")
                    self.auction = auctionData
                    self.items = itemsData
                    self.viewerCount = auctionData.currentViewers

                    // Find current active item
                    self.currentItem = itemsData.first { $0.isActive }
                    print("🎯 [LiveAuctionPageView] Active item: \(self.currentItem?.name ?? "none")")
                }
            )
            .store(in: &cancellables)
    }

    private func setupRealTimeUpdates() {
        print("📡 [LiveAuctionPageView] Setting up real-time updates")

        // Connect to auction
        socketService.connectToAuction(auctionId)

        // Join the auction room to receive broadcasts
        socketService.joinAuction(auctionId)
        print("🏠 [LiveAuctionPageView] Joined auction room: \(auctionId)")

        // Connection status
        socketService.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { status in
                self.connectionStatus = status
            }
            .store(in: &cancellables)

        // Viewer count updates
        socketService.onViewerCountUpdate { update in
            DispatchQueue.main.async {
                if update.auctionId == self.auctionId {
                    self.viewerCount = update.viewerCount
                }
            }
        }
        .store(in: &cancellables)

        // Bid updates
        socketService.onBidUpdate { bidUpdate in
            DispatchQueue.main.async {
                if bidUpdate.auctionId == self.auctionId {
                    self.updateItemBid(bidUpdate)
                }
            }
        }
        .store(in: &cancellables)

        // Timer events (item changes)
        socketService.onTimerEvent { timerEvent in
            DispatchQueue.main.async {
                if timerEvent.auctionId == self.auctionId {
                    self.handleTimerEvent(timerEvent)
                }
            }
        }
        .store(in: &cancellables)

        // New item events (when seller creates new items)
        socketService.onNewItem { newItemData in
            DispatchQueue.main.async {
                if newItemData.auctionId == self.auctionId {
                    self.handleNewItem(newItemData)
                }
            }
        }
        .store(in: &cancellables)
    }

    private func updateItemBid(_ bidUpdate: BidUpdateData) {
        // Update item in items array
        if let index = items.firstIndex(where: { $0._id == bidUpdate.itemId }) {
            var updatedItem = items[index]
            // Create a new item with updated bid (since AuctionItem properties might be let)
            items[index] = AuctionItem(
                _id: updatedItem._id,
                auctionId: updatedItem.auctionId,
                name: updatedItem.name,
                description: updatedItem.description,
                images: updatedItem.images,
                startingPrice: updatedItem.startingPrice,
                currentBid: bidUpdate.bidAmount,
                bidIncrement: updatedItem.bidIncrement,
                estimatedDuration: updatedItem.estimatedDuration,
                itemEndTime: updatedItem.itemEndTime,
                status: updatedItem.status,
                winnerId: updatedItem.winnerId,
                winningBid: updatedItem.winningBid,
                bidCount: (updatedItem.bidCount ?? 0) + 1,
                category: updatedItem.category,
                condition: updatedItem.condition,
                weight: updatedItem.weight,
                dimensions: updatedItem.dimensions,
                auctionOrder: updatedItem.auctionOrder
            )

            // Update current item if it's the same
            if currentItem?._id == bidUpdate.itemId {
                currentItem = items[index]
            }
        }

        print("💰 [LiveAuctionPageView] Bid updated: \(bidUpdate.bidderName) - $\(bidUpdate.bidAmount)")
    }

    private func handleNewItem(_ newItemData: NewItemData) {
        print("🆕 [LiveAuctionPageView] New item created: \(newItemData.item.name)")
        print("⏱️ [LiveAuctionPageView] New item timer data - EstimatedDuration: \(newItemData.item.estimatedDuration ?? 0), ItemEndTime: \(newItemData.item.itemEndTime ?? "nil"), Status: \(newItemData.item.status)")

        // Add the new item to the items array
        let newAuctionItem = AuctionItem(
            _id: newItemData.item._id,
            auctionId: newItemData.item.auctionId,
            name: newItemData.item.name,
            description: newItemData.item.description,
            images: newItemData.item.images,
            startingPrice: newItemData.item.startingPrice,
            currentBid: newItemData.item.currentBid,
            bidIncrement: newItemData.item.bidIncrement,
            estimatedDuration: newItemData.item.estimatedDuration,
            itemEndTime: newItemData.item.itemEndTime,
            status: newItemData.item.status,
            winnerId: newItemData.item.winnerId,
            winningBid: newItemData.item.winningBid,
            bidCount: newItemData.item.bidCount,
            category: newItemData.item.category,
            condition: newItemData.item.condition,
            weight: newItemData.item.weight,
            dimensions: newItemData.item.dimensions,
            auctionOrder: newItemData.item.auctionOrder
        )

        // Add to items array
        items.append(newAuctionItem)

        // If this is an active item, set it as current
        if newAuctionItem.status == .active {
            currentItem = newAuctionItem
        }
    }

    private func handleTimerEvent(_ timerEvent: TimerEventWithAction) {
        print("⏱️ [LiveAuctionPageView] Timer event: \(timerEvent.action) for item: \(timerEvent.itemId)")
        print("⏱️ [LiveAuctionPageView] Timer event data - StartTime: \(timerEvent.startTime ?? "nil"), EndTime: \(timerEvent.endTime ?? "nil")")

        switch timerEvent.action {
        case "start":
            // Check if item exists, if not create it from timer event data
            if let index = items.firstIndex(where: { $0._id == timerEvent.itemId }) {
                // Update existing item
                let updatedItem = items[index]
                items[index] = AuctionItem(
                    _id: updatedItem._id,
                    auctionId: updatedItem.auctionId,
                    name: updatedItem.name,
                    description: updatedItem.description,
                    images: updatedItem.images,
                    startingPrice: updatedItem.startingPrice,
                    currentBid: updatedItem.currentBid,
                    bidIncrement: updatedItem.bidIncrement,
                    estimatedDuration: updatedItem.estimatedDuration,
                    itemEndTime: timerEvent.endTime,
                    status: .active,
                    winnerId: updatedItem.winnerId,
                    winningBid: updatedItem.winningBid,
                    bidCount: updatedItem.bidCount,
                    category: updatedItem.category,
                    condition: updatedItem.condition,
                    weight: updatedItem.weight,
                    dimensions: updatedItem.dimensions,
                    auctionOrder: updatedItem.auctionOrder
                )
                currentItem = items[index]
            } else if let itemDetails = timerEvent.itemDetails {
                // Create new item from timer event data (dynamic items)
                print("🆕 [LiveAuctionPageView] Creating new dynamic item from timer_started event: \(itemDetails.name)")
                let newItem = AuctionItem(
                    _id: itemDetails._id,
                    auctionId: timerEvent.auctionId,
                    name: itemDetails.name,
                    description: itemDetails.description,
                    images: itemDetails.images,
                    startingPrice: itemDetails.startingPrice,
                    currentBid: itemDetails.currentBid,
                    bidIncrement: itemDetails.bidIncrement,
                    estimatedDuration: timerEvent.duration,
                    itemEndTime: timerEvent.endTime,
                    status: .active,
                    winnerId: itemDetails.winnerId,
                    winningBid: itemDetails.winningBid,
                    bidCount: itemDetails.bidCount,
                    category: itemDetails.category,
                    condition: itemDetails.condition,
                    weight: itemDetails.weight,
                    dimensions: itemDetails.dimensions,
                    auctionOrder: itemDetails.auctionOrder
                )

                // Add to items array and set as current
                items.append(newItem)
                currentItem = newItem

                print("✅ [LiveAuctionPageView] Dynamic item \"\(itemDetails.name)\" added and set as current")
            }

        case "end":
            // Update item status to sold/unsold
            if let index = items.firstIndex(where: { $0._id == timerEvent.itemId }) {
                let updatedItem = items[index]
                let finalStatus: AuctionItemStatus = (updatedItem.currentBid ?? 0) > updatedItem.startingPrice ? .sold : .unsold

                items[index] = AuctionItem(
                    _id: updatedItem._id,
                    auctionId: updatedItem.auctionId,
                    name: updatedItem.name,
                    description: updatedItem.description,
                    images: updatedItem.images,
                    startingPrice: updatedItem.startingPrice,
                    currentBid: updatedItem.currentBid,
                    bidIncrement: updatedItem.bidIncrement,
                    estimatedDuration: updatedItem.estimatedDuration,
                    itemEndTime: updatedItem.itemEndTime,
                    status: finalStatus,
                    winnerId: updatedItem.winnerId,
                    winningBid: updatedItem.winningBid,
                    bidCount: updatedItem.bidCount,
                    category: updatedItem.category,
                    condition: updatedItem.condition,
                    weight: updatedItem.weight,
                    dimensions: updatedItem.dimensions,
                    auctionOrder: updatedItem.auctionOrder
                )

                // Clear current item if this was it
                if currentItem?._id == timerEvent.itemId {
                    currentItem = nil
                }
            }

        default:
            break
        }
    }

    private func cleanup() {
        print("🧹 [LiveAuctionPageView] Cleaning up")
        cancellables.removeAll()
    }

    // MARK: - Periodic Refresh for Real-time Updates

    private func startPeriodicRefresh() {
        print("🔄 [LiveAuctionPageView] Starting periodic refresh every 3 seconds")
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.refreshAuctionData()
        }
    }

    private func stopPeriodicRefresh() {
        print("🛑 [LiveAuctionPageView] Stopping periodic refresh")
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refreshAuctionData() {
        print("🔄 [LiveAuctionPageView] Refreshing auction data...")

        auctionService.getAuctionDetails(auctionId: auctionId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ [LiveAuctionPageView] Refresh error: \(error)")
                    }
                },
                receiveValue: { (auctionData, itemsData) in
                    print("✅ [LiveAuctionPageView] Refreshed auction data")

                    // Update auction data
                    self.auction = auctionData
                    self.viewerCount = auctionData.currentViewers

                    // Update items array with new data
                    self.items = itemsData

                    // Find and update current active item
                    if let activeItem = itemsData.first(where: { $0.status == .active }) {
                        self.currentItem = activeItem
                        print("🎯 [LiveAuctionPageView] Updated active item: \(activeItem.name) - Price: \(activeItem.currentBid ?? activeItem.startingPrice)")
                    }

                    // Ensure we have a display item even if no active item
                    if self.currentItem == nil {
                        // Get the most recent item
                        if let recentItem = itemsData.last {
                            print("📦 [LiveAuctionPageView] No active item, showing recent: \(recentItem.name)")
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Views

struct AuctionItemRowView: View {
    let item: AuctionItem
    let isActive: Bool
    let isDarkMode: Bool
    let onTap: () -> Void
    let onBidTap: () -> Void

    init(item: AuctionItem, isActive: Bool, isDarkMode: Bool = false, onTap: @escaping () -> Void, onBidTap: @escaping () -> Void) {
        self.item = item
        self.isActive = isActive
        self.isDarkMode = isDarkMode
        self.onTap = onTap
        self.onBidTap = onBidTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Item Image
                if let imageUrl = item.primaryImageURL {
                    CachedImageView(
                        url: URL(string: imageUrl),
                        placeholder: { ProgressView().scaleEffect(0.5) },
                        failureView: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .overlay(Image(systemName: "photo"))
                        }
                    )
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
                }

                // Item Details
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundColor(isDarkMode ? .white : .primary)

                        Spacer()

                        statusBadge(item.status)
                    }

                    Text("Current: $\(String(format: "%.0f", item.displayPrice))")
                        .font(.subheadline)
                        .foregroundColor(.green)

                    if isActive {
                        Text("💀 LIVE BIDDING NOW")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }

                if item.isActive {
                    Button("Bid") {
                        onBidTap()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .font(.caption)
                    .fontWeight(.semibold)
                }
            }
            .padding()
            .background(
                isActive ?
                Color.blue.opacity(isDarkMode ? 0.3 : 0.1) :
                (isDarkMode ? Color.white.opacity(0.1) : Color(.systemBackground))
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func statusBadge(_ status: AuctionItemStatus) -> some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.2))
            .foregroundColor(statusColor(status))
            .cornerRadius(4)
    }

    private func statusColor(_ status: AuctionItemStatus) -> Color {
        switch status {
        case .active: return .green
        case .pending: return .blue
        case .sold: return .purple
        case .unsold: return .gray
        }
    }
}

struct ItemDetailSheet: View {
    let item: AuctionItem
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Item Images
                    if !item.images.isEmpty {
                        TabView {
                            ForEach(item.images, id: \.self) { imageUrl in
                                CachedImageView(
                                    url: URL(string: imageUrl),
                                    placeholder: { ProgressView() },
                                    failureView: { Rectangle().fill(Color.gray.opacity(0.3)) }
                                )
                                .aspectRatio(contentMode: .fit)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle())
                        .frame(height: 250)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(item.description)
                            .font(.body)

                        if let category = item.category {
                            Label(category, systemImage: "tag")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pricing Information")
                                .font(.headline)

                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Starting Price")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("$\(String(format: "%.0f", item.startingPrice))")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }

                                Spacer()

                                VStack(alignment: .trailing) {
                                    Text("Current Bid")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("$\(String(format: "%.0f", item.displayPrice))")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - More Options Sheet

struct MoreOptionsSheet: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Video")
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.top, 20)

                HStack(spacing: 20) {
                    // Sound Option
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray5))
                            .frame(width: 150, height: 120)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.primary)

                                    Text("Sound")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            )
                    }
                    .onTapGesture {
                        print("🔊 Sound option tapped")
                    }

                    // Captions Option
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray5))
                            .frame(width: 150, height: 120)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "captions.bubble.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.red)

                                    Text("Captions")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.red)
                                }
                            )
                    }
                    .onTapGesture {
                        print("📝 Captions option tapped")
                    }
                }

                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Share Options Sheet

struct ShareOptionsSheet: View {
    let auctionId: String
    let auctionTitle: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with seller info
                    HStack(spacing: 12) {
                        // Profile image with golden border
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.yellow, Color.orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)

                            Circle()
                                .fill(Color.primary)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.yellow)
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("goldenbidz")
                                .font(.headline)
                                .fontWeight(.semibold)

                            // Live stream card
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary)
                                .frame(height: 120)
                                .overlay(
                                    VStack(spacing: 8) {
                                        HStack {
                                            Text("Live")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.red)
                                                .cornerRadius(4)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.top, 8)

                                        Spacer()

                                        VStack(spacing: 4) {
                                            HStack {
                                                Image(systemName: "crown.fill")
                                                    .foregroundColor(.yellow)
                                                Text("FAST VIP SHOW")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            }

                                            HStack {
                                                Image(systemName: "crown.fill")
                                                    .foregroundColor(.yellow)
                                                Text("$50 GIVEAWAYS...")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            }

                                            Text("Shop Live Now!")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.bottom, 8)
                                    }
                                )
                        }
                    }
                    .padding()

                    // Sharing options
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                        // Search
                        shareOption(icon: "magnifyingglass", title: "Search", action: {})

                        // User profiles
                        shareOption(icon: "person.circle.fill", title: "mikeypalz", color: .pink, action: {})
                        shareOption(icon: "person.circle.fill", title: "alexsmi734...", action: {})

                        // Copy Link
                        shareOption(icon: "link", title: "Copy Link", action: {
                            UIPasteboard.general.string = "https://malloflebanon.com/auction/\(auctionId)"
                        })

                        // Messages
                        shareOption(icon: "message.fill", title: "Messages", color: .green, action: {})

                        // IG Stories
                        shareOption(icon: "plus.circle.fill", title: "IG Stories", color: .orange, action: {})

                        // Instagram
                        shareOption(icon: "camera.circle.fill", title: "Instagram", color: .purple, action: {})

                        // Messenger
                        shareOption(icon: "paperplane.fill", title: "Messenger", color: .blue, action: {})
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }

    private func shareOption(icon: String, title: String, color: Color = .primary, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Circle()
                    .fill(color == .primary ? Color(.systemGray5) : color.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(color == .primary ? .primary : color)
                    )
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Wallet Sheet

struct WalletSheet: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Wallet")
                    .font(.title)
                    .fontWeight(.medium)
                    .padding(.top, 20)

                VStack(spacing: 16) {
                    // Shipping option
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "shippingbox.fill")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Shipping")
                                .font(.headline)
                                .fontWeight(.medium)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ship to Next To Alfa Store")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Saida 00961")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)

                    Divider()

                    // Add Payment Method
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "creditcard.fill")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Add Payment Method")
                                .font(.headline)
                                .fontWeight(.medium)

                            Text("You won't be charged until you purchase")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Add") {
                            print("💳 Add Payment Method tapped")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    .padding(.vertical, 8)

                    Divider()

                    // Make Referrals, Earn Credit
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.yellow.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "gift.fill")
                                    .font(.title3)
                                    .foregroundColor(.yellow)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Make Referrals, Earn Credit")
                                .font(.headline)
                                .fontWeight(.medium)

                            Text("Earn up to US$200 for each referral")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)

                    Divider()

                    // Promo Code
                    HStack(spacing: 12) {
                        TextField("Promo Code", text: .constant(""))
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button("Apply") {
                            print("🎟️ Apply Promo Code tapped")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Preview

// MARK: - Simple Countdown Timer (for estimatedDuration fallback)

struct SimpleCountdownTimer: View {
    let initialSeconds: Int
    @State private var remainingSeconds: Int = 0
    @State private var timer: Timer?

    init(initialSeconds: Int) {
        self.initialSeconds = initialSeconds
        self._remainingSeconds = State(initialValue: initialSeconds)
    }

    private var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var timerColor: Color {
        if remainingSeconds <= 0 { return .red }
        if remainingSeconds <= 30 { return .red }
        if remainingSeconds <= 60 { return .orange }
        return .green
    }

    var body: some View {
        Text(remainingSeconds <= 0 ? "ENDED" : formattedTime)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(timerColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(timerColor.opacity(0.2))
            .cornerRadius(4)
            .onAppear {
                startCountdown()
            }
            .onDisappear {
                stopCountdown()
            }
    }

    private func startCountdown() {
        print("⏱️ [SimpleCountdownTimer] Starting countdown with \(remainingSeconds) seconds")
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                stopCountdown()
            }
        }
    }

    private func stopCountdown() {
        timer?.invalidate()
        timer = nil
    }
}

struct LiveAuctionPageView_Previews: PreviewProvider {
    static var previews: some View {
        LiveAuctionPageView(auctionId: "sample-auction-id")
    }
}