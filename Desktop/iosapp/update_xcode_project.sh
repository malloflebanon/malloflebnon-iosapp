#!/bin/bash

# Script to automatically add new Swift files to Xcode project
# Usage: ./update_xcode_project.sh

XCODE_PROJECT_DIR="/Users/ahmadbaba/Desktop/iosapp/MallOfLebanon-iOS"
PROJECT_FILE="$XCODE_PROJECT_DIR/MallOfLebanon-iOS.xcodeproj/project.pbxproj"
SOURCE_DIR="$XCODE_PROJECT_DIR/MallOfLebanon-iOS"

echo "🔍 Scanning for new Swift files in: $SOURCE_DIR"

# Find all Swift files in the project directory
SWIFT_FILES=$(find "$SOURCE_DIR" -name "*.swift" -type f)

# Files that need to be added to Xcode project
NEW_FILES_FOUND=()

# Check each Swift file to see if it's already in the project
for file in $SWIFT_FILES; do
    filename=$(basename "$file")

    # Check if file is already referenced in project.pbxproj
    if ! grep -q "$filename" "$PROJECT_FILE"; then
        NEW_FILES_FOUND+=("$file")
        echo "📄 Found new file: $filename"
    fi
done

if [ ${#NEW_FILES_FOUND[@]} -eq 0 ]; then
    echo "✅ All Swift files are already in the Xcode project!"
    exit 0
fi

echo ""
echo "🛠️  Adding ${#NEW_FILES_FOUND[@]} new files to Xcode project..."

# Backup the project file
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"
echo "💾 Created backup: project.pbxproj.backup"

# For each new file, add it to the project
for file in "${NEW_FILES_FOUND[@]}"; do
    filename=$(basename "$file")
    relative_path=$(python3 -c "import os; print(os.path.relpath('$file', '$XCODE_PROJECT_DIR'))")

    echo "➕ Adding $filename..."

    # Generate unique IDs for Xcode project (simple approach)
    file_ref_id=$(python3 -c "import hashlib; import random; print('EA' + hashlib.md5(('$filename' + str(random.randint(1000,9999))).encode()).hexdigest()[:22].upper())")
    build_file_id=$(python3 -c "import hashlib; import random; print('EB' + hashlib.md5(('$filename' + 'build' + str(random.randint(1000,9999))).encode()).hexdigest()[:22].upper())")

    # Add to PBXBuildFile section
    sed -i '' "/\/\* End PBXBuildFile section \*\//i\\
		$build_file_id /* $filename in Sources */ = {isa = PBXBuildFile; fileRef = $file_ref_id /* $filename */; };
" "$PROJECT_FILE"

    # Add to PBXFileReference section
    sed -i '' "/\/\* End PBXFileReference section \*\//i\\
		$file_ref_id /* $filename */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = $filename; sourceTree = \"<group>\"; };
" "$PROJECT_FILE"

    # Add to Sources build phase
    sed -i '' "/files = (/a\\
				$build_file_id /* $filename in Sources */,
" "$PROJECT_FILE"

    # Add to main group (find the MallOfLebanon-iOS group)
    sed -i '' "/children = (/a\\
				$file_ref_id /* $filename */,
" "$PROJECT_FILE"
done

echo ""
echo "✅ Successfully added all new files to Xcode project!"
echo ""
echo "📋 Summary:"
for file in "${NEW_FILES_FOUND[@]}"; do
    filename=$(basename "$file")
    echo "   ✓ $filename"
done

echo ""
echo "🔄 Next steps:"
echo "   1. Close Xcode if it's open"
echo "   2. Reopen your project in Xcode"
echo "   3. Clean build folder (Cmd+Shift+K)"
echo "   4. Build project (Cmd+B)"
echo ""
echo "💡 If there are any issues, restore from backup:"
echo "   cp \"$PROJECT_FILE.backup\" \"$PROJECT_FILE\""