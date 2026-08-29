import os
from PIL import Image, ImageDraw

def create_fastkirana_app_icon(canvas_size=1024):
    # Supersampled high-res canvas (1024x1024)
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Scale coordinates from 140x120 base viewbox to 1024x1024 with padding
    scale = canvas_size / 130.0
    offset_x = 2 * scale
    offset_y = 5 * scale

    red_color = (226, 10, 34, 255) # #E20A22
    white_color = (255, 255, 255, 255)

    def sx(x): return x * scale + offset_x
    def sy(y): return y * scale + offset_y

    # 1. Left Speed Lines
    draw.rounded_rectangle([sx(8), sy(44), sx(30), sy(50.5)], radius=3.25*scale, fill=red_color)
    draw.rounded_rectangle([sx(0.5), sy(58), sx(30), sy(64.5)], radius=3.25*scale, fill=red_color)
    draw.rounded_rectangle([sx(8), sy(72), sx(30), sy(78.5)], radius=3.25*scale, fill=red_color)
    
    # Circle dot
    r = 3 * scale
    cx, cy = sx(2), sy(61.25)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=red_color)

    # 2. Main Red Solid Rounded Square Container
    draw.rounded_rectangle(
        [sx(25), sy(10), sx(125), sy(110)],
        radius=28 * scale,
        fill=red_color
    )

    # 3. Clean Bold Italic Sans-Serif Block 'F' in White
    f_points = [
        (sx(62), sy(32)),
        (sx(98), sy(32)),
        (sx(95), sy(46)),
        (sx(75.5), sy(46)),
        (sx(73.4), sy(56)),
        (sx(89), sy(56)),
        (sx(86.5), sy(68)),
        (sx(71), sy(68)),
        (sx(66.8), sy(88)),
        (sx(50.2), sy(88)),
    ]
    draw.polygon(f_points, fill=white_color)

    return img

# Generate Master 1024x1024 Icon
master_icon = create_fastkirana_app_icon(1024)

# Also save master brand assets
assets_brand = r"d:\Fastkirana\fastkirana_flutter\assets\brand"
os.makedirs(assets_brand, exist_ok=True)
master_icon.save(os.path.join(assets_brand, "fastkirana_app_icon.png"), "PNG")
master_icon.save(os.path.join(assets_brand, "fastkirana_exact_logo.png"), "PNG")
print("Saved master logo to assets/brand/")

# Save Android Mipmaps
res_dir = r"d:\Fastkirana\fastkirana_flutter\android\app\src\main\res"
sizes = {
    "mipmap-mdpi": (48, 48),
    "mipmap-hdpi": (72, 72),
    "mipmap-xhdpi": (96, 96),
    "mipmap-xxhdpi": (144, 144),
    "mipmap-xxxhdpi": (192, 192),
}

for folder, size in sizes.items():
    target_folder = os.path.join(res_dir, folder)
    os.makedirs(target_folder, exist_ok=True)
    target_path = os.path.join(target_folder, "ic_launcher.png")
    resized = master_icon.resize(size, Image.Resampling.LANCZOS)
    resized.save(target_path, "PNG")
    print(f"Generated {size} -> {target_path}")

# Play Store 512x512
playstore_path = os.path.join(res_dir, "playstore_icon_512.png")
master_icon.resize((512, 512), Image.Resampling.LANCZOS).save(playstore_path, "PNG")
print(f"Generated 512x512 -> {playstore_path}")

print("All Android launcher icons matching Login page logo generated successfully!")
