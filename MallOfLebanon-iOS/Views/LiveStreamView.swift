import SwiftUI
import Combine
import UIKit

// MARK: - Live Stream View
// Displays real-time video stream from auction sellers (matching frontend SimpleStreamPlayer)

struct LiveStreamView: View {
    let auctionId: String

    @StateObject private var socketService = SocketService.shared
    @State private var currentFrame: UIImage?
    @State private var isStreamActive = false
    @State private var streamQuality = "auto"
    @State private var lastFrameTime: Date = Date()
    @State private var connectionStatus = "Connecting..."
    @State private var frameCount = 0
    @State private var showQualityPicker = false
    @State private var cancellables = Set<AnyCancellable>()

    // Stream statistics
    @State private var fps: Double = 0
    @State private var resolution = "Unknown"
    @State private var dataReceived = 0

    private let qualityOptions = ["auto", "high", "medium", "low"]

    var body: some View {
        VStack(spacing: 0) {
            // Stream Display Area
            ZStack {
                // Background
                Rectangle()
                    .fill(Color.black)
                    .aspectRatio(16/9, contentMode: .fit)

                // Stream Content
                if let frame = currentFrame {
                    Image(uiImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipped()
                        .transition(.opacity.animation(.easeInOut(duration: 0.1)))
                } else {
                    // Placeholder/Loading State
                    VStack(spacing: 16) {
                        if isStreamActive {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Loading stream...")
                                .foregroundColor(.white)
                                .font(.headline)
                        } else {
                            Image(systemName: "video.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("Stream not active")
                                .foregroundColor(.gray)
                                .font(.headline)
                            Text(connectionStatus)
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }

                // Stream Controls Overlay
                VStack {
                    HStack {
                        // Connection Status Badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(socketService.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(socketService.isConnected ? "LIVE" : "OFFLINE")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)

                        Spacer()

                        // Quality Selector Button
                        Button(action: {
                            showQualityPicker.toggle()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "gear")
                                Text(streamQuality.uppercased())
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }

                    Spacer()

                    // Bottom Stream Info
                    if socketService.isConnected && currentFrame != nil {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(String(format: "%.1f", fps)) FPS")
                                    .font(.caption)
                                Text(resolution)
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)

                            Spacer()

                            Text("📺 Frames: \(frameCount)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(12)
            }
            .background(Color.black)
            .cornerRadius(12)

            // Quality Picker (if visible)
            if showQualityPicker {
                qualityPickerView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            setupStreamHandling()
        }
        .onDisappear {
            cleanup()
        }
    }

    private var qualityPickerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Stream Quality")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button("Done") {
                    showQualityPicker = false
                }
                .foregroundColor(.blue)
            }
            .padding()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(qualityOptions, id: \.self) { quality in
                    Button(action: {
                        selectQuality(quality)
                    }) {
                        HStack {
                            Image(systemName: streamQuality == quality ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(streamQuality == quality ? .blue : .gray)
                            Text(quality.capitalized)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16, corners: [.topLeft, .topRight])
    }

    // MARK: - Private Methods

    private func setupStreamHandling() {
        print("🎥 [LiveStreamView] Setting up stream for auction: \(auctionId)")

        // Connect to auction
        socketService.connectToAuction(auctionId)

        // Handle stream frames
        socketService.onStreamFrame { frame in
            DispatchQueue.main.async {
                self.handleStreamFrame(frame)
            }
        }
        .store(in: &cancellables)

        // Handle connection changes
        socketService.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { connected in
                self.isStreamActive = connected
                if connected {
                    self.connectionStatus = "Connected"
                    // Request initial quality
                    self.requestStreamQuality(self.streamQuality)
                } else {
                    self.connectionStatus = "Disconnected"
                    self.currentFrame = nil
                }
            }
            .store(in: &cancellables)
    }

    private func handleStreamFrame(_ frame: StreamFrame) {
        // Only process frames for our auction
        guard frame.auctionId == auctionId else { return }

        // Convert base64 to UIImage
        if let imageData = Data(base64Encoded: frame.imageData),
           let image = UIImage(data: imageData) {

            // Update frame
            self.currentFrame = image

            // Update statistics
            self.frameCount += 1
            self.resolution = frame.resolution

            // Calculate FPS
            let now = Date()
            let timeDiff = now.timeIntervalSince(lastFrameTime)
            if timeDiff > 0 {
                self.fps = 1.0 / timeDiff
            }
            self.lastFrameTime = now

            print("🎥 [LiveStreamView] Frame received: \(frame.quality) @ \(frame.resolution)")
        } else {
            print("❌ [LiveStreamView] Failed to decode frame data")
        }
    }

    private func selectQuality(_ quality: String) {
        print("🎛️ [LiveStreamView] Quality selected: \(quality)")
        streamQuality = quality
        showQualityPicker = false
        requestStreamQuality(quality)
    }

    private func requestStreamQuality(_ quality: String) {
        print("📡 [LiveStreamView] Requesting quality: \(quality)")
        socketService.requestStreamQuality(quality, auctionId: auctionId)
    }

    private func cleanup() {
        print("🧹 [LiveStreamView] Cleaning up stream view")
        cancellables.removeAll()
        // Note: Don't disconnect socket as it might be used by other views
    }
}

// MARK: - Supporting Views and Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview
struct LiveStreamView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LiveStreamView(auctionId: "preview-auction-id")
                .previewDisplayName("iPhone 13")
                .previewDevice("iPhone 13")

            LiveStreamView(auctionId: "preview-auction-id")
                .previewDisplayName("iPad")
                .previewDevice("iPad Pro (11-inch) (3rd generation)")
        }
    }
}