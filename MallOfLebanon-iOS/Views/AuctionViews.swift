import SwiftUI
import Combine
import Foundation

// MARK: - Video Streaming Data Models

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

struct QualityRequest: Codable {
    let auctionId: String
    let quality: String // "low", "medium", "high", "ultra"
    let timestamp: String
}


// MARK: - Auction Sheet Item
struct AuctionSheetItem: Identifiable {
    let id: String
}

// MARK: - Auction Section for Home Page
struct AuctionSection: View {
    @StateObject private var auctionService = AuctionService.shared
    @State private var liveAuctions: [LiveAuction] = []
    @State private var upcomingAuctions: [LiveAuction] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var presentingAuctionId: String = ""
    @State private var showingAuctionDetail = false
    @State private var showingLiveAuction = false
    @State private var liveAuctionId: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        Text("Live Auctions")
                            .font(.title2)
                            .font(.system(.body, design: .default).weight(.bold))
                            .foregroundColor(.primary)
                    }
                    Text("Bid on exclusive items in real-time!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                if !liveAuctions.isEmpty || !upcomingAuctions.isEmpty {
                    NavigationLink(destination: AuctionListView()) {
                        Text("View All")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }

            // Content
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if liveAuctions.isEmpty && upcomingAuctions.isEmpty {
                noAuctionsView
            } else {
                auctionCardsView
            }
        }
        .onAppear {
            loadAuctions()
        }
        .sheet(item: .constant(showingAuctionDetail ? AuctionSheetItem(id: presentingAuctionId) : nil)) { sheetItem in
            AuctionDetailView(auctionId: sheetItem.id)
                .onAppear {
                    print("📱 [AuctionSection] Sheet presented with auction ID: \(sheetItem.id)")
                }
        }
        .fullScreenCover(isPresented: $showingLiveAuction) {
            LiveAuctionPageView(auctionId: liveAuctionId)
                .onAppear {
                    print("🚀 [AuctionSection] Full-screen LiveAuctionPageView presented")
                    print("🎯 [AuctionSection] LiveAuctionPageView auctionId parameter: '\(liveAuctionId)'")
                    print("📊 [AuctionSection] liveAuctionId state value: '\(liveAuctionId)'")
                }
                .onDisappear {
                    print("👋 [AuctionSection] Full-screen LiveAuctionPageView dismissed")
                    liveAuctionId = ""
                }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading auctions...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Failed to load auctions")
                .font(.headline)
                .foregroundColor(.primary)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                loadAuctions()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var noAuctionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("No Active Auctions")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Check back soon for exciting live bidding opportunities!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var auctionCardsView: some View {
        VStack(spacing: 16) {
            // Live Auctions (prioritized)
            if !liveAuctions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(liveAuctions.prefix(5)) { auction in
                            AuctionCard(auction: auction, isLive: true) {
                                print("🎯 [AuctionSection] User tapped live auction: \(auction.title)")
                                print("📱 [AuctionSection] Auction ID: \(auction._id)")
                                print("📈 [AuctionSection] Auction Status: \(auction.status.displayName)")
                                print("🚀 [AuctionSection] Opening LiveAuctionPageView directly for live auction")

                                // Use dispatch to ensure state is set on main thread
                                DispatchQueue.main.async {
                                    print("🎯 [AuctionSection] Setting liveAuctionId = \(auction._id)")
                                    self.presentLiveAuction(auctionId: auction._id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            // Upcoming Auctions (if no live auctions or space permitting)
            if !upcomingAuctions.isEmpty && (liveAuctions.isEmpty || liveAuctions.count < 3) {
                if !liveAuctions.isEmpty {
                    HStack {
                        Text("Upcoming")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(upcomingAuctions.prefix(3)) { auction in
                            AuctionCard(auction: auction, isLive: false) {
                                print("🎯 [AuctionSection] User tapped upcoming auction: \(auction.title)")
                                print("📱 [AuctionSection] Auction ID: \(auction._id)")
                                print("📈 [AuctionSection] Auction Status: \(auction.status.displayName)")

                                // Use dispatch to ensure state is set on main thread
                                DispatchQueue.main.async {
                                    print("🚀 [AuctionSection] Setting presentingAuctionId = \(auction._id)")
                                    presentingAuctionId = auction._id
                                    showingAuctionDetail = false
                                    print("🚀 [AuctionSection] Setting showingAuctionDetail = true")
                                    showingAuctionDetail = true
                                    print("✅ [AuctionSection] Navigation state set, sheet should appear")
                                    print("✅ [AuctionSection] Current presentingAuctionId value: '\(presentingAuctionId)'")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func loadAuctions() {
        print("🚀 [AuctionSection] Starting loadAuctions()...")
        print("🔄 [AuctionSection] Setting isLoading = true")
        isLoading = true
        errorMessage = nil

        print("📞 [AuctionSection] Calling auctionService.getHomeAuctions()...")
        auctionService.getHomeAuctions()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    print("🎯 [AuctionSection] Received completion: \(completion)")
                    self.isLoading = false
                    print("🔄 [AuctionSection] Setting isLoading = false")

                    if case .failure(let error) = completion {
                        let errorDescription = error.localizedDescription
                        print("❌ [AuctionSection] Error occurred: \(error)")
                        print("📝 [AuctionSection] Error description: \(errorDescription)")
                        self.errorMessage = errorDescription
                        print("🔄 [AuctionSection] Set errorMessage = \(errorDescription)")
                    } else {
                        print("✅ [AuctionSection] Completion successful (no error)")
                    }
                },
                receiveValue: { (live, upcoming) in
                    print("📦 [AuctionSection] Received auction data:")
                    print("🔴 [AuctionSection] Live auctions: \(live.count)")
                    print("🕐 [AuctionSection] Upcoming auctions: \(upcoming.count)")

                    for (index, auction) in live.enumerated() {
                        print("🎯 [AuctionSection] Live \(index + 1): \(auction.title) - \(auction.status.displayName)")
                    }

                    for (index, auction) in upcoming.enumerated() {
                        print("⏰ [AuctionSection] Upcoming \(index + 1): \(auction.title) - \(auction.status.displayName)")
                    }

                    self.liveAuctions = live
                    self.upcomingAuctions = upcoming
                    print("💾 [AuctionSection] Successfully stored auction data")
                    print("📡 [AuctionSection] Final result: \(live.count) live + \(upcoming.count) upcoming auctions")
                }
            )
            .store(in: &cancellables)

        print("📝 [AuctionSection] Subscription stored in cancellables")
    }

    private func presentLiveAuction(auctionId: String) {
        print("🚀 [AuctionSection] presentLiveAuction called with ID: \(auctionId)")
        guard !auctionId.isEmpty else {
            print("❌ [AuctionSection] Cannot present live auction with empty ID")
            return
        }

        liveAuctionId = auctionId
        print("📱 [AuctionSection] Set liveAuctionId = \(liveAuctionId)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🎯 [AuctionSection] Triggering fullScreenCover presentation")
            showingLiveAuction = true
            print("✅ [AuctionSection] showingLiveAuction = true")
        }
    }
}

// MARK: - Auction Detail View
struct AuctionDetailView: View {
    let auctionId: String
    @StateObject private var auctionService = AuctionService.shared
    @State private var auction: LiveAuction?
    @State private var items: [AuctionItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    @Environment(\.dismiss) var dismiss

    // State for Join Auction functionality
    @State private var showingBiddingSheet = false
    @State private var selectedItem: AuctionItem?
    @State private var bidAmount: String = ""
    @State private var isPlacingBid = false
    @State private var bidError: String?
    @State private var hasJoinedAuction = false
    @State private var showJoinedAlert = false
    @State private var showingLiveStream = false

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading auction...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Error Loading Auction")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            loadAuctionDetails()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if let auction = auction {
                    auctionDetailContent(auction)
                }
            }
            .navigationTitle("Live Auction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            print("🔍 [AuctionDetailView] View appeared for auction ID: \(auctionId)")
            print("🔍 [AuctionDetailView] Current loading state: \(isLoading)")
            print("🔍 [AuctionDetailView] Current error: \(errorMessage ?? "nil")")
            loadAuctionDetails()
        }
        .sheet(isPresented: $showingBiddingSheet) {
            biddingSheet
        }
        .fullScreenCover(isPresented: $showingLiveStream) {
            if let auction = auction {
                LiveAuctionPageView(auctionId: auction._id)
                    .onAppear {
                        print("📱 [AuctionDetailView] FullScreenCover opened - LiveAuctionPageView appearing for auction: \(auction._id)")
                    }
            } else {
                Text("Error: Auction data not available")
                    .onAppear {
                        print("❌ [AuctionDetailView] FullScreenCover opened but auction data is nil")
                    }
            }
        }
        .onChange(of: showingLiveStream) { isShowing in
            print("📱 [AuctionDetailView] showingLiveStream changed to: \(isShowing)")
            if isShowing {
                if let auction = auction {
                    print("🎯 [AuctionDetailView] About to show WebRTC sheet for auction: \(auction._id) (\(auction.title))")
                } else {
                    print("❌ [AuctionDetailView] showingLiveStream = true but auction is nil")
                }
            }
        }
        .alert(isPresented: $showJoinedAlert) {
            Alert(
                title: Text("Joined Auction!"),
                message: Text("You've joined the auction! You'll be notified when items become available for bidding."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onDisappear {
            print("👋 [AuctionDetailView] View disappeared")
        }
    }

    private func auctionDetailContent(_ auction: LiveAuction) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Auction Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(auction.title)
                                .font(.title2)
                                .font(.system(.body, design: .default).weight(.bold))
                            Text(auction.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack {
                            Image(systemName: "eye.fill")
                                .foregroundColor(.green)
                            Text("\(auction.currentViewers)")
                                .font(.caption)
                        }
                    }

                    // Status Badge
                    HStack {
                        statusBadge(for: auction.status)
                        Spacer()
                        if auction.isLive {
                            Button(hasJoinedAuction ? "Joined ✓" : "Join Auction") {
                                print("🎯 [AuctionDetailView] User joined auction: \(auction.title)")
                                joinAuction()
                            }
                            .disabled(hasJoinedAuction)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Auction Items
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Auction Items")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVStack(spacing: 8) {
                            ForEach(items) { item in
                                AuctionItemCard(item: item) {
                                    openBiddingSheet(for: item)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No items in this auction yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                }
            }
        }
    }

    private func statusBadge(for status: AuctionStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(for: status))
                .frame(width: 8, height: 8)
            Text(status.displayName)
                .font(.caption)
                .font(.system(.body, design: .default).weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor(for: status).opacity(0.1))
        .cornerRadius(8)
    }

    private func statusColor(for status: AuctionStatus) -> Color {
        switch status {
        case .live: return .red
        case .scheduled: return .blue
        case .ended: return .gray
        case .cancelled: return .gray
        case .paused: return .orange
        }
    }

    // MARK: - Bidding Sheet View

    private var biddingSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let item = selectedItem {
                    // Item Details
                    VStack(spacing: 12) {
                        Text("Place Bid")
                            .font(.largeTitle)
                            .font(.system(.body, design: .default).weight(.bold))

                        Text(item.name)
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        VStack(spacing: 4) {
                            HStack {
                                Text("Current Bid:")
                                    .foregroundColor(.secondary)
                                Text("$\(item.formattedCurrentBid)")
                                    .font(.system(.body, design: .default).weight(.semibold))
                            }
                            HStack {
                                Text("Next Minimum Bid:")
                                    .foregroundColor(.secondary)
                                Text("$\(item.formattedNextBid)")
                                    .font(.system(.body, design: .default).weight(.semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Bid Amount Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Bid Amount")
                            .font(.headline)

                        TextField("Enter bid amount", text: $bidAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.title2)

                        if let error = bidError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()

                    Spacer()

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: placeBid) {
                            HStack {
                                if isPlacingBid {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text("Placing Bid...")
                                } else {
                                    Image(systemName: "hammer.fill")
                                    Text("Place Bid - $\(bidAmount)")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isPlacingBid ? Color.gray : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(isPlacingBid || bidAmount.isEmpty)

                        Button("Cancel") {
                            showingBiddingSheet = false
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }

    // MARK: - Join Auction and Bidding Functions

    private func joinAuction() {
        print("🎯 [AuctionDetailView] Join Auction tapped")

        // Prevent multiple joins
        guard !hasJoinedAuction else {
            print("⚠️ [AuctionDetailView] Already joined auction")
            return
        }

        // Mark as joined first
        hasJoinedAuction = true

        // For live auctions, open the live stream view immediately
        guard let auction = auction else {
            print("❌ [AuctionDetailView] No auction data available")
            return
        }

        if auction.isLive {
            print("📺 [AuctionDetailView] Opening live stream for auction: \(auction.title)")
            DispatchQueue.main.async {
                self.showingLiveStream = true
            }
        } else {
            // For non-live auctions, show joined alert
            print("🕐 [AuctionDetailView] Auction not live yet, joining auction lobby...")
            DispatchQueue.main.async {
                self.showJoinedAlert = true
            }
        }

        // Check if there are active items to bid on
        let activeItems = items.filter { $0.isActive }
        print("🎯 [AuctionDetailView] Active items count: \(activeItems.count)")

        // Note: Bidding functionality can still be accessed through item cards
        // The live stream view will also have bidding capabilities
    }

    private func openBiddingSheet(for item: AuctionItem) {
        print("🎯 [AuctionDetailView] Opening bidding sheet for: \(item.name)")
        selectedItem = item
        bidAmount = String(format: "%.2f", item.nextMinimumBid)
        bidError = nil
        showingBiddingSheet = true
    }

    private func placeBid() {
        guard let item = selectedItem,
              let auction = auction,
              let amount = Double(bidAmount) else {
            bidError = "Invalid bid amount"
            return
        }

        print("🎯 [AuctionDetailView] Placing bid of $\(amount) on \(item.name)")

        // Validate bid amount
        if amount < item.nextMinimumBid {
            bidError = "Bid must be at least $\(item.formattedNextBid)"
            return
        }

        isPlacingBid = true
        bidError = nil

        auctionService.placeBid(auctionId: auction._id, itemId: item._id, amount: amount)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isPlacingBid = false
                    if case .failure(let error) = completion {
                        print("❌ [AuctionDetailView] Bid failed: \(error)")
                        bidError = "Failed to place bid: \(error.localizedDescription)"
                    }
                },
                receiveValue: { response in
                    print("✅ [AuctionDetailView] Bid response: \(response.success ? "Success" : "Failed")")
                    if response.success {
                        showingBiddingSheet = false
                        // Refresh auction details to get updated bid
                        loadAuctionDetails()
                    } else {
                        bidError = response.message
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func loadAuctionDetails() {
        print("🔍 [AuctionDetailView] ====== STARTING loadAuctionDetails() ======")
        print("🔍 [AuctionDetailView] Auction ID: \(auctionId)")
        print("🔍 [AuctionDetailView] Setting isLoading = true...")
        isLoading = true
        errorMessage = nil
        print("🔍 [AuctionDetailView] Loading state set, calling getAuctionDetails...")

        auctionService.getAuctionDetails(auctionId: auctionId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    print("🎯 [AuctionDetailView] Received completion: \(completion)")
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        let errorDescription = error.localizedDescription
                        print("❌ [AuctionDetailView] Error: \(errorDescription)")
                        self.errorMessage = errorDescription
                    }
                },
                receiveValue: { (auctionData, itemsData) in
                    print("📦 [AuctionDetailView] Received auction data:")
                    print("🎯 [AuctionDetailView] Auction: \(auctionData.title)")
                    print("📦 [AuctionDetailView] Items count: \(itemsData.count)")

                    self.auction = auctionData
                    self.items = itemsData

                    for (index, item) in itemsData.enumerated() {
                        print("🎯 [AuctionDetailView] Item \(index + 1): \(item.name) - $\(item.currentBid ?? 0)")
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Auction Item Card
struct AuctionItemCard: View {
    let item: AuctionItem
    let onBidTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Item Image Placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .font(.system(.body, design: .default).weight(.medium))
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack {
                    Text("Current Bid:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(item.formattedCurrentBid)")
                        .font(.caption)
                        .font(.system(.body, design: .default).weight(.semibold))
                        .foregroundColor(.primary)
                }
            }

            Spacer()

            VStack(spacing: 4) {
                statusBadge(for: item.status)
                if item.isActive {
                    Button("Bid") {
                        print("🎯 [AuctionItemCard] User wants to bid on: \(item.name)")
                        onBidTap()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func statusBadge(for status: AuctionItemStatus) -> some View {
        Text(status.displayName)
            .font(.caption2)
            .font(.system(.body, design: .default).weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(for: status).opacity(0.2))
            .foregroundColor(statusColor(for: status))
            .cornerRadius(4)
    }

    private func statusColor(for status: AuctionItemStatus) -> Color {
        switch status {
        case .active: return .green
        case .pending: return .blue
        case .sold: return .gray
        case .unsold: return .orange
        }
    }
}

// MARK: - Auction Card
struct AuctionCard: View {
    let auction: LiveAuction
    let isLive: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Auction Image with Status Badge
            ZStack(alignment: .topLeading) {
                CachedImageView(
                    url: URL(string: auction.primaryImageURL ?? ""),
                    placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(ProgressView().scaleEffect(0.6))
                    },
                    failureView: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                            .overlay(
                                Image(systemName: "hammer.fill")
                                    .foregroundColor(.orange)
                                    .font(.title3)
                            )
                    }
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: 280, height: 140)
                .clipped()
                .cornerRadius(12)

                // Status Badge
                HStack {
                    Circle()
                        .fill(isLive ? Color.red : Color.blue)
                        .frame(width: 8, height: 8)
                    Text(auction.displayStatus)
                        .font(.caption2)
                        .font(.system(.body, design: .default).weight(.bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .padding(8)
            }

            // Auction Info
            VStack(alignment: .leading, spacing: 8) {
                Text(auction.title)
                    .font(.headline)
                    .font(.system(.body, design: .default).weight(.bold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Seller and Store Info
                if auction.sellerId != nil {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("by Seller")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                // Current Item and Bid Info
                if let currentItem = auction.currentItem {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Current Item:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        Text(currentItem.name)
                            .font(.subheadline)
                            .font(.system(.body, design: .default).weight(.medium))
                            .lineLimit(1)

                        HStack {
                            Text("Current Bid:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(currentItem.formattedCurrentBid)")
                                .font(.subheadline)
                                .font(.system(.body, design: .default).weight(.bold))
                                .foregroundColor(.green)

                            Spacer()

                            if currentItem.hasBids {
                                Text("\(currentItem.bidCount ?? 0) bids")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                }

                // Viewer Count
                HStack {
                    Image(systemName: "eye.fill")
                        .font(.caption)
                        .foregroundColor(isLive ? .red : .blue)
                    Text(auction.formattedViewerCount)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let itemCount = auction.itemCount, itemCount > 0 {
                        Text("\(itemCount) items")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Action Button
            Button(action: onTap) {
                HStack {
                    Image(systemName: isLive ? "hammer.fill" : "calendar")
                        .font(.subheadline)
                    Text(isLive ? "Join Auction" : "View Details")
                        .font(.subheadline)
                        .font(.system(.body, design: .default).weight(.semibold))
                    Spacer()
                    if isLive {
                        Text("LIVE")
                            .font(.caption)
                            .font(.system(.body, design: .default).weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: isLive ? [Color.red, Color.orange] : [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Auction List View (Full Screen)
struct AuctionListView: View {
    @StateObject private var auctionService = AuctionService.shared
    @State private var liveAuctions: [LiveAuction] = []
    @State private var upcomingAuctions: [LiveAuction] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("Auction Type", selection: $selectedTab) {
                    Text("Live (\(liveAuctions.count))").tag(0)
                    Text("Upcoming (\(upcomingAuctions.count))").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                if isLoading {
                    Spacer()
                    ProgressView("Loading auctions...")
                        .scaleEffect(1.2)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    ErrorView(message: error) {
                        loadAllAuctions()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            let auctions = selectedTab == 0 ? liveAuctions : upcomingAuctions

                            if auctions.isEmpty {
                                EmptyAuctionsView(isLive: selectedTab == 0)
                                    .padding(.top, 50)
                            } else {
                                ForEach(auctions) { auction in
                                    AuctionListRow(auction: auction) {
                                        // Navigate to auction detail
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        loadAllAuctions()
                    }
                }
            }
            .navigationTitle("Auctions")
            .onAppear {
                loadAllAuctions()
            }
        }
    }

    private func loadAllAuctions() {
        isLoading = true
        errorMessage = nil

        auctionService.getHomeAuctions()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        self.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { (live, upcoming) in
                    self.liveAuctions = live
                    self.upcomingAuctions = upcoming
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Auction List Row
struct AuctionListRow: View {
    let auction: LiveAuction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Auction Image
                CachedImageView(
                    url: URL(string: auction.primaryImageURL ?? ""),
                    placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(ProgressView().scaleEffect(0.6))
                    },
                    failureView: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                            .overlay(
                                Image(systemName: "hammer.fill")
                                    .foregroundColor(.orange)
                            )
                    }
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .cornerRadius(8)

                // Auction Info
                VStack(alignment: .leading, spacing: 6) {
                    // Title and Status
                    HStack {
                        Text(auction.title)
                            .font(.headline)
                            .font(.system(.body, design: .default).weight(.semibold))
                            .lineLimit(2)

                        Spacer()

                        // Status Badge
                        Text(auction.displayStatus)
                            .font(.caption)
                            .font(.system(.body, design: .default).weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(auction.isLive ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    // Current Item (if any)
                    if let currentItem = auction.currentItem {
                        Text("Current: \(currentItem.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        HStack {
                            Text("Bid: $\(currentItem.formattedCurrentBid)")
                                .font(.subheadline)
                                .font(.system(.body, design: .default).weight(.medium))
                                .foregroundColor(.green)

                            if currentItem.hasBids {
                                Text("(\(currentItem.bidCount ?? 0) bids)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }

                    // Metadata
                    HStack {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(auction.currentViewers)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let itemCount = auction.itemCount {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(itemCount) items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Supporting Views

struct EmptyAuctionsView: View {
    let isLive: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isLive ? "hammer" : "calendar")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text(isLive ? "No Live Auctions" : "No Upcoming Auctions")
                .font(.headline)
                .foregroundColor(.primary)

            Text(isLive ?
                 "All auctions have ended. Check upcoming auctions or visit again later!" :
                 "No auctions are scheduled yet. Check back soon for exciting bidding opportunities!"
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Failed to Load")
                .font(.headline)
                .foregroundColor(.primary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again", action: onRetry)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
    }
}

// MARK: - Live Stream Placeholder View
struct LiveStreamPlaceholderView: View {
    let auction: LiveAuction
    @State private var isConnecting = true
    @State private var isConnected = false
    @State private var connectionStatus = "Connecting to live stream..."

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
            // Live Stream Header
            VStack(spacing: 16) {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .fill(Color.red.opacity(0.3))
                                .scaleEffect(isConnected ? 1.5 : 1.0)
                                .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isConnected)
                        )

                    Text("LIVE")
                        .font(.title2)
                        .font(.system(.body, design: .default).weight(.bold))
                        .foregroundColor(.red)

                    Spacer()

                    Text("\(auction.currentViewers) watching")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Text(auction.title)
                    .font(.title)
                    .font(.system(.body, design: .default).weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Stream Content Area
            ZStack {
                // Stream background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        VStack(spacing: 16) {
                            if isConnecting {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))

                                Text(connectionStatus)
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.white)

                                    Text("Live Stream Connected!")
                                        .font(.title3)
                                        .font(.system(.body, design: .default).weight(.semibold))
                                        .foregroundColor(.white)

                                    Text("Auction ID: \(auction._id)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))

                                    if isConnected {
                                        Text("✅ Socket Connected")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else {
                                        Text("❌ Socket Disconnected")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    )

                // Connection status overlay
                VStack {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(isConnected ? "CONNECTED" : "CONNECTING")
                                .font(.caption2)
                                .font(.system(.body, design: .default).weight(.bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(12)

                        Spacer()
                    }
                    Spacer()
                }
                .padding(12)
            }

            // Current Item Information
            if let currentItem = auction.currentItem {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Item")
                        .font(.headline)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentItem.name)
                                .font(.subheadline)
                                .font(.system(.body, design: .default).weight(.medium))

                            HStack {
                                Text("Current Bid:")
                                    .foregroundColor(.secondary)
                                Text("$\(currentItem.formattedCurrentBid)")
                                    .font(.system(.body, design: .default).weight(.semibold))
                                    .foregroundColor(.green)
                            }
                            .font(.caption)
                        }

                        Spacer()

                        Button("Place Bid") {
                            // Bidding functionality would go here
                            print("🔨 [LiveStream] Place bid tapped for: \(currentItem.name)")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            }
            .padding()
        }
        .onAppear {
            setupLiveStream()
        }
    }

    private func setupLiveStream() {
        print("📺 [LiveStreamPlaceholder] Setting up live stream for: \(auction.title)")
        print("🆔 [LiveStreamPlaceholder] Auction ID: \(auction._id)")

        // Simulate connecting to the auction
        // In a real implementation, this would connect via SocketService
        // socketService.connectToAuction(auction._id)

        // Simulate connection process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                isConnecting = false
                isConnected = true
                connectionStatus = "Live stream ready!"
            }
        }
    }
}

// MARK: - Live Stream Player View
struct LiveStreamPlayerView: View {
    let auctionId: String
    let auctionTitle: String

    @State private var currentFrame: UIImage?
    @State private var isStreamActive = false
    @State private var isConnecting = true
    @State private var connectionStatus = "Connecting..."
    @State private var fps: Double = 0.0
    @State private var lastFrameTime: Date = Date()
    @State private var streamQuality = "4k"
    @State private var showQualityPicker = false
    @State private var isFullScreen = false

    // Mock streaming properties
    @State private var streamTimer: Timer?
    @State private var frameCount: Int = 0
    @State private var livePulse: Bool = false
    @State private var connectionPulse: Bool = false

    // Real Socket.IO connection (will be added when SocketService is included)
    // private let socketService = SocketService.shared
    @State private var cancellables = Set<AnyCancellable>()
    @State private var webSocketTask: URLSessionWebSocketTask?
    @State private var urlSession = URLSession(configuration: .default)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Live Stream Header
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isStreamActive ? Color.red : Color.gray)
                            .frame(width: 8, height: 8)
                            .opacity(isStreamActive && livePulse ? 0.6 : 1.0)
                            .animation(
                                isStreamActive ?
                                Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true) :
                                .default,
                                value: livePulse
                            )

                        Text("LIVE")
                            .font(.title2)
                            .font(.system(.body, design: .default).weight(.bold))
                            .foregroundColor(isStreamActive ? .red : .gray)
                    }

                    Text(auctionTitle)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    if isStreamActive {
                        Text("\(String(format: "%.0f", fps)) FPS")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                .padding()

                // Video Stream Area
                ZStack {
                    // Background
                    Rectangle()
                        .fill(Color.black)
                        .aspectRatio(16/9, contentMode: .fit)

                    if let frame = currentFrame {
                        // Live Video Frame
                        Image(uiImage: frame)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipped()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isFullScreen.toggle()
                                }
                            }
                    } else if isConnecting {
                        // Connecting State
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text(connectionStatus)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    } else {
                        // No Stream State
                        VStack(spacing: 12) {
                            Image(systemName: "video.slash")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)

                            Text("No stream available")
                                .font(.headline)
                                .foregroundColor(.gray)

                            Button("Reconnect") {
                                reconnectStream()
                            }
                            .foregroundColor(.blue)
                        }
                    }

                    // Quality Selector and Full Screen (top right)
                    VStack {
                        HStack {
                            Spacer()

                            // Full Screen Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isFullScreen.toggle()
                                }
                            }) {
                                Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                            }

                            // Quality Selector
                            Button(action: { showQualityPicker.toggle() }) {
                                Text(streamQuality.uppercased())
                                    .font(.caption)
                                    .font(.system(.body, design: .default).weight(.bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                            }
                            .padding(.leading, 4)
                        }
                        .padding()
                        Spacer()
                    }
                }
                .cornerRadius(12)
                .padding(.horizontal)

                // Stream Controls
                HStack(spacing: 20) {
                    Button(action: {
                        if isStreamActive {
                            disconnectStream()
                        } else {
                            connectStream()
                        }
                    }) {
                        HStack {
                            Image(systemName: isStreamActive ? "stop.circle.fill" : "play.circle.fill")
                            Text(isStreamActive ? "Disconnect" : "Connect")
                        }
                        .foregroundColor(isStreamActive ? .red : .green)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }

                    Button("Quality") {
                        showQualityPicker.toggle()
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()

                // Stream Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Stream Status:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isStreamActive ? Color.green : (isConnecting ? Color.orange : Color.red))
                                .frame(width: 6, height: 6)
                                .opacity(isStreamActive && connectionPulse ? 0.3 : 1.0)

                            Text(getStreamStatus())
                                .font(.caption)
                                .font(.system(.body, design: .default).weight(.medium))
                                .foregroundColor(isStreamActive ? .green : (isConnecting ? .orange : .red))
                        }
                    }

                    HStack {
                        Text("Quality:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(streamQuality.capitalized)
                            .font(.caption)
                            .font(.system(.body, design: .default).weight(.medium))
                    }

                    if isStreamActive {
                        HStack {
                            Text("Frame Rate:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(String(format: "%.1f", fps)) fps")
                                .font(.caption)
                                .font(.system(.body, design: .default).weight(.medium))
                        }
                    }

                    HStack {
                        Text("Auction ID:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(auctionId)
                            .font(.caption)
                            .font(.system(.body, design: .default).weight(.medium))
                            .lineLimit(1)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal)

                Spacer()
            }
        }
        .actionSheet(isPresented: $showQualityPicker) {
            ActionSheet(
                title: Text("Stream Quality"),
                message: Text("Select video quality"),
                buttons: [
                    .default(Text("Low (240p)")) { selectQuality("low") },
                    .default(Text("Medium (480p)")) { selectQuality("medium") },
                    .default(Text("High (720p)")) { selectQuality("high") },
                    .default(Text("Ultra HD (1080p)")) { selectQuality("ultra") },
                    .default(Text("4K Ultra HD (2160p)")) { selectQuality("4k") },
                    .cancel()
                ]
            )
        }
        .onAppear {
            setupRealStreamHandling()
        }
        .onDisappear {
            cleanup()
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            fullScreenVideoView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }

    // MARK: - Private Methods

    private func fullScreenVideoView() -> some View {
        ZStack {
            // Video content - fills entire screen edge to edge
            if let frame = currentFrame {
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isFullScreen = false
                        }
                    }
            } else if isConnecting {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2.0)

                    Text(connectionStatus)
                        .font(.title2)
                        .foregroundColor(.white)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("No stream available")
                        .font(.title2)
                        .foregroundColor(.gray)

                    Button("Reconnect") {
                        reconnectStream()
                    }
                    .foregroundColor(.blue)
                    .font(.title3)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
            }

            // Controls overlay
            VStack {
                // Top controls
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isFullScreen = false
                        }
                    }) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }

                    Spacer()

                    // Live indicator
                    if isStreamActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .opacity(livePulse ? 0.3 : 1.0)
                                .animation(
                                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                    value: livePulse
                                )

                            Text("LIVE")
                                .font(.title2)
                                .font(.system(.body, design: .default).weight(.bold))
                                .foregroundColor(.red)

                            Text("(\(String(format: "%.1f", fps)) FPS)")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                    }

                    Spacer()

                    // Quality button
                    Button(action: { showQualityPicker.toggle() }) {
                        Text(streamQuality.uppercased())
                            .font(.title3)
                            .font(.system(.body, design: .default).weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                }
                .padding()

                Spacer()

                // Bottom controls
                HStack(spacing: 30) {
                    Button(action: {
                        if isStreamActive {
                            disconnectStream()
                        } else {
                            connectStream()
                        }
                    }) {
                        HStack {
                            Image(systemName: isStreamActive ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title2)
                            Text(isStreamActive ? "Disconnect" : "Connect")
                                .font(.title3)
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(10)
                    }

                    Button("Exit Full Screen") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isFullScreen = false
                        }
                    }
                    .foregroundColor(.white)
                    .font(.title3)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func setupStreamHandling() {
        print("🎥 [LiveStreamPlayer] Setting up stream for auction: \(auctionId)")

        // Simulate connection process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            connectionStatus = "Connected - Starting stream..."
            isConnecting = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                startMockStream()
            }
        }
    }

    private func startMockStream() {
        connectionStatus = "Live stream active"
        isStreamActive = true
        fps = 30.0 // Simulate 30 FPS

        // Trigger pulse animations
        livePulse = true
        connectionPulse = true

        // Create a mock video frame (colored rectangle with counter)
        generateMockFrame()

        // Start timer to simulate streaming
        streamTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
            generateMockFrame()
            updateFPSOptimized()
        }
    }

    private func generateMockFrame() {
        frameCount += 1

        // Create a mock frame with changing colors and frame count
        let size = CGSize(width: 640, height: 360)
        let renderer = UIGraphicsImageRenderer(size: size)

        currentFrame = renderer.image { context in
            // Background gradient
            let colors = [UIColor.blue, UIColor.purple, UIColor.red]
            let color = colors[frameCount % colors.count]
            context.cgContext.setFillColor(color.withAlphaComponent(0.8).cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            // Add frame info text
            let text = "🎥 Live Frame #\(frameCount)\nAuction: \(auctionId)\nFPS: \(String(format: "%.1f", fps))"
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 24, weight: .bold)
            ]

            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedText.size()
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            attributedText.draw(in: textRect)
        }
    }

    // Optimized FPS calculation - update less frequently
    @State private var fpsUpdateCounter: Int = 0
    @State private var fpsAccumulator: Double = 0.0

    private func updateFPSOptimized() {
        let now = Date()
        let timeDiff = now.timeIntervalSince(lastFrameTime)

        if timeDiff > 0 {
            // Accumulate FPS measurements
            fpsAccumulator += 1.0 / timeDiff
            fpsUpdateCounter += 1

            // Update displayed FPS every 5 frames for smoother UI
            if fpsUpdateCounter >= 5 {
                fps = fpsAccumulator / Double(fpsUpdateCounter)
                fpsAccumulator = 0.0
                fpsUpdateCounter = 0
            }
        }
        lastFrameTime = now
    }

    private func selectQuality(_ quality: String) {
        print("🎛️ [LiveStreamPlayer] Quality selected: \(quality)")
        streamQuality = quality
        showQualityPicker = false
        requestStreamQuality(quality)
    }

    private func requestStreamQuality(_ quality: String) {
        print("📡 [LiveStreamPlayer] Requesting quality: \(quality) via WebSocket")
        sendQualityRequest(quality)

        connectionStatus = "Quality changed to \(quality)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if isStreamActive {
                connectionStatus = "Live stream active"
            }
        }
    }

    private func connectStream() {
        print("🔌 [DEBUG] ===== CONNECT STREAM CALLED =====")
        print("🔌 [DEBUG] Auction ID: \(auctionId)")
        print("🔌 [DEBUG] Auction Title: \(auctionTitle)")
        print("🔌 [DEBUG] Current connecting state: \(isConnecting)")
        print("🔌 [DEBUG] Current active state: \(isStreamActive)")
        print("🔌 [DEBUG] Current connection status: '\(connectionStatus)'")

        isConnecting = true
        connectionStatus = "Connecting..."

        print("🔌 [DEBUG] State updated - isConnecting: \(isConnecting)")
        print("🔌 [DEBUG] About to call setupRealStreamHandling()")

        setupRealStreamHandling()

        print("🔌 [DEBUG] setupRealStreamHandling() call completed")
        print("🔌 [DEBUG] ===== CONNECT STREAM END =====")
    }

    private func disconnectStream() {
        print("🔌❌ [DEBUG] ===== DISCONNECT STREAM CALLED =====")
        print("🔌❌ [DEBUG] Before disconnect - streamTimer: \(streamTimer != nil ? "active" : "nil")")
        print("🔌❌ [DEBUG] Before disconnect - isStreamActive: \(isStreamActive)")
        print("🔌❌ [DEBUG] Before disconnect - currentFrame: \(currentFrame != nil ? "present" : "nil")")

        streamTimer?.invalidate()
        streamTimer = nil
        isStreamActive = false
        currentFrame = nil
        connectionStatus = "Disconnected"
        frameCount = 0

        print("🔌❌ [DEBUG] After disconnect - isStreamActive: \(isStreamActive)")
        print("🔌❌ [DEBUG] After disconnect - connectionStatus: '\(connectionStatus)'")

        // Stop pulse animations
        livePulse = false
        connectionPulse = false

        print("🔌❌ [DEBUG] About to cancel WebSocket task...")

        // Disconnect WebSocket properly with enhanced cleanup
        if let task = webSocketTask {
            print("🔌❌ [DEBUG] Cancelling WebSocket task with goingAway...")
            task.cancel(with: .goingAway, reason: "User disconnect".data(using: .utf8))
            webSocketTask = nil
            print("🔌❌ [DEBUG] WebSocket task cancelled and cleared")
        } else {
            print("🔌❌ [DEBUG] No WebSocket task to cancel")
        }

        // Also ensure isConnecting is false to prevent race conditions
        isConnecting = false

        // Clear current frame to prevent memory buildup
        currentFrame = nil
        print("🔌❌ [DEBUG] Cleared current frame and connecting state")

        print("🔌❌ [DEBUG] WebSocket cleanup completed")
    }

    private func reconnectStream() {
        print("🔄 [DEBUG] ===== RECONNECT STREAM BUTTON CLICKED =====")
        print("🔄 [DEBUG] User clicked reconnect button")
        print("🔄 [DEBUG] Before disconnect - isConnecting: \(isConnecting), isStreamActive: \(isStreamActive)")

        // Prevent multiple reconnect attempts
        guard !isConnecting else {
            print("🔄 [DEBUG] ⚠️ Reconnect ignored - already connecting")
            return
        }

        disconnectStream()

        print("🔄 [DEBUG] After disconnect - isConnecting: \(isConnecting), isStreamActive: \(isStreamActive)")
        print("🔄 [DEBUG] Waiting 0.5 seconds before reconnecting to allow cleanup...")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔄 [DEBUG] 0.5 second delay completed, calling connectStream()")
            // Double check we're still not connecting from another source
            guard !self.isConnecting else {
                print("🔄 [DEBUG] ⚠️ Reconnect cancelled - connection started from elsewhere")
                return
            }
            self.connectStream()
        }
    }

    private func getStreamStatus() -> String {
        if isConnecting {
            return "Connecting"
        } else if isStreamActive {
            return "Live"
        } else {
            return "Disconnected"
        }
    }

    private func cleanup() {
        print("🧹 [LiveStreamPlayer] Cleaning up stream view")
        streamTimer?.invalidate()
        streamTimer = nil

        // Cleanup WebSocket connection
        webSocketTask?.cancel()
        webSocketTask = nil
        cancellables.removeAll()
    }

    // MARK: - Real Video Streaming Methods

    private func setupRealStreamHandling() {
        print("🌐 [DEBUG] ===== SETUP REAL STREAM HANDLING CALLED =====")
        print("🌐 [DEBUG] Auction ID: \(auctionId)")
        print("🌐 [DEBUG] About to set up WebSocket connection")

        // Connect to WebSocket
        connectionStatus = "Connecting to live stream..."
        isConnecting = true

        print("🌐 [DEBUG] Status updated to: '\(connectionStatus)'")
        print("🌐 [DEBUG] isConnecting set to: \(isConnecting)")
        print("🌐 [DEBUG] About to call connectToWebSocket()")

        connectToWebSocket()

        print("🌐 [DEBUG] connectToWebSocket() call completed")
        print("🌐 [DEBUG] ===== SETUP REAL STREAM HANDLING END =====")
    }

    // Optimized frame processing queue - reuse single background queue
    private static let frameProcessingQueue = DispatchQueue(label: "com.malloflebanon.frameProcessing", qos: .userInitiated)

    private func processLiveFrame(_ frameData: LiveFrameData) {
        // Optimized throttling - more aggressive frame dropping for performance
        let currentTime = CFAbsoluteTimeGetCurrent()

        // Skip frames if processing too fast (limit to 15fps max for better performance)
        if currentTime - lastFrameTime.timeIntervalSince1970 < 0.067 {
            return // Drop frame silently for performance
        }

        // Use static queue to avoid creating new queues
        Self.frameProcessingQueue.async {
            // Optimized base64 processing
            let base64String = frameData.imageData.hasPrefix("data:image/") ?
                String(frameData.imageData.dropFirst(23)) : frameData.imageData

            guard let imageData = Data(base64Encoded: base64String),
                  let image = UIImage(data: imageData) else {
                return // Fail silently for performance
            }

            // Batch UI updates on main thread
            DispatchQueue.main.async {
                self.updateFrameUI(image: image, frameNumber: frameData.frameNumber)
            }
        }
    }

    // Separate method for UI updates to reduce main thread blocking
    private func updateFrameUI(image: UIImage, frameNumber: Int?) {
        // Release previous frame to prevent memory buildup
        self.currentFrame = nil

        // Set new frame
        self.currentFrame = image
        self.frameCount = frameNumber ?? self.frameCount + 1

        // Activate stream only once
        if !self.isStreamActive {
            self.activateStream()
        }

        // Update FPS less frequently for performance
        self.updateFPSOptimized()
    }

    // Optimized stream activation - called only once
    private func activateStream() {
        self.connectionStatus = "Live stream active"
        self.isStreamActive = true
        self.livePulse = true
        self.connectionPulse = true
        self.setupStreamMetrics()
    }

    private func setupStreamMetrics() {
        // Start FPS calculation timer
        streamTimer?.invalidate()
        streamTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // FPS calculation happens in updateFPS()
        }
    }

    private func connectToWebSocket() {
        print("🔗 [DEBUG] ===== CONNECT TO WEBSOCKET CALLED =====")

        // CRUCIAL: Prevent multiple simultaneous connections
        if isConnecting {
            print("🔗 [DEBUG] ⚠️ Connection already in progress (isConnecting=true), skipping duplicate request")
            return
        }

        // CRUCIAL: Cancel any existing WebSocket connection first and wait
        if let existingTask = webSocketTask {
            print("🔗 [DEBUG] Cancelling existing WebSocket connection...")
            existingTask.cancel(with: .goingAway, reason: "Reconnecting".data(using: .utf8))
            webSocketTask = nil

            // Wait a moment for cleanup to complete before starting new connection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.continueWebSocketConnection()
            }
            return
        }

        // No existing connection, proceed immediately
        continueWebSocketConnection()
    }

    private func continueWebSocketConnection() {
        print("🔗 [DEBUG] ===== CONTINUE WEBSOCKET CONNECTION =====")
        print("🔗 [DEBUG] Current thread: \(Thread.current)")
        print("🔗 [DEBUG] Connection timestamp: \(Date())")

        // Set connecting state to prevent duplicates
        isConnecting = true
        print("🔗 [DEBUG] ✅ Set isConnecting = true")

        // Get base URL from APIService
        let apiBaseURL = APIService.shared.baseURLForDebugging
        print("🔗 [DEBUG] API Base URL from APIService: '\(apiBaseURL)'")

        // Remove /api from the URL since Socket.IO runs on the root path
        let baseURL = apiBaseURL.replacingOccurrences(of: "/api", with: "")
        print("🔗 [DEBUG] Modified Base URL for Socket.IO: '\(baseURL)'")
        print("🔗 [DEBUG] Base URL validation: \(baseURL.contains("http") ? "✅ Contains http" : "❌ Missing http")")

        print("🔗 [DEBUG] About to call performSocketIOHandshake with: \(baseURL)")

        // Step 1: Socket.IO handshake - get session ID
        performSocketIOHandshake(baseURL: baseURL)

        print("🔗 [DEBUG] performSocketIOHandshake call completed")
        print("🔗 [DEBUG] ===== CONTINUE WEBSOCKET CONNECTION END =====")
    }

    private func performSocketIOHandshake(baseURL: String) {
        print("🤝 [DEBUG] ===== PERFORM SOCKET.IO HANDSHAKE =====")
        print("🤝 [DEBUG] Base URL received: '\(baseURL)'")
        print("🤝 [DEBUG] Current connection status: '\(connectionStatus)'")
        print("🤝 [DEBUG] Current isConnecting state: \(isConnecting)")

        // Socket.IO handshake URL format: http://localhost:3007/socket.io/?EIO=4&transport=polling
        let fullHandshakeURL = "\(baseURL)/socket.io/?EIO=4&transport=polling"
        print("🤝 [DEBUG] Full handshake URL: '\(fullHandshakeURL)'")

        guard let handshakeURL = URL(string: fullHandshakeURL) else {
            print("❌ [DEBUG] Invalid handshake URL: '\(fullHandshakeURL)'")
            DispatchQueue.main.async {
                self.connectionStatus = "Connection failed - Invalid URL"
                self.isConnecting = false
                print("❌ [DEBUG] Set isConnecting = false due to invalid URL")
            }
            return
        }

        print("🤝 [DEBUG] ✅ Handshake URL created successfully: \(handshakeURL)")
        print("🤝 [DEBUG] URL scheme: \(handshakeURL.scheme ?? "nil")")
        print("🤝 [DEBUG] URL host: \(handshakeURL.host ?? "nil")")
        print("🤝 [DEBUG] URL port: \(handshakeURL.port ?? -1)")
        print("🤝 [DEBUG] About to perform HTTP GET request...")

        var request = URLRequest(url: handshakeURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        print("🤝 [DEBUG] Request configured:")
        print("🤝 [DEBUG]   - Method: \(request.httpMethod ?? "nil")")
        print("🤝 [DEBUG]   - Timeout: \(request.timeoutInterval)")
        print("🤝 [DEBUG]   - Headers: \(request.allHTTPHeaderFields ?? [:])")

        print("🤝 [DEBUG] Starting URLSession.shared.dataTask...")

        URLSession.shared.dataTask(with: request) { data, response, error in
            print("🤝 [DEBUG] ===== HANDSHAKE RESPONSE RECEIVED =====")
            print("🤝 [DEBUG] Response timestamp: \(Date())")
            print("🤝 [DEBUG] Response thread: \(Thread.current)")

            if let error = error {
                print("❌ [DEBUG] ===== HANDSHAKE ERROR OCCURRED =====")
                print("❌ [DEBUG] Error type: \(type(of: error))")
                print("❌ [DEBUG] Error code: \((error as NSError).code)")
                print("❌ [DEBUG] Error domain: \((error as NSError).domain)")
                print("❌ [DEBUG] Error description: \(error.localizedDescription)")
                print("❌ [DEBUG] Full error: \(error)")

                DispatchQueue.main.async {
                    print("❌ [DEBUG] Setting handshake failed status on main thread")
                    self.connectionStatus = "Handshake failed: \(error.localizedDescription)"
                    self.isConnecting = false
                    print("❌ [DEBUG] Set isConnecting = false due to handshake error")
                }
                return
            }

            print("🤝 [DEBUG] ✅ No error - checking response and data...")

            if let httpResponse = response as? HTTPURLResponse {
                print("🤝 [DEBUG] ===== HTTP RESPONSE DETAILS =====")
                print("🤝 [DEBUG] HTTP Status Code: \(httpResponse.statusCode)")
                print("🤝 [DEBUG] Status code success: \(200...299 ~= httpResponse.statusCode ? "✅ Success" : "❌ Error")")
                print("🤝 [DEBUG] HTTP Headers:")
                for (key, value) in httpResponse.allHeaderFields {
                    print("🤝 [DEBUG]   - \(key): \(value)")
                }
            } else {
                print("⚠️ [DEBUG] Response is not HTTPURLResponse: \(response?.description ?? "nil")")
            }

            print("🤝 [DEBUG] Checking data...")
            guard let data = data else {
                print("❌ [DEBUG] No data received")
                DispatchQueue.main.async {
                    self.connectionStatus = "No data received"
                    self.isConnecting = false
                    print("❌ [DEBUG] Set isConnecting = false due to no data")
                }
                return
            }

            print("🤝 [DEBUG] Data received: \(data.count) bytes")

            guard let responseString = String(data: data, encoding: .utf8) else {
                print("❌ [DEBUG] Failed to convert data to string")
                print("❌ [DEBUG] Raw data: \(data)")
                DispatchQueue.main.async {
                    self.connectionStatus = "Invalid response encoding"
                    self.isConnecting = false
                    print("❌ [DEBUG] Set isConnecting = false due to string conversion failure")
                }
                return
            }

            print("📝 [DEBUG] ===== HANDSHAKE RESPONSE CONTENT =====")
            print("📝 [DEBUG] Response: '\(responseString)'")
            print("📝 [DEBUG] Response length: \(responseString.count) characters")
            print("📝 [DEBUG] First 10 chars: '\(String(responseString.prefix(10)))'")
            print("📝 [DEBUG] Starts with '0{': \(responseString.hasPrefix("0{") ? "✅ Yes" : "❌ No")")

            // Parse Socket.IO handshake response (format: 0{"sid":"sessionId","upgrades":["websocket"],...})
            if responseString.hasPrefix("0{") {
                let jsonString = String(responseString.dropFirst(1)) // Remove the '0' prefix
                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let sessionId = json["sid"] as? String {

                    print("✅ [LiveStreamPlayer] Got session ID: \(sessionId)")

                    // Step 2: Upgrade to WebSocket
                    DispatchQueue.main.async {
                        self.upgradeToWebSocket(baseURL: baseURL, sessionId: sessionId)
                    }
                } else {
                    print("❌ [LiveStreamPlayer] Failed to parse session ID")
                    DispatchQueue.main.async {
                        self.connectionStatus = "Session parse failed"
                        self.isConnecting = false
                    }
                }
            } else {
                print("❌ [LiveStreamPlayer] Unexpected handshake format: \(responseString)")
                DispatchQueue.main.async {
                    self.connectionStatus = "Unexpected response"
                    self.isConnecting = false
                }
            }
        }.resume()
    }

    private func upgradeToWebSocket(baseURL: String, sessionId: String) {
        print("🚀 [DEBUG] ===== UPGRADE TO WEBSOCKET =====")
        print("🚀 [DEBUG] Base URL: '\(baseURL)'")
        print("🚀 [DEBUG] Session ID: '\(sessionId)'")
        print("🚀 [DEBUG] Upgrade timestamp: \(Date())")

        // Socket.IO WebSocket URL format: ws://localhost:3007/socket.io/?EIO=4&transport=websocket&sid=sessionId
        let wsURLString = baseURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")

        print("🚀 [DEBUG] WebSocket URL string: '\(wsURLString)'")

        let fullWSURL = "\(wsURLString)/socket.io/?EIO=4&transport=websocket&sid=\(sessionId)"
        print("🚀 [DEBUG] Full WebSocket URL: '\(fullWSURL)'")

        guard let wsURL = URL(string: fullWSURL) else {
            print("❌ [DEBUG] Invalid WebSocket upgrade URL: '\(fullWSURL)'")
            DispatchQueue.main.async {
                self.connectionStatus = "WebSocket URL failed"
                self.isConnecting = false
                print("❌ [DEBUG] Set isConnecting = false due to invalid WebSocket URL")
            }
            return
        }

        print("🚀 [DEBUG] ✅ WebSocket URL created successfully")
        print("🚀 [DEBUG] WS scheme: \(wsURL.scheme ?? "nil")")
        print("🚀 [DEBUG] WS host: \(wsURL.host ?? "nil")")
        print("🚀 [DEBUG] WS port: \(wsURL.port ?? -1)")

        print("🔌 [DEBUG] Creating WebSocket task...")

        // Create WebSocket task with session ID
        webSocketTask = URLSession.shared.webSocketTask(with: wsURL)

        print("🔌 [DEBUG] ✅ WebSocket task created")
        print("🔌 [DEBUG] WebSocket task state: \(webSocketTask?.state.rawValue ?? -1)")

        print("🔌 [DEBUG] Starting message listener BEFORE resume...")

        // Start listening for messages BEFORE resuming
        receiveMessage()

        print("🔌 [DEBUG] ✅ Message listener started")
        print("🔌 [DEBUG] About to resume WebSocket connection...")

        // Resume connection
        webSocketTask?.resume()

        print("🔌 [DEBUG] ✅ WebSocket resumed")
        print("🔌 [DEBUG] WebSocket state after resume: \(webSocketTask?.state.rawValue ?? -1)")

        // Send Socket.IO upgrade message with longer delay for connection stability
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🔌 [DEBUG] ===== 1.0s DELAY COMPLETE - SENDING UPGRADE PROBE =====")
            self.sendSocketIOUpgrade()
        }

        // Send initial connection and join auction with even longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🔌 [DEBUG] ===== 2.0s DELAY COMPLETE - SENDING CONNECT =====")
            self.sendSocketIOConnect()
        }

        // Join auction with additional delay to ensure connection is stable
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("🔌 [DEBUG] ===== 3.0s DELAY COMPLETE - JOINING AUCTION =====")
            self.sendJoinAuction()
        }

        print("🚀 [DEBUG] ===== UPGRADE TO WEBSOCKET END =====")
    }

    private func sendSocketIOUpgrade() {
        print("📡 [DEBUG] ===== SEND SOCKET.IO UPGRADE PROBE =====")
        print("📡 [DEBUG] WebSocket task exists: \(webSocketTask != nil ? "✅ Yes" : "❌ No")")
        print("📡 [DEBUG] WebSocket state: \(webSocketTask?.state.rawValue ?? -1)")
        print("📡 [DEBUG] Sending '2probe' message...")

        // Socket.IO upgrade message format: "2probe"
        webSocketTask?.send(.string("2probe")) { error in
            if let error = error {
                print("❌ [DEBUG] Failed to send upgrade probe:")
                print("❌ [DEBUG]   - Error: \(error)")
                print("❌ [DEBUG]   - Error code: \((error as NSError).code)")
                print("❌ [DEBUG]   - Error domain: \((error as NSError).domain)")
            } else {
                print("✅ [DEBUG] Successfully sent Socket.IO upgrade probe '2probe'")
                print("✅ [DEBUG] Waiting for '3probe' response...")
            }
        }
        print("📡 [DEBUG] ===== SEND UPGRADE PROBE COMPLETED =====")
    }

    private func sendSocketIOConnect() {
        print("🔌 [DEBUG] ===== SEND SOCKET.IO CONNECT =====")
        print("🔌 [DEBUG] WebSocket task exists: \(webSocketTask != nil ? "✅ Yes" : "❌ No")")
        print("🔌 [DEBUG] WebSocket state: \(webSocketTask?.state.rawValue ?? -1)")
        print("🔌 [DEBUG] Current connection status: '\(connectionStatus)'")
        print("🔌 [DEBUG] Current isConnecting: \(isConnecting)")
        print("🔌 [DEBUG] Sending '40' message...")

        // Socket.IO connect message format: "40" (4=ENGINE.IO message, 0=connect)
        webSocketTask?.send(.string("40")) { error in
            if let error = error {
                print("❌ [DEBUG] Failed to send Socket.IO connect:")
                print("❌ [DEBUG]   - Error: \(error)")
                print("❌ [DEBUG]   - Error code: \((error as NSError).code)")
                print("❌ [DEBUG]   - Error domain: \((error as NSError).domain)")
                DispatchQueue.main.async {
                    print("❌ [DEBUG] Setting connection failed status")
                    self.connectionStatus = "Failed to connect"
                    self.isConnecting = false
                    print("❌ [DEBUG] Set isConnecting = false due to connect send failure")
                }
            } else {
                print("✅ [DEBUG] Successfully sent Socket.IO connect '40'")
                print("✅ [DEBUG] Waiting for server acknowledgment...")
                DispatchQueue.main.async {
                    print("🔄 [DEBUG] Updating status to 'Awaiting server response...'")
                    self.connectionStatus = "Awaiting server response..."
                    print("🔄 [DEBUG] Keeping isConnecting = true until server confirmation")
                    // Keep isConnecting = true until we receive "auction_joined" confirmation

                    // Add timeout to prevent infinite waiting
                    DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                        if self.isConnecting {
                            print("⏰ [DEBUG] Connection timeout - forcing stream activation")
                            self.connectionStatus = "Connected (timeout fallback)"
                            self.isConnecting = false
                            self.isStreamActive = true
                            print("✅ [DEBUG] Fallback activation - isConnecting: false, isStreamActive: true")
                        }
                    }
                }
            }
        }
        print("🔌 [DEBUG] ===== SEND CONNECT COMPLETED =====")
    }

    private func receiveMessage() {
        webSocketTask?.receive { result in
            switch result {
            case .success(let message):
                self.handleWebSocketMessage(message)
                self.receiveMessage() // Continue listening

            case .failure(let error):
                print("❌ [DEBUG] WebSocket error occurred: \(error.localizedDescription)")
                print("❌ [DEBUG] Error code: \(error._code)")
                print("❌ [DEBUG] Error domain: \(error._domain)")
                print("❌ [DEBUG] Full error: \(error)")

                DispatchQueue.main.async {
                    self.isConnecting = false

                    // Check if this is a cancellation error (code -999) - DO NOT retry
                    if error._code == -999 {
                        print("🔄 [DEBUG] WebSocket was cancelled (expected) - no retry needed")
                        self.connectionStatus = "Disconnected"
                        return
                    }

                    self.connectionStatus = "Connection lost"

                    // Check if this is a "Socket is not connected" error (code 57)
                    if error._code == 57 {
                        print("🔄 [DEBUG] Socket disconnection detected - will retry connection...")
                        // Attempt reconnection after 3 seconds for socket disconnection
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            print("🔄 [DEBUG] Retrying WebSocket connection after socket error...")
                            // Only retry if we're not already connecting
                            guard !self.isConnecting else {
                                print("🔄 [DEBUG] ⚠️ Retry cancelled - already connecting")
                                return
                            }
                            self.connectToWebSocket()
                        }
                    } else {
                        print("🔄 [DEBUG] General WebSocket error - will retry after longer delay...")
                        // Attempt reconnection after 5 seconds for other errors
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            print("🔄 [DEBUG] Retrying WebSocket connection after general error...")
                            // Only retry if we're not already connecting
                            guard !self.isConnecting else {
                                print("🔄 [DEBUG] ⚠️ Retry cancelled - already connecting")
                                return
                            }
                            self.connectToWebSocket()
                        }
                    }
                }
            }
        }
    }

    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            // Reduce logging for performance - only log significant messages
            if text.contains("video_frame") || text.contains("live_frame") {
                parseSocketMessage(text)
            } else if text.count < 100 {
                parseSocketMessage(text)
            } else {
                // Skip verbose non-video messages for performance
                return
            }

        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseSocketMessage(text)
            }

        @unknown default:
            break // Handle silently for performance
        }
    }

    private func parseSocketMessage(_ text: String) {
        print("📥 [DEBUG] Received WebSocket message: '\(text)'")

        // Handle Socket.IO protocol messages
        if text == "3probe" {
            // Response to our probe - send upgrade complete
            print("🔄 [DEBUG] Received probe response, sending upgrade complete...")
            webSocketTask?.send(.string("5")) { _ in
                print("✅ [DEBUG] Sent upgrade complete")
            }
            return
        }

        // Handle Socket.IO connection acknowledgment
        if text == "40" {
            print("🔌 [DEBUG] ===== SOCKET.IO CONNECTION CONFIRMED =====")
            DispatchQueue.main.async {
                self.connectionStatus = "Socket connected"
                print("✅ [DEBUG] Socket.IO connection established successfully")
            }

            // Send auction join request after successful connection
            print("🏠 [DEBUG] Sending joinAuction request...")
            let joinAuctionMessage = "42[\"joinAuction\",{\"auctionId\":\"\(auctionId)\"}]"
            print("🏠 [DEBUG] Join message: \(joinAuctionMessage)")
            webSocketTask?.send(.string(joinAuctionMessage)) { error in
                if let error = error {
                    print("❌ [DEBUG] Failed to send joinAuction: \(error)")
                    DispatchQueue.main.async {
                        self.connectionStatus = "Failed to join auction"
                        self.isConnecting = false
                    }
                } else {
                    print("✅ [DEBUG] Successfully sent joinAuction request")
                    DispatchQueue.main.async {
                        self.connectionStatus = "Joining auction..."
                    }
                }
            }
            return
        }

        // Socket.IO message format: Engine.IO packet type + Socket.IO packet type + data
        // Example: "42["live_frame",{...}]" = 4 (Engine.IO message) + 2 (Socket.IO event) + ["live_frame",data]
        if text.hasPrefix("42[") {
            // Extract JSON array from Socket.IO event message
            let jsonString = String(text.dropFirst(2)) // Remove "42" prefix
            guard let jsonData = jsonString.data(using: .utf8),
                  let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [Any],
                  jsonArray.count >= 2,
                  let event = jsonArray[0] as? String else {
                print("❌ [LiveStreamPlayer] Failed to parse Socket.IO event: \(text)")
                return
            }

            print("🎯 [LiveStreamPlayer] Socket.IO Event: \(event)")

            switch event {
            case "live_frame", "video_frame":
                if let eventData = jsonArray[1] as? [String: Any] {
                    print("📹 [LiveStreamPlayer] Frame data keys: \(eventData.keys.sorted())")

                    do {
                        let frameDataJson = try JSONSerialization.data(withJSONObject: eventData)
                        let frame = try JSONDecoder().decode(LiveFrameData.self, from: frameDataJson)
                        print("✅ [LiveStreamPlayer] Frame decoded successfully: \(frame.auctionId)")

                        DispatchQueue.main.async {
                            self.processLiveFrame(frame)
                        }
                    } catch {
                        print("❌ [LiveStreamPlayer] Failed to decode frame: \(error)")
                        print("❌ [LiveStreamPlayer] Frame data: \(eventData)")

                        // Try to process the frame manually if JSON decoding fails
                        if let auctionId = eventData["auctionId"] as? String,
                           let imageData = eventData["imageData"] as? String {
                            print("🔄 [LiveStreamPlayer] Attempting manual frame processing...")
                            let manualFrame = LiveFrameData(
                                auctionId: auctionId,
                                imageData: imageData,
                                quality: eventData["quality"] as? String,
                                resolution: eventData["resolution"] as? String,
                                timestamp: eventData["timestamp"] as? Double,
                                frameNumber: eventData["frameNumber"] as? Int
                            )
                            DispatchQueue.main.async {
                                self.processLiveFrame(manualFrame)
                            }
                        }
                    }
                } else {
                    print("❌ [LiveStreamPlayer] Invalid frame data structure")
                }

            case "auction_joined":
                DispatchQueue.main.async {
                    print("🎯 [DEBUG] ===== AUCTION JOINED CONFIRMED =====")
                    self.connectionStatus = "Live"
                    self.isConnecting = false
                    self.isStreamActive = true
                    print("✅ [DEBUG] Stream is now ACTIVE - isConnecting: false, isStreamActive: true")
                }
            case "auctionJoined": // Handle camelCase variant
                DispatchQueue.main.async {
                    print("🎯 [DEBUG] ===== AUCTION JOINED (camelCase) CONFIRMED =====")
                    self.connectionStatus = "Live"
                    self.isConnecting = false
                    self.isStreamActive = true
                    print("✅ [DEBUG] Stream is now ACTIVE - isConnecting: false, isStreamActive: true")
                }
            case "error":
                if let errorData = jsonArray[1] as? [String: Any],
                   let errorMessage = errorData["message"] as? String {
                    print("❌ [DEBUG] Server error: \(errorMessage)")
                    DispatchQueue.main.async {
                        self.connectionStatus = "Error: \(errorMessage)"
                        self.isConnecting = false
                    }
                }

            case "stream_started":
                DispatchQueue.main.async {
                    self.connectionStatus = "Stream started"
                }

            default:
                print("🔍 [LiveStreamPlayer] Unhandled event: \(event)")
                break
            }
        } else if text.hasPrefix("40") {
            // Socket.IO connect acknowledgment
            print("✅ [LiveStreamPlayer] Socket.IO connected")
        } else if text.hasPrefix("2") {
            // Engine.IO ping/pong
            if text == "2" {
                // Ping - respond with pong
                webSocketTask?.send(.string("3")) { _ in }
            }
        } else {
            print("🔍 [LiveStreamPlayer] Other message: \(text)")
        }
    }

    private func sendJoinAuction() {
        print("📤 [DEBUG] ===== SEND JOIN AUCTION =====")
        print("📤 [DEBUG] Auction ID: \(auctionId)")
        print("📤 [DEBUG] WebSocket task status: \(webSocketTask != nil ? "present" : "nil")")

        // Socket.IO event format: 42["event_name", event_data]
        let eventData = [
            "auctionId": auctionId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        let eventArray: [Any] = ["join_auction", eventData]

        print("📤 [DEBUG] Event data: \(eventData)")

        guard let jsonData = try? JSONSerialization.data(withJSONObject: eventArray),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ [DEBUG] Failed to encode join_auction event")
            return
        }

        let socketIOMessage = "42\(jsonString)"

        print("📤 [DEBUG] Socket.IO message: \(socketIOMessage)")
        print("📤 [DEBUG] About to send via WebSocket...")

        webSocketTask?.send(.string(socketIOMessage)) { error in
            if let error = error {
                print("❌ [DEBUG] Failed to send join_auction: \(error.localizedDescription)")
                print("❌ [DEBUG] Send error details: \(error)")
            } else {
                print("✅ [DEBUG] Successfully sent join_auction for: \(self.auctionId)")
                print("📤 [DEBUG] Message sent: \(socketIOMessage)")
            }
        }

        print("📤 [DEBUG] ===== SEND JOIN AUCTION END =====")
    }

    private func sendQualityRequest(_ quality: String) {
        // Socket.IO event format: 42["event_name", event_data]
        let eventData = [
            "auctionId": auctionId,
            "quality": quality,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        let eventArray: [Any] = ["request_quality_stream", eventData]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: eventArray),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ [LiveStreamPlayer] Failed to encode quality request")
            return
        }

        let socketIOMessage = "42\(jsonString)"

        webSocketTask?.send(.string(socketIOMessage)) { error in
            if let error = error {
                print("❌ [LiveStreamPlayer] Failed to send quality request: \(error)")
            } else {
                print("✅ [LiveStreamPlayer] Quality request sent: \(quality)")
                print("📤 [LiveStreamPlayer] Quality message: \(socketIOMessage)")
            }
        }
    }
}

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

    // UI State - Overlays
    // Items and chat overlay state removed
    @State private var showingBiddingSheet = false
    @State private var showingItemDetails = false
    @State private var selectedDetailItem: AuctionItem?
    // showingControls removed - controls always visible

    // Real-time Updates
    @State private var viewerCount = 0
    @State private var connectionStatus = "Connecting..."
    @State private var isMinimized = false

    var body: some View {
        ZStack {
            // Full-screen background
            Color.black
                .ignoresSafeArea(.all)

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let auction = auction {
                fullScreenAuctionView(auction)
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
            if let _ = auction, let _ = currentItem {
                Text("Bidding sheet would open here")
                    .padding()
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
            .ignoresSafeArea(.all)

            // Floating overlays (foreground layer) - always visible
            floatingControlsOverlay(auction)

            // Items and chat overlays removed as requested
        }
    }

    // MARK: - Floating Controls Overlay
    private func floatingControlsOverlay(_ auction: LiveAuction) -> some View {
        VStack(spacing: 0) {
            // Top controls
            HStack {
                topControlsBar(auction)
            }
            .padding(.horizontal)
            .padding(.top)

            Spacer()

            // Bottom auction display - pushed to absolute bottom
            VStack(spacing: 0) {
                bottomControlsBar(auction)
            }
        }
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
                }

                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.caption)
                    Text("\(viewerCount)")
                        .font(.caption)
                        .fontWeight(.medium)

                    // Down arrow button for minimize
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMinimized.toggle()
                        }
                        print("📱 Down arrow tapped - isMinimized: \(isMinimized)")
                    }) {
                        Image(systemName: isMinimized ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                            )
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func bottomControlsBar(_ auction: LiveAuction) -> some View {
        VStack(spacing: 16) {
            // Auction Item Display
            auctionItemDisplay(auction)

            // Current item info (if available)
            if let item = currentItem {
                currentItemFloatingBanner(item)
            }

            // Action buttons removed as requested (items, chat, bid)
        }
    }

    // MARK: - Auction Item Display
    private func auctionItemDisplay(_ auction: LiveAuction) -> some View {
        VStack(spacing: 0) {
            // Main item info row - Two sections layout
            HStack(spacing: 0) {
                // LEFT SECTION - Image + Title + Shipping (at beginning of screen)
                HStack(alignment: .top, spacing: 12) {
                    // Smaller item image - real product image
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "shippingbox.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                        )

                    // Item details column
                    VStack(alignment: .leading, spacing: 2) {
                        // Item name at top aligned with image
                        Text("XS-XSMALL PULL #191")
                            .font(Font.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        // Open-box below name
                        Text("Open-box")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))

                        // Shipping on same line as flag
                        HStack(spacing: 4) {
                            Text("🇱🇧")
                            Text("US$38.24 Int Shipping + Taxes")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // RIGHT SECTION - Price and timer (not overlapping)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("US$2")
                        .font(Font.title3.weight(.bold))
                        .foregroundColor(.white)

                    HStack(spacing: 2) {
                        Text("💀")
                        Text("00:01")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Bottom buttons row
            HStack(spacing: 12) {
                // Custom button - with white border
                Button(action: {
                    print("🎛️ Custom button tapped")
                }) {
                    Text("Custom")
                        .font(Font.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white, lineWidth: 1)
                        )
                }

                // Bid button - orange background
                Button(action: {
                    print("💰 Bid button tapped")
                }) {
                    HStack {
                        Text("Bid: US$3")
                        Image(systemName: "chevron.right.2")
                    }
                    .font(Font.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .padding(.top, 8)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 0)
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
            let updatedItem = items[index]
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

// MARK: - Supporting Views for Live Auction

struct AuctionItemRowViewLive: View {
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