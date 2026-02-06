import SwiftUI
import Combine

// MARK: - Auction Chat View
// Real-time chat for auction participants (matching frontend AuctionChat)

struct AuctionChatView: View {
    let auctionId: String

    @StateObject private var socketService = SocketService.shared
    @State private var messages: [ChatMessage] = []
    @State private var newMessageText = ""
    @State private var isConnected = false
    @State private var cancellables = Set<AnyCancellable>()

    // UI State
    @State private var showingEmojiPicker = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Chat Header
            chatHeaderView

            // Messages List
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            ChatMessageRow(message: message)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _ in
                    // Auto-scroll to bottom when new message arrives
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if let lastMessage = messages.last {
                            scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Message Input
            messageInputView
        }
        .background(Color(.systemBackground))
        .onAppear {
            setupChat()
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - View Components

    private var chatHeaderView: some View {
        HStack {
            Image(systemName: "message")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Live Chat")
                    .font(.headline)
                    .fontWeight(.semibold)

                HStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("\(messages.count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private var messageInputView: some View {
        HStack(spacing: 12) {
            // Emoji Button
            Button(action: {
                showingEmojiPicker.toggle()
            }) {
                Image(systemName: "face.smiling")
                    .font(.title3)
                    .foregroundColor(.blue)
            }

            // Text Input
            HStack {
                TextField("Type a message...", text: $newMessageText)
                    .focused($isTextFieldFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        sendMessage()
                    }

                if !newMessageText.isEmpty {
                    Button(action: {
                        newMessageText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(20)

            // Send Button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(newMessageText.isEmpty ? .gray : .blue)
            }
            .disabled(newMessageText.isEmpty || !isConnected)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    // MARK: - Private Methods

    private func setupChat() {
        print("💬 [AuctionChatView] Setting up chat for auction: \(auctionId)")

        // Connect to auction chat
        socketService.connectToAuction(auctionId)

        // Listen for connection changes
        socketService.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { connected in
                self.isConnected = connected
            }
            .store(in: &cancellables)

        // Listen for chat messages
        socketService.onChatMessage { message in
            DispatchQueue.main.async {
                if message.auctionId == self.auctionId {
                    self.addMessage(message)
                }
            }
        }
        .store(in: &cancellables)

        // Listen for bid updates to show as system messages
        socketService.onBidUpdate { bidUpdate in
            DispatchQueue.main.async {
                if bidUpdate.auctionId == self.auctionId {
                    self.addBidSystemMessage(bidUpdate)
                }
            }
        }
        .store(in: &cancellables)

        // Add welcome message
        addSystemMessage("Welcome to the live auction chat! 👋")
    }

    private func sendMessage() {
        let trimmedText = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, isConnected else { return }

        print("📤 [AuctionChatView] Sending message: \(trimmedText)")

        socketService.sendChatMessage(trimmedText, auctionId: auctionId)

        // Clear input
        newMessageText = ""

        // Dismiss keyboard
        isTextFieldFocused = false
    }

    private func addMessage(_ message: ChatMessage) {
        // Prevent duplicate messages
        guard !messages.contains(where: { $0.id == message.id }) else { return }

        messages.append(message)
        print("💬 [AuctionChatView] Added message: \(message.message)")

        // Limit message history to last 100 messages
        if messages.count > 100 {
            messages.removeFirst()
        }
    }

    private func addSystemMessage(_ text: String) {
        let systemMessage = ChatMessage(
            id: UUID().uuidString,
            auctionId: auctionId,
            userId: "system",
            username: "System",
            message: text,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            type: "system"
        )
        addMessage(systemMessage)
    }

    private func addBidSystemMessage(_ bidUpdate: BidUpdateData) {
        let bidMessage = ChatMessage(
            id: UUID().uuidString,
            auctionId: auctionId,
            userId: "system",
            username: "System",
            message: "💰 \(bidUpdate.bidderName) bid $\(String(format: "%.0f", bidUpdate.bidAmount))",
            timestamp: bidUpdate.timestamp,
            type: "bid_notification"
        )
        addMessage(bidMessage)
    }

    private func cleanup() {
        print("🧹 [AuctionChatView] Cleaning up chat view")
        cancellables.removeAll()
    }
}

// MARK: - Chat Message Row

struct ChatMessageRow: View {
    let message: ChatMessage

    private var isSystemMessage: Bool {
        message.type == "system" || message.type == "bid_notification" || message.userId == "system"
    }

    private var messageTime: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: message.timestamp) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return timeFormatter.string(from: date)
        }
        return ""
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isSystemMessage {
                systemMessageView
            } else {
                userMessageView
            }
        }
        .id(message.id)
    }

    private var systemMessageView: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Text(message.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)

                Text(messageTime)
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }
            Spacer()
        }
    }

    private var userMessageView: some View {
        HStack(alignment: .top, spacing: 8) {
            // User Avatar
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(message.username.prefix(1).uppercased()))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )

            // Message Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(message.username)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(messageTime)
                        .font(.caption2)
                        .foregroundColor(.tertiary)

                    Spacer()
                }

                Text(message.message)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(16, corners: [.topRight, .bottomLeft, .bottomRight])
            }

            Spacer(minLength: 60) // Leave space on the right
        }
    }
}

// MARK: - Supporting Models

struct ChatMessage: Codable, Identifiable {
    let id: String
    let auctionId: String?
    let userId: String
    let username: String
    let message: String
    let timestamp: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case id, auctionId, userId, username, message, timestamp, type
    }
}

// MARK: - Preview

struct AuctionChatView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AuctionChatView(auctionId: "sample-auction")
                .previewDisplayName("iPhone Chat")

            AuctionChatView(auctionId: "sample-auction")
                .previewDisplayName("iPad Chat")
                .previewDevice("iPad Pro (11-inch) (3rd generation)")
        }
    }
}