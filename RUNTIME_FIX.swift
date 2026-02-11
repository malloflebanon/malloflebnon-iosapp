// 🚨 RUNTIME FIX - Add this directly in Xcode if emergency fixes aren't working

// In WebRTCLiveStreamView.swift - replace the WebRTCVideoView call with:

WebRTCVideoView(
    auctionId: auctionId,
    isSellerMode: isSellerMode,
    isJoined: $isJoined,
    onJoin: {
        print("🚨 [RUNTIME FIX] Join action triggered")
        joinAuction()

        // DIRECT WebRTC startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("🚨 [RUNTIME FIX] Starting WebRTC directly...")
            WebRTCService.shared.startWebRTC(auctionId: auctionId, isSellerMode: isSellerMode)
            print("🚨 [RUNTIME FIX] WebRTC startup completed")
        }
    }
)

// This bypasses all potential binding issues and directly starts WebRTC