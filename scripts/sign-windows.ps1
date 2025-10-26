#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sign Windows executables and installers with Authenticode
.DESCRIPTION
    Signs DBC Parser executable and installer with a code signing certificate
.PARAMETER CertPath
    Path to .pfx certificate file
.PARAMETER Password
    Certificate password (use secure string in production)
.PARAMETER Thumbprint
    Certificate thumbprint (alternative to CertPath/Password)
.PARAMETER Timestamp
    Timestamp server URL (default: DigiCert)
#>

param(
    [string]$CertPath,
    [string]$Password,
    [string]$Thumbprint,
    [string]$Timestamp = "http://timestamp.digicert.com"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "DBC Parser Code Signing Script"
Write-Host "========================================"
Write-Host ""

# Validate parameters
if ([string]::IsNullOrEmpty($CertPath) -and [string]::IsNullOrEmpty($Thumbprint)) {
    Write-Host "❌ ERROR: Must specify either -CertPath or -Thumbprint" -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\sign-windows.ps1 -CertPath cert.pfx -Password 'password'"
    Write-Host "  .\sign-windows.ps1 -Thumbprint '1234567890ABCDEF...'"
    exit 1
}

# Find signtool.exe
Write-Host "Looking for signtool.exe..."
$signtoolPaths = Get-ChildItem "C:\Program Files (x86)\Windows Kits" -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "x64" } |
    Sort-Object -Property LastWriteTime -Descending

if (-not $signtoolPaths) {
    Write-Host "❌ ERROR: signtool.exe not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Windows SDK:"
    Write-Host "  winget install Microsoft.WindowsSDK"
    Write-Host "  Or download from: https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/"
    exit 1
}

$signtool = $signtoolPaths[0].FullName
Write-Host "✓ Found signtool: $signtool" -ForegroundColor Green

# Verify certificate if using file
if ($CertPath) {
    if (-not (Test-Path $CertPath)) {
        Write-Host "❌ ERROR: Certificate file not found: $CertPath" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Certificate file found: $CertPath" -ForegroundColor Green
}

# Find files to sign
Write-Host ""
Write-Host "Searching for files to sign..."
$filesToSign = @()

# Executable
$exe = Get-ChildItem "deploy\windows\appDBC_Parser.exe" -ErrorAction SilentlyContinue
if ($exe) {
    $filesToSign += $exe
    Write-Host "  Found: $($exe.Name)"
}

# Installer
$installers = Get-ChildItem "installer_output\DBC_Parser_Setup_*.exe" -ErrorAction SilentlyContinue
foreach ($installer in $installers) {
    $filesToSign += $installer
    Write-Host "  Found: $($installer.Name)"
}

if ($filesToSign.Count -eq 0) {
    Write-Host "⚠️  WARNING: No files found to sign" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Expected locations:"
    Write-Host "  - deploy\windows\appDBC_Parser.exe"
    Write-Host "  - installer_output\DBC_Parser_Setup_*.exe"
    Write-Host ""
    Write-Host "Please build and deploy first:"
    Write-Host "  .\deploy-windows.ps1"
    Write-Host "  .\build-installer.ps1"
    exit 1
}

Write-Host ""
Write-Host "Found $($filesToSign.Count) file(s) to sign"
Write-Host ""

# Sign each file
$signedCount = 0
$failedCount = 0

foreach ($file in $filesToSign) {
    Write-Host "Signing: $($file.Name)" -ForegroundColor Cyan
    
    # Build signtool arguments
    $signArgs = @("sign")
    
    if ($CertPath) {
        $signArgs += "/f"
        $signArgs += $CertPath
        $signArgs += "/p"
        $signArgs += $Password
    } else {
        $signArgs += "/sha1"
        $signArgs += $Thumbprint
    }
    
    $signArgs += "/tr"
    $signArgs += $Timestamp
    $signArgs += "/td"
    $signArgs += "SHA256"
    $signArgs += "/fd"
    $signArgs += "SHA256"
    $signArgs += "/d"
    $signArgs += "DBC Parser"
    $signArgs += "/du"
    $signArgs += "https://github.com/dnasso/DBCFileViewer"
    $signArgs += $file.FullName
    
    # Sign
    $output = & $signtool $signArgs 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Signed successfully" -ForegroundColor Green
        $signedCount++
        
        # Verify signature
        Write-Host "  Verifying signature..." -NoNewline
        & $signtool verify /pa $file.FullName 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host " ✓" -ForegroundColor Green
        } else {
            Write-Host " ⚠️  Verification warning" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ Failed to sign" -ForegroundColor Red
        Write-Host "  Error: $output" -ForegroundColor Red
        $failedCount++
    }
    
    Write-Host ""
}

# Summary
Write-Host "========================================"
Write-Host "Code Signing Summary"
Write-Host "========================================"
Write-Host "Successfully signed: $signedCount file(s)" -ForegroundColor Green
if ($failedCount -gt 0) {
    Write-Host "Failed: $failedCount file(s)" -ForegroundColor Red
}
Write-Host ""

if ($signedCount -gt 0) {
    Write-Host "Signed files:"
    foreach ($file in $filesToSign) {
        # Check if file is signed
        $sig = Get-AuthenticodeSignature $file.FullName -ErrorAction SilentlyContinue
        if ($sig -and $sig.Status -eq "Valid") {
            Write-Host "  ✓ $($file.FullName)" -ForegroundColor Green
            Write-Host "    Subject: $($sig.SignerCertificate.Subject)"
            Write-Host "    Valid until: $($sig.SignerCertificate.NotAfter)"
        }
    }
    
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Test signed executable on clean Windows system"
    Write-Host "  2. Verify no SmartScreen warnings appear"
    Write-Host "  3. Check digital signature in file properties"
    Write-Host "  4. Distribute signed binaries"
}

exit $failedCount
