# Running DBC Parser with GUI on Windows/WSL ✅ WORKING

## Status: FIXED!
All Docker GUI scripts are now working correctly. The application launches successfully in WSL with GUI forwarding.

## Quick Solutions

### Option 1: PowerShell Script (Easiest for Windows)
From PowerShell or Windows Terminal:
```powershell
cd C:\Users\Joe\Coding\school\cs425\DBCFileViewer
.\run-docker-gui.ps1
```

### Option 2: WSL Bash Script
From WSL terminal:
```bash
cd /mnt/c/Users/Joe/Coding/school/cs425/DBCFileViewer
chmod +x run-docker-gui.sh
./run-docker-gui.sh
```

### Option 3: Manual Docker Run (Advanced)
If you need to run manually, use this command in WSL:
```bash
docker run -it --rm \
  --name dbc-parser-gui \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v /mnt/wslg/runtime-dir/wayland-0:/tmp/wayland-0:rw \
  -e DISPLAY=:0 \
  -e WAYLAND_DISPLAY=wayland-0 \
  -e XDG_RUNTIME_DIR=/tmp \
  -e QT_QPA_PLATFORM=wayland;xcb \
  -e QT_XCB_GL_INTEGRATION=none \
  -v /usr/lib/wsl:/usr/lib/wsl:ro \
  -e LD_LIBRARY_PATH=/usr/lib/wsl/lib \
  --device=/dev/dxg \
  --security-opt seccomp=unconfined \
  --network host \
  dbcfileviewer:latest
```

## Why This Happens

The `start_app.sh` script inside the container needs access to:
- **X11 socket**: `/tmp/.X11-unix/X0` → Not mounted by default
- **Wayland socket**: `/mnt/wslg/runtime-dir/wayland-0` → Not mounted by default
- **WSLg GPU libs**: `/usr/lib/wsl` → Not mounted by default

Without these mounts, the script correctly reports "No display server found" and uses offscreen rendering (no visible GUI).

## What the Scripts Do

The `run-docker-gui.sh` (called by `run-docker-gui.ps1`) automatically:
1. ✓ Detects WSL vs Linux environment
2. ✓ Finds and mounts Wayland socket from WSLg
3. ✓ Mounts X11 socket for fallback
4. ✓ Mounts WSL GPU libraries for hardware acceleration
5. ✓ Sets correct environment variables (DISPLAY, WAYLAND_DISPLAY, QT_QPA_PLATFORM)
6. ✓ Configures Qt to use Wayland with X11 fallback

## Troubleshooting

### "No display server found"
- Make sure you're using `run-docker-gui.ps1` or `run-docker-gui.sh`
- Don't run `docker run` directly without the proper mounts

### PowerShell script won't run
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Container exited immediately"
Check the logs to see what `start_app.sh` detected:
```bash
docker logs dbc-parser-gui
```

### GUI still doesn't appear
1. Verify WSLg is working:
   ```bash
   wsl -e bash -c "ls -la /mnt/wslg/runtime-dir/"
   ```
2. Try running a simple X11 app in WSL:
   ```bash
   wsl -e bash -c "sudo apt-get update && sudo apt-get install -y x11-apps && xcalc"
   ```

## Files Created
- `run-docker-gui.ps1` - PowerShell wrapper for Windows
- `run-docker-gui.sh` - Bash script with auto-detection (WSL/Linux)
- `start_app.sh` - Container entrypoint (inside Docker image)

## See Also
- `DOCKER_WSL_GUI.md` - Comprehensive setup guide
- `WSL_GUI_SETUP_SUMMARY.md` - Technical summary
