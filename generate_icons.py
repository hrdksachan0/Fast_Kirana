import os
import shutil
from PIL import Image, ImageOps

source_img_path = r"C:\Users\Sooraj\.gemini\antigravity\brain\a915c493-7c04-4be2-ab13-117d5df8f75b\.user_uploaded\media_1787842877683.png"
flutter_dir = r"d:\Fastkirana\fastkirana_flutter"
android_res_dir = os.path.join(flutter_dir, "android", "app", "src", "main", "res")
assets_icon_dir = os.path.join(flutter_dir, "assets", "icon")
web_icons_dir = os.path.join(flutter_dir, "web", "icons")

os.makedirs(assets_icon_dir, exist_ok=True)
os.makedirs(web_icons_dir, exist_ok=True)

# 1. Load source image
img = Image.open(source_img_path).convert("RGBA")

# Crop any transparent/white margins if needed
bbox = img.getbbox()
if bbox:
    img = img.crop(bbox)

# Create high-res 1024x1024 master icon centered
master_size = 1024
master_icon = Image.new("RGBA", (master_size, master_size), (0, 0, 0, 0))

# Scale source maintaining aspect ratio to fit inside ~85% of master
target_w = int(master_size * 0.88)
target_h = int(target_w * (img.height / img.width))
if target_h > int(master_size * 0.88):
    target_h = int(master_size * 0.88)
    target_w = int(target_h * (img.width / img.height))

img_resized = img.resize((target_w, target_h), Image.Resampling.LANCZOS)
pos_x = (master_size - target_w) // 2
pos_y = (master_size - target_h) // 2
master_icon.paste(img_resized, (pos_x, pos_y), img_resized)

# Save master icon
master_icon_path = os.path.join(assets_icon_dir, "app_icon.png")
master_icon.save(master_icon_path, format="PNG")
print("Saved master icon:", master_icon_path)

# Android Mipmap sizes
mipmap_sizes = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

for folder, size in mipmap_sizes.items():
    dest_dir = os.path.join(android_res_dir, folder)
    os.makedirs(dest_dir, exist_ok=True)
    
    # ic_launcher.png
    scaled = master_icon.resize((size, size), Image.Resampling.LANCZOS)
    scaled.save(os.path.join(dest_dir, "ic_launcher.png"), format="PNG")
    scaled.save(os.path.join(dest_dir, "ic_launcher_round.png"), format="PNG")
    
    # Adaptive foreground (standard 432x432 base scaled for mipmap, or scaled icon with margin)
    fg_size = int(size * 1.5)
    fg = Image.new("RGBA", (fg_size, fg_size), (0, 0, 0, 0))
    fg_inner = master_icon.resize((int(fg_size * 0.65), int(fg_size * 0.65)), Image.Resampling.LANCZOS)
    fg_pos = ((fg_size - fg_inner.width) // 2, (fg_size - fg_inner.height) // 2)
    fg.paste(fg_inner, fg_pos, fg_inner)
    fg_final = fg.resize((size, size), Image.Resampling.LANCZOS)
    fg_final.save(os.path.join(dest_dir, "ic_launcher_foreground.png"), format="PNG")

print("All Android launcher mipmaps generated successfully!")

# Web icons
web_sizes = {
    "Icon-192.png": 192,
    "Icon-512.png": 512,
    "Icon-maskable-192.png": 192,
    "Icon-maskable-512.png": 512,
    "favicon.png": 64,
}

for fname, wsize in web_sizes.items():
    wscaled = master_icon.resize((wsize, wsize), Image.Resampling.LANCZOS)
    wscaled.save(os.path.join(web_icons_dir, fname), format="PNG")

print("All Web icons generated successfully!")
