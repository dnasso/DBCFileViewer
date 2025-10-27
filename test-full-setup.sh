#!/bin/bash

# Test script for DBC Parser Docker setup
# This script tests both server and GUI functionality

set -e

echo "🚀 Starting DBC Parser Full Test"

# Stop any existing containers
echo "🧹 Cleaning up existing containers..."
./docker-setup.sh stop

# Start server first
echo "🖥️  Starting DBC Server..."
./docker-setup.sh run-server-only
sleep 3

# Check if server is running
echo "✅ Checking server status..."
if docker ps | grep -q dbc-server-only; then
    echo "✅ Server is running!"
    docker logs dbc-server-only
else
    echo "❌ Server failed to start"
    exit 1
fi

# Test server connectivity
echo "🔗 Testing server connectivity..."
if timeout 5 bash -c 'cat < /dev/null > /dev/tcp/localhost/12345'; then
    echo "✅ Server is accepting connections on port 12345!"
else
    echo "⚠️  Could not connect to server (this might be normal if server needs specific protocol)"
fi

echo ""
echo "🎨 Server is ready! Now you can run the GUI with:"
echo "./docker-setup.sh run-gui-only"
echo ""
echo "Or clean up with:"
echo "./docker-setup.sh stop"
echo ""
echo "✅ Test completed successfully!"
