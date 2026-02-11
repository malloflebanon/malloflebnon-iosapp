#!/bin/bash

# Mall of Lebanon iOS App - IP Address Updater
# This script updates the API base URL in the iOS app to match your current IP address

echo "🔧 Mall of Lebanon iOS App - IP Address Updater"
echo "================================================="

# Get current IP address (excluding localhost)
CURRENT_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

if [ -z "$CURRENT_IP" ]; then
    echo "❌ Could not detect current IP address"
    exit 1
fi

echo "📍 Current IP Address: $CURRENT_IP"
echo "🎯 Port: 3007"
echo "🔗 New API URL: http://$CURRENT_IP:3007/api"
echo ""

# Update APIService.swift
API_SERVICE_FILE="MallOfLebanon-iOS/MallOfLebanon-iOS/Services/APIService.swift"
if [ -f "$API_SERVICE_FILE" ]; then
    # Replace the baseURL line
    sed -i.backup "s|private let baseURL = \"http://.*:3007/api\"|private let baseURL = \"http://$CURRENT_IP:3007/api\"|g" "$API_SERVICE_FILE"
    echo "✅ Updated $API_SERVICE_FILE"
else
    echo "⚠️  File not found: $API_SERVICE_FILE"
fi

# Update ContentView.swift
CONTENT_VIEW_FILE="MallOfLebanon-iOS/MallOfLebanon-iOS/ContentView.swift"
if [ -f "$CONTENT_VIEW_FILE" ]; then
    # Replace the baseURL line
    sed -i.backup "s|private let baseURL = \"http://.*:3007/api\"|private let baseURL = \"http://$CURRENT_IP:3007/api\"|g" "$CONTENT_VIEW_FILE"
    echo "✅ Updated $CONTENT_VIEW_FILE"
else
    echo "⚠️  File not found: $CONTENT_VIEW_FILE"
fi

echo ""
echo "🎉 IP address update completed!"
echo "📱 Please rebuild your iOS app to use the new configuration."
echo ""
echo "🔍 To verify the API is accessible, run:"
echo "   curl http://$CURRENT_IP:3007/api/health"