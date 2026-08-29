Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\Sooraj\.gemini\antigravity\brain\a915c493-7c04-4be2-ab13-117d5df8f75b\.user_uploaded\media_1787842877683.png"
$flutterDir = "d:\Fastkirana\fastkirana_flutter"
$resDir = "$flutterDir\android\app\src\main\res"
$assetsIconDir = "$flutterDir\assets\icon"
$webIconsDir = "$flutterDir\web\icons"

if (-not (Test-Path $assetsIconDir)) { New-Item -ItemType Directory -Path $assetsIconDir -Force }
if (-not (Test-Path $webIconsDir)) { New-Item -ItemType Directory -Path $webIconsDir -Force }

$srcBitmap = [System.Drawing.Bitmap]::FromFile($srcPath)

function Resize-Image($source, $targetWidth, $targetHeight, $destPath) {
    $destBitmap = New-Object System.Drawing.Bitmap($targetWidth, $targetHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($destBitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)

    # Center source image
    $aspectSrc = $source.Width / $source.Height
    $aspectTarget = $targetWidth / $targetHeight
    
    $drawW = $targetWidth
    $drawH = $targetHeight
    if ($aspectSrc -gt $aspectTarget) {
        $drawH = [int]($targetWidth / $aspectSrc)
    } else {
        $drawW = [int]($targetHeight * $aspectSrc)
    }
    
    $posX = [int](($targetWidth - $drawW) / 2)
    $posY = [int](($targetHeight - $drawH) / 2)

    $graphics.DrawImage($source, $posX, $posY, $drawW, $drawH)
    $graphics.Dispose()

    $destBitmap.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBitmap.Dispose()
}

# 1. Master Icon
Resize-Image $srcBitmap 1024 1024 "$assetsIconDir\app_icon.png"
Write-Host "Saved master icon: $assetsIconDir\app_icon.png"

# 2. Android Mipmaps
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

    Resize-Image $srcBitmap $size $size "$destFolder\ic_launcher.png"
    Resize-Image $srcBitmap $size $size "$destFolder\ic_launcher_round.png"
    Resize-Image $srcBitmap $size $size "$destFolder\ic_launcher_foreground.png"
}
Write-Host "All Android mipmaps saved successfully!"

# 3. Web Icons
Resize-Image $srcBitmap 192 192 "$webIconsDir\Icon-192.png"
Resize-Image $srcBitmap 512 512 "$webIconsDir\Icon-512.png"
Resize-Image $srcBitmap 192 192 "$webIconsDir\Icon-maskable-192.png"
Resize-Image $srcBitmap 512 512 "$webIconsDir\Icon-maskable-512.png"
Resize-Image $srcBitmap 64 64 "$webIconsDir\favicon.png"
Write-Host "All Web icons saved successfully!"

$srcBitmap.Dispose()
