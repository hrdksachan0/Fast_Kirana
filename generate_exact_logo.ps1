Add-Type -AssemblyName System.Drawing

$flutterDir = "d:\Fastkirana\fastkirana_flutter"
$resDir = "$flutterDir\android\app\src\main\res"
$assetsIconDir = "$flutterDir\assets\icon"
$webIconsDir = "$flutterDir\web\icons"
$artifactPath = "C:\Users\Sooraj\.gemini\antigravity\brain\a915c493-7c04-4be2-ab13-117d5df8f75b\exact_logo_preview.png"

$primaryRed = [System.Drawing.ColorTranslator]::FromHtml("#E20A22")
$lightRed = [System.Drawing.ColorTranslator]::FromHtml("#FF1E3C")
$white = [System.Drawing.Color]::White

function Create-RoundedRectanglePath($rect, [float]$radius) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = [float]($radius * 2.0)
    $arcRect = New-Object System.Drawing.RectangleF([float]$rect.X, [float]$rect.Y, $diameter, $diameter)
    
    $path.AddArc($arcRect, [float]180, [float]90)
    $arcRect.X = [float]($rect.Right - $diameter)
    $path.AddArc($arcRect, [float]270, [float]90)
    $arcRect.Y = [float]($rect.Bottom - $diameter)
    $path.AddArc($arcRect, [float]0, [float]90)
    $arcRect.X = [float]$rect.Left
    $path.AddArc($arcRect, [float]90, [float]90)
    
    $path.CloseFigure()
    return $path
}

function Draw-ExactFastKiranaLogo($g, [float]$canvasWidth, [float]$canvasHeight, [float]$scaleFactor) {
    $center = [float]($canvasWidth / 2.0)
    $centerY = [float]($canvasHeight / 2.0)
    
    $brushRed = New-Object System.Drawing.SolidBrush($primaryRed)
    $brushWhite = New-Object System.Drawing.SolidBrush($white)

    # 1. Dimensions
    $boxSize = [float]($canvasHeight * 0.62 * $scaleFactor)
    $boxRadius = [float]($boxSize * 0.28)
    
    # Position: shifted right to perfectly balance the 3 red speed lines on the left
    $boxX = [float]($center - ($boxSize * 0.36))
    $boxY = [float]($centerY - ($boxSize / 2.0))

    # 2. Draw 3 Red Speed Lines extending out on the Left
    $lineH = [float]($boxSize * 0.10)
    $penRed = New-Object System.Drawing.Pen($primaryRed, $lineH)
    $penRed.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penRed.EndCap = [System.Drawing.Drawing2D.LineCap]::Flat

    # Top line
    $l1Y = [float]($boxY + ($boxSize * 0.42))
    $l1Start = [float]($boxX - ($boxSize * 0.28))
    $l1End = [float]($boxX + ($boxSize * 0.10))
    $g.DrawLine($penRed, $l1Start, $l1Y, $l1End, $l1Y)

    # Middle line (longest)
    $l2Y = [float]($boxY + ($boxSize * 0.58))
    $l2Start = [float]($boxX - ($boxSize * 0.44))
    $l2End = [float]($boxX + ($boxSize * 0.10))
    $g.DrawLine($penRed, $l2Start, $l2Y, $l2End, $l2Y)

    # Bottom line
    $l3Y = [float]($boxY + ($boxSize * 0.74))
    $l3Start = [float]($boxX - ($boxSize * 0.30))
    $l3End = [float]($boxX + ($boxSize * 0.10))
    $g.DrawLine($penRed, $l3Start, $l3Y, $l3End, $l3Y)

    # 3. Draw Main Red Squircle
    $boxRect = New-Object System.Drawing.RectangleF($boxX, $boxY, $boxSize, $boxSize)
    $gradBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $boxRect,
        $primaryRed,
        $lightRed,
        [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
    )
    $squirclePath = Create-RoundedRectanglePath $boxRect $boxRadius
    $g.FillPath($gradBrush, $squirclePath)
    $squirclePath.Dispose()
    $gradBrush.Dispose()

    # 4. Draw Bold White Italic "F" inside the Red Squircle
    $fCenter = [float]($boxX + ($boxSize / 2.0))
    $fCenterY = [float]($boxY + ($boxSize / 2.0))

    $fPath = New-Object System.Drawing.Drawing2D.GraphicsPath

    $p1x = [float]($fCenter - ($boxSize * 0.08)); $p1y = [float]($fCenterY - ($boxSize * 0.28))
    $p2x = [float]($fCenter + ($boxSize * 0.26)); $p2y = [float]($fCenterY - ($boxSize * 0.28))
    $p3x = [float]($fCenter + ($boxSize * 0.22)); $p3y = [float]($fCenterY - ($boxSize * 0.13))
    $p4x = [float]($fCenter + ($boxSize * 0.06)); $p4y = [float]($fCenterY - ($boxSize * 0.13))
    $p5x = [float]($fCenter + ($boxSize * 0.04)); $p5y = [float]($fCenterY - ($boxSize * 0.02))
    $p6x = [float]($fCenter + ($boxSize * 0.19)); $p6y = [float]($fCenterY - ($boxSize * 0.02))
    $p7x = [float]($fCenter + ($boxSize * 0.15)); $p7y = [float]($fCenterY + ($boxSize * 0.10))
    $p8x = [float]($fCenter + ($boxSize * 0.01)); $p8y = [float]($fCenterY + ($boxSize * 0.10))
    $p9x = [float]($fCenter - ($boxSize * 0.05)); $p9y = [float]($fCenterY + ($boxSize * 0.30))
    $p10x = [float]($fCenter - ($boxSize * 0.20)); $p10y = [float]($fCenterY + ($boxSize * 0.30))

    $fPath.AddLine($p1x, $p1y, $p2x, $p2y)
    $fPath.AddLine($p2x, $p2y, $p3x, $p3y)
    $fPath.AddLine($p3x, $p3y, $p4x, $p4y)
    $fPath.AddLine($p4x, $p4y, $p5x, $p5y)
    $fPath.AddLine($p5x, $p5y, $p6x, $p6y)
    $fPath.AddLine($p6x, $p6y, $p7x, $p7y)
    $fPath.AddLine($p7x, $p7y, $p8x, $p8y)
    $fPath.AddLine($p8x, $p8y, $p9x, $p9y)
    $fPath.AddLine($p9x, $p9y, $p10x, $p10y)
    $fPath.CloseFigure()

    $g.FillPath($brushWhite, $fPath)
    $fPath.Dispose()

    $brushRed.Dispose()
    $brushWhite.Dispose()
    $penRed.Dispose()
}

