import os
from PIL import Image, ImageDraw

def create_centered_app_icon(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    red_color = (226, 10, 34, 255)       # #E20A22 FastKirana Signature Red
    white_color = (255, 255, 255, 255)   # #FFFFFF Clean White

    # 1. Main Centered Rounded Squircle (Padding 5% from edges, 90% size)
    padding = size * 0.04
    radius = size * 0.22
    draw.rounded_rectangle(
        [padding, padding, size - padding, size - padding],
        radius=radius,
        fill=red_color
    )

    # 2. Mathematically Centered Bold Italic 'F'
    # Base 100x100 coordinates centered at (50, 50)
    # The bounding box of this F is from X=30 to X=70 (width 40), Y=24 to Y=76 (height 52)
    # Center is at (50, 50)
    center_x = size / 2.0
    center_y = size / 2.0
    scale = size / 100.0

    # Perfectly centered bold italic F polygon coordinates:
    f_points_base = [
        (34.0, 24.0),  # Top-left of top bar
        (68.0, 24.0),  # Top-right of top bar
        (65.0, 35.0),  # Bottom-right of top bar
        (47.5, 35.0),  # Inner top corner
        (45.5, 44.0),  # Inner corner to mid bar
        (61.0, 44.0),  # Mid bar top-right
        (58.5, 54.0),  # Mid bar bottom-right
        (43.0, 54.0),  # Mid bar inner corner
        (38.5, 76.0),  # Bottom-right of stem
        (25.0, 76.0),  # Bottom-left of stem
    ]

    # Shift base coordinates so bounding center is exactly (50, 50)
    min_x = min(p[0] for p in f_points_base)
    max_x = max(p[0] for p in f_points_base)
    min_y = min(p[1] for p in f_points_base)
    max_y = max(p[1] for p in f_points_base)
    orig_cx = (min_x + max_x) / 2.0
    orig_cy = (min_y + max_y) / 2.0

    offset_x = 50.0 - orig_cx
    offset_y = 50.0 - orig_cy

    scaled_points = []
    for px, py in f_points_base:
        x = (px + offset_x) * scale
        y = (py + offset_y) * scale
        scaled_points.append((x, y))

    draw.polygon(scaled_points, fill=white_color)

    return img

def create_adaptive_foreground(size=1024):
    # Android Adaptive Foreground: The logo must stay within the 66dp safe center (62% of canvas)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    
    # Generate centered icon scaled to 70% of canvas
    icon = create_centered_app_icon(int(size * 0.72))
    pos = (size - icon.width) // 2
    img.paste(icon, (pos, pos), icon)
    return img

# 1. Generate Master 1024x1024 App Icon
master = create_centered_app_icon(1024)

# Save Master Brand Assets
assets_brand = r"d:\Fastkirana\fastkirana_flutter\assets\brand"
os.makedirs(assets_brand, exist_ok=True)
master.save(os.path.join(assets_brand, "fastkirana_app_icon.png"), "PNG")
master.save(os.path.join(assets_brand, "fastkirana_exact_logo.png"), "PNG")

# 2. Save Standard Mipmap App Icons (ic_launcher.png)
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
    resized = master.resize(size, Image.Resampling.LANCZOS)
    resized.save(target_path, "PNG")

# Play Store 512x512
master.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(res_dir, "playstore_icon_512.png"), "PNG")

# 3. Save Adaptive Foreground Icons (ic_launcher_foreground.png)
adaptive_master = create_adaptive_foreground(1024)
adaptive_sizes = {
    "mipmap-mdpi": (108, 108),
    "mipmap-hdpi": (162, 162),
    "mipmap-xhdpi": (216, 216),
    "mipmap-xxhdpi": (324, 324),
    "mipmap-xxxhdpi": (432, 432),
}

for folder, size in adaptive_sizes.items():
    target_folder = os.path.join(res_dir, folder)
    target_path = os.path.join(target_folder, "ic_launcher_foreground.png")
    resized = adaptive_master.resize(size, Image.Resampling.LANCZOS)
    resized.save(target_path, "PNG")

# 4. Set Red background for adaptive background in values/colors.xml
values_folder = os.path.join(res_dir, "values")
os.makedirs(values_folder, exist_ok=True)
colors_content = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
"""
with open(os.path.join(values_folder, "colors.xml"), "w", encoding="utf-8") as f:
    f.write(colors_content)

print("[SUCCESS] Mathematically centered, bold, pristine App Launcher Icons generated across all densities!")
