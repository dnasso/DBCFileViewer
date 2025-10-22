#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build DBC Parser on Windows using CMake
.DESCRIPTION
    Configures and builds the DBC Parser application using CMake and Ninja
#>

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "DBC Parser Windows Build Script"
Write-Host "========================================"
Write-Host ""

# Configuration
$BUILD_TYPE = "Release"
$BUILD_DIR = "build"
$GENERATOR = "Ninja"

# Check for CMake
if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    Write-Host "❌ ERROR: CMake not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install CMake from: https://cmake.org/download/"
    Write-Host "Or via winget: winget install Kitware.CMake"
    exit 1
}

Write-Host "✓ CMake found: $(cmake --version | Select-Object -First 1)" -ForegroundColor Green

# Check for Ninja and add to PATH if needed
if (-not (Get-Command ninja -ErrorAction SilentlyContinue)) {
    # Check common Qt Ninja installation path
    $qtNinjaPath = "C:\Qt\Tools\Ninja"
    if (Test-Path "$qtNinjaPath\ninja.exe") {
        $env:PATH = "$qtNinjaPath;$env:PATH"
        Write-Host "✓ Ninja found in Qt Tools (added to PATH)" -ForegroundColor Green
    } else {
        Write-Host "⚠️  WARNING: Ninja not found, falling back to default generator" -ForegroundColor Yellow
        $GENERATOR = $null
    }
}
else {
    Write-Host "✓ Ninja found" -ForegroundColor Green
}

# Check for Qt
if (-not $env:Qt6_DIR -and -not $env:QTDIR) {
    Write-Host "⚠️  WARNING: Qt6 not found in environment variables" -ForegroundColor Yellow
    Write-Host "Please set Qt6_DIR or QTDIR environment variable"
    Write-Host "Example: `$env:Qt6_DIR = 'C:\Qt\6.8.2\msvc2022_64'"
    Write-Host ""
    Write-Host "Attempting to find Qt..."
    
    # Try to find Qt in common locations
    $qtPaths = @(
        "C:\Qt\6.8.2\mingw_64",
        "C:\Qt\6.9.2\mingw_64",
        "C:\Qt\6.8.2\msvc2022_64",
        "C:\Qt\6.9.2\msvc2022_64",
        "C:\Qt\6.8.1\msvc2022_64",
        "C:\Qt\6.8.0\msvc2022_64",
        "C:\Qt\6.7.2\msvc2022_64"
    )
    
    foreach ($path in $qtPaths) {
        if (Test-Path $path) {
            Write-Host "✓ Found Qt at: $path" -ForegroundColor Green
            $env:Qt6_DIR = $path
            break
        }
    }
    
    if (-not $env:Qt6_DIR) {
        Write-Host "❌ ERROR: Could not find Qt installation" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "✓ Qt6 found: $($env:Qt6_DIR ?? $env:QTDIR)" -ForegroundColor Green
}

# Clean previous build
if (Test-Path $BUILD_DIR) {
    Write-Host ""
    Write-Host "Cleaning previous build directory..."
    Remove-Item -Recurse -Force $BUILD_DIR
}

# Create build directory
Write-Host ""
Write-Host "Creating build directory..."
New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null

# Configure CMake
Write-Host ""
Write-Host "Configuring CMake..."
Write-Host "Build Type: $BUILD_TYPE"
if ($GENERATOR) {
    Write-Host "Generator: $GENERATOR"
}

$cmakeArgs = @(
    "-B", $BUILD_DIR,
    "-DCMAKE_BUILD_TYPE=$BUILD_TYPE"
)

# Prefer Ninja if available, otherwise use appropriate makefiles
if ($GENERATOR) {
    $cmakeArgs += "-G", $GENERATOR
    Write-Host "Using $GENERATOR generator"
}
elseif ($env:Qt6_DIR -match "mingw") {
    $cmakeArgs += "-G", "MinGW Makefiles"
    Write-Host "Using MinGW Makefiles generator (Ninja not found)"
}

& cmake @cmakeArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ ERROR: CMake configuration failed" -ForegroundColor Red
    exit 1
}

# Build
Write-Host ""
Write-Host "Building project..."
cmake --build $BUILD_DIR --config $BUILD_TYPE --parallel

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ ERROR: Build failed" -ForegroundColor Red
    exit 1
}

# Success
Write-Host ""
Write-Host "========================================"
Write-Host "✓ Build completed successfully!" -ForegroundColor Green
Write-Host "========================================"
Write-Host ""
Write-Host "Executable: $BUILD_DIR\appDBC_Parser.exe"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Test the application:"
Write-Host "     cd $BUILD_DIR && .\appDBC_Parser.exe"
Write-Host ""
Write-Host "  2. Deploy for distribution:"
Write-Host "     .\deploy-windows.ps1"
Write-Host ""
Write-Host "  3. Create installer:"
Write-Host "     .\build-installer.ps1"
