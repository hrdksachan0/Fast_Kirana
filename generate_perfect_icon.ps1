Add-Type -AssemblyName System.Drawing

$flutterDir = "d:\Fastkirana\fastkirana_flutter"
$resDir = "$flutterDir\android\app\src\main\res"
$assetsIconDir = "$flutterDir\assets\icon"
$webIconsDir = "$flutterDir\web\icons"

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

function Draw-VectorFLogo($g, [float]$canvasSize, [float]$scaleFactor) {
    $center = [float]($canvasSize / 2.0)
    $brushWhite = New-Object System.Drawing.SolidBrush($white)

    # 1. High Precision Geometric Vector 'F'
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath

    $p1x = [float]($center - ($canvasSize * 0.04 * $scaleFactor)); $p1y = [float]($center - ($canvasSize * 0.28 * $scaleFactor))
    $p2x = [float]($center + ($canvasSize * 0.28 * $scaleFactor)); $p2y = [float]($center - ($canvasSize * 0.28 * $scaleFactor))
    $p3x = [float]($center + ($canvasSize * 0.24 * $scaleFactor)); $p3y = [float]($center - ($canvasSize * 0.13 * $scaleFactor))
    $p4x = [float]($center + ($canvasSize * 0.08 * $scaleFactor)); $p4y = [float]($center - ($canvasSize * 0.13 * $scaleFactor))
    $p5x = [float]($center + ($canvasSize * 0.06 * $scaleFactor)); $p5y = [float]($center - ($canvasSize * 0.02 * $scaleFactor))
    $p6x = [float]($center + ($canvasSize * 0.21 * $scaleFactor)); $p6y = [float]($center - ($canvasSize * 0.02 * $scaleFactor))
    $p7x = [float]($center + ($canvasSize * 0.18 * $scaleFactor)); $p7y = [float]($center + ($canvasSize * 0.09 * $scaleFactor))
    $p8x = [float]($center + ($canvasSize * 0.03 * $scaleFactor)); $p8y = [float]($center + ($canvasSize * 0.09 * $scaleFactor))
    $p9x = [float]($center - ($canvasSize * 0.02 * $scaleFactor)); $p9y = [float]($center + ($canvasSize * 0.28 * $scaleFactor))
    $p10x = [float]($center - ($canvasSize * 0.15 * $scaleFactor)); $p10y = [float]($center + ($canvasSize * 0.28 * $scaleFactor))

    $path.AddLine($p1x, $p1y, $p2x, $p2y)
    $path.AddLine($p2x, $p2y, $p3x, $p3y)
    $path.AddLine($p3x, $p3y, $p4x, $p4y)
    $path.AddLine($p4x, $p4y, $p5x, $p5y)
    $path.AddLine($p5x, $p5y, $p6x, $p6y)
    $path.AddLine($p6x, $p6y, $p7x, $p7y)
    $path.AddLine($p7x, $p7y, $p8x, $p8y)
    $path.AddLine($p8x, $p8y, $p9x, $p9y)
    $path.AddLine($p9x, $p9y, $p10x, $p10y)
    $path.CloseFigure()

    $g.FillPath($brushWhite, $path)
    $path.Dispose()

    # 2. 3 Sleek Capsule Speed Lines on the Left
    $lineWidth = [float]($canvasSize * 0.048 * $scaleFactor)
    $pen = New-Object System.Drawing.Pen($white, $lineWidth)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    # Line 1 (Top)
    $l1Y = [float]($center - ($canvasSize * 0.14 * $scaleFactor))
    $l1Start = [float]($center - ($canvasSize * 0.36 * $scaleFactor))
    $l1End = [float]($center - ($canvasSize * 0.18 * $scaleFactor))
    $g.DrawLine($pen, $l1Start, $l1Y, $l1End, $l1Y)

    # Line 2 (Middle - Longest)
    $l2Y = [float]($center)
    $l2Start = [float]($center - ($canvasSize * 0.44 * $scaleFactor))
    $l2End = [float]($center - ($canvasSize * 0.16 * $scaleFactor))
    $g.DrawLine($pen, $l2Start, $l2Y, $l2End, $l2Y)

    # Line 3 (Bottom)
    $l3Y = [float]($center + ($canvasSize * 0.14 * $scaleFactor))
    $l3Start = [float]($center - ($canvasSize * 0.34 * $scaleFactor))
    $l3End = [float]($center - ($canvasSize * 0.19 * $scaleFactor))
    $g.DrawLine($pen, $l3Start, $l3Y, $l3End, $l3Y)

    $brushWhite.Dispose()
    $pen.Dispose()
}

# 1. Full Icon (Legacy)
function Generate-FullIcon([int]$size, [string]$destPath, [bool]$isRound) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $rect = New-Object System.Drawing.RectangleF([float]0, [float]0, [float]$size, [float]$size)
    $gradBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        $primaryRed,
        $lightRed,
        [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
    )

    if ($isRound) {
        $g.FillEllipse($gradBrush, $rect)
    } else {
        $radius = [float]($size * 0.22)
        $path = Create-RoundedRectanglePath $rect $radius
        $g.FillPath($gradBrush, $path)
        $path.Dispose()
    }
    $gradBrush.Dispose()

    Draw-VectorFLogo $g ([float]$size) ([float]0.88)

    $g.Dispose()
    $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# 2. Adaptive Foreground Icon (Centered in safe zone)
function Generate-ForegroundIcon([int]$size, [string]$destPath) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    Draw-VectorFLogo $g ([float]$size) ([float]0.60)

    $g.Dispose()
    $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# Generate 1024 Master
Generate-FullIcon 1024 "$assetsIconDir\app_icon.png" $false
Write-Host "Generated Ultra-Sharp Master app_icon.png"

# Generate Android Mipmaps
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

    Generate-FullIcon $size "$destFolder\ic_launcher.png" $false
    Generate-FullIcon $size "$destFolder\ic_launcher_round.png" $true
    Generate-ForegroundIcon $size "$destFolder\ic_launcher_foreground.png"
}
Write-Host "Generated all Android density mipmaps with high-precision vector F"

# Web Icons
Generate-FullIcon 192 "$webIconsDir\Icon-192.png" $false
Generate-FullIcon 512 "$webIconsDir\Icon-512.png" $false
Generate-FullIcon 192 "$webIconsDir\Icon-maskable-192.png" $false
Generate-FullIcon 512 "$webIconsDir\Icon-maskable-512.png" $false
Generate-FullIcon 64 "$webIconsDir\favicon.png" $false
Write-Host "Generated all Web icons"
