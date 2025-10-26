#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=${IMAGE_NAME:-dbcfileviewer-dev:latest}
CONTAINER_NAME=${CONTAINER_NAME:-dbcfileviewer-dev}

# Ensure DISPLAY is set on Linux
if [[ -z "${DISPLAY:-}" ]]; then
  export DISPLAY=:0
fi

# Allow local connections to X server (if needed)
if command -v xhost >/dev/null 2>&1; then
  xhost +local:root >/dev/null 2>&1 || true
fi

echo "Running ${CONTAINER_NAME} from ${IMAGE_NAME} with X11 forwarding"
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
docker run --rm -it \
  --name "${CONTAINER_NAME}" \
  -e DISPLAY \
  -e QT_QPA_PLATFORM=xcb \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v "$(pwd)":"/workspaces/DBCFileViewer" \
  -w "/workspaces/DBCFileViewer" \
  "${IMAGE_NAME}" bash

