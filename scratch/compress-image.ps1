Add-Type -AssemblyName System.Drawing

function Resize-Image {
    param (
        [string]$InputPath,
        [string]$OutputPath,
        [int]$Width,
        [int]$Height
    )
    
    $srcImg = [System.Drawing.Image]::FromFile($InputPath)
    $destImg = New-Object System.Drawing.Bitmap($Width, $Height)
    $g = [System.Drawing.Graphics]::FromImage($destImg)
    
    # Set high quality rendering options
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    
    # Draw original image into resized bitmap
    $g.DrawImage($srcImg, 0, 0, $Width, $Height)
    
    # Save the resized bitmap
    $destImg.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    
    # Clean up
    $g.Dispose()
    $destImg.Dispose()
    $srcImg.Dispose()
}

# Resize the logo to 400x250 (or 512x512 since it's a square logo)
# Let's make it 512x512 to preserve layout and drastically reduce size!
Resize-Image -InputPath "d:\Fastkirana\fastkirana_app_icon.png" -OutputPath "d:\Fastkirana\fastkirana_app_icon_small.png" -Width 512 -Height 340

# Print the size of the compressed image
$originalSize = (Get-Item "d:\Fastkirana\fastkirana_app_icon.png").Length
$newSize = (Get-Item "d:\Fastkirana\fastkirana_app_icon_small.png").Length
Write-Output "Original Size: $originalSize bytes"
Write-Output "Compressed Size: $newSize bytes"
