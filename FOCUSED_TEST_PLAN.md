# 🎯 Focused Test Plan - WebRTC Connection Issue

## 🔍 **Root Cause Identified:**
The SocketService is successfully generating and sending WebRTC offers, but the WebRTC Service is never receiving them. This indicates a **Publisher-Subscriber disconnect**.

## 🧪 **Enhanced Debug Logging Added:**

### **Look for these specific logs in sequence:**

1. **WebRTC Service Startup:**
```
🎥 [WebRTC] ========== STARTING WEBRTC ==========
🎥 [WebRTC] Auction: 69889d3806ebe4ce58fa7ae3, seller: false
🎥 [WebRTC] Current WebRTC instance: ObjectIdentifier(...)
🎥 [WebRTC] SocketService instance: ObjectIdentifier(...)
👁️ [WebRTC] VIEWER MODE: Setting up listeners and joining stream
🎧 [WebRTC] Setting up WebRTC offer listener...
🎧 [SocketService] NEW WEBRTC OFFER SUBSCRIBER REGISTERED
🎧 [SocketService] SocketService instance: ObjectIdentifier(...)
🎧 [WebRTC] WebRTC offer listener setup complete
🎥 [WebRTC] ========== WEBRTC STARTUP COMPLETE ==========
```

2. **Real Seller Check (NEW):**
```
🔗 [SocketService] Checking for real seller on localhost:3005...
🔗 [SocketService] Checking for real seller stream for auction: 69889d3806ebe4ce58fa7ae3
📡 [SocketService] Seller check response status: 200
🎯 [SocketService] Real seller offer found!
📦 [SocketService] Real offer data: [actual offer from CRM]
```

3. **Offer Processing:**
```
🎯 [SocketService] handleWebRTCOffer called with data: [offer]
📤 [SocketService] About to send WebRTC offer to subscribers...
📡 [SocketService] Sending WebRTC offer to subscribers
🎯 [SocketService] PUBLISHER: Delivering offer to subscriber for auction: 69889d3806ebe4ce58fa7ae3
📨 [WebRTC] *** RECEIVED OFFER *** for auction: 69889d3806ebe4ce58fa7ae3
✅ [WebRTC] Offer accepted, processing...
```

## 🎯 **Critical Debug Points:**

### **✅ Success Indicators:**
- `🎧 [SocketService] NEW WEBRTC OFFER SUBSCRIBER REGISTERED` - Confirms WebRTC listener is registered
- `🎯 [SocketService] PUBLISHER: Delivering offer to subscriber` - Confirms offers reach subscribers
- `📨 [WebRTC] *** RECEIVED OFFER ***` - Confirms WebRTC service receives offers

### **❌ Failure Indicators:**
- **Missing subscriber registration**: No `🎧 [SocketService] NEW WEBRTC OFFER SUBSCRIBER REGISTERED`
- **Missing delivery**: No `🎯 [SocketService] PUBLISHER: Delivering offer to subscriber`
- **Instance mismatch**: Different ObjectIdentifier values for SocketService instances

## 🔧 **New Features Added:**

1. **Real Seller Connection**: Now checks `localhost:3005` for your actual CRM seller stream
2. **Instance Tracking**: Logs ObjectIdentifier to detect singleton issues
3. **Publisher Tracing**: Detailed logging of the publisher-subscriber chain
4. **Timing Analysis**: Better understanding of when components initialize

## 📱 **Testing Instructions:**

1. **Ensure your CRM seller is streaming** at `http://localhost:3005/lebanon/auctions/live/69889d3806ebe4ce58fa7ae3`
2. **Run the iOS app** and join the auction as viewer
3. **Look specifically for**:
   - The complete WebRTC startup sequence above
   - Whether subscriber registration happens
   - Whether offers are delivered to subscribers
4. **Report findings**: Which specific log message is missing from the expected sequence

## 🎯 **Expected Outcome:**

With the enhanced logging, we should now be able to pinpoint exactly where the publisher-subscriber chain breaks and fix the final connection issue.

The app will now attempt to connect to your real seller stream first, then fall back to simulation if the real stream isn't available.