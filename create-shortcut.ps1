# Create a nice Windows shortcut with custom icon
# This creates a desktop shortcut to launch DBC Parser

# Create a nice Windows shortcut with custom icon
# This creates a desktop shortcut to launch DBC Parser with VcXsrv (but nicer!)

$ShortcutPath = [Environment]::GetFolderPath("Desktop") + "\DBC Parser.lnk"
$TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$WorkingDirectory = "$PWD"
# Use the VcXsrv script with hidden window
$Arguments = "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$PWD\run-docker-gui.ps1`""
$IconLocation = "$PWD\dbctrain.ico"  # Using your existing train icon!

$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $TargetPath
$Shortcut.Arguments = $Arguments
$Shortcut.WorkingDirectory = $WorkingDirectory
$Shortcut.WindowStyle = 1  # Normal window
$Shortcut.Description = "DBC File Viewer - Docker Container"

# Set custom icon if it exists
if (Test-Path $IconLocation) {
    $Shortcut.IconLocation = $IconLocation
    Write-Host "Custom icon set: $IconLocation" -ForegroundColor Green
} else {
    Write-Host "No custom icon found at $IconLocation - using default" -ForegroundColor Yellow
    Write-Host "To add a custom icon, place an .ico file at: $IconLocation" -ForegroundColor Yellow
}

$Shortcut.Save()

Write-Host "`nDesktop shortcut created: $ShortcutPath" -ForegroundColor Green
Write-Host "You can now launch DBC Parser from your desktop!" -ForegroundColor Cyan
