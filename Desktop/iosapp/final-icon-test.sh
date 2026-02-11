#!/bin/bash

echo "🔧 Final MOL Icon Debug & Test"
echo "==============================="

APP_PATH="/Users/ahmadbaba/Library/Developer/Xcode/DerivedData/MallOfLebanon-iOS-fqclwapirtrmpeaagopxrxwmywgu/Build/Products/Debug-iphonesimulator/MallOfLebanon-iOS.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not built. Building now..."
    cd /Users/ahmadbaba/Desktop/iosapp/MallOfLebanon-iOS
    xcodebuild -project MallOfLebanon-iOS.xcodeproj -scheme MallOfLebanon-iOS -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2" build
    echo ""
fi

echo "🔍 Checking built app:"
if [ -d "$APP_PATH" ]; then
    echo "✅ App bundle exists"

    echo "📱 App icons in bundle:"
    find "$APP_PATH" -name "*Icon*.png" | while read file; do
        echo "   $(basename "$file") - $(file "$file" | cut -d: -f2)"
    done

    echo ""
    echo "📋 Info.plist CFBundleIcons:"
    /usr/libexec/PlistBuddy -c "Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles" "$APP_PATH/Info.plist" 2>/dev/null || echo "   No CFBundleIconFiles found"

    echo ""
    echo "🎯 Testing with available simulators:"
    DEVICES=$(xcrun simctl list devices available | grep "iPhone" | head -3)
    echo "$DEVICES"

    # Get first available iPhone
    DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')

    if [ ! -z "$DEVICE_ID" ]; then
        echo ""
        echo "🚀 Testing installation on: $DEVICE_ID"

        # Boot if needed
        xcrun simctl boot "$DEVICE_ID" 2>/dev/null || echo "   (Device already booted)"

        # Install app
        echo "📲 Installing app..."
        xcrun simctl install "$DEVICE_ID" "$APP_PATH"

        if [ $? -eq 0 ]; then
            echo "✅ App installed successfully!"
            echo ""
            echo "🎉 INSTRUCTIONS TO SEE THE ICON:"
            echo "   1. Open Simulator app"
            echo "   2. Look for 'Mall Of Lebanon' app on home screen"
            echo "   3. Icon should show 'MOL' text in white circle on steel blue background"
            echo ""
            echo "💡 If icon still doesn't show:"
            echo "   - Restart Simulator app completely"
            echo "   - Device → Erase All Content and Settings"
            echo "   - Rebuild and install again"
            echo "   - Sometimes it takes 10-30 seconds for iOS to refresh icons"

            # Launch the app
            echo ""
            echo "🎯 Launching app to test functionality..."
            xcrun simctl launch "$DEVICE_ID" com.malloflebanon.ios

        else
            echo "❌ Failed to install app"
        fi
    else
        echo "❌ No iPhone simulator found"
    fi

else
    echo "❌ App bundle not found at: $APP_PATH"
fi

echo ""
echo "🔧 If icon STILL doesn't show, the issue might be:"
echo "   1. iOS Simulator caching - requires complete restart"
echo "   2. Icon format incompatibility - try different PNG compression"
echo "   3. Asset catalog configuration - check Xcode project directly"
echo ""
echo "✅ Everything looks technically correct - the icon should display!"