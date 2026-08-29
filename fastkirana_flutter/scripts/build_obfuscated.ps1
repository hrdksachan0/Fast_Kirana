# FastKirana Obfuscated Release Build
# Usage: .\build_obfuscated.ps1 [AAB|APK]

param(
    [ValidateSet("AAB", "APK")]
    [string]$Target = "AAB"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FastKirana Obfuscated Release Build" -ForegroundColor Cyan
Write-Host "  Target: $Target" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Push-Location $ProjectRoot
try {
    if ($Target -eq "AAB") {
        $args = @("build", "appbundle", "--release", "--obfuscate", "--split-debug-info=build/debug-info")
        $outputPath = "build\app\outputs\bundle\release\app-release.aab"
    } else {
        $args = @("build", "apk", "--release", "--obfuscate", "--split-debug-info=build/debug-info")
        $outputPath = "build\app\outputs\flutter-apk\app-release.apk"
    }

    $args += @(
        "--dart-define=API_BASE_URL=https://www.fastkirana.in",
        "--dart-define=WEB_STOREFRONT_URL=https://fastkirana.in",
        "--dart-define=RAZORPAY_KEY_ID=rzp_live_TRvyzlqHiRGWbr",
        "--dart-define=BUILD_FLAVOR=prod"
    )

    & flutter @args
} finally {
    Pop-Location
}

if ($LASTEXITCODE -eq 0) {
    $fullPath = Join-Path $ProjectRoot $outputPath
    $size = [math]::Round((Get-Item $fullPath).Length / 1MB, 2)
    Write-Host ""
    Write-Host "  SUCCESS! $Target built: $outputPath ($size MB)" -ForegroundColor Green
    Write-Host "  Debug symbols: build/debug-info/" -ForegroundColor Gray
    Write-Host "  Keep build/debug-info/ for crash de-obfuscation in Crashlytics!" -ForegroundColor Yellow
}
