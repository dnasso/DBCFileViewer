# Running DBC Parser GUI in Docker (Linux & WSL2)

## Prerequisites

### For WSL2 (Windows)
1. **Windows 11** (or Windows 10 with WSLg backport)
2. **WSL2** installed and configured
3. **Docker Desktop** with WSL2 backend enabled
4. **WSLg** (Windows Subsystem for Linux GUI) - comes with Windows 11 by default

### For Native Linux
1. **Docker** installed
2. **X11** or **Wayland** display server
3. **xhost** utility (usually in `x11-xserver-utils` or `xorg-x11-server-utils` package)

## Quick Start

### 1. Build the Docker Image

From terminal (WSL or Linux) in the project directory:

```bash
docker build -f .devcontainer/Dockerfile.fixed -t dbcfileviewer:latest .
```

### 2. Run the Application

Use the provided cross-platform script (works on both Linux and WSL):

```bash
chmod +x run-docker-gui.sh
./run-docker-gui.sh
```

The script automatically detects your environment (WSL vs Native Linux) and configures GUI forwarding appropriately.

## Manual Docker Run (Alternative)

### For WSL2
```bash
docker run -it --rm \
  --name dbc-parser-gui \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v /run/user/$(id -u)/wayland-0:/tmp/wayland-0:rw \
  -e DISPLAY=$DISPLAY \
  -e WAYLAND_DISPLAY=wayland-0 \
  -e XDG_RUNTIME_DIR=/tmp \
  -e QT_QPA_PLATFORM=wayland;xcb \
  -v /usr/lib/wsl:/usr/lib/wsl:ro \
  -e LD_LIBRARY_PATH=/usr/lib/wsl/lib \
  --device=/dev/dxg \
  -v $(pwd)/logs:/app/logs:rw \
  -v $(pwd)/config:/app/config:rw \
  --network host \
  dbcfileviewer:latest
```

### For Native Linux
```bash
# Enable X11 forwarding
xhost +local:

docker run -it --rm \
  --name dbc-parser-gui \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v /run/user/$(id -u)/${WAYLAND_DISPLAY}:/tmp/wayland-0:rw \
  -e DISPLAY=$DISPLAY \
  -e WAYLAND_DISPLAY=wayland-0 \
  -e XDG_RUNTIME_DIR=/tmp \
  -e QT_QPA_PLATFORM=wayland;xcb \
  --device=/dev/dri \
  -v $(pwd)/logs:/app/logs:rw \
  -v $(pwd)/config:/app/config:rw \
  --network host \
  dbcfileviewer:latest
```

## Troubleshooting

### GUI Not Showing

#### WSL2 (Windows)
1. **Check WSLg is running:**
   ```bash
   echo $WAYLAND_DISPLAY
   # Should output: wayland-0
   ```

2. **Check X11 display:**
   ```bash
   echo $DISPLAY
   # Should output: :0
   ```

3. **Check Wayland socket:**
   ```bash
   ls -la /run/user/$(id -u)/wayland-0
   # Should show a socket file
   ```

4. **Restart WSL:**
   ```powershell
   # In PowerShell (Windows side)
   wsl --shutdown
   wsl
   ```

#### Native Linux
1. **Check display server:**
   ```bash
   echo $DISPLAY
   # Should output something like :0 or :1
   
   echo $WAYLAND_DISPLAY
   # Might output wayland-0 if using Wayland
   ```

2. **Enable X11 forwarding:**
   ```bash
   xhost +local:
   ```

3. **Check display sockets:**
   ```bash
   ls -la /tmp/.X11-unix/
   # Should show X0 or similar
   
   ls -la /run/user/$(id -u)/wayland-*
   # Should show Wayland socket if using Wayland
   ```

4. **Test with simple app:**
   ```bash
   sudo apt-get install x11-apps
   xclock
   # Should open a clock window
   ```

### Docker Access Issues

If Docker requires sudo:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### WSLg Not Working

Restart WSL:
```powershell
# In PowerShell (Windows side)
wsl --shutdown
wsl
```

### Qt Platform Plugin Error

If you see "Could not load the Qt platform plugin":

1. The app will try Wayland first, then fallback to X11
2. Check the container logs:
   ```bash
   docker logs dbc-parser-wsl
   ```

## Architecture

### WSLg (Windows Subsystem for Linux GUI)

WSLg provides:
- **Wayland compositor** for native Linux GUI apps
- **X11 server** (XWayland) for X11-based apps
- **PulseAudio** for audio
- **GPU acceleration** via DXG driver

### Docker Image Structure

The `Dockerfile.fixed` uses multi-stage build:

1. **Builder stage**: Compiles Qt application with all dependencies
2. **Runtime stage**: Minimal image with only runtime libraries
   - Includes both Wayland and X11 support
   - Qt configured to try Wayland first, fallback to X11

### Socket Mounting

The run script mounts:
- `/tmp/.X11-unix` - X11 socket for XWayland
- `/run/user/$(id -u)/wayland-0` - Wayland socket from WSLg
- `/usr/lib/wsl` - WSL GPU libraries (optional, for acceleration)

## Performance Tips

1. **Use Wayland** (default) - better performance than X11
2. **GPU acceleration** - automatically enabled if `/dev/dxg` exists
3. **Host networking** - reduces overhead for GUI forwarding

## Environment Variables

Key environment variables set in the container:

- `DISPLAY=:0` - X11 display server
- `WAYLAND_DISPLAY=wayland-0` - Wayland display
- `QT_QPA_PLATFORM=wayland;xcb` - Qt tries Wayland first, X11 as fallback
- `XDG_RUNTIME_DIR=/tmp` - Runtime directory for sockets
- `QT_XCB_GL_INTEGRATION=none` - Disable GLX integration (can cause issues)

## Debugging

Enable Qt debug logging:
```bash
docker run -it --rm \
  ... \
  -e QT_DEBUG_PLUGINS=1 \
  -e QT_LOGGING_RULES='qt.qpa.*=true' \
  dbcfileviewer:latest
```

View container logs in real-time:
```bash
docker logs -f dbc-parser-wsl
```

## Known Issues

1. **Font rendering** may look different than native Windows
2. **High DPI** scaling might need adjustment
3. **Some Qt styles** may not work perfectly in Wayland mode

## Additional Resources

- [WSLg Documentation](https://github.com/microsoft/wslg)
- [Docker Desktop WSL2 Backend](https://docs.docker.com/desktop/windows/wsl/)
- [Qt Wayland Compositor](https://doc.qt.io/qt-6/qtwaylandcompositor-index.html)
