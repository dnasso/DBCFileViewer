#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build all DBC Parser release artifacts
.DESCRIPTION
    Builds Windows installer, Flatpak bundle, and Docker image
#>

param(
    [switch]$SkipWindows,
    [switch]$SkipFlatpak,
    [switch]$SkipDocker,
    [switch]$NoClean
)

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "DBC Parser - Build All Releases"
Write-Host "========================================"
Write-Host ""

$startTime = Get-Date

# Track what we're building
$buildTasks = @()
if (-not $SkipWindows) { $buildTasks += "Windows Installer" }
if (-not $SkipFlatpak) { $buildTasks += "Flatpak Bundle" }
if (-not $SkipDocker) { $buildTasks += "Docker Image" }

Write-Host "Building: $($buildTasks -join ', ')"
Write-Host ""

# Clean build artifacts if requested
if (-not $NoClean) {
    Write-Host "Cleaning previous build artifacts..."
    if (Test-Path "build") { Remove-Item -Recurse -Force "build" -ErrorAction SilentlyContinue }
    if (Test-Path "deploy/windows") { Remove-Item -Recurse -Force "deploy/windows" -ErrorAction SilentlyContinue }
    Write-Host "✓ Cleaned" -ForegroundColor Green
    Write-Host ""
}

$results = @{}

# =============================================================================
# 1. Windows Build and Installer
# =============================================================================
if (-not $SkipWindows) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "1. Building Windows Installer"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host ""
    
    try {
        # Build
        Write-Host "→ Building Windows executable..."
        & .\build-windows.ps1
        if ($LASTEXITCODE -ne 0) { throw "Windows build failed" }
        
        # Deploy
        Write-Host ""
        Write-Host "→ Deploying Windows application..."
        & .\deploy-windows.ps1
        if ($LASTEXITCODE -ne 0) { throw "Windows deployment failed" }
        
        # Create installer
        Write-Host ""
        Write-Host "→ Creating Windows installer..."
        & .\build-installer.ps1
        if ($LASTEXITCODE -ne 0) { throw "Installer creation failed" }
        
        $installerFile = Get-ChildItem "installer_output\DBC_Parser_Setup_*.exe" | Select-Object -First 1
        if ($installerFile) {
            $results["Windows"] = @{
                Status = "✓ Success"
                File = $installerFile.FullName
                Size = "{0:N2} MB" -f ($installerFile.Length / 1MB)
            }
            Write-Host ""
            Write-Host "✓ Windows installer created successfully!" -ForegroundColor Green
        }
        else {
            throw "Installer file not found"
        }
    }
    catch {
        $results["Windows"] = @{
            Status = "✗ Failed"
            Error = $_.Exception.Message
        }
        Write-Host ""
        Write-Host "✗ Windows build failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

# =============================================================================
# 2. Flatpak Bundle (via WSL)
# =============================================================================
if (-not $SkipFlatpak) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "2. Building Flatpak Bundle"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host ""
    
    try {
        # Check if WSL is available
        if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
            throw "WSL not found. Install WSL to build Flatpak."
        }
        
        Write-Host "→ Building Flatpak via WSL..."
        $flatpakCmd = "cd /mnt/c/Users/Joe/Coding/school/cs425/DBCFileViewer && mkdir -p flatpak && flatpak-builder --repo=repo --disable-rofiles-fuse --force-clean build-dir com.qtdevs.DBCParser.yml && flatpak build-bundle repo flatpak/dbc-parser.flatpak com.qtdevs.DBCParser"
        wsl -e bash -lc $flatpakCmd
        
        if ($LASTEXITCODE -ne 0) { throw "Flatpak build failed" }
        
        $flatpakFile = Get-Item "flatpak/dbc-parser.flatpak" -ErrorAction Stop
        $results["Flatpak"] = @{
            Status = "✓ Success"
            File = $flatpakFile.FullName
            Size = "{0:N2} MB" -f ($flatpakFile.Length / 1MB)
        }
        Write-Host ""
        Write-Host "✓ Flatpak bundle created successfully!" -ForegroundColor Green
    }
    catch {
        $results["Flatpak"] = @{
            Status = "✗ Failed"
            Error = $_.Exception.Message
        }
        Write-Host ""
        Write-Host "✗ Flatpak build failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

# =============================================================================
# 3. Docker Image
# =============================================================================
if (-not $SkipDocker) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "3. Building Docker Image"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host ""
    
    try {
        # Check if Docker is available
        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
            throw "Docker not found. Install Docker Desktop to build images."
        }
        
        Write-Host "→ Building Docker image..."
        $dockerTag = "dbc-parser:latest"
        docker build -t $dockerTag -f Dockerfile.linux .
        
        if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }
        
        # Get image size
        $imageInfo = docker images $dockerTag --format "{{.Size}}" | Select-Object -First 1
        
        $results["Docker"] = @{
            Status = "✓ Success"
            Tag = $dockerTag
            Size = $imageInfo
        }
        Write-Host ""
        Write-Host "✓ Docker image created successfully!" -ForegroundColor Green
    }
    catch {
        $results["Docker"] = @{
            Status = "✗ Failed"
            Error = $_.Exception.Message
        }
        Write-Host ""
        Write-Host "✗ Docker build failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

# =============================================================================
# Summary
# =============================================================================
$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host ""
Write-Host "========================================"
Write-Host "Build Summary"
Write-Host "========================================"
Write-Host ""

foreach ($key in $results.Keys) {
    Write-Host "$key : $($results[$key].Status)" -ForegroundColor $(if ($results[$key].Status -match "✓") { "Green" } else { "Red" })
    
    if ($results[$key].File) {
        Write-Host "  File: $($results[$key].File)"
        Write-Host "  Size: $($results[$key].Size)"
    }
    elseif ($results[$key].Tag) {
        Write-Host "  Tag: $($results[$key].Tag)"
        Write-Host "  Size: $($results[$key].Size)"
    }
    
    if ($results[$key].Error) {
        Write-Host "  Error: $($results[$key].Error)" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "Total time: $($duration.ToString('mm\:ss'))"
Write-Host ""

# Exit with error if any build failed
$failedBuilds = $results.Values | Where-Object { $_.Status -match "✗" }
if ($failedBuilds.Count -gt 0) {
    Write-Host "⚠️  Some builds failed. Check the logs above." -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ All builds completed successfully!" -ForegroundColor Green
