#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build Windows installer using Inno Setup
.DESCRIPTION
    Compiles the installer.iss script to create a Windows installer executable
#>

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "DBC Parser Installer Build Script"
Write-Host "========================================"
Write-Host ""

# Check if deployment exists
if (-not (Test-Path "deploy\windows\appDBC_Parser.exe")) {
    Write-Host "❌ ERROR: Deployment not found. Please run deployment first:" -ForegroundColor Red
    Write-Host "  .\deploy-windows.ps1"
    exit 1
}

# Find Inno Setup
$innoSetupPaths = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
)

$iscc = $null
foreach ($path in $innoSetupPaths) {
    if (Test-Path $path) {
        $iscc = $path
        Write-Host "✓ Found Inno Setup: $iscc" -ForegroundColor Green
        break
    }
}

if (-not $iscc) {
    Write-Host "❌ ERROR: Inno Setup not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Inno Setup from: https://jrsoftware.org/isinfo.php"
    Write-Host ""
    Write-Host "Or install via Chocolatey:"
    Write-Host "  choco install innosetup"
    Write-Host ""
    Write-Host "Or install via winget:"
    Write-Host "  winget install JRSoftware.InnoSetup"
    exit 1
}

# Create deploy-assets directory if needed (for icon)
if (-not (Test-Path "deploy-assets")) {
    Write-Host "Creating deploy-assets directory..."
    New-Item -ItemType Directory -Path "deploy-assets" -Force | Out-Null
}

# Check for icon file
if (-not (Test-Path "deploy-assets\dbctrain.ico")) {
    Write-Host "⚠️  Warning: Icon file not found at deploy-assets\dbctrain.ico" -ForegroundColor Yellow
    Write-Host "Creating placeholder icon..."
    
    # Copy a Windows system icon as placeholder (optional)
    # You should replace this with your actual app icon
    if (Test-Path "$env:SystemRoot\System32\shell32.dll") {
        Write-Host "Using placeholder icon for now. Please add your custom icon to deploy-assets\dbctrain.ico"
    }
}

# Compile the installer
Write-Host ""
Write-Host "Compiling installer..."
Write-Host "Command: $iscc installer.iss"
Write-Host ""

& $iscc "installer.iss"

if ($LASTEXITCODE -eq 0) {
    $installerPath = Get-ChildItem -Path "installer_output" -Filter "DBC_Parser_Setup_*.exe" | Select-Object -First 1
    
    if ($installerPath) {
        $size = [math]::Round($installerPath.Length / 1MB, 2)
        
        Write-Host ""
        Write-Host "========================================"
        Write-Host "✓ Installer built successfully!" -ForegroundColor Green
        Write-Host "========================================"
        Write-Host ""
        Write-Host "Installer: $($installerPath.FullName)"
        Write-Host "Size: $size MB"
        Write-Host ""
        Write-Host "Test the installer:"
        Write-Host "  Start-Process '$($installerPath.FullName)'"
        Write-Host ""
        Write-Host "Sign the installer (optional, requires certificate):"
        Write-Host "  signtool sign /f cert.pfx /p password /t http://timestamp.digicert.com '$($installerPath.FullName)'"
    }
} else {
    Write-Host ""
    Write-Host "❌ ERROR: Installer compilation failed" -ForegroundColor Red
    exit 1
}
