# PowerShell wrapper for package-and-upload.sh
# Runs the bash script in WSL

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OBS Package Upload Tool (Windows)" -ForegroundColor Cyan
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

# Get the current directory in WSL format
$currentDir = (Get-Location).Path
$wslPath = wsl wslpath -a $currentDir

Write-Host "[INFO] Current directory: $currentDir" -ForegroundColor Blue
Write-Host "[INFO] WSL path: $wslPath" -ForegroundColor Blue
Write-Host ""

# Check if script exists
$scriptPath = Join-Path $currentDir "scripts\package-and-upload.sh"
if (-not (Test-Path $scriptPath)) {
    Write-Host "[✗] Script not found: $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Running package-and-upload.sh in WSL..." -ForegroundColor Blue
Write-Host ""

# Make script executable and run it
wsl -e bash -c "cd '$wslPath' && chmod +x scripts/package-and-upload.sh && ./scripts/package-and-upload.sh"

$exitCode = $LASTEXITCODE
Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "[✓] Script completed successfully" -ForegroundColor Green
} else {
    Write-Host "[✗] Script exited with code: $exitCode" -ForegroundColor Red
}

exit $exitCode
