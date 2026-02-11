# Video Streaming Setup Instructions

## Problem Identified
- No real seller is streaming video (status 404)
- System uses simulated WebRTC data instead of real streams
- Live frame fallback is not receiving actual frames from server

## Solution: Test with Seller Mode

### Step 1: Enable Seller Mode in the App
1. Open the iOS app
2. Navigate to the auction view (WebRTCLiveStreamView)
3. **IMPORTANT**: Switch the mode picker from "Viewer" to "Seller"
4. Tap "Join Stream"
5. The app should now start broadcasting from your device camera

### Step 2: Test with Two Devices/Simulators
1. **Device 1**: Set to "Seller" mode and join
2. **Device 2**: Set to "Viewer" mode and join
3. Device 2 should receive the video stream from Device 1

### Step 3: Verify Camera Permissions
If no video appears:
1. Check iOS camera permissions in Settings > Privacy & Security > Camera > MallOfLebanon
2. Grant camera and microphone permissions

## Expected Behavior in Seller Mode

When you switch to **Seller mode** and join:
- The app requests camera/microphone permissions
- Camera preview appears in the local video view
- WebRTC service starts broadcasting your camera feed
- Other viewers can connect and see your stream

## Current Issue Analysis

From your logs:
```
📡 [SocketService] Seller check response status: 404
⚠️ [SocketService] No real seller offer available (status: 404)
🧪 [SocketService] No real WebRTC events detected, initiating test simulation
```

This means:
1. **No seller is currently streaming** (hence status 404)
2. **System creates fake/simulated data** for testing
3. **Viewers receive simulated offers** but no real video

## Quick Test Commands

To test if this works, run the app and:

1. **Start as Seller**:
   - Mode: "Seller"
   - Join stream
   - Should see camera preview

2. **Connect as Viewer** (second device/simulator):
   - Mode: "Viewer"
   - Join stream
   - Should see seller's video

## Backend Server Requirements

For production, you need:
- Socket.io server running on localhost:3005
- WebRTC signaling server
- Live frame streaming endpoint
- Proper auction management

## Alternative: Use Live Frame Fallback

If WebRTC is too complex for testing, the app supports live frame streaming:
- Server sends periodic image frames via Socket.io
- App displays these as a video-like experience
- Requires server to emit 'live_frame' events with base64 image data

## Debugging Steps

1. **Check if seller mode works**:
   - Enable seller mode
   - Look for camera preview
   - Check for "📹 [WebRTC] Camera capture started" logs

2. **Verify WebRTC connection**:
   - Look for "✅ [WebRTC] Peer connection established" logs
   - Check connection state changes

3. **Test live frame fallback**:
   - Look for "🖼️ [WebRTC] Received live frame" logs
   - Check if frames are being processed

## Expected Log Flow for Working Stream

**Seller side**:
```
🎬 [WebRTCVideoView] Starting WebRTC for auction: [ID]
📹 [WebRTC] Camera capture started at 30 FPS
📡 [WebRTC] Creating offer...
✅ [WebRTC] Peer connection established
```

**Viewer side**:
```
📨 [WebRTC] *** RECEIVED OFFER *** for auction: [ID]
✅ [WebRTC] Offer accepted, processing...
📡 [WebRTC] Creating answer...
✅ [WebRTC] Peer connection established
```