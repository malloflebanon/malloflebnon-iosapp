#!/bin/bash

# Script to automatically update iOS app API URL with current Mac IP address

echo "🔍 Detecting current Mac IP address..."

# Get the current Mac's IP address
MAC_IP=$(ifconfig en0 | grep "inet " | awk '{print $2}')

if [ -z "$MAC_IP" ]; then
    MAC_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
fi

if [ -z "$MAC_IP" ]; then
    echo "❌ Could not detect Mac IP address"
    exit 1
fi

echo "✅ Detected Mac IP: $MAC_IP"

# Update the iOS APIService.swift file
API_FILE="/Users/ahmadbaba/Desktop/iosapp/MallOfLebanon-iOS/MallOfLebanon-iOS/APIService.swift"

if [ ! -f "$API_FILE" ]; then
    echo "❌ APIService.swift not found at $API_FILE"
    exit 1
fi

# Create backup
cp "$API_FILE" "${API_FILE}.backup"

# Update the baseURL with new IP
sed -i '' "s|private let baseURL = \"http://.*:3007/api\"|private let baseURL = \"http://$MAC_IP:3007/api\"|g" "$API_FILE"

echo "✅ Updated iOS app API URL to: http://$MAC_IP:3007/api"
echo "💾 Created backup at: ${API_FILE}.backup"
echo ""
echo "🚀 You can now build and run your iOS app!"
echo "📱 The app will connect to your backend at http://$MAC_IP:3007"