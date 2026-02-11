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

    var body: some View {
        ZStack {
            // Full-screen background - completely black including status bar area
            Color.black
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
        }
        .onDisappear {
            cleanup()
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all)
            .clipped()

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
                        .shadow(color: .black, radius: 1, x: 0, y: 0)
                }

                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.caption)
                        .shadow(color: .black, radius: 1, x: 0, y: 0)
                    Text("\(viewerCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .shadow(color: .black, radius: 1, x: 0, y: 0)

                    // Down arrow button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMinimized.toggle()
                        }
                        print("📱 Down arrow tapped - isMinimized: \(isMinimized)")
                    }) {
                        Image(systemName: isMinimized ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 1, x: 0, y: 0)
                    }
                }
            }
            .foregroundColor(.white)

            Spacer()
        }
    }

    private func bottomControlsBar(_ auction: LiveAuction) -> some View {
        // All bottom icons removed as requested
        EmptyView()
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
                        .shadow(color: .black, radius: 2, x: 0, y: 0)

                    Text("More")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 0, y: 0)
                }
                .padding(8)
                .background(Color.black.opacity(0.5))
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
                        .shadow(color: .black, radius: 2, x: 0, y: 0)

                    Text("Clip")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 0, y: 0)
                }
                .padding(8)
                .background(Color.black.opacity(0.5))
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
                        .shadow(color: .black, radius: 2, x: 0, y: 0)

                    Text("Share")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 0, y: 0)
                }
                .padding(8)
                .background(Color.black.opacity(0.5))
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
                        .shadow(color: .black, radius: 2, x: 0, y: 0)

                    Text("Wallet")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 0, y: 0)
                }
                .padding(8)
                .background(Color.black.opacity(0.5))
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
                        .shadow(color: .black, radius: 2, x: 0, y: 0)

                    Text("Shop")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 0, y: 0)
                }
                .padding(8)
                .background(Color.black.opacity(0.5))
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

    private func currentItemFloatingBanner(_ item: AuctionItem) -> some View {
        HStack(spacing: 12) {
            // Item Thumbnail
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
                .frame(width: 50, height: 50)
                .clipped()
                .cornerRadius(8)
            }

            // Item Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("🔴 LIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)

                    // Timer if available
                    if let endTime = item.itemEndTime {
                        AuctionTimerCompactView(endTime: endTime)
                    }
                }

                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    Text("Current: $\(String(format: "%.0f", item.currentBid ?? item.startingPrice))")
                        .font(.caption)
                        .foregroundColor(.green)

                    Text("Next: $\(String(format: "%.0f", item.nextMinimumBid))")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.6), lineWidth: 1)
        )
    }

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
            let formatter = ISO8601DateFormatter()
            guard let endDate = formatter.date(from: endTime) else {
                timeRemaining = "--:--"
                return
            }

            let now = Date()
            let interval = endDate.timeIntervalSince(now)

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

    private func handleTimerEvent(_ timerEvent: TimerEvent) {
        print("⏱️ [LiveAuctionPageView] Timer event: \(timerEvent.action) for item: \(timerEvent.itemId)")

        switch timerEvent.action {
        case "start":
            // Update item status to active and set as current
            if let index = items.firstIndex(where: { $0._id == timerEvent.itemId }) {
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

                    Text("Current: $\(String(format: "%.0f", item.currentBid ?? item.startingPrice))")
                        .font(.subheadline)
                        .foregroundColor(.green)

                    if isActive {
                        Text("🔴 LIVE BIDDING NOW")
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
                                    Text("$\(String(format: "%.0f", item.currentBid ?? item.startingPrice))")
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
                                .fill(Color.black)
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
                                .fill(Color.black)
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
                        .background(Color.black)
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

struct LiveAuctionPageView_Previews: PreviewProvider {
    static var previews: some View {
        LiveAuctionPageView(auctionId: "sample-auction-id")
    }
}