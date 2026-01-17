#!/usr/bin/env python3

import os
import hashlib
import random
import re

# Configuration
XCODE_PROJECT_DIR = "/Users/ahmadbaba/Desktop/iosapp/MallOfLebanon-iOS"
PROJECT_FILE = f"{XCODE_PROJECT_DIR}/MallOfLebanon-iOS.xcodeproj/project.pbxproj"
SOURCE_DIR = f"{XCODE_PROJECT_DIR}/MallOfLebanon-iOS"

# Group mappings based on file types
GROUP_MAPPINGS = {
    "Models": "EA9261AA2EE49259002C9A7A",
    "Services": "EA9261A32EE49238002C9A7A",
    "Views/Authentication": "EA9261B02EE49259002C9A7A",
    "Views/Cart": "EA9261B12EE49259002C9A7A",
    "Views/Shopping": "EA9261B22EE49259002C9A7A",
    "MallOfLebanon-iOS": "E20001020000000000000001"
}

def get_group_for_file(filename):
    """Determine which group a file should go into based on its name."""
    if filename.endswith("Models.swift"):
        return "Models", GROUP_MAPPINGS["Models"]
    elif filename.endswith(("Manager.swift", "Service.swift")):
        return "Services", GROUP_MAPPINGS["Services"]
    elif filename.endswith("ViewModel.swift"):
        return "Models", GROUP_MAPPINGS["Models"]  # ViewModels go with Models
    elif filename.endswith("View.swift"):
        if any(x in filename for x in ["Login", "Register"]):
            return "Views/Authentication", GROUP_MAPPINGS["Views/Authentication"]
        elif "Cart" in filename:
            return "Views/Cart", GROUP_MAPPINGS["Views/Cart"]
        elif any(x in filename for x in ["Product", "Shopping"]):
            return "Views/Shopping", GROUP_MAPPINGS["Views/Shopping"]
        else:
            return "Views", GROUP_MAPPINGS["MallOfLebanon-iOS"]  # Default to main group
    elif filename.startswith("ContentView_"):
        return "MallOfLebanon-iOS", GROUP_MAPPINGS["MallOfLebanon-iOS"]
    else:
        return "MallOfLebanon-iOS", GROUP_MAPPINGS["MallOfLebanon-iOS"]

def generate_unique_id(filename, prefix="EA"):
    """Generate a unique ID for Xcode project files."""
    unique_str = f"{filename}{random.randint(1000, 9999)}"
    hash_obj = hashlib.md5(unique_str.encode())
    return prefix + hash_obj.hexdigest()[:22].upper()

def find_new_swift_files():
    """Find Swift files that are not yet in the project."""
    new_files = []

    # Get all Swift files in the project directory
    for root, dirs, files in os.walk(SOURCE_DIR):
        for file in files:
            if file.endswith('.swift'):
                file_path = os.path.join(root, file)

                # Skip main app files and files already in project
                if file not in ['MallOfLebanon_iOSApp.swift', 'ContentView.swift']:
                    # Read project file to check if file is already there
                    with open(PROJECT_FILE, 'r') as f:
                        if file not in f.read():
                            new_files.append((file_path, file))

    return new_files

def update_project_file(new_files):
    """Update the project file with new Swift files in organized groups."""

    # Read the current project file
    with open(PROJECT_FILE, 'r') as f:
        content = f.read()

    # Backup
    with open(PROJECT_FILE + ".backup", 'w') as f:
        f.write(content)
    print("💾 Created backup: project.pbxproj.backup")

    build_files_to_add = []
    file_refs_to_add = []
    sources_to_add = []
    group_additions = {}

    for file_path, filename in new_files:
        group_name, group_id = get_group_for_file(filename)

        # Generate unique IDs
        file_ref_id = generate_unique_id(filename, "EA")
        build_file_id = generate_unique_id(filename + "build", "EB")

        print(f"➕ Adding {filename} to {group_name}...")

        # Prepare additions
        build_files_to_add.append(
            f"\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};"
        )

        file_refs_to_add.append(
            f"\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};"
        )

        sources_to_add.append(
            f"\t\t\t\t{build_file_id} /* {filename} in Sources */,"
        )

        # Group additions
        if group_id not in group_additions:
            group_additions[group_id] = []
        group_additions[group_id].append(
            f"\t\t\t\t{file_ref_id} /* {filename} */,"
        )

    # Apply changes to content

    # 1. Add PBXBuildFile entries
    build_section_end = "/* End PBXBuildFile section */"
    if build_section_end in content:
        content = content.replace(
            build_section_end,
            "\n".join(build_files_to_add) + "\n" + build_section_end
        )

    # 2. Add PBXFileReference entries
    file_ref_section_end = "/* End PBXFileReference section */"
    if file_ref_section_end in content:
        content = content.replace(
            file_ref_section_end,
            "\n".join(file_refs_to_add) + "\n" + file_ref_section_end
        )

    # 3. Add to Sources build phase
    sources_pattern = r"(E19999940000000000000000 /\* Sources \*/ = \{[^}]+files = \([^)]*)"
    sources_match = re.search(sources_pattern, content, re.DOTALL)
    if sources_match:
        existing_sources = sources_match.group(1)
        new_sources = existing_sources + "\n" + "\n".join(sources_to_add)
        content = content.replace(existing_sources, new_sources)

    # 4. Add files to their respective groups
    for group_id, files_to_add in group_additions.items():
        # Find the group and add files to its children
        group_pattern = f"({group_id} /\\* .* \\*/ = \\{{[^}}]+children = \\([^)]*)"
        group_match = re.search(group_pattern, content, re.DOTALL)
        if group_match:
            existing_group = group_match.group(1)
            new_group = existing_group + "\n" + "\n".join(files_to_add)
            content = content.replace(existing_group, new_group)

    # Write the updated content
    with open(PROJECT_FILE, 'w') as f:
        f.write(content)

def main():
    print("🔍 Scanning for new Swift files...")
    new_files = find_new_swift_files()

    if not new_files:
        print("✅ All Swift files are already in the Xcode project!")
        return

    print(f"🛠️  Adding {len(new_files)} new files to Xcode project...")

    update_project_file(new_files)

    print("\n✅ Successfully added all new files to Xcode project with proper organization!")
    print("\n📋 Summary:")
    for file_path, filename in new_files:
        group_name, _ = get_group_for_file(filename)
        print(f"   ✓ {filename} → {group_name}")

    print("\n🔄 Next steps:")
    print("   1. Close Xcode if it's open")
    print("   2. Reopen your project in Xcode")
    print("   3. Clean build folder (Cmd+Shift+K)")
    print("   4. Build project (Cmd+B)")

if __name__ == "__main__":
    main()