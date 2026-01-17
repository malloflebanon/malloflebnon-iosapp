#!/usr/bin/env python3

import os
from PIL import Image, ImageDraw, ImageFont
import math

def create_mol_icon(size):
    """Create a Mall of Lebanon app icon with MOL acronym"""

    # Create image with rounded corners
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background gradient (Lebanese flag colors inspired - red, white, green)
    # Create a subtle gradient
    for y in range(size):
        # Gradient from Lebanese red to white to green
        if y < size // 3:
            # Top third - Lebanese red
            red_val = int(220 - (220 - 255) * (y / (size // 3)))
            green_val = int(20 + (255 - 20) * (y / (size // 3)))
            blue_val = int(20 + (255 - 20) * (y / (size // 3)))
        elif y < 2 * size // 3:
            # Middle third - white
            red_val = 255
            green_val = 255
            blue_val = 255
        else:
            # Bottom third - Lebanese green
            y_offset = y - 2 * size // 3
            red_val = int(255 - (255 - 0) * (y_offset / (size // 3)))
            green_val = int(255 - (255 - 150) * (y_offset / (size // 3)))
            blue_val = int(255 - (255 - 0) * (y_offset / (size // 3)))

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

    # Draw a more prominent background circle/badge for MOL text
    badge_size = int(size * 0.7)
    badge_x = size // 2 - badge_size // 2
    badge_y = size // 2 - badge_size // 2

    # White circle background with shadow for the MOL text
    shadow_offset = max(1, size // 40)
    draw.ellipse([badge_x + shadow_offset, badge_y + shadow_offset,
                  badge_x + badge_size + shadow_offset, badge_y + badge_size + shadow_offset],
                 fill=(0, 0, 0, 60))  # Shadow

    # Main white circle
    draw.ellipse([badge_x, badge_y, badge_x + badge_size, badge_y + badge_size],
                 fill=(255, 255, 255, 240))

    # Circle border
    border_width = max(1, size // 30)
    draw.ellipse([badge_x, badge_y, badge_x + badge_size, badge_y + badge_size],
                 outline=(44, 102, 130), width=border_width)

    # Add "MOL" text
    if size >= 40:  # Only add text for larger sizes
        try:
            # Try to use a system font - bold for better visibility
            font_size = max(int(size * 0.15), 8)
            try:
                font = ImageFont.truetype("/System/Library/Fonts/Helvetica-Bold.ttc", font_size)
            except:
                try:
                    font = ImageFont.truetype("/System/Library/Fonts/Arial-BoldMT.ttc", font_size)
                except:
                    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
        except:
            # Fallback to default font
            font = ImageFont.load_default()

        # Draw "MOL" in the circle
        text = "MOL"
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]

        text_x = size // 2 - text_width // 2
        text_y = size // 2 - text_height // 2

        # Text shadow
        shadow_offset = max(1, size // 80)
        draw.text((text_x + shadow_offset, text_y + shadow_offset), text, fill=(0, 0, 0, 100), font=font)
        # Main text - dark blue
        draw.text((text_x, text_y), text, fill=(25, 60, 90), font=font)

    # Add small shopping cart or bag icons around the circle for larger sizes
    if size >= 60:
        # Shopping cart at top right
        cart_size = size // 8
        cart_x = int(size * 0.75)
        cart_y = int(size * 0.2)

        # Simple cart outline
        draw.rectangle([cart_x, cart_y + cart_size//3, cart_x + cart_size, cart_y + cart_size],
                      outline=(200, 150, 50), width=max(1, size // 60))
        # Cart handle
        draw.arc([cart_x - cart_size//4, cart_y, cart_x + cart_size//4, cart_y + cart_size//2],
                start=180, end=0, fill=(200, 150, 50), width=max(1, size // 60))

        # Shopping bag at bottom left
        bag_size = size // 10
        bag_x = int(size * 0.15)
        bag_y = int(size * 0.7)

        # Bag body
        draw.rectangle([bag_x, bag_y, bag_x + bag_size, bag_y + bag_size],
                      fill=(180, 140, 40), outline=(150, 110, 30), width=1)
        # Bag handles
        handle_size = bag_size // 3
        draw.arc([bag_x + bag_size//4 - handle_size//2, bag_y - handle_size//2,
                  bag_x + bag_size//4 + handle_size//2, bag_y + handle_size//2],
                start=0, end=180, fill=(150, 110, 30), width=max(1, size // 80))
        draw.arc([bag_x + 3*bag_size//4 - handle_size//2, bag_y - handle_size//2,
                  bag_x + 3*bag_size//4 + handle_size//2, bag_y + handle_size//2],
                start=0, end=180, fill=(150, 110, 30), width=max(1, size // 80))

    return img

def generate_all_mol_icons():
    """Generate all required iOS app icon sizes with MOL"""

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

    print("🎨 Generating Mall of Lebanon (MOL) app icons...")

    for size, description in icon_sizes:
        print(f"   Creating {size}x{size} MOL icon ({description})...")
        icon = create_mol_icon(size)

        # Save with proper naming convention
        if size == 1024:
            filename = "icon_1024x1024.png"
        else:
            filename = f"icon_{size}x{size}.png"

        filepath = os.path.join(base_path, filename)
        icon.save(filepath, "PNG")

    print("✅ All MOL app icons generated successfully!")
    return True

if __name__ == "__main__":
    generate_all_mol_icons()