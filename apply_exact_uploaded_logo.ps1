Add-Type -AssemblyName System.Drawing

$srcImgPath = "C:\Users\Sooraj\.gemini\antigravity\brain\a915c493-7c04-4be2-ab13-117d5df8f75b\.user_uploaded\media_1787845973556.png"
$flutterDir = "d:\Fastkirana\fastkirana_flutter"
$resDir = "$flutterDir\android\app\src\main\res"
$assetsIconDir = "$flutterDir\assets\icon"
$webIconsDir = "$flutterDir\web\icons"

# 1. Copy directly to master app_icon.png
Copy-Item -Path $srcImgPath -Destination "$assetsIconDir\app_icon.png" -Force

$srcBmp = [System.Drawing.Image]::FromFile($srcImgPath)

# 2. Generate Mipmaps
$mipmaps = @{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

foreach ($folder in $mipmaps.Keys) {
    $size = $mipmaps[$folder]
    $destFolder = "$resDir\$folder"
    if (-not (Test-Path $destFolder)) { New-Item -ItemType Directory -Path $destFolder -Force }

    # Legacy squircle & round icon
    $mBmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $mg = [System.Drawing.Graphics]::FromImage($mBmp)
    $mg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $mg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $mg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $mg.Clear([System.Drawing.Color]::Transparent)

    $destRect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $mg.DrawImage($srcBmp, $destRect)

    $mg.Dispose()
    $mBmp.Save("$destFolder\ic_launcher.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $mBmp.Save("$destFolder\ic_launcher_round.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $mBmp.Dispose()

    # Adaptive foreground (scaled 72% centered with transparent padding)
    $fgBmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $fgg = [System.Drawing.Graphics]::FromImage($fgBmp)
    $fgg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $fgg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $fgg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $fgg.Clear([System.Drawing.Color]::Transparent)

    $fgSize = [int]($size * 0.72)
    $fgOffset = [int](($size - $fgSize) / 2)
    $fgRect = New-Object System.Drawing.Rectangle($fgOffset, $fgOffset, $fgSize, $fgSize)
    $fgg.DrawImage($srcBmp, $fgRect)

    $fgg.Dispose()
    $fgBmp.Save("$destFolder\ic_launcher_foreground.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $fgBmp.Dispose()
}

# 3. Web Icons
$webSizes = @{
    "Icon-192.png" = 192
    "Icon-512.png" = 512
    "Icon-maskable-192.png" = 192
    "Icon-maskable-512.png" = 512
    "favicon.png" = 64
}

foreach ($fname in $webSizes.Keys) {
    $wsize = $webSizes[$fname]
    $wBmp = New-Object System.Drawing.Bitmap($wsize, $wsize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $wg = [System.Drawing.Graphics]::FromImage($wBmp)
    $wg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $wg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $wg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $wg.Clear([System.Drawing.Color]::Transparent)

    $wRect = New-Object System.Drawing.Rectangle(0, 0, $wsize, $wsize)
    $wg.DrawImage($srcBmp, $wRect)

    $wg.Dispose()
    $wBmp.Save("$webIconsDir\$fname", [System.Drawing.Imaging.ImageFormat]::Png)
    $wBmp.Dispose()
}

$srcBmp.Dispose()
Write-Host "Applied uploaded logo to all mipmaps and web assets!"
