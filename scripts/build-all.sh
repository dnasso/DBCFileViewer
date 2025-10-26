#!/bin/bash
set -e

APP_NAME="DBC_Parser"
VERSION="0.0.1"
REGISTRY="docker.io/GuyFerrari"

echo "Building Qt application for multiple platforms..."

# Build Linux image
echo "Building Linux image..."
docker build -f Dockerfile.linux \
  -t ${REGISTRY}/${APP_NAME}:${VERSION}-linux \
  -t ${REGISTRY}/${APP_NAME}:latest-linux \
  .

# Build Windows image (requires Windows Docker host or Docker Desktop with Windows containers)
echo "Building Windows image..."
docker build -f Dockerfile.windows \
  -t ${REGISTRY}/${APP_NAME}:${VERSION}-windows \
  -t ${REGISTRY}/${APP_NAME}:latest-windows \
  .

# Push images
echo "Pushing images..."
docker push ${REGISTRY}/${APP_NAME}:${VERSION}-linux
docker push ${REGISTRY}/${APP_NAME}:latest-linux
docker push ${REGISTRY}/${APP_NAME}:${VERSION}-windows
docker push ${REGISTRY}/${APP_NAME}:latest-windows

# Create and push multi-platform manifest
echo "Creating multi-platform manifest..."
docker manifest create ${REGISTRY}/${APP_NAME}:${VERSION} \
  ${REGISTRY}/${APP_NAME}:${VERSION}-linux \
  ${REGISTRY}/${APP_NAME}:${VERSION}-windows

docker manifest create ${REGISTRY}/${APP_NAME}:latest \
  ${REGISTRY}/${APP_NAME}:latest-linux \
  ${REGISTRY}/${APP_NAME}:latest-windows

docker manifest push ${REGISTRY}/${APP_NAME}:${VERSION}
docker manifest push ${REGISTRY}/${APP_NAME}:latest

echo "Build complete!"