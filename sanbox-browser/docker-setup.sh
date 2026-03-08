#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="sandbox-browser:bookworm-slim"

docker build -t "${IMAGE_NAME}" -f Dockerfile .
echo "Built ${IMAGE_NAME}"
