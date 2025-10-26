#!/bin/bash
# run-docker-mac.sh - Run DBC Parser Docker container on macOS
# This script handles X11 display setup for GUI applications on Mac

set -e

IMAGE_NAME="dbc-parser:debian-slim"
CONTAINER_NAME="dbc-parser-app"

echo "========================================"
echo "DBC Parser Docker Runner for macOS"
echo "========================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ ERROR: Docker is not installed!"
    echo ""
    echo "Please install Docker Desktop for Mac from:"
    echo "https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ ERROR: Docker is not running!"
    echo ""
    echo "Please start Docker Desktop and try again."
    exit 1
fi

echo "✓ Docker is installed and running"

# Check if XQuartz is installed
if ! command -v xquartz &> /dev/null && [ ! -d "/Applications/Utilities/XQuartz.app" ]; then
    echo ""
    echo "⚠️  WARNING: XQuartz (X11) is not installed!"
    echo ""
    echo "XQuartz is required to display GUI applications from Docker."
    echo ""
    echo "Installation options:"
    echo "1. Install via Homebrew (recommended):"
    echo "   brew install --cask xquartz"
    echo ""
    echo "2. Download from: https://www.xquartz.org/"
    echo ""
    read -p "Do you want to install XQuartz via Homebrew now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! command -v brew &> /dev/null; then
            echo "❌ ERROR: Homebrew is not installed!"
            echo ""
            echo "Install Homebrew first from: https://brew.sh/"
            echo "Then run this script again."
            exit 1
        fi
        
        echo "Installing XQuartz..."
        brew install --cask xquartz
        
        echo ""
        echo "✓ XQuartz installed successfully!"
        echo ""
        echo "⚠️  IMPORTANT: You need to log out and log back in (or restart your Mac)"
        echo "   for XQuartz to work properly on first installation."
        echo ""
        read -p "Press Enter to continue anyway, or Ctrl+C to exit and restart..."
    else
        echo "Please install XQuartz manually and run this script again."
        exit 1
    fi
else
    echo "✓ XQuartz is installed"
fi

# Check if the Docker image exists
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo ""
    echo "❌ ERROR: Docker image '$IMAGE_NAME' not found!"
    echo ""
    echo "Please build the image first:"
    echo "  docker build -f Dockerfile.linux -t $IMAGE_NAME ."
    echo ""
    echo "Or pull it from Docker Hub:"
    echo "  docker pull <username>/$IMAGE_NAME"
    exit 1
fi

echo "✓ Docker image '$IMAGE_NAME' found"
echo ""

# Get the IP address for X11 forwarding
# On macOS, we need to allow connections from Docker
IP=$(ifconfig en0 | grep "inet " | awk '{print $2}')
if [ -z "$IP" ]; then
    # Try Wi-Fi interface if ethernet is not available
    IP=$(ifconfig en1 | grep "inet " | awk '{print $2}')
fi

if [ -z "$IP" ]; then
    echo "⚠️  WARNING: Could not detect IP address. Using host.docker.internal"
    DISPLAY_VAR="host.docker.internal:0"
else
    echo "✓ Detected IP address: $IP"
    DISPLAY_VAR="$IP:0"
fi

echo ""
echo "Setting up X11 permissions..."

# Enable X11 forwarding from Docker
# This allows Docker containers to connect to the Mac's display
xhost + "$IP" &> /dev/null || xhost +local: &> /dev/null || true

echo "✓ X11 permissions configured"
echo ""
echo "========================================"
echo "Starting DBC Parser..."
echo "========================================"
echo ""
echo "Container name: $CONTAINER_NAME"
echo "Display: $DISPLAY_VAR"
echo ""

# Remove existing container if it exists
docker rm -f "$CONTAINER_NAME" &> /dev/null || true

# Run the container
# Use --rm to automatically remove container when it exits
# Mount current directory for file access
docker run --rm \
    --name "$CONTAINER_NAME" \
    -e DISPLAY="$DISPLAY_VAR" \
    -e QT_QPA_PLATFORM=xcb \
    -e QT_LOGGING_RULES="*.debug=false" \
    -v "$(pwd):/data" \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
    --network host \
    "$IMAGE_NAME"

echo ""
echo "========================================"
echo "DBC Parser exited"
echo "========================================"

# Clean up X11 permissions
xhost - "$IP" &> /dev/null || xhost -local: &> /dev/null || true
