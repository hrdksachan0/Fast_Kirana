# FastKirana Keystore Generator
# Run this script once to generate the signing keystore for release builds.
#
# Usage (PowerShell as Administrator):
#   .\generate_keystore.ps1
#
# Output: android/app/fastkirana_release.keystore
#
# IMPORTANT: Write down the passwords — you will need them for signing.
#            Store the keystore file securely (backup + password manager).

param(
    [string]$KeystoreName = "fastkirana_release",
    [string]$Alias = "fastkirana",
    [string]$ValidityYears = 25,
    [string]$KeySize = "2048"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FastKirana Release Keystore Generator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Java is available
try {
    $javaVersion = java -version 2>&1 | Out-String
    if ($javaVersion -notmatch "version") {
        throw "Java not found"
    }
    Write-Host "  Java found: $javaVersion" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Java is not installed or not in PATH." -ForegroundColor Red
    Write-Host "  Install JDK 17+ from https://adoptium.net/" -ForegroundColor Yellow
    exit 1
}

$keystorePath = Join-Path $PSScriptRoot "fastkirana_release.keystore"

if (Test-Path $keystorePath) {
    Write-Host "  WARNING: Keystore already exists at: $keystorePath" -ForegroundColor Yellow
    $overwrite = Read-Host "  Overwrite? (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "  Aborted." -ForegroundColor Yellow
        exit 0
    }
    Remove-Item $keystorePath -Force
}

Write-Host ""
Write-Host "  Generating keystore (${KeySize}-bit RSA, valid ${ValidityYears} years)..." -ForegroundColor Cyan

$distName = "CN=FastKirana App, OU=Mobile, O=FastKirana, L=Kanpur, ST=UP, C=IN"
$storePass = Read-Host "  Enter KEYSTORE password (min 6 chars)" -AsSecureString
$keyPass = Read-Host "  Enter KEY password (min 6 chars, can be same as keystore)" -AsSecureString

# Convert secure strings to plain text for keytool (keytool doesn't accept secure strings)
$storePassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePass)
)
$keyPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPass)
)

if ($storePassPlain.Length -lt 6 -or $keyPassPlain.Length -lt 6) {
    Write-Host "  ERROR: Password must be at least 6 characters." -ForegroundColor Red
    exit 1
}

$keytoolArgs = @(
    "-genkeypair",
    "-v",
    "-storetype", "PKCS12",
    "-keystore", $keystorePath,
    "-alias", $Alias,
    "-keyalg", "RSA",
    "-keysize", $KeySize,
    "-validity", ($ValidityYears * 365).ToString(),
    "-storepass", $storePassPlain,
    "-keypass", $keyPassPlain,
    "-dname", $distName
)

& keytool @keytoolArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "  SUCCESS! Keystore generated at:" -ForegroundColor Green
    Write-Host "    $keystorePath" -ForegroundColor White
    Write-Host ""
    Write-Host "  NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "  1. Copy this keystore to your password manager (it's irreplaceable!)" -ForegroundColor White
    Write-Host "  2. Create android/key.properties with these values:" -ForegroundColor White
    Write-Host "     storeFile=fastkirana_release.keystore" -ForegroundColor Gray
    Write-Host "     storePassword=<your_keystore_password>" -ForegroundColor Gray
    Write-Host "     keyAlias=fastkirana" -ForegroundColor Gray
    Write-Host "     keyPassword=<your_key_password>" -ForegroundColor Gray
    Write-Host "  3. Add android/key.properties to .gitignore (already done)" -ForegroundColor White
    Write-Host "  4. Build release: flutter build appbundle --release" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "  FAILED to generate keystore. Check Java installation." -ForegroundColor Red
    exit 1
}
