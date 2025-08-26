#!/usr/bin/env bash
set -euo pipefail

# Build and push all service images to GHCR
# Requirements:
#  - GHCR_TOKEN (PAT with write:packages)
#  - GHCR_OWNER (GitHub username or org)
# Optional:
#  - TAG (default: latest)
#  - PLATFORM (e.g., linux/amd64)
#  - SERVICES (space-separated list). Default: "identity product cart order payment api-gateway"
#
# Usage:
#   GHCR_OWNER=<owner> GHCR_TOKEN=<pat> ./scripts/docker-build-all.sh
#   GHCR_OWNER=<owner> GHCR_TOKEN=<pat> TAG=v0.1.0 SERVICES="cart order" ./scripts/docker-build-all.sh

: "${GHCR_OWNER:?Set GHCR_OWNER to your GitHub username/org}"
: "${GHCR_TOKEN:?Set GHCR_TOKEN to a GitHub PAT with write:packages}"

TAG=${TAG:-latest}
#SERVICES=${SERVICES:-"identity product cart order payment api-gateway"}
SERVICES=${SERVICES:-"api-gateway"}

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

for svc in $SERVICES; do
  echo "[INFO] Building $svc as ghcr.io/${GHCR_OWNER}/${svc}:${TAG}"
  SERVICE="$svc" IMAGE_NAME="$svc" TAG="$TAG" PLATFORM="${PLATFORM:-}" GHCR_OWNER="$GHCR_OWNER" GHCR_TOKEN="$GHCR_TOKEN" \
    "$ROOT_DIR/scripts/docker-build.sh"
done

echo "[OK] Built and pushed images: $SERVICES (tag: $TAG)"
