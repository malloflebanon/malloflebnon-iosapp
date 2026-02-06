import SwiftUI
import Combine

// MARK: - Auction Timer View
// Displays countdown timers for auctions and items (matching frontend LiveAuctionTimer)

struct AuctionTimerView: View {
    let auction: LiveAuction
    let currentItem: AuctionItem?

    @StateObject private var socketService = SocketService.shared
    @State private var timeRemaining: TimeInterval = 0
    @State private var timerState: TimerState = .stopped
    @State private var cancellables = Set<AnyCancellable>()

    // Timer tracking
    @State private var updateTimer: Timer?
    @State private var endTime: Date?
    @State private var startTime: Date?

    enum TimerState {
        case stopped
        case running
        case paused
        case finished
    }

    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progressPercentage: Double {
        guard let startTime = startTime,
              let endTime = endTime,
              startTime < endTime else { return 0 }

        let totalDuration = endTime.timeIntervalSince(startTime)
        let elapsed = Date().timeIntervalSince(startTime)
        return min(max(elapsed / totalDuration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 12) {
            if let item = currentItem, item.isActive {
                activeItemTimerView
            } else {
                noActiveItemView
            }
        }
        .onAppear {
            setupTimer()
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - View Components

    private var activeItemTimerView: some View {
        VStack(spacing: 16) {
            // Timer Display
            VStack(spacing: 8) {
                Text("Current Item Timer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 4) {
                    Image(systemName: timerIcon)
                        .foregroundColor(timerColor)
                        .font(.title2)

                    Text(formattedTime)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(timerColor)
                }

                Text(timerStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Progress Bar
            if timerState == .running {
                VStack(spacing: 6) {
                    ProgressView(value: progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: timerColor))
                        .frame(height: 8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)

                    HStack {
                        Text("Started")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Ends")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Item Info
            if let item = currentItem {
                itemInfoView(item)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: timerColor.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(timerColor.opacity(0.5), lineWidth: 2)
        )
    }

    private func itemInfoView(_ item: AuctionItem) -> some View {
        VStack(spacing: 8) {
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Current Bid: $\(String(format: "%.0f", item.currentBid ?? item.startingPrice))")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Bids: \(item.bidCount ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    statusBadge(item.status)
                }
            }
        }
    }

    private var noActiveItemView: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer.square")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("No Active Timer")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Waiting for next auction item to start...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var timerIcon: String {
        switch timerState {
        case .running:
            return timeRemaining <= 30 ? "timer.circle" : "play.circle.fill"
        case .paused:
            return "pause.circle"
        case .finished:
            return "checkmark.circle.fill"
        case .stopped:
            return "timer"
        }
    }

    private var timerColor: Color {
        switch timerState {
        case .running:
            return timeRemaining <= 30 ? .red : (timeRemaining <= 60 ? .orange : .green)
        case .paused:
            return .orange
        case .finished:
            return .blue
        case .stopped:
            return .gray
        }
    }

    private var timerStatusText: String {
        switch timerState {
        case .running:
            return timeRemaining <= 30 ? "⚠️ Closing Soon!" : "🔴 Live Bidding"
        case .paused:
            return "⏸️ Paused"
        case .finished:
            return "✅ Item Closed"
        case .stopped:
            return "⏹️ Not Started"
        }
    }

    private func statusBadge(_ status: AuctionItemStatus) -> some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.2))
            .foregroundColor(statusColor(status))
            .cornerRadius(6)
    }

    private func statusColor(_ status: AuctionItemStatus) -> Color {
        switch status {
        case .active: return .green
        case .pending: return .blue
        case .sold: return .purple
        case .unsold: return .gray
        }
    }

    // MARK: - Private Methods

    private func setupTimer() {
        print("⏱️ [AuctionTimerView] Setting up timer for auction: \(auction._id)")

        // Listen for timer events from socket
        socketService.onTimerEvent { timerEvent in
            DispatchQueue.main.async {
                self.handleTimerEvent(timerEvent)
            }
        }
        .store(in: &cancellables)

        // Start update timer
        startUpdateTimer()

        // Initialize with current item if active
        if let item = currentItem, item.isActive {
            calculateInitialTimer(for: item)
        }
    }

    private func handleTimerEvent(_ event: TimerEvent) {
        guard event.auctionId == auction._id else { return }

        print("⏱️ [AuctionTimerView] Timer event: \(event.action)")

        switch event.action {
        case "start":
            if let startTimeString = event.startTime,
               let endTimeString = event.endTime,
               let start = ISO8601DateFormatter().date(from: startTimeString),
               let end = ISO8601DateFormatter().date(from: endTimeString) {

                self.startTime = start
                self.endTime = end
                self.timerState = .running

                updateTimeRemaining()
                print("⏱️ [AuctionTimerView] Timer started: \(start) -> \(end)")
            }

        case "pause":
            self.timerState = .paused
            print("⏱️ [AuctionTimerView] Timer paused")

        case "resume":
            self.timerState = .running
            print("⏱️ [AuctionTimerView] Timer resumed")

        case "end":
            self.timerState = .finished
            self.timeRemaining = 0
            print("⏱️ [AuctionTimerView] Timer ended")

        default:
            print("❓ [AuctionTimerView] Unknown timer action: \(event.action)")
        }
    }

    private func calculateInitialTimer(for item: AuctionItem) {
        guard let endTimeString = item.itemEndTime,
              let endDate = ISO8601DateFormatter().date(from: endTimeString) else {
            print("⚠️ [AuctionTimerView] No valid end time for item")
            return
        }

        let now = Date()
        if endDate > now {
            self.timeRemaining = endDate.timeIntervalSince(now)
            self.endTime = endDate
            self.timerState = .running
            print("⏱️ [AuctionTimerView] Initial timer: \(timeRemaining) seconds remaining")
        } else {
            self.timeRemaining = 0
            self.timerState = .finished
            print("⏱️ [AuctionTimerView] Item already ended")
        }
    }

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timerState == .running {
                updateTimeRemaining()
            }
        }
    }

