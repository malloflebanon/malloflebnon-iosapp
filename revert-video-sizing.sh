#!/bin/bash

# Revert Script for Video Sizing
# This script reverts the custom 19:20:10:80 video sizing back to the previous working version

echo "🔄 Reverting video sizing to previous working version..."

# Check if backup exists
if [ -f "/Users/ahmadbaba/Desktop/iosapp/MallOfLebanon-iOS/MallOfLebanon-iOS/Views/WebRTCVideoView.swift.backup" ]; then
    # Restore the backup
    cp "/Users/ahmadbaba/Desktop/iosapp/MallOfLebanon-iOS/MallOfLebanon-iOS/Views/WebRTCVideoView.swift.backup" "/Users/ahmadbaba/Desktop/iosapp/MallOfLebanon-iOS/MallOfLebanon-iOS/Views/WebRTCVideoView.swift"
    echo "✅ Successfully reverted to previous video sizing"
    echo "📁 Original file restored from backup"

    # Test build after revert
    echo "🔨 Testing build after revert..."
    cd "/Users/ahmadbaba/Desktop/iosapp/MallOfLebanon-iOS"
    xcodebuild -scheme MallOfLebanon-iOS -configuration Debug build -destination 'platform=iOS Simulator,name=iPhone 17' -quiet

    if [ $? -eq 0 ]; then
        echo "✅ Build successful after revert"
        echo "🎯 Video sizing reverted successfully - app is ready to use"
    else
        echo "❌ Build failed after revert - manual intervention required"
    fi
else
    echo "❌ Backup file not found!"
    echo "📁 Expected: /Users/ahmadbaba/Desktop/iosapp/MallOfLebanon-iOS/MallOfLebanon-iOS/Views/WebRTCVideoView.swift.backup"
fi