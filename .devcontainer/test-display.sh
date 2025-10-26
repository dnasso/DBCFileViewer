#!/bin/bash
# Test display configuration and Qt GUI support

echo "=== Display Configuration Test ==="
echo

echo "Environment variables:"
echo "  DISPLAY=$DISPLAY"
echo "  WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
echo "  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
echo "  QT_QPA_PLATFORM=$QT_QPA_PLATFORM"
echo

# Check mounts
echo "Mount points:"
if [ -d "/mnt/wslg" ]; then
    echo "  ✓ /mnt/wslg exists"
    if [ -S "/mnt/wslg/runtime-dir/wayland-0" ]; then
        echo "    ✓ Wayland socket found"
    else
        echo "    ✗ No Wayland socket"
    fi
else
    echo "  ✗ /mnt/wslg not mounted"
fi

if [ -d "/tmp/.X11-unix" ]; then
    echo "  ✓ /tmp/.X11-unix exists"
    if [ -S "/tmp/.X11-unix/X0" ]; then
        echo "    ✓ X11 socket found"
    else
        echo "    ✗ No X11 socket"
    fi
else
    echo "  ✗ /tmp/.X11-unix not mounted"
fi
echo

# Test host.docker.internal
echo "Network connectivity:"
if getent hosts host.docker.internal >/dev/null 2>&1; then
    ip=$(getent hosts host.docker.internal | awk '{print $1}')
    echo "  ✓ host.docker.internal resolves to $ip"
    
    # Test X11 port if using remote display
    if [[ "$DISPLAY" == *"host.docker.internal"* ]] || [[ "$DISPLAY" == *"$ip"* ]]; then
        if timeout 2 bash -c "</dev/tcp/$ip/6000" 2>/dev/null; then
            echo "    ✓ X11 port 6000 is open"
        else
            echo "    ✗ X11 port 6000 is closed"
            echo "      Start VcXsrv on Windows host and allow through firewall"
        fi
    fi
else
    echo "  ✗ host.docker.internal does not resolve"
fi
echo

# Test simple X app if available
echo "GUI test:"
if command -v xclock >/dev/null 2>&1; then
    echo "  Testing xclock..."
    if timeout 5 xclock -display "$DISPLAY" &>/dev/null & then
        sleep 1
        if pgrep xclock >/dev/null; then
            echo "    ✓ xclock started successfully"
            pkill xclock
        else
            echo "    ✗ xclock failed to start"
        fi
    else
        echo "    ✗ xclock command failed"
    fi
else
    echo "  ⚠ xclock not installed (install x11-apps to test)"
fi
echo

echo "=== Test Complete ==="
echo
echo "To run your Qt app:"
echo "  ./build/appDBC_Parser"
