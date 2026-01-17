#!/bin/bash

# Smart Xcode Project Organizer
# Automatically adds Swift files to proper folder structure in Xcode project

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

    # Skip files already in project or that should be ignored
    if ! grep -q "$filename" "$PROJECT_FILE" && [[ ! "$filename" =~ ^(MallOfLebanon_iOSApp|ContentView)\.swift$ ]]; then
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

# Function to determine the correct group ID based on file type
get_group_id_for_file() {
    local filename="$1"

    case "$filename" in
        *Models.swift)
            echo "EA9261AA2EE49259002C9A7A"  # Models group
            ;;
        *Manager.swift)
            echo "EA9261A32EE49238002C9A7A"   # Services group
            ;;
        *Service.swift)
            echo "EA9261A32EE49238002C9A7A"   # Services group
            ;;
        *ViewModel.swift)
            echo "EA9261AA2EE49259002C9A7A"   # Models group (ViewModels go with Models)
            ;;
        *View.swift)
            if [[ "$filename" == *"Login"* || "$filename" == *"Register"* ]]; then
                echo "EA9261B02EE49259002C9A7A"  # Authentication group
            elif [[ "$filename" == *"Cart"* ]]; then
                echo "EA9261B12EE49259002C9A7A"  # Cart group
            elif [[ "$filename" == *"Product"* || "$filename" == *"Shopping"* ]]; then
                echo "EA9261B22EE49259002C9A7A"  # Shopping group
            else
                echo "EA9261B42EE49259002C9A7A"  # General Views group
            fi
            ;;
        ContentView_*.swift)
            echo "E20001020000000000000001"   # Main MallOfLebanon-iOS group
            ;;
        *)
            echo "E20001020000000000000001"   # Default to main group
            ;;
    esac
}

# Function to get group name for display
get_group_name() {
    local group_id="$1"

    case "$group_id" in
        "EA9261AA2EE49259002C9A7A")
            echo "Models"
            ;;
        "EA9261A32EE49238002C9A7A")
            echo "Services"
            ;;
        "EA9261B02EE49259002C9A7A")
            echo "Views/Authentication"
            ;;
        "EA9261B12EE49259002C9A7A")
            echo "Views/Cart"
            ;;
        "EA9261B22EE49259002C9A7A")
            echo "Views/Shopping"
            ;;
        "EA9261B42EE49259002C9A7A")
            echo "Views"
            ;;
        *)
            echo "MallOfLebanon-iOS"
            ;;
    esac
}

# For each new file, add it to the project in the correct group
for file in "${NEW_FILES_FOUND[@]}"; do
    filename=$(basename "$file")
    group_id=$(get_group_id_for_file "$filename")
    group_name=$(get_group_name "$group_id")

    echo "➕ Adding $filename to $group_name..."

    # Generate unique IDs for Xcode project
    file_ref_id=$(python3 -c "import hashlib; import random; print('EA' + hashlib.md5(('$filename' + str(random.randint(1000,9999))).encode()).hexdigest()[:22].upper())")
    build_file_id=$(python3 -c "import hashlib; import random; print('EB' + hashlib.md5(('$filename' + 'build' + str(random.randint(1000,9999))).encode()).hexdigest()[:22].upper())")

    # Add to PBXBuildFile section
    sed -i '' "/\/\* End PBXBuildFile section \*\//i\\
		$build_file_id /* $filename in Sources */ = {isa = PBXBuildFile; fileRef = $file_ref_id /* $filename */; };\\
" "$PROJECT_FILE"

    # Add to PBXFileReference section
    sed -i '' "/\/\* End PBXFileReference section \*\//i\\
		$file_ref_id /* $filename */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = $filename; sourceTree = \"<group>\"; };\\
" "$PROJECT_FILE"

    # Add to Sources build phase
    sed -i '' "/buildActionMask = 2147483647;/,/files = (/a\\
				$build_file_id /* $filename in Sources */,\\
" "$PROJECT_FILE"

    # Add to the specific group
    sed -i '' "/$group_id \/\* .* \*\/ = {/,/children = (/a\\
				$file_ref_id /* $filename */,\\
" "$PROJECT_FILE"
done

echo ""
echo "✅ Successfully added all new files to Xcode project with proper organization!"
echo ""
echo "📋 Summary:"
for file in "${NEW_FILES_FOUND[@]}"; do
    filename=$(basename "$file")
    group_name=$(get_group_name "$(get_group_id_for_file "$filename")")
    echo "   ✓ $filename → $group_name"
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