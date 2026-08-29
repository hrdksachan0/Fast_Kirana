# FastKirana Development Build Script
# Usage: .\build_dev.ps1 [-Install]

param(
    [switch]$Install
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

function Write-Header($text) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

Write-Header "FastKirana Dev Build"

Push-Location $ProjectRoot
try {
    $buildArgs = @("build", "apk", "--debug")
    $buildArgs += @(
        "--dart-define=API_BASE_URL=http://localhost:3000",
        "--dart-define=WEB_STOREFRONT_URL=http://localhost:3000",
        "--dart-define=RAZORPAY_KEY_ID=rzp_test_placeholder",
        "--dart-define=BUILD_FLAVOR=dev"
    )
    & flutter @buildArgs
} finally {
    Pop-Location
}

if ($LASTEXITCODE -eq 0) {
    $outputPath = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-debug.apk"
    $size = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
    Write-Host ""
    Write-Host "  Dev APK ready: $outputPath ($size MB)" -ForegroundColor Green

    if ($Install) {
        Write-Host "  Installing via ADB..." -ForegroundColor Cyan
        adb install -r $outputPath
    }
}
