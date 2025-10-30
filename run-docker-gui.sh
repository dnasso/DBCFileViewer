#!/bin/bash
# Script to run DBC Parser Docker container with GUI support
# Supports: Native Linux, WSL2 (Windows), and standard X11 setups

set -e


# Docker image name
IMAGE_NAME="dbcfileviewer:latest"

# Debug: print working directory and image name
echo "[DEBUG] Working directory: $(pwd)"
echo "[DEBUG] IMAGE_NAME: $IMAGE_NAME"

# Check if IMAGE_NAME is empty
if [ -z "$IMAGE_NAME" ]; then
    echo "[ERROR] IMAGE_NAME is empty. Please set the Docker image name."
    exit 2
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect if running in WSL
detect_environment() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        print_success "Detected: Windows Subsystem for Linux (WSL)"
        IS_WSL=true
    else
        print_success "Detected: Native Linux"
        IS_WSL=false
    fi
}

print_info "Detecting environment and setting up GUI forwarding..."
detect_environment

# Detect Wayland support
USE_WAYLAND=false
WAYLAND_SOCKET_NAME="wayland-0"

# Check if Wayland sockets exist
if [ "$IS_WSL" = true ]; then
    # WSL: Check for WSLg Wayland socket
    if [ -S "/mnt/wslg/runtime-dir/${WAYLAND_SOCKET_NAME}" ] || [ -S "/run/user/$(id -u)/${WAYLAND_SOCKET_NAME}" ]; then
        print_success "WSLg detected with Wayland support"
        USE_WAYLAND=true
        # Set WAYLAND_DISPLAY if not already set
        export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-${WAYLAND_SOCKET_NAME}}"
    fi
else
    # Linux: Check for Wayland compositor
    if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -S "/run/user/$(id -u)/${WAYLAND_SOCKET_NAME}" ]; then
        print_success "Wayland compositor detected"
        USE_WAYLAND=true
        export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-${WAYLAND_SOCKET_NAME}}"
    fi
fi

if [ "$USE_WAYLAND" = false ]; then
    print_info "Wayland not detected, using X11"
fi

# Set DISPLAY if not already set
if [ -z "${DISPLAY:-}" ]; then
    export DISPLAY=:0
    print_info "Set DISPLAY=:0"
fi

# Build Docker run command
DOCKER_CMD="docker run -it --rm --name dbc-parser-gui"

# Setup Wayland if available

HAS_WAYLAND=false
if [ "$USE_WAYLAND" = true ]; then
    # Find Wayland socket - try multiple locations
    WAYLAND_SOCKET=""
    # Priority order: WSLg > XDG_RUNTIME_DIR > /run/user
    for socket_path in \
        "/mnt/wslg/runtime-dir/${WAYLAND_SOCKET_NAME}" \
        "${XDG_RUNTIME_DIR:-/tmp}/${WAYLAND_SOCKET_NAME}" \
        "/run/user/$(id -u)/${WAYLAND_SOCKET_NAME}"; do
        if [ -S "$socket_path" ]; then
            WAYLAND_SOCKET="$socket_path"
            break
        fi
    done
    if [ -n "$WAYLAND_SOCKET" ] && [ -S "$WAYLAND_SOCKET" ]; then
        print_success "Mounting Wayland socket: $WAYLAND_SOCKET"
        DOCKER_CMD="$DOCKER_CMD -v ${WAYLAND_SOCKET}:/tmp/${WAYLAND_SOCKET_NAME}:rw"
        DOCKER_CMD="$DOCKER_CMD -e WAYLAND_DISPLAY=${WAYLAND_SOCKET_NAME}"
        DOCKER_CMD="$DOCKER_CMD -e XDG_RUNTIME_DIR=/tmp"
        HAS_WAYLAND=true
    else
        print_warning "Wayland socket not found"
    fi
fi