    private func updateTimeRemaining() {
        guard let endTime = endTime else { return }

        let now = Date()
        let remaining = endTime.timeIntervalSince(now)

        if remaining <= 0 {
            self.timeRemaining = 0
            self.timerState = .finished
            print("⏱️ [AuctionTimerView] Timer finished")
        } else {
            self.timeRemaining = remaining
        }
    }

    private func cleanup() {
        print("🧹 [AuctionTimerView] Cleaning up timer")
        updateTimer?.invalidate()
        updateTimer = nil
        cancellables.removeAll()
    }
}

// MARK: - Compact Timer View (for inline display)

struct CompactTimerView: View {
    let timeRemaining: TimeInterval
    let isActive: Bool

    private var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var timerColor: Color {
        if !isActive { return .gray }
        return timeRemaining <= 30 ? .red : (timeRemaining <= 60 ? .orange : .green)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isActive ? "timer" : "timer.square")
                .font(.caption)
                .foregroundColor(timerColor)

            Text(formattedTime)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(timerColor)

            if !isActive {
                Text("(ended)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(timerColor.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

struct AuctionTimerView_Previews: PreviewProvider {
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
            description: "Beautiful vintage watch",
            images: [],
            startingPrice: 5000,
            currentBid: 7500,
            bidIncrement: 1000,
            estimatedDuration: 300,
            itemEndTime: ISO8601DateFormatter().string(from: Date().addingTimeInterval(180)),
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

        Group {
            AuctionTimerView(auction: sampleAuction, currentItem: sampleItem)
                .previewDisplayName("Active Timer")

            AuctionTimerView(auction: sampleAuction, currentItem: nil)
                .previewDisplayName("No Active Item")

            CompactTimerView(timeRemaining: 125, isActive: true)
                .previewDisplayName("Compact Timer")
        }
        .padding()
    }
}