# 1. Generate 1024x1024 Master on Clean Pure White Background (#FFFFFF)
$bmp = New-Object System.Drawing.Bitmap(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear($white)

Draw-ExactFastKiranaLogo $g 1024 1024 1.0

$g.Dispose()
$bmp.Save("$assetsIconDir\app_icon.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Save($artifactPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# 2. Generate Android Mipmaps (With White Background for Legacy + Transparent Safe-zone for Adaptive Foreground)
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

    # Legacy icon on clean white
    $mBmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $mg = [System.Drawing.Graphics]::FromImage($mBmp)
    $mg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $mg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $mg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $mg.Clear($white)

    Draw-ExactFastKiranaLogo $mg ([float]$size) ([float]$size) ([float]1.0)

    $mg.Dispose()
    $mBmp.Save("$destFolder\ic_launcher.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $mBmp.Save("$destFolder\ic_launcher_round.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $mBmp.Dispose()
    
    # Adaptive Foreground (Transparent, Centered in safe zone)
    $fgBmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $fgg = [System.Drawing.Graphics]::FromImage($fgBmp)
    $fgg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $fgg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $fgg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $fgg.Clear([System.Drawing.Color]::Transparent)

    Draw-ExactFastKiranaLogo $fgg ([float]$size) ([float]$size) ([float]0.95)

    $fgg.Dispose()
    $fgBmp.Save("$destFolder\ic_launcher_foreground.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $fgBmp.Dispose()
}

# 3. Web Icons on White
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
    $wg.Clear($white)

    Draw-ExactFastKiranaLogo $wg ([float]$wsize) ([float]$wsize) ([float]1.0)

    $wg.Dispose()
    $wBmp.Save("$webIconsDir\$fname", [System.Drawing.Imaging.ImageFormat]::Png)
    $wBmp.Dispose()
}

Write-Host "Generated White Background FastKirana Logo & All Density Mipmaps!"