# Setup X11 (always try to mount for fallback)
HAS_X11=false
if [ -d /tmp/.X11-unix ]; then
    print_success "Mounting X11 socket"
    DOCKER_CMD="$DOCKER_CMD -v /tmp/.X11-unix:/tmp/.X11-unix:rw"
    DOCKER_CMD="$DOCKER_CMD -e DISPLAY=${DISPLAY:-:0}"
    HAS_X11=true
    # Enable X11 forwarding on native Linux
    if [ "$IS_WSL" = false ] && command -v xhost &> /dev/null; then
        xhost +local: 2>/dev/null || print_warning "Could not run xhost"
    fi
fi

# Set Qt platform based on what's available
# Force X11 (xcb) for WSL to avoid Wayland crashes
if [ "$IWSL" = true ]; then
    DOCKER_CMD="$DOCKER_CMD -e QT_QPA_PLATFORM=xcb"
    print_success "Qt will use X11 (forced for WSL stability)"
elif [ "$HAS_WAYLAND" = true ] && [ "$HAS_X11" = true ]; then
    DOCKER_CMD="$DOCKER_CMD -e 'QT_QPA_PLATFORM=wayland;xcb'"
    print_success "Qt will use Wayland with X11 fallback"
elif [ "$HAS_WAYLAND" = true ]; then
    DOCKER_CMD="$DOCKER_CMD -e QT_QPA_PLATFORM=wayland"
    print_success "Qt will use Wayland"
elif [ "$HAS_X11" = true ]; then
    DOCKER_CMD="$DOCKER_CMD -e QT_QPA_PLATFORM=xcb"
    print_success "Qt will use X11"
else
    DOCKER_CMD="$DOCKER_CMD -e QT_QPA_PLATFORM=offscreen"
    print_error "No display server found! GUI will not work."
fi

# Mount PulseAudio socket for audio (optional, both WSL and Linux)
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
PULSE_SOCKET="${RUNTIME_DIR}/pulse/native"
if [ -S "$PULSE_SOCKET" ]; then
    print_success "Mounting PulseAudio socket"
    PULSE_DIR="$(dirname "$PULSE_SOCKET")"
    DOCKER_CMD="$DOCKER_CMD -v ${PULSE_DIR}:/tmp/pulse:ro"
    DOCKER_CMD="$DOCKER_CMD -e PULSE_SERVER=unix:/tmp/pulse/native"
fi


# Add GPU support
if [ "$IS_WSL" = true ]; then
    # WSL-specific GPU support
    if [ -d /usr/lib/wsl ]; then
        print_success "Mounting WSL GPU libraries"
        DOCKER_CMD="$DOCKER_CMD -v /usr/lib/wsl:/usr/lib/wsl:ro"
        DOCKER_CMD="$DOCKER_CMD -e LD_LIBRARY_PATH=/usr/lib/wsl/lib"
        if [ -c /dev/dxg ]; then
            DOCKER_CMD="$DOCKER_CMD --device=/dev/dxg"
        fi
    fi
else
    # Native Linux GPU support
    if [ -d /dev/dri ]; then
        print_success "Mounting DRI devices for GPU acceleration"
        DOCKER_CMD="$DOCKER_CMD --device=/dev/dri"
    fi
fi

# Use software rendering for WSL stability (avoids GPU-related crashes)
if [ "$IS_WSL" = true ]; then
    DOCKER_CMD="$DOCKER_CMD -e QT_XCB_GL_INTEGRATION=none"
else
    DOCKER_CMD="$DOCKER_CMD -e QT_XCB_GL_INTEGRATION=xcb_egl"
fi
DOCKER_CMD="$DOCKER_CMD --security-opt seccomp=unconfined --network host"

# Add volume mounts for logs and config
mkdir -p logs config
DOCKER_CMD="$DOCKER_CMD -v $(pwd)/logs:/app/logs:rw -v $(pwd)/config:/app/config:rw"

# Add the image name
DOCKER_CMD="$DOCKER_CMD $IMAGE_NAME"

print_info "Starting container..."
echo ""
echo "Command: $DOCKER_CMD"
echo ""
echo "[DEBUG] Running command directly (not eval)..."

# Run the command directly without eval to avoid quoting issues
$DOCKER_CMD
