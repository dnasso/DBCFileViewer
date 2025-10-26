#!/bin/bash
# run-docker-mac-simple.sh - Simple runner for DBC Parser on macOS
# Assumes XQuartz is already installed and running

IMAGE_NAME="dbc-parser:debian-slim"

# Start XQuartz if not running
if ! pgrep -x "XQuartz" > /dev/null; then
    echo "Starting XQuartz..."
    open -a XQuartz
    sleep 3
fi

# Allow X11 connections from localhost
xhost +local: > /dev/null 2>&1

# Get Mac IP address
IP=$(ifconfig en0 | grep "inet " | awk '{print $2}')
[ -z "$IP" ] && IP=$(ifconfig en1 | grep "inet " | awk '{print $2}')
[ -z "$IP" ] && IP="host.docker.internal"

echo "Running DBC Parser..."
echo "Display: $IP:0"

# Run container
docker run --rm \
    -e DISPLAY="$IP:0" \
    -e QT_QPA_PLATFORM=xcb \
    -v "$(pwd):/data" \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
    --network host \
    "$IMAGE_NAME"
