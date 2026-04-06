import Foundation
import Combine
import AVFoundation
import UIKit

// MARK: - WebRTC Service for iOS Live Streaming (Live Frame Mode)
// Simplified version without WebRTC dependencies for live image streaming

// Connection state for live frame mode
enum ConnectionState {
    case closed, connecting, connected, disconnected
}

// Stream statistics
struct StreamStats {
    var framesReceived: Int = 0
    var bytesReceived: Int = 0
    var currentFPS: Double = 0.0
    var averageLatency: Double = 0.0
}

class WebRTCService: NSObject, ObservableObject {
    static let shared = WebRTCService()

    // Published properties for SwiftUI binding
    @Published var connectionState: ConnectionState = .closed
    @Published var isConnected = false
    @Published var isStreaming = false
    @Published var streamStats = StreamStats()
    @Published var currentLiveFrame: UIImage? = nil

    // Live frame processing
    private var cancellables = Set<AnyCancellable>()
    private var lastFrameTime = Date()

    override init() {
        super.init()
        print("🎥 [WebRTC] WebRTCService initialized in live frame mode")
    }

    // MARK: - Live Frame Handling (Main functionality for live streaming)

    func handleLiveFrame(_ frameData: LiveFrameData) {
        print("🖼️ [WebRTC] ===== PROCESSING LIVE FRAME =====")
        print("🖼️ [WebRTC] Auction ID: \(frameData.auctionId)")
        print("🖼️ [WebRTC] Frame quality: \(frameData.quality ?? "unknown")")
        print("🖼️ [WebRTC] Frame resolution: \(frameData.resolution ?? "unknown")")
        print("🖼️ [WebRTC] Data size: \(frameData.imageData.count) characters")

        // Convert base64 image data to UIImage
        guard let imageData = extractImageData(from: frameData.imageData),
              let uiImage = UIImage(data: imageData) else {
            print("❌ [WebRTC] Failed to decode live frame image data")
            return
        }

        print("✅ [WebRTC] Live frame decoded successfully!")
        print("✅ [WebRTC] Image size: \(uiImage.size)")
        print("✅ [WebRTC] Image scale: \(uiImage.scale)")

        // Update connection state and publish the frame
        DispatchQueue.main.async {
            let wasConnected = self.connectionState == .connected

            self.connectionState = .connected
            self.isConnected = true
            self.isStreaming = true
            self.currentLiveFrame = uiImage

            // Update statistics
            self.streamStats.framesReceived += 1
            self.streamStats.bytesReceived += frameData.imageData.count

            // Calculate FPS
            let now = Date()
            let timeDiff = now.timeIntervalSince(self.lastFrameTime)
            if timeDiff > 0 {
                self.streamStats.currentFPS = 1.0 / timeDiff
            }
            self.lastFrameTime = now

            if !wasConnected {
                print("🟢 [WebRTC] Live stream connection established via image frames")
            }

            print("📺 [WebRTC] Live frame published to UI (frame #\(self.streamStats.framesReceived))")
        }
    }

    // MARK: - Helper Methods

    private func extractImageData(from base64String: String) -> Data? {
        // Handle data URL format (data:image/jpeg;base64,...)
        var cleanBase64 = base64String

        // Remove data URL prefix if present
        if base64String.hasPrefix("data:image") {
            if let range = base64String.range(of: "base64,") {
                cleanBase64 = String(base64String[range.upperBound...])
            }
        }

        // Remove any whitespace/newlines
        cleanBase64 = cleanBase64.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)

        return Data(base64Encoded: cleanBase64)
    }

    // MARK: - Stream Control (Simplified)

    func disconnect() {
        print("🔴 [WebRTC] Disconnecting live stream...")
        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.isConnected = false
            self.isStreaming = false
            self.currentLiveFrame = nil
        }
    }

    func reconnect() {
        print("🔄 [WebRTC] Reconnecting live stream...")
        DispatchQueue.main.async {
            self.connectionState = .connecting
        }
    }

    // MARK: - Statistics

    func resetStats() {
        DispatchQueue.main.async {
            self.streamStats = StreamStats()
        }
    }
}

// MARK: - Note: LiveFrameData model is imported from SocketService.swift