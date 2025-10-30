# PowerShell wrapper to run Docker container with GUI support in WSL
# This script forwards the call to the bash script in WSL

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DBC Parser Docker GUI Launcher (Windows)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if WSL is available
try {
    $null = wsl --status 2>&1
    Write-Host "[✓] WSL is available" -ForegroundColor Green
} catch {
    Write-Host "[✗] WSL is not available. Please install WSL2." -ForegroundColor Red
    Write-Host "    Visit: https://learn.microsoft.com/en-us/windows/wsl/install" -ForegroundColor Yellow
    exit 1
}


# Get the current directory in WSL format (no extra quotes)
$currentDir = (Get-Location).Path
$wslPath = wsl wslpath -a $currentDir

Write-Host "[INFO] Current directory: $currentDir" -ForegroundColor Blue
Write-Host "[INFO] WSL path: $wslPath" -ForegroundColor Blue
Write-Host ""

# Check if run-docker-gui.sh exists
if (-not (Test-Path "run-docker-gui.sh")) {
    Write-Host "[✗] run-docker-gui.sh not found in current directory" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Launching Docker container via WSL..." -ForegroundColor Blue
Write-Host ""

# Run the bash script in WSL
wsl -e bash -c "cd '$wslPath' && chmod +x run-docker-gui.sh && ./run-docker-gui.sh"

$exitCode = $LASTEXITCODE
Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "[✓] Container exited successfully" -ForegroundColor Green
} else {
    Write-Host "[✗] Container exited with code: $exitCode" -ForegroundColor Red
}

exit $exitCode
