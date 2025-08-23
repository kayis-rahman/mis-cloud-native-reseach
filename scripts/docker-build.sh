#!/usr/bin/env bash
set -euo pipefail

# Build and push a service image to GitHub Container Registry (GHCR)
# Requirements:
#  - Environment variable GHCR_TOKEN must be set (PAT with write:packages, read:packages)
#  - GHCR_OWNER must be set (your GitHub username or org, e.g., kayis-rahman)
#  - Docker installed and running
#
# Usage examples:
#  SERVICE=identity ./scripts/docker-build.sh
#  SERVICE=identity TAG=v0.1.0 ./scripts/docker-build.sh
#  SERVICE=identity IMAGE_NAME=identity-service TAG=latest ./scripts/docker-build.sh
#
# Optional env vars:
#  - SERVICE (default: identity) — one of: identity, cart, product, order, payment
#  - IMAGE_NAME (default: same as SERVICE)
#  - TAG (default: latest)
#  - PLATFORM (optional; e.g., linux/amd64 for Apple Silicon cross-build)
#
# Resulting image: ghcr.io/${GHCR_OWNER}/${IMAGE_NAME}:${TAG}

if [[ -z "${GHCR_TOKEN:-}" ]]; then
  echo "[ERROR] GHCR_TOKEN env var is required (GitHub PAT with write:packages)." >&2
  exit 1
fi
if [[ -z "${GHCR_OWNER:-}" ]]; then
  echo "[ERROR] GHCR_OWNER env var is required (your GitHub username or org)." >&2
  exit 1
fi

SERVICE="${SERVICE:-identity}"
IMAGE_NAME="${IMAGE_NAME:-$SERVICE}"
TAG="${TAG:-latest}"

# Validate service folder
SERVICE_DIR="services/${SERVICE}"
if [[ ! -d "$SERVICE_DIR" ]]; then
  echo "[ERROR] Unknown service: $SERVICE (expected directory $SERVICE_DIR)" >&2
  exit 1
fi

IMAGE="ghcr.io/${GHCR_OWNER}/${IMAGE_NAME}:${TAG}"

echo "[INFO] Logging in to GHCR as ${GHCR_OWNER}"
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_OWNER" --password-stdin

echo "[INFO] Building image: $IMAGE"
cd "$SERVICE_DIR"

# Auto-detect ARM host and default to cross-building for linux/amd64 unless PLATFORM is explicitly set
if [[ -z "${PLATFORM:-}" ]]; then
  ARCH=$(uname -m || true)
  if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
    PLATFORM="linux/amd64"
    echo "[INFO] Detected ARM host ($ARCH); defaulting to cross-build for $PLATFORM"
  fi
fi

if [[ -n "${PLATFORM:-}" ]]; then
  echo "[INFO] Using buildx for platform: $PLATFORM"
  # Buildx cross-build and push in one step (requires buildx and QEMU installed via Docker Desktop)
  docker buildx build --platform "$PLATFORM" -t "$IMAGE" --push .
  PUSHED=1
else
  docker build -t "$IMAGE" .
  echo "[INFO] Pushing image: $IMAGE"
  docker push "$IMAGE"
  PUSHED=1
fi

echo "[INFO] Done. Pushed $IMAGE"