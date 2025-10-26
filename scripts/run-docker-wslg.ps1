# Run DBC Parser using WSLg through Docker Desktop
# This requires running the container in WSL mode

Write-Host "Starting DBC Parser with WSLg support..." -ForegroundColor Green

# Run the container through WSL to use WSLg
wsl -e docker run -it --rm `
    -e DISPLAY=:0 `
    -e WAYLAND_DISPLAY=wayland-0 `
    -e XDG_RUNTIME_DIR=/tmp `
    -e QT_QPA_PLATFORM=wayland `
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw `
    -v /mnt/wslg:/mnt/wslg:rw `
    --name dbc_parser `
    dbc_parser:linux

Write-Host "`nContainer stopped." -ForegroundColor Green
