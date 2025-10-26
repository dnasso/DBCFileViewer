param(
  [string]$ImageName = "dbcfileviewer-dev:latest",
  [string]$ContainerName = "dbcfileviewer-dev"
)

$ErrorActionPreference = "Stop"

Write-Host "Building/Running Dev Container: $ContainerName from $ImageName" -ForegroundColor Cyan

# Check Docker
try { docker info | Out-Null } catch { Write-Error "Docker Desktop is not running" }

# Ensure an X server exists (VcXsrv recommended)
$vcxsrvPaths = @(
  "C:\\Program Files\\VcXsrv\\vcxsrv.exe",
  "C:\\Program Files (x86)\\VcXsrv\\vcxsrv.exe"
)
$vcxsrvPath = $vcxsrvPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $vcxsrvPath) {
  Write-Warning "VcXsrv not found. Install via 'winget install marha.VcXsrv' or Chocolatey."
} else {
  if (-not (Get-Process vcxsrv -ErrorAction SilentlyContinue)) {
    Write-Host "Starting VcXsrv..."
    Start-Process $vcxsrvPath -ArgumentList "-ac -multiwindow -clipboard -wgl" -WindowStyle Hidden | Out-Null
    Start-Sleep -Seconds 2
  }
}

# Resolve host DISPLAY
$hostIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "192.168.*" -or $_.IPAddress -like "10.*" -or $_.IPAddress -like "172.*" } | Select-Object -First 1).IPAddress
if (-not $hostIP) { $hostIP = "host.docker.internal" }
$displayVar = "$hostIP:0.0"

# Remove any existing container
docker rm -f $ContainerName 2>$null | Out-Null

# Run interactive dev shell
docker run --rm -it `
  --name $ContainerName `
  -e DISPLAY=$displayVar `
  -e QT_QPA_PLATFORM=xcb `
  -v "${PWD}:/workspaces/DBCFileViewer" `
  -w "/workspaces/DBCFileViewer" `
  $ImageName powershell

