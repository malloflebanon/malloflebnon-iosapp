import SwiftUI
import Combine

// MARK: - Enhanced Bidding Interface
// Advanced bidding UI with quick increments, real-time updates, and validation
// Matches the frontend BiddingInterface component

struct EnhancedBiddingView: View {
    let auction: LiveAuction
    let item: AuctionItem

    @StateObject private var auctionService = AuctionService.shared
    @StateObject private var socketService = SocketService.shared
    @Environment(\.presentationMode) var presentationMode

    // Bidding State
    @State private var bidAmount: String = ""
    @State private var isPlacingBid = false
    @State private var bidError: String?
    @State private var bidSuccess: String?
    @State private var showBidConfirmation = false

    // Auto-bidding
    @State private var isAutoBidEnabled = false
    @State private var maxAutoBid: String = ""
    @State private var autoBidIncrement: Double = 1000

    // Real-time updates
    @State private var currentBidAmount: Double
    @State private var cancellables = Set<AnyCancellable>()

    // Wallet info
    @State private var walletBalance: Double = 0
    @State private var availableBalance: Double = 0

    // Timer for clearing messages
    @State private var messageTimer: Timer?

    init(auction: LiveAuction, item: AuctionItem) {
        self.auction = auction
        self.item = item
        self._currentBidAmount = State(initialValue: item.currentBid ?? item.startingPrice)
    }

    var minimumBid: Double {
        return (currentBidAmount == 0 ? item.startingPrice : currentBidAmount) + item.bidIncrement
    }

    var quickIncrements: [Double] {
        return [
            item.bidIncrement,
            item.bidIncrement * 2,
            item.bidIncrement * 5,
            item.bidIncrement * 10
        ]
    }

    var formattedMinimumBid: String {
        return String(format: "%.0f", minimumBid)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with Item Info
                    itemInfoSection

                    // Current Bid Status
                    currentBidSection

                    // Wallet Balance
                    walletSection

                    // Bidding Input
                    biddingInputSection

                    // Quick Increment Buttons
                    quickIncrementsSection

                    // Auto-Bidding (if enabled)
                    if isAutoBidEnabled {
                        autoBiddingSection
                    }

                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("Place Bid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupBidding()
            loadWalletInfo()
        }
        .onDisappear {
            cleanup()
        }
        .alert(isPresented: $showBidConfirmation) {
            bidConfirmationAlert
        }
    }

    // MARK: - View Sections

