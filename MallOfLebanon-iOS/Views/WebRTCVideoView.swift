import SwiftUI
import WebRTC
import Combine

// MARK: - WebRTC Video Player View for iOS

struct WebRTCVideoView: View {
    let auctionId: String
    let isSellerMode: Bool
    @Binding var isJoined: Bool
    let onJoin: () -> Void

    // WebRTC Service
    @StateObject private var webRTCService = WebRTCService.shared

    // UI State
    @State private var showingControls = true
    @State private var isLocalVideoMuted = false
    @State private var isLocalAudioMuted = false
    @State private var selectedQuality = "hd"
    @State private var showQualityMenu = false

    var body: some View {
        ZStack {
            if !isJoined {
                // Join Screen
                joinScreen
            } else {
                // Video streaming interface
                videoStreamingInterface
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
        .background(Color.black)
        .onAppear {
            print("🎬 [WebRTCVideoView] ========== VIEW APPEARED ==========")
            print("🎬 [WebRTCVideoView] Auction ID: \(auctionId)")
            print("🎬 [WebRTCVideoView] Current isJoined: \(isJoined)")
            print("🎬 [WebRTCVideoView] Seller mode: \(isSellerMode)")
            if isJoined {
                print("🎬 [WebRTCVideoView] Starting WebRTC due to onAppear with isJoined=true")
                startWebRTC()
            } else {
                print("🎬 [WebRTCVideoView] Not starting WebRTC (isJoined=false)")
            }
            setupAutomaticDiagnostic()
        }
        .onChange(of: isJoined) { newJoinedState in
            print("🔄 [WebRTCVideoView] ========== isJoined CHANGED ==========")
            print("🔄 [WebRTCVideoView] isJoined changed from ? to \(newJoinedState)")
            print("🔄 [WebRTCVideoView] Auction: \(auctionId)")
            print("🔄 [WebRTCVideoView] Seller mode: \(isSellerMode)")
            print("🔄 [WebRTCVideoView] Current WebRTC state: \(webRTCService.connectionState)")

            if newJoinedState {
                print("✅ [WebRTCVideoView] Starting WebRTC due to isJoined change...")
                print("✅ [WebRTCVideoView] About to call startWebRTC()...")
                startWebRTC()
                print("✅ [WebRTCVideoView] startWebRTC() call completed")
            } else {
                print("❌ [WebRTCVideoView] Stopping WebRTC due to isJoined change...")
                webRTCService.stopWebRTC()
            }

            print("🔄 [WebRTCVideoView] ========== isJoined CHANGE COMPLETE ==========")
        }
    }

    // MARK: - Join Screen

    private var joinScreen: some View {
        VStack(spacing: 20) {
            // Video placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    VStack(spacing: 16) {
                        // Video icon removed as requested

                        VStack(spacing: 8) {
                            Text("Ready to Stream")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Text("Auction ID: \(auctionId)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))

                            Text(isSellerMode ? "Seller Mode" : "Viewer Mode")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                )

            Button(action: {
                print("🎬 [WebRTCVideoView] Join button pressed")
                onJoin()
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Join Stream")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding()
    }

    // MARK: - Video Streaming Interface

    private var videoStreamingInterface: some View {
        ZStack {
            // Remote video with custom sizing (19:20:10:80)
            remoteVideoView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all)
                .clipped()

            // Local video preview (small overlay)
            VStack {
                HStack {
                    Spacer()
                    localVideoPreview
                        .frame(width: 120, height: 90)
                        .cornerRadius(12)
                        .shadow(radius: 8)
                        .padding()
                }
                Spacer()
            }

            // Video controls overlay removed

            // Seller Info and Viewer Controls Header
            VStack {
                HStack {
                    // Seller Info Header (Left) - Inline implementation
                    sellerInfoHeaderInline
                        .padding(.leading, 20)
                        .padding(.top, 32)

                    Spacer()

                    // Right-side controls removed - handled in parent view
                }
                Spacer()
            }

            // Quality menu overlay removed
        }
        .background(Color.black)
        .ignoresSafeArea(.all)
        .clipped()
    }

    // MARK: - Remote Video View

    private var remoteVideoView: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea(.all)

                // WebRTC Remote Video Renderer with custom sizing (19:20:10:80)
                WebRTCVideoRenderer(videoTrack: webRTCService.remoteVideoTrack, isLocal: false)
                    .frame(
                        width: geometry.size.width - 20 - 80,  // Subtract leading(20) and trailing(80)
                        height: geometry.size.height - 19 - 10  // Subtract top(19) and bottom(10)
                    )
                    .position(
                        x: 20 + (geometry.size.width - 20 - 80) / 2,  // Center in available width
                        y: 19 + (geometry.size.height - 19 - 10) / 2   // Center in available height
                    )
                    .background(Color.black)

                // Live Frame Fallback with custom sizing (19:20:10:80)
                if let liveFrame = webRTCService.currentLiveFrame {
                    Image(uiImage: liveFrame)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: geometry.size.width - 20 - 80,  // Custom width
                            height: geometry.size.height - 19 - 10  // Custom height
                        )
                        .position(
                            x: 20 + (geometry.size.width - 20 - 80) / 2,  // Custom positioning
                            y: 19 + (geometry.size.height - 19 - 10) / 2
                        )
                        .clipped()
                        .background(Color.black)
                        .overlay(
                            VStack {
                                Spacer()
                                HStack {
                                    Text("Live Stream")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.8))
                                        .cornerRadius(4)
                                    Spacer()
                                }
                                .padding()
                            }
                        )
                }

                // Connection loader
                if webRTCService.currentLiveFrame == nil && !webRTCService.isConnected {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2
                        )
                } else if webRTCService.currentLiveFrame == nil && webRTCService.connectionState == .failed {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.red.opacity(0.7))

                        VStack(spacing: 8) {
                            Text("Connection Failed")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Unable to connect to the stream. Tap to retry.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }

                        Button("Retry Connection") {
                            // Retry connection
                            webRTCService.startWebRTC(auctionId: auctionId, isSellerMode: isSellerMode)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
                }
            }
        }
        .ignoresSafeArea(.all)
    }

    // MARK: - Local Video Preview

    private var localVideoPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)

            if webRTCService.isStreaming {
                WebRTCVideoRenderer(videoTrack: nil, isLocal: true)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

        }
    }

    // MARK: - Video Controls

    private var videoControlsOverlay: some View {
        // All video controls removed as requested (mic, video, camera, settings)
        EmptyView()
    }

    // MARK: - Quality Menu

    private var qualityMenuOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stream Quality")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(streamQualities, id: \.key) { quality in
                Button(action: {
                    selectedQuality = quality.key
                    showQualityMenu = false
                    updateStreamQuality(quality.key)
                }) {
                    HStack {
                        Text("\(quality.value) (\(quality.key.uppercased()))")
                            .foregroundColor(.white)
                            .fontWeight(selectedQuality == quality.key ? .bold : .medium)

                        Spacer()

                        if selectedQuality == quality.key {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(selectedQuality == quality.key ? Color.blue.opacity(0.3) : Color.clear)
                )
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .frame(maxWidth: 250)
        .position(x: 200, y: 150)
    }

    // MARK: - Stream Stats

    private var streamStatsView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text("FPS")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text("\(webRTCService.streamStats.fps) fps")
                    .font(.caption)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading) {
                Text("Bitrate")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text("\(webRTCService.streamStats.bitrate / 1000) kbps")
                    .font(.caption)
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }

    // MARK: - Debug Status Overlay

    private var debugStatusOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            // WebRTC Connection Status
            HStack(spacing: 8) {
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(webRTCService.connectionState == .connected ? .green : .orange)

                Text("WebRTC: \(webRTCService.connectionState.rawValue)")
                    .font(.caption2)
                    .foregroundColor(.white)
            }

            // Live Frame Status
            HStack(spacing: 8) {
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(webRTCService.currentLiveFrame != nil ? .blue : .gray)

                Text("Live Frame: \(webRTCService.currentLiveFrame != nil ? "Active" : "None")")
                    .font(.caption2)
                    .foregroundColor(.white)
            }

            // Streaming Status (seller only)
            if isSellerMode {
                HStack(spacing: 8) {
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(webRTCService.isStreaming ? .red : .gray)

                    Text("Stream: \(webRTCService.isStreaming ? "Active" : "Inactive")")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }

            // Auto-start Status
            HStack(spacing: 8) {
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(isJoined ? .green : .red)

                Text("Auto-Start: \(isJoined ? "Triggered" : "Waiting")")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
        .padding()
    }

    // MARK: - Actions

    private func startWebRTC() {
        print("🎬 [WebRTCVideoView] Starting WebRTC for auction: \(auctionId)")
        print("🎬 [WebRTCVideoView] Is seller mode: \(isSellerMode)")
        print("🎬 [WebRTCVideoView] WebRTC service current state: \(webRTCService.connectionState)")

        webRTCService.startWebRTC(auctionId: auctionId, isSellerMode: isSellerMode)

        print("🎬 [WebRTCVideoView] WebRTC service started, new state: \(webRTCService.connectionState)")
    }

    private func setupAutomaticDiagnostic() {
        print("🩺 [DIAGNOSTIC] Setting up automatic diagnostic system")

        // Monitor for joined state that should trigger WebRTC
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            if isJoined && webRTCService.connectionState == .closed {
                print("🚨 [DIAGNOSTIC] ISSUE DETECTED: isJoined=true but WebRTC not started")
                print("🚨 [DIAGNOSTIC] Applying automatic fix...")

                DispatchQueue.main.async {
                    WebRTCService.shared.startWebRTC(auctionId: auctionId, isSellerMode: isSellerMode)
                    print("🚨 [DIAGNOSTIC] Emergency WebRTC startup completed")
                }
            }
        }
    }

    private func toggleMute() {
        webRTCService.toggleMute()
        isLocalAudioMuted.toggle()
    }

    private func toggleVideo() {
        webRTCService.toggleVideo()
        isLocalVideoMuted.toggle()
    }

    private func switchCamera() {
        webRTCService.switchCamera()
    }

    private func updateStreamQuality(_ quality: String) {
        print("🎬 [WebRTCVideoView] Updating stream quality to: \(quality)")

        // Send quality update to socket service
        SocketService.shared.requestStreamQuality(quality, auctionId: auctionId)

        // Update local stream quality if seller
        if isSellerMode {
            webRTCService.updateStreamQuality(quality)
        }
    }

    // MARK: - Seller Info Header (Inline)

    private var sellerInfoHeaderInline: some View {
        HStack(spacing: 8) {
            // Seller Profile Image and Name Section
            HStack(spacing: 8) {
                // Profile Image
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    )
                    .shadow(radius: 2)

                // Seller Info Stacked Vertically
                VStack(alignment: .leading, spacing: 2) {
                    // Seller Name (top row)
                    HStack(spacing: 4) {
                        Text("biddingboulevard")
                            .font(.system(.subheadline, design: .default).weight(.medium))
                            .foregroundColor(.white)

                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }

                    // Rating, Shipping, Follow (bottom row)
                    HStack(spacing: 8) {
                        // Rating Section
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)

                            Text("4.7")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }

                        // Shipping Info
                        HStack(spacing: 2) {
                            Image(systemName: "shippingbox.fill")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))

                            Text("3d")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }

                        // Follow Button
                        Button(action: {
                            print("🔔 Follow button tapped")
                        }) {
                            Text("Follow")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.yellow)
                                )
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .blur(radius: 4)
        )
    }

    // MARK: - Viewer Controls Header (Inline)

    private var viewerControlsHeaderInline: some View {
        HStack(spacing: 6) {
            // Red live indicator
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)

            // "Live" text (no viewer count number)
            Text("Live Now")
                .font(.system(.caption, design: .default).weight(.medium))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 1, x: 0, y: 0)

            // Minimize/Down Arrow Button next to live indicator
            Button(action: {
                print("📱 Minimize screen tapped")
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 1, x: 0, y: 0)
            }
        }
    }

    // MARK: - Right-side Controls (Inline)

    private var rightSideControlsInline: some View {
        VStack(spacing: 16) {
            // More button
            Button(action: {
                print("📱 More button tapped")
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 0)

                    Text("More")
                        .font(.caption)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 0)
                }
            }

            // Clip button
            Button(action: {
                print("📹 Clip button tapped")
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "video.badge.plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 0)

                    Text("Clip")
                        .font(.caption)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 0)
                }
            }

            // Share button
            Button(action: {
                print("📤 Share button tapped")
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.right")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 0)

                    Text("Share")
                        .font(.caption)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 0)
                }
            }

            // Wallet button
            Button(action: {
                print("💳 Wallet button tapped")
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "wallet.pass")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 0)

                    Text("Wallet")
                        .font(.caption)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 0)
                }
            }

            // Shop button
            Button(action: {
                print("🛒 Shop button tapped")
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "storefront")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 0)

                    Text("Shop")
                        .font(.caption)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 0)
                }
            }
        }
        .background(Color.red.opacity(0.3)) // Temporary debug background
        .onAppear {
            print("🎯 [DEBUG] Right-side controls in WebRTC view appeared")
        }
    }

    // MARK: - Helper Properties

    private let streamQualities: [(key: String, value: String)] = [
        ("auto", "Auto"),
        ("4k", "4K Ultra HD"),
        ("fhd", "Full HD 1080p"),
        ("hd", "HD 720p"),
        ("sd", "SD 480p"),
        ("low", "Low 360p"),
        ("mobile", "Mobile 240p")
    ]
}

// MARK: - WebRTC Video Renderer

struct WebRTCVideoRenderer: UIViewRepresentable {
    let videoTrack: RTCVideoTrack?
    let isLocal: Bool

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let videoView = RTCMTLVideoView(frame: .zero)
        // Custom sizing configuration (19:20:10:80)
        videoView.videoContentMode = .scaleAspectFill
        videoView.clipsToBounds = true
        videoView.backgroundColor = UIColor.black
        videoView.contentMode = .scaleAspectFill

        // Custom constraints for 19:20:10:80 sizing
        videoView.translatesAutoresizingMaskIntoConstraints = false
        videoView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        videoView.setContentHuggingPriority(.defaultLow, for: .vertical)
        videoView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        videoView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        return videoView
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        if let videoTrack = videoTrack {
            videoTrack.add(uiView)
        }
    }
}

// MARK: - Preview

struct WebRTCVideoView_Previews: PreviewProvider {
    static var previews: some View {
        WebRTCVideoView(
            auctionId: "sample-auction-id",
            isSellerMode: false,
            isJoined: .constant(false),
            onJoin: {}
        )
    }
}