# FastKirana Build Scripts
# =========================
# PowerShell scripts for building the FastKirana Flutter app.

# Usage:
#   .\build_release.ps1          # Production build (requires key.properties)
#   .\build_release.ps1 -Flavor  # Production build with flavor
#   .\build_dev.ps1              # Development/debug build
#   .\build_apk.ps1              # Release APK (not AAB)
#   .\build_obfuscated.ps1       # Release AAB with code obfuscation

param(
    [switch]$Obfuscate,
    [switch]$Apk,
    [switch]$Clean
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

function Invoke-FlutterBuild($args) {
    Push-Location $ProjectRoot
    try {
        & flutter @args
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter build failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
}

# ──────────────────────────────────────────────
# Build Release AAB
# ──────────────────────────────────────────────
function Build-ReleaseAab {
    Write-Header "Building Release AAB"

    $buildArgs = @("build", "appbundle", "--release")

    if ($Obfuscate) {
        $buildArgs += @("--obfuscate", "--split-debug-info=build/debug-info")
        Write-Host "  Code obfuscation: ENABLED" -ForegroundColor Yellow
        Write-Host "  Debug symbols: build/debug-info/" -ForegroundColor Gray
    }

    # Production API URL + Razorpay live key
    $buildArgs += @(
        "--dart-define=API_BASE_URL=https://www.fastkirana.in",
        "--dart-define=WEB_STOREFRONT_URL=https://fastkirana.in",
        "--dart-define=RAZORPAY_KEY_ID=rzp_live_TRvyzlqHiRGWbr",
        "--dart-define=BUILD_FLAVOR=prod"
    )

    Write-Host "  API: https://www.fastkirana.in" -ForegroundColor Green
    Write-Host "  Flavor: prod" -ForegroundColor Green

    Invoke-FlutterBuild $buildArgs

    $outputPath = Join-Path $ProjectRoot "build\app\outputs\bundle\release\app-release.aab"
    if (Test-Path $outputPath) {
        $size = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
        Write-Host ""
        Write-Host "  SUCCESS! AAB built: $outputPath ($size MB)" -ForegroundColor Green
    }
}

# ──────────────────────────────────────────────
# Build Release APK
# ──────────────────────────────────────────────
function Build-ReleaseApk {
    Write-Header "Building Release APK"

    $buildArgs = @("build", "apk", "--release")

    if ($Obfuscate) {
        $buildArgs += @("--obfuscate", "--split-debug-info=build/debug-info")
    }

    $buildArgs += @(
        "--dart-define=API_BASE_URL=https://www.fastkirana.in",
        "--dart-define=WEB_STOREFRONT_URL=https://fastkirana.in",
        "--dart-define=RAZORPAY_KEY_ID=rzp_live_TRvyzlqHiRGWbr",
        "--dart-define=BUILD_FLAVOR=prod"
    )

    Invoke-FlutterBuild $buildArgs

    $outputPath = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $outputPath) {
        $size = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
        Write-Host ""
        Write-Host "  SUCCESS! APK built: $outputPath ($size MB)" -ForegroundColor Green
    }
}

# ──────────────────────────────────────────────
# Build Dev APK
# ──────────────────────────────────────────────
function Build-DevApk {
    Write-Header "Building Development APK"

    $buildArgs = @("build", "apk", "--debug")

    $buildArgs += @(
        "--dart-define=API_BASE_URL=http://localhost:3000",
        "--dart-define=WEB_STOREFRONT_URL=http://localhost:3000",
        "--dart-define=RAZORPAY_KEY_ID=rzp_test_placeholder",
        "--dart-define=BUILD_FLAVOR=dev"
    )

    Write-Host "  API: http://localhost:3000" -ForegroundColor Yellow
    Write-Host "  Flavor: dev" -ForegroundColor Yellow

    Invoke-FlutterBuild $buildArgs

    $outputPath = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-debug.apk"
    if (Test-Path $outputPath) {
        $size = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
        Write-Host ""
        Write-Host "  SUCCESS! Dev APK: $outputPath ($size MB)" -ForegroundColor Green
        Write-Host "  Install: adb install $outputPath" -ForegroundColor Gray
    }
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
if ($Clean) {
    Write-Host "  Cleaning build artifacts..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    flutter clean
    Pop-Location
}

if ($Apk) {
    if ($Obfuscate) {
        Build-ReleaseApk
    } else {
        Build-ReleaseApk
    }
} else {
    Build-ReleaseAab
}

Write-Host ""
Write-Host "  Done! " -NoNewline -ForegroundColor Green

if ($Obfuscate) {
    Write-Host "Symbol maps available in build/debug-info/ for crash de-obfuscation." -ForegroundColor Gray
} else {
    Write-Host "Tip: use -Obfuscate for production AAB builds." -ForegroundColor Gray
}
