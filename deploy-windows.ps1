#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy DBC Parser for Windows using windeployqt
.DESCRIPTION
    Collects all Qt dependencies and creates a standalone deployment directory
.PARAMETER BuildDir
    Path to the build directory containing the executable
.PARAMETER QtDir
    Path to Qt installation (e.g., C:\Qt\6.8.2\msvc2022_64)
.PARAMETER OutputDir
    Output directory for deployment package (default: .\deploy\windows)
#>

param(
    [string]$BuildDir = ".\build",
    [string]$QtDir = "",
    [string]$OutputDir = ".\deploy\windows"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "DBC Parser Windows Deployment Script"
Write-Host "========================================"
Write-Host ""

# Find Qt installation if not specified
if ([string]::IsNullOrEmpty($QtDir)) {
    Write-Host "Searching for Qt installation..."
    $possibleQtPaths = @(
        "C:\Qt\6.8.2\msvc2022_64",
        "C:\Qt\6.8.2\mingw_64",
        "C:\Qt\6.8.0\msvc2022_64",
        "$env:USERPROFILE\Qt\6.8.2\msvc2022_64",
        "$env:USERPROFILE\Qt\6.8.2\mingw_64"
    )
    
    foreach ($path in $possibleQtPaths) {
        if (Test-Path "$path\bin\windeployqt.exe") {
            $QtDir = $path
            Write-Host "✓ Found Qt at: $QtDir" -ForegroundColor Green
            break
        }
    }
    
    if ([string]::IsNullOrEmpty($QtDir)) {
        Write-Host "❌ ERROR: Could not find Qt installation" -ForegroundColor Red
        Write-Host "Please specify -QtDir parameter"
        exit 1
    }
}

# Verify windeployqt exists
$windeployqt = "$QtDir\bin\windeployqt.exe"
if (-not (Test-Path $windeployqt)) {
    Write-Host "❌ ERROR: windeployqt.exe not found at: $windeployqt" -ForegroundColor Red
    exit 1
}

# Find executable (pick most recently updated build)
$exePath = Get-ChildItem -Path $BuildDir -Filter "appDBC_Parser.exe" -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $exePath) {
    Write-Host "❌ ERROR: Could not find appDBC_Parser.exe in $BuildDir" -ForegroundColor Red
    Write-Host "Please build the project first or specify correct -BuildDir"
    exit 1
}

Write-Host "✓ Found executable: $($exePath.FullName)" -ForegroundColor Green

# Create output directory
Write-Host ""
Write-Host "Creating deployment directory: $OutputDir"
if (Test-Path $OutputDir) {
    Write-Host "⚠️  Output directory exists, cleaning..." -ForegroundColor Yellow
    Remove-Item -Path $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Copy executable to deployment directory
Write-Host "Copying executable..."
Copy-Item -Path $exePath.FullName -Destination $OutputDir

# Get QML source directory
$qmlSourceDir = Resolve-Path "."

# Run windeployqt
Write-Host ""
Write-Host "Running windeployqt..."
Write-Host "Command: $windeployqt --release --qmldir `"$qmlSourceDir`" --no-compiler-runtime `"$OutputDir\appDBC_Parser.exe`""
Write-Host ""

& $windeployqt `
    --release `
    --qmldir "$qmlSourceDir" `
    --no-compiler-runtime `
    "$OutputDir\appDBC_Parser.exe"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ERROR: windeployqt failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit 1
}

# Copy MinGW runtime DLLs (windeployqt doesn't copy these)
Write-Host ""
Write-Host "Copying MinGW runtime DLLs..."
$mingwBin = "$QtDir\bin"
$mingwRuntimeDlls = @(
    "libgcc_s_seh-1.dll",
    "libstdc++-6.dll",
    "libwinpthread-1.dll"
)

$copiedCount = 0
foreach ($dll in $mingwRuntimeDlls) {
    $sourcePath = Join-Path $mingwBin $dll
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $OutputDir -ErrorAction SilentlyContinue
        Write-Host "  ✓ Copied $dll"
        $copiedCount++
    } else {
        Write-Host "  ⚠️  $dll not found (may not be needed for MSVC builds)" -ForegroundColor Yellow
    }
}

if ($copiedCount -eq 0) {
    Write-Host "  ℹ️  No MinGW runtime DLLs found - this is normal for MSVC builds" -ForegroundColor Cyan
}

# Copy additional files (DBC files, configs, etc.)
Write-Host ""
Write-Host "Copying additional resources..."
$additionalFiles = @(
    "SimpBMS-2.dbc",
    "sample_transmission_config.json",
    "simpbms_transmission_config.json",
    "README.md"
)

foreach ($file in $additionalFiles) {
    if (Test-Path $file) {
        Copy-Item -Path $file -Destination $OutputDir -ErrorAction SilentlyContinue
        Write-Host "  ✓ Copied $file"
    }
}

# Get deployment size
$size = (Get-ChildItem -Path $OutputDir -Recurse | Measure-Object -Property Length -Sum).Sum
$sizeMB = [math]::Round($size / 1MB, 2)

Write-Host ""
Write-Host "========================================"
Write-Host "✓ Deployment completed successfully!" -ForegroundColor Green
Write-Host "========================================"
Write-Host ""
Write-Host "Deployment directory: $OutputDir"
Write-Host "Total size: $sizeMB MB"
Write-Host ""
Write-Host "To create a ZIP archive:"
Write-Host "  Compress-Archive -Path '$OutputDir\*' -DestinationPath 'DBC_Parser_Windows.zip'"
Write-Host ""
Write-Host "To create an installer, use a tool like:"
Write-Host "  - Inno Setup (https://jrsoftware.org/isinfo.php)"
Write-Host "  - NSIS (https://nsis.sourceforge.io/)"
Write-Host "  - WiX Toolset (https://wixtoolset.org/)"
