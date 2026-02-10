import SwiftUI
import Combine

// MARK: - Live Auction Page
// Complete auction experience combining live stream, bidding, chat, and timer
// This replaces and enhances the existing AuctionDetailView

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

    // UI State
    @State private var selectedTab = 0
    @State private var showingBiddingSheet = false
    @State private var showingItemDetails = false
    @State private var selectedDetailItem: AuctionItem?

    // Real-time Updates
    @State private var viewerCount = 0
    @State private var connectionStatus = "Connecting..."

    private let tabs = ["Stream", "Items", "Chat"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let auction = auction {
                    auctionContent(auction)
                }
            }
            .navigationTitle("Live Auction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        socketService.disconnect()
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if let item = currentItem, item.isActive {
                        Button("Bid") {
                            showingBiddingSheet = true
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
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
    }

    // MARK: - View Components

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading auction...")
                .font(.headline)
                .foregroundColor(.secondary)
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

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
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

    private func auctionContent(_ auction: LiveAuction) -> some View {
        VStack(spacing: 0) {
            // Auction Header
            auctionHeader(auction)

            // Timer (if active item)
            if let item = currentItem, item.isActive {
                AuctionTimerView(auction: auction, currentItem: item)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }

            // Tab Navigation
            tabSelector

            // Tab Content
            TabView(selection: $selectedTab) {
                streamTabView
                    .tag(0)

                itemsTabView
                    .tag(1)

                chatTabView
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }

    private func auctionHeader(_ auction: LiveAuction) -> some View {
        VStack(spacing: 12) {
            // Title and Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(auction.title)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(auction.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    statusBadge(auction.status)

                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .foregroundColor(.green)
                        Text("\(viewerCount)")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            // Current Item Info (if available)
            if let item = currentItem {
                currentItemBanner(item)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private func currentItemBanner(_ item: AuctionItem) -> some View {
        HStack(spacing: 12) {
            // Item Thumbnail
            if let imageUrl = item.primaryImageURL {
                CachedImageView(
                    url: URL(string: imageUrl),
                    placeholder: { ProgressView().scaleEffect(0.5) },
                    failureView: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipped()
                .cornerRadius(8)
            }

            // Item Info
            VStack(alignment: .leading, spacing: 4) {
                Text("🔴 LIVE NOW")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)

                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Bid")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.0f", item.currentBid ?? item.startingPrice))")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Bid")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.0f", item.nextMinimumBid))")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            // Quick Bid Button
            Button(action: {
                showingBiddingSheet = true
            }) {
                Image(systemName: "hammer.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue)
                    .cornerRadius(22)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(tabs[index])
                            .font(.subheadline)
                            .fontWeight(selectedTab == index ? .semibold : .medium)

                        if selectedTab == index {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(height: 2)
                                .transition(.opacity)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(selectedTab == index ? .blue : .secondary)
                }
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
    }

    private var streamTabView: some View {
        VStack(spacing: 16) {
            LiveStreamView(auctionId: auctionId)
                .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var itemsTabView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    AuctionItemRowView(item: item, isActive: item._id == currentItem?._id) {
                        selectedDetailItem = item
                        showingItemDetails = true
                    } onBidTap: {
                        if item.isActive {
                            showingBiddingSheet = true
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var chatTabView: some View {
        AuctionChatView(auctionId: auctionId)
            .background(Color(.systemGroupedBackground))
    }

    private func statusBadge(_ status: AuctionStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status == .live ? Color.red : Color.blue)
                .frame(width: 6, height: 6)
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.1))
        .cornerRadius(12)
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
    let onTap: () -> Void
    let onBidTap: () -> Void

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
            .background(isActive ? Color.blue.opacity(0.1) : Color(.systemBackground))
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

// MARK: - Preview

struct LiveAuctionPageView_Previews: PreviewProvider {
    static var previews: some View {
        LiveAuctionPageView(auctionId: "sample-auction-id")
    }
}