# Docker GUI Setup Summary for Linux & WSL2

## Cross-Platform Compatibility

This setup now works on:
- ✅ **Windows with WSL2** (WSLg support)
- ✅ **Native Linux** (X11 or Wayland)
- ✅ **Auto-detection** of environment

## Changes Made

### 1. **Updated Dockerfile.fixed**
   - Added Wayland runtime libraries (`libwayland-client0`, `libwayland-cursor0`, `libwayland-egl1`)
   - Added `libdbus-1-3` for better IPC support
   - Changed default `QT_QPA_PLATFORM` to `wayland;xcb` (tries Wayland first, X11 fallback)
   - Added `QT_XCB_GL_INTEGRATION=none` to avoid GLX issues
   - Set `XDG_RUNTIME_DIR=/tmp` for socket location

### 2. **Created run-docker-gui.sh** (formerly run-docker-wsl.sh)
   - **Cross-platform** launch script (Linux + WSL)
   - Automatically detects environment (WSL vs Native Linux)
   - Automatically detects Wayland vs X11
   - Mounts correct sockets based on platform
   - GPU support:
     - WSL: `/usr/lib/wsl`, `/dev/dxg`
     - Linux: `/dev/dri`
   - Sets proper environment variables for each platform

### 3. **Updated docker-setup.sh**
   - Added `detect_wsl()` function
   - Enhanced Wayland detection to find WSLg sockets (`/mnt/wslg/runtime-dir/`)
   - Added WSL GPU support mounting
   - Better error messages for WSL users

### 4. **Created DOCKER_WSL_GUI.md**
   - Comprehensive documentation
   - Troubleshooting guide
   - Architecture explanation

## How to Use

### Quick Start (Works on both Linux and WSL)

```bash
# 1. Build the image
docker build -f .devcontainer/Dockerfile.fixed -t dbcfileviewer:latest .

# 2. Run using the cross-platform script (RECOMMENDED)
chmod +x run-docker-gui.sh
./run-docker-gui.sh

# OR use the general setup script
chmod +x docker-setup.sh
./docker-setup.sh build
./docker-setup.sh run-docker
```

The script automatically detects:
- WSL vs Native Linux
- Wayland vs X11
- Available GPU support

## Key Fixes for GUI Display

### Problem: GUI not showing
**Root Cause**: Different display server configurations between WSL and Linux

**Solution (Auto-detected by script)**:

#### For WSL2:
1. Mount Wayland socket: `/run/user/$(id -u)/wayland-0` → `/tmp/wayland-0`
2. Set `WAYLAND_DISPLAY=wayland-0`
3. Set `QT_QPA_PLATFORM=wayland;xcb` (Wayland with X11 fallback)
4. Set `XDG_RUNTIME_DIR=/tmp`
5. Mount WSL GPU libraries: `/usr/lib/wsl`

#### For Native Linux:
1. Mount X11 socket: `/tmp/.X11-unix`
2. Mount Wayland socket if available: `/run/user/$(id -u)/$WAYLAND_DISPLAY`
3. Enable X11 forwarding: `xhost +local:`
4. Set `QT_QPA_PLATFORM` based on available display servers
5. Mount DRI devices for GPU: `/dev/dri`

### Problem: Qt platform plugin errors
**Root Cause**: Missing Wayland libraries or wrong platform selection

**Solution**:
1. Added Wayland runtime libraries to Dockerfile
2. Qt tries multiple platforms automatically
3. Disabled GLX integration (`QT_XCB_GL_INTEGRATION=none`)

### Problem: Slow/no GPU acceleration
**Root Cause**: Missing WSL GPU driver mount

**Solution**:
1. Mount `/usr/lib/wsl` (WSL GPU libraries)
2. Mount `/dev/dxg` device (DirectX Graphics device)
3. Set `LD_LIBRARY_PATH=/usr/lib/wsl/lib`

## Testing

### Test 1: Check WSLg is working
```bash
echo $WAYLAND_DISPLAY  # Should show: wayland-0
echo $DISPLAY          # Should show: :0
```

### Test 2: Test with simple X11 app
```bash
sudo apt-get install x11-apps
xclock  # Should open a clock window
```

### Test 3: Run the Docker container
```bash
./run-docker-wsl.sh
# GUI should appear on Windows desktop
```

## Debugging

### Enable Qt debug output
```bash
docker run -it --rm \
  -e QT_DEBUG_PLUGINS=1 \
  -e QT_LOGGING_RULES='qt.qpa.*=true' \
  ... \
  dbcfileviewer:latest
```

### Check what platform Qt is using
Look for lines like:
- `Using Qt platform: wayland` (good - native WSLg)
- `Using Qt platform: xcb` (okay - X11 fallback)
- `Using Qt platform: offscreen` (bad - no GUI)

## Architecture

### WSL2 (Windows)
```
Windows 11
    └── WSLg (Wayland Compositor)
        ├── /run/user/*/wayland-0 (Wayland socket)
        ├── /tmp/.X11-unix/X0 (XWayland socket)
        └── /usr/lib/wsl (GPU libraries)
            └── Docker Container
                └── Qt App (tries Wayland → X11 → offscreen)
```

### Native Linux
```
Linux Desktop Environment
    ├── X11 Display Server (:0)
    │   └── /tmp/.X11-unix/X0 (X11 socket)
    └── Wayland Compositor (optional)
        └── /run/user/*/wayland-0 (Wayland socket)
            └── Docker Container
                ├── /dev/dri (GPU access)
                └── Qt App (tries Wayland → X11 → offscreen)
```

## Files Modified

1. `.devcontainer/Dockerfile.fixed` - Added Wayland support for both platforms
2. `docker-setup.sh` - Environment detection (WSL/Linux) and smart mounting
3. `run-docker-gui.sh` - **NEW** Cross-platform GUI launch script (auto-detects environment)
4. `DOCKER_WSL_GUI.md` - **NEW** Documentation for both WSL and Linux
5. `WSL_GUI_SETUP_SUMMARY.md` - This file (updated for dual compatibility)

## Next Steps

1. Rebuild the Docker image:
   ```bash
   docker build -f .devcontainer/Dockerfile.fixed -t dbcfileviewer:latest .
   ```

2. Test with the cross-platform script:
   ```bash
   chmod +x run-docker-gui.sh
   ./run-docker-gui.sh
   ```
   
   **The script will automatically:**
   - Detect if you're on WSL or Linux
   - Find and mount Wayland/X11 sockets
   - Configure GPU support appropriately
   - Set the correct Qt platform

3. If it doesn't work, check `DOCKER_WSL_GUI.md` for troubleshooting

## Common Issues

**Issue**: "Could not load the Qt platform plugin"
- **Fix**: Rebuild image with updated Dockerfile.fixed

**Issue**: GUI shows but is very slow
- **Fix**: Make sure GPU mounting is working (`/usr/lib/wsl`, `/dev/dxg`)

**Issue**: No display at all
- **Fix**: Restart WSL with `wsl --shutdown` (in PowerShell), then reopen WSL

**Issue**: Socket permission denied
- **Fix**: Add `--security-opt seccomp=unconfined` to docker run

## References

- [WSLg GitHub](https://github.com/microsoft/wslg)
- [Qt Wayland](https://doc.qt.io/qt-6/qtwaylandcompositor-index.html)
- [Docker on WSL2](https://docs.docker.com/desktop/windows/wsl/)
