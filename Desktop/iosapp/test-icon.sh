#!/bin/bash

# Mall of Lebanon - Test MOL Icon Script
echo "🧪 Testing Mall of Lebanon MOL Icon"
echo "===================================="

# Get the built app path
APP_PATH="/Users/ahmadbaba/Library/Developer/Xcode/DerivedData/MallOfLebanon-iOS-fqclwapirtrmpeaagopxrxwmywgu/Build/Products/Debug-iphonesimulator/MallOfLebanon-iOS.app"

if [ -d "$APP_PATH" ]; then
    echo "✅ App found at: $APP_PATH"

    # Check for icon files in the built app
    echo ""
    echo "🔍 Checking built app icons:"
    find "$APP_PATH" -name "*.png" | head -5

    echo ""
    echo "📱 Launching iPhone 17 Simulator..."

    # Boot iPhone 17 simulator
    DEVICE_ID=$(xcrun simctl list devices | grep "iPhone 17 (" | grep -v "Pro" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')

    if [ ! -z "$DEVICE_ID" ]; then
        echo "   Device ID: $DEVICE_ID"
        xcrun simctl boot "$DEVICE_ID" 2>/dev/null || echo "   (Simulator already booted)"

        echo "📲 Installing app on simulator..."
        xcrun simctl install "$DEVICE_ID" "$APP_PATH"

        echo "🚀 Opening Mall of Lebanon app..."
        xcrun simctl launch "$DEVICE_ID" com.malloflebanon.ios

        echo ""
        echo "✅ App launched! Check your iPhone simulator:"
        echo "   1. Look for 'Mall Of Lebanon' app on home screen"
        echo "   2. Icon should show 'MOL' in white circle"
        echo "   3. Lebanese flag colors in background"
        echo "   4. Small shopping cart and bag icons"
        echo ""
        echo "🎯 If icon doesn't show immediately:"
        echo "   - Wait a few seconds for icon to load"
        echo "   - Restart the simulator if needed"
        echo "   - Clean build and rebuild in Xcode"
    else
        echo "❌ iPhone 17 simulator not found"
        echo "   Available devices:"
        xcrun simctl list devices | grep iPhone | head -5
    fi
else
    echo "❌ App not found. Please build the project first:"
    echo "   1. Open Xcode"
    echo "   2. Build and run the project"
    echo "   3. Then run this script"
fi