$ErrorActionPreference = "Stop"
$fontsDir = "d:\Fastkirana\fastkirana_flutter\assets\fonts"
if (!(Test-Path $fontsDir)) {
    New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("fastkirana_fonts_" + [System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$fontDownloads = @(
    @{
        Family = "Inter"
        Url = "https://fonts.google.com/download?family=Inter"
        Files = @("Inter-Regular.ttf", "Inter-Medium.ttf", "Inter-SemiBold.ttf", "Inter-Bold.ttf", "Inter-ExtraBold.ttf", "Inter-Black.ttf")
    },
    @{
        Family = "Plus Jakarta Sans"
        Url = "https://fonts.google.com/download?family=Plus+Jakarta+Sans"
        Files = @("PlusJakartaSans-Bold.ttf", "PlusJakartaSans-ExtraBold.ttf")
    },
    @{
        Family = "Poppins"
        Url = "https://fonts.google.com/download?family=Poppins"
        Files = @("Poppins-SemiBold.ttf", "Poppins-Bold.ttf")
    },
    @{
        Family = "Roboto Mono"
        Url = "https://fonts.google.com/download?family=Roboto+Mono"
        Files = @("RobotoMono-Regular.ttf", "RobotoMono-Bold.ttf")
    }
)

try {
    foreach ($font in $fontDownloads) {
        $familyName = $font.Family
        Write-Host "Downloading $familyName..."
        $zipPath = Join-Path $tempDir "$($familyName -replace '\s','_').zip"
        $extractPath = Join-Path $tempDir ($familyName -replace '\s','_')
        
        # Download ZIP
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
        Invoke-WebRequest -Uri $font.Url -OutFile $zipPath -UserAgent "Mozilla/5.0"
        
        # Extract ZIP
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        # Search and copy required files
        foreach ($file in $font.Files) {
            $found = Get-ChildItem -Path $extractPath -Recurse -File | Where-Object { $_.Name -eq $file }
            if ($found) {
                Copy-Item -Path $found[0].FullName -Destination (Join-Path $fontsDir $file) -Force
                Write-Host "  Copied: $file"
            } else {
                # Try case-insensitive or partial match in static folder
                $alt = Get-ChildItem -Path $extractPath -Recurse -File | Where-Object { $_.Name -like "*$file*" -or $_.Name -replace '_','' -eq ($file -replace '_','') }
                if ($alt) {
                    Copy-Item -Path $alt[0].FullName -Destination (Join-Path $fontsDir $file) -Force
                    Write-Host "  Copied (alt match $($alt[0].Name)): $file"
                } else {
                    Write-Warning "  Could not find $file in $extractPath. Available files:"
                    Get-ChildItem -Path $extractPath -Recurse -File | ForEach-Object { Write-Host "    $($_.FullName)" }
                }
            }
        }
    }
}
finally {
    # Cleanup temp dir
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`nFinished downloading fonts. Contents of $fontsDir:"
Get-ChildItem -Path $fontsDir | Format-Table Name, Length, LastWriteTime
