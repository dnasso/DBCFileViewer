# PowerShell wrapper for setup-obs-scm.sh

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OBS SCM/CI Setup Tool (Windows)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if WSL is available
try {
    $null = wsl --status 2>&1
    Write-Host "[✓] WSL is available" -ForegroundColor Green
} catch {
    Write-Host "[✗] WSL is not available. Please install WSL2." -ForegroundColor Red
    exit 1
}

$currentDir = (Get-Location).Path
$wslPath = wsl wslpath -a $currentDir

Write-Host "[INFO] Running setup-obs-scm.sh in WSL..." -ForegroundColor Blue
Write-Host ""

# Make script executable and run
wsl -e bash -c "cd '$wslPath' && chmod +x scripts/setup-obs-scm.sh && ./scripts/setup-obs-scm.sh"

exit $LASTEXITCODE
