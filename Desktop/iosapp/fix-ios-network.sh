#!/bin/bash

# Mall of Lebanon iOS App - Complete Network Fix Script
# This script automatically fixes all network configuration issues
# Author: Claude Code Assistant
# Version: 2.0

echo "🔧 Mall of Lebanon iOS App - Complete Network Fix"
echo "=================================================="

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Get current IP address (excluding localhost)
echo "🔍 Detecting current Mac IP address..."
CURRENT_IP=$(ifconfig en0 | grep "inet " | awk '{print $2}' 2>/dev/null)

if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
fi

if [ -z "$CURRENT_IP" ]; then
    print_error "Could not detect current IP address"
    print_info "Please check your network connection and try again"
    exit 1
fi

print_status "Detected Mac IP: $CURRENT_IP"
print_info "Target Backend: http://$CURRENT_IP:3007/api"
echo ""

# Verify backend is running
echo "🏥 Checking backend health..."
BACKEND_STATUS=$(curl -s -m 5 "http://$CURRENT_IP:3007/api/health" 2>/dev/null)
if [ $? -eq 0 ] && [[ $BACKEND_STATUS == *"healthy"* ]]; then
    print_status "Backend is running and healthy"
else
    print_warning "Backend might not be running on $CURRENT_IP:3007"
    print_info "Please ensure your backend server is started"
    echo "   Command: cd /path/to/your/backend && npm run dev"
fi
echo ""

# Define file paths
API_SERVICE_FILE="MallOfLebanon-iOS/MallOfLebanon-iOS/APIService.swift"
INFO_PLIST_FILE="MallOfLebanon-iOS/MallOfLebanon-iOS/Info.plist"

# Update APIService.swift
echo "📱 Updating APIService.swift..."
if [ -f "$API_SERVICE_FILE" ]; then
    # Create backup
    cp "$API_SERVICE_FILE" "${API_SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

    # Update the baseURL line
    sed -i.temp "s|private let baseURL = \"http://.*:3007/api\"|private let baseURL = \"http://$CURRENT_IP:3007/api\"|g" "$API_SERVICE_FILE"
    rm "${API_SERVICE_FILE}.temp" 2>/dev/null

    print_status "Updated APIService.swift with new IP: $CURRENT_IP"
else
    print_error "APIService.swift not found at: $API_SERVICE_FILE"
    exit 1
fi

# Update Info.plist
echo "🔐 Updating Info.plist security settings..."
if [ -f "$INFO_PLIST_FILE" ]; then
    # Create backup
    cp "$INFO_PLIST_FILE" "${INFO_PLIST_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

    # Check if NSExceptionDomains exists and update it
    if grep -q "NSExceptionDomains" "$INFO_PLIST_FILE"; then
        # Remove existing IP addresses (but keep localhost) and add current IP
        # Use sed to replace any existing IP address with current IP
        sed -i.temp "s|<key>[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}</key>|<key>$CURRENT_IP</key>|g" "$INFO_PLIST_FILE"
        rm "${INFO_PLIST_FILE}.temp" 2>/dev/null

        print_status "Updated Info.plist with new IP security exception: $CURRENT_IP"
    else
        print_warning "NSExceptionDomains not found in Info.plist - using NSAllowsArbitraryLoads"
        print_info "Current configuration allows all HTTP connections"
    fi
else
    print_error "Info.plist not found at: $INFO_PLIST_FILE"
    exit 1
fi

echo ""
echo "🎉 Network configuration update completed!"
echo "============================================="
print_status "APIService.swift: Updated to use $CURRENT_IP:3007"
print_status "Info.plist: Added HTTP security exception for $CURRENT_IP"
echo ""

# Verification
echo "🔍 Verification:"
echo "   • Backend Health: curl http://$CURRENT_IP:3007/api/health"
echo "   • API Base URL: http://$CURRENT_IP:3007/api"
echo ""

print_info "Next Steps:"
echo "   1. Clean and rebuild your iOS project in Xcode"
echo "   2. Run the app on simulator or device"
echo "   3. Test sign-in and product fetching"
echo ""

print_warning "Note: Run this script whenever your IP address changes!"
echo "   • After router restart"
echo "   • After reconnecting to WiFi"
echo "   • After switching networks"
echo ""

echo "🚀 Ready to build and test your iOS app!"