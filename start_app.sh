#!/bin/bash
set -euo pipefail

echo "=========================================="
echo "Starting DBC Parser Application..."
echo "=========================================="
echo "Arguments: $*"

RUN_DIR="/app"

# Function to setup X11 forwarding
setup_x11() {
    echo ""
    echo "[X11 Setup]"
    
    # Check if DISPLAY is set
    if [[ -z "${DISPLAY:-}" ]]; then
        echo "⚠️  DISPLAY not set, trying to detect..."
        if [[ -S /tmp/.X11-unix/X0 ]]; then
            export DISPLAY=:0
            echo "✓ Set DISPLAY=:0"
        elif [[ -S /tmp/.X11-unix/X1 ]]; then
            export DISPLAY=:1
            echo "✓ Set DISPLAY=:1"
        else
            echo "✗ No X11 socket found"
            return 1
        fi
    else
        echo "✓ DISPLAY already set to: $DISPLAY"
    fi
    
    # Check X11 socket accessibility
    if [[ -d /tmp/.X11-unix ]]; then
        echo "✓ /tmp/.X11-unix directory exists"
        ls -la /tmp/.X11-unix/ 2>/dev/null || echo "  (empty or no permissions)"
    else
        echo "✗ /tmp/.X11-unix directory not found"
        return 1
    fi
    
    # Set X11 authority if available
    if [[ -n "${XAUTHORITY:-}" ]] && [[ -f "$XAUTHORITY" ]]; then
        echo "✓ XAUTHORITY found: $XAUTHORITY"
    else
        echo "⚠️  XAUTHORITY not set or file not found"
    fi
    
    return 0
}

# Function to setup Wayland forwarding
setup_wayland() {
    echo ""
    echo "[Wayland Setup]"
    
    # Check for Wayland socket
    WAYLAND_SOCKET=""
    
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        echo "✓ WAYLAND_DISPLAY set to: $WAYLAND_DISPLAY"
        
        # Check common Wayland socket locations
        if [[ -S "/tmp/vscode-wayland-${WAYLAND_DISPLAY}" ]]; then
            WAYLAND_SOCKET="/tmp/vscode-wayland-${WAYLAND_DISPLAY}"
        elif [[ -S "/tmp/${WAYLAND_DISPLAY}" ]]; then
            WAYLAND_SOCKET="/tmp/${WAYLAND_DISPLAY}"
        elif [[ -S "${XDG_RUNTIME_DIR:-/run/user/1000}/${WAYLAND_DISPLAY}" ]]; then
            WAYLAND_SOCKET="${XDG_RUNTIME_DIR:-/run/user/1000}/${WAYLAND_DISPLAY}"
        fi
    else
        echo "⚠️  WAYLAND_DISPLAY not set, checking for sockets..."
        
        # Try to find any wayland socket
        for socket in /tmp/vscode-wayland-* /tmp/wayland-* "${XDG_RUNTIME_DIR:-/run/user/1000}"/wayland-*; do
            if [[ -S "$socket" ]]; then
                WAYLAND_SOCKET="$socket"
                export WAYLAND_DISPLAY=$(basename "$socket")
                echo "✓ Found Wayland socket: $socket"
                break
            fi
        done
    fi
    
    if [[ -n "$WAYLAND_SOCKET" ]] && [[ -S "$WAYLAND_SOCKET" ]]; then
        echo "✓ Wayland socket accessible: $WAYLAND_SOCKET"
        export WAYLAND_SOCKET
        return 0
    else
        echo "✗ No accessible Wayland socket found"
        return 1
    fi
}

# Function to determine best Qt platform
setup_qt_platform() {
    echo ""
    echo "[Qt Platform Setup]"
    
    local has_x11=false
    local has_wayland=false
    
    setup_x11 && has_x11=true || has_x11=false
    setup_wayland && has_wayland=true || has_wayland=false
    
    # Determine the best QT_QPA_PLATFORM
    if $has_wayland && $has_x11; then
        export QT_QPA_PLATFORM="wayland;xcb"
        echo "✓ Using Qt platform: wayland;xcb (Wayland with X11 fallback)"
    elif $has_wayland; then
        export QT_QPA_PLATFORM="wayland"
        echo "✓ Using Qt platform: wayland"
    elif $has_x11; then
        export QT_QPA_PLATFORM="xcb"
        echo "✓ Using Qt platform: xcb (X11)"
    else
        export QT_QPA_PLATFORM="offscreen"
        echo "⚠️  No display server found, using offscreen rendering"
        echo "⚠️  GUI will not be visible!"
    fi
    
    # Additional Qt environment variables for better compatibility
    export QT_XCB_GL_INTEGRATION=none
    export QT_LOGGING_RULES="qt.qpa.*=true"
    
    echo ""
    echo "[Environment Summary]"
    echo "DISPLAY=${DISPLAY:-<not set>}"
    echo "WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-<not set>}"
    echo "QT_QPA_PLATFORM=$QT_QPA_PLATFORM"
    echo "=========================================="
}

start_gui() {
    echo ""
    echo "[Starting GUI Application]"
    
    cd "$RUN_DIR"

    echo ""
    echo "Launching appDBC_Parser..."
    echo "Environment:"
    echo "  DISPLAY=${DISPLAY:-<not set>}"
    echo "  WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-<not set>}"
    echo "  QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-<not set>}"
    echo "  XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-<not set>}"
    echo "=========================================="
    exec ./appDBC_Parser
}

MODE="${1:-gui}"
case "$MODE" in
    gui|"")
        start_gui "$@"
        ;;
    *)
        echo "Unknown command: $MODE"
        echo "Usage: $0 [gui]"
        exit 1
        ;;
esac
