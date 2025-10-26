#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=${IMAGE_NAME:-dbcfileviewer-dev:latest}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

echo "Building dev image: ${IMAGE_NAME}"
docker build -f .devcontainer/Dockerfile -t "${IMAGE_NAME}" "${REPO_ROOT}"
echo "Done."