    private var itemInfoSection: some View {
        VStack(spacing: 12) {
            // Item Image
            if let imageUrl = item.primaryImageURL, !imageUrl.isEmpty {
                CachedImageView(
                    url: URL(string: imageUrl),
                    placeholder: { ProgressView() },
                    failureView: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 120)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                )
                .aspectRatio(contentMode: .fit)
                .frame(height: 120)
                .cornerRadius(12)
            }

            Text(item.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            if !item.description.isEmpty {
                Text(item.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var currentBidSection: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Current Bid")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(String(format: "%.0f", currentBidAmount))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            VStack(spacing: 4) {
                Text("Minimum Bid")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(formattedMinimumBid)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }

            VStack(spacing: 4) {
                Text("Increment")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(String(format: "%.0f", item.bidIncrement))")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }

    private var walletSection: some View {
        HStack {
            Image(systemName: "creditcard")
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Available Balance")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(String(format: "%.0f", availableBalance))")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            Spacer()

            if availableBalance < minimumBid {
                Text("Insufficient Balance")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var biddingInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Bid Amount")
                .font(.headline)

            HStack {
                Text("$")
                    .font(.title)
                    .foregroundColor(.secondary)

                TextField("Enter amount", text: $bidAmount)
                    .font(.title)
                    .keyboardType(.numberPad)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: bidAmount) { newValue in
                        // Clear previous messages when user types
                        clearMessages()
                    }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Error/Success Messages
            if let error = bidError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if let success = bidSuccess {
                Label(success, systemImage: "checkmark.circle")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
    }

    private var quickIncrementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Bid")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(quickIncrements, id: \.self) { increment in
                    Button(action: {
                        let quickBidAmount = minimumBid + increment - item.bidIncrement
                        bidAmount = String(format: "%.0f", quickBidAmount)
                    }) {
                        VStack(spacing: 4) {
                            Text("+$\(String(format: "%.0f", increment))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("$\(String(format: "%.0f", minimumBid + increment - item.bidIncrement))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var autoBiddingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Auto-Bidding")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $isAutoBidEnabled)
                    .labelsHidden()
            }

            if isAutoBidEnabled {
                VStack(spacing: 8) {
                    HStack {
                        Text("Maximum Auto-Bid: $")
                        TextField("Max amount", text: $maxAutoBid)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    Text("The system will automatically bid up to your maximum when outbid.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Main Bid Button
            Button(action: handlePlaceBid) {
                HStack {
                    if isPlacingBid {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Placing Bid...")
                    } else {
                        Image(systemName: "hammer.fill")
                        Text("Place Bid - $\(bidAmount.isEmpty ? formattedMinimumBid : bidAmount)")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isPlacingBid || !isValidBid ? Color.gray : Color.blue)
                .cornerRadius(12)
            }
            .disabled(isPlacingBid || !isValidBid)

            // Auto-Bid Toggle
            Button(action: {
                isAutoBidEnabled.toggle()
            }) {
                HStack {
                    Image(systemName: isAutoBidEnabled ? "checkmark.circle.fill" : "circle")
                    Text("Enable Auto-Bidding")
                }
                .foregroundColor(.blue)
            }
        }
    }

    // MARK: - Computed Properties

    private var isValidBid: Bool {
        guard let amount = Double(bidAmount) else { return false }
        return amount >= minimumBid && amount <= availableBalance
    }

    private var bidConfirmationAlert: Alert {
        Alert(
            title: Text("Confirm Bid"),
            message: Text("Place bid of $\(bidAmount) on \(item.name)?"),
            primaryButton: .default(Text("Confirm")) {
                confirmBid()
            },
            secondaryButton: .cancel()
        )
    }

    // MARK: - Private Methods

    private func setupBidding() {
        // Set initial bid amount to minimum
        bidAmount = formattedMinimumBid

        // Listen for bid updates
        socketService.onBidUpdate { [self] bidUpdate in
            DispatchQueue.main.async {
                if bidUpdate.auctionId == auction._id && bidUpdate.itemId == item._id {
                    self.currentBidAmount = bidUpdate.bidAmount
                    // Update minimum bid
                    let newMinimum = self.minimumBid
                    if self.bidAmount.isEmpty || Double(self.bidAmount) ?? 0 < newMinimum {
                        self.bidAmount = String(format: "%.0f", newMinimum)
                    }
                }
            }
        }
        .store(in: &cancellables)

        // Listen for outbid notifications
        socketService.onOutbid { [self] outbidData in
            DispatchQueue.main.async {
                if outbidData.auctionId == auction._id && outbidData.itemId == item._id {
                    self.bidError = "You've been outbid! New highest bid: $\(String(format: "%.0f", outbidData.newHighestBid))"
                    self.clearMessagesAfterDelay()
                }
            }
        }
        .store(in: &cancellables)
    }

    private func loadWalletInfo() {
        auctionService.getAuctionWallet()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ [EnhancedBiddingView] Failed to load wallet: \(error)")
                    }
                },
                receiveValue: { walletResponse in
                    if walletResponse.success {
                        self.walletBalance = walletResponse.wallet.balance
                        self.availableBalance = walletResponse.wallet.availableBalance
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func handlePlaceBid() {
        guard let amount = Double(bidAmount) else {
            bidError = "Please enter a valid bid amount"
            clearMessagesAfterDelay()
            return
        }

        if amount < minimumBid {
            bidError = "Bid must be at least $\(formattedMinimumBid)"
            clearMessagesAfterDelay()
            return
        }

        if amount > availableBalance {
            bidError = "Insufficient balance. Available: $\(String(format: "%.0f", availableBalance))"
            clearMessagesAfterDelay()
            return
        }

        showBidConfirmation = true
    }

    private func confirmBid() {
        guard let amount = Double(bidAmount) else { return }

        isPlacingBid = true
        bidError = nil
        bidSuccess = nil

        auctionService.placeBid(auctionId: auction._id, itemId: item._id, amount: amount)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [self] completion in
                    self.isPlacingBid = false

                    if case .failure(let error) = completion {
                        self.bidError = error.localizedDescription
                        self.clearMessagesAfterDelay()
                    }
                },
                receiveValue: { [self] response in
                    if response.success {
                        self.bidSuccess = "Bid placed successfully!"

                        // Update wallet balance if provided
                        if let walletInfo = response.wallet {
                            self.availableBalance = walletInfo.newAvailableBalance
                        }

                        // Auto-dismiss after success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    } else {
                        self.bidError = response.message
                    }
                    self.clearMessagesAfterDelay()
                }
            )
            .store(in: &cancellables)
    }

    private func clearMessages() {
        bidError = nil
        bidSuccess = nil
        messageTimer?.invalidate()
    }

    private func clearMessagesAfterDelay() {
        messageTimer?.invalidate()
        messageTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            bidError = nil
            bidSuccess = nil
        }
    }

    private func cleanup() {
        cancellables.removeAll()
        messageTimer?.invalidate()
    }
}

// MARK: - Extensions for Auction Service

extension AuctionService {
    func getAuctionWallet() -> AnyPublisher<AuctionWalletResponse, APIError> {
        return apiService.performRequest(
            endpoint: "/auction/user/wallet",
            method: .GET,
            responseType: AuctionWalletResponse.self
        )
    }
}

// MARK: - Preview
struct EnhancedBiddingView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleAuction = LiveAuction(
            _id: "sample-auction",
            title: "Sample Auction",
            description: "Test auction",
            sellerId: "seller1",
            storeId: nil,
            status: .live,
            currentViewers: 25,
            scheduledStartTime: nil,
            actualStartTime: nil,
            currency: "USD",
            streamUrl: nil,
            streamPlatform: nil,
            currentItem: nil,
            currentBid: nil,
            itemCount: 5,
            region: "lebanon",
            thumbnailImage: nil,
            createdAt: nil
        )

        let sampleItem = AuctionItem(
            _id: "sample-item",
            auctionId: "sample-auction",
            name: "Vintage Watch",
            description: "Beautiful vintage watch from the 1950s",
            images: [],
            startingPrice: 5000,
            currentBid: 7500,
            bidIncrement: 1000,
            estimatedDuration: 300,
            itemEndTime: nil,
            status: .active,
            winnerId: nil,
            winningBid: nil,
            bidCount: 12,
            category: "Accessories",
            condition: "Excellent",
            weight: nil,
            dimensions: nil,
            auctionOrder: 1
        )

        EnhancedBiddingView(auction: sampleAuction, item: sampleItem)
    }
}