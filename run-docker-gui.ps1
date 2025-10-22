# Run DBC Parser in Docker with GUI support
# This script starts VcXsrv and runs the Docker container

# Run DBC Parser in Docker with GUI support
# This script starts VcXsrv and runs the Docker container

# Check if VcXsrv is already running
$vcxsrvProcess = Get-Process -Name "vcxsrv" -ErrorAction SilentlyContinue

if ($vcxsrvProcess) {
    Write-Host "VcXsrv X Server is already running." -ForegroundColor Green
} else {
    Write-Host "Starting VcXsrv X Server..." -ForegroundColor Green
    
    # Start VcXsrv silently in the background
    # -ac: disable access control (allow any client)
    # -multiwindow: use native Windows windows
    Start-Process "C:\Program Files\VcXsrv\vcxsrv.exe" -ArgumentList "-ac -multiwindow -clipboard -wgl -silent-dup-error" -WindowStyle Hidden
    
    # Wait for X server to fully initialize
    Start-Sleep -Seconds 5
}

# Get the host IP address for WSL/Docker
$hostIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -like "*WSL*" -or $_.InterfaceAlias -like "*vEthernet*"} | Select-Object -First 1).IPAddress

if (-not $hostIP) {
    # Fallback to host.docker.internal
    $hostIP = "host.docker.internal"
}

# Run the Docker container with GUI support (no console window)
docker run -it --rm `
    -e DISPLAY="${hostIP}:0.0" `
    -e QT_QPA_PLATFORM=xcb `
    --name dbc_parser `
    dbc_parser:linux
