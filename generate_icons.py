import os
from PIL import Image

src_icon = r"d:\Fastkirana\fastkirana_flutter\assets\brand\fastkirana_app_icon.png"
if not os.path.exists(src_icon):
    src_icon = r"d:\Fastkirana\fastkirana_flutter\assets\brand\fastkirana_exact_logo.png"

print(f"Using source icon: {src_icon}")

img = Image.open(src_icon)
print(f"Source size: {img.size}, mode: {img.mode}")

# Android launcher sizes
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
    resized = img.resize(size, Image.Resampling.LANCZOS)
    resized.save(target_path, "PNG")
    print(f"Saved {size} to {target_path}")

# Play Store 512x512 icon
playstore_icon = r"d:\Fastkirana\fastkirana_flutter\android\app\src\main\res\playstore_icon_512.png"
resized_512 = img.resize((512, 512), Image.Resampling.LANCZOS)
resized_512.save(playstore_icon, "PNG")
print(f"Saved 512x512 Play Store icon to {playstore_icon}")

print("Launcher icons generated successfully!")
