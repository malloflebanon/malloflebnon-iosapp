#!/usr/bin/env python3

import os
from PIL import Image, ImageDraw, ImageFont

def create_simple_test_icon(size):
    """Create a very simple test icon that iOS will definitely accept"""

    # Create square image with solid background
    img = Image.new('RGB', (size, size), (70, 130, 180))  # Steel blue
    draw = ImageDraw.Draw(img)

    # Draw a simple white circle
    margin = size // 6
    draw.ellipse([margin, margin, size - margin, size - margin], fill='white')

    # Add simple text "MOL"
    if size >= 40:
        try:
            font_size = max(size // 6, 12)
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica-Bold.ttc", font_size)
        except:
            font = ImageFont.load_default()

        text = "MOL"
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]

        text_x = size // 2 - text_width // 2
        text_y = size // 2 - text_height // 2

        draw.text((text_x, text_y), text, fill='black', font=font)

    return img

def generate_simple_icons():
    """Generate simple test icons for all required sizes"""

    icon_sizes = [
        (40, "20pt@2x"), (60, "20pt@3x"), (58, "29pt@2x"), (87, "29pt@3x"),
        (80, "40pt@2x"), (120, "40pt@3x"), (120, "60pt@2x"), (180, "60pt@3x"),
        (20, "20pt@1x"), (40, "20pt@2x"), (29, "29pt@1x"), (58, "29pt@2x"),
        (40, "40pt@1x"), (80, "40pt@2x"), (152, "76pt@2x"), (167, "83.5pt@2x"),
        (1024, "1024pt@1x")
    ]

    base_path = "/Users/ahmadbaba/Desktop/iosapp/MallOfLebanon-iOS/MallOfLebanon-iOS/Assets.xcassets/AppIcon.appiconset/"

    print("🔧 Creating simple test icons for debugging...")

    for size, description in icon_sizes:
        print(f"   Creating simple {size}x{size} icon...")
        icon = create_simple_test_icon(size)

        if size == 1024:
            filename = "icon_1024x1024.png"
        else:
            filename = f"icon_{size}x{size}.png"

        filepath = os.path.join(base_path, filename)
        icon.save(filepath, "PNG", optimize=True, quality=95)

    print("✅ Simple test icons created successfully!")
    return True

if __name__ == "__main__":
    generate_simple_icons()