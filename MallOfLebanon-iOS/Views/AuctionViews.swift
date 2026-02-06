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
        .sheet(isPresented: $showingLiveStream) {
            if let auction = auction {
                NavigationView {
                    LiveStreamPlayerView(auctionId: auction._id, auctionTitle: auction.title)
                        .navigationTitle("Live Auction")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Close") {
                                    showingLiveStream = false
                                }
                            }
                        }
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
                            .opacity(isStreamActive && livePulse ? 0.3 : 1.0)
                            .animation(
                                isStreamActive ?
                                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
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
                        Text("\(String(format: "%.1f", fps)) FPS")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(connectionPulse ? 0.3 : 0.1))
                            .cornerRadius(4)
                            .animation(
                                Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: connectionPulse
                            )
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
                        .foregroundColor(isStreamActive ? .red : .green)
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
            updateFPS()
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

    private func updateFPS() {
        let now = Date()
        let timeDiff = now.timeIntervalSince(lastFrameTime)
        if timeDiff > 0 {
            fps = 1.0 / timeDiff
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
        isConnecting = true
        connectionStatus = "Connecting..."
        setupRealStreamHandling()
    }

    private func disconnectStream() {
        streamTimer?.invalidate()
        streamTimer = nil
        isStreamActive = false
        currentFrame = nil
        connectionStatus = "Disconnected"
        frameCount = 0

        // Stop pulse animations
        livePulse = false
        connectionPulse = false

        // Disconnect WebSocket
        webSocketTask?.cancel()
        webSocketTask = nil
    }

    private func reconnectStream() {
        disconnectStream()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            connectStream()
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
        print("🔌 [LiveStreamPlayer] Setting up direct WebSocket connection for auction: \(auctionId)")

        // Connect to WebSocket
        connectionStatus = "Connecting to live stream..."
        isConnecting = true

        connectToWebSocket()
    }

    private func processLiveFrame(_ frameData: LiveFrameData) {
        print("🎬 [LiveStreamPlayer] Processing live frame for auction: \(frameData.auctionId)")

        // Throttle frame processing to avoid overwhelming the main thread
        let currentTime = Date().timeIntervalSince1970

        // Skip frames if we're processing too fast (limit to ~20fps for smoother performance)
        if currentTime - lastFrameTime.timeIntervalSince1970 < 0.05 {
            print("⚡ [LiveStreamPlayer] Dropping frame for performance")
            return
        }

        // Move heavy image processing to background queue
        DispatchQueue.global(qos: .userInitiated).async {
            // Handle base64 data URL format from frontend
            let base64String = frameData.imageData.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
            print("📸 [LiveStreamPlayer] Base64 data length: \(base64String.count)")

            guard let imageData = Data(base64Encoded: base64String) else {
                print("❌ [LiveStreamPlayer] Failed to decode base64 data")
                return
            }

            guard let image = UIImage(data: imageData) else {
                print("❌ [LiveStreamPlayer] Failed to create UIImage from data")
                return
            }

            print("✅ [LiveStreamPlayer] Successfully created UIImage: \(image.size)")

            // Update UI on main thread
            DispatchQueue.main.async {
                // Update frame and streaming status
                self.currentFrame = image
                self.frameCount = frameData.frameNumber ?? self.frameCount + 1

                // Start streaming if this is the first frame
                if !self.isStreamActive {
                    self.connectionStatus = "Live stream active"
                    self.isStreamActive = true
                    self.livePulse = true
                    self.connectionPulse = true
                    self.setupStreamMetrics()
                    print("🟢 [LiveStreamPlayer] Stream activated!")
                }

                // Update FPS calculation
                self.updateFPS()
                print("📹 [LiveStreamPlayer] Frame processed: \(self.frameCount), FPS: \(String(format: "%.1f", self.fps))")

                print("✅ [LiveStreamPlayer] Processed frame #\(self.frameCount) - FPS: \(String(format: "%.1f", self.fps))")
            }
        }
    }

    private func setupStreamMetrics() {
        // Start FPS calculation timer
        streamTimer?.invalidate()
        streamTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // FPS calculation happens in updateFPS()
        }
    }

    private func connectToWebSocket() {
        // Get base URL from APIService
        let apiBaseURL = APIService.shared.baseURLForDebugging
        // Remove /api from the URL since Socket.IO runs on the root path
        let baseURL = apiBaseURL.replacingOccurrences(of: "/api", with: "")

        print("🔗 [LiveStreamPlayer] Starting Socket.IO connection to: \(baseURL)")

        // Step 1: Socket.IO handshake - get session ID
        performSocketIOHandshake(baseURL: baseURL)
    }

    private func performSocketIOHandshake(baseURL: String) {
        // Socket.IO handshake URL format: http://localhost:3007/socket.io/?EIO=4&transport=polling
        guard let handshakeURL = URL(string: "\(baseURL)/socket.io/?EIO=4&transport=polling") else {
            print("❌ [LiveStreamPlayer] Invalid handshake URL")
            connectionStatus = "Connection failed"
            isConnecting = false
            return
        }

        print("🤝 [LiveStreamPlayer] Performing Socket.IO handshake: \(handshakeURL)")

        var request = URLRequest(url: handshakeURL)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [LiveStreamPlayer] Handshake error: \(error)")
                DispatchQueue.main.async {
                    self.connectionStatus = "Handshake failed"
                    self.isConnecting = false
                }
                return
            }

            guard let data = data,
                  let responseString = String(data: data, encoding: .utf8) else {
                print("❌ [LiveStreamPlayer] Invalid handshake response")
                DispatchQueue.main.async {
                    self.connectionStatus = "Invalid response"
                    self.isConnecting = false
                }
                return
            }

            print("📝 [LiveStreamPlayer] Handshake response: \(responseString)")

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
        // Socket.IO WebSocket URL format: ws://localhost:3007/socket.io/?EIO=4&transport=websocket&sid=sessionId
        let wsURLString = baseURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")

        guard let wsURL = URL(string: "\(wsURLString)/socket.io/?EIO=4&transport=websocket&sid=\(sessionId)") else {
            print("❌ [LiveStreamPlayer] Invalid WebSocket upgrade URL")
            connectionStatus = "WebSocket URL failed"
            isConnecting = false
            return
        }

        print("🚀 [LiveStreamPlayer] Upgrading to WebSocket: \(wsURL)")

        // Create WebSocket task with session ID
        webSocketTask = URLSession.shared.webSocketTask(with: wsURL)

        // Start listening for messages
        receiveMessage()

        // Resume connection
        webSocketTask?.resume()

        // Send Socket.IO upgrade message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendSocketIOUpgrade()
        }

        // Send initial connection and join auction after a bit more delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sendSocketIOConnect()
            self.sendJoinAuction()
        }
    }

    private func sendSocketIOUpgrade() {
        // Socket.IO upgrade message format: "2probe"
        webSocketTask?.send(.string("2probe")) { error in
            if let error = error {
                print("❌ [LiveStreamPlayer] Failed to send upgrade probe: \(error)")
            } else {
                print("📡 [LiveStreamPlayer] Sent Socket.IO upgrade probe")
            }
        }
    }

    private func sendSocketIOConnect() {
        // Socket.IO connect message format: "40" (4=ENGINE.IO message, 0=connect)
        webSocketTask?.send(.string("40")) { error in
            if let error = error {
                print("❌ [LiveStreamPlayer] Failed to send connect: \(error)")
            } else {
                print("🔌 [LiveStreamPlayer] Sent Socket.IO connect")
                DispatchQueue.main.async {
                    self.connectionStatus = "Connected to stream"
                    self.isConnecting = false
                }
            }
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { result in
            switch result {
            case .success(let message):
                self.handleWebSocketMessage(message)
                self.receiveMessage() // Continue listening

            case .failure(let error):
                print("❌ [LiveStreamPlayer] WebSocket error: \(error)")
                DispatchQueue.main.async {
                    self.connectionStatus = "Connection lost"
                    self.isConnecting = false

                    // Attempt reconnection after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.connectToWebSocket()
                    }
                }
            }
        }
    }

    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            print("📨 [LiveStreamPlayer] Received: \(text.prefix(200))...")
            parseSocketMessage(text)

        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseSocketMessage(text)
            }

        @unknown default:
            print("❓ [LiveStreamPlayer] Unknown message type")
        }
    }

    private func parseSocketMessage(_ text: String) {
        print("📨 [LiveStreamPlayer] Raw message: \(text.prefix(100))...")

        // Handle Socket.IO protocol messages
        if text == "3probe" {
            // Response to our probe - send upgrade complete
            webSocketTask?.send(.string("5")) { error in
                if let error = error {
                    print("❌ [LiveStreamPlayer] Failed to send upgrade complete: \(error)")
                } else {
                    print("✅ [LiveStreamPlayer] Sent upgrade complete")
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
                    self.connectionStatus = "Connected to auction"
                    self.isConnecting = false
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
        // Socket.IO event format: 42["event_name", event_data]
        let eventData = [
            "auctionId": auctionId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        let eventArray: [Any] = ["join_auction", eventData]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: eventArray),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ [LiveStreamPlayer] Failed to encode join_auction event")
            return
        }

        let socketIOMessage = "42\(jsonString)"

        webSocketTask?.send(.string(socketIOMessage)) { error in
            if let error = error {
                print("❌ [LiveStreamPlayer] Failed to send join_auction: \(error)")
            } else {
                print("✅ [LiveStreamPlayer] Sent join_auction for: \(self.auctionId)")
                print("📤 [LiveStreamPlayer] Message: \(socketIOMessage)")
            }
        }
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