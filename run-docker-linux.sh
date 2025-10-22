#!/bin/bash
# DBC Parser Docker Runner for Linux
# Runs the DBC Parser Docker image with X11 forwarding

set -e

IMAGE_NAME="dbc-parser:debian-slim"
CONTAINER_NAME="dbc-parser"

echo "========================================"
echo "DBC Parser Docker Runner for Linux"
echo "========================================"
echo ""

# Check if Docker is installed
echo "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "❌ ERROR: Docker is not installed"
    echo ""
    echo "Install Docker:"
    echo "  Ubuntu/Debian: sudo apt install docker.io"
    echo "  Fedora: sudo dnf install docker"
    echo "  Arch: sudo pacman -S docker"
    echo ""
    echo "Then enable and start Docker:"
    echo "  sudo systemctl enable docker"
    echo "  sudo systemctl start docker"
    echo "  sudo usermod -aG docker $USER"
    echo "  (Log out and back in for group changes to take effect)"
    exit 1
fi

echo "✓ Docker is installed: $(docker --version)"

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "❌ ERROR: Docker daemon is not running"
    echo ""
    echo "Start Docker:"
    echo "  sudo systemctl start docker"
    echo ""
    echo "Or if you need to add yourself to the docker group:"
    echo "  sudo usermod -aG docker $USER"
    echo "  (Then log out and back in)"
    exit 1
fi

echo "✓ Docker is running"

# Check if image exists
echo "Checking Docker image..."
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo "❌ ERROR: Docker image '$IMAGE_NAME' not found"
    echo ""
    echo "Build the image first:"
    echo "  docker build -f Dockerfile.linux -t $IMAGE_NAME ."
    exit 1
fi

echo "✓ Docker image '$IMAGE_NAME' found"
echo ""

# Check if X11 is available
echo "Checking X11 display..."
if [ -z "$DISPLAY" ]; then
    echo "⚠️  WARNING: DISPLAY environment variable not set"
    echo "Defaulting to :0"
    export DISPLAY=:0
fi

echo "✓ Using DISPLAY=$DISPLAY"

# Allow X11 connections from Docker containers
echo "Configuring X11 access..."
xhost +local:docker &> /dev/null || {
    echo "⚠️  WARNING: Could not run 'xhost +local:docker'"
    echo "X11 forwarding may not work properly"
    echo ""
    echo "If the app fails to start, try:"
    echo "  xhost +local:docker"
    echo "  or"
    echo "  xhost +local:root"
}

echo "✓ X11 access configured"
echo ""

echo "========================================"
echo "Starting DBC Parser Container..."
echo "========================================"
echo ""
echo "Container name: $CONTAINER_NAME"
echo "Display: $DISPLAY"
echo "Working directory mounted: $(pwd)"
echo ""

# Remove existing container if it exists
docker rm -f "$CONTAINER_NAME" &> /dev/null || true

# Run the container
docker run --rm \
    --name "$CONTAINER_NAME" \
    -e DISPLAY="$DISPLAY" \
    -e QT_QPA_PLATFORM=xcb \
    -e QT_LOGGING_RULES="*.debug=false" \
    -e LIBGL_ALWAYS_INDIRECT=0 \
    -e QT_XCB_GL_INTEGRATION=xcb_glx \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v "$(pwd):/workspace:rw" \
    --network host \
    --ipc=host \
    "$IMAGE_NAME"

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "========================================"
    echo "DBC Parser exited successfully"
    echo "========================================"
else
    echo "========================================"
    echo "❌ ERROR: Container failed or crashed!"
    echo "========================================"
    echo ""
    echo "Troubleshooting tips:"
    echo "1. Check X11 access: xhost +local:docker"
    echo "2. Verify DISPLAY: echo \$DISPLAY"
    echo "3. Test X11: xeyes (should show a window)"
    echo "4. Check Docker logs: docker logs $CONTAINER_NAME"
    echo "5. Try with --privileged flag (add to docker run above)"
    echo ""
    echo "If you see 'could not connect to display', try:"
    echo "  xhost +local:root"
    echo "  xhost +SI:localuser:root"
fi

exit $EXIT_CODE
