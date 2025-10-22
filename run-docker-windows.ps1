# run-docker-windows.ps1 - Run DBC Parser Docker container on Windows
# This script handles VcXsrv installation and X11 display setup for GUI applications

param(
    [string]$ImageName = "dbc-parser:debian-slim",
    [string]$ContainerName = "dbc-parser"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "DBC Parser Docker Runner for Windows"
Write-Host "========================================"
Write-Host ""

# Check if Docker is installed
Write-Host "Checking Docker installation..."
try {
    $dockerVersion = docker --version
    if ($LASTEXITCODE -ne 0) { throw }
    Write-Host "✓ Docker is installed: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Docker is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Docker Desktop for Windows from:"
    Write-Host "https://www.docker.com/products/docker-desktop"
    exit 1
}

# Check if Docker is running
Write-Host "Checking if Docker is running..."
try {
    docker info | Out-Null
    if ($LASTEXITCODE -ne 0) { throw }
    Write-Host "✓ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Docker is not running!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please start Docker Desktop and try again."
    exit 1
}

# Check if VcXsrv is installed
Write-Host "Checking VcXsrv installation..."
$vcxsrvPaths = @(
    "C:\Program Files\VcXsrv\vcxsrv.exe",
    "C:\Program Files (x86)\VcXsrv\vcxsrv.exe",
    "$env:ProgramFiles\VcXsrv\vcxsrv.exe",
    "${env:ProgramFiles(x86)}\VcXsrv\vcxsrv.exe"
)

$vcxsrvPath = $null
foreach ($path in $vcxsrvPaths) {
    if (Test-Path $path) {
        $vcxsrvPath = $path
        break
    }
}

if (-not $vcxsrvPath) {
    Write-Host "⚠️  WARNING: VcXsrv is not installed!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "VcXsrv (X Server) is required to display GUI applications from Docker."
    Write-Host ""
    Write-Host "Installation options:"
    Write-Host "1. Install via Chocolatey (recommended):"
    Write-Host "   choco install vcxsrv"
    Write-Host ""
    Write-Host "2. Install via winget:"
    Write-Host "   winget install marha.VcXsrv"
    Write-Host ""
    Write-Host "3. Download installer from: https://sourceforge.net/projects/vcxsrv/"
    Write-Host ""
    
    $response = Read-Host "Do you want to install VcXsrv now? (c=Chocolatey, w=winget, n=no)"
    
    if ($response -eq "c" -or $response -eq "C") {
        # Check if Chocolatey is installed
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            Write-Host "❌ ERROR: Chocolatey is not installed!" -ForegroundColor Red
            Write-Host ""
            Write-Host "Install Chocolatey first from: https://chocolatey.org/install"
            Write-Host "Then run this script again."
            exit 1
        }
        
        Write-Host ""
        Write-Host "Installing VcXsrv via Chocolatey (requires admin privileges)..."
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"choco install vcxsrv -y`"" -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Re-check for VcXsrv
        foreach ($path in $vcxsrvPaths) {
            if (Test-Path $path) {
                $vcxsrvPath = $path
                break
            }
        }
        
        if (-not $vcxsrvPath) {
            Write-Host "❌ ERROR: VcXsrv installation may have failed!" -ForegroundColor Red
            Write-Host "Please check the installation and try again."
            exit 1
        }
        
        Write-Host "✓ VcXsrv installed successfully!" -ForegroundColor Green
    }
    elseif ($response -eq "w" -or $response -eq "W") {
        # Check if winget is available
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host "❌ ERROR: winget is not available!" -ForegroundColor Red
            Write-Host ""
            Write-Host "winget should be available on Windows 10 (1809+) and Windows 11."
            Write-Host "Try installing via Chocolatey instead, or download manually."
            exit 1
        }
        
        Write-Host ""
        Write-Host "Installing VcXsrv via winget..."
        winget install marha.VcXsrv --silent
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ ERROR: VcXsrv installation failed!" -ForegroundColor Red
            exit 1
        }
        
        # Re-check for VcXsrv
        foreach ($path in $vcxsrvPaths) {
            if (Test-Path $path) {
                $vcxsrvPath = $path
                break
            }
        }
        
        if (-not $vcxsrvPath) {
            Write-Host "❌ ERROR: VcXsrv installation may have failed!" -ForegroundColor Red
            Write-Host "Please check the installation and try again."
            exit 1
        }
        
        Write-Host "✓ VcXsrv installed successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "Please install VcXsrv manually and run this script again."
        exit 1
    }
} else {
    Write-Host "✓ VcXsrv is installed at: $vcxsrvPath" -ForegroundColor Green
}

