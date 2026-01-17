#!/usr/bin/env python3

import os
from PIL import Image, ImageDraw, ImageFont
import math

def create_mall_icon(size):
    """Create a Mall of Lebanon app icon"""

    # Create image with rounded corners
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background gradient (Lebanese flag colors inspired)
    # Create a subtle gradient from light blue to white
    for y in range(size):
        # Gradient from blue-teal to white
        blue_val = int(44 + (255 - 44) * (y / size))  # From dark blue to white
        green_val = int(102 + (255 - 102) * (y / size))  # From teal to white
        red_val = int(130 + (255 - 130) * (y / size))   # From blue-grey to white

        for x in range(size):
            img.putpixel((x, y), (red_val, green_val, blue_val, 255))

    # Apply rounded corners
    corner_radius = size // 8  # iOS style corner radius

    # Create a mask for rounded corners
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([(0, 0), (size, size)], corner_radius, fill=255)

    # Apply the mask
    img.putalpha(mask)

    # Now draw the mall/shopping elements
    draw = ImageDraw.Draw(img)

    # Draw shopping bag
    bag_width = size // 3
    bag_height = size // 2.5
    bag_x = size // 2 - bag_width // 2
    bag_y = size // 2 - bag_height // 4

    # Shopping bag body (white with shadow)
    draw.rectangle([bag_x + 2, bag_y + 2, bag_x + bag_width + 2, bag_y + bag_height + 2],
                   fill=(0, 0, 0, 40))  # Shadow
    draw.rectangle([bag_x, bag_y, bag_x + bag_width, bag_y + bag_height],
                   fill=(255, 255, 255, 230))

    # Shopping bag handles
    handle_thickness = size // 25
    handle_width = bag_width // 4
    handle_height = bag_height // 4

    # Left handle
    draw.ellipse([bag_x + bag_width//4 - handle_width//2,
                  bag_y - handle_height//2,
                  bag_x + bag_width//4 + handle_width//2,
                  bag_y + handle_height//2],
                 outline=(44, 102, 130), width=handle_thickness)

    # Right handle
    draw.ellipse([bag_x + 3*bag_width//4 - handle_width//2,
                  bag_y - handle_height//2,
                  bag_x + 3*bag_width//4 + handle_width//2,
                  bag_y + handle_height//2],
                 outline=(44, 102, 130), width=handle_thickness)

    # Add "M" for Mall in a stylish way
    if size >= 60:  # Only add text for larger sizes
        try:
            # Try to use a system font
            font_size = size // 6
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
        except:
            # Fallback to default font
            font = ImageFont.load_default()

        # Draw "M" in the shopping bag
        text = "M"
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]

        text_x = bag_x + bag_width // 2 - text_width // 2
        text_y = bag_y + bag_height // 2 - text_height // 2

        # Text shadow
        draw.text((text_x + 1, text_y + 1), text, fill=(0, 0, 0, 60), font=font)
        # Main text
        draw.text((text_x, text_y), text, fill=(44, 102, 130), font=font)

    # Add small shopping elements (dots representing items)
    if size >= 40:
        dot_size = max(2, size // 40)
        # Small dots around the bag to represent shopping/commerce
        for i in range(3):
            angle = i * 120 * math.pi / 180
            dot_x = size // 2 + int(math.cos(angle) * size // 3.5)
            dot_y = size // 2 + int(math.sin(angle) * size // 3.5)

            draw.ellipse([dot_x - dot_size, dot_y - dot_size,
                         dot_x + dot_size, dot_y + dot_size],
                        fill=(220, 180, 50, 180))  # Golden dots

    return img

def generate_all_icon_sizes():
    """Generate all required iOS app icon sizes"""

    # iOS App Icon sizes (in pixels)
    icon_sizes = [
        (40, "20pt@2x"),    # iPhone Notification
        (60, "20pt@3x"),    # iPhone Notification
        (58, "29pt@2x"),    # iPhone Settings
        (87, "29pt@3x"),    # iPhone Settings
        (80, "40pt@2x"),    # iPhone Spotlight
        (120, "40pt@3x"),   # iPhone Spotlight
        (120, "60pt@2x"),   # iPhone App
        (180, "60pt@3x"),   # iPhone App
        (20, "20pt@1x"),    # iPad Notification
        (40, "20pt@2x"),    # iPad Notification
        (29, "29pt@1x"),    # iPad Settings
        (58, "29pt@2x"),    # iPad Settings
        (40, "40pt@1x"),    # iPad Spotlight
        (80, "40pt@2x"),    # iPad Spotlight
        (152, "76pt@2x"),   # iPad App
        (167, "83.5pt@2x"), # iPad Pro App
        (1024, "1024pt@1x") # App Store
    ]

    base_path = "/Users/ahmadbaba/Desktop/iosapp/MallOfLebanon-iOS/MallOfLebanon-iOS/Assets.xcassets/AppIcon.appiconset/"

    print("🎨 Generating Mall of Lebanon app icons...")

    for size, description in icon_sizes:
        print(f"   Creating {size}x{size} icon ({description})...")
        icon = create_mall_icon(size)

        # Save with proper naming convention
        if size == 1024:
            filename = "icon_1024x1024.png"
        else:
            filename = f"icon_{size}x{size}.png"

        filepath = os.path.join(base_path, filename)
        icon.save(filepath, "PNG")

    print("✅ All app icons generated successfully!")
    return True

if __name__ == "__main__":
    generate_all_icon_sizes()