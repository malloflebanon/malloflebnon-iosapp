import Foundation
import WebRTC
import Combine
import AVFoundation

// MARK: - WebRTC Service for iOS Live Streaming

class WebRTCService: NSObject, ObservableObject {
    static let shared = WebRTCService()

    // Published properties for SwiftUI binding
    @Published var connectionState: RTCPeerConnectionState = .closed
    @Published var isConnected = false
    @Published var isStreaming = false
    @Published var streamStats = StreamStats()
    @Published var currentLiveFrame: UIImage? = nil

    // WebRTC Components
    private var peerConnection: RTCPeerConnection?
    private var localVideoTrack: RTCVideoTrack?
    private var localAudioTrack: RTCAudioTrack?
    private var localStream: RTCMediaStream?
    private(set) var remoteVideoTrack: RTCVideoTrack?

    // Media components
    private var videoCapturer: RTCCameraVideoCapturer?
    private var videoSource: RTCVideoSource?
    private var audioSource: RTCAudioSource?

    // Configuration
    private let peerConnectionFactory: RTCPeerConnectionFactory
    private var configuration: RTCConfiguration

    // Socket integration
    private var socketService: SocketService?
    private var currentAuctionId: String?
    private var isSellerMode = false

    // Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    struct StreamStats {
        var fps: Int = 0
        var bitrate: Int = 0
        var packetsLost: Int = 0
        var jitter: Double = 0.0
    }

    // MARK: - Initialization

    override init() {
        // Initialize WebRTC factory
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        self.peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )

        // Configure STUN servers (same as frontend)
        self.configuration = RTCConfiguration()
        configuration.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"])
        ]
        configuration.sdpSemantics = .unifiedPlan

        super.init()
        setupAudioSession()
    }

    // MARK: - Public Interface

    func startWebRTC(auctionId: String, isSellerMode: Bool = false) {
        print("🎥 [WebRTC] ========== STARTING WEBRTC ==========")
        print("🎥 [WebRTC] Auction: \(auctionId), seller: \(isSellerMode)")
        print("🎥 [WebRTC] Current WebRTC instance: \(ObjectIdentifier(self))")
        print("🎥 [WebRTC] Method called successfully - WebRTC service is accessible")

        // Clean up any existing connection first
        if connectionState != .closed {
            print("🧽 [WebRTC] Cleaning up existing connection before starting new one")
            stopWebRTC()
        }

        self.currentAuctionId = auctionId
        self.isSellerMode = isSellerMode
        self.socketService = SocketService.shared

        print("🎥 [WebRTC] SocketService instance: \(ObjectIdentifier(SocketService.shared))")
        print("🎥 [WebRTC] SocketService connected: \(SocketService.shared.isConnected)")

        // Update connection state immediately
        DispatchQueue.main.async {
            self.connectionState = .new
        }

        // Note: Real socket connection will be set up in setupWebRTCListeners via setupLiveFrameListener

        // Setup peer connection
        setupPeerConnection()

        if isSellerMode {
            print("👑 [WebRTC] SELLER MODE: Setting up local media and creating offer")
            // Seller: Setup camera and create offer
            setupLocalMedia()
            createOffer()
        } else {
            print("👁️ [WebRTC] VIEWER MODE: Setting up listeners and joining stream")
            // Viewer: Wait for offer from seller
            setupWebRTCListeners()
        }

        print("🔄 [WebRTC] Initial connection state: \(connectionState)")
        print("🎥 [WebRTC] ========== WEBRTC STARTUP COMPLETE ==========")
    }

    func stopWebRTC() {
        print("🛑 [WebRTC] Stopping WebRTC connection")

        // Clean up local media
        stopLocalMedia()

        // Close peer connection
        peerConnection?.close()
        peerConnection = nil

        // Update state
        DispatchQueue.main.async {
            self.connectionState = .closed
            self.isConnected = false
            self.isStreaming = false
            self.currentLiveFrame = nil // Clear live frame fallback
        }

        // Cancel any Combine subscriptions
        cancellables.removeAll()

        currentAuctionId = nil
        isSellerMode = false
    }

    func switchCamera() {
        guard let capturer = videoCapturer else { return }

        let devices = RTCCameraVideoCapturer.captureDevices()
        print("📷 [WebRTC] Switching camera - available devices: \(devices.count)")

        // Cycle through camera priority: External -> Back -> Front -> Repeat
        let nextCamera: AVCaptureDevice?

        // Check for USB/external cameras first
        if let externalCamera = devices.first(where: { device in
            let name = device.localizedName.lowercased()
            return name.contains("usb") || name.contains("trust") || name.contains("external") ||
                   (device.position == .unspecified && !name.contains("facetime"))
        }) {
            nextCamera = externalCamera
            print("🎯 [WebRTC] Switching to external/USB camera: \(externalCamera.localizedName)")
        }
        // Then back camera
        else if let backCamera = devices.first(where: { $0.position == .back }) {
            nextCamera = backCamera
            print("🎯 [WebRTC] Switching to back camera: \(backCamera.localizedName)")
        }
        // Then front camera
        else if let frontCamera = devices.first(where: { $0.position == .front }) {
            nextCamera = frontCamera
            print("🎯 [WebRTC] Switching to front camera: \(frontCamera.localizedName)")
        }
        // Finally any available
        else {
            nextCamera = devices.first
            if let camera = nextCamera {
                print("🎯 [WebRTC] Switching to first available camera: \(camera.localizedName)")
            }
        }

        if let device = nextCamera {
            let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
            if let format = formats.last {
                capturer.stopCapture { [weak self] in
                    capturer.startCapture(with: device, format: format, fps: 30) { error in
                        if let error = error {
                            print("❌ [WebRTC] Camera switch error: \(error.localizedDescription)")
                        } else {
                            print("✅ [WebRTC] Camera switched successfully to \(device.localizedName)")
                        }
                    }
                }
            }
        }
    }

    func toggleMute() {
        localAudioTrack?.isEnabled.toggle()
    }

    func toggleVideo() {
        localVideoTrack?.isEnabled.toggle()
    }

    func updateStreamQuality(_ quality: String) {
        print("📹 [WebRTCService] Updating stream quality to: \(quality)")

        // Update video constraints based on quality
        guard let capturer = videoCapturer,
              let videoSource = videoSource else {
            print("⚠️ [WebRTCService] Video capturer or source not available")
            return
        }

        // Define quality settings
        let qualitySettings = getQualitySettings(for: quality)

        // Update capture format
        DispatchQueue.main.async {
            if let device = AVCaptureDevice.default(for: .video) {
                let format = self.findOptimalFormat(for: device, targetWidth: qualitySettings.width, targetHeight: qualitySettings.height)
                capturer.stopCapture { [weak self] in
                    capturer.startCapture(with: device, format: format, fps: Int(qualitySettings.fps)) { error in
                        if let error = error {
                            print("❌ [WebRTCService] Failed to update capture quality: \(error)")
                        } else {
                            print("✅ [WebRTCService] Successfully updated to \(quality) quality")
                        }
                    }
                }
            }
        }
    }

    private func getQualitySettings(for quality: String) -> (width: Int32, height: Int32, fps: Int32) {
        switch quality {
        case "4k":
            return (3840, 2160, 30)
        case "fhd":
            return (1920, 1080, 60)
        case "hd":
            return (1280, 720, 30)
        case "sd":
            return (854, 480, 30)
        case "low":
            return (640, 360, 25)
        case "mobile":
            return (426, 240, 15)
        default: // "auto" or unknown
            return (1280, 720, 30) // Default to HD
        }
    }

    private func findOptimalFormat(for device: AVCaptureDevice, targetWidth: Int32, targetHeight: Int32) -> AVCaptureDevice.Format {
        var bestFormat: AVCaptureDevice.Format?
        var bestScore = Int.max

        for format in device.formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let widthDiff = abs(dimensions.width - targetWidth)
            let heightDiff = abs(dimensions.height - targetHeight)
            let score = Int(widthDiff + heightDiff)

            if score < bestScore {
                bestScore = score
                bestFormat = format
            }
        }

        return bestFormat ?? device.formats.first!
    }

    // MARK: - WebRTC Setup

    private func setupPeerConnection() {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )

        peerConnection = peerConnectionFactory.peerConnection(
            with: configuration,
            constraints: constraints,
            delegate: self
        )

        print("✅ [WebRTC] Peer connection created")
    }

    private func setupLocalMedia() {
        guard let peerConnection = peerConnection else { return }

        print("📹 [WebRTC] Setting up local media (seller mode)")

        // Create local media stream
        let streamId = "LocalStream"
        localStream = peerConnectionFactory.mediaStream(withStreamId: streamId)

        // Setup video
        setupVideoTrack()

        // Setup audio
        setupAudioTrack()

        // Add tracks to peer connection
        if let videoTrack = localVideoTrack {
            peerConnection.add(videoTrack, streamIds: [streamId])
        }

        if let audioTrack = localAudioTrack {
            peerConnection.add(audioTrack, streamIds: [streamId])
        }

        DispatchQueue.main.async {
            self.isStreaming = true
        }

        print("✅ [WebRTC] Local media setup complete")
    }

    private func setupVideoTrack() {
        // Create video source
        videoSource = peerConnectionFactory.videoSource()

        // Create video capturer
        videoCapturer = RTCCameraVideoCapturer(delegate: videoSource!)

        // Create video track
        localVideoTrack = peerConnectionFactory.videoTrack(
            with: videoSource!,
            trackId: "video0"
        )

        // Start capturing
        startVideoCapture()

        print("✅ [WebRTC] Video track setup complete")
    }

    private func setupAudioTrack() {
        // Create audio source
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        audioSource = peerConnectionFactory.audioSource(with: audioConstraints)

        // Create audio track
        localAudioTrack = peerConnectionFactory.audioTrack(with: audioSource!, trackId: "audio0")

        print("✅ [WebRTC] Audio track setup complete")
    }

    private func startVideoCapture() {
        guard let capturer = videoCapturer else { return }

        // Get available capture devices
        let devices = RTCCameraVideoCapturer.captureDevices()
        print("📷 [WebRTC] Found \(devices.count) camera devices:")
        for (index, device) in devices.enumerated() {
            print("📷 [WebRTC] Camera \(index): \(device.localizedName) - Position: \(device.position.rawValue)")
        }

        // Priority order: 1) External/USB cameras 2) Back camera 3) Front camera 4) Any available
        let selectedCamera: AVCaptureDevice

        // First try to find USB/external cameras (usually don't have specific position)
        if let externalCamera = devices.first(where: { device in
            let name = device.localizedName.lowercased()
            return name.contains("usb") || name.contains("trust") || name.contains("external") ||
                   (device.position == .unspecified && !name.contains("facetime"))
        }) {
            selectedCamera = externalCamera
            print("🎯 [WebRTC] Selected external/USB camera: \(externalCamera.localizedName)")
        }
        // Then try back camera
        else if let backCamera = devices.first(where: { $0.position == .back }) {
            selectedCamera = backCamera
            print("🎯 [WebRTC] Selected back camera: \(backCamera.localizedName)")
        }
        // Then front camera
        else if let frontCamera = devices.first(where: { $0.position == .front }) {
            selectedCamera = frontCamera
            print("🎯 [WebRTC] Selected front camera: \(frontCamera.localizedName)")
        }
        // Finally any available camera
        else if let anyCamera = devices.first {
            selectedCamera = anyCamera
            print("🎯 [WebRTC] Selected first available camera: \(anyCamera.localizedName)")
        }
        else {
            print("❌ [WebRTC] No camera available")
            return
        }

        // Get supported formats
        let formats = RTCCameraVideoCapturer.supportedFormats(for: selectedCamera)
        print("📷 [WebRTC] Found \(formats.count) supported formats for \(selectedCamera.localizedName)")

        // Choose the best quality format (usually the last one)
        guard let format = formats.last else {
            print("❌ [WebRTC] No supported formats for selected camera")
            return
        }

        print("📷 [WebRTC] Selected format: \(format.formatDescription)")

        // Start capture at 30 FPS
        let fps = 30
        capturer.startCapture(with: selectedCamera, format: format, fps: fps) { error in
            if let error = error {
                print("❌ [WebRTC] Camera capture error: \(error.localizedDescription)")
            } else {
                print("✅ [WebRTC] Camera capture started successfully with \(selectedCamera.localizedName) at \(fps) FPS")
            }
        }
    }

    private func stopLocalMedia() {
        videoCapturer?.stopCapture()
        localVideoTrack = nil
        localAudioTrack = nil
        localStream = nil
        videoSource = nil
        audioSource = nil
        videoCapturer = nil

        DispatchQueue.main.async {
            self.isStreaming = false
        }

        print("🛑 [WebRTC] Local media stopped")
    }

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.allowBluetoothA2DP, .allowAirPlay])
            try audioSession.setActive(true)
            print("✅ [WebRTC] Audio session configured")
        } catch {
            print("❌ [WebRTC] Audio session error: \(error.localizedDescription)")
        }
    }

    // MARK: - WebRTC Signaling

    private func createOffer() {
        guard let peerConnection = peerConnection else { return }

        print("📡 [WebRTC] Creating offer...")

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )

        peerConnection.offer(for: constraints) { [weak self] (sdp, error) in
            guard let self = self else { return }

            if let error = error {
                print("❌ [WebRTC] Create offer error: \(error.localizedDescription)")
                return
            }

            guard let sdp = sdp else {
                print("❌ [WebRTC] No SDP in offer")
                return
            }

            // Set local description
            peerConnection.setLocalDescription(sdp) { [weak self] error in
                if let error = error {
                    print("❌ [WebRTC] Set local description error: \(error.localizedDescription)")
                    return
                }

                print("✅ [WebRTC] Local description set, sending offer")
                self?.sendOffer(sdp)
            }
        }
    }

    private func sendOffer(_ sdp: RTCSessionDescription) {
        guard let auctionId = currentAuctionId,
              let socketService = socketService else { return }

        let offer = RTCSessionDescriptionData(type: sdpTypeToString(sdp.type), sdp: sdp.sdp)
        let offerData = WebRTCOfferData(auctionId: auctionId, offer: offer, sellerId: nil)

        socketService.sendWebRTCOffer(offerData)
        print("📡 [WebRTC] Offer sent via socket")
    }

    private func setupWebRTCListeners() {
        // Ensure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard let socketService = self.socketService else {
                print("❌ [WebRTC] SocketService not available!")
                return
            }

            print("🔗 [WebRTC] Setting up WebRTC listeners...")
            print("🔗 [WebRTC] Socket connected: \(socketService.isConnected)")
            print("🔗 [WebRTC] SocketService instance: \(ObjectIdentifier(socketService))")
            print("🔗 [WebRTC] WebRTC instance: \(ObjectIdentifier(self))")

            // Clear any existing subscriptions first
            self.cancellables.removeAll()

            // Setup WebRTC offer listener for viewers
            print("🎧 [WebRTC] Setting up WebRTC offer listener...")
            print("🎧 [WebRTC] About to call socketService.onWebRTCOffer...")
            print("🎧 [WebRTC] Current auction: \(self.currentAuctionId ?? "nil")")
            print("🎧 [WebRTC] Seller mode: \(self.isSellerMode)")

            let subscription = socketService.onWebRTCOffer { [weak self] offerData in
                DispatchQueue.main.async {
                    print("📨 [WebRTC] *** RECEIVED OFFER *** for auction: \(offerData.auctionId)")
                    print("📨 [WebRTC] Current auction: \(self?.currentAuctionId ?? "nil")")
                    print("📨 [WebRTC] Seller mode: \(self?.isSellerMode ?? false)")

                    guard let self = self,
                          let auctionId = self.currentAuctionId,
                          offerData.auctionId == auctionId,
                          !self.isSellerMode else {
                        print("❌ [WebRTC] Offer rejected - wrong auction or mode")
                        print("❌ [WebRTC] Expected auction: \(self?.currentAuctionId ?? "nil"), got: \(offerData.auctionId)")
                        print("❌ [WebRTC] Seller mode: \(self?.isSellerMode ?? false)")
                        return
                    }

                    print("✅ [WebRTC] Offer accepted, processing...")
                    self.handleWebRTCOffer(offerData)
                }
            }

            subscription.store(in: &self.cancellables)
            print("🎧 [WebRTC] WebRTC offer listener setup complete")
            print("🎧 [WebRTC] Subscription stored in cancellables, count: \(self.cancellables.count)")

            // Setup WebRTC answer listener for sellers
            socketService.onWebRTCAnswer { [weak self] answerData in
                DispatchQueue.main.async {
                    print("📨 [WebRTC] Received answer for auction: \(answerData.auctionId)")
                    guard let self = self,
                          let auctionId = self.currentAuctionId,
                          answerData.auctionId == auctionId,
                          self.isSellerMode else {
                        print("❌ [WebRTC] Answer rejected - wrong auction or mode")
                        return
                    }

                    print("✅ [WebRTC] Processing answer...")
                    self.handleWebRTCAnswer(answerData)
                }
            }
            .store(in: &self.cancellables)

            // Setup ICE candidate listener for both
            socketService.onWebRTCIceCandidate { [weak self] candidateData in
                DispatchQueue.main.async {
                    print("🧊 [WebRTC] Received ICE candidate for auction: \(candidateData.auctionId)")
                    guard let self = self,
                          let auctionId = self.currentAuctionId,
                          candidateData.auctionId == auctionId else {
                        print("❌ [WebRTC] ICE candidate rejected - wrong auction")
                        return
                    }

                    print("✅ [WebRTC] Processing ICE candidate...")
                    self.handleWebRTCIceCandidate(candidateData)
                }
            }
            .store(in: &self.cancellables)

            // Setup live frame listener using existing socket service
            print("🖼️ [WebRTC] Setting up live frame listener...")
            // Use existing SocketService connection for live frames
            self.setupExistingSocketLiveFrameListener()

            // Enhanced connection flow with retries
            if let auctionId = self.currentAuctionId {
                print("🔗 [WebRTC] Starting enhanced connection flow for auction: \(auctionId)")
                self.establishSocketConnectionWithRetry(auctionId: auctionId)
            } else {
                print("❌ [WebRTC] No auction ID available for joining stream")
            }

            print("👂 [WebRTC] WebRTC listeners setup complete (viewer mode)")
        }
    }

    private func establishSocketConnectionWithRetry(auctionId: String, attempt: Int = 1, maxAttempts: Int = 3) {
        print("🔄 [WebRTC] Connection attempt \(attempt)/\(maxAttempts) for auction: \(auctionId)")

        guard let socketService = socketService else { return }

        // Connect to auction
        socketService.connectToAuction(auctionId)

        // Monitor connection with timeout
        let connectionTimeout = DispatchWorkItem { [weak self] in
            if !socketService.isConnected && attempt < maxAttempts {
                print("⏰ [WebRTC] Connection attempt \(attempt) timed out, retrying...")
                self?.establishSocketConnectionWithRetry(auctionId: auctionId, attempt: attempt + 1, maxAttempts: maxAttempts)
            } else if !socketService.isConnected {
                print("❌ [WebRTC] All connection attempts failed, proceeding with fallback")
                self?.proceedWithStreamJoin(auctionId: auctionId)
            }
        }

        // Set timeout for this attempt
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: connectionTimeout)

        // Monitor successful connection
        socketService.$isConnected
            .filter { $0 == true }
            .first()
            .sink { [weak self] _ in
                print("✅ [WebRTC] Socket connected on attempt \(attempt)! Proceeding with stream join...")
                connectionTimeout.cancel()
                self?.proceedWithStreamJoin(auctionId: auctionId)
            }
            .store(in: &cancellables)
    }

    private func proceedWithStreamJoin(auctionId: String) {
        print("🎯 [WebRTC] Proceeding with stream join for auction: \(auctionId)")

        guard let socketService = socketService else { return }

        // Join the stream
        socketService.joinStream(auctionId)

        // Set up offer timeout for viewers
        if !isSellerMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
                if self?.connectionState != .connected && self?.connectionState != .connecting {
                    print("⚠️ [WebRTC] No WebRTC offer received within timeout, checking for alternative sources")
                    self?.handleNoOfferReceived(auctionId: auctionId)
                }
            }
        }
    }

    private func handleNoOfferReceived(auctionId: String) {
        print("🔍 [WebRTC] Handling no offer received scenario for auction: \(auctionId)")

        // Update UI to show waiting state
        DispatchQueue.main.async {
            self.connectionState = .new
        }

        // Attempt to request offer from server
        requestWebRTCOffer(auctionId: auctionId)

        // After a short delay, if still no offer, show helpful message
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            if self.connectionState != .connected && self.connectionState != .connecting {
                print("ℹ️ [WebRTC] No seller appears to be broadcasting for this auction")
                // Update UI to show "waiting for seller" state
                DispatchQueue.main.async {
                    self.connectionState = .new // Keep in waiting state rather than failed
                }
            }
        }
    }

    private func requestWebRTCOffer(auctionId: String) {
        print("📤 [WebRTC] Requesting WebRTC offer for auction: \(auctionId)")

        guard let socketService = socketService else { return }

        let message: [String: Any] = [
            "event": "request_webrtc_offer",
            "auctionId": auctionId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        socketService.sendMessage(message)

        // Set another timeout for this request
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            if self?.connectionState != .connected {
                print("⚠️ [WebRTC] Still no offer after request, this may indicate no active seller")
                DispatchQueue.main.async {
                    self?.connectionState = .failed
                }
            }
        }
    }

    // MARK: - Remote Video Rendering

    func getLocalVideoRenderer() -> RTCVideoRenderer? {
        // Return a renderer for local video preview
        return nil // Implementation would return actual renderer
    }

    func getRemoteVideoRenderer() -> RTCVideoRenderer? {
        // Return a renderer for remote video
        return nil // Implementation would return actual renderer
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WebRTCService: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCPeerConnectionState) {
        print("🔄 [WebRTC] Connection state changed: \(stateChanged.rawValue)")

        DispatchQueue.main.async {
            self.connectionState = stateChanged
            self.isConnected = stateChanged == .connected
        }

        switch stateChanged {
        case .connected:
            print("✅ [WebRTC] Peer connection established")
            startStatsCollection()
        case .failed, .disconnected:
            print("❌ [WebRTC] Peer connection failed/disconnected")
            DispatchQueue.main.async {
                self.isStreaming = false
            }
        default:
            break
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("📺 [WebRTC] Remote stream added")

        if let videoTrack = stream.videoTracks.first {
            self.remoteVideoTrack = videoTrack
            print("📹 [WebRTC] Remote video track available")
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("📺 [WebRTC] Remote stream removed")
        self.remoteVideoTrack = nil
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("🧊 [WebRTC] ICE candidate generated")
        sendIceCandidate(candidate)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("🧊 [WebRTC] ICE candidates removed")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("📊 [WebRTC] Data channel opened")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("🤝 [WebRTC] Should negotiate")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("🧊 [WebRTC] ICE connection state: \(newState.rawValue)")

        switch newState {
        case .new:
            print("🧊 [WebRTC] ICE state: NEW - Starting ICE gathering")
        case .checking:
            print("🧊 [WebRTC] ICE state: CHECKING - Finding connection path")
        case .connected:
            print("✅ [WebRTC] ICE state: CONNECTED - ICE connection established")
        case .completed:
            print("✅ [WebRTC] ICE state: COMPLETED - ICE gathering finished")
        case .failed:
            print("❌ [WebRTC] ICE state: FAILED - ICE connection failed")
        case .disconnected:
            print("⚠️ [WebRTC] ICE state: DISCONNECTED - ICE connection lost")
        case .closed:
            print("🔒 [WebRTC] ICE state: CLOSED - ICE connection closed")
        case .count:
            print("🧊 [WebRTC] ICE state: COUNT")
        @unknown default:
            print("❓ [WebRTC] ICE state: UNKNOWN")
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("🧊 [WebRTC] ICE gathering state: \(newState.rawValue)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("📡 [WebRTC] Signaling state changed: \(stateChanged.rawValue)")
    }

    // MARK: - Helper Methods

    private func sdpTypeToString(_ type: RTCSdpType) -> String {
        switch type {
        case .offer:
            return "offer"
        case .prAnswer:
            return "pranswer"
        case .answer:
            return "answer"
        case .rollback:
            return "rollback"
        @unknown default:
            return "unknown"
        }
    }

    private func sendIceCandidate(_ candidate: RTCIceCandidate) {
        guard let auctionId = currentAuctionId,
              let socketService = socketService else { return }

        let iceCandidate = RTCIceCandidateData(
            candidate: candidate.sdp,
            sdpMLineIndex: candidate.sdpMLineIndex,
            sdpMid: candidate.sdpMid
        )

        let candidateData = WebRTCIceCandidateData(
            auctionId: auctionId,
            candidate: iceCandidate,
            target: isSellerMode ? "viewer" : "seller"
        )

        socketService.sendWebRTCIceCandidate(candidateData)
        print("🧊 [WebRTC] ICE candidate sent")
    }

    private func startStatsCollection() {
        // Collect WebRTC statistics periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.collectStats()
        }
    }

    private func collectStats() {
        guard let peerConnection = peerConnection else { return }

        peerConnection.statistics { [weak self] report in
            // Parse WebRTC stats and update streamStats
            // Implementation would parse the statistics report

            DispatchQueue.main.async {
                // Update stats on main thread
                self?.streamStats = StreamStats()
            }
        }
    }

    // MARK: - WebRTC Signal Handling

    private func handleWebRTCOffer(_ offerData: WebRTCOfferData) {
        guard let peerConnection = peerConnection else { return }

        print("📺 [WebRTC] Handling WebRTC offer from seller")

        let sessionDescription = RTCSessionDescription(
            type: .offer,
            sdp: offerData.offer.sdp
        )

        peerConnection.setRemoteDescription(sessionDescription) { [weak self] error in
            if let error = error {
                print("❌ [WebRTC] Set remote description error: \(error.localizedDescription)")
                return
            }

            print("✅ [WebRTC] Remote description set successfully")

            // Update connection state optimistically
            DispatchQueue.main.async {
                self?.connectionState = .connecting
            }

            self?.createAnswer()
        }
    }

    private func handleWebRTCAnswer(_ answerData: WebRTCAnswerData) {
        guard let peerConnection = peerConnection else { return }

        print("📺 [WebRTC] Handling WebRTC answer from viewer")

        let sessionDescription = RTCSessionDescription(
            type: .answer,
            sdp: answerData.answer.sdp
        )

        peerConnection.setRemoteDescription(sessionDescription) { error in
            if let error = error {
                print("❌ [WebRTC] Set remote description error: \(error.localizedDescription)")
                return
            }

            print("✅ [WebRTC] Remote description set successfully")
        }
    }

    private func handleWebRTCIceCandidate(_ candidateData: WebRTCIceCandidateData) {
        guard let peerConnection = peerConnection else { return }

        print("🧊 [WebRTC] Handling ICE candidate")

        let iceCandidate = RTCIceCandidate(
            sdp: candidateData.candidate.candidate,
            sdpMLineIndex: candidateData.candidate.sdpMLineIndex,
            sdpMid: candidateData.candidate.sdpMid
        )

        peerConnection.add(iceCandidate) { error in
            if let error = error {
                print("❌ [WebRTC] Add ICE candidate error: \(error.localizedDescription)")
                return
            }

            print("✅ [WebRTC] ICE candidate added successfully")
        }
    }

    // MARK: - Live Frame Listener using Existing SocketService

    private func setupExistingSocketLiveFrameListener() {
        print("🖼️ [WebRTC] Setting up live frame listener using existing SocketService")

        guard let socketService = socketService else {
            print("❌ [WebRTC] SocketService not available for live frames")
            return
        }

        // Listen for live frames from the existing SocketService connection
        socketService.onLiveFrame { [weak self] frameData in
            DispatchQueue.main.async {
                print("🖼️ [WebRTC] Received live frame via existing SocketService")
                self?.handleLiveFrame(frameData)
            }
        }
        .store(in: &cancellables)

        print("✅ [WebRTC] Live frame listener setup complete using existing SocketService")
    }

    // MARK: - Live Frame Fallback (matching web implementation)

    private func handleLiveFrame(_ frameData: LiveFrameData) {
        print("🖼️ [WebRTC] Processing live frame fallback")
        print("🖼️ [WebRTC] Frame quality: \(frameData.quality ?? "unknown")")
        print("🖼️ [WebRTC] Frame resolution: \(frameData.resolution ?? "unknown")")

        // Convert base64 image data to UIImage
        guard let imageData = extractImageData(from: frameData.imageData),
              let uiImage = UIImage(data: imageData) else {
            print("❌ [WebRTC] Failed to decode live frame image data")
            return
        }

        print("✅ [WebRTC] Live frame decoded successfully, size: \(uiImage.size)")

        // Update connection state and publish the frame
        DispatchQueue.main.async {
            if self.connectionState != .connected {
                self.connectionState = .connected
                self.isStreaming = true
                print("📺 [WebRTC] Connection state updated to connected via live frames")
            }

            // Publish the frame for the UI to display
            self.currentLiveFrame = uiImage
            print("🖼️ [WebRTC] Live frame published to UI")
        }
    }

    private func extractImageData(from base64String: String) -> Data? {
        // Handle data URL format: "data:image/jpeg;base64,/9j/4AAQ..."
        let cleanBase64: String
        if base64String.hasPrefix("data:") {
            guard let commaIndex = base64String.firstIndex(of: ",") else {
                print("❌ [WebRTC] Invalid data URL format")
                return nil
            }
            cleanBase64 = String(base64String[base64String.index(after: commaIndex)...])
        } else {
            cleanBase64 = base64String
        }

        return Data(base64Encoded: cleanBase64)
    }

    private func createAnswer() {
        guard let peerConnection = peerConnection else { return }

        print("📡 [WebRTC] Creating answer...")

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )

        peerConnection.answer(for: constraints) { [weak self] (sdp, error) in
            guard let self = self else { return }

            if let error = error {
                print("❌ [WebRTC] Create answer error: \(error.localizedDescription)")
                return
            }

            guard let sdp = sdp else {
                print("❌ [WebRTC] No SDP in answer")
                return
            }

            // Set local description
            peerConnection.setLocalDescription(sdp) { [weak self] error in
                if let error = error {
                    print("❌ [WebRTC] Set local description error: \(error.localizedDescription)")
                    return
                }

                print("✅ [WebRTC] Local description set, sending answer")

                // Update to connected state after successful signaling
                DispatchQueue.main.async {
                    self?.isConnected = true
                    self?.connectionState = .connected
                }

                self?.sendAnswer(sdp)
            }
        }
    }

    private func sendAnswer(_ sdp: RTCSessionDescription) {
        guard let auctionId = currentAuctionId,
              let socketService = socketService else { return }

        let answer = RTCSessionDescriptionData(type: sdpTypeToString(sdp.type), sdp: sdp.sdp)
        let answerData = WebRTCAnswerData(
            auctionId: auctionId,
            answer: answer,
            viewerId: "", // Would need to get actual viewer ID
            sellerId: ""  // Would need to get actual seller ID
        )

        socketService.sendWebRTCAnswer(answerData)
        print("📡 [WebRTC] Answer sent via socket")
    }
}