# Check if Docker image exists
Write-Host "Checking Docker image..."
try {
    docker image inspect $ImageName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw }
    Write-Host "✓ Docker image '$ImageName' found" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Docker image '$ImageName' not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please build the image first:"
    Write-Host "  docker build -f Dockerfile.linux -t $ImageName ."
    Write-Host ""
    Write-Host "Or pull it from Docker Hub:"
    Write-Host "  docker pull <username>/$ImageName"
    exit 1
}

Write-Host ""
Write-Host "========================================"
Write-Host "Starting VcXsrv X Server..."
Write-Host "========================================"
Write-Host ""

# Check if VcXsrv is already running
$vcxsrvRunning = Get-Process vcxsrv -ErrorAction SilentlyContinue

if ($vcxsrvRunning) {
    Write-Host "✓ VcXsrv is already running (PID: $($vcxsrvRunning.Id))" -ForegroundColor Green
} else {
    Write-Host "Starting VcXsrv..."
    
    # Start VcXsrv with proper settings
    # -ac: disable access control (allow all clients)
    # -multiwindow: integrate X windows with Windows desktop
    # -clipboard: enable clipboard sharing
    # -wgl: enable OpenGL
    Start-Process $vcxsrvPath -ArgumentList "-ac -multiwindow -clipboard -wgl" -WindowStyle Hidden
    
    # Wait for VcXsrv to start
    Start-Sleep -Seconds 2
    
    $vcxsrvRunning = Get-Process vcxsrv -ErrorAction SilentlyContinue
    if ($vcxsrvRunning) {
        Write-Host "✓ VcXsrv started successfully (PID: $($vcxsrvRunning.Id))" -ForegroundColor Green
    } else {
        Write-Host "⚠️  WARNING: Could not verify VcXsrv is running" -ForegroundColor Yellow
    }
}

# Get Windows host IP for WSL2
Write-Host ""
Write-Host "Detecting network configuration..."
$wslIP = (wsl hostname -I).Trim()
if ($wslIP) {
    Write-Host "✓ WSL IP detected: $wslIP" -ForegroundColor Green
}

# Get Windows host IP that Docker can reach
$hostIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "192.168.*" -or $_.IPAddress -like "10.*" -or $_.IPAddress -like "172.*" } | Select-Object -First 1).IPAddress

if (-not $hostIP) {
    $hostIP = "host.docker.internal"
    Write-Host "✓ Using Docker internal host reference: $hostIP" -ForegroundColor Green
} else {
    Write-Host "✓ Host IP detected: $hostIP" -ForegroundColor Green
}

$displayVar = "${hostIP}:0.0"

Write-Host ""
Write-Host "========================================"
Write-Host "Starting DBC Parser Container..."
Write-Host "========================================"
Write-Host ""
Write-Host "Container name: $ContainerName"
Write-Host "Display: $displayVar"
Write-Host "Working directory mounted: $(Get-Location)"
Write-Host ""

# Remove existing container if it exists
docker rm -f $ContainerName 2>$null | Out-Null

# Run the container
try {
    docker run --rm `
        --name $ContainerName `
        -e DISPLAY=$displayVar `
        -e QT_QPA_PLATFORM=xcb `
        -e QT_LOGGING_RULES="*.debug=false" `
        -e LIBGL_ALWAYS_INDIRECT=0 `
        -e QT_XCB_GL_INTEGRATION=xcb_glx `
        -v "$(Get-Location):/data" `
        $ImageName
        
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Host ""
    Write-Host "❌ ERROR: Container failed to start or crashed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting tips:"
    Write-Host "1. Make sure VcXsrv is running (check system tray)"
    Write-Host "2. Try restarting VcXsrv"
    Write-Host "3. Check Docker logs: docker logs $ContainerName"
    Write-Host "4. Ensure Windows Firewall allows VcXsrv connections"
    exit 1
}

Write-Host ""
Write-Host "========================================"
Write-Host "DBC Parser exited successfully"
Write-Host "========================================"
Write-Host ""
Write-Host "Note: VcXsrv is still running in the background."
Write-Host "To stop it, run: Stop-Process -Name vcxsrv"
