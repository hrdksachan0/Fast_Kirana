import os
from PIL import Image

# Read master icon
master_path = r"d:\Fastkirana\fastkirana_flutter\assets\brand\fastkirana_app_icon.png"
master = Image.open(master_path)

res_dir = r"d:\Fastkirana\fastkirana_flutter\android\app\src\main\res"

# Generate ic_launcher_foreground for each mipmap with comfortable adaptive padding (70% scale)
sizes = {
    "mipmap-mdpi": (108, 108),
    "mipmap-hdpi": (162, 162),
    "mipmap-xhdpi": (216, 216),
    "mipmap-xxhdpi": (324, 324),
    "mipmap-xxxhdpi": (432, 432),
}

for folder, size in sizes.items():
    target_folder = os.path.join(res_dir, folder)
    os.makedirs(target_folder, exist_ok=True)
    
    # Create transparent 108dp canvas
    foreground = Image.new("RGBA", size, (0, 0, 0, 0))
    
    # Scale logo to ~72% of canvas to fit within Android adaptive safe zone (66dp)
    logo_size = int(size[0] * 0.72)
    logo_resized = master.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
    
    # Center logo on canvas
    pos_x = (size[0] - logo_size) // 2
    pos_y = (size[1] - logo_size) // 2
    foreground.paste(logo_resized, (pos_x, pos_y), logo_resized)
    
    fg_path = os.path.join(target_folder, "ic_launcher_foreground.png")
    foreground.save(fg_path, "PNG")
    print(f"Saved adaptive foreground to {fg_path}")

# Create mipmap-anydpi-v26/ic_launcher.xml
anydpi_folder = os.path.join(res_dir, "mipmap-anydpi-v26")
os.makedirs(anydpi_folder, exist_ok=True)
xml_content = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
with open(os.path.join(anydpi_folder, "ic_launcher.xml"), "w", encoding="utf-8") as f:
    f.write(xml_content)

# Add ic_launcher_background color in values/colors.xml
values_folder = os.path.join(res_dir, "values")
os.makedirs(values_folder, exist_ok=True)
colors_content = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
"""
with open(os.path.join(values_folder, "colors.xml"), "w", encoding="utf-8") as f:
    f.write(colors_content)

print("Adaptive icon XML & foregrounds generated successfully!